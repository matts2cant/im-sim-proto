class_name LockpickSounds
extends Resource
## The lockpicking minigame's sounds as data: one-shot cues and the tuning of the two continuous
## voices. Defaults reproduce the HTML prototype's WebAudio synth
## (`design/prototypes/lockpicking_bench.html`, "Audio (placeholder synth)";
## [ADR 0108](../../../design/decisions/0108-lockpick-sounds.md)).

## Cue -> stream. Noisy cues map to an AudioStreamRandomizer over their baked variants.
@export var cues: Dictionary[StringName, AudioStream] = {}

@export_group("Mix")
## The prototype's master gain (also baked into the one-shots).
@export var master_gain: float = 0.7
@export var sample_rate: float = 44100.0

@export_group("Scrape")
## Gain per unit of scraping (0..1).
@export var scrape_gain: float = 0.16
## Bandpass centre: base + tension (0..1) x per_tension, Hz.
@export var scrape_frequency: float = 2000.0
@export var scrape_frequency_per_tension: float = 1600.0
@export var scrape_q: float = 3.0
## setTargetAtTime time constants, seconds.
@export var scrape_gain_time: float = 0.03
@export var scrape_frequency_time: float = 0.05
## The filter's frequency before the first target (the prototype's initial 2600 Hz).
@export var scrape_start_frequency: float = 2600.0

@export_group("Strain")
## Strain at or below this is silent.
@export var strain_threshold: float = 0.12
## Gain per unit of strain.
@export var strain_gain: float = 0.09
## Triangle pitch: base + strain x per_strain, Hz.
@export var strain_frequency: float = 260.0
@export var strain_frequency_per_strain: float = 900.0
@export var strain_gain_time: float = 0.04
@export var strain_frequency_time: float = 0.05
## The oscillator's frequency before the first target (the prototype's initial 300 Hz).
@export var strain_start_frequency: float = 300.0
