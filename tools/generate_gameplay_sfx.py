"""Ask ElevenLabs for any gameplay sound source that is missing.

Reads tools/audio_sources/gameplay_sfx.json and, for each cue whose source
tools/audio_sources/sfx/gameplay/<category>__<cue>.mp3 does not exist yet,
calls the ElevenLabs sound-effects endpoint with its prompt and duration.
Existing sources are never regenerated: delete one to ask for a new take.
The sources are committed; tools/build_gameplay_audio.py turns them into the
game's .ogg files deterministically and needs no network.

    ELEVENLABS_API_KEY=... python tools/generate_gameplay_sfx.py

(In a proxied session the key is injected, and any placeholder value works.)
"""
from __future__ import annotations

import json
import os
import sys
import time
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
MANIFEST = ROOT / "tools/audio_sources/gameplay_sfx.json"
SOURCES = ROOT / "tools/audio_sources/sfx/gameplay"
ENDPOINT = "https://api.elevenlabs.io/v1/sound-generation"


def source_path(cue_id: str) -> Path:
    return SOURCES / (cue_id.replace("/", "__") + ".mp3")


def generate(cue: dict, key: str) -> bytes:
    body = json.dumps({"text": cue["prompt"], "duration_seconds": cue["duration"],
                       "prompt_influence": cue.get("influence", 0.6)}).encode()
    request = urllib.request.Request(ENDPOINT, data=body, method="POST", headers={
        "xi-api-key": key, "Content-Type": "application/json", "Accept": "audio/mpeg"})
    for attempt in range(4):
        try:
            with urllib.request.urlopen(request, timeout=120) as response:
                return response.read()
        except OSError as error:
            if attempt == 3:
                raise
            print(f"  retry after {error}", file=sys.stderr)
            time.sleep(2 ** attempt)
    raise RuntimeError("unreachable")


def main() -> None:
    key = os.environ.get("ELEVENLABS_API_KEY", "proxy-injected")
    SOURCES.mkdir(parents=True, exist_ok=True)
    for cue in json.loads(MANIFEST.read_text())["cues"]:
        path = source_path(cue["id"])
        if path.exists():
            continue
        print(f"generating {cue['id']} ({cue['duration']} s)")
        path.write_bytes(generate(cue, key))


if __name__ == "__main__":
    main()
