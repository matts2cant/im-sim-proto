class_name ElectronicLock
extends Lock
## Lock component: an electronic lock, a network device (ADR 0078). Opened remotely (the entity's
## `command.unlock` / `command.open` receptrons; from M11 with network access) or by losing power
## when the entity is tagged `door.fail_safe`; a `door.fail_secure` entity (or one with neither tag)
## stays as it was. Power loss is the entity's Powered switching off, or the entity gaining
## `state.unpowered` (whatever sets it: the device network).

const FAIL_SAFE: StringName = &"door.fail_safe"
const FAIL_SECURE: StringName = &"door.fail_secure"
const UNPOWERED: StringName = &"state.unpowered"

var _tags: Tags
var _powered: Powered


func _ready() -> void:
	super._ready()
	_tags = ActorState.tags_of(entity)
	if _tags != null:
		_tags.container.changed.connect(_on_tag_changed)
	_powered = Powered.of(entity)
	if _powered != null:
		_powered.power_changed.connect(_on_power_changed)


func locked_reason(_user: Node) -> String:
	return "electronic"


func is_fail_safe() -> bool:
	return _tags != null and _tags.has(FAIL_SAFE)


## Power went out: a fail-safe lock unlocks.
func power_lost() -> void:
	var target := lockable()
	if target == null:
		return
	if not LockRules.locked_after_power_loss(target.locked, is_fail_safe()):
		target.unlock(entity, &"power")


func _on_power_changed(on: bool) -> void:
	if not on:
		power_lost()


func _on_tag_changed(tag: StringName, added: bool) -> void:
	if added and tag == UNPOWERED:
		power_lost()
