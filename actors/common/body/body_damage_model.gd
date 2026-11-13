class_name BodyDamageModel
extends RefCounted
## Pure body-part health: six parts with current and max health from a BodyProfile, damage with
## per-type and per-part multipliers, area damage shared out by weights, medkit healing split over
## the damaged parts. Head or torso at 0 = dead. No scene tree (BodyParts is the node adapter).

const HEAD: StringName = &"head"
const TORSO: StringName = &"torso"
const ARM_L: StringName = &"arm_l"
const ARM_R: StringName = &"arm_r"
const LEG_L: StringName = &"leg_l"
const LEG_R: StringName = &"leg_r"
const PARTS: Array[StringName] = [HEAD, TORSO, ARM_L, ARM_R, LEG_L, LEG_R]
const LEGS: Array[StringName] = [LEG_L, LEG_R]
const ARMS: Array[StringName] = [ARM_L, ARM_R]
## Either of these at 0 is death.
const VITAL: Array[StringName] = [HEAD, TORSO]
# Healing below this is treated as nothing left to give.
const EPSILON: float = 0.0001

var profile: BodyProfile

var _health: Dictionary[StringName, float] = {}


func _init(p_profile: BodyProfile) -> void:
	profile = p_profile
	reset()


func reset() -> void:
	for part in PARTS:
		_health[part] = profile.max_health(part)


func health(part: StringName) -> float:
	return _health.get(part, 0.0)


func max_health(part: StringName) -> float:
	return profile.max_health(part)


## Health as a fraction of max (0..1).
func ratio(part: StringName) -> float:
	var top := max_health(part)
	return health(part) / top if top > 0.0 else 0.0


func is_disabled(part: StringName) -> bool:
	return health(part) <= 0.0


func is_dead() -> bool:
	return VITAL.any(is_disabled)


func disabled_legs() -> int:
	return LEGS.filter(is_disabled).size()


func disabled_arms() -> int:
	return ARMS.filter(is_disabled).size()


func is_damaged(part: StringName) -> bool:
	return health(part) < max_health(part)


## Damage `amount` of `type` to one part after the profile's multipliers; returns the damage dealt
## (before clamping, so a 50 headshot reads 50 even on a 40-health head). Health never goes below 0.
func damage_part(part: StringName, type: StringName, amount: float) -> float:
	if not _health.has(part) or amount <= 0.0:
		return 0.0
	var dealt := amount * profile.multiplier(part, type)
	_health[part] = maxf(_health[part] - dealt, 0.0)
	return dealt


## How a hit of `amount` without a known part is shared out: by the profile's area weights for the
## type (explosive, fire), else all to the default part (torso). Raw amounts, before multipliers.
func split(type: StringName, amount: float) -> Dictionary[StringName, float]:
	var shares: Dictionary[StringName, float] = {}
	var weights := profile.area_weights(type)
	if weights.is_empty():
		shares[profile.default_part] = amount
		return shares
	for part in PARTS:
		if weights.get(part, 0.0) > 0.0:
			shares[part] = amount * weights[part]
	return shares


## Applies a hit that arrived without a part (split()); returns the damage dealt per part.
func damage_area(type: StringName, amount: float) -> Dictionary[StringName, float]:
	var dealt: Dictionary[StringName, float] = {}
	var shares := split(type, amount)
	for part in shares:
		dealt[part] = damage_part(part, type, shares[part])
	return dealt


## Medkit healing: `amount` is split evenly over the damaged parts; what a part cannot take (it
## reached max) is split again over the parts still damaged. Disabled limbs heal too. The dead
## cannot heal. Returns the health actually restored.
func heal(amount: float) -> float:
	if is_dead() or amount <= 0.0:
		return 0.0
	var left := amount
	while left > EPSILON:
		var damaged := PARTS.filter(is_damaged)
		if damaged.is_empty():
			break
		var share := left / damaged.size()
		for part: StringName in damaged:
			var given := minf(share, max_health(part) - health(part))
			_health[part] += given
			left -= given
	return amount - left


## Medkit on one part (ADR 0111): heals `part` by up to `amount`, never above its max; disabled
## limbs heal too, the dead cannot heal. Returns the health actually restored.
func heal_part(part: StringName, amount: float) -> float:
	if is_dead() or amount <= 0.0 or not _health.has(part):
		return 0.0
	var given := minf(amount, max_health(part) - health(part))
	if given <= EPSILON:
		return 0.0
	_health[part] += given
	return given


func to_dict() -> Dictionary:
	var parts := {}
	for part in PARTS:
		parts[String(part)] = _health[part]
	return parts


func from_dict(data: Dictionary) -> void:
	for part in PARTS:
		_health[part] = clampf(float(data.get(String(part), _health[part])), 0.0, max_health(part))
