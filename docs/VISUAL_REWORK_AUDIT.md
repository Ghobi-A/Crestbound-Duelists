# Visual rework audit

Status: **2026-09-05 repository-wide audit**. This is the evidence and scope ledger
for the vertical-slice presentation pass; it does not certify interactive quality.

## Player-facing map

| Flow | Scene / owner | Current presentation | Principal gap |
| --- | --- | --- | --- |
| Boot/title, new/continue | `boot.tscn`, `boot_screen.gd` | Unified slate/gold chrome and restrained title composition | No authored title mark or key art; menu has little atmosphere |
| Greymere exploration | `greymere.tscn`, `greymere.gd`, `map_renderer.gd` | Layered/autotiled town, props, vignette, NPC indicators | Generated tiles and landmark are readable but not production art |
| Dialogue | `dialogue_box.gd`, JSON dialogue | Portrait-aware bottom box; missing portraits degrade to full-width copy | Only neutral portraits exist; 44 px box makes long prose dense |
| Party setup | `party_setup.tscn`, `party_setup.gd` | Data-driven roster, row and party order | List-first composition still reads as setup tooling; no Crest/Entity focal art |
| Hollow Court battle | `party_battle.tscn`, controller/resolver/HUD scripts | Variable formations, grounding, targeting rings, anticipation/hit/defeat motion, awakening flash | One generated background; effects are geometric; entities assume a two-frame strip |
| Victory/defeat | battle controller + dialogue | Outcome copy and scene transition | No dedicated result composition, sting, or authored outcome illustration |
| Onboarding/round review | shared UI nodes | Consistent semantic accents | Modal rectangles compete with characters on the small canvas |

The reachable slice is boot → Greymere → NPC/dialogue → Court entrance → party
setup → battle → victory return (or defeat to boot). Debug encounter shapes remain
data-supported but are not additional story screens.

## Asset inventory and classification

“Authored-local” means hand-plotted in `tools/authored_art.py`; it is a deliberate
intermediate, **not final production approval**. “Generated support” means the
deterministic generator is an appropriate long-term owner only where non-focal.

| Family | Files present | Classification | Finding |
| --- | ---: | --- | --- |
| Aren class battle poses | 6 PNG + sidecars | authored-local / replacement-ready | Single-frame 37–57×44 silhouettes; motion tween supplies absent states |
| Elara/Mira battle poses | 2 PNG + sidecars | authored-local / replacement-ready | Single-frame, no state acting |
| Story enemy battle poses | 3 PNG + sidecars | authored-local / replacement-ready | Single-frame, bosses not represented |
| Aren/Elara/Mira overworld | 8 twelve-frame sheets | generated placeholder | Functional 24×32 walkers; focal characters need authored sheets |
| Nine townsfolk overworld sprites | 9 PNG + sidecars | authored-local / replacement-ready | Static front pose only; sufficient for stationary slice NPCs, not production animation |
| Portraits | 17 neutral PNG | authored-local / incomplete | Consistent 86×96 crop; 68 required expression files are missing |
| Bonded Entities | 5 two-frame 64×32 strips | generated placeholder | Focal manifestation art; Grave Stag exists although no current player default |
| Hollow Court background | 320×122 PNG | generated placeholder | Correct gameplay safe region; lacks authored depth and landmark finish |
| Greymere terrain/props/glow/vignette | 4 PNG + tile manifest | generated support | Acceptable architecture and deterministic variants; focal Court arch remains placeholder |
| UI font/icons | bitmap font + 56×7 atlas | generated support | Cohesive and crisp; icon vocabulary is too small for production |
| Root `ChatGPT Image …` PNGs | 19 loose files | obsolete/unintegrated references | No runtime references, non-semantic names, uncertain clearance; retain pending provenance review |
| `docs/visual_refs/baseline_*` | captured renders | generated regression evidence | Never ship as game art |
| `battle_art_style_reference`, `overworld_art_style_reference` | 2 images | external reference only | Composition benchmark; explicitly prohibited as source pixels |
| Audio folder | `.gitkeep` only | missing | No music, UI, dialogue, battle, awakening or environment audio |
| Crest art, landmarks, VFX, UI ornament | none | missing | Highest-impact production gap after focal character animation |

The exhaustive, path-level production contract is in `ASSET_MANIFEST.md`.

## Cross-screen inconsistencies

* **Scale and finish:** authored-local single poses, generated walkers, painterly
  portraits and procedural tiles occupy visibly different finish levels.
* **Hierarchy:** battle sprites own the upper field, but setup and outcome moments
  are dominated by text panels. Dialogue is consistently placed yet too shallow
  for its longest lines.
* **Feedback:** target gold/violet grammar is coherent. Brace/Hex/awakening use
  small geometric overlays that communicate state but do not express their fiction.
* **Transitions:** scene changes are functional cuts. The Court entrance, awakening,
  victory and defeat lack authored transition frames and audio punctuation.
* **Lighting:** Greymere's vignette and Court palette suggest one moonlit world,
  but characters do not yet share a reliable rim-light/value convention.

## Comparison with visual references

The reference targets show larger readable silhouettes, foreground occlusion,
landmark-led navigation, layered atmospheric depth and effects with clear attack
vectors. Current Greymere has correct layer separation and deterministic terrain
transitions, but lower material variety and landmark specificity. Current battle
has correct opposing formation and contact shadows, but smaller focal figures,
shallower depth, and generic shape-based VFX. No source pixels or identifiable
designs from the references are permitted.

## Architectural blockers found and addressed

1. Battle background code previously assumed exact 320×122 source pixels. It now
   accepts sidecar-directed `cover`, `contain`, or `native` fitting and focal crop.
2. Entity rendering previously hardcoded 32×32 frames and offsets. It now reads
   frame geometry, anchor, and stage offset from the same sidecar convention.
3. Dialogue always requested `neutral`. It now accepts the documented five-word
   expression vocabulary with neutral fallback; dialogue data can direct acting.
4. Missing: Crest art, Entity state metadata, VFX atlases, landmarks and UI
   ornament have stable target paths specified, but should not be filled with
   low-quality permanent stand-ins.

## Priorities and acceptance risks

**P0:** authored animated Aren/Elara/Mira/enemies, Court background/node, Crest
awakening and impact VFX, expression portraits, title mark, and essential audio.
**P1:** Entity manifestations, Greymere landmark kit, setup/result compositions,
status icons. **P2:** townsfolk motion, ambient variants and secondary ornament.

Static checks cannot judge silhouette quality, frame timing, controller feel,
contrast on a target display, or audiovisual impact. Each authored delivery must
be reviewed in-engine at 320×180 and nearest-scaled 4× before its placeholder is
retired.
