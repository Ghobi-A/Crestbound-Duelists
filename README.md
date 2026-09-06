# Crestbound Duelists

**A tested Monte Carlo balance laboratory powering an original Godot
tactical RPG.**

### ▶ [Launch the interactive Balance Lab](https://crestbound-balance-lab.streamlit.app)
### ▶ [Play the browser prototype](https://ghobi-a.github.io/Crestbound-Duelists/) — Quick Battle reaches gameplay in one click, no install

[Read the technical case study](docs/ARCHITECTURE.md)
· [Browse the source](https://github.com/Ghobi-A/Crestbound-Duelists)

**Technical highlights:** 140+ regression tests · YAML-driven game data ·
Monte Carlo simulation (100,000 battles per matchup) · three AI decision
policies · stateful Nash/maximin analysis · Godot 4 client

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
| **Balance Lab** (Python) | Stable, tested | Combat engine, Monte Carlo simulation, AI policies, stateful Nash/maximin analysis, YAML-driven game data, JSON export |
| **Game Client** (Godot 4) | First playable prototype | 320x180 pixel-art client: class selection, Greymere overworld, dialogue, pre-battle party setup, and a round-based 3v3 party battle in the Hollow Court with original sprite art |

**What it was:** a stochastic combat simulation and decision-system
case study (that work is preserved and corrected — see
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

python -m pytest              # regression suite
python balance_report.py      # quick balance smell check (~1s)
python main.py --quick        # reduced simulation suite (~10s)
python main.py                # full 100k-sims-per-matchup suite
python nash.py                # stateful game-theoretic analysis
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
python tools/generate_snapshot.py              # 100k sims per matchup
python tools/generate_snapshot.py --sims 5000  # quick local refresh
```

The generator seeds Python's global `random` (default `--seed 42`). The
stateful Nash rollout receives the same explicit seed and restores the
caller's random state after analysis, so the committed analytical payload
is reproducible rather than merely statistically similar.

`.github/workflows/balance-snapshot.yml` validates combat changes on pull
requests. On `main` it reruns the full suite, regenerates YAML-derived
exports for the Godot client, validates the Godot project, regenerates the
production balance snapshot, and commits changed generated outputs.

## Running the game

**In the browser:** [ghobi-a.github.io/Crestbound-Duelists](https://ghobi-a.github.io/Crestbound-Duelists/)
— no install. From the title screen:

- **Play Story Demo** — full flow: class selection → Greymere → dialogue
  and exploration → party setup → battle.
- **Quick Battle** — recruiter shortcut. Skips Greymere entirely: picks
  a default class, loads the opening party, and drops straight into party
  setup for the Hollow Court battle.
- **Continue** — appears once a compatible save exists.
- **Controls** — shows the key bindings below at any time.

Controls: WASD/arrows to move, **Z/Enter/Space** to interact/confirm,
**X/Esc** to cancel. Party setup: Up/Down select, Left/Right toggle
front/back row, Z swap/confirm. A dismissible onboarding panel explains
controls and the objective the first time you enter Greymere, and
battle basics the first time you enter a battle. Battle rules:
`docs/BATTLE_SYSTEM.md`; setup details: `docs/GODOT_SETUP.md`.

**Locally (Godot editor):**

1. Install **Godot 4.3+** (https://godotengine.org/download).
2. Open `game/project.godot` in the editor and press **F5**.

**Web export:** `game/export_presets.cfg` defines a single "Web" export
preset — single-threaded (`variant/thread_support=false`, no
Cross-Origin-Opener/Embedder-Policy headers required), the project's
Compatibility (`gl_compatibility`) renderer, a fixed 1280×720 (16:9)
canvas, and a custom loading shell (`game/web/shell.html`).
`.github/workflows/godot-web-deploy.yml` builds and publishes it to
GitHub Pages on pushes to `main` that touch the game or deploy workflow.
The build output (`build/web/`) is generated, not committed.

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

| Mechanic | v2.2 implementation |
|----------|---------------------|
| Damage | `power × 2·ATK/(ATK+DEF) × U(0.85, 1.0)`, minimum 1 |
| Speed | `SPD + U(0,20)` initiative; gaps ≥20 are deterministic |
| Brace | `1.20×` relevant DEF/RES; defence-break Signatures punch through it |
| Hex | Blocks dedicated buff moves, strips active positive stat mods, suppresses new positive stat changes |
| Cooldowns | Signature/Gambit cooldown 1 means unavailable for the next decision round |
| Stat decay | Temporary modifiers expire after 3 turns |

The v2.2 pass deliberately leaves the six base stat spreads unchanged and
fixes structural incentives first. In particular, every Gambit now has
higher raw `power × accuracy` EV than its class Basic; its downside comes
from miss variance, cooldown and any self-debuff rather than from being a
strictly worse average-damage button.

| Class | HP | ATK | DEF | MAG | RES | SPD | Role |
|-------|---:|----:|----:|----:|----:|----:|------|
| Warrior | 85 | 75 | 70 | 30 | 35 | 40 | Physical bruiser |
| Mage | 75 | 30 | 35 | 80 | 75 | 42 | Magical specialist |
| Assassin | 70 | 70 | 35 | 38 | 55 | 80 | Fast striker / initiative control |
| Guardian | 85 | 40 | 75 | 40 | 75 | 35 | Defensive anchor |
| Neutral | 78 | 55 | 50 | 55 | 50 | 50 | Adaptive generalist |
| Sorcerer | 72 | 40 | 30 | 80 | 48 | 80 | Fast curse specialist |

On top of this, the RPG layer adds **Crests** (behaviour-altering
passives, per-crest **Resonance** gains, and earned awakenings) and
**Bonded Entities** — same class, different Crest/Entity,
meaningfully different unit. Encounters are data-defined
(`data/encounters.yaml`) and may be 1v1, 2v2, 3v3, or asymmetric;
the battle engine, UI, and AI scale to whatever the data declares.

## Simulation findings

The original research question was: *when does stochastic execution force
optimal strategies to become mixed?*

The v2.1 implementation answered that question with the single-turn matrix

```text
A[i,j] = E[damage_A(move_i)] - E[damage_B(move_j)]
```

but that matrix is separable: `A[i,j] = f(i) - g(j)`. Each player's action
therefore does not change the value of the opponent's action. The old result
that all 15 matchups produced pure equilibria was consequently **not evidence
that execution stochasticity rules out mixed play**; the payoff definition
itself largely guaranteed independent pure best responses except at ties.

That earlier result is still useful in a narrower form:

> Execution stochasticity alone does not create mixed strategies when the
> analysed payoff is immediate, expected-damage-only and action-separable.

v2.2 fixes the research model. `nash.py` now estimates a seeded three-round
state-action game by forcing each joint opening action pair and rolling the
real transition system forward:

```text
s_t = (HP, cooldowns, buffs, debuffs, Hex, initiative, Brace, ...)
Q(s_t, a_i, a_j) ≈ seeded finite-horizon rollout utility
```

That makes the 3×3 payoff matrix genuinely interaction-dependent: Armor
Break changes the value of Brace and later physical actions; Cripple changes
initiative; Fortify changes future mitigation; Hex removes/suppresses buffs;
and cooldown use changes the future action set. `nash.py` reports a
**separability residual** alongside maximin strategy entropy so mixed policies,
when found, are empirical rather than structurally impossible.

The committed `results/recruiter_snapshot.json` is regenerated from the new
model after balance changes land on `main`; use that snapshot rather than an
old v2.1 headline for current matchup conclusions.

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
│                          #   original pixel art and presentation layer)
├── tools/                 # Godot validation, art generation, analytics
├── docs/                  # architecture, design, battle, lore and story docs
└── analysis.ipynb         # original data-science notebook
```

## License

MIT — see `LICENSE`.
