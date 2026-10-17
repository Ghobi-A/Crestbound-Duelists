# Greymere Outskirts — Route 01

## Playable slice

From Greymere's southern approach, face the southern road exit and press Z
(Travel). Route 01 is a 60×35 tile map of connected forest clearings and a
winding dirt road. The western exit returns to town; the northern sign marks a
closed future-region gate. Both arrival spawns are separated from exit tiles.
Doors retain the existing adjacent-interaction controls, including interiors.

Three roadside duelists have fixed facings and four-tile, obstacle-aware sight.
Entering their line triggers a short exclamation, dialogue and the existing
party setup / battle scenes. Talking also starts a challenge. A confirmed
victory sets an individual defeated flag; later conversations use alternate
text. Cancellation returns to the saved tile without a win. Defeat restores the
party and retreats to Greymere's southern approach. An interrupted setup or
reload cannot leave a transient battle lock behind.

Tall-grass steps have a 12% encounter probability and eight-step cooldown.
These are **raider ambushes using the existing class-based combat**, not creature
collection. Safe terrain never rolls an encounter. Menus, dialogue, trading,
alerts, scene transitions and other battles suppress rolls. An initial six-step
grace and battle-return grace prevent immediate chains. RNG state is serialized
as a decimal string (avoiding JSON 64-bit precision loss), alongside cooldowns.

A side clearing contains two Potions in a one-time chest. The existing inventory,
item catalogue, save manager and field bag are reused. There is also a location
sign, a traveller with directions, flowers, a pond and the closed northern gate.

## Ownership and extension

- `tools/route_01_world.py` owns the authored route, placements, encounter zones,
  spawns, recovery destination, messages and environment-based battle backdrop.
  `python tools/build_greymere_world.py` compiles it into the existing world JSON.
- `WorldLocation` handles shared interactions and movement-step encounter hooks.
  `WorldEncounters` owns callable LOS and seeded, step-based encounter rules.
- `GameState` stores inventory/flags and per-location encounter state. A transient
  battle-return dictionary is deliberately omitted from save payloads. Version-2
  saves without the new fields load with defaults; the save version is unchanged.
- YAML remains the source of truth for all four new encounters; the exporter
  generates both JSON copies. Difficulty is a gentle 2v1 against a Crest-less
  opponent, with no parallel stat or damage implementation.
- `BattleController` and `PartySetup` route world encounter outcomes through that
  return context. Existing Hollow Court behaviour remains intact.
- Runtime atlases are materialized by the same PixelLab walk build step as PR #24.
  Standing poses, directional animation, depth sorting and camera behaviour reuse
  the existing engine. The route HUD uses a short label to fit the current plate.

## Validation

The Python topology/data tests verify every map spawn and interaction is
reachable, both transition directions, valid encounter/class/art/item references,
and reproducible map compilation. `route_smoke.tscn` runs in the real Godot client:
walking, both travel directions, all three trainer activations, LOS and blocking,
modal suppression, grass dialogue/setup, step cooldown, chest duplication,
actual battle resolution with a test-only enemy-HP fixture, victory persistence,
return/re-entry, alternate dialogue, old-save defaults and defeat recovery.
The existing world smoke continues to visit all six interiors and the Court.

QA includes native 720p/1080p captures of the route, grass approach, side clearing
and outdoor battle, plus release Web export and existing browser checks. Results
and any environment limitations are recorded in the pull request; this document
is not itself a claim that every check has completed.

## Deliberate limits

- Trainers stay at their fixed tile. The current NPC class has no walking/pathing
  system, so no separate movement implementation was introduced for approach.
- New trainers reuse existing villager/class art. Dedicated portraits and battle
  designs remain future art work; no established character designs are replaced.
- The existing source art can retain dark purple edge contamination. This change
  does not globally strip purple, which would damage legitimate cloth/effects.
- No in-battle flee mechanic was added. Existing party-setup cancellation works.
- The northern gate is intentionally closed, with explanatory text, rather than
  linking to a missing scene. No unrelated world-map or engine rewrite is included.


## Inspected native renders

The following are actual Godot 4.3 llvmpipe renders at 1280×720, captured and
visually inspected during this implementation, not mock-ups:

![Route entrance](../visual_refs/route_01/baseline_route_01.png)
![Grass approach](../visual_refs/route_01/baseline_route_grass.png)
![Optional supply clearing](../visual_refs/route_01/baseline_route_clearing.png)
![Outdoor battle](../visual_refs/route_01/baseline_battle_route.png)

The initial presentation CI run exposed an asset-build dependency ordering bug:
PixelLab's Pillow-based materializer was invoked before dependencies were
installed. Presentation validation now installs development dependencies first;
Web deployment explicitly installs Pillow before materialization. Render QA's
existing dependency setup already installs Pillow.


## Final local check results

- 266 Python tests passed; focused route/navigation tests passed after formatting.
- Ruff passed for the new Python route definition and route tests; Python source
  compilation and JavaScript syntax checking passed.
- Godot editor import/static checks passed; the walk audit reported no flags.
- The final real-client route harness reported `ROUTE_SMOKE: 0 failures`.
- Existing `WORLD_SMOKE: 0 failures` verified the six interior transitions.
- Release Web export succeeded. Playwright ran against that exported build with
  no page errors, checked four viewport sizes, and captured route travel, the
  route menu and return to Greymere. Those browser renders were inspected and
  showed the correct route/town HUD and corresponding scene in each direction.
- Four native 720p captures were inspected. CI additionally repeats selected
  route/battle captures at 1080p and runs the gameplay/Web checks.

The headless dummy renderer can emit a custom-sampler diagnostic and existing
missing move-VFX warnings. These did not cause gameplay failures; the actual
OpenGL/native and browser renders were inspected separately.
