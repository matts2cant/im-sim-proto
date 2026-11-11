extends RefCounted
## Test helper (not a suite): lockpicking params per skill tier (from the real skill table), pins
## with known shear lifts, and a careful player driving a PinTumbler (aim and aim_x, as the mouse).

const TABLE: SkillTable = preload("res://actors/common/abilities/skill_table.tres")
const TUNING: LockpickTuning = preload("res://objects/locks/lockpicking/lockpick_tuning.tres")
## The tip counts as arrived under a pin this close to its slot.
const ARRIVED := 0.05


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


## The force the binding pin needs at the model's tension.
static func required(model: PinTumbler) -> float:
	return model.tuning.lift_required_base + model.tuning.lift_required_tension * model.tension * model.tension


## The tip is under pin `index` (arrived).
static func at_pin(model: PinTumbler, index: int) -> bool:
	return model.pick == index and absf(model.tip_x - index) < ARRIVED


## One step of a careful player heading for pin `index`: lowers the aim and aims along the keyway at
## it until the tip has arrived, then aims the lift so the tip settles `over` above its shear line.
static func drive(model: PinTumbler, index: int, over: float = 0.01) -> void:
	if not at_pin(model, index):
		model.aim = 0.0
		model.aim_x = index
	else:
		model.aim = model.pins[index].shear + required(model) + over


## Solves `model` like a careful player: for each binding pin in turn, moves the tip there and lifts
## it to its shear line at `tension`, stepping `dt`. Returns the seconds it took (or -1 when it did not
## open within `limit` s).
static func solve(model: PinTumbler, tension: float, dt: float, limit: float = 30.0) -> float:
	model.tension = tension
	var time := 0.0
	while not model.opened and time < limit:
		var index := model.binding_index()
		if index < 0:
			break
		drive(model, index)
		model.step(dt)
		time += dt
	return time if model.opened else -1.0
