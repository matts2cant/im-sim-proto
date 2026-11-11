"""Bakes the lockpicking one-shot sounds to WAV: a port of the HTML prototype's WebAudio synth.

Reference: design/prototypes/lockpicking_bench.html, "Audio (placeholder synth)". ADR 0108.

    py -3.12 tools/sfx_gen/lockpick_sfx.py            # writes items/lockpick/audio/sfx/*.wav
    py -3.12 tools/sfx_gen/lockpick_sfx.py --vectors  # prints biquad test vectors (GDScript test data)

Standard library only. Deterministic: noise comes from fixed seeds (zlib.crc32 of the cue name, the
variant and the part), so re-running reproduces the same files byte for byte.

What is ported, following the Web Audio API specification:
- `tone(freq, dur, vol, type, endFreq, delay)`: an OscillatorNode (phase 0 at its start) whose
  frequency is held or ramped with exponentialRampToValueAtTime, through a GainNode set to `vol` and
  ramped exponentially to 0.0001 over `dur`, stopped at `dur + 0.02`. Waveforms are the spec's Fourier
  series (square, sawtooth, triangle, sine) summed up to the Nyquist frequency at the current pitch, and
  normalised so the full series peaks at 1, as browsers build their band-limited tables.
- `burst(dur, vol, type, freq, q, delay)`: white noise in [-1, 1) (a buffer of Math.random() * 2 - 1;
  the random start offset into it is just another stretch of noise, so each variant draws fresh noise
  from its seed) through a BiquadFilterNode, with the same gain envelope, stopped at `dur + 0.02`.
  Biquads use the spec's coefficient formulas: lowpass and highpass take Q in dB
  (alpha = sin(w0) / (2 * 10^(Q/20))), bandpass takes Q linearly (alpha = sin(w0) / (2 Q)).
- Every cue goes through the master gain (0.7) and is written 44.1 kHz, mono, 16-bit, clipped to [-1, 1].

Cues that use noise get three variants (`<cue>_1.wav` ... `_3.wav`), played at random in game;
noise-free cues get one file (`<cue>.wav`). `relock` is new (not in the prototype): the creak of the
plug turning back, then three quick pin settles built like `drop` and `tick`.

Next to each new WAV the tool writes a minimal `.import` asking Godot for uncompressed PCM
(`compress/mode=0`), so the game plays the exact samples and tests can read them.
"""

import math
import os
import random
import struct
import sys
import zlib

SAMPLE_RATE = 44100
MASTER_GAIN = 0.7
ENVELOPE_FLOOR = 0.0001  # the gain's exponential ramp target
STOP_TAIL = 0.02  # sources stop at dur + 0.02
VARIANTS = 3

# Peak of each spec waveform's full Fourier series (the Gibbs overshoot for square and sawtooth:
# Si(pi) / (pi / 2)); browsers scale their band-limited tables by its inverse.
GIBBS_PEAK = 1.1789797444721672
WAVE_PEAK = {"sine": 1.0, "square": GIBBS_PEAK, "sawtooth": GIBBS_PEAK, "triangle": 1.0}

OUT_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "items", "lockpick", "audio", "sfx")


# ---------- the prototype's palette ----------


def tone(freq, dur, vol, wave="sine", end_freq=None, delay=0.0):
    return {"kind": "tone", "freq": freq, "dur": dur, "vol": vol, "wave": wave, "end_freq": end_freq, "delay": delay}


def burst(dur, vol, ftype, freq, q=1.0, delay=0.0):
    return {"kind": "burst", "dur": dur, "vol": vol, "ftype": ftype, "freq": freq, "q": q, "delay": delay}


def relock_parts():
    """Creak (the plug turns back), then three pins settle 75 and 80 ms apart, falling in pitch."""
    parts = [tone(140, 0.28, 0.12, "sawtooth", 95)]
    for delay, pitch in ((0.30, 2400), (0.375, 2150), (0.455, 1900)):
        parts.append(tone(pitch, 0.03, 0.1, "square", None, delay))
        parts.append(burst(0.015, 0.12, "highpass", 4200, 1, delay))
    return parts


# The SFX table, transcribed from the prototype (click(muted) split into two cues).
CUES = {
    "click": [burst(0.03, 0.45, "highpass", 3200), tone(3400, 0.04, 0.18, "square")],
    "click_muted": [burst(0.03, 0.12, "highpass", 3200), tone(1800, 0.04, 0.05, "square")],
    "tick": [burst(0.02, 0.22, "highpass", 4200)],
    "clunk": [tone(170, 0.14, 0.45, "sine", 110), burst(0.08, 0.3, "lowpass", 900)],
    "creak": [tone(140, 0.28, 0.12, "sawtooth", 95)],
    "jam": [tone(95, 0.16, 0.5, "sine", 70), burst(0.1, 0.35, "lowpass", 600)],
    "snap": [burst(0.12, 0.7, "highpass", 1800), tone(1500, 0.18, 0.3, "square", 260)],
    "drop": [tone(2400, 0.03, 0.12, "square"), tone(1900, 0.03, 0.1, "square", None, 0.05)],
    "open": [
        tone(420, 0.09, 0.4, "square", 300),
        burst(0.1, 0.4, "bandpass", 1200, 2, 0.07),
        tone(260, 0.16, 0.35, "sine", 180, 0.08),
    ],
    "relock": relock_parts(),
}


# ---------- Web Audio building blocks ----------


def exp_ramp(v0, v1, duration, t):
    """exponentialRampToValueAtTime: v0 * (v1 / v0)^(t / duration) during the ramp, v1 after."""
    if t >= duration:
        return v1
    return v0 * (v1 / v0) ** (t / duration)


def wave_partials(wave):
    """(harmonic -> coefficient of sin(k * phase)) generator for the spec's waveforms."""
    if wave == "sine":
        return lambda k: 1.0 if k == 1 else 0.0
    if wave == "square":
        return lambda k: 4.0 / (math.pi * k) if k % 2 == 1 else 0.0
    if wave == "sawtooth":
        return lambda k: (2.0 / (math.pi * k)) * (1.0 if k % 2 == 1 else -1.0)
    if wave == "triangle":
        return lambda k: (8.0 / (math.pi * math.pi * k * k)) * (1.0 if k % 4 == 1 else -1.0) if k % 2 == 1 else 0.0
    raise ValueError(wave)


def biquad_coefficients(ftype, freq, q, sample_rate=SAMPLE_RATE):
    """Web Audio BiquadFilterNode coefficients, normalised by a0: (b0, b1, b2, a1, a2)."""
    w0 = 2.0 * math.pi * freq / sample_rate
    cos_w0 = math.cos(w0)
    if ftype == "bandpass":
        alpha = math.sin(w0) / (2.0 * q)
        b0, b1, b2 = alpha, 0.0, -alpha
    else:
        alpha = math.sin(w0) / (2.0 * 10.0 ** (q / 20.0))
        if ftype == "lowpass":
            b0, b1, b2 = (1.0 - cos_w0) / 2.0, 1.0 - cos_w0, (1.0 - cos_w0) / 2.0
        elif ftype == "highpass":
            b0, b1, b2 = (1.0 + cos_w0) / 2.0, -(1.0 + cos_w0), (1.0 + cos_w0) / 2.0
        else:
            raise ValueError(ftype)
    a0 = 1.0 + alpha
    return (b0 / a0, b1 / a0, b2 / a0, -2.0 * cos_w0 / a0, (1.0 - alpha) / a0)


def biquad_process(coefficients, samples):
    """Direct form I, zero initial state."""
    b0, b1, b2, a1, a2 = coefficients
    x1 = x2 = y1 = y2 = 0.0
    out = []
    for x in samples:
        y = b0 * x + b1 * x1 + b2 * x2 - a1 * y1 - a2 * y2
        x2, x1 = x1, x
        y2, y1 = y1, y
        out.append(y)
    return out


def envelope(vol, dur, t):
    return exp_ramp(vol, ENVELOPE_FLOOR, dur, t)


def render_tone(part, length):
    """The part's samples from its start (delay excluded), `length` samples long."""
    nyquist = SAMPLE_RATE / 2.0
    coefficient = wave_partials(part["wave"])
    scale = 1.0 / WAVE_PEAK[part["wave"]]
    stop = int(round((part["dur"] + STOP_TAIL) * SAMPLE_RATE))
    out = [0.0] * length
    phase = 0.0
    max_k = int(nyquist / min(part["freq"], part["end_freq"] or part["freq"])) + 1
    coefficients = [0.0] + [coefficient(k) for k in range(1, max_k + 1)]
    for n in range(min(stop, length)):
        t = n / SAMPLE_RATE
        freq = part["freq"] if not part["end_freq"] else exp_ramp(part["freq"], part["end_freq"], part["dur"], t)
        # Sum sin(k * phase) for every partial below Nyquist (Chebyshev recurrence).
        harmonics = min(int(nyquist / freq), max_k)
        if harmonics * freq >= nyquist:
            harmonics -= 1
        angle = 2.0 * math.pi * phase
        s1, s0 = math.sin(angle), 0.0
        two_cos = 2.0 * math.cos(angle)
        value = 0.0
        for k in range(1, harmonics + 1):
            value += coefficients[k] * s1
            s1, s0 = two_cos * s1 - s0, s1
        out[n] = value * scale * envelope(part["vol"], part["dur"], t)
        phase += freq / SAMPLE_RATE
        phase -= math.floor(phase)
    return out


def render_burst(part, length, seed):
    rng = random.Random(seed)
    stop = int(round((part["dur"] + STOP_TAIL) * SAMPLE_RATE))
    noise = [rng.random() * 2.0 - 1.0 if n < stop else 0.0 for n in range(length)]
    filtered = biquad_process(biquad_coefficients(part["ftype"], part["freq"], part["q"]), noise)
    # The gain node only passes the filter's ringing after the source stops, at the 0.0001 floor.
    return [filtered[n] * envelope(part["vol"], part["dur"], n / SAMPLE_RATE) for n in range(length)]


def cue_length(parts):
    return max(int(round((p["delay"] + p["dur"] + STOP_TAIL) * SAMPLE_RATE)) for p in parts)


def render_cue(name, parts, variant):
    length = cue_length(parts)
    mix = [0.0] * length
    for index, part in enumerate(parts):
        start = int(round(part["delay"] * SAMPLE_RATE))
        if part["kind"] == "tone":
            samples = render_tone(part, length - start)
        else:
            seed = zlib.crc32(f"{name}/{variant}/{index}".encode("utf-8"))
            samples = render_burst(part, length - start, seed)
        for n, value in enumerate(samples):
            mix[start + n] += value
    return [max(-1.0, min(1.0, value * MASTER_GAIN)) for value in mix]


def is_noisy(parts):
    return any(p["kind"] == "burst" for p in parts)


# ---------- output ----------


def write_wav(path, samples):
    frames = b"".join(struct.pack("<h", int(round(s * 32767.0))) for s in samples)
    header = struct.pack(
        "<4sI4s4sIHHIIHH4sI",
        b"RIFF",
        36 + len(frames),
        b"WAVE",
        b"fmt ",
        16,
        1,  # PCM
        1,  # mono
        SAMPLE_RATE,
        SAMPLE_RATE * 2,
        2,
        16,
        b"data",
        len(frames),
    )
    with open(path, "wb") as f:
        f.write(header + frames)


IMPORT_TEMPLATE = '[remap]\n\nimporter="wav"\ntype="AudioStreamWAV"\n\n[params]\n\ncompress/mode=0\n'


def ensure_import(path):
    """A minimal .import asking for PCM; Godot fills in the rest on import. Existing files are kept."""
    import_path = path + ".import"
    if not os.path.exists(import_path):
        with open(import_path, "w", encoding="utf-8", newline="\n") as f:
            f.write(IMPORT_TEMPLATE)


def bake():
    os.makedirs(OUT_DIR, exist_ok=True)
    for name, parts in CUES.items():
        if is_noisy(parts):
            files = [(f"{name}_{v}.wav", v) for v in range(1, VARIANTS + 1)]
        else:
            files = [(f"{name}.wav", 0)]
        for filename, variant in files:
            samples = render_cue(name, parts, variant)
            path = os.path.join(OUT_DIR, filename)
            write_wav(path, samples)
            ensure_import(path)
            peak = max(abs(s) for s in samples)
            print(f"{filename:20s} {len(samples) / SAMPLE_RATE:.3f} s  peak {peak:.3f}")


def vectors():
    """Biquad test data for tests/items/lockpick/audio/lockpick_biquad_test.gd."""
    signal = [1.0, 0.5, -0.25, 0.0, -1.0, 0.75, 0.0, 0.0, 0.3, -0.6]
    for ftype, freq, q in (("bandpass", 2600.0, 3.0), ("lowpass", 900.0, 1.0), ("highpass", 3200.0, 1.0)):
        c = biquad_coefficients(ftype, freq, q)
        print(ftype, freq, q)
        print("  coefficients", ", ".join(f"{v:.12f}" for v in c))
        print("  output", ", ".join(f"{v:.12f}" for v in biquad_process(c, signal)))


if __name__ == "__main__":
    if "--vectors" in sys.argv:
        vectors()
    else:
        bake()
