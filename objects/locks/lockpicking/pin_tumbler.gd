class_name PinTumbler
extends RefCounted
## Pure model of a pin-tumbler lock being picked (ADR 0073, 0107, 0109): a faithful port of the final
## prototype's simulation (design/prototypes/lockpicking_bench.html `step()`, `setPick()`, the wheel
## and pointer handlers). Under tension one pin binds at a time (the seeded binding order); the pick
## tip follows the lift target like a spring and, on a binding pin, lags behind it: that lag is the
## force. The binding pin sets (click) after staying at its shear line for the picker's `set_dwell`;
## lifted through it, it oversets (jam, until tension is released); set and loose pins overset only
## when shoved well past it. Spools false-set (the plug turns further) and need tension eased while
## lifting (counter-rotation); serrated pins tick. Too little tension drops set pins (the last one every
## `drop_delay` s below the drop threshold, all at 0 %); forcing a bound pin at high tension or prying
## an overset strains the pick until it snaps.
## The pick (ADR 0109): `aim` is the lift the mouse asks for (0..1) and `aim_x` where along the keyway
## the tip should go (in pin slots). The tip slides along the keyway only while tip and aim are both
## in the bottom band; above it the tip stays under its pin, which is the nearest slot once the tip is
## more than `slot_hysteresis` from it. When a pin sets the tip stays put: the aim's lead becomes a
## bias that lowering the aim wears off. Fast sideways strokes in the bottom band rake: every lock
## rattles; a raking picker (`rake`) on a rakeable lock (a property: few pins, all standard) sets the
## binding pin every `rake_strokes` reversals with light tension.
## Events (set, overset, false_set, tick, creak, drop, snap, open, scrape, rake_stroke, rake,
## rake_hint) collect in `events` for the adapter (sound cue, caption, noise), which takes them with
## take_events().

enum Spool { NONE, FALSE_SET, SET }

const STANDARD: StringName = &"standard"
const SPOOL: StringName = &"spool"
const SERRATED: StringName = &"serrated"
const SALT := 7919


## One pin stack. Heights are 0..1 lifts of the key pin.
class Pin:
	extends RefCounted
	var type: StringName = &"standard"
	## Shear-line lift.
	var shear: float = 0.5
	## A spool's false-set lift.
	var false_lift: float = 0.38
	## A serrated pin's tick lifts.
	var levels: Array[float] = []
	## Current lift of the key pin (it rests on the tip while the pick is under it).
	var height: float = 0.0
	var is_set: bool = false
	var overset: bool = false
	var spool: Spool = Spool.NONE
	## Tension at the false set.
	var false_tension: float = 0.0
	## Serrated ticks heard (bit per level).
	var ticks: int = 0
	## Extra force a tick needs, decaying.
	var bump: float = 0.0
	## Seconds this binding pin has stayed at its shear line.
	var dwell: float = 0.0
	## Drawn shear lift: eases to `shear` after a re-layout.
	var shown_shear: float = 0.5
	## Drawn shear lift when the re-layout started.
	var shear_from: float = 0.5

	func reset() -> void:
		height = 0.0
		is_set = false
		overset = false
		spool = Spool.NONE
		false_tension = 0.0
		ticks = 0
		bump = 0.0
		dwell = 0.0


## Something the player hears or sees: a sound cue (LockpickAudio), a caption, a noise loudness.
class Event:
	extends RefCounted
	var kind: StringName
	var cue: StringName
	var caption: String
	var loudness: float

	func _init(p_kind: StringName, p_cue: StringName, p_caption: String, p_loudness: float) -> void:
		kind = p_kind
		cue = p_cue
		caption = p_caption
		loudness = p_loudness


var tuning: LockpickTuning
var params: LockpickParams
var pins: Array[Pin] = []
## Binding order (pin indices).
var order: Array[int] = []
## Lift tolerance multiplier of the lock (its tier).
var tolerance_mult: float = 1.0
## A rakeable lock (at most `rake_max_pins` pins, all standard).
var rakeable: bool = false
var tension: float = 0.0
## Lift the mouse asks for (0..1), and how far below it the tip is held after a set (the bias).
var aim: float = 0.0
var aim_bias: float = 0.0
## Where along the keyway the mouse asks the tip to go (pin slots, 0 = the front pin).
var aim_x: float = 0.0
## Pick tip lift and its target (aim minus bias).
var tip: float = 0.0
var target: float = 0.0
## Pick tip position along the keyway (pin slots), and the pin it is under.
var tip_x: float = 0.0
var pick: int = 0
var strain: float = 0.0
## Tip lag on a binding or jammed pin (the bow of the pick).
var force: float = 0.0
## Rub of the binding pin or the rake, 0..1 (the scrape sound).
var scraping: float = 0.0
var nudge: float = 0.0
## Extra plug turn of a false set (degrees), and of serrated ticks.
var false_turn: float = 0.0
var tick_turn: float = 0.0
var opened: bool = false
## 0..1 open animation.
var open_t: float = 0.0
## 0..1 after a re-layout (1: settled).
var relayout_t: float = 1.0
## Seconds since tension was first applied.
var elapsed: float = 0.0
var events: Array[Event] = []

var _set_stack: Array[int] = []
var _drop_timer: float = 0.0
## Rake strokes counted towards the next set, the last stroke's direction and the time since it.
var _rake: int = 0
var _rake_dir: int = 0
var _rake_gap: float = 0.0
var _clock: float = 0.0
var _last_scrape: float = -INF
var _last_creak: float = -INF
var _last_rake_hint: float = -INF
var _open_delay: float = -1.0
var _started: bool = false
## Plug angle when the last re-layout started (it turns back from there).
var _relock_angle: float = 0.0


func _init(p_tuning: LockpickTuning, p_params: LockpickParams) -> void:
	tuning = p_tuning
	params = p_params


## Builds the pins from `types` (front to back) with seed `seed`; `shuffle_types` shuffles the types
## first (a practice tier's pin set). The same seed gives the same lock.
func build(types: Array[StringName], pin_seed: int, p_tolerance_mult: float = 1.0, shuffle_types: bool = false) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = pin_seed * SALT + types.size()
	var kinds: Array[StringName] = types.duplicate()
	if shuffle_types:
		_shuffle(kinds, rng)
	pins = []
	for i in kinds.size():
		var pin := Pin.new()
		pin.type = kinds[i]
		pin.shear = tuning.pin_height_min + rng.randf() * tuning.pin_height_range
		pin.false_lift = pin.shear - tuning.false_set_offset
		for offset in tuning.serrated_offsets:
			pin.levels.append(pin.shear - offset)
		pin.shown_shear = pin.shear
		pin.shear_from = pin.shear
		pins.append(pin)
	var indices: Array[int] = []
	for i in pins.size():
		indices.append(i)
	_shuffle(indices, rng)
	order = indices
	tolerance_mult = p_tolerance_mult
	rakeable = (
		pins.size() <= tuning.rake_max_pins and kinds.all(func(kind: StringName) -> bool: return kind == STANDARD)
	)
	pick = clampi(pick, 0, maxi(pins.size() - 1, 0))
	tip_x = pick
	aim_x = pick
	_reset_progress()


## A practice lock re-locked with a new layout: the plug turns back, the old pins drop and the new
## ones settle at their heights over `relayout_time`; tension and lift go back to zero.
func relock(types: Array[StringName], pin_seed: int, p_tolerance_mult: float, shuffle_types: bool) -> void:
	_relock_angle = plug_angle_deg()
	var old := pins
	opened = false
	open_t = 0.0
	_open_delay = -1.0
	tension = 0.0
	_release_pick()
	build(types, pin_seed, p_tolerance_mult, shuffle_types)
	# The old pins drop from where they were; the drawn shear lines ease to the new heights.
	for i in mini(old.size(), pins.size()):
		pins[i].height = old[i].height
		pins[i].shear_from = old[i].shown_shear
		pins[i].shown_shear = old[i].shown_shear
	relayout_t = 0.0 if tuning.relayout_time > 0.0 else 1.0
	_started = false
	elapsed = 0.0


## Mouse wheel: `notches` of tension (up is positive), `fine` (Shift) for the small step. It holds
## where it is left.
func turn_wrench(notches: float, fine: bool) -> void:
	if opened:
		return
	var step_size := tuning.wheel_fine_step if fine else tuning.wheel_step
	tension = clampf(tension + notches * step_size, 0.0, 1.0)


## Mouse motion: moves the aim `slots` pin slots along the keyway (positive: deeper) and `lift` up
## (0..1 of the range). Ignored once the lock is open.
func move_aim(slots: float, lift: float) -> void:
	if opened or pins.is_empty():
		return
	aim = clampf(aim + lift, 0.0, 1.0)
	aim_x = clampf(aim_x + slots, -tuning.aim_x_margin, pins.size() - 1 + tuning.aim_x_margin)


## A / D: aims the tip at the previous (-1) or next (+1) pin slot, only while tip and aim are in the
## bottom band (the tip then slides there like a mouse move).
func step_pin(direction: int) -> void:
	if opened or pins.is_empty() or direction == 0 or not in_bottom_band():
		return
	var from := clampi(roundi(aim_x), 0, pins.size() - 1)
	aim_x = clampi(from + signi(direction), 0, pins.size() - 1)


## Tip and aim both in the bottom band: the tip can slide between pins and rake.
func in_bottom_band() -> bool:
	return tip <= tuning.bottom_band and aim <= tuning.bottom_band


## The pin binding now (the first unset one in the binding order), or -1.
func binding_index() -> int:
	for i in order:
		if not pins[i].is_set:
			return i
	return -1


func set_count() -> int:
	return pins.filter(func(pin: Pin) -> bool: return pin.is_set).size()


func any_progress() -> bool:
	return pins.any(
		func(pin: Pin) -> bool: return pin.is_set or pin.overset or pin.spool == Spool.FALSE_SET or pin.ticks != 0
	)


func any_overset() -> bool:
	return pins.any(func(pin: Pin) -> bool: return pin.overset)


## The plug's turn in degrees (it shows tension, sets, false sets; the open turn; a re-lock turning
## back).
func plug_angle_deg() -> float:
	if opened:
		var eased := 1.0 - pow(1.0 - open_t, 3.0)
		return tuning.plug_open_base + eased * tuning.plug_open_turn
	var angle := tension * tuning.plug_tension_turn + set_count() * tuning.plug_set_turn + false_turn + tick_turn
	if relayout_t < 1.0:
		return lerpf(_relock_angle, angle, 1.0 - pow(1.0 - relayout_t, 3.0))
	return angle


## The events since the last call.
func take_events() -> Array[Event]:
	var out := events
	events = []
	return out


## One tick.
func step(dt: float) -> void:
	_clock += dt
	nudge = maxf(0.0, nudge - dt * tuning.nudge_decay)
	_step_relayout(dt)
	if opened:
		# The continuous sounds fall silent once the lock opens.
		scraping = 0.0
		strain = 0.0
		force = 0.0
		open_t = minf(1.0, open_t + dt * tuning.open_rate)
		if _open_delay >= 0.0:
			_open_delay -= dt
			if _open_delay < 0.0:
				_emit(&"open", &"open", "the plug turns, unlocked")
		return
	if pins.is_empty():
		return
	# When a pin sets the tip stays where it was instead of springing up to the aim: the aim's lead
	# becomes a bias, which lowering the aim wears off.
	aim_bias = minf(aim_bias, aim)
	target = maxf(0.0, aim - aim_bias)
	var prev_tip_x := tip_x
	_step_slide(dt)
	if not _started and (tension > 0.0 or target > 0.05):
		_started = true
	if _started:
		elapsed += dt
	_step_lift(dt, pins[pick])
	_step_drops(dt)
	_step_rake(dt, prev_tip_x)
	if strain >= tuning.break_strain:
		_break_pick()


# The tip slides along the keyway only while it is in the bottom band; lifted higher, it stays under
# its pin. Its pin is the nearest slot once the tip is more than `slot_hysteresis` from it.
func _step_slide(dt: float) -> void:
	var count := pins.size()
	var down := in_bottom_band()
	var goal := clampf(aim_x, -tuning.aim_x_margin, count - 1 + tuning.aim_x_margin) if down else float(pick)
	var rate := tuning.slide_ease if down else tuning.settle_ease
	tip_x += (goal - tip_x) * minf(1.0, rate * dt)
	if down:
		var near := clampi(roundi(tip_x), 0, count - 1)
		if near != pick and absf(tip_x - pick) > tuning.slot_hysteresis:
			pick = near


# The pick on `pin`: the prototype's three cases (jammed, binding, free), the other pins falling, the
# overset check, the binding pin's events and the scrape.
func _step_lift(dt: float, pin: Pin) -> void:
	var binding := _binding_here()
	var active := tension >= params.drop
	var prev_tip := tip
	var ease := minf(1.0, tuning.tip_ease * dt)
	force = 0.0
	if pin.overset:
		# Jammed: the pick cannot lift the pin further; prying it strains the pick.
		if target < tip:
			tip += (target - tip) * ease
		else:
			tip = minf(pin.height, tip + (target - tip) * ease)
		force = maxf(0.0, target - tip)
		_strain(force, tuning.strain_rate_overset, true, dt)
	elif binding and active and not pin.is_set:
		var stuck := (
			pin.type == SPOOL
			and pin.spool == Spool.FALSE_SET
			and tension > pin.false_tension - tuning.stuck_spool_margin
		)
		var required := tuning.lift_required_base + tuning.lift_required_tension * tension * tension + pin.bump
		if target > tip:
			force = target - tip
			if not stuck:
				tip = minf(target, tip + maxf(0.0, force - required) * tuning.lift_rate * dt)
		else:
			tip += (target - tip) * ease
		pin.height = tip
		var hard := tension > params.high - tuning.hard_margin or stuck
		var gain := tuning.strain_rate * (1.0 + maxf(0.0, tension - params.high) * tuning.strain_high_tension)
		_strain(force, gain, hard, dt)
		pin.bump = maxf(0.0, pin.bump - dt * tuning.bump_decay)
	else:
		tip += (target - tip) * ease
		strain = maxf(0.0, strain - tuning.strain_relief * dt)
		# The key pin rests on the tip, set or not (a set pin's driver stays caught above the shear line).
		pin.height = tip
	_fall_others(dt)
	var tol := _tolerance()
	_check_overset(pin, binding, tol)
	if binding and active and not pin.is_set and not pin.overset:
		_pin_events(pin, tol, dt)
	var speed := absf(tip - prev_tip) / maxf(dt, 0.001)
	var rubbing := binding and active and not pin.is_set and not pin.overset and speed > tuning.scrape_speed
	scraping = minf(1.0, speed * tuning.scrape_gain) if rubbing else 0.0
	if rubbing and _clock - _last_scrape > tuning.scrape_noise_interval:
		_last_scrape = _clock
		_emit(&"scrape", &"", "")


func _strain(p_force: float, gain: float, hard: bool, dt: float) -> void:
	if p_force > tuning.strain_force and hard:
		strain += (p_force - tuning.strain_force) * gain * dt
	else:
		strain = maxf(0.0, strain - tuning.strain_relief * dt)


func _fall_others(dt: float) -> void:
	for i in pins.size():
		var other := pins[i]
		if i != pick and not other.overset:
			other.height = maxf(0.0, other.height - tuning.pin_fall_rate * dt)


func _binding_here() -> bool:
	return not any_overset() and binding_index() == pick


# The lift tolerance around the shear line: the picker's, the lock's, narrower above the sweet spot.
func _tolerance() -> float:
	var over := 1.0
	if tension > params.high:
		over = maxf(tuning.over_floor, 1.0 - tuning.over_slope * (tension - params.high) / (1.0 - params.high))
	return (tuning.base_tolerance + params.tolerance_bonus) * tolerance_mult * over


# Overset: with the plug turning (tension at the sweet spot's low edge or above), the binding pin's
# key pin pushed past the shear line (beyond the tolerance) jams in the housing. Set and loose pins
# overset only when shoved `set_overset` further; a set pin that oversets is no longer set.
func _check_overset(pin: Pin, binding: bool, tol: float) -> void:
	if tension < params.low or pin.overset:
		return
	if (pin.is_set or not binding) and pin.height > pin.shear + tol + tuning.set_overset:
		if pin.is_set:
			pin.is_set = false
			_set_stack.erase(pick)
		_overset(pin)
	elif not pin.is_set and binding and pin.height > pin.shear + tol:
		_overset(pin)


# The binding pin's false set, ticks, counter-rotation and set (after the dwell).
func _pin_events(pin: Pin, tol: float, dt: float) -> void:
	var height := pin.height
	if pin.type == SPOOL and pin.spool == Spool.NONE and tension >= params.low and height >= pin.false_lift - tol:
		_false_set(pin)
	if pin.type == SERRATED:
		for k in pin.levels.size():
			if pin.ticks & (1 << k) == 0 and height >= pin.levels[k] and tension >= params.low:
				pin.ticks |= 1 << k
				pin.bump = tuning.tick_bump
				tick_turn += tuning.tick_turn
				nudge = tuning.nudge_tick
				_emit(&"tick", &"tick", "tick")
	if pin.spool == Spool.FALSE_SET:
		var progress := clampf((height - pin.false_lift) / (pin.shear - pin.false_lift), 0.0, 1.0)
		var extra := tuning.false_set_turn * (1.0 - progress)
		if extra < false_turn - tuning.creak_step and _clock - _last_creak > tuning.creak_interval:
			_last_creak = _clock
			_emit(&"creak", &"creak", "creak, the plug pushes back")
		false_turn = minf(false_turn, extra)
	var can_set := tension >= params.low if pin.type != SPOOL else pin.spool == Spool.FALSE_SET
	# It sets only after staying at the shear line for the dwell: lifted through it too fast, the key
	# pin is carried past it (the overset above).
	if can_set and height >= pin.shear - tol and height <= pin.shear + tol:
		pin.dwell += dt
		if pin.dwell >= params.set_dwell:
			_set_pin(pick)
	else:
		pin.dwell = 0.0


func _set_pin(index: int) -> void:
	var pin := pins[index]
	pin.is_set = true
	if pin.type == SPOOL:
		pin.spool = Spool.SET
	pin.bump = 0.0
	pin.dwell = 0.0
	aim_bias += maxf(0.0, target - tip)
	_set_stack.append(index)
	false_turn = 0.0
	var muted := tension > params.high
	nudge = tuning.nudge_set_muted if muted else tuning.nudge_set
	_emit(&"set", &"click_muted" if muted else &"click", "(muffled click)" if muted else "click")
	if set_count() == pins.size():
		opened = true
		open_t = 0.0
		_open_delay = tuning.open_sound_delay


func _overset(pin: Pin) -> void:
	pin.overset = true
	nudge = tuning.nudge_overset
	_emit(&"overset", &"jam", "clunk, a pin is overset: release the tension to reset")


func _false_set(pin: Pin) -> void:
	pin.spool = Spool.FALSE_SET
	pin.false_tension = tension
	false_turn = tuning.false_set_turn
	nudge = tuning.nudge_false_set
	_emit(&"false_set", &"clunk", "deep clunk, the plug turns further")


# Too little tension: at 0 % every pin drops; below the drop threshold the last set pin drops every
# `drop_delay` seconds.
func _step_drops(dt: float) -> void:
	if tension <= tuning.release_tension:
		if any_progress():
			_reset_progress()
			_emit(&"drop", &"drop", "pins drop")
		_drop_timer = 0.0
	elif tension < params.drop:
		_drop_timer += dt
		if _drop_timer >= params.drop_delay and not _set_stack.is_empty():
			_drop_last()
			_drop_timer = 0.0
	else:
		_drop_timer = 0.0


func _drop_last() -> void:
	var index: int = _set_stack.pop_back()
	var pin := pins[index]
	pin.is_set = false
	pin.spool = Spool.NONE
	pin.ticks = 0
	_emit(&"drop", &"drop", "a pin drops")


# Raking: fast back-and-forth strokes of the tip in the bottom band. Each reversal of a stroke faster
# than `rake_speed` is one stroke: a tick, the scrape, a rake noise (throttled). Every lock rattles; on
# a rakeable lock a raking picker with tension from the drop threshold to the sweet spot's top and no
# pin overset sets the binding pin every `rake_strokes` strokes; otherwise a caption says why.
func _step_rake(dt: float, prev_tip_x: float) -> void:
	var speed_x := (tip_x - prev_tip_x) / maxf(dt, 0.001)
	_rake_gap += dt
	if _rake_gap > tuning.rake_gap:
		_rake_dir = 0
		_rake = 0
	if not in_bottom_band() or absf(speed_x) <= tuning.rake_speed:
		return
	scraping = maxf(scraping, minf(1.0, absf(speed_x) / tuning.rake_scrape_speed))
	var direction := 1 if speed_x > 0.0 else -1
	if direction == _rake_dir:
		return
	if _rake_dir != 0:
		_rake_stroke()
	_rake_dir = direction
	_rake_gap = 0.0


func _rake_stroke() -> void:
	nudge = maxf(nudge, tuning.nudge_rake)
	_emit(&"rake_stroke", &"tick", "")
	if _clock - _last_scrape > tuning.rake_noise_interval:
		_last_scrape = _clock
		_emit(&"rake", &"", "")
	if not (params.rake and rakeable):
		return
	var jammed := any_overset()
	if tension >= params.drop and tension <= params.high and not jammed:
		_rake += 1
		if _rake >= tuning.rake_strokes:
			_rake = 0
			var index := binding_index()
			if index >= 0:
				_set_pin(index)
	elif _clock - _last_rake_hint > tuning.rake_hint_interval:
		_last_rake_hint = _clock
		var hint := "rattle: too much tension, the pins bind"
		if jammed:
			hint = "rattle: a pin is overset, release the tension"
		elif tension < params.drop:
			hint = "rattle: the pins bounce back, add a little tension"
		_emit(&"rake_hint", &"", hint)


func _break_pick() -> void:
	nudge = tuning.nudge_snap
	_emit(&"snap", &"snap", "SNAP, the pick breaks")
	tension = 0.0
	_release_pick()
	_reset_progress()


func _release_pick() -> void:
	aim = 0.0
	aim_bias = 0.0
	target = 0.0
	tip = 0.0


func _step_relayout(dt: float) -> void:
	if relayout_t >= 1.0:
		return
	relayout_t = minf(1.0, relayout_t + dt / tuning.relayout_time)
	var eased := 1.0 - pow(1.0 - relayout_t, 3.0)
	for pin in pins:
		pin.shown_shear = lerpf(pin.shear_from, pin.shear, eased)


func _reset_progress() -> void:
	for pin in pins:
		pin.reset()
	_set_stack.clear()
	strain = 0.0
	_drop_timer = 0.0
	false_turn = 0.0
	tick_turn = 0.0
	_rake = 0


func _emit(kind: StringName, cue: StringName, caption: String) -> void:
	events.append(Event.new(kind, cue, caption, tuning.loudness(kind)))


static func _shuffle(items: Array, rng: RandomNumberGenerator) -> void:
	for i in range(items.size() - 1, 0, -1):
		var j := floori(rng.randf() * (i + 1))
		var swap: Variant = items[i]
		items[i] = items[j]
		items[j] = swap
