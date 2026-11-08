class_name RadioBaseStation
extends Node
## Component (ADR 0075, ADR 0077): the radio base station's behaviour, beside the entity's Device.
## On `command.broadcast` (from an alarm controller that reaches it; origin = the incident) it
## emits a dispatch: an `alert.dispatch` STRAIGHT RADIUS stimulus of `dispatch_range` metres from
## the station (walls do not matter) whose about_point is the incident. Characters with the
## `heard_dispatch` receptron (requires `equipment.radio`) search there. The command arrives
## through its receptron (DeviceActionEffect, blocked while unpowered or broken).
## EventLog: `radio.dispatch {station, point, range}`.

@export var config: RadioBaseStationConfig
@export var entity_path: NodePath = ^".."

var entity: Node3D
var device: Device


func _ready() -> void:
	entity = get_node_or_null(entity_path) as Node3D
	device = Device.of(entity)
	if device == null or config == null:
		push_warning("RadioBaseStation %s: needs a Device sibling and a config" % get_path())
		return
	device.action_received.connect(_on_action)


## Dispatches every radio in range to search at `at`.
func dispatch(at: Vector3) -> void:
	var origin := entity.global_position
	var stimulus := Stimulus.make_radius(config.dispatch_type, 1.0, origin, config.dispatch_range, entity)
	stimulus.about_point = at
	var station := String(entity.name)
	EventLog.record(&"radio.dispatch", station, "", {"station": station, "point": at, "range": config.dispatch_range})
	StimulusSystem.emit(stimulus)


func _on_action(action: StringName, stimulus: Stimulus) -> void:
	if action == Device.BROADCAST:
		dispatch(stimulus.origin)
