class_name RadioBaseStation
extends Node
## Component (ADR 0075, ADR 0077): the radio base station's behaviour, beside the entity's Device.
## On `command.broadcast` (from an alarm controller that reaches it; origin = the incident) it
## emits a dispatch: an `alert.dispatch` STRAIGHT RADIUS stimulus of `dispatch_range` metres from
## the station (walls do not matter) whose about_point is the incident. Characters with the
## `heard_dispatch` receptron (requires `equipment.radio`) search there. The command arrives
## through its receptron (DeviceActionEffect, blocked while unpowered or broken).
## Security screens (ADR 0083): device_status() says "broadcasting" for `broadcast_shown` seconds
## after a dispatch, else "idle" (nothing while switched off).
## Switched off by a remote `command.disable` (its DeviceSwitch, M12a) it ignores broadcasts until
## `command.enable`.
## EventLog: `radio.dispatch {station, point, range}`.

## Alarm controller -> radio base station: broadcast the incident at the stimulus origin.
const BROADCAST: StringName = &"command.broadcast"
const BROADCASTING: StatusWord = preload("res://objects/devices/status_words/broadcasting.tres")

@export var config: RadioBaseStationConfig
@export var entity_path: NodePath = ^".."

var entity: Node3D
var device: Device
## Seconds it still shows as broadcasting.
var broadcast_left: float = 0.0


func _ready() -> void:
	entity = get_node_or_null(entity_path) as Node3D
	device = Device.of(entity)
	if device == null or config == null:
		push_warning("RadioBaseStation %s: needs a Device sibling and a config" % get_path())
		set_physics_process(false)
		return
	device.action_received.connect(_on_action)


## Status words for security screens (DeviceStatus): broadcasting / idle.
func device_status() -> Array[StatusWord]:
	if not DeviceSwitch.is_enabled(entity):
		return [] as Array[StatusWord]
	return [BROADCASTING if broadcast_left > 0.0 else DeviceStatus.IDLE] as Array[StatusWord]


## Its command (device-to-device traffic: screens' tables leave it out), while switched on.
func device_commands() -> Array[StringName]:
	if not DeviceSwitch.is_enabled(entity):
		return [] as Array[StringName]
	return [BROADCAST] as Array[StringName]


func _physics_process(delta: float) -> void:
	broadcast_left = maxf(broadcast_left - delta, 0.0)


## Dispatches every radio in range to search at `at`.
func dispatch(at: Vector3) -> void:
	var origin := entity.global_position
	var stimulus := Stimulus.make_radius(config.dispatch_type, 1.0, origin, config.dispatch_range, entity)
	stimulus.about_point = at
	broadcast_left = config.broadcast_shown
	var station := EntityNames.log_name(entity)
	EventLog.record(
		EventKinds.RADIO_DISPATCH, station, "", {"station": station, "point": at, "range": config.dispatch_range}
	)
	StimulusSystem.emit(stimulus)


func _on_action(action: StringName, stimulus: Stimulus) -> void:
	if action == RadioBaseStation.BROADCAST and DeviceSwitch.is_enabled(entity):
		dispatch(stimulus.origin)
