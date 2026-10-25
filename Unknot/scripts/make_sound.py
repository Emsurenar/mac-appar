#!/usr/bin/env python3
"""Writes Resources/Unknot.wav, the sound a break starts with: two soft wooden notes, a fourth apart.

Each note is a small marimba: a tone plus the bar's overtones at 4 and 10 times the pitch, which die away
much faster than the tone itself. Run it again after changing the numbers below.
"""
import math
import struct
import wave
from pathlib import Path

RATE = 44100
LENGTH = 1.1          # seconds
LOUDNESS = 0.045      # RMS over the first 300 ms, out of 1: about as loud as macOS's own Purr and Glass

# (start in seconds, frequency in Hz, strength)
NOTES = [(0.0, 659.26, 1.0), (0.13, 880.0, 0.85)]   # E5, then A5
PARTIALS = [(1, 1.0, 0.3), (4, 0.22, 0.05), (10, 0.06, 0.015)]  # (multiple, strength, decay time)


def sample(t: float) -> float:
    value = 0.0
    for start, freq, strength in NOTES:
        dt = t - start
        if dt < 0:
            continue
        attack = min(dt / 0.004, 1.0)  # a 4 ms attack, so there's no click
        for multiple, level, decay in PARTIALS:
            value += strength * level * attack * math.exp(-dt / decay) * math.sin(2 * math.pi * freq * multiple * dt)
    return value


def main() -> None:
    samples = [sample(i / RATE) for i in range(int(LENGTH * RATE))]
    # Fade the last 80 ms to silence
    fade = int(0.08 * RATE)
    for i in range(fade):
        samples[-1 - i] *= i / fade
    head = samples[: int(0.3 * RATE)]
    rms = math.sqrt(sum(s * s for s in head) / len(head))
    frames = b"".join(struct.pack("<h", int(s / rms * LOUDNESS * 32767)) for s in samples)
    out = Path(__file__).resolve().parent.parent / "Resources" / "Unknot.wav"
    with wave.open(str(out), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(frames)
    print(f"Wrote {out} ({out.stat().st_size // 1024} KB)")


if __name__ == "__main__":
    main()
