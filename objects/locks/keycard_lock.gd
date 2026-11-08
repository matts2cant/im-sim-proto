class_name KeycardLock
extends Lock
## Lock component: a keycard reader (ADR 0078). E on the locked entity unlocks it (and opens it) when
## the user carries a keycard whose `key_id` is the reader's access id, or is tagged
## `access.<access_id>`. Characters with that access also pass it while it stays locked (a guard
## with the key: grants_passage(), and its navigation layer, AccessLayers).

const ACCEPT_TONE_HZ := 1180.0

@export var data: KeycardLockData


func access_id() -> StringName:
	return data.access_id if data != null else &""


## The `key_id`s of the keycards `user` carries (its inventory's item stacks with a `key_id`).
static func carried_key_ids(user: Node) -> Array[String]:
	var ids: Array[String] = []
	if user == null:
		return ids
	for child in user.get_children():
		var carried := child as PlayerInventory
		if carried == null or carried.inventory == null:
			continue
		for stack in carried.inventory.stacks:
			var key := str(stack.state.get("key_id", ""))
			if not key.is_empty():
				ids.append(key)
	return ids


## True when `actor` holds this reader's access: a keycard with its id, or an `access.<id>` tag.
func has_access(actor: Node) -> bool:
	if LockRules.key_matches(access_id(), carried_key_ids(actor)):
		return true
	var tags := ActorState.tags_of(actor)
	return tags != null and not String(access_id()).is_empty() and tags.has(AccessLayers.access_tag(access_id()))


func use_prompt(user: Node) -> String:
	return "E: open (keycard)" if has_access(user) else ""


func use_locked(user: Node) -> bool:
	if not has_access(user):
		return false
	make_noise(data.accept_noise, ACCEPT_TONE_HZ)
	return unlock_for(user, &"keycard")


func locked_reason(_user: Node) -> String:
	return "keycard"


func grants_passage(actor: Node) -> bool:
	return has_access(actor)


func passage_layers() -> int:
	return AccessLayers.access_layer(access_id())
