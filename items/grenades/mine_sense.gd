class_name MineSense
extends Node
## Component of the player's view (ADR 0131): highlights armed mines (ProximityTrigger.GROUP) within
## its entity's `mine_sense_range` attribute (m; 0 = none: the Demolition skill gives 8 m from
## Advanced), through darkness and smoke (ProximityTrigger.set_highlighted()), checked every
## `check_ticks` physics ticks. Visual only: the highlight is drawn for whoever looks.

const RANGE_ATTRIBUTE: StringName = &"mine_sense_range"

@export var check_ticks: int = 10
@export var entity_path: NodePath = ^".."

var entity: Node3D

var _tick: int = 0


func _ready() -> void:
	entity = get_node(entity_path) as Node3D


func _physics_process(_delta: float) -> void:
	_tick += 1
	if _tick % maxi(check_ticks, 1) == 0:
		refresh()


## Highlights the armed mines in range now, unhighlights the others.
func refresh() -> void:
	var reach := Attributes.read(entity, RANGE_ATTRIBUTE, 0.0)
	var here := entity.global_position
	for node in get_tree().get_nodes_in_group(ProximityTrigger.GROUP):
		var trigger := node as ProximityTrigger
		if trigger == null or not trigger.is_inside_tree():
			continue
		var near := reach > 0.0 and trigger.global_position.distance_to(here) <= reach
		trigger.set_highlighted(near and trigger.is_armed)
