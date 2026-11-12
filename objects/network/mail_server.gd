class_name MailServer
extends Node
## Component (M12c, ADR 0115): makes its entity's Device a mail server named `host` (an in-house
## server: a rack, a box on a shelf, any entity with a Device). A computer whose `mail_server` names
## this host reaches its unread mail only while its Device reaches this one (MailRoute). An off-site
## server is not an entity: an edge router's InternetLink stands for it.

const GROUP: StringName = &"mail_server"

## The name computers use for it ("MAIL-01"); empty: its entity's display name.
@export var host: String = ""
@export var entity_path: NodePath = ^".."


func _ready() -> void:
	add_to_group(GROUP)


## Its Device (on the entity), or null.
func device() -> Device:
	return Device.of(get_node_or_null(entity_path))


## The name it answers to: `host`, else its entity's display name.
func host_name() -> String:
	return host if not host.is_empty() else NetworkSource.display_name(device())


## The mail server in `tree` answering to `p_host`, or null.
static func find(tree: SceneTree, p_host: String) -> MailServer:
	if tree == null or p_host.is_empty():
		return null
	for node in tree.get_nodes_in_group(GROUP):
		var server := node as MailServer
		if server != null and not server.is_queued_for_deletion() and server.host_name() == p_host:
			return server
	return null
