class_name SecurityCamera
extends Node
## Component (ADR 0079): a security camera's behaviour, beside the entity's Device. Nothing here is
## camera-specific beyond the parts it turns: any entity with a Device, a turning node (`pivot_path`)
## carrying a PerceptionSensor and this component watches and reports the same way.
## - Vision: its PerceptionSensor (child of the turning `Eye`, eye height 0) with its own
##   PerceptionConfig (`security_camera_perception.tres`: hostile `actor.player`, no hidden tags so
##   Cloak does not hide you, focus only); light, distance and line of sight are the guards' rules.
## - Sweep (CameraModel): turns around its rest yaw (the pivot's yaw at load) and holds at each end;
##   while it sees a target the sweep waits, so it keeps the target in view.
## - Detection (SightMeter): the meter rises by the sighting's gain per second and falls when nothing
##   is seen; at 1.0 it reports an incident at the target's position (Device.report_incident()) to
##   every alarm controller it reaches, beeps (noise `beep_loudness`), and reports nothing more until
##   no target has been seen for `report_cooldown` seconds.
## - Status lamp (`lamp_path`, a mesh): green idle, amber above `amber_threshold`, red while detected;
##   off while blind.
## - Remote commands (receptrons -> DeviceActionEffect -> Device.action_received): `command.disable`
##   / `command.enable` (blind, lamp off), `command.stop_sweep`, `command.resume_sweep`,
##   `command.pan_left`, `command.pan_right` (one pan step, clamped to the sweep range).
## - Unpowered or broken (its Device down): blind, lamp off, the sweep stops where it is.
## EventLog: `camera.detected {camera, target, point, controllers}`. Saveable.

@export var config: SecurityCameraConfig
## The node turned by the sweep (yaw about its local Y).
@export var pivot_path: NodePath = ^"../Pivot"
## Mesh of the status lamp (its material is made per camera).
@export var lamp_path: NodePath = ^"../Pivot/Tilt/Lamp"
@export var sensor_path: NodePath = ^"../Pivot/Tilt/Eye/PerceptionSensor"
## AudioStreamPlayer3D for the beep; optional.
@export var sound_path: NodePath = ^"../Sound"
@export var entity_path: NodePath = ^".."
## Starts blind (a `command.enable` turns it on).
@export var start_disabled: bool = false

var entity: Node3D
var device: Device
var sensor: PerceptionSensor
var model: CameraModel
var meter: SightMeter
## Blinded by `command.disable` (until `command.enable`).
var disabled: bool = false
## What it saw this tick (null: nothing, or blind).
var last_sighting: PerceptionSensor.Sighting

var _pivot: Node3D
var _rest_yaw: float = 0.0
var _lamp: MeshInstance3D
var _lamp_material: StandardMaterial3D


func _ready() -> void:
	add_to_group(&"saveable")
	entity = get_node_or_null(entity_path) as Node3D
	device = Device.of(entity)
	_pivot = get_node_or_null(pivot_path) as Node3D
	sensor = get_node_or_null(sensor_path) as PerceptionSensor
	if device == null or config == null or _pivot == null or sensor == null:
		push_warning("SecurityCamera %s: needs a Device sibling, a config, a pivot and a sensor" % get_path())
		set_physics_process(false)
		return
	model = CameraModel.new(config)
	meter = SightMeter.new(config.meter_decay, config.report_cooldown)
	disabled = start_disabled
	_rest_yaw = _pivot.rotation.y
	_lamp = get_node_or_null(lamp_path) as MeshInstance3D
	if _lamp != null:
		_lamp_material = StandardMaterial3D.new()
		_lamp_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_lamp.material_override = _lamp_material
	var sound := get_node_or_null(sound_path) as AudioStreamPlayer3D
	if sound != null and sound.stream == null:
		sound.stream = PlaceholderBeep.tone(config.beep_hz, 0.25)
	device.action_received.connect(_on_action)
	device.state_changed.connect(_on_device_state_changed)
	_apply_pose()
	_update_lamp()


## The SecurityCamera child of `node`, or null.
static func of(node: Node) -> SecurityCamera:
	if node == null:
		return null
	for child in node.get_children():
		if child is SecurityCamera:
			return child as SecurityCamera
	return null


## Not disabled, powered and unbroken.
func is_watching() -> bool:
	return not disabled and device != null and device.is_up()


## Current turn from the rest yaw, degrees (positive: left).
func yaw() -> float:
	return model.yaw


func _physics_process(delta: float) -> void:
	if not is_watching():
		last_sighting = null
		return
	last_sighting = sensor.look()
	model.step(delta, last_sighting != null)
	_apply_pose()
	if meter.step(delta, last_sighting.gain if last_sighting != null else 0.0):
		_detected(last_sighting)
	_update_lamp()


func _detected(sighting: PerceptionSensor.Sighting) -> void:
	var point := sighting.target.global_position
	var told := device.report_incident(point)
	StimulusSystem.emit(Stimulus.make_noise(config.beep_loudness, entity.global_position, entity))
	var sound := get_node_or_null(sound_path) as AudioStreamPlayer3D
	if sound != null and sound.is_inside_tree():
		sound.play()
	var camera_name := String(entity.name)
	var target_name := String(sighting.target.name)
	var data := {"camera": camera_name, "target": target_name, "point": point, "controllers": told}
	EventLog.record(&"camera.detected", camera_name, target_name, data)


func _on_action(action: StringName, _stimulus: Stimulus) -> void:
	match action:
		Device.DISABLE:
			disabled = true
			_blinded()
		Device.ENABLE:
			disabled = false
		Device.STOP_SWEEP:
			model.stop_sweep()
		Device.RESUME_SWEEP:
			model.resume_sweep()
		Device.PAN_LEFT:
			model.pan(1)
		Device.PAN_RIGHT:
			model.pan(-1)
	_apply_pose()
	_update_lamp()


func _on_device_state_changed(up: bool) -> void:
	if not up:
		_blinded()
	_update_lamp()


func _blinded() -> void:
	last_sighting = null
	meter.reset()


func _apply_pose() -> void:
	_pivot.rotation.y = _rest_yaw + deg_to_rad(model.yaw)


func _update_lamp() -> void:
	if _lamp == null:
		return
	_lamp.visible = is_watching()
	var color := config.idle_color
	if meter.detected:
		color = config.detected_color
	elif meter.meter > config.amber_threshold:
		color = config.suspicious_color
	_lamp_material.albedo_color = color


func save_state() -> Dictionary:
	return {"disabled": disabled, "sweep": model.to_dict(), "meter": meter.to_dict()}


func load_state(data: Dictionary) -> void:
	disabled = bool(data.get("disabled", disabled))
	model.from_dict(data.get("sweep", {}) as Dictionary)
	meter.from_dict(data.get("meter", {}) as Dictionary)
	_apply_pose()
	_update_lamp()
