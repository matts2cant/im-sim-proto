class_name PlayerConfig
extends Resource
## Tuning for the first-person player controller. Movement noise, knockback, body, carry and
## interaction tuning live in their own components' .tres (player_movement_noise.tres,
## player_knockback.tres, player_body.tres, the Carrier's carry.tres, the Interactor's interactor.tres).
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
## Multiplier on the engine gravity, applied to the player only (ADR 0036).
@export var gravity_scale: float
## Jump apex height in metres; the launch speed is derived from the scaled gravity.
@export var jump_apex_height: float

@export_group("Look")
## Radians per screen pixel of mouse motion.
@export var mouse_sensitivity: float
@export var max_pitch_deg: float

@export_group("Mantle")
## Ledge top above the ground the player last stood on (and above the feet).
@export var mantle_min_height: float
@export var mantle_max_height: float
## Horizontal distance from the capsule axis to the ledge face.
@export var mantle_reach: float
@export var mantle_base_duration: float
@export var mantle_duration_per_metre: float

@export_group("Aim")
## Horizontal speed (m/s) above which the aim cone counts as moving.
@export var aim_moving_speed: float
## Airborne this long (s) before the aim counts as jumping/falling (a teleport or a step off a
## kerb does not bloom the cone).
@export var aim_air_grace: float
