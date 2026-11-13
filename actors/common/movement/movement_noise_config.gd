class_name MovementNoiseConfig
extends Resource
## Tuning for a character's MovementNoise (footsteps and landings). Values live in the actor's
## `<actor>_movement_noise.tres`; the script only declares them. Loudness in audible metres
## (ADR 0032), distances in metres, speeds in m/s.

@export_group("Footsteps")
## Ground distance between footsteps per stance.
@export var walk_stride: float
@export var sprint_stride: float
@export var crouch_stride: float
## Footstep loudness per stance, before the surface multiplier.
@export var walk_loudness: float
@export var sprint_loudness: float
@export var crouch_loudness: float

@export_group("Landing")
## Touchdowns slower than this (downward m/s) make no landing noise.
@export var landing_min_impact_speed: float
## Landing loudness = landing_loudness x clamp(impact / reference, 1, max factor) x surface.
@export var landing_loudness: float
@export var landing_reference_speed: float
@export var landing_max_factor: float

@export_group("Surfaces")
## Surface multipliers and sounds; the floor's surface is Surface.of() its collider (`surface`
## metadata, else the entity's `material.*` tag; ADR 0033, ADR 0138).
@export var surfaces: SurfaceTable
## Collision layers of the downward probe that reads the floor's surface: world and objects (a prop
## stood on reads its material tag).
@export_flags_3d_physics var surface_probe_mask: int = 9

@export_group("Audio")
## Loudness that plays at 0 dB; louder or quieter noises scale 10 dB per decade, clamped.
@export var audio_reference_loudness: float
@export var audio_min_db: float
@export var audio_max_db: float
