# Vertical Slice v0.1 — Specification

Living document for the opening chapter of Crestbound Duelists: the
playable vertical slice. It records what the slice contains, the design
decisions behind it, and how far implementation has got. Update the
**Status** table with every commit that changes the slice.

- Branch: `claude/vertical-slice-v0.1` (stacked on PR #37).
- Canon sources: `docs/STORY_OUTLINE.md` (protected, newest canon),
  `docs/LORE_BIBLE.md` and `docs/GAME_DESIGN_FOUNDATION.md` (protected),
  and `docs/rework/CHAPTER_ONE_PROVISIONAL_CANON.md` for new material.
- Mechanics reference: `docs/BATTLE_SYSTEM.md`.

## Status

| Area | State | Notes |
|---|---|---|
| Spec and provisional canon | done | This file and `CHAPTER_ONE_PROVISIONAL_CANON.md` |
| Combat 3.0 and the Python party engine | planned | Section 4 |
| Replay parity | planned | Section 5 |
| Progression, saves v3, Quick Battle isolation | planned | Section 6 |
| Solo encounters and Old Greymaw | planned | Sections 3 and 4.9 |
| Greymere story rework | planned | Section 2 |
| Hollow Court dungeon | planned | Section 2 |
| Civara, assessment, ending, credits | planned | Section 2 |
| Pause menu, battle HUD, results, title, settings | planned | Section 7 |
| Music director, SFX, music manifest | planned | Section 8 |
| Art (PixelLab) | planned | Section 9 |
| Balance snapshot and Streamlit tab | planned | Section 10 |
| End-to-end QA (native and web) | planned | Section 11 |

## 1. Goals and non-goals

**Goal:** a complete opening chapter of about 45–60 minutes that plays
like a real JRPG demo. Story is told through character, place and play,
with a small, readable but deep battle system and a full RPG loop
(rewards, abilities, equipment, menus, saves).

**Pillars kept** (from `GAME_DESIGN_FOUNDATION.md`):
- builds over creatures;
- commitment over movement, with no grid;
- simulation-backed balance;
- a world with weight.

Awakening is earned in battle, never a level-up. Battlefield conditions
never use tiles.

**Out of scope:** later acts, an open world, multiplayer, crafting,
procedural content, grid combat, large item or ability catalogues, the
full Bonded Entity roster, engine rewrites.

## 2. The chapter

Times are first-playthrough estimates, with optional content in brackets.

| # | Beat | Where | Play | Min |
|---|---|---|---|---|
| 1 | *The Last Accord* (skippable) | cinematic | — | 1.7 |
| 2 | Morning at Kai's house; Lena's note "EAT SOMETHING" | Kai's house | wake, read, leave | 1 |
| 3 | Joey's bad idea: the goats are loose in the orchard | Greymere | round-up mini-event | 3 |
| 4 | Danfor catches them; a sparring lesson | Greymere | **1v1 tutorial** (Basic, Signature, Gambit, Brace, a telegraph) | 4 |
| 5 | Gell's account of Civara and the powers; Joey pockets a trinket | Gell's shop | dialogue, shop | 2 |
| 6 | Lena patches the scrape and scolds Joey | Lena's house | dialogue | 1 |
| 7 | Silas: "Have you been near the old ridge?" | Silas's study | dialogue | 1.5 |
| 8 | Village activities, open | Greymere | quests, supplies, signs | [6] |
| 9 | Route 01 | Route 01 | three 1v1 trainers, a 1v2 ambush, foraging | 7 [4] |
| 10 | Greymaw's trail and den (optional) | Route 01, Greymaw's Den | **1v1 boss** | [6] |
| 11 | Abnormal signs: dogs, metallic well water, a tremor; Silas afraid | Greymere | dialogue, world changes | 2 |
| 12 | Almyra's "geological inspection"; Silas and Almyra recognise each other; the cordon | Greymere | staged scene, reactions | 3 |
| 13 | The incident: collapse, failed bonding, sealed passages, Riven; Joey missing | Greymere / north arch | staged scene; Silas's warning | 2 |
| 14 | The Collapsed Stair | Hollow Court 1 | 1v1, 1v2, shrine | 5 |
| 15 | The Drowned Gallery: Almyra pinned | Hollow Court 2 | **2v1, 2v2** | 5 |
| 16 | The Radial Chamber: Joey cornered | Hollow Court 3 | **protect Joey** (survive 4), **defeat the anchor** | 4 |
| 17 | The bond and the impossible memory | Hollow Court 3 | cinematic beat | 1.5 |
| 18 | The Sealed Choir | Hollow Court 3 | **3v1 phased boss** | 6 |
| 19 | Aftermath: custody or classification (dialogue choices) | Greymere | staged scene, choices | 4 |
| 20 | Civara: Classification Hall; six patterns answer; the player stabilises a class | Civara | staged scene, **class choice** | 3 |
| 21 | Combat assessment against a same-class assessor | Civara | **1v1** | 3 |
| 22 | Ending cinematic, credits, end of demo | — | — | 2.5 |

Critical path: about 49 minutes. With optional content: about 65.

### Progression gates (`story_stage`)

| Stage | Opens at | What changes |
|---|---|---|
| `morning` | New Game | Joey's goats event active; the Route 01 road is closed by Danfor ("after your lesson") |
| `village` | the spar is won | Route 01 opens; village quests are available |
| `abnormal` | Route 01's three trainers are beaten, or after Silas's ridge conversation and any one trainer | Abnormal signs; Almyra's arrival triggers when Kai next enters Greymere's square |
| `cordon` | Almyra's scene ends | The ridge path and Greymaw's Den close (Greymaw becomes unavailable for the rest of the chapter); the north arch cordon is up |
| `incident` | Kai talks to Danfor at the cordon at dusk | The court dungeon opens; Greymere's NPCs move to the emergency stations |
| `aftermath` | the Choir is beaten | Greymere is damaged; the custody conversation; the north road to Civara opens |
| `civara` | Kai walks the north road | Civara opens; Greymere locks behind (end of chapter) |
| `complete` | the assessment ends | The ending plays; the end-of-demo screen appears |

Greymaw is optional and missable. It is closed once the cordon goes up,
which the journal warns about ("Ferris says the wolf only comes down
before the frost").

## 3. Encounter roster

Every encounter is defined in `data/encounters.yaml`. The player party is
listed explicitly: `kai` resolves to Kai's current build, which is
Unbonded, then Unsettled, then the stabilised class.

| id | Shape | Player | Enemy | Objective | Notes |
|---|---|---|---|---|---|
| `greymere_spar_danfor` | 1v1 | Kai | Danfor (Guardian, no Crest) | defeat all | tutorial; telegraphed Shield Rush |
| `route01_rowan` | 1v1 | Kai | Apprentice Rowan (Neutral) | defeat all | trainer |
| `route01_squire` | 1v1 | Kai | Travelling Squire (Guardian) | defeat all | trainer |
| `route01_challenger` | 1v1 | Kai | Wandering Challenger (Warrior) | defeat all | trainer; Joey's wager rematch |
| `route01_roadside` | 1v2 | Kai | two Roadside Toughs | defeat all | tall grass, random |
| `greymaw_den` | 1v1 | Kai | Old Greymaw | defeat all | optional boss, phases |
| `court_stair_wisp` | 1v1 | Kai | Riven Wisp | defeat all | visible on the map |
| `court_stair_pair` | 1v2 | Kai | two Riven Wisps | defeat all | visible on the map |
| `court_gallery_husk` | 2v1 | Kai, Almyra | Riven Husk | defeat all | Almyra freed |
| `court_gallery_pair` | 2v2 | Kai, Almyra | Husk and Wisp | defeat all | |
| `court_protect_joey` | 1+1 vs 2 | Kai, Joey (protected) | two Wisps | survive 4, protect Joey | Joey only Braces |
| `court_anchor` | 1v2 | Kai | Riven Anchor (target) and a Wisp | defeat target | the seal breaks when the anchor falls |
| `court_sealed_choir` | 3v1 | Kai, Almyra, Hale | the Sealed Choir | defeat all | three phases; retry from the shrine |
| `civara_assessment` | 1v1 | Kai | Assessor of Kai's class (another build) | defeat all | shows build variety |
| `qb_*` | any | chosen | chosen | any | Quick Battle challenges |

Shapes in the chapter: 1v1 ×9, 1v2 ×3, 2v1, 2v2, a protect battle and
3v1. 3v3 is used only in Quick Battle. No battle fills both sides with
three by default.

## 4. Combat System 3.0

The Python party engine (`party_combat.py`) and the Godot battle runtime
(`game/scripts/battle/`) implement every rule below. Values live in YAML.

### 4.1 Round flow (unchanged foundation)

1. **Commit.** Each living player unit commits one action: a move, Brace,
   Item, Awaken or Flee. Enemies choose by AI profile, or by phase script
   for bosses.
2. **Order.** Brace first, then by `spd × speed modifiers + U(0, speed_band)`.
   Ties keep commit order.
3. **Resolve** each action. Win and loss are checked after every action.
4. **End of round.** Ticks run (cooldowns, modifiers, statuses,
   damage-over-time, telegraphs), then objective progress and
   phase triggers.

### 4.2 Attack properties and affinities

- Every damaging move has a `property`: `impact`, `edge` or `arcane`.
- A unit's affinity profile is `{weak: [..], resist: [..]}`. It starts
  from its Crest's `affinity_profile`. The Entity or equipment can add or
  remove entries, and authored enemies override it.
- **Weakness:** ×`weakness_multiplier` (1.3). The attacker gains
  `weakness_resonance` (+10) and the target is **Staggered**: it loses
  Brace for the rest of the round, and a pending telegraph is delayed one
  round.
- **Resist:** ×`resist_multiplier` (0.75).
- **Exposed** (a status): every property counts as a weakness.

| Crest | Resists | Weak to | Why |
|---|---|---|---|
| Crimson | Edge | Arcane | conviction shrugs off cuts; doubt gets through |
| Azure | Impact | Arcane | built to hold a line |
| Eclipse | Arcane | Edge | at home in the dark |
| Ember | Arcane | Impact | spreads easily, smothered by weight |
| Glass | Edge | Impact | sharp, brittle |
| Verdant | — | — | adaptation |
| Unsettled (Kai after the bond) | — | — | answers all six, settles none |

### 4.3 Loadouts

- **Slots:** Basic, Signature, Gambit and Flex. **Brace** is always
  available and needs no slot.
- **Flex** takes any unlocked move that isn't already equipped.
- **Pools:** each class has its default three (`move_ids`, unchanged so
  the 1v1 lab stays comparable) plus one alternative per slot
  (`unlockable_moves`). That is six class moves, 36 in total.
- **Alternatives trade, never strictly dominate,** across these axes:
  - power against accuracy;
  - `speed` (an initiative modifier: −20 to +20);
  - mitigation (self Brace riders);
  - statuses;
  - `resonance_bonus`.
- **Kai's provisional kits:**
  - **Unbonded** (before the bond): Strike, Shoulder Check, Wild Swing,
    plus Steady Footing (Flex, unlocked by the spar).
  - **Unsettled** (after the bond): adds Crest Flare (an adaptive Arcane
    Signature, +Resonance) and Overflow (a Gambit that recoils).

### 4.4 Resonance

- **Gain:** each Crest's playstyle events (`resonance_gain`, unchanged),
  plus +10 for landing a weakness hit and +8 for answering a telegraph
  with Brace.
- **Readiness:** the meter is 0–100. Awakening is **ready** when the meter
  reaches the Crest's `min_resonance` and its `awakening_condition` holds.
  The HUD glows and plays a sound.
- **Awaken** is a command: it uses the unit's action for the round, goes
  first, and starts the effect immediately. The player chooses when.
  Once per battle.
- **All six awakenings:**
  - Crimson **Empowered Gambit:** Gambits gain +25% power and 50% lifesteal.
  - Azure **Counter Stance:** +4 DEF/RES and 30% counter.
  - Eclipse **Hex Saturation:** Hex raises used cooldowns by 1.
  - Ember **Scorched Ground:** hits apply *Scorched* (4 damage per round
    for 3 rounds, no tiles).
  - Glass **Perfect Edge:** 100% accuracy and +15% power.
  - Verdant **Overgrowth:** +initiative, and a stat bloom of +3 that
    rotates through ATK, DEF, MAG, RES and SPD each round.
  - Unsettled **Resonance Surge:** +20% power, the next hit Exposes, and
    the bearer takes 5% max HP recoil per round.
- **Fixes:** the duration counts like every other duration (+1 tick
  rule), and the AWAKE tag clears when the effect ends.

### 4.5 Bonded Entities

- **All six passives work:**
  - Storm Lion: intercept.
  - Iron Tortoise: Brace +1 round.
  - Ash Seraph: a terrain-tag bonus.
  - **Glass Mantis:** +15% against a target already hit this round.
  - **Mirror Fox:** copies the last enemy self-buff.
  - **Grave Stag:** hexed enemies deal −10% damage.
- **Granted moves** become real moves and are equipped to Flex when the
  Entity is bonded:
  - Storm Lion `lionfall_verdict`
  - Iron Tortoise `bastion_stride`
  - Grave Stag `mourning_toll`
  - Glass Mantis `shard_mantis_cut`

### 4.6 Enemy behaviour profiles

`combat_config.yaml` holds `ai_profiles`. Each profile weights expected
damage, KO chance, status value, debuff value, self-preservation (Brace
below an HP threshold), target choice (lowest HP, highest threat,
protected unit) and noise (seeded).

| Profile | Behaviour |
|---|---|
| aggressive | damage and KOs, ignores Brace |
| defensive | Braces when hurt or when the player has a ready Gambit |
| disruptive | Hex, debuffs, targets the highest-Resonance unit |
| opportunistic | finishes low HP, punishes Exposed or Staggered |
| scripted | boss phase script |

Reactivity: profiles read the player's last two actions. A run of Braces
is punished by guard-break moves; a ready awakening raises priority on
the bearer.

### 4.7 Telegraphs

- A move with `telegraph: true` takes two rounds. In round N the caster
  **winds up** (an intent icon and a warning line); in round N+1 it lands
  at its normal initiative.
- **Answers:**
  - **Brace** (the target takes `telegraph_brace_multiplier` 0.5);
  - a **Stagger** (delays the attack one round);
  - **KO** of the caster (cancels it).
- The target of a wind-up is fixed and shown.

### 4.8 Objectives

| Objective | Params | Win | Lose |
|---|---|---|---|
| `defeat_all` | — | all enemies down | all players down |
| `defeat_target` | unit tag `target` | the tagged unit down | all players down |
| `survive` | `turns_required` | the round count reached | all players down |
| `protect` | unit tag `protected` | the base objective's win | the protected unit down |

`objectives` can combine one win condition with protect.
`court_protect_joey` is `survive 4` plus `protect`. The HUD shows
progress.

### 4.9 Bosses

Boss units declare `stat_scale` (multipliers on base stats; HP
separately) and `phases`. Each phase has a trigger (`hp_below` or
`round`), a move list, an AI profile or script, an affinity override,
statuses on entry and a banner.

**Old Greymaw** (1v1). Assassin chassis; HP ×2.2; others ×1.0–1.15.
- **Stalking:** Lunge (Edge basic), Feint (lowers DEF, then gives Greymaw
  +speed next round), Rend (Edge, Bleed 2 rounds).
- **Charging:** after 2 stalking rounds, **Pounce** (a telegraphed heavy
  Impact Gambit). When Pounce resolves (hit or miss), Greymaw is
  **Exposed** for 1 round.
- **Enraged** (HP below 40%): **Howl** (removes the player's positive
  modifiers, +SPD), then the Lunge–Rend–Pounce cycle every 2 rounds.
- **Viable strategies** (checked in simulation, section 10):
  - Brace on each Pounce, then punish the Exposed round;
  - fast Edge or weakness aggression (Greymaw is weak to Arcane before
    the enrage and to Impact after it);
  - a Resonance burst: Awaken during an Exposed round;
  - item sustain.
- **Reward:** the *Greymaw Fang* charm. Once per battle, an Edge hit
  ignores Brace, and hits on Exposed or Staggered targets give
  +10 Resonance. It gives the Choir's Ward phase a second answer. The
  story stays fully beatable without it.

**The Sealed Choir** (3v1). Neutral chassis; HP ×3.6.
- **Ward:** resists Impact and Edge; weak to Arcane. **Requiem**
  (telegraphed, hits all) every 3rd round.
- **Fracture** (below 66%): Dirge Hex on the highest-Resonance unit;
  summons one Riven Wisp, once.
- **Collapse** (below 33%): Exposed every other round; attacks twice in
  Exposed rounds.

### 4.10 Items in battle

The **Item** command uses an inventory consumable. It counts as the unit's
action and resolves at Brace priority.
- Potion: +25 HP.
- Hi-Potion: +55 HP.
- Clearwater: cures Hex and Bleed.
- Resonance Tonic: +25 Resonance.
- Smelling Salts: revives a downed ally at 30% HP.

## 5. Python reference engine and replay parity

- **`party_combat.py`:** an N-vs-M battle engine with the same rules and
  ordering as the Godot runtime. All randomness goes through `Dice`, a
  seeded stream with one method per kind of draw. `combat.py` and
  `battle_1v1` stay as the **classic duel model** behind the committed
  recruiter analytics.
- **`game/scripts/battle/battle_dice.gd`** is the same interface in
  Godot. `BattleResolver` takes a dice object; live battles use a seeded
  RNG, and replays use a recorded stream.
- **Damage roll:** `floor(base × (variance_low + (variance_high − variance_low)·u))`
  in both runtimes. Bounds are unchanged; the distributions now match.
- **Parity fixture:** `tools/generate_combat_parity.py` writes the legacy
  damage-bound cases plus seeded scenarios. Each scenario holds the
  encounter, the scripted player commands, the dice stream and the
  expected event log. `combat_parity_smoke.gd` replays every scenario
  through the real Godot runtime and compares the logs. CI derives the
  expected count from the fixture.

## 6. Progression, rewards and saves

- **New data** (YAML, exported to `game/data`):
  - `data/items.yaml`: consumables;
  - `data/equipment.yaml`: charms, one slot per character;
  - `data/quests.yaml`: the main beats and optional quests;
  - `data/progression.yaml`: unlocks and rewards by flag;
  - `data/cast.yaml`: named builds — Kai's provisional profiles, Almyra,
    Hale, Joey, Danfor and the assessor templates.
- **Encounter rewards:** crowns, items, unlocks and flags, shown on the
  results screen.
- **No XP and no levels.** Kai grows through new moves, charms, Resonance
  mastery (a per-Crest counter that unlocks the class alternatives) and
  the class choice.
- **Recovery points:** Kai's bed, the Court shrine and the Civara hall.
  Each one heals the party fully and saves. Items are not refilled.
- **Economy:** crowns come from battles (8–20) and quests (15–40). Gell
  stocks consumables; the Civara stall stocks one charm and Tonics.
  Prices are set so a careful first run can afford about 2 Potions and
  1 charm without grinding.
- **Saves:**
  - `save_version` 3. v2 saves are migrated (they restart the chapter
    at Kai's house with crowns and items kept, and set
    `legacy_save_migrated`).
  - Autosave at checkpoints, plus manual save in the pause menu.
  - Quick Battle uses its own in-memory state and never writes the story
    save.
  - Settings (volumes, text speed, graphics) live in `user://settings.cfg`.

## 7. UI

- **Battle HUD:**
  - Cards are sized by party count: one large card per side in 1v1,
    stacked cards for 2–3.
  - HP bars with numbers; a Resonance bar with a ready glow.
  - Affinity icons (weak and resist), status icons and intent icons for
    telegraphs.
  - A target preview with the damage range, hit chance and affinity
    outcome.
  - The initiative rail; a round preview that scales with the action
    count; confirm and cancel.
- **Pause menu** (full screen): Party, Status, Abilities (loadout),
  Crests, Bonded Entities, Inventory, Journal, Settings, Save, Title.
- **Results:** victory or defeat banner, rewards, unlocks, quest updates,
  and Retry or Return where the encounter allows it.
- **Title:** New Game, Continue, Quick Battle, Settings, Credits,
  Watch Opening.
- **Hints:** every prompt goes through `HintBar` and `InputDevice`.
- **Checked** at 1280×720 and 960×540, with keyboard and a simulated
  controller.

## 8. Audio

- **MusicDirector** (`AudioRouter`):
  - crossfades;
  - a battle push and pop that resumes exploration music;
  - per-encounter music and boss overrides;
  - victory and defeat cues;
  - cinematic ducking;
  - buses (Master, Music, SFX, Voice, Ambience) with saved volumes.
- **Missing tracks** fall back as documented in `docs/MUSIC_MANIFEST.md`,
  which also holds the Suno prompts.
- **New effects:** Resonance, telegraph, Greymaw, Riven, item, unlock,
  quest and save sounds, plus Court and Civara ambience. ElevenLabs,
  built by `tools/build_gameplay_audio.py`.

## 9. Art

New art comes from PixelLab, matched to the existing references. The
reviewed sources are committed and the existing deterministic builders
process them. Each asset is listed in `docs/ASSET_MANIFEST.md`.

| Kind | Assets |
|---|---|
| Overworld and battle | Kai Unbonded, Old Greymaw, Riven Wisp, Riven Husk, Riven Anchor, the Sealed Choir, Specialist Hale, Joey, Danfor |
| Story figures | Joey, Lena, Danfor, Silas and Gell |
| Environments | Hollow Court and Civara |
| VFX | Greymaw and Riven effects; status and affinity icons |
| Cinematics | ending stills |

## 10. Balance and simulation

- **Engine:** the party engine, with seeds recorded in the snapshot.
- **Player policies:**
  - `random`;
  - `greedy` (highest expected damage);
  - `tactical` (Braces against telegraphs, plays weaknesses, Awakens when
    ready);
  - plus boss archetypes: `guard_counter`, `aggressor`, `burst`,
    `sustain`.
- **Reported in the snapshot's `vertical_slice` section:**
  - encounter difficulty: win rate, rounds and HP left, per encounter,
    class and policy;
  - boss strategy diversity: win rate per archetype;
  - loadout viability: every slot pair per class;
  - Resonance: time to awaken per Crest;
  - ability usage shares;
  - repeated three-action sequences;
  - policy sensitivity;
  - 3v3 class composition matrices.
- **Targets:**
  - every chapter encounter is winnable by `tactical` at ≥85% for all six
    classes (for encounters after Civara) or for the provisional kits;
  - `random` must not win bosses at above 40%;
  - at least 3 of 4 boss archetypes are viable (≥50%);
  - no single action exceeds 45% of a class's usage under `tactical`.
- **Equal win rates are not evidence of good play.** Repetition and
  dominance metrics are reported alongside them.

## 11. QA

- **Python:** the party engine (each mechanic), objectives, phases,
  telegraphs, affinities, loadouts, the save migration, quest and
  progression data, encounter shapes.
- **Godot:**
  - replay parity;
  - `story_smoke`: the whole chapter headless with forced battle
    outcomes, plus save and reload at every checkpoint;
  - `boss_smoke`: Greymaw victory, defeat, retry, skip and persistence;
  - menu and HUD smoke tests at both sizes.
- **Web:** `tools/verify_world_web.mjs` and a slice walkthrough on a real
  export, with audio instrumented and a low-frame-rate run.
- **Evidence:** Movie Maker clips and screenshots at both resolutions.
- **Still needs a human:** feel, a physical controller, listening, and
  fun.

## 12. Assumptions and open items

- Kai's age is about 20 (LORE_BIBLE).
- "Belgrave" and "Bellgrave" both appear in the docs. The slice never
  names it.
- The Hollow Court Crest stays unnamed, and "Unsettled" is a description,
  not a name. Kai's stabilised class sets the Crest's recognised pattern
  (for example, Crimson resonance), and the default Crest for that class
  is used mechanically.
- Liora first appears in Civara, at classification. The legacy
  `mira_intro` key is retired from Greymere.
- Seeds: the snapshot default is 42; parity scenarios use seed 1000 plus
  the scenario index.
