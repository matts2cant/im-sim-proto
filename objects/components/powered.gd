class_name Powered
extends Node
## Component: something that runs on a power circuit (ADR 0066), e.g. a lamp. While off, every node
## in `targets` is hidden (a Light3D, a glowing bulb mesh), so a hidden light lights nothing
## (LightExposure skips it). The entity opts into circuit `circuit` by this property alone: it
## joins group `circuit.<circuit>`, through which a CircuitBreaker (or any other switch) reaches
## it with Powered.set_circuit(). Nothing refers to specific lamps. Saveable (`on`).

signal power_changed(on: bool)

const GROUP: StringName = &"powered"
const CIRCUIT_GROUP_PREFIX := "circuit."

## Circuit id, e.g. `perception_lab`; empty: on no circuit (always on).
@export var circuit: StringName = &""
## Nodes shown while powered and hidden while not; empty: every Light3D under the entity.
@export var targets: Array[NodePath] = []
@export var on: bool = true:
	set(value):
		if value == on:
			return
		on = value
		if is_node_ready():
			_apply()
			power_changed.emit(on)
@export var entity_path: NodePath = ^".."

var entity: Node


func _ready() -> void:
	add_to_group(GROUP)
	add_to_group(&"saveable")
	if not circuit.is_empty():
		add_to_group(group_for(circuit))
	entity = get_node_or_null(entity_path)
	_apply()


static func of(node: Node) -> Powered:
	if node == null:
		return null
	for child in node.get_children():
		if child is Powered:
			return child as Powered
	return null


## The group of the Powered nodes on circuit `circuit_id`.
static func group_for(circuit_id: StringName) -> StringName:
	return StringName(CIRCUIT_GROUP_PREFIX + String(circuit_id))


## Switches every Powered on `circuit_id` in `tree`; returns how many there are.
static func set_circuit(tree: SceneTree, circuit_id: StringName, value: bool) -> int:
	var count := 0
	for node in tree.get_nodes_in_group(group_for(circuit_id)):
		var powered := node as Powered
		if powered != null and not powered.is_queued_for_deletion():
			powered.on = value
			count += 1
	return count


## The nodes this switches (resolved `targets`, or every Light3D under the entity).
func target_nodes() -> Array[Node3D]:
	var nodes: Array[Node3D] = []
	if targets.is_empty():
		if entity != null:
			for light in entity.find_children("*", "Light3D", true, false):
				nodes.append(light as Node3D)
		return nodes
	for path in targets:
		var node := get_node_or_null(path) as Node3D
		if node != null:
			nodes.append(node)
	return nodes


func _apply() -> void:
	for node in target_nodes():
		node.visible = on


func save_state() -> Dictionary:
	return {"on": on}


func load_state(data: Dictionary) -> void:
	on = bool(data.get("on", on))
