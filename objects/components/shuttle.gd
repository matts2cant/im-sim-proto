class_name Shuttle
extends Node
## Component (ADR 0125): moves its entity (the parent Node3D) back and forth along a straight line
## at a steady speed: `travel` metres centred on where it starts, along `axis` in the entity's
## parent's frame. It stops while the entity cannot act (ActorState: dead or unconscious, so a
## downed training dummy lies still) and carries on from there once it can. The shooting range's
## walking dummy is a training dummy with a Shuttle. Saveable: where it is on the line and which way
## it is going.

## Direction of travel in the entity's parent's frame (normalised on ready).
@export var axis: Vector3 = Vector3.RIGHT
## Length of the line (metres), centred on the start.
@export_range(0.0, 50.0, 0.1) var travel: float = 4.0
## Metres per second (1.5: a guard's walk).
@export_range(0.0, 10.0, 0.1) var speed: float = 1.5
@export var entity_path: NodePath = ^".."

var entity: Node3D
## Signed distance from the centre along `axis`.
var offset: float = 0.0
## +1 or -1: the way it moves now.
var direction: float = 1.0

var _centre: Vector3


func _ready() -> void:
	add_to_group(LevelSnapshot.GROUP)
	entity = Entities.of_component(self, entity_path) as Node3D
	if entity == null:
		set_physics_process(false)
		return
	axis = axis.normalized()
	_centre = entity.position


func _physics_process(delta: float) -> void:
	if not ActorState.can_act(entity):
		return
	step(delta)


## Advances `delta` seconds (turning at either end) and places the entity.
func step(delta: float) -> void:
	var half := travel * 0.5
	var left := speed * delta
	while left > 0.0 and half > 0.0:
		var room := (half - offset) if direction > 0.0 else (offset + half)
		if left < room:
			offset += direction * left
			left = 0.0
		else:
			offset += direction * room
			left -= room
			direction = -direction
	_place()


## The line's centre in the entity's parent's frame.
func centre() -> Vector3:
	return _centre


func save_state() -> Dictionary:
	return {"offset": offset, "direction": direction}


func load_state(data: Dictionary) -> void:
	offset = float(data.get("offset", 0.0))
	direction = 1.0 if float(data.get("direction", 1.0)) >= 0.0 else -1.0
	_place()


func _place() -> void:
	if entity != null:
		entity.position = _centre + axis * offset
