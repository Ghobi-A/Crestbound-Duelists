# Crestbound Duelists

**A tested Monte Carlo balance laboratory powering an original Godot
tactical RPG.**

### ▶ [Launch the interactive Balance Lab](https://crestbound-balance-lab.streamlit.app)

[Read the technical case study](docs/ARCHITECTURE.md)
· [Browse the source](https://github.com/Ghobi-A/Crestbound-Duelists)

**Technical highlights:** 140 regression tests · YAML-driven game data ·
Monte Carlo simulation (100,000 battles per matchup) · three AI decision
policies · Nash/maximin analysis · Godot 4 client

---

Human Duelists bind themselves to **Crests** (fragments of a dead god)
and **Bonded Entities**, creating distinct class builds, abilities,
awakenings, and team compositions. Battles are variable-size Duelist
encounters (1v1 duels, 2v2 partnerships, 3v3 party fights, asymmetric
ambushes) decided by initiative, cooldowns, Brace, Hex, pre-battle
positioning, Resonance, and Crest awakening — not by moving on a grid.

---

## What this repository is

| Layer | Status | What it does |
|-------|--------|--------------|
| **Balance Lab** (Python) | Stable, tested | Combat engine, Monte Carlo simulation, AI policies, Nash/maximin analysis, YAML-driven game data, JSON export |
| **Game Client** (Godot 4) | First playable prototype | 320x180 pixel-art client: class selection, Greymere overworld, dialogue, pre-battle party setup, and a round-based 3v3 party battle in the Hollow Court with original sprite art |

**What it was:** a stochastic combat simulation and decision-system
case study (that work is preserved — see
[Simulation findings](#simulation-findings) below).

**What it is becoming:** an original tactical RPG (design:
`docs/GAME_DESIGN_FOUNDATION.md`, world: `docs/LORE_BIBLE.md`,
story: `docs/STORY_OUTLINE.md`).

---

## Architecture

```text
data/*.yaml  ──▶  loaders.py (validate)  ──▶  combat engine + simulations
     │                                              │
     │                                              ▼
     │                                    tests / balance reports
     ▼
export_game_data.py  ──▶  exports/*.json + game/data/*.json  ──▶  Godot client
```

One source of truth: the YAML in `data/`. The Godot client hardcodes
no balance values. Details: `docs/ARCHITECTURE.md` and
`docs/DATA_PIPELINE.md`.

## Running the Python side

```bash
pip install -r requirements-dev.txt   # app + tests + notebook/Nash toolchain

python -m pytest              # 140 regression tests (fast)
python balance_report.py      # quick balance smell check (~1s)
python main.py --quick        # reduced simulation suite (~10s)
python main.py                # full 100k-sims-per-matchup suite
python nash.py                # game-theoretic analysis
python export_game_data.py    # export JSON for the game client
```

## Running the Balance Lab web app

```bash
pip install -r requirements.txt   # lean runtime deps only
streamlit run streamlit_app.py
```

`streamlit_app.py` is the Streamlit Community Cloud entrypoint. It has
four tabs: a **Live Duel** simulator that runs the real engine on
request (100–5,000 battles, cached), the **Balance Matrix** heatmap and
ranked class win rates, an **AI Policy Comparison** with the Nash
agreement check, and the **Engineering Architecture** walkthrough.

The expensive figures come from a committed snapshot rather than being
computed per page load:

```bash
python tools/generate_snapshot.py              # 100k sims per matchup (~7 min)
python tools/generate_snapshot.py --sims 5000  # quick local refresh
```

The generator seeds Python's global `random` (default `--seed 42`), which
is what the combat engine draws initiative and damage variance from, so
the committed snapshot is reproducible rather than merely statistically
similar — re-running it on the same data yields an identical payload.

`.github/workflows/balance-snapshot.yml` reruns that generator whenever
`data/` or the engine changes and commits the result, so the dashboard
cannot drift from the YAML source of truth.

## Running the game

1. Install **Godot 4.2+** (https://godotengine.org/download).
2. Open `game/project.godot` in the editor and press **F5**.

Controls: WASD/arrows to move, **Z/Enter/Space** to interact/confirm,
**X/Esc** to cancel. Flow: title → class selection → Greymere → talk
to Warden Elara Thorne / Mira Solen → the Hollow Court arch →
pre-battle party setup (front/back formation) → round-based 3v3 party
battle → post-battle scene. Battle rules: `docs/BATTLE_SYSTEM.md`;
setup details: `docs/GODOT_SETUP.md`.

## Data workflow

```text
Edit YAML → run tests → run simulations → export JSON → launch Godot
```

Every combat number the game uses (class stats, move powers, accuracy,
Brace multiplier, damage variance, Crest passives and awakenings)
lives in `data/*.yaml`, is validated by `loaders.py`, is testable by
simulation, and reaches the game only through `export_game_data.py`.

---

## The combat system

Six asymmetric classes — Warrior, Mage, Assassin, Guardian, Neutral,
Sorcerer — each with exactly three moves:

| Slot | Identity |
|------|----------|
| **Basic** | Reliable, repeatable (100% accuracy, no cooldown) |
| **Signature** | Class-defining tactical action (debuffs, buffs, Hex) |
| **Gambit** | High-impact, higher-risk (more power, less accuracy) |

| Mechanic | Implementation |
|----------|----------------|
| Damage | `power × 2·ATK/(ATK+DEF) × U(0.85, 1.0)`, minimum 1 |
| Speed | Probabilistic turn order inside a 7-point band; deterministic beyond it |
| Brace | Defensive multiplier for the second mover / a visible tactical stance in grid battles |
| Hex | Blocks buff actions while active |
| Cooldowns | Gate Signature/Gambit reuse |
| Stat decay | Temporary modifiers expire after 3 turns |

| Class | HP | ATK | DEF | MAG | RES | SPD | Role |
|-------|---:|----:|----:|----:|----:|----:|------|
| Warrior | 85 | 75 | 70 | 30 | 35 | 40 | Physical bruiser |
| Mage | 75 | 30 | 35 | 80 | 75 | 42 | Magical specialist |
| Assassin | 70 | 70 | 35 | 38 | 55 | 80 | Fast striker |
| Guardian | 85 | 40 | 75 | 40 | 75 | 35 | Defensive tank |
| Neutral | 78 | 55 | 50 | 55 | 50 | 50 | Adaptive generalist |
| Sorcerer | 72 | 40 | 30 | 80 | 48 | 80 | Fast curse specialist |

On top of this, the RPG layer adds **Crests** (behaviour-altering
passives, per-crest **Resonance** gains, and earned awakenings) and
**Bonded Entities** — same class, different Crest/Entity,
meaningfully different unit. Encounters are data-defined
(`data/encounters.yaml`) and may be 1v1, 2v2, 3v3, or asymmetric;
the battle engine, UI, and AI scale to whatever the data declares.

## Simulation findings

The original research question — *when does stochastic execution force
optimal strategies to become mixed?* — and its answer are preserved:

- Across all 15 matchups, single-turn equilibria are **pure**:
  execution randomness (damage variance, probabilistic speed) does
  **not** by itself induce mixed-strategy optimal play.
- Immediate expected damage dominates single-turn decisions; strategic
  randomness needs multi-turn state (cooldowns, buffs, statuses).

Reproduce with `python nash.py` and `analysis.ipynb`
(`greedy_heatmap.png`, `class_rankings.png`, `policy_comparison.png`,
`fight_duration.png`, `move_usage.png` are generated artifacts).

## Repository structure

```text
Crestbound-Duelists/
├── data/                  # YAML source of truth (classes, moves, config,
│                          #   crests, entities, encounters, terrain,
│                          #   objectives, narrative)
├── models.py combat.py ai.py simulation.py nash.py main.py
├── loaders.py rpg_models.py export_game_data.py balance_report.py
├── streamlit_app.py       # Balance Lab web app (Streamlit entrypoint)
├── .streamlit/config.toml # app theme
├── requirements.txt       # lean runtime deps for the deployed app
├── requirements-dev.txt   # + pytest, scipy, notebook toolchain
├── results/               # committed recruiter_snapshot.json (precomputed)
├── tests/                 # pytest regression suite
├── exports/               # generated JSON (build artifact, committed)
├── game/                  # Godot 4 client (scenes, scripts, exported data,
│                          #   generated original pixel art)
├── tools/                 # Godot static validation, pixel-art generator,
│                          #   balance snapshot generator
├── docs/                  # ARCHITECTURE, GAME_DESIGN_FOUNDATION,
│                          #   BATTLE_SYSTEM, DATA_PIPELINE, GODOT_SETUP,
│                          #   LORE_BIBLE, STORY_OUTLINE
└── analysis.ipynb         # original data-science notebook
```

## License

MIT — see `LICENSE`.
