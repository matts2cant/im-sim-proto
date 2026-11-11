extends RefCounted
## Test helper (not a suite): lockpicking params per skill tier (from the real skill table) and pins
## with known shear lifts.

const TABLE: SkillTable = preload("res://actors/common/abilities/skill_table.tres")
const TUNING: LockpickTuning = preload("res://objects/locks/lockpicking/lockpick_tuning.tres")


## The params of a picker with Lockpicking at `tier` (the skill table's modifiers over the tuning).
static func params(tier: int) -> LockpickParams:
	return LockpickParams.from_set(attributes(tier), TUNING)


static func attributes(tier: int) -> AttributeSet:
	var attribute_set := AttributeSet.new()
	for modifier in TABLE.find(&"lockpicking").modifiers_for(tier):
		attribute_set.add_modifier(modifier)
	return attribute_set


## Gives `pin` the shear lift `shear` (false set and ticks below it as the tuning says).
static func fix_pin(pin: PinTumbler.Pin, shear: float, tuning: LockpickTuning) -> void:
	pin.shear = shear
	pin.shown_shear = shear
	pin.shear_from = shear
	pin.false_lift = shear - tuning.false_set_offset
	pin.levels.clear()
	for offset in tuning.serrated_offsets:
		pin.levels.append(shear - offset)


## Solves `model` like a careful player: for each binding pin in turn, moves the pick there and lifts
## it to its shear line at `tension`, stepping `dt`. Returns the seconds it took (or -1 when it did not
## open within `limit` s).
static func solve(model: PinTumbler, tension: float, dt: float, limit: float = 30.0) -> float:
	model.tension = tension
	var time := 0.0
	while not model.opened and time < limit:
		var index := model.binding_index()
		if index < 0:
			break
		if model.goal() != index:
			model.move_pick(signi(index - model.goal()))
		elif not model.is_changing_pin():
			var required := TUNING.lift_required_base + TUNING.lift_required_tension * tension * tension
			model.target = model.pins[index].shear + required + 0.01
		model.step(dt, 0, false, false)
		time += dt
	return time if model.opened else -1.0
