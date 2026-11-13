class_name BodyResetButton
extends Usable
## Component (ADR 0125): pressing it (E) stands every downed body back up: each entity inside
## `scope_path` carrying `required_tag` that cannot act (ActorState: `state.dead` or
## `state.unconscious`, whatever added them) gets a `restore` CONTACT stimulus from the user, right
## away; its `restore` receptron does the rest (RestoreEffect: full health, conscious; a training
## dummy's pose follows its tags). Bodies still up, and entities without the receptron, are left
## alone. EventLog: `range.bodies_reset {by, count}` (count: the bodies that reacted).

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
	var count := reset_downed(user)
	var by := String(user.name) if user != null else ""
	EventLog.record(&"range.bodies_reset", by, "", {"by": by, "count": count})
	used.emit(user)
	return true


## Restores every downed body in scope (`by`: the stimulus source, else this button's entity);
## returns how many reacted.
func reset_downed(by: Node = null) -> int:
	var scope := get_node_or_null(scope_path)
	if scope == null:
		return 0
	var source: Node = by if by != null else get_parent()
	var count := 0
	for node in get_tree().get_nodes_in_group(Tags.GROUP):
		var tags := node as Tags
		var entity := tags.get_parent()
		if entity == null or not scope.is_ancestor_of(entity) or not tags.has(required_tag):
			continue
		if ActorState.can_act(entity):
			continue
		var stimulus := Stimulus.make_contact(RestoreEffect.STIMULUS, 1.0, entity, source)
		if not StimulusSystem.would_affect(stimulus):
			continue
		StimulusSystem.emit_now(stimulus)
		count += 1
	return count
