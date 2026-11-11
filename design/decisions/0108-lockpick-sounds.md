# 108. Lockpicking sounds: baked one-shots from a port of the prototype's WebAudio synth, live continuous voices

Status: Accepted

Date: 2026-11-11

## Context

The player reads a lock through sound ([lockpicking.md](../game/lockpicking.md) "Feedback"). The approved HTML prototype ([lockpicking_bench.html](../prototypes/lockpicking_bench.html), "Audio (placeholder synth)" and `audioFrame()`) synthesises every sound with WebAudio: one-shots composed from `tone()` (an oscillator with exponential pitch and gain ramps) and `burst()` (filtered white noise), and two continuous voices driven every frame, the scrape (noise through a bandpass that rises with tension) and the strain (a triangle that rises before a break). The user approved those sounds and wants the game to reproduce them exactly. Godot has no WebAudio graph, the project has no audio middleware, and no third-party audio may be fetched ([ADR 0026](0026-audio.md)).

## Decision

- **One-shots are baked to WAV** by `tools/sfx_gen/lockpick_sfx.py` (Python standard library, deterministic seeds), a port of the WebAudio graph to the Web Audio specification: oscillators phase 0 at their start, their waveforms the spec's Fourier series summed below Nyquist and normalised to a peak of 1 like browsers' band-limited tables; `exponentialRampToValueAtTime` for pitch and gain (to 0.0001 over `dur`, stopped at `dur + 0.02`); BiquadFilterNode coefficients (Q in dB for lowpass and highpass, linear for bandpass); master gain 0.7; 44.1 kHz mono 16-bit, imported as uncompressed PCM. Files in `items/lockpick/audio/sfx/`.
- **Noise variants**: cues that use noise (click, click_muted, tick, clunk, jam, snap, open, relock) get three variants with different seeds, played at random (`AudioStreamRandomizer`, no pitch or volume randomisation); creak and drop are noise-free and get one file each.
- **A new `relock` cue** (a practice lock turning back and re-pinning) from the same palette: the creak, then three pin settles 75 and 80 ms apart (a short square blip at 2400, 2150 and 1900 Hz plus a tick-like highpass burst each), at the other cues' level.
- **Continuous voices are synthesised live** by `LockpickVoices` (pure logic) into an `AudioStreamGenerator` (30 ms buffer, about 46 ms once Godot rounds it to a power of two of frames), filled in `_process` from the frames available, with the prototype's formulas: scrape gain `scraping x 0.16`, bandpass centre `2000 + tension x 1600` Hz at Q 3 on a looping 1 s noise buffer; strain `s = strain > 0.12 ? strain : 0`, gain `s x 0.09`, triangle at `260 + s x 900` Hz; each target approached like `setTargetAtTime` (time constants 0.03 / 0.05 s and 0.04 / 0.05 s), per sample. The bandpass is `WebAudioBiquad`, the same formulas as the bake tool. A silent voice costs nothing; both voices cost about 0.18 ms per 60 fps frame. The prototype's `hint` doubling of the scrape is dropped.
- **Heard directly by the player**: `LockpickAudio` plays everything on non-positional `AudioStreamPlayer`s on the Master bus (the project has no bus layout) at the prototype's mix, one-shots on a pool of six players so overlapping cues never cut each other off. Its API (`play(cue)`, `set_scrape(amount, tension)`, `set_strain(strain)`, `stop_all()`) is what the minigame calls. Cues and voice tuning are data: `items/lockpick/audio/sounds.tres` (`LockpickSounds`).
- Guards hear lockpicking only through the noise stimuli the minigame emits; the audio emits no stimuli.

## Alternatives considered

- **Synthesise the one-shots live too**: no files, but a GDScript oscillator bank and envelope scheduler for ten short cues costs CPU at every click and duplicates what a file does for free; the tool keeps the exact formulas reviewable and re-runnable.
- **Bake the continuous voices as loops**: the scrape's centre and the strain's pitch move continuously with the controls; looped files would need pitch-shifting (which also shifts the noise band's width) and crossfades, and would not match the prototype.
- **Hand-made or third-party sounds**: a real sound pass is planned later ([lockpicking.md](../game/lockpicking.md)); for now the user approved the prototype's sounds.

## Consequences

- Re-running the tool reproduces the files byte for byte; changing a cue means editing its table in the tool and re-baking. A real sound pass only replaces files and `sounds.tres` entries.
- Checked against Chrome's OfflineAudioContext on the noise-free parts: sine parts are identical, triangle within -54 dB, sawtooth -30 dB, square -19 to -22 dB (browsers choose how many partials each pitch range keeps; the spectra and levels match, peaks within 5%), and the biquads give Chrome's outputs to 6 decimals. Noise cannot match sample for sample (the prototype uses `Math.random()`), only statistically. Chrome starts the `drop` cue's delayed second blip about one cycle late (its start time is not an exact sample there); the port starts it on time, as the specification says.
- The live strain is a naive (not band-limited) triangle: its harmonics fall off as 1/k², so aliasing is far below audibility at 260-1160 Hz. The scrape's filter coefficients follow the smoothed centre every 32 samples instead of every sample.
- Godot reports one leaked `AudioStreamGeneratorPlayback` when the game quits while the voices' player is still playing (a bare generator player does the same); freeing the node first avoids it.
- Tests: `tests/items/lockpick/audio/` (the baked files, the biquad against the tool's vectors, the voices' pitch, level and smoothing, the node's API).
