extends RefCounted
## Test helper (not a suite): minimal device entities built in code (stimulus_fixtures entities with
## a Device, and optionally a Powered and a Breakable), to show devices are generic: any entity with
## a Device and the right receptrons is one.

const Fixtures := preload("res://tests/core/stimulus/stimulus_fixtures.gd")


## A Node3D device entity under `parent` at `position` with `receptrons`, a Device, and a Powered
## (`powered`) and a Breakable with `health` (> 0) when asked. Cable it with link().
static func device(
	parent: Node,
	entity_name: String,
	position: Vector3,
	receptrons: Array[Receptron] = [],
	powered: bool = false,
	health: float = 0.0,
) -> Node3D:
	var root := Node3D.new()
	if powered:
		var power := Powered.new()
		power.name = "Powered"
		root.add_child(power)
	if health > 0.0:
		var breakable := Breakable.new()
		breakable.name = "Breakable"
		breakable.break_on_depleted = false
		root.add_child(breakable)
	var component := Device.new()
	component.name = "Device"
	root.add_child(component)
	var entity := Fixtures.compose(root, parent, entity_name, position, receptrons)
	if health > 0.0:
		(entity.get_node("Attributes") as Attributes).attribute_set.set_base(Breakable.HEALTH, health)
	return entity


## Cables `a` to `b` (listed on `a`'s Device; links are undirected).
static func link(a: Node3D, b: Node3D) -> void:
	var component := Device.of(a)
	component.links.append(component.get_path_to(b))


## A receptron for command `type` like the shipped ones: blocked while unpowered or broken, running
## `effects`.
static func command_receptron(type: StringName, effects: Array[Effect]) -> Receptron:
	var receptron := Fixtures.receptron(type, effects, String(type))
	receptron.blocked_tags = [Device.UNPOWERED, Device.BROKEN]
	return receptron


## A receptron for command `type` that runs DeviceActionEffect (as the shipped ones do).
static func action_receptron(type: StringName) -> Receptron:
	return command_receptron(type, [DeviceActionEffect.new()])
