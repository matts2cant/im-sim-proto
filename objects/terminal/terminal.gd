class_name Terminal
extends Node
## LEGACY (M12a, ADR 0114): the security terminal is gone (computers replace it: objects/computer/).
## What is left is only the data source of the old network map (ADR 0083, 0099) so that the map's
## files (ui/terminal/network_graph.gd, network_layout.gd, network_view.gd, which the deck's Map
## takes over) and their tests still compile until the deck replaces them. No scene uses it. Delete
## it (with terminal_config.gd, terminal.tres and ui/terminal/terminal_style.gd) once the deck's Map
## no longer needs it.
## devices() gives every device its entity's cables join it to, up or down (DeviceGraph.component),
## its own row first: online when reached, its status words (DeviceStatus), whether it is disabled,
## has a view, and, when online, the commands of the config's table it accepts. cables() gives the
## links between them.

@export var config: TerminalConfig
@export var entity_path: NodePath = ^".."

var entity: Node3D
var device: Device


## One device of the terminal's network.
class Row:
	extends RefCounted
	var device: Device
	var name: String
	var online: bool = false
	var status: PackedStringArray
	var disabled: bool = false
	var commands: Array[StringName] = []
	var has_view: bool = false
	var is_self: bool = false

	func is_online() -> bool:
		return online

	## Its entity's world position (zero once freed).
	func position() -> Vector3:
		return device.entity.global_position if is_instance_valid(device.entity) else Vector3.ZERO


func _ready() -> void:
	entity = get_node_or_null(entity_path) as Node3D
	device = Device.of(entity)


func is_up() -> bool:
	return device != null and device.is_up()


## Every device on the entity's physical network (its own row first, then breadth-first). Empty
## while it is down.
func devices() -> Array[Row]:
	var rows: Array[Row] = []
	if not is_up():
		return rows
	var graph := Device.graph(get_tree())
	var own_id := device.get_instance_id()
	var ids := PackedInt64Array([own_id])
	ids.append_array(graph.component(own_id))
	var reached := graph.reachable(own_id)
	for id in ids:
		var other := instance_from_id(id) as Device
		if other == null or not is_instance_valid(other.entity):
			continue
		var row := Row.new()
		row.device = other
		row.name = display_name(other)
		row.is_self = id == own_id
		row.online = row.is_self or reached.has(id)
		row.status = DeviceStatus.of(other.entity, row.online)
		row.disabled = row.online and DeviceStatus.is_disabled(other.entity)
		row.has_view = DeviceStatus.has_view(other.entity)
		if row.online and not row.is_self and config != null:
			row.commands = _offered(other)
		rows.append(row)
	return rows


## The cables between `rows` (devices()), as index pairs into it (lower index first), each once.
static func cables(rows: Array[Row]) -> Array[Vector2i]:
	var index_of: Dictionary[Device, int] = {}
	for i in rows.size():
		index_of[rows[i].device] = i
	var pairs: Array[Vector2i] = []
	for i in rows.size():
		for other in rows[i].device.linked():
			if not index_of.has(other):
				continue
			var j := index_of[other]
			var pair := Vector2i(mini(i, j), maxi(i, j))
			if not pairs.has(pair):
				pairs.append(pair)
	return pairs


static func display_name(other: Device) -> String:
	return Computer.display_name(other)


func _offered(other: Device) -> Array[StringName]:
	var accepted: Array[StringName] = []
	for command in config.commands():
		if other.accepts(command, entity):
			accepted.append(command)
	return config.offered(accepted)
