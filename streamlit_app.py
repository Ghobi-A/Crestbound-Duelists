"""
Crestbound Duelists — Balance Lab
==================================
Streamlit front end for the Python simulation stack: live Monte Carlo duels,
the precomputed 6x6 balance matrix, AI policy comparison, and the data
pipeline that feeds the Godot client.

Run locally:
    streamlit run streamlit_app.py
"""

from __future__ import annotations

import json
import math
from pathlib import Path

import pandas as pd
import plotly.graph_objects as go
import streamlit as st

from ai import POLICIES
from models import ClassName
from simulation import ALL_CLASSES, run_matchup

# ── Links ────────────────────────────────────────────────────────────
GITHUB_URL = "https://github.com/Ghobi-A/Crestbound-Duelists"
# Set once the Godot web build is published (GitHub Pages / itch.io).
GODOT_WEB_URL = ""

REPO_ROOT = Path(__file__).resolve().parent
SNAPSHOT_PATH = REPO_ROOT / "results" / "recruiter_snapshot.json"

# ── Palette (light surface, validated) ───────────────────────────────
SURFACE = "#fcfcfb"
TEXT_PRIMARY = "#0b0b0b"
TEXT_SECONDARY = "#52514e"
TEXT_MUTED = "#8a8880"
GRID = "#e8e7e3"
SERIES = ["#2a78d6", "#eb6834", "#1baf7a"]  # blue, orange, aqua

# Diverging blue<->red around a neutral gray midpoint, for win rates
# centred on 50%. Losing side red, winning side blue.
DIVERGING = [
    (0.00, "#a02a2a"),
    (0.15, "#e34948"),
    (0.32, "#ec8080"),
    (0.44, "#f5b0b0"),
    (0.50, "#f0efec"),
    (0.56, "#9ec5f4"),
    (0.68, "#5598e7"),
    (0.85, "#2a78d6"),
    (1.00, "#184f95"),
]

PLOTLY_LAYOUT = dict(
    paper_bgcolor=SURFACE,
    plot_bgcolor=SURFACE,
    font=dict(color=TEXT_SECONDARY, size=13),
    margin=dict(l=10, r=10, t=40, b=10),
    hoverlabel=dict(bgcolor="#ffffff", font_size=13, bordercolor=GRID),
)


st.set_page_config(
    page_title="Crestbound Duelists — Balance Lab",
    page_icon="⚔️",
    layout="wide",
)


# ── Snapshot ─────────────────────────────────────────────────────────

@st.cache_data(show_spinner=False)
def load_snapshot() -> dict | None:
    """Precomputed analytics, committed to the repo. None if not generated."""
    if not SNAPSHOT_PATH.exists():
        return None
    return json.loads(SNAPSHOT_PATH.read_text(encoding="utf-8"))


@st.cache_data(show_spinner=False)
def simulate(class_a: str, class_b: str, n_sims: int, policy: str) -> dict:
    """Live Monte Carlo run. Cached so repeated settings are instant."""
    result = run_matchup(ClassName(class_a), ClassName(class_b), n_sims, policy)
    result.pop("logs", None)
    return result


@st.cache_data(show_spinner=False)
def sample_battle(class_a: str, class_b: str, policy: str) -> list[dict]:
    """One logged battle, for the readable action trace."""
    result = run_matchup(
        ClassName(class_a), ClassName(class_b), 1, policy, log_actions=True
    )
    return [
        {
            "Turn": log.turn,
            "Actor": log.actor_class,
            "Move": log.move_name,
            "Type": log.move_type,
            "Hit": "yes" if log.hit else "miss",
            "Damage": log.final_damage,
            "Target HP": f"{log.target_hp_before} → {log.target_hp_after}",
        }
        for log in result["logs"]
    ]


def wilson_interval(wins: int, n: int, z: float = 1.96) -> tuple[float, float]:
    """Wilson score interval — well behaved near 0% and 100%, unlike normal."""
    if n == 0:
        return (0.0, 0.0)
    p = wins / n
    denom = 1 + z**2 / n
    centre = (p + z**2 / (2 * n)) / denom
    margin = z * math.sqrt(p * (1 - p) / n + z**2 / (4 * n**2)) / denom
    return (100 * max(0.0, centre - margin), 100 * min(1.0, centre + margin))


snapshot = load_snapshot()
CLASS_NAMES = [c.value for c in ALL_CLASSES]


# ── Header ───────────────────────────────────────────────────────────

st.title("Crestbound Duelists")
st.caption(
    "A tested Monte Carlo balance laboratory powering an original "
    "turn-based tactical RPG."
)

m1, m2, m3, m4 = st.columns(4)
m1.metric("Regression tests", "140")
m2.metric("Playable classes", str(len(CLASS_NAMES)))
m3.metric(
    "Simulations per matchup",
    f"{snapshot['sims_per_matchup']:,}" if snapshot else "—",
)
m4.metric("Data architecture", "YAML → Godot")

links = st.columns(3)
links[0].link_button("View source on GitHub", GITHUB_URL, use_container_width=True)
if GODOT_WEB_URL:
    links[1].link_button(
        "Play the RPG prototype", GODOT_WEB_URL, use_container_width=True
    )

if snapshot is None:
    st.warning(
        "No precomputed snapshot found. Run "
        "`python tools/generate_snapshot.py` to populate the Balance Matrix "
        "and AI Policy tabs. The Live Duel simulator works regardless."
    )

st.divider()

tab_duel, tab_matrix, tab_policy, tab_arch = st.tabs(
    ["Live Duel", "Balance Matrix", "AI Policy Comparison", "Engineering Architecture"]
)


# ── Live Duel ────────────────────────────────────────────────────────

with tab_duel:
    st.subheader("Live Duel Simulator")
    st.write(
        "Runs the real combat engine in this browser session — every battle "
        "rolls damage variance, accuracy, Brace and Hex from the YAML data."
    )

    left, right = st.columns(2)
    with left:
        class_a = st.selectbox("Duelist A", CLASS_NAMES, index=0)
        class_b = st.selectbox("Duelist B", CLASS_NAMES, index=1)
    with right:
        policy = st.selectbox(
            "AI policy", sorted(POLICIES), index=sorted(POLICIES).index("greedy")
        )
        simulations = st.slider(
            "Simulations", min_value=100, max_value=5_000, value=1_000, step=100
        )
        show_log = st.checkbox("Show a sample battle log", value=False)

    if st.button("Run simulation", type="primary"):
        with st.spinner(f"Simulating {simulations:,} battles..."):
            result = simulate(class_a, class_b, simulations, policy)

        lo_a, hi_a = wilson_interval(result["wins_a"], result["n_sims"])

        c1, c2, c3 = st.columns(3)
        c1.metric(f"{result['class_a']} win rate", f"{result['win_rate_a']}%")
        c2.metric(f"{result['class_b']} win rate", f"{result['win_rate_b']}%")
        c3.metric("Average duration", f"{result['avg_turns']} turns")

        st.caption(
            f"{result['n_sims']:,} simulations · 95% Wilson interval for "
            f"{result['class_a']}: {lo_a:.1f}% – {hi_a:.1f}% "
            f"(±{(hi_a - lo_a) / 2:.1f} points)"
        )

        fig = go.Figure()
        fig.add_trace(
            go.Bar(
                x=[result["win_rate_a"], result["win_rate_b"]],
                y=[result["class_a"], result["class_b"]],
                orientation="h",
                marker=dict(color=[SERIES[0], SERIES[1]], line=dict(width=0)),
                text=[f"{result['win_rate_a']}%", f"{result['win_rate_b']}%"],
                textposition="outside",
                textfont=dict(color=TEXT_PRIMARY, size=14),
                hovertemplate="%{y}: %{x}% win rate<extra></extra>",
                width=0.5,
            )
        )
        fig.add_vline(
            x=50, line=dict(color=TEXT_MUTED, width=1, dash="dot"),
            annotation_text="even", annotation_position="top",
            annotation_font=dict(color=TEXT_MUTED, size=11),
        )
        fig.update_layout(
            **PLOTLY_LAYOUT,
            height=220,
            showlegend=False,
            xaxis=dict(range=[0, 108], showgrid=True, gridcolor=GRID,
                       ticksuffix="%", zeroline=False),
            yaxis=dict(showgrid=False),
            bargap=0.4,
        )
        st.plotly_chart(fig, use_container_width=True)

        with st.expander("Raw result"):
            st.json(result)

        if show_log:
            st.subheader("Sample battle")
            log_rows = sample_battle(class_a, class_b, policy)
            if log_rows:
                st.dataframe(
                    pd.DataFrame(log_rows), use_container_width=True, hide_index=True
                )
            else:
                st.info("That battle produced no logged actions.")


# ── Balance Matrix ───────────────────────────────────────────────────

with tab_matrix:
    st.subheader("Balance Matrix")

    if snapshot is None:
        st.info("Generate the snapshot to populate this tab.")
    else:
        st.write(
            f"Every one of the 15 unique matchups run "
            f"{snapshot['sims_per_matchup']:,} times with the "
            f"`{snapshot['matrix_policy']}` policy. Each cell is the row "
            f"class's win rate against the column class."
        )

        matrix = snapshot["win_matrix"]
        z = [[matrix[a][b] for b in CLASS_NAMES] for a in CLASS_NAMES]
        text = [
            [("—" if a == b else f"{matrix[a][b]:.1f}") for b in CLASS_NAMES]
            for a in CLASS_NAMES
        ]

        heat = go.Figure(
            go.Heatmap(
                z=z,
                x=CLASS_NAMES,
                y=CLASS_NAMES,
                zmin=0,
                zmax=100,
                colorscale=DIVERGING,
                text=text,
                texttemplate="%{text}",
                textfont=dict(size=13),
                xgap=2,
                ygap=2,
                hovertemplate=(
                    "%{y} vs %{x}<br>%{y} wins %{z:.1f}% of battles<extra></extra>"
                ),
                colorbar=dict(
                    title=dict(text="Win rate", side="right"),
                    ticksuffix="%",
                    outlinewidth=0,
                    thickness=14,
                ),
            )
        )
        heat.update_layout(
            **PLOTLY_LAYOUT,
            height=520,
            xaxis=dict(title="Opponent", side="top", showgrid=False),
            yaxis=dict(title="Duelist", autorange="reversed", showgrid=False),
        )
        st.plotly_chart(heat, use_container_width=True)

        st.subheader("Ranked class win rates")
        averages = snapshot["class_averages"]
        ranked = sorted(averages.items(), key=lambda kv: kv[1])
        names = [k for k, _ in ranked]
        values = [v for _, v in ranked]

        bars = go.Figure(
            go.Bar(
                x=[v - 50 for v in values],
                y=names,
                base=50,
                orientation="h",
                marker=dict(
                    color=values,
                    cmin=0,
                    cmax=100,
                    colorscale=DIVERGING,
                    line=dict(width=0),
                ),
                text=[f"{v:.1f}%" for v in values],
                textposition="outside",
                textfont=dict(color=TEXT_PRIMARY, size=13),
                hovertemplate=(
                    "%{y}: %{customdata:.1f}% average win rate<extra></extra>"
                ),
                customdata=values,
                width=0.55,
            )
        )
        bars.add_vline(x=50, line=dict(color=TEXT_MUTED, width=1, dash="dot"))
        bars.update_layout(
            **PLOTLY_LAYOUT,
            height=340,
            showlegend=False,
            xaxis=dict(range=[min(values) - 8, max(values) + 8], showgrid=True,
                       gridcolor=GRID, ticksuffix="%", zeroline=False),
            yaxis=dict(showgrid=False),
            bargap=0.35,
        )
        st.plotly_chart(bars, use_container_width=True)

        spread = max(averages.values()) - min(averages.values())
        st.caption(
            f"Average win rate across all opponents, mirror matches excluded. "
            f"Spread between strongest and weakest class: {spread:.1f} points."
        )

        with st.expander("Matrix as a table"):
            st.dataframe(
                pd.DataFrame(z, index=CLASS_NAMES, columns=CLASS_NAMES),
                use_container_width=True,
            )


# ── AI Policy Comparison ─────────────────────────────────────────────

with tab_policy:
    st.subheader("AI Policy Comparison")

    if snapshot is None:
        st.info("Generate the snapshot to populate this tab.")
    else:
        st.write(
            "Three decision policies — `random`, `greedy` (highest expected "
            "damage this turn) and `lookahead` (one-step minimax that values "
            "buffs, debuffs and Hex, then subtracts the opponent's best "
            "response) — played against each other in mirror matches, so "
            "class strength cancels out and only the policy differs. "
            f"{snapshot['policy_sims_per_class']:,} battles per class per "
            "pairing."
        )

        comparison = snapshot["policy_comparison"]
        fig = go.Figure()

        for idx, (key, per_class) in enumerate(comparison.items()):
            name_a, name_b = key.split("_vs_")
            values = [per_class[c]["win_rate_a"] for c in CLASS_NAMES]
            fig.add_trace(
                go.Bar(
                    name=f"{name_a} vs {name_b}",
                    x=CLASS_NAMES,
                    y=values,
                    marker=dict(color=SERIES[idx % len(SERIES)], line=dict(width=0)),
                    text=[f"{v:.0f}" for v in values],
                    textposition="outside",
                    textfont=dict(color=TEXT_PRIMARY, size=11),
                    hovertemplate=(
                        f"%{{x}} mirror match<br>{name_a} beats {name_b} "
                        "%{y:.1f}% of the time<extra></extra>"
                    ),
                )
            )

        fig.add_hline(
            y=50,
            line=dict(color=TEXT_MUTED, width=1, dash="dot"),
            annotation_text="no advantage",
            annotation_position="top left",
            annotation_font=dict(color=TEXT_MUTED, size=11),
        )
        fig.update_layout(
            **PLOTLY_LAYOUT,
            height=440,
            barmode="group",
            bargap=0.3,
            bargroupgap=0.08,
            legend=dict(orientation="h", yanchor="bottom", y=1.02, x=0),
            xaxis=dict(showgrid=False),
            yaxis=dict(
                title="First policy's win rate",
                range=[0, 105],
                showgrid=True,
                gridcolor=GRID,
                ticksuffix="%",
                zeroline=False,
            ),
        )
        st.plotly_chart(fig, use_container_width=True)
        st.caption(
            "Bars above the dotted line mean the first policy in the pairing "
            "wins more than half its mirror matches against the second."
        )

        st.info(
            "**The deeper policy is the weaker one.** `lookahead` loses to "
            "`greedy` in every class it does not tie, and drops to 3.1% "
            "(Warrior) and 0.9% (Guardian). It even loses to `random` in "
            "those two classes.\n\n"
            "This is a real result, not a bug. `lookahead` spends turns on "
            "buffs, debuffs and Hex that its heuristic overvalues, while "
            "battles here resolve in about three turns — far too fast for "
            "tempo investments to pay off. Depth of search does not help "
            "when the horizon is shorter than the payback period, and the "
            "effect is worst for the classes whose kits offer the most "
            "utility moves to be tempted by."
        )

        with st.expander("Policy comparison as a table"):
            rows = []
            for key, per_class in comparison.items():
                name_a, name_b = key.split("_vs_")
                for cls in CLASS_NAMES:
                    rows.append(
                        {
                            "Pairing": f"{name_a} vs {name_b}",
                            "Class": cls,
                            "First policy win %": per_class[cls]["win_rate_a"],
                            "Second policy win %": per_class[cls]["win_rate_b"],
                        }
                    )
            st.dataframe(
                pd.DataFrame(rows), use_container_width=True, hide_index=True
            )

        nash_rows = snapshot.get("nash", [])
        if nash_rows:
            st.subheader("Game-theoretic check")
            agree = sum(1 for r in nash_rows if r["greedy_matches_nash"])
            mixed = sum(1 for r in nash_rows if not r["is_pure_a"])
            n1, n2 = st.columns(2)
            n1.metric(
                "Greedy matches the maximin move",
                f"{agree}/{len(nash_rows)} matchups",
            )
            n2.metric(
                "Matchups with a mixed optimal strategy",
                f"{mixed}/{len(nash_rows)}",
            )
            st.caption(
                "Single-turn normal-form games solved by linear programming "
                "(`nash.py`). This asks whether the cheap greedy heuristic "
                "actually plays the game-theoretically optimal move, and "
                "where stochastic execution fails to induce mixed strategies. "
                "Every matchup resolves to a **pure** optimal strategy that "
                "greedy already finds — which explains the chart above, and "
                "says something about the design: damage variance alone does "
                "not create the payoff structure that rewards mixing. "
                "Making duels genuinely strategic needs mechanics that "
                "punish predictability, not just wider damage rolls."
            )
            with st.expander("Per-matchup maximin analysis"):
                st.dataframe(
                    pd.DataFrame(
                        [
                            {
                                "Matchup": f"{r['class_a']} vs {r['class_b']}",
                                "Greedy move": r["greedy_move"],
                                "Maximin move": r["nash_dominant"],
                                "Agree": "yes" if r["greedy_matches_nash"] else "no",
                                "Entropy": r["entropy_a"],
                                "Pure strategy": "yes" if r["is_pure_a"] else "no",
                            }
                            for r in nash_rows
                        ]
                    ),
                    use_container_width=True,
                    hide_index=True,
                )


# ── Engineering Architecture ─────────────────────────────────────────

with tab_arch:
    st.subheader("Engineering Architecture")
    st.write(
        "One source of truth. The YAML in `data/` defines every stat, move "
        "and encounter; the Godot client hardcodes no balance values."
    )

    st.code(
        """
YAML configuration          data/*.yaml — classes, moves, crests, encounters
      |
      v
Validation / loaders        loaders.py — schema checks, typed dataclasses
      |
      v
Combat engine               combat.py — initiative, variance, Brace, Hex
      |
      v
Monte Carlo + AI policies   simulation.py, ai.py — random / greedy / lookahead
      |
      v
Balance reports             balance_report.py, nash.py — matrices, maximin
      |
      v
JSON export                 export_game_data.py -> exports/*.json
      |
      v
Godot client                game/ — 320x180 pixel-art RPG, gl_compatibility
        """.strip(),
        language="text",
    )

    a1, a2 = st.columns(2)
    with a1:
        st.markdown(
            """
**Why it is built this way**

- Balance changes are data edits, not code edits. Retune a class in
  `data/classes.yaml`, re-run the suite, re-export.
- The simulation harness and the shipped game read the *same* numbers,
  so the analysis can never drift from the product.
- 140 regression tests cover loaders, combat resolution, AI policies,
  the Nash solver, encounters and the export pipeline.
            """
        )
    with a2:
        st.markdown(
            """
**Reproducing this page**

- `python tools/generate_snapshot.py` recomputes every precomputed
  figure shown here and writes `results/recruiter_snapshot.json`.
- CI regenerates that snapshot whenever `data/` changes, so the
  dashboard cannot go stale against the balance data.
- Live duels on the first tab run the real engine on request —
  nothing on this page is a mock.
            """
        )

    if snapshot:
        st.caption(
            f"Snapshot generated {snapshot['generated_at']} "
            f"(commit `{snapshot.get('git_commit') or 'unknown'}`) in "
            f"{snapshot['runtime_seconds']}s."
        )
