class_name DeviceKinds
extends Resource
## The kinds of device, by entity tag (ADR 0114, 0121): data in `objects/devices/device_kinds.tres`
## (shipped()), one SecurityKind per kind with its name, icon, the Security app's group and the
## exploit item kind that opens it. A device's kind is the first kind whose tag its entity has
## (kind_for()); nothing in code names a kind. Read by the Security app (ComputerConfig, the kinds
## with a group), the deck's Map (every box's icon) and exploit items (ExploitItems).

const PATH: String = "res://objects/devices/device_kinds.tres"

@export var kinds: Array[SecurityKind] = []


## The shipped kinds.
static func shipped() -> DeviceKinds:
	return load(PATH) as DeviceKinds


## The kind of `entity` (the first kind whose tag it has), or null.
func kind_for(entity: Node) -> SecurityKind:
	if entity == null or not is_instance_valid(entity):
		return null
	for kind in kinds:
		if kind != null and ActorState.has(entity, kind.tag):
			return kind
	return null
