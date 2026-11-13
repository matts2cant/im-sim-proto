class_name Fuse
extends Node
## Component (ADR 0131): once lit, sets off its entity's Explosive (`Explosive.explode()`, the one
## detonation entry) after `time` seconds: a thrown grenade, a mine whose disarming failed (lit for
## 0.5 s). While lit and when `hits_characters` is on, a body entity also collides with characters
## (players, guards) so a thrown grenade bounces off people; props never scan them otherwise
## (PhysicsObject, ADR 0054). EventLog `fuse.lit {object, time}`. Saveable (lit, time left).

## Lit (any source), with the seconds it burns.
signal lit(seconds: float)

@export var time: float = 2.5
## While lit, the body entity also collides with the character layers (bounces off people).
@export var hits_characters: bool = true
@export var entity_path: NodePath = ^".."

var entity: Node3D
## Seconds left while lit, else the full time.
var left: float = 0.0
var is_lit: bool = false


func _ready() -> void:
	add_to_group(&"saveable")
	entity = get_node(entity_path) as Node3D
	left = time


static func of(node: Node) -> Fuse:
	if node == null:
		return null
	for child in node.get_children():
		if child is Fuse:
			return child as Fuse
	return null


## Lights it for `seconds` (negative: `time`); lit again, it keeps the shorter time left.
func light(seconds: float = -1.0) -> void:
	var burn := time if seconds < 0.0 else seconds
	left = minf(left, burn) if is_lit else burn
	is_lit = true
	_collide_with_characters()
	EventLog.record(EventKinds.FUSE_LIT, String(entity.name), "", {"object": String(entity.name), "time": left})
	lit.emit(left)


func _physics_process(delta: float) -> void:
	if not is_lit:
		return
	left -= delta
	if left > 0.0:
		return
	is_lit = false
	left = 0.0
	var explosive := Explosive.of(entity)
	if explosive != null:
		explosive.explode()


func save_state() -> Dictionary:
	return {"lit": is_lit, "left": left}


func load_state(data: Dictionary) -> void:
	is_lit = bool(data.get("lit", is_lit))
	left = float(data.get("left", left))
	if is_lit:
		_collide_with_characters()


func _collide_with_characters() -> void:
	var body := entity as CollisionObject3D
	if hits_characters and body != null:
		body.collision_mask |= PhysicsLayers.CHARACTER_LAYERS
