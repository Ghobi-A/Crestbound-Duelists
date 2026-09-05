# Production asset manifest

This is the production contract for the **current vertical slice**, not a claim that
every listed file exists. Status: **authored-local** = hand-plotted interim art;
**placeholder** = must be replaced; **support** = generator may remain the owner;
**missing** = target path reserved. Priorities are P0 (slice-defining), P1 (needed
for production cohesion), P2 (finish). Stable IDs/paths must not be renamed casually.

## Characters and enemies

| Asset ID | Subject / purpose | Target path | Dimensions / layout | Required states | Status | Priority |
| --- | --- | --- | --- | --- | --- | --- |
| `aren-{warrior,guardian,mage,sorcerer,assassin,neutral}-ow` | Aren exploration by selected class | `game/assets/characters/aren/<class>/overworld.png` | 24×32, 12 horizontal frames | down/up/side walk ×4, west mirror | placeholder | P0 |
| `aren-<class>-battle` | Aren combat focal | `game/assets/characters/aren/<class>/battle.png` | target 40×48 horizontal; per-file sidecar | idle, attack, signature, gambit, hit, brace, awaken, defeat | authored-local; idle only | P0 |
| `elara-ow`, `mira-ow` | Companion exploration | `game/assets/characters/{elara,mira}/overworld.png` | 24×32, 12 horizontal frames | down/up/side walk ×4 | placeholder | P0 |
| `elara-battle`, `mira-battle` | Companion combat | `game/assets/characters/{elara,mira}/battle.png` | 40×48 horizontal + sidecar | idle, attack, signature, gambit, hit, brace, awaken, defeat | authored-local; idle only | P0 |
| `riven-raider-battle` | Riven-touched Raider | `game/assets/enemies/riven_raider/battle.png` | 48×48 horizontal + sidecar | idle, attack, signature, gambit, hit, brace, defeat | authored-local; idle only | P0 |
| `hexbound-adept-battle` | Hexbound Adept | `game/assets/enemies/hexbound_adept/battle.png` | 40×48 horizontal + sidecar | same, plus hex-cast anticipation | authored-local; idle only | P0 |
| `unbound-mercenary-battle` | Unbound Mercenary | `game/assets/enemies/unbound_mercenary/battle.png` | 44×48 horizontal + sidecar | idle, attack, signature, gambit, hit, brace, defeat | authored-local; idle only | P0 |
| `townsfolk-<key>-ow` | Nine named/flavour NPCs | `game/assets/characters/townsfolk/<key>/overworld.png` | 16–24×30 + sidecar | down idle; side/up optional | authored-local static | P2 |

Townsfolk keys: `elder_woman`, `farmboy`, `farmhand_capped`, `guard_spear`,
`guard_sword`, `herbalist_woman`, `hooded_stranger`, `torch_bearer`, `village_elder`.

## Portrait contract

| Asset ID | Character/location | Purpose / target path | Dimensions / states | Status | Priority |
| --- | --- | --- | --- | --- | --- |
| `portrait-aren-<class>-<expression>` | Aren / all class looks | Dialogue and major battle beat; `game/assets/portraits/aren/<class>/<expression>.png` | 86×96; five separate crops | neutral authored-local; 24 expressions missing | P0 |
| `portrait-elara-<expression>` | Elara | `game/assets/portraits/elara/<expression>.png` | 86×96; neutral, determined, injured, surprised, intense | neutral authored-local; 4 missing | P0 |
| `portrait-mira-<expression>` | Mira | `game/assets/portraits/mira/<expression>.png` | same | neutral authored-local; 4 missing | P0 |
| `portrait-town-<key>-<expression>` | Nine townsfolk | `game/assets/portraits/townsfolk/<key>/<expression>.png` | 86×96; neutral required, other expressions optional | neutral authored-local; optional 36 missing | P2 |

## Crests and Bonded Entities

| Asset ID | System / purpose | Target path | Dimensions / layout | States | Status | Priority |
| --- | --- | --- | --- | --- | --- | --- |
| `crest-{crimson,azure,ember,eclipse,glass,verdant}-icon` | Crest menus/status | `game/assets/crests/<id>/icon.png` | 16×16 | dormant, active readability | missing | P1 |
| `crest-<id>-card` | Setup/lore focal | `game/assets/crests/<id>/card.png` | 96×128 | dormant glyph artwork | missing | P1 |
| `crest-<id>-awaken` | Awakening transition | `game/assets/vfx/awakening/<id>.png` | 160×90, horizontal frames + sidecar | gather, glyph, release, settle | missing | P0 |
| `entity-{storm_lion,iron_tortoise,ash_seraph,mirror_fox,grave_stag}` | Battle manifestation | `game/assets/entities/<id>/idle.png` | target 48×48 horizontal + sidecar | idle ≥4; appear/hit/awaken reserved in sidecar | placeholder 2×32 | P1 |
| `entity-<id>-card` | Setup/bond focal | `game/assets/entities/<id>/card.png` | 128×96 | neutral manifestation | missing | P1 |

## Locations, landmarks and props

| Asset ID | Location / purpose | Target path | Dimensions / layout | States | Status | Priority |
| --- | --- | --- | --- | --- | --- | --- |
| `bg-hollow-court` | Battle depth and staging | `game/assets/battle/backgrounds/hollow_court.png` + `.json` | ≥320×122; cover/contain/native, focal point, safe area | dormant; awakened optional alternate | placeholder; sidecar ready | P0 |
| `greymere-terrain` | Ground/water/path/walls | `game/assets/tiles/greymere_atlas.png` | 16×16 atlas, manifest coordinates and 4-bit transitions | terrain variants | support | P2 |
| `greymere-props` | Non-focal town dressing | `game/assets/tiles/greymere_props.png` | manifest-driven atlas | roof/foliage/fence/barrel/lamp props | support | P2 |
| `greymere-court-arch` | Navigation/story landmark | `game/assets/landmarks/greymere_court_arch.png` | 64×64 + sidecar anchor | sealed, open, cleared glow | missing (atlas stand-in) | P0 |
| `hollow-court-node` | Battle/story focal landmark | `game/assets/landmarks/hollow_court_node.png` | 64×64 horizontal + sidecar | dormant pulse, responding, awakened | missing (background stand-in) | P0 |
| `greymere-lighting` | Atmosphere support | `game/assets/tiles/{glow,vignette}.png` | 48×48 and 320×180 | static modulation | support | P2 |

## VFX, UI and audio

| Asset ID | Purpose | Target path | Dimensions / layout | Required states | Status | Priority |
| --- | --- | --- | --- | --- | --- | --- |
| `vfx-basic-{slash,blunt,magic}` | Basic action readability | `game/assets/vfx/actions/<id>.png` | 48×48 horizontal + sidecar | anticipation/contact/decay | missing | P0 |
| `vfx-signature-<move-id>` | One distinct motif per YAML signature move | `game/assets/vfx/moves/<move_id>.png` | 64×64 horizontal + sidecar | cast/travel/contact/decay as applicable | missing | P0 |
| `vfx-gambit-{physical,magic}` | High-risk action weight | `game/assets/vfx/actions/gambit_<type>.png` | 64×64 horizontal + sidecar | charge/contact/decay | missing | P0 |
| `vfx-{brace,hex,resonance,heal,defeat}` | Persistent/status feedback | `game/assets/vfx/status/<id>.png` | 32×32 or 48×48 + sidecar | apply, loop, expire | missing; geometry stand-in | P1 |
| `ui-title-mark` | Boot identity | `game/assets/ui/title_mark.png` | ≤240×64 transparent | static | missing | P0 |
| `ui-frame-atlas` | Crest-specific corners/dividers | `game/assets/ui/frame_atlas.png` | 64×32, 1 px grid | corners, divider, selection tick | missing; code-drawn stand-in | P1 |
| `ui-icons` | Command/objective/status language | `game/assets/ui/icons.png` + manifest | 7×7 cells | current 8 plus Brace, Hex, Resonance, rows, result | support; incomplete | P1 |
| `ui-font` | Readable pixel typography | `game/assets/ui/crestbound_font.*` | 8 px body face | glyph coverage in `.fnt` | support | P1 |
| `result-{victory,defeat}-ornament` | Dedicated outcome composition | `game/assets/ui/results/<state>.png` | ≤160×48 transparent | static | missing | P1 |
| `audio-music-{greymere,court,battle,victory,defeat}` | Scene identity | `game/assets/audio/music/<id>.ogg` | loop points documented | five cues | missing | P0 |
| `audio-sfx-*` | UI move/confirm/cancel, step, dialogue, hit types, Brace, Hex, Resonance, awaken | `game/assets/audio/sfx/<id>.ogg` | mono, normalized family | one-shot/loop metadata | missing | P0 |

The move-VFX row expands to these YAML-owned `vfx_key` asset IDs (and therefore
exact target basenames): `slash_arc`, `armor_shatter`, `dust_trail`, `arcane_bolt`,
`mind_shards`, `overload_burst`, `quick_flash`, `cripple_slash`, `lethal_gleam`,
`shield_impact`, `fortify_glow`, `avalanche_rocks`, `hybrid_spark`, `focus_aura`,
`wild_shimmer`, `flame_burst`, `hex_sigil`, and `voidfire_pillar`. Their current
status is **missing**, P0; adding a move to YAML adds a matching manifest obligation.

### Integration rule

Focal PNGs ship with a same-name JSON sidecar. Battle/overworld sheets declare
frame geometry, count, feet `anchor` and named states. Entities additionally declare
`stage_offset`. Backgrounds declare `fit` and normalized `focal_point`; `safe_area`
documents the unobscured composition. Missing art must render the current fallback,
log only actionable malformed metadata, and never alter combat state.

### Runtime sidecar schemas (P0 delivery detail)

All sheets are transparent RGBA PNGs with equal-width frames in one horizontal
row. `anchor` is measured from each frame's top-left; VFX `offset` is relative to
the affected Duelist's authored effect origin above their feet. Presentation JSON
must never contain power, damage, accuracy, cooldown, or status chance.

* **Battle Duelist:** `frame_width`, `frame_height`, `frame_count`, `anchor`, and
  `states`. Frame order is idle (2–4 looping), attack anticipation/contact/recovery,
  signature anticipation/contact/recovery, gambit anticipation/contact/recovery,
  hit, brace loop, awaken loop, defeat. Each state supplies `start`, `count`, `fps`,
  and `loop`. Facing is right for players and left for opponents; do not bake both
  facings into one sheet.
* **VFX:** target 48×48 for ordinary action/status effects and 64×64 for signature
  and gambit effects. Sidecar keys are `frame_width`, `frame_height`, `frame_count`,
  `fps`, `loop`, `anchor`, `offset`, `scale`, `z_index`, optional `states`, and
  `hold` (0–0.25 seconds). Ordinary effects target 0.16–0.35 seconds; signatures
  0.25–0.55; gambits 0.3–0.65. Default layer is above combatants and below HUD.
* **Awakening:** `<crest_id>.png`, 160×90 frames, gather → glyph → release → settle,
  target total 0.55–0.9 seconds, non-looping; transparent background. The runtime
  supplies environment dim and recovery, so artwork must not paint a full opaque
  screen or invent a Crest glyph absent from approved concept art.
* **Entity:** `frame_width`, `frame_height`, `frame_count`, `anchor`, `stage_offset`,
  default `fps`, and optional `states` named appear/idle/hit/awaken/dismiss. Missing
  states fall back to idle. Idle loops; emphasis states target 0.2–0.6 seconds.
* **Environment plates:** 320×122 minimum. Optional `<location>_far.png`, main
  `<location>.png`, and `<location>_foreground.png` share `fit`, normalized
  `focal_point`, and `[x,y,w,h]` `safe_area`. Foreground is transparent and may
  occupy only outer edges; it cannot cover either formation, rings, or the 110–180
  HUD region.
* **Landmark:** transparent 64×64 with feet/base `anchor`, optional `z_index`, and
  no baked map terrain. The Court opening remains aligned to the existing `C` tile.
* **Title/result:** title mark is transparent, at most 240×48 in its composition;
  result ornaments are transparent 160×48. Text must not be baked into result art.
