class_name WeaponState
extends RefCounted
## Pure weapon cycle: rate of fire, magazine, reload timing, dry fire. Spare rounds come from an
## AmmoPool (a plain count, or the inventory's ammo stacks: InventoryAmmo). Time advances only
## through step(), so tests drive it exactly.

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


## Without `p_ammo` the spare rounds are a plain pool of `data.reserve_ammo`.
func _init(p_data: WeaponData, p_ammo: AmmoPool = null) -> void:
	data = p_data
	magazine = data.magazine_size
	ammo = p_ammo if p_ammo != null else AmmoPool.new(data.reserve_ammo)


func is_reloading() -> bool:
	return reload_left > 0.0


func step(delta: float) -> void:
	cooldown = maxf(cooldown - delta, 0.0)
	if not is_reloading():
		return
	reload_left -= delta
	if reload_left <= EPSILON:
		reload_left = 0.0
		magazine += ammo.take(data.magazine_size - magazine)


## Pulls the trigger: FIRED uses a round (if the weapon has ammo) and starts the cycle; DRY when
## the magazine is empty (the click also waits a cycle); BUSY during the cycle; RELOADING.
func try_fire() -> Result:
	if is_reloading():
		return Result.RELOADING
	if cooldown > EPSILON:
		return Result.BUSY
	cooldown = data.cycle_time
	if data.uses_ammo():
		if magazine <= 0:
			return Result.DRY
		magazine -= 1
	return Result.FIRED


## Starts a reload; false when there is nothing to do (no ammo weapon, already reloading, full,
## no reserve).
func start_reload() -> bool:
	if not data.uses_ammo() or is_reloading() or magazine >= data.magazine_size or reserve <= 0:
		return false
	reload_left = data.reload_time
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
