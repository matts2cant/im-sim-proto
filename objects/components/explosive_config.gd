class_name ExplosiveConfig
extends Resource
## Tuning for an Explosive (explosive barrel). Values live in the object's `*_explosive.tres`.

@export_group("Trigger")
## Heat at which it explodes (fire adds its perceived intensity, like Flammable heat).
@export var heat_threshold: float
## Heat lost per second.
@export var cool_rate: float

@export_group("Blast")
## `damage.explosive` (RADIUS, LINE_OF_SIGHT).
@export var damage_intensity: float
@export var damage_radius: float
## `fire` burst (RADIUS, LINE_OF_SIGHT): ignites what it reaches hot enough.
@export var fire_intensity: float
@export var fire_radius: float
## `noise` (PATH), audible metres.
@export var noise_loudness: float
## Radial impulse (N s) on physics objects at the centre, falling off linearly to 0 at the radius.
@export var impulse: float
@export var impulse_radius: float

@export_group("Effects")
@export var sound: AudioStream
@export var sound_volume_db: float
@export var light_range: float
@export var light_energy: float
