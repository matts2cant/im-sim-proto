class_name DoorOpener
extends Node
## Component of a navigating character (ADR 0078): opens doors as its path reaches them. Every tick
## while it walks, the next `lookahead` metres of its NavigationAgent3D path (from where it stands)
## are checked against the doorways of the doors near it (group Door.GROUP, Door.crosses()); a
## closed door on the way is asked to open for it (Door.open_for(): a locked door opens only when
## one of its locks lets the character through, e.g. a keycard it holds or an `access.<id>` tag).
## It also puts the agent on its navigation layers: AccessLayers.WALK plus one layer per
## `access.<id>` tag, so paths cross locked doors only for characters with the access. Doors it
## opened stay open (nobody closes them behind).

@export var entity_path: NodePath = ^".."
## Metres of path ahead in which a door opens (a 0.6 s door clears for a 5 m/s run at 3 m).
@export var lookahead: float = 3.5
## Points are raised by this much so a floor-level path passes through the doorway volume.
@export var path_lift: float = 0.5

var walker: NavWalker
var _tags: Tags


func _ready() -> void:
	walker = get_node_or_null(entity_path) as NavWalker
	_tags = ActorState.tags_of(walker)
	if _tags != null:
		_tags.container.changed.connect(_on_tag_changed)
	update_layers.call_deferred()


static func of(node: Node) -> DoorOpener:
	if node == null:
		return null
	for child in node.get_children():
		if child is DoorOpener:
			return child as DoorOpener
	return null


## Puts the agent on WALK plus the layers of its `access.<id>` tags.
func update_layers() -> void:
	if walker == null or walker.agent == null:
		return
	walker.agent.navigation_layers = AccessLayers.agent_layers(_tags.container if _tags != null else null)


func _physics_process(_delta: float) -> void:
	if walker == null or not walker.is_moving() or not ActorState.can_act(walker):
		return
	var points := path_ahead()
	if points.size() < 2:
		return
	var reach := lookahead + 2.0
	for node in get_tree().get_nodes_in_group(Door.GROUP):
		var door := node as Door
		if door == null or door.is_open() or door.entity == null:
			continue
		if door.entity.global_position.distance_to(walker.global_position) > reach:
			continue
		if door.crosses(points):
			door.open_for(walker)


## The next `lookahead` metres of the walker's path from where it stands (raised by `path_lift`).
func path_ahead() -> PackedVector3Array:
	var points := PackedVector3Array()
	var lift := Vector3.UP * path_lift
	var from := walker.global_position + lift
	points.append(from)
	var agent := walker.agent
	if agent == null:
		return points
	var path := agent.get_current_navigation_path()
	var left := lookahead
	for i in range(agent.get_current_navigation_path_index(), path.size()):
		var to := path[i] + lift
		var length := from.distance_to(to)
		if length >= left:
			points.append(from + (to - from).normalized() * left)
			break
		points.append(to)
		left -= length
		from = to
	return points


func _on_tag_changed(tag: StringName, _added: bool) -> void:
	if String(tag).begins_with(AccessLayers.ACCESS_TAG_PREFIX):
		update_layers()
