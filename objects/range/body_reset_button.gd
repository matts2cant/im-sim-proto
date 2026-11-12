class_name BodyResetButton
extends Usable
## Component (ADR 0125): pressing it (E) stands every downed body back up: each entity inside
## `scope_path` carrying `required_tag` whose BodyParts is dead or unconscious gets BodyParts.reset()
## (full health, conscious; a training dummy's pose follows its body). Bodies still up are left
## alone. EventLog: `range.bodies_reset {by, count}`.

## Only entities under this node count (the room).
@export var scope_path: NodePath = ^"../.."
## Only entities with this tag (hierarchical) count.
@export var required_tag: StringName = &"actor.dummy"
@export var label: String = "dummies"


func _ready() -> void:
	verb = "reset"


func target_name() -> String:
	return label


func use(user: Node) -> bool:
	var count := reset_downed()
	var by := String(user.name) if user != null else ""
	EventLog.record(&"range.bodies_reset", by, "", {"by": by, "count": count})
	used.emit(user)
	return true


## Resets every downed body in scope; returns how many.
func reset_downed() -> int:
	var scope := get_node_or_null(scope_path)
	if scope == null:
		return 0
	var count := 0
	for node in get_tree().get_nodes_in_group(Tags.GROUP):
		var tags := node as Tags
		var entity := tags.get_parent()
		if entity == null or not scope.is_ancestor_of(entity) or not tags.has(required_tag):
			continue
		for child in entity.get_children():
			var body := child as BodyParts
			if body != null and (body.is_dead() or body.is_unconscious()):
				body.reset()
				count += 1
	return count
