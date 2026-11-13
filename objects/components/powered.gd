class_name Powered
extends Node
## Component: something that runs on a power circuit (ADR 0066), e.g. a lamp. While off, every node
## in `targets` is hidden (a Light3D, a glowing bulb mesh), so a hidden light lights nothing
## (LightExposure skips it). The entity opts into circuit `circuit` by this property alone: it
## joins group `circuit.<circuit>`, through which a CircuitBreaker (or any other switch) reaches
## it with Powered.set_circuit(). Nothing refers to specific lamps.
## Outages (ADR 0131, M14b): take_emp() cuts the power for some seconds whatever the circuit says
## (an EMP, through the `disrupted_by_emp` receptron its _ready adds to the entity's receiver:
## EmpEffect); it comes back by itself when the outage ends, unless the circuit was switched off
## meanwhile. is_on() is the power the entity has: `on` (the circuit's switch) and no outage.
## `power_changed` reports changes of is_on(). Saveable (`on`, `outage`).

signal power_changed(on: bool)

const GROUP: StringName = &"powered"
const CIRCUIT_GROUP_PREFIX := "circuit."

## Circuit id, e.g. `perception_lab`; empty: on no circuit (always on).
@export var circuit: StringName = &""
## Nodes shown while powered and hidden while not; empty: every Light3D under the entity.
@export var targets: Array[NodePath] = []
## The circuit's switch (a CircuitBreaker sets it).
@export var on: bool = true:
	set(value):
		if value == on:
			return
		on = value
		if is_node_ready():
			_changed()
@export var entity_path: NodePath = ^".."

var entity: Node
## Seconds of outage left (an EMP); 0: none.
var outage: float = 0.0

var _was_on: bool = true


func _ready() -> void:
	add_to_group(GROUP)
	add_to_group(&"saveable")
	add_to_group(EmpEffect.GROUP)
	if not circuit.is_empty():
		add_to_group(group_for(circuit))
	entity = get_node_or_null(entity_path)
	EmpEffect.listen(entity)
	_was_on = is_on()
	set_physics_process(outage > 0.0)
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


## True while it has power: its circuit is on and no outage runs.
func is_on() -> bool:
	return on and outage <= 0.0


## An EMP (EmpEffect): no power for `seconds` (the longer of this and an outage already running).
func take_emp(seconds: float, _cause: Stimulus = null) -> void:
	if seconds <= outage:
		return
	outage = seconds
	set_physics_process(true)
	_changed()


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


func _physics_process(delta: float) -> void:
	outage = maxf(outage - delta, 0.0)
	if outage <= 0.0:
		set_physics_process(false)
		_changed()


# Shows or hides the targets; reports a change of is_on().
func _changed() -> void:
	_apply()
	var now := is_on()
	if now != _was_on:
		_was_on = now
		power_changed.emit(now)


func _apply() -> void:
	var lit := is_on()
	for node in target_nodes():
		node.visible = lit


func save_state() -> Dictionary:
	return {"on": on, "outage": outage}


func load_state(data: Dictionary) -> void:
	outage = maxf(float(data.get("outage", 0.0)), 0.0)
	set_physics_process(outage > 0.0)
	on = bool(data.get("on", on))
	_changed()
