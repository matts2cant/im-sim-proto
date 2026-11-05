class_name PlayerConfig
extends Resource
## Tuning for the first-person player controller and its movement noise.
## The values live in player_config.tres; the script only declares them.
## Distances in metres, speeds in m/s, loudness in audible metres (ADR 0032).

@export_group("Body")
@export var capsule_radius: float
@export var standing_height: float
@export var crouched_height: float
@export var standing_eye_height: float
@export var crouched_eye_height: float
## Seconds the camera takes to move between standing and crouched eye height.
@export var eye_transition_time: float
@export var max_slope_deg: float
## Below this height the player is put back at its spawn point (fell out of the level).
@export var fall_respawn_height: float

@export_group("Movement")
@export var walk_speed: float
@export var sprint_speed: float
@export var crouch_speed: float
## Sprint only applies while the move input is within this angle of straight ahead.
@export var sprint_max_angle_deg: float
@export var ground_acceleration: float
@export var ground_deceleration: float
## Fraction of ground acceleration available in the air.
@export var air_control: float
## Jump apex height in metres; the launch speed is derived from gravity.
@export var jump_apex_height: float

@export_group("Look")
## Radians per screen pixel of mouse motion.
@export var mouse_sensitivity: float
@export var max_pitch_deg: float

@export_group("Mantle")
## Ledge top above the feet.
@export var mantle_min_height: float
@export var mantle_max_height: float
## Horizontal distance from the capsule axis to the ledge face.
@export var mantle_reach: float
@export var mantle_base_duration: float
@export var mantle_duration_per_metre: float

@export_group("Noise")
## Ground distance between footsteps per movement mode.
@export var walk_stride: float
@export var sprint_stride: float
@export var crouch_stride: float
## Footstep loudness (audible metres) per movement mode, before the surface multiplier.
@export var walk_loudness: float
@export var sprint_loudness: float
@export var crouch_loudness: float
## Touchdowns slower than this (downward m/s) make no landing noise.
@export var landing_min_impact_speed: float
## Landing loudness = walk_loudness x clamp(impact / reference, 1, max factor) x surface.
@export var landing_reference_speed: float
@export var landing_max_factor: float
@export var surfaces: SurfaceTable

@export_group("Audio")
## Loudness that plays at 0 dB; louder or quieter noises scale 10 dB per decade, clamped.
@export var audio_reference_loudness: float
@export var audio_min_db: float
@export var audio_max_db: float
