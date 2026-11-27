# Audio sources and rights

Every sound in the game, where it came from and how it is built. All files
are Ogg Vorbis under `game/assets/audio/`, played through `AudioRouter`
(`game/scripts/presentation/audio_router.gd`). A missing file is silent, so
any cue can be replaced by dropping in a new `.ogg` with the same name.

## Rights

| Source | Used for | Rights position |
|---|---|---|
| **Suno** (made by the project owner) | `music/opening_theme.ogg` (cut from "The Veiled Accord") | Suno grants ownership and commercial use of songs made while subscribed to a paid plan. Songs made on the free plan are for non-commercial use only. **Confirm the plan each track was made on before a commercial release.** |
| **Project owner** (supplied tracks) | `music/main_theme.ogg`, `music/battle.ogg`, `music/greymere.ogg`, `music/greymere_route.ogg` | Added to the repository by the owner. The same Suno terms apply if they were made there. |
| **ElevenLabs** text to speech (voice "Dmitri", model `eleven_multilingual_v2`), generated on the project owner's account | `voice/opening/vo_01.ogg` … `vo_08.ogg` | ElevenLabs allows commercial use of output generated on a paid plan. Free-plan output is non-commercial and needs attribution. **Confirm the account's plan before a commercial release.** |
| **ElevenLabs** sound effects, generated on the project owner's account | Everything under `sfx/` and `ambience/` | Same terms as ElevenLabs text to speech, above. |

No third-party sample packs, library sounds or recordings are used.

## Gameplay sound effects

- **Cue list:** `tools/audio_sources/gameplay_sfx.json` holds each cue's
  ElevenLabs prompt, length, kind and target level.
- **Generation:** `tools/generate_gameplay_sfx.py` asks ElevenLabs only
  for sources that are missing. The sources are committed in
  `tools/audio_sources/sfx/gameplay/`. To try a new take, delete one
  source and run the script again.
- **Build:** `tools/build_gameplay_audio.py` builds the game files from
  those sources, with no network. Its output is byte-for-byte repeatable.

| Kind | What the build does | Output |
|---|---|---|
| one-shot | Trims silence, adds a short fade-out, mono | `sfx/<category>/<cue>.ogg` |
| steps | Splits a take of several footsteps at each footfall and keeps the four most even | `sfx/world/step_<surface>_1..4.ogg` |
| loop | Crossfades the end into the start (2 s, equal power) so it loops seamlessly; tames peaks to 14 dB above the average; stereo | `ambience/<cue>.ogg` |

### Levels

The music measures about **−18 LUFS** integrated (battle, Greymere, route,
title and opening themes: −17.5 to −18.1). Each cue's `level` is its
loudest 100 ms RMS window in dBFS, with peaks kept under −1 dBFS. The
music's loudest 100 ms sits near −15 dBFS.

| Group | Level (dBFS) | Intent |
|---|---|---|
| Footsteps | −27 to −29 | Felt under the music, never over it |
| Menu move, cancel and denied | −25 to −27 | Light ticks |
| Menu confirm, door, chest | −21 to −23 | Clear acknowledgement |
| Attack swings, miss, brace, heal, hex | −20 to −22 | |
| Hits, block, KO, court door | −15 to −19 | The punch of a round |
| Encounter sting, awakening, victory, defeat | −15 to −18 | Moments that interrupt the music |
| Ambience beds | −32 to −34 average | Beneath everything |

### In the game

- **Footsteps:** they follow the surface under the player
  (`WorldLocation.surface_at`): cobble, dirt, grass, or wood indoors.
  AudioRouter picks a different variant each step, with ±6 % pitch and
  ±1.5 dB jitter.
- **Stacking guard:** the same cue retriggered within 45 ms is dropped.
  At most 8 sound effects play at once; past that, the oldest is cut.
- **Ambience:** each location names its bed in `ambience_id` (Greymere,
  Route 01, interiors). It fades in on arrival, keeps playing across
  places that share it, and stops for battles, the title screen and the
  opening movie.

| Cue | Where it plays |
|---|---|
| `ui/move`, `ui/confirm`, `ui/cancel` | Title, party setup and battle menus. `move` also plays, softly, as a dialogue line advances. |
| `ui/denied` | A locked door |
| `world/step_*` | Each tile step, at the footfall |
| `world/door` | Entering or leaving a building |
| `world/travel` | Leaving along a road edge |
| `world/interact` | Reading a sign or a notice board |
| `world/chest` | Opening a chest |
| `world/encounter` | A wild encounter or a trainer engaging |
| `world/court_transition` | Entering the Hollow Court |
| `battle/physical`, `magic`, `heavy_physical` | An attack's wind-up (`heavy_physical` for gambits) |
| `battle/hit_physical`, `hit_magic`, `hit_heavy` | The moment of contact |
| `battle/block` | A hit on a braced target |
| `battle/brace`, `hex`, `heal`, `miss`, `ko`, `awakening` | Those battle events |
| `battle/victory`, `battle/defeat` | The result screen |

## The opening movie

The narration, the opening theme and the opening's own sound effects
(`sfx/world/heartbeat`, `wind_trees` and `birdsong`) are built by
`tools/build_opening_audio.py`. See `docs/rework/OPENING_THE_LAST_ACCORD.md`.

## Not verified

These levels are measured, not listened to. Judge the mix by ear in the
game and the web build, and adjust a cue's `level` in the cue list, then
rebuild.

Still missing:
- music for the Hollow Court, victory and defeat (the battle theme carries
  on under the result stings);
- a Resonance cue.
