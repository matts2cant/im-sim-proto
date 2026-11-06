class_name PlayerConfig
extends Resource
## Tuning for the first-person player controller. Movement noise, knockback and body tuning live in
## their own components' .tres (player_movement_noise.tres, player_knockback.tres, player_body.tres).
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

@export_group("Interact")
## Reach of the Interactor ray from the eyes (E: pick up, use, carry; ADR 0051).
@export var interact_reach: float

@export_group("Carry")
## Reach of the pick-up look ray from the eyes. The mass limit is the `carry_mass_limit` attribute.
@export var carry_reach: float
## Hold point (ADR 0053): the centre sits (base + largest half-extent) along the view from the eyes
## and (drop + half-extent) lower on the screen. A release aims at least capsule radius +
## half-extent + clearance out from the player's axis.
@export var hold_base_distance: float
@export var hold_drop: float
@export var hold_clearance: float
## Seconds the object takes to move to the hold point and turn upright after pick-up.
@export var hold_turn_time: float
## See-through amount of the held object's meshes (0 opaque, 1 invisible).
@export var held_transparency: float
## Release: the shape is cast from the chest (this far below the eyes, on the player's axis) to the
## hold point and placed this many metres short of the first contact.
@export var release_start_drop: float
@export var release_margin: float
## Throw: impulse along the view (N s); speed = min(max speed, impulse / mass).
@export var throw_impulse: float
@export var throw_max_speed: float
## Carrying at least this mass (kg) multiplies the move speed by `heavy_carry_speed_factor`.
@export var heavy_carry_mass: float
@export var heavy_carry_speed_factor: float

@export_group("Physics props")
## Mass (kg) whose weight (x engine gravity) presses on the rigid bodies the player stands on
## (ADR 0054: props do not collide with the player's kinematic body in the solver).
@export var body_mass: float
## The weight on one body is at most this many times that body's own weight (a small crate gets
## 4 x 98 = 392 N, a 0.5 kg bottle 20 N): large mass ratios destabilise the solver.
@export var weight_max_ratio: float
## Most force (N) the player pushes rigid bodies with by walking into them, shared between them.
## A prop on the floor needs more than 0.5 x mass x 9.8 N to slide (prop friction 0.5): 250 N
## moves a small (10 kg, 49 N) or metal (25 kg, 123 N) crate, not a large one (60 kg, 294 N).
@export var push_force: float
## Pushed bodies are not sped up past this (m/s): pushing slows the player down, and a pushed
## crate stays under ImpactSettings.min_speed (2.5), so shoving one into a wall makes no impact.
@export var push_max_speed: float
## A rigid body counts as walked into within this distance (m) ahead of the capsule, and as stood
## on within this distance below the feet.
@export var push_probe: float
