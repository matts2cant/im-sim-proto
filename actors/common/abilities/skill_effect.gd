class_name SkillEffect
extends Resource
## One attribute a skill changes: a Modifier of `op` on `attribute` whose magnitude is
## `tier_values[tier]` (Untrained, Trained, Advanced, Master). A tier whose value changes nothing
## (MULTIPLY 1, ADD 0) adds no modifier.

@export var attribute: StringName = &""
@export var op: Modifier.Op = Modifier.Op.MULTIPLY
## One magnitude per tier, Untrained first.
@export var tier_values: Array[float] = [1.0, 1.0, 1.0, 1.0]
## OVERRIDE only.
@export var priority: int = 0


## The modifier for `tier` (clamped to the table), or null when that tier changes nothing.
func modifier_for(tier: int, source: StringName) -> Modifier:
	if tier_values.is_empty():
		return null
	var magnitude := tier_values[clampi(tier, 0, tier_values.size() - 1)]
	if op == Modifier.Op.MULTIPLY and is_equal_approx(magnitude, 1.0):
		return null
	if op == Modifier.Op.ADD and is_zero_approx(magnitude):
		return null
	return Modifier.create(attribute, op, magnitude, source, priority)
