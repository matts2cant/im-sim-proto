class_name FlammableConfig
extends Resource
## Tuning for a Flammable (ADR 0046). Values live in each object's `*_fire.tres`.
## Heat is in "perceived fire intensity" units; a fire pulse adds its perceived intensity.

@export_group("Ignition")
## Heat at which the object ignites.
@export var ignition_threshold: float
## Heat lost per second while not burning.
@export var cool_rate: float

@export_group("Burning")
## Seconds of burning before the object burns out (ignored when `permanent`).
@export var fuel_seconds: float
## A permanent fire (brazier) never runs out of fuel.
@export var permanent: bool = false
## Intensity and radius of the `fire` and `damage.fire` pulses (RADIUS, LINE_OF_SIGHT).
@export var intensity: float
@export var radius: float
## Seconds between pulses.
@export var pulse_interval: float
## Loudness (audible metres) of the crackle `noise` emitted with every pulse.
@export var noise_loudness: float

@export_group("Effects")
## Light range = fire radius x this.
@export var light_range_factor: float
@export var light_energy: float
## Relative flicker amplitude of the light energy.
@export var light_flicker: float
## Particle emission sphere radius in metres (the visible flame size).
@export var flame_size: float
@export var crackle: AudioStream
@export var crackle_volume_db: float
