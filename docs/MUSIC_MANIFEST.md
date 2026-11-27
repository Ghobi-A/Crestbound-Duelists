# Music manifest

Every music cue Chapter One asks for: what exists, where it plays, and what
plays until a missing track arrives. Rights for the delivered tracks are in
`docs/AUDIO_SOURCES.md`.

The runtime is `game/scripts/presentation/audio_router.gd`.

- **Cues.** A cue is a file name in `game/assets/audio/music/<cue>.ogg`.
- **Crossfades.** Two players crossfade, so a change of track never cuts.
  The default fade is 0.8 s, and 0.5 s into a battle.
- **Resume.** The map's track resumes where it left off after a battle
  (`remember_music`).
- **Ducking.** Staged dialogue ducks the music by 7 dB.
- **Buses.** Music plays on the Music bus. Players set its level (0–10)
  in Settings, saved in `user://settings.cfg`.

**Adding a missing track needs no code.** Export it as Ogg Vorbis, about
−18 LUFS integrated, with its loop point at the file's start, and save it
under the cue name. It replaces its fallback in `MUSIC_FALLBACK`.

## Delivered

| Cue | File | Length | Plays | Loops |
|---|---|---|---|---|
| `main_theme` | `music/main_theme.ogg` | 1:52 | title, Quick Battle, credits; Civara's fallback; the ending's fallback | yes |
| `opening_theme` | `music/opening_theme.ogg` | 1:41 | *The Last Accord* | no (cinematic) |
| `greymere` | `music/greymere.ogg` | 1:27 | Greymere and its homes | yes |
| `greymere_route` | `music/greymere_route.ogg` | 1:24 | Route 01 | yes |
| `battle` | `music/battle.ogg` | 2:39 | every battle; fallback for the boss, Court and result cues | yes |

## Missing, with their integration points

| Cue | Where it plays | Until it exists |
|---|---|---|
| `hollow_court` | the three Hollow Court rooms (`music_id`) | no music; the `court` ambience carries the rooms |
| `court_battle` | the Wisp, Husk, Protect-Joey and anchor fights | `battle` |
| `greymaw_boss` | Old Greymaw's den | `battle` |
| `choir_boss` | the Sealed Choir | `battle` |
| `incident` | the collapse at dusk (StoryDirector `music` effect in `danfor_cordon`) | silence under the scene |
| `civara` | the forecourt and the Classification Hall | `main_theme` |
| `chapter_ending` | the ending cinematic and the credits | `main_theme` |
| `victory` | the victory banner | the battle track carries on |
| `defeat` | the defeat banner | the battle track carries on |

## Suno prompts for the missing tracks

Written to sit beside the delivered score (orchestral fantasy, restrained,
Celtic and choral colour). Each prompt is a starting point: keep the take
that loops cleanly and sits under dialogue.

**`hollow_court`: exploration, loops, about 2:00.**
> Dark ambient orchestral underscore for an ancient drowned temple beneath a village. Slow, low strings, distant wordless choir holding one sustained note, faint bowed metal, water-drip percussion, a fragile harp motif that never resolves. Sparse, eerie and reverent, not horror. No drums, no vocals with words. 60 BPM, D minor, seamless loop.

**`court_battle`: Riven skirmishes, loops, about 1:45.**
> Tense orchestral battle music for fighting ghostly light creatures in a sunken stone temple. Driving low ostinato strings, taiko and frame drums, sharp col legno hits, a wordless choir answering in short phrases, glassy synth shimmer for the Riven light. Urgent but restrained, room for sound effects. 120 BPM, E minor, seamless loop.

**`greymaw_boss`: the optional wolf boss, loops, about 2:15.**
> Folk-orchestral boss battle against an ancient giant wolf in a forest hollow at dusk. Pounding low drums like a heartbeat, snarling cellos and basses, a mournful fiddle and whistle carrying a village-legend melody, horn calls that feel like a howl, and a rising choir at the climax. Wild and primal, earthy rather than magical. 132 BPM, A minor, seamless loop.

**`choir_boss`: the climax, loops, about 2:30.**
> Epic choral orchestral final-boss music for the opening chapter of a fantasy RPG: an ancient containment rite turned hostile, a ring of singing stone statues. Massive wordless choir in Latin-like syllables, pipe organ, full brass, relentless string ostinato and war drums. A bell tolls on the downbeats, and there is a fragile solo-soprano bridge before the final surge. Grand, sacred and threatening. 140 BPM, C minor, seamless loop.

**`incident`: under the collapse scene, about 1:00, no loop needed.**
> Cinematic tension cue: a quiet village at dusk as the ground gives way. Low sustained cello and bass drone, distant rumbling timpani swells, high violins in uneasy clusters, a few muted horn stabs, one deep boom near the end and then silence. No melody, no drums groove. Builds dread for 60 seconds.

**`civara`: the capital, loops, about 2:00.**
> Stately Renaissance-inspired orchestral theme for a grand administrative city of Duelists. Bright brass fanfare figures, harpsichord and lute arpeggios, marching snare kept light, strings carrying a proud but slightly cold melody, bustle and bureaucracy rather than heroism. 100 BPM, F major, seamless loop.

**`chapter_ending`: the ending and credits, about 2:30.**
> Emotional orchestral ending theme for the first chapter of a fantasy RPG: a young man far from his small home village looks out over a great city at night. Begins with a solo piano and harp playing a gentle home melody, then the strings take it and the full orchestra swells with a hopeful choir, before settling back to a quiet, unresolved piano phrase. Warm, bittersweet, hopeful. 72 BPM, G major.

**`victory`: banner sting, about 0:06, no loop.**
> Short triumphant orchestral victory fanfare for a fantasy RPG battle win: brass and strings, a rising three-note motif, a cymbal swell and a warm final chord. Six seconds.

**`defeat`: banner sting, about 0:06, no loop.**
> Short sombre orchestral defeat sting for a fantasy RPG: low strings descending, a soft muted horn, a fading timpani roll ending on an unresolved minor chord. Six seconds.

## Ambience beds

These come through the gameplay audio manifest (`tools/audio_sources/gameplay_sfx.json`,
generated by ElevenLabs and built by `tools/build_gameplay_audio.py`):

| Ambience | Bed |
|---|---|
| `greymere` | village day |
| `route` | the road |
| `interior` | the homes |
| `court` | the Hollow Court: cold drip and hum |
| `civara` | the stone square |
