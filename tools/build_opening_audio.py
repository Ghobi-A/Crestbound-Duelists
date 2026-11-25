"""Cut the opening movie's theme from the full Suno track.

tools/audio_sources/the_veiled_accord.mp3 (3:34) becomes
game/assets/audio/music/opening_theme.ogg (1:40.5), timed to
game/data/cinematics/opening_the_last_accord.json:

* 0:00-1:10  the track's opening at full level (Scenes 1-3);
* 1:10-1:18  fades to a quiet bed under the descent;
* 1:18-1:30  the bed holds under the chamber and cuts to silence at the
             cut to black;
* 1:31.5     the track's own ending (its last 9 s) under the title card;
* the music ducks about 5 dB under each narration window in the timeline.

It also encodes the narration: tools/audio_sources/narration/vo_NN.mp3
(ElevenLabs, voice "Dmitri") becomes game/assets/audio/voice/opening/
vo_NN.ogg, with leading and trailing silence trimmed and loudness evened.

    python tools/build_opening_audio.py      (needs ffmpeg)
"""
from __future__ import annotations

import json
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "tools/audio_sources/the_veiled_accord.mp3"
OUT = ROOT / "game/assets/audio/music/opening_theme.ogg"
TIMELINE = ROOT / "game/data/cinematics/opening_the_last_accord.json"
NARRATION = ROOT / "tools/audio_sources/narration"
VOICE_OUT = ROOT / "game/assets/audio/voice/opening"
DUCK = 0.55              # music level under narration (about -5 dB)
BODY_END = 90.0          # cut to black
FADE = (70.0, 78.0)      # the music fades as the descent begins
BED = 0.08               # level held under the chamber
GAP = 1.5                # silence before the title
ENDING = (204.6, 213.6)  # the track's natural close


def _ducking() -> str:
    windows = json.loads(TIMELINE.read_text())["narration"]
    under = "+".join(f"between(t,{w['start'] - 0.3},{w['end'] + 0.3})" for w in windows)
    return f"volume='if({under},{DUCK},1)':eval=frame"


def build_narration() -> None:
    VOICE_OUT.mkdir(parents=True, exist_ok=True)
    trim = ("silenceremove=start_periods=1:start_threshold=-45dB,areverse,"
            "silenceremove=start_periods=1:start_threshold=-45dB,areverse,"
            "loudnorm=I=-16:TP=-1.5:LRA=7")
    for source in sorted(NARRATION.glob("vo_*.mp3")):
        subprocess.run(["ffmpeg", "-v", "error", "-y", "-i", str(source), "-af", trim, "-map_metadata", "-1",
                        "-c:a", "libvorbis", "-q:a", "6", "-ar", "44100", "-ac", "1",
                        str(VOICE_OUT / f"{source.stem}.ogg")], check=True)


def main() -> None:
    build_narration()
    a, b = FADE
    level = (f"if(lt(t,{a}),1,if(lt(t,{b}),1-{1 - BED}*(t-{a})/{b - a},"
             f"if(lt(t,{BODY_END - 0.4}),{BED},{BED}*({BODY_END}-t)/0.4)))")
    graph = (f"[0:a]atrim=0:{BODY_END},asetpts=PTS-STARTPTS,volume='{level}':eval=frame[a];"
             f"anullsrc=r=48000:cl=stereo,atrim=0:{GAP}[s];"
             f"[0:a]atrim={ENDING[0]}:{ENDING[1]},asetpts=PTS-STARTPTS,afade=t=in:d=1.2[c];"
             f"[a][s][c]concat=n=3:v=0:a=1,{_ducking()}[out]")
    OUT.parent.mkdir(parents=True, exist_ok=True)
    subprocess.run(["ffmpeg", "-v", "error", "-y", "-i", str(SOURCE), "-filter_complex", graph,
                    "-map", "[out]", "-map_metadata", "-1", "-c:a", "libvorbis", "-q:a", "5",
                    "-ar", "48000", str(OUT)], check=True)


if __name__ == "__main__":
    main()
