#!/usr/bin/env python3
"""
Generates "Stillness" — the seamless ambient loop that plays during a Focus session.

The sound is an original, royalty-free drone: a warm low pad built from a small
harmonic series with very slow "breathing" swells. Every partial and every LFO
completes a whole number of cycles within the loop length, so the end of the file
joins its start with no click and no gap — AVAudioPlayer can loop it forever.

Output: a 16-bit stereo WAV, which the build step converts to gapless Apple Lossless
(.m4a) so the bundled asset stays small. Re-run to regenerate; the result is
deterministic (fixed phases, no randomness).

    python3 scripts/generate_ambient.py
"""

import array
import math
import wave

SR = 44100          # sample rate
LOOP_SECONDS = 24.0  # whole number of breaths fit inside this
PEAK = 0.72         # headroom below full scale

N = int(SR * LOOP_SECONDS)
GRID = 1.0 / LOOP_SECONDS  # smallest frequency whose period divides the loop


def snap(freq: float) -> float:
    """Round a frequency to the nearest one that loops seamlessly over LOOP_SECONDS."""
    return round(freq / GRID) * GRID


# A warm minor-leaning pad. Each voice: (frequency Hz, amplitude, stereo phase spread).
# Fundamental ~96 Hz with a soft harmonic series, a fifth and a sub for body, plus a
# detuned twin one grid-step away so the pad beats very slowly (period == loop length).
F0 = snap(96.0)
VOICES = []
for h, amp in [(1, 1.00), (2, 0.42), (3, 0.26), (4, 0.15), (5, 0.09), (6, 0.05)]:
    VOICES.append((snap(F0 * h), amp))
VOICES.append((snap(F0 * 1.5), 0.30))   # perfect fifth, for openness
VOICES.append((snap(F0 * 0.5), 0.34))   # sub-octave, for warmth
VOICES.append((snap(F0 + GRID), 0.50))  # detuned twin -> ~0.04 Hz beat

# Slow amplitude "breath": 12 s in, 12 s out -> 2 cycles across a 24 s loop.
BREATH_HZ = snap(1.0 / 12.0)
# A longer one-cycle swell over the whole loop for gentle drift.
DRIFT_HZ = snap(1.0 / LOOP_SECONDS)


def deterministic_phase(i: int) -> float:
    """Fixed, reproducible per-voice phase so partials don't all start aligned."""
    return (i * 0.382 % 1.0) * 2.0 * math.pi


def render():
    left = array.array("d", bytes(8 * N))
    right = array.array("d", bytes(8 * N))

    two_pi = 2.0 * math.pi
    for idx, (freq, amp) in enumerate(VOICES):
        w = two_pi * freq / SR
        phase = deterministic_phase(idx)
        # widen the stereo image: each voice sits a little differently L vs R
        pan = 0.5 + 0.18 * math.sin(idx * 1.7)
        la = amp * pan
        ra = amp * (1.0 - pan + 0.5)  # keep both channels lively
        for n in range(N):
            s = math.sin(w * n + phase)
            left[n] += la * s
            right[n] += ra * s

    # Breathing + drift envelope (shared shape, slight L/R phase offset for movement).
    bw = two_pi * BREATH_HZ / SR
    dw = two_pi * DRIFT_HZ / SR
    for n in range(N):
        breath = 0.62 + 0.38 * (0.5 + 0.5 * math.sin(bw * n - math.pi / 2))
        drift = 0.85 + 0.15 * (0.5 + 0.5 * math.sin(dw * n))
        env_l = breath * drift
        env_r = (0.62 + 0.38 * (0.5 + 0.5 * math.sin(bw * n - math.pi / 2 + 0.4))) * drift
        left[n] *= env_l
        right[n] *= env_r

    # Normalize to PEAK, then a gentle soft-clip for safety.
    peak = max(max(abs(v) for v in left), max(abs(v) for v in right)) or 1.0
    g = PEAK / peak
    out = array.array("h", bytes(2 * 2 * N))
    for n in range(N):
        l = math.tanh(left[n] * g)
        r = math.tanh(right[n] * g)
        out[2 * n] = int(max(-1.0, min(1.0, l)) * 32767)
        out[2 * n + 1] = int(max(-1.0, min(1.0, r)) * 32767)
    return out


def main():
    samples = render()
    path = "build/stillness.wav"
    with wave.open(path, "wb") as w:
        w.setnchannels(2)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(samples.tobytes())
    print(f"wrote {path}: {N} frames, {LOOP_SECONDS:g}s, {N * 4 / 1e6:.1f} MB")


if __name__ == "__main__":
    main()
