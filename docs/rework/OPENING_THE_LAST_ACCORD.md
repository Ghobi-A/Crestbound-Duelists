# Opening Movie — The Last Accord

Status: **provisional canon** (2026-11). This note adds history set several
centuries before the game. It does not change the protected documents
(`docs/LORE_BIBLE.md`, `docs/STORY_OUTLINE.md`,
`docs/GAME_DESIGN_FOUNDATION.md`). The powers use the rework names from
`docs/rework/STORY_SYNOPSIS.md`: Avelan, Draco Factum, Prudentia, Opulena.

Deliberately **unrevealed**: the original catastrophe, Eidros's death, and
whatever lies beyond the Veil. The movie should leave the player with the
sense that civilisation is built on a promise nobody truly kept.

| | First playthrough | After the ending |
|---|---|---|
| The war | Crests caused a terrible war. | Humanity misunderstood what the Crests were. |
| The Accord | It saved civilisation. | It institutionalised competition over dangerous power. |
| The chamber | It holds something dangerous. | It may have been protecting civilisation all along. |
| The awakening | Something ancient is waking. | An ancient containment system is beginning to fail. |

Tone: melancholic, mysterious, cinematic dark fantasy. Length: 1:40.5.

## How it plays

- It plays when a new story game begins, after class selection, and fades
  into Greymere with wind and birdsong.
- **Watch Opening** on the title menu replays it and returns to the menu.
- Any key shows "Hold Z to skip". Holding Confirm (Z) skips, and Back (X)
  skips at once while the prompt is showing.

The timeline is authored in
`game/data/cinematics/opening_the_last_accord.json`. Its art is in
`game/assets/cinematics/opening/`, built by `tools/build_cinematic.py` from
the PixelLab sources in `tools/cinematic_sources/opening/`.

## Shot list

| Time | Shot | What happens |
|---|---|---|
| 0:00–0:20 | Battlefield at dawn | Fade from black over an endless battlefield: broken weapons, abandoned banners, ruined fortifications, a vast stone structure split in two. Magic motes drift. An exhausted, unnamed Duelist walks through, carrying an injured child. On the horizon a colossal Bonded Entity breaks apart into light. |
| 0:20–0:25 | A city rebuilt | Scaffolding, masons, trade resuming. |
| 0:25–0:30 | Soldiers home | Soldiers return along a country road to their families. |
| 0:30–0:34 | Scholars | Fragments recovered from ancient ruins. |
| 0:34–0:40 | The hall | Four representatives around a circular stone table, under four banners. |
| 0:40–0:45 | The treaty | **THE VEILED ACCORD**. Four signatures, one after another. The music turns briefly hopeful. |
| 0:45–0:51 | Avelan | Officials seal ancient documents in an underground archive. |
| 0:51–0:57 | Draco Factum | Soldiers drill with experimental Crest-powered weapons. |
| 0:57–1:03 | Prudentia | Scholars observe an unstable fragment in a containment chamber. |
| 1:03–1:10 | Opulena | A concealed Crest is traded for a chest of gold aboard a ship. Fade to black. |
| 1:10–1:18 | Descent | The music fades. The camera sinks through mountains, earth and buried architecture. |
| 1:18–1:30 | The chamber | A chamber older than the four nations; six worn monuments around a central structure. One cracks (1:22). Faint light emerges. Something moves in the dark (1:26). A distant heartbeat (1:24, 1:26, 1:28). Cut to black at 1:30. |
| 1:31–1:38 | Title | **C R E S T B O U N D / D U E L I S T S** fades in, holds, fades out. |
| 1:39–1:40 | Into Greymere | Wind through trees and birdsong; fade into Greymere. |

## Audio you supply

Every sound is optional. A missing file is silent, so add each one whenever
it's ready, with no code change. Use **Ogg Vorbis (`.ogg`)**, 44.1 or
48 kHz, under `game/assets/audio/`; Godot imports it on the next editor
open or export.

### Narration (ElevenLabs)

One file per line. Each starts at its time below, which is also when its
subtitle appears. Keep each recording within its window. **Voice:** an
older, weary narrator, quiet and unhurried, as if remembering. No grandeur,
and no villainy.

| File | Starts | Window | Line |
|---|---|---|---|
| `voice/opening/vo_01.ogg` | 0:01.5 | 5.3 s | There was a time when men believed that power was a blessing. |
| `voice/opening/vo_02.ogg` | 0:07.3 | 5.3 s | They built their kingdoms upon it. Raised their banners in its name. |
| `voice/opening/vo_03.ogg` | 0:13.2 | 5.6 s | And when their neighbours grew stronger, they asked for more. |
| `voice/opening/vo_04.ogg` | 0:25.5 | 7.0 s | When the cost became greater than any kingdom could bear, the surviving nations made a promise. |
| `voice/opening/vo_05.ogg` | 0:34.5 | 6.5 s | Never again would the power of the Crests determine the fate of mankind. |
| `voice/opening/vo_06.ogg` | 0:46.5 | 3.0 s | Peace endured. |
| `voice/opening/vo_07.ogg` | 0:52.5 | 5.0 s | Cities flourished. Generations passed. |
| `voice/opening/vo_08.ogg` | 0:59.5 | 8.0 s | And the things we promised to bury were quietly brought back into the light. |

From 1:10 the movie has no narration.

### Music (Suno)

**Done.** The full Suno track "The Veiled Accord" (3:34) is in
`tools/audio_sources/the_veiled_accord.mp3`. `tools/build_opening_audio.py`
cuts it to `music/opening_theme.ogg` (1:40.5): the opening plays at full
level to 1:10, fades to a quiet bed under the descent, cuts to silence at
1:30, and the track's own ending plays under the title. The brief below was
the original target.

One continuous track, `music/opening_theme.ogg`, about 1:40, starting at
0:00. It should be orchestral and sparse: strings, low choir, a solo
instrument, distant percussion.

| Time | Section | Direction |
|---|---|---|
| 0:00–0:20 | Aftermath | Slow, mournful, low strings and a solo voice or cello; wide and empty. |
| 0:20–0:34 | Time passes | Gentle motion as cities rebuild; warmer harmony. |
| 0:34–0:45 | The Accord | Builds solemnly. **Brief hopeful swell at ~0:38–0:45** as the treaty is signed. |
| 0:45–1:10 | Broken promise | Hope drains; uneasy, secretive, a quiet pulse under the four vignettes. |
| 1:10–1:18 | Descent | **The music fades** to near silence (a low drone at most). |
| 1:18–1:30 | The chamber | Near silence; the heartbeat carries it. Cut to silence at 1:30. |
| 1:31–1:40 | Title | A single restrained motif or choir note under the title, decaying into the wind. |

If the title motif is easier as a separate file, make
`music/opening_title.ogg`. It starts at 1:31.5 and replaces the theme.

### Sound effects

| File | When | Sound |
|---|---|---|
| `sfx/world/heartbeat.ogg` | 1:24.0, 1:26.2, 1:28.4 | A single distant, muffled "lub-dub", about 0.7 s, barely audible. |
| `sfx/world/wind_trees.ogg` | End (into Greymere) | Wind through trees, 6–10 s. |
| `sfx/world/birdsong.ogg` | End (into Greymere) | Morning birdsong, 6–10 s. |
