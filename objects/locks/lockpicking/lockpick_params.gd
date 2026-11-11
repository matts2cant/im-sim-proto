class_name LockpickParams
extends RefCounted
## The picker's lockpicking forgiveness and assists (ADR 0073, 0107): the prototype's
## `skillParams(t)` read from attributes, so the Lockpicking skill (and later an augmentation) changes
## them through modifiers. Bases come from LockpickTuning.
## Assist levels are cumulative: 0 sound only, 1 + tension gauge, 2 + captions, 3 + pins view; a
## practice lock always shows all three.

const WINDOW_LOW: StringName = &"lockpick_window_low"
const WINDOW_HIGH: StringName = &"lockpick_window_high"
const DROP_THRESHOLD: StringName = &"lockpick_drop_threshold"
const DROP_DELAY: StringName = &"lockpick_drop_delay"
const LIFT_TOLERANCE: StringName = &"lockpick_lift_tolerance"
const RAKE: StringName = &"lockpick_rake"
const ASSIST: StringName = &"lockpick_assist"
const ASSIST_GAUGE := 1
const ASSIST_CAPTIONS := 2
const ASSIST_PINS := 3

## Working tension window (0..1).
var low: float = 0.30
var high: float = 0.60
## Below this tension set pins start to drop.
var drop: float = 0.15
## Seconds per dropped pin below `drop`.
var drop_delay: float = 0.3
## Added to the base lift tolerance around the shear line.
var tolerance_bonus: float = 0.0
## Rakes rakeable (Simple) locks by holding LMB.
var rake: bool = false
## 0..3 (see the class description).
var assist: int = 0


## The params of `entity` (its attributes over `tuning`'s bases).
static func from_entity(entity: Node, tuning: LockpickTuning) -> LockpickParams:
	return _build(
		func(attribute: StringName, base: float) -> float: return Attributes.read(entity, attribute, base), tuning
	)


## The params of an AttributeSet (tests, tools).
static func from_set(attribute_set: AttributeSet, tuning: LockpickTuning) -> LockpickParams:
	return _build(attribute_set.evaluate, tuning)


## `assist` for a lock: a practice lock always shows everything.
static func assist_for(level: int, practice: bool) -> int:
	return ASSIST_PINS if practice else clampi(level, 0, ASSIST_PINS)


static func shows_gauge(level: int) -> bool:
	return level >= ASSIST_GAUGE


static func shows_captions(level: int) -> bool:
	return level >= ASSIST_CAPTIONS


static func shows_pins(level: int) -> bool:
	return level >= ASSIST_PINS


## The zone word of `tension` on the gauge: drop, low, sweet, high.
func zone(tension: float) -> String:
	if tension < drop:
		return "drop"
	if tension < low:
		return "low"
	return "sweet" if tension <= high else "high"


static func _build(read: Callable, tuning: LockpickTuning) -> LockpickParams:
	var params := LockpickParams.new()
	params.low = read.call(WINDOW_LOW, tuning.window_low)
	params.high = read.call(WINDOW_HIGH, tuning.window_high)
	params.drop = read.call(DROP_THRESHOLD, tuning.drop_threshold)
	params.drop_delay = read.call(DROP_DELAY, tuning.drop_delay)
	params.tolerance_bonus = read.call(LIFT_TOLERANCE, tuning.lift_tolerance_bonus)
	params.rake = float(read.call(RAKE, tuning.rake)) >= 0.5
	params.assist = clampi(roundi(float(read.call(ASSIST, tuning.assist))), 0, ASSIST_PINS)
	return params
