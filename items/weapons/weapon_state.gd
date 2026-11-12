class_name WeaponState
extends RefCounted
## Pure weapon cycle: rate of fire, magazine, reload timing, dry fire. Spare rounds come from an
## AmmoPool (a plain count, or the inventory's ammo stacks: InventoryAmmo). Time advances only
## through step(), so tests drive it exactly. Fitted attachments (ADR 0085) change its stats through
## their Modifiers: stat() is the WeaponData value with them applied.

## An attachment was fitted (the holder shows it on the view model).
signal attached(attachment: AttachmentData)

enum Result { FIRED, DRY, BUSY, RELOADING }

# Timer slack so float error never costs a whole tick.
const EPSILON: float = 0.0001

var data: WeaponData
var magazine: int = 0
var ammo: AmmoPool
## Spare rounds available to reload from.
var reserve: int:
	get:
		return ammo.available()
## Seconds until the next shot or swing is allowed.
var cooldown: float = 0.0
## Seconds left of a running reload; 0 when not reloading.
var reload_left: float = 0.0
## Fitted attachments, in the order they were fitted.
var attachments: Array[AttachmentData] = []

# Holds the attachments' modifiers; bases come from `data` (evaluate()).
var _stats := AttributeSet.new()
# How long before the end of the last step the cycle ran out (try_fire()'s `keep_rhythm`).
var _late: float = 0.0


## Without `p_ammo` the spare rounds are a plain pool of `data.reserve_ammo`.
func _init(p_data: WeaponData, p_ammo: AmmoPool = null) -> void:
	data = p_data
	magazine = data.magazine_size
	ammo = p_ammo if p_ammo != null else AmmoPool.new(data.reserve_ammo)


## Fits `attachment`: its modifiers apply to stat() from now on. False when its slot is not one of
## the weapon's or is already taken (one attachment per slot).
func attach(attachment: AttachmentData) -> bool:
	if attachment == null or not data.attachment_slots.has(attachment.slot):
		return false
	for fitted in attachments:
		if fitted.slot == attachment.slot:
			return false
	attachments.append(attachment)
	for modifier in attachment.modifiers:
		_stats.add_modifier(modifier)
	attached.emit(attachment)
	return true


## The weapon's `stat` (a numeric WeaponData property, or `suppressed`) with the attachments applied:
## a silencer's `fire_noise` x0.25 turns 25 into 6.25.
func stat(name: StringName) -> float:
	return _stats.evaluate(name, data.base_stat(name))


func is_reloading() -> bool:
	return reload_left > 0.0


func step(delta: float) -> void:
	_late = maxf(delta - cooldown, 0.0) if cooldown > 0.0 else 0.0
	cooldown = maxf(cooldown - delta, 0.0)
	if not is_reloading():
		return
	reload_left -= delta
	if reload_left <= EPSILON:
		reload_left = 0.0
		magazine += ammo.take(data.magazine_size - magazine)


## Pulls the trigger: FIRED uses a round (if the weapon has ammo) and starts the cycle (cycle_time x
## `cycle_mult`, the user's skill); DRY when the magazine is empty (the click also waits a cycle);
## BUSY during the cycle; RELOADING. `keep_rhythm` (automatic fire, ADR 0123): the time the cycle
## ran out before the last step ended is taken off the next cycle, so a 0.07 s cycle fires every
## 0.07 s on average at any physics rate instead of every whole number of steps.
func try_fire(cycle_mult: float = 1.0, keep_rhythm: bool = false) -> Result:
	if is_reloading():
		return Result.RELOADING
	if cooldown > EPSILON:
		return Result.BUSY
	cooldown = data.cycle_time * cycle_mult - (_late if keep_rhythm else 0.0)
	_late = 0.0
	if data.uses_ammo():
		if magazine <= 0:
			return Result.DRY
		magazine -= 1
	return Result.FIRED


## Starts a reload taking reload_time x `time_mult` (the user's skill); false when there is nothing
## to do (no ammo weapon, already reloading, full, no reserve).
func start_reload(time_mult: float = 1.0) -> bool:
	if not data.uses_ammo() or is_reloading() or magazine >= data.magazine_size or reserve <= 0:
		return false
	reload_left = data.reload_time * time_mult
	return true


## Holstering cancels a reload (no rounds move).
func cancel_reload() -> void:
	reload_left = 0.0


func to_dict() -> Dictionary:
	return {"magazine": magazine, "reserve": reserve}


func from_dict(state: Dictionary) -> void:
	magazine = int(state.get("magazine", magazine))
	if state.has("reserve"):
		ammo.restore(int(state["reserve"]))
	cooldown = 0.0
	reload_left = 0.0
