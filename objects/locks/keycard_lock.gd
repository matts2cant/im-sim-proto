class_name KeycardLock
extends Lock
## Lock component: a keycard reader (ADR 0078), a box on the wall beside the frame (ADR 0098). E on
## the reader of the locked entity opens it without unlocking it (Lock.grant_for(): a door is locked
## again once closed, so the card is needed every time) when the user carries a keycard whose
## `key_id` is the reader's access id, or is tagged `access.<access_id>`. Characters with that access
## also pass it while it stays locked (a guard with the key: grants_passage(), and its navigation
## layer, AccessLayers).

const ACCEPT_TONE_HZ := 1180.0
const HARDWARE: PackedScene = preload("res://objects/locks/hardware/card_reader_box.tscn")

@export var data: KeycardLockData


func mount() -> int:
	return Mount.WALL


func hardware() -> PackedScene:
	return HARDWARE


func access_id() -> StringName:
	return data.access_id if data != null else &""


## The `key_id`s of the keycards `user` carries (any character's Inventory).
static func carried_key_ids(user: Node) -> Array[String]:
	var inventory := Inventory.of(user)
	if inventory == null:
		var none: Array[String] = []
		return none
	return inventory.key_ids()


## True when `actor` holds this reader's access: a keycard with its id, or an `access.<id>` tag.
func has_access(actor: Node) -> bool:
	if LockRules.key_matches(access_id(), carried_key_ids(actor)):
		return true
	var tags := Tags.of(actor)
	return tags != null and not String(access_id()).is_empty() and tags.has(AccessLayers.access_tag(access_id()))


func use_prompt(user: Node) -> String:
	return "E: open (keycard)" if has_access(user) else ""


func use_locked(user: Node) -> bool:
	if not has_access(user):
		return false
	make_noise(data.accept_noise, ACCEPT_TONE_HZ)
	return grant_for(user, &"keycard")


func locked_reason(_user: Node) -> String:
	return "keycard"


func grants_passage(actor: Node) -> bool:
	return has_access(actor)


func passage_layers() -> int:
	return AccessLayers.access_layer(access_id())
