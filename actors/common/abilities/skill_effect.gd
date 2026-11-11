class_name SkillEffect
extends Resource
## One attribute a skill changes: a Modifier of `op` on `attribute` whose magnitude is
## `tier_values[tier]` (Untrained, Trained, Advanced, Master). A tier whose value changes nothing
## (MULTIPLY 1, ADD 0) adds no modifier.
## The Display group only says how the Skills tab's tier table shows it (ADR 0111): a row label, and
## either the modifier itself ("x0.8", "+0.03") or the value it gives a stated base (settle 0.8 s ->
## "0.6 s"), scaled and with a unit, or one text per tier.

@export var attribute: StringName = &""
@export var op: Modifier.Op = Modifier.Op.MULTIPLY
## One magnitude per tier, Untrained first.
@export var tier_values: Array[float] = [1.0, 1.0, 1.0, 1.0]
## OVERRIDE only.
@export var priority: int = 0

@export_group("Display")
## Row label in the tier table ("Spread"); empty: the attribute name.
@export var label: String = ""
## Show the value the modifier gives `display_base` instead of the modifier itself.
@export var shows_value: bool = false
## The consumer's base value (its tuning) the table applies the modifier to when `shows_value`.
@export var display_base: float = 0.0
## Shown value x this (0.4 -> 40 with 100 and unit " %").
@export var display_scale: float = 1.0
## Appended to the number (" s", " %", "°").
@export var display_unit: String = ""
## Most decimals shown (trailing zeros dropped).
@export var display_decimals: int = 2
## One text per tier instead of a number (assists: "Sound only", "+ tension gauge", ...).
@export var tier_texts: Array[String] = []


## The modifier for `tier` (clamped to the table), or null when that tier changes nothing.
func modifier_for(tier: int, source: StringName) -> Modifier:
	if tier_values.is_empty():
		return null
	var magnitude := magnitude_at(tier)
	if op == Modifier.Op.MULTIPLY and is_equal_approx(magnitude, 1.0):
		return null
	if op == Modifier.Op.ADD and is_zero_approx(magnitude):
		return null
	return Modifier.create(attribute, op, magnitude, source, priority)


## The magnitude at `tier` (clamped to the table; 0 when there is none).
func magnitude_at(tier: int) -> float:
	if tier_values.is_empty():
		return 0.0
	return tier_values[clampi(tier, 0, tier_values.size() - 1)]


## The tier table's row label.
func display_label() -> String:
	return label if not label.is_empty() else String(attribute)


## The tier table's cell for `tier`: a tier text, the value given to `display_base`, or the
## modifier ("x0.8" multiply, "+0.03" / "-0.03" add, the value for override).
func display_text(tier: int) -> String:
	if not tier_texts.is_empty():
		return tier_texts[clampi(tier, 0, tier_texts.size() - 1)]
	var magnitude := magnitude_at(tier)
	if shows_value:
		return _number(_applied(display_base, magnitude) * display_scale) + display_unit
	match op:
		Modifier.Op.MULTIPLY:
			return "x" + _number(magnitude)
		Modifier.Op.ADD:
			var scaled := magnitude * display_scale
			return ("-" if scaled < 0.0 else "+") + _number(absf(scaled)) + display_unit
	return _number(magnitude * display_scale) + display_unit


func _applied(base: float, magnitude: float) -> float:
	match op:
		Modifier.Op.MULTIPLY:
			return base * magnitude
		Modifier.Op.ADD:
			return base + magnitude
	return magnitude


## `value` with up to `decimals` decimals, trailing zeros dropped ("27.5", "30", "0.068").
static func trimmed(value: float, decimals: int) -> String:
	var text := String.num(value, decimals)
	if text.contains("."):
		text = text.rstrip("0").trim_suffix(".")
	return "0" if text == "-0" else text


func _number(value: float) -> String:
	return trimmed(value, display_decimals)
