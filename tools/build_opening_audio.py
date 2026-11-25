"""Cut the opening movie's theme from the full Suno track.

tools/audio_sources/the_veiled_accord.mp3 (3:34) becomes
game/assets/audio/music/opening_theme.ogg (1:40.5), timed to
game/data/cinematics/opening_the_last_accord.json:

* 0:00-1:10  the track's opening at full level (Scenes 1-3);
* 1:10-1:18  fades to a quiet bed under the descent;
* 1:18-1:30  the bed holds under the chamber and cuts to silence at the
             cut to black;
* 1:31.5     the track's own ending (its last 9 s) under the title card.

    python tools/build_opening_audio.py      (needs ffmpeg)
"""
from __future__ import annotations

import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "tools/audio_sources/the_veiled_accord.mp3"
OUT = ROOT / "game/assets/audio/music/opening_theme.ogg"
BODY_END = 90.0          # cut to black
FADE = (70.0, 78.0)      # the music fades as the descent begins
BED = 0.08               # level held under the chamber
GAP = 1.5                # silence before the title
ENDING = (204.6, 213.6)  # the track's natural close


def main() -> None:
    a, b = FADE
    level = (f"if(lt(t,{a}),1,if(lt(t,{b}),1-{1 - BED}*(t-{a})/{b - a},"
             f"if(lt(t,{BODY_END - 0.4}),{BED},{BED}*({BODY_END}-t)/0.4)))")
    graph = (f"[0:a]atrim=0:{BODY_END},asetpts=PTS-STARTPTS,volume='{level}':eval=frame[a];"
             f"anullsrc=r=48000:cl=stereo,atrim=0:{GAP}[s];"
             f"[0:a]atrim={ENDING[0]}:{ENDING[1]},asetpts=PTS-STARTPTS,afade=t=in:d=1.2[c];"
             "[a][s][c]concat=n=3:v=0:a=1[out]")
    OUT.parent.mkdir(parents=True, exist_ok=True)
    subprocess.run(["ffmpeg", "-v", "error", "-y", "-i", str(SOURCE), "-filter_complex", graph,
                    "-map", "[out]", "-map_metadata", "-1", "-c:a", "libvorbis", "-q:a", "5",
                    "-ar", "48000", str(OUT)], check=True)


if __name__ == "__main__":
    main()
