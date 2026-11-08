class_name SecurityCameraConfig
extends Resource
## Tuning of a SecurityCamera (ADR 0079): `objects/camera/security_camera.tres`. Its vision (cones,
## gain, hostile and hidden tags) is the PerceptionConfig of its PerceptionSensor
## (`security_camera_perception.tres`). Angles in degrees, from the rest yaw (left positive).

@export_group("Sweep")
## The sweep turns between -sweep_half_angle and +sweep_half_angle around the rest yaw; pan steps are
## clamped to the same range.
@export var sweep_half_angle: float = 40.0
@export var sweep_speed: float = 15.0
## Seconds it holds at each end of the sweep.
@export var sweep_hold: float = 2.0
## One `command.pan_left` / `command.pan_right` turns it this far.
@export var pan_step: float = 15.0

@export_group("Detection")
## Suspicion lost per second while nothing is seen (SightMeter).
@export var meter_decay: float = 0.25
## Seconds a target must stay unseen after a detection before the camera can report again.
@export var report_cooldown: float = 10.0
## The status lamp turns amber above this meter.
@export var amber_threshold: float = 0.3
## Noise (audible metres, PATH) of the beep on a detection.
@export var beep_loudness: float = 8.0
@export var beep_hz: float = 1320.0

@export_group("Status lamp")
@export var idle_color: Color = Color(0.2, 1.0, 0.3)
@export var suspicious_color: Color = Color(1.0, 0.65, 0.1)
@export var detected_color: Color = Color(1.0, 0.1, 0.08)
