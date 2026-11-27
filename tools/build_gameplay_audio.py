"""Build the game's gameplay sound effects from the committed ElevenLabs sources.

Reads tools/audio_sources/gameplay_sfx.json and the sources written by
tools/generate_gameplay_sfx.py, and writes Ogg Vorbis files where
AudioRouter looks for them:

* "oneshot": silence trimmed, a short fade-out, levelled, mono, to
  game/assets/audio/sfx/<category>/<cue>.ogg;
* "steps":   a take of several footsteps is split at each footfall, and the
  most even `variants` steps become <cue>_1.ogg ... <cue>_N.ogg, which
  AudioRouter picks between at random;
* "loop":    an ambience bed whose end is crossfaded into its start so it
  loops without a seam, stereo, to game/assets/audio/ambience/<cue>.ogg.

`level` is the loudest 100 ms RMS window in dBFS (for loops, the average
RMS), so cues sit at a planned distance under or over the music, which
measures about -18 LUFS. Peaks are kept under -1 dBFS. The build is
deterministic: the same sources always give the same files.

    python tools/build_gameplay_audio.py      (needs ffmpeg and numpy)
"""
from __future__ import annotations

import json
import subprocess
import tempfile
import wave
from pathlib import Path

import numpy as np

ROOT = Path(__file__).resolve().parents[1]
MANIFEST = ROOT / "tools/audio_sources/gameplay_sfx.json"
SOURCES = ROOT / "tools/audio_sources/sfx/gameplay"
SFX_OUT = ROOT / "game/assets/audio/sfx"
AMBIENCE_OUT = ROOT / "game/assets/audio/ambience"
RATE = 44100
PEAK_CEILING = 10 ** (-1.0 / 20)   # -1 dBFS
SILENCE_DB = -50.0
STEP_LENGTH = 0.34                 # seconds kept after each footfall
STEP_GAP = 0.22                    # footfalls closer than this are one step
LOOP_CROSSFADE = 2.0               # seconds
LOOP_HEADROOM = 14.0               # a bed's peaks stay this close to its average (dB)


def decode(path: Path, channels: int) -> np.ndarray:
    """Float samples, shape (frames, channels)."""
    raw = subprocess.run(["ffmpeg", "-v", "error", "-i", str(path), "-ac", str(channels), "-ar", str(RATE),
                          "-f", "f32le", "-"], check=True, capture_output=True).stdout
    return np.frombuffer(raw, dtype="<f4").reshape(-1, channels).astype(np.float64)


def encode(samples: np.ndarray, out: Path, quality: int = 4) -> None:
    out.parent.mkdir(parents=True, exist_ok=True)
    pcm = (np.clip(samples, -1.0, 1.0) * 32767.0).round().astype("<i2")
    with tempfile.TemporaryDirectory() as tmp:
        wav_path = Path(tmp) / "cue.wav"
        with wave.open(str(wav_path), "wb") as wav:
            wav.setnchannels(samples.shape[1])
            wav.setsampwidth(2)
            wav.setframerate(RATE)
            wav.writeframes(pcm.tobytes())
        subprocess.run(["ffmpeg", "-v", "error", "-y", "-i", str(wav_path), "-map_metadata", "-1",
                        "-fflags", "+bitexact", "-flags:a", "+bitexact", "-c:a", "libvorbis",
                        "-q:a", str(quality), str(out)], check=True)


def window_rms_db(samples: np.ndarray, seconds: float = 0.1) -> np.ndarray:
    mono = samples.mean(axis=1)
    size = max(1, int(RATE * seconds))
    frames = len(mono) // size
    if frames == 0:
        return np.array([20 * np.log10(max(1e-9, np.sqrt(np.mean(mono ** 2))))])
    blocks = mono[: frames * size].reshape(frames, size)
    return 20 * np.log10(np.maximum(1e-9, np.sqrt(np.mean(blocks ** 2, axis=1))))


def level(samples: np.ndarray, target_db: float, average: bool = False) -> np.ndarray:
    measured = window_rms_db(samples)
    current = 20 * np.log10(max(1e-9, np.sqrt(np.mean(samples.mean(axis=1) ** 2)))) if average else measured.max()
    gained = samples * 10 ** ((target_db - current) / 20)
    peak = np.abs(gained).max()
    return gained * (PEAK_CEILING / peak) if peak > PEAK_CEILING else gained


def trim(samples: np.ndarray, pad: float = 0.01) -> np.ndarray:
    envelope = np.abs(samples).max(axis=1)
    loud = np.nonzero(envelope > 10 ** (SILENCE_DB / 20))[0]
    if len(loud) == 0:
        return samples
    start = max(0, loud[0] - int(RATE * pad))
    end = min(len(samples), loud[-1] + int(RATE * pad))
    return samples[start:end]


def fade(samples: np.ndarray, fade_in: float, fade_out: float) -> np.ndarray:
    out = samples.copy()
    n_in = min(len(out), int(RATE * fade_in))
    n_out = min(len(out), int(RATE * fade_out))
    if n_in:
        out[:n_in] *= np.linspace(0.0, 1.0, n_in)[:, None]
    if n_out:
        out[-n_out:] *= np.linspace(1.0, 0.0, n_out)[:, None]
    return out


def footfalls(samples: np.ndarray) -> list[int]:
    """Sample index of each step: where a 10 ms envelope rises past half its
    loudest level, at least STEP_GAP after the previous one."""
    envelope = window_rms_db(samples, 0.01)
    threshold = envelope.max() - 14.0
    hop = int(RATE * 0.01)
    onsets: list[int] = []
    for i in range(1, len(envelope)):
        if envelope[i] >= threshold > envelope[i - 1] and (not onsets or (i * hop - onsets[-1]) > RATE * STEP_GAP):
            onsets.append(max(0, i * hop - int(RATE * 0.012)))
    return onsets


def build_steps(cue: dict, samples: np.ndarray) -> list[np.ndarray]:
    starts = footfalls(samples)
    steps = []
    for i, start in enumerate(starts):
        end = start + int(RATE * STEP_LENGTH)
        if i + 1 < len(starts):
            end = min(end, starts[i + 1] - int(RATE * 0.01))
        piece = samples[start:end]
        if len(piece) > RATE * 0.08:
            steps.append(fade(piece, 0.003, 0.06))
    if len(steps) < cue["variants"]:
        raise SystemExit(f"{cue['id']}: found {len(steps)} footfalls, need {cue['variants']}")
    # Keep the steps whose loudness is closest to the take's median, so no
    # variant jumps out of a walk.
    peaks = np.array([window_rms_db(step, 0.05).max() for step in steps])
    order = np.argsort(np.abs(peaks - np.median(peaks)), kind="stable")[: cue["variants"]]
    return [level(steps[i], cue["level"]) for i in sorted(order)]


def tame(samples: np.ndarray, ceiling: float) -> np.ndarray:
    """Smoothly pull down anything above `ceiling` (linear), so an anvil
    strike or a fire pop never jumps out of a background bed."""
    envelope = np.abs(samples).max(axis=1)
    hold = int(RATE * 0.02)
    padded = np.pad(envelope, (hold, hold), mode="edge")
    windows = np.lib.stride_tricks.sliding_window_view(padded, 2 * hold + 1)
    peak = windows.max(axis=1)
    gain = np.minimum(1.0, ceiling / np.maximum(peak, 1e-9))
    kernel = np.hanning(2 * hold + 1)
    gain = np.convolve(np.pad(gain, (hold, hold), mode="edge"), kernel / kernel.sum(), mode="valid")
    return samples * gain[:, None]


def build_loop(cue: dict, samples: np.ndarray) -> np.ndarray:
    overlap = int(RATE * LOOP_CROSSFADE)
    body = samples[:-overlap].copy()
    tail = samples[-overlap:]
    ramp = np.linspace(0.0, 1.0, overlap)[:, None]
    # Equal-power crossfade of the tail into the head.
    body[:overlap] = body[:overlap] * np.sin(ramp * np.pi / 2) + tail * np.cos(ramp * np.pi / 2)
    body = level(body, cue["level"], average=True)
    for _ in range(3):  # taming lowers the average a little; settle it
        body = level(tame(body, 10 ** ((cue["level"] + LOOP_HEADROOM) / 20)), cue["level"], average=True)
    return tame(body, 10 ** ((cue["level"] + LOOP_HEADROOM + 0.5) / 20))


def outputs_for(cue: dict) -> list[Path]:
    category, name = cue["id"].split("/")
    if cue["kind"] == "loop":
        return [AMBIENCE_OUT / f"{name}.ogg"]
    if cue["kind"] == "steps":
        return [SFX_OUT / category / f"{name}_{i + 1}.ogg" for i in range(cue["variants"])]
    return [SFX_OUT / category / f"{name}.ogg"]


def main() -> None:
    for cue in json.loads(MANIFEST.read_text())["cues"]:
        source = SOURCES / (cue["id"].replace("/", "__") + ".mp3")
        if not source.exists():
            raise SystemExit(f"missing source {source.relative_to(ROOT)}: run tools/generate_gameplay_sfx.py")
        if cue["kind"] == "loop":
            encode(build_loop(cue, decode(source, 2)), outputs_for(cue)[0], quality=3)
        elif cue["kind"] == "steps":
            for piece, out in zip(build_steps(cue, decode(source, 1)), outputs_for(cue), strict=True):
                encode(piece, out)
        else:
            sound = fade(trim(decode(source, 1)), 0.002, min(0.08, 0.25 * cue["duration"]))
            encode(level(sound, cue["level"]), outputs_for(cue)[0])


if __name__ == "__main__":
    main()
