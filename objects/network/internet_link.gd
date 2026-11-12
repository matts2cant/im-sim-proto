class_name InternetLink
extends Node
## Component (M12c, ADR 0115): "the internet" as data on an edge router (any entity with a Device,
## usually a Router). The off-site hosts it lists (a mail server on the internet) are reached
## through it: a computer reaches such a host while its Device reaches this link's Device, so
## cutting the edge router (its breaker, a shot, a cable upstream) cuts the route. MailRoute.

const GROUP: StringName = &"internet_link"

## The off-site hosts reached through this link ("mail.halcyon-mail.net"); empty: any off-site host.
@export var hosts: PackedStringArray = []
@export var entity_path: NodePath = ^".."


func _ready() -> void:
	add_to_group(GROUP)


## Its Device (on the entity), or null.
func device() -> Device:
	return Device.of(get_node_or_null(entity_path))


## True when `host` is reached through this link.
func serves(host: String) -> bool:
	return not host.is_empty() and (hosts.is_empty() or hosts.has(host))


## The internet links in `tree` that serve `host`, in tree order.
static func serving(tree: SceneTree, host: String) -> Array[InternetLink]:
	var found: Array[InternetLink] = []
	if tree == null:
		return found
	for node in tree.get_nodes_in_group(GROUP):
		var link := node as InternetLink
		if link != null and not link.is_queued_for_deletion() and link.serves(host) and link.device() != null:
			found.append(link)
	return found
