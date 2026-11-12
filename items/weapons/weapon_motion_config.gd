class_name WeaponMotionConfig
extends Resource
## How a weapon's first-person model moves by code (ADR 0120, M13b; no arms or hands), read by
## WeaponMotion: the kick of a shot, the sway that lags mouse turns, the bob while walking, the dip
## of a reload and the raise of a draw (lowered on holstering), plus the camera shake of a shot
## (the player's camera, x the camera motion setting). Distances in metres in the camera's frame,
## angles in degrees. Every number is an @export_range so the shooting range's tuning panel lists
## it (ADR 0125). Melee weapons keep their chop (WeaponData.view_swing_deg): no kick.

@export_group("Kick")
## Peak of one shot's kick: back towards the eye (m), nose up (degrees), roll to a random side.
@export_range(0.0, 0.2, 0.005) var kick_back: float = 0.04
@export_range(0.0, 30.0, 0.5) var kick_pitch_deg: float = 6.0
@export_range(0.0, 15.0, 0.5) var kick_roll_deg: float = 1.5
## Seconds from the shot to the kick's peak; it settles back in about five of them (a critically
## damped spring, so the shots of an automatic weapon stack into a shudder).
@export_range(0.01, 0.2, 0.005) var kick_time: float = 0.035
## Most kicks that stack (automatic fire): the kick never goes past this many single peaks.
@export_range(1.0, 4.0, 0.1) var kick_stack_max: float = 1.5

@export_group("Sway")
## Degrees the model lags behind per degree the view turns (mouse look), up to `sway_max_deg`.
@export_range(0.0, 1.0, 0.01) var sway_per_deg: float = 0.2
@export_range(0.0, 10.0, 0.1) var sway_max_deg: float = 3.0
## Metres the model shifts per degree of lag (it trails sideways as well as turning).
@export_range(0.0, 0.01, 0.0005) var sway_shift: float = 0.003
## Time constant (s) of the lag's return to the rest pose.
@export_range(0.01, 0.5, 0.01) var sway_return_time: float = 0.09

@export_group("Bob")
## Bob at `bob_reference_speed` (walking): metres down at each footstep, metres side to side.
@export_range(0.0, 0.05, 0.001) var bob_height: float = 0.01
@export_range(0.0, 0.05, 0.001) var bob_side: float = 0.008
## Metres walked per bob cycle (two footsteps: one side swing, two dips).
@export_range(0.5, 8.0, 0.1) var bob_stride: float = 4.0
## Ground speed (m/s) at which the bob is `bob_height` / `bob_side`; it scales with speed up to
## `bob_max_scale` (sprinting).
@export_range(0.5, 10.0, 0.1) var bob_reference_speed: float = 4.0
@export_range(1.0, 3.0, 0.05) var bob_max_scale: float = 1.5
## The bob x this while crouched.
@export_range(0.0, 1.0, 0.05) var bob_crouch_scale: float = 0.6
## Time constant (s) of the bob's size following the speed (it fades out on stopping).
@export_range(0.01, 0.5, 0.01) var bob_ease_time: float = 0.12

@export_group("Reload")
## At the bottom of the reload dip: metres down, nose down (degrees), roll inwards (degrees).
@export_range(0.0, 0.6, 0.01) var reload_drop: float = 0.3
@export_range(0.0, 80.0, 1.0) var reload_pitch_deg: float = 35.0
@export_range(0.0, 60.0, 1.0) var reload_roll_deg: float = 20.0
## Share of the reload time the dip takes going down (and again coming back up).
@export_range(0.05, 0.5, 0.01) var reload_ease_share: float = 0.25

@export_group("Draw")
## Seconds to raise the weapon into view on drawing it and to lower it on holstering.
@export_range(0.05, 1.0, 0.01) var draw_time: float = 0.3
@export_range(0.05, 1.0, 0.01) var holster_time: float = 0.2
## Start of the raise (end of the lowering): metres down, nose down (degrees).
@export_range(0.0, 0.6, 0.01) var draw_drop: float = 0.3
@export_range(0.0, 80.0, 1.0) var draw_pitch_deg: float = 40.0

@export_group("Camera shake")
## Peak camera shake of a shot (degrees; x the camera motion setting), dying out over `shake_time`
## seconds. Shots and the crosshair do not follow it.
@export_range(0.0, 3.0, 0.05) var shake_deg: float = 0.2
@export_range(0.02, 0.6, 0.01) var shake_time: float = 0.15
