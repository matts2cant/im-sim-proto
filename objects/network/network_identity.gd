class_name NetworkIdentity
extends Node
## Component (ADR 0140): who a user is to the network. Accounts (DeviceAccounts), exploit grants
## (DeviceIntrusion), traces (Tracer) and Wi-Fi keys (AccessPoint) are keyed by its `id` (key_of()),
## never by a node name: two characters with the same node name are two users, and renaming one
## changes nothing.
## Any entity can carry it. One that acts on a network without one gets one then (ensure(): the
## scene SCENE_PATH added as a child, so a save restores it like any spawned node and its id with
## it). Reads never add one: a user without an identity has no access, trace or key anywhere.
## `id`: set in a level for a fixed identity; empty: a random one is made when it enters the tree.
## Saveable (`id`).
## Saves made before ADR 0140 keyed users by node name; components that keep users call
## loaded_key() on each saved key: a key from such a save goes to the character of that name
## (migrate()), once.

const SCENE_PATH: String = "res://objects/network/network_identity.tscn"
const NODE_NAME: StringName = &"NetworkIdentity"
## Save key components write beside their users (value FORMAT): their keys are identity ids.
const FORMAT_KEY: String = "user_keys"
const FORMAT: String = "identity"

## The id users are keyed by; empty: one is generated (generate()).
@export var id: String = ""


func _enter_tree() -> void:
	if id.is_empty():
		id = NetworkIdentity.generate()


func _ready() -> void:
	add_to_group(&"saveable")


## The NetworkIdentity child of `entity` (or `entity` itself), or null.
static func of(entity: Node) -> NetworkIdentity:
	if entity == null or not is_instance_valid(entity):
		return null
	if entity is NetworkIdentity:
		return entity as NetworkIdentity
	for child in entity.get_children():
		if child is NetworkIdentity:
			return child as NetworkIdentity
	return null


## The key `user` is known by on networks: its identity's id; "" without one (it has nothing).
static func key_of(user: Node) -> String:
	var identity := NetworkIdentity.of(user)
	return identity.id if identity != null else ""


## The key of `user`, giving it an identity first when it has none (it is about to get access, a
## key or trace). "" for a null or freed user.
static func ensure(user: Node) -> String:
	if user == null or not is_instance_valid(user):
		return ""
	var identity := NetworkIdentity.of(user)
	if identity == null:
		identity = (load(SCENE_PATH) as PackedScene).instantiate() as NetworkIdentity
		identity.name = NODE_NAME
		identity.id = NetworkIdentity.generate()
		user.add_child(identity)
	return identity.id


## A new random id (16 hex digits; not affected by the global random seed).
static func generate() -> String:
	return "u" + Crypto.new().generate_random_bytes(8).hex_encode()


## The key to load a saved user key as: `key` itself from a save that wrote FORMAT_KEY (`data`), else
## (a save from before ADR 0140, keyed by node name) the key of the character `context`'s level calls
## `key` (migrate()); "" when there is none.
static func loaded_key(context: Node, key: String, data: Dictionary) -> String:
	if str(data.get(FORMAT_KEY, "")) == FORMAT:
		return key
	return NetworkIdentity.migrate(context, key)


## Legacy saves only: the identity key of the character named `legacy_name` in `context`'s tree (a
## CharacterBody3D first, else any node of that name), given an identity if needed; "" when none.
static func migrate(context: Node, legacy_name: String) -> String:
	if context == null or not context.is_inside_tree() or legacy_name.is_empty():
		return ""
	var matches := context.get_tree().root.find_children(legacy_name, "", true, false)
	var found: Node = null
	for each in matches:
		if String(each.name) != legacy_name:
			continue
		if each is CharacterBody3D:
			found = each
			break
		if found == null:
			found = each
	return NetworkIdentity.ensure(found) if found != null else ""


func save_state() -> Dictionary:
	return {"id": id}


func load_state(data: Dictionary) -> void:
	var saved := str(data.get("id", ""))
	if not saved.is_empty():
		id = saved
