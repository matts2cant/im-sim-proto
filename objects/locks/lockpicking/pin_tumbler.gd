class_name PinTumbler
extends RefCounted
## Pure model of a pin-tumbler lock being picked (ADR 0073, 0107): a faithful port of the approved
## prototype's simulation (design/prototypes/lockpicking_bench.html `step()`). Under tension one pin
## binds at a time (the seeded binding order); the pick tip follows the lift target like a spring and,
## on a binding pin, lags behind it: that lag is the force. Lifting the binding pin to its shear line
## sets it (click), past it oversets it (jam, until tension is released); spools false-set (the plug
## turns further) and need tension eased while lifting (counter-rotation); serrated pins tick. Too
## little tension drops set pins (the last one every `drop_delay` s below the drop threshold, all at
## 0 %); forcing a bound pin at high tension or prying an overset strains the pick until it snaps.
## A Master rakes rakeable (Simple) locks by holding LMB.
## Changing pins (ADR 0107) drops the lift target to the bottom, lets the tip fall below the pins,
## then moves the pick across; lift input is ignored until it arrives and further presses queue.
## Events (set, overset, false_set, tick, creak, drop, snap, open, scrape) collect in `events` for
## the adapter (sound cue, caption, noise), which takes them with take_events().

enum Spool { NONE, FALSE_SET, SET }
enum Phase { NONE, DROP, MOVE }

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
	## Current lift.
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
## Pick tip lift and its target (mouse).
var tip: float = 0.0
var target: float = 0.0
## Pin under the pick, and its drawn position (eases across during a pin change).
var pick: int = 0
var pick_shown: float = 0.0
var strain: float = 0.0
## Tip lag on a binding or jammed pin (the bow of the pick).
var force: float = 0.0
## Rub of the binding pin, 0..1 (the scrape sound).
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
var _rake: float = 0.0
var _clock: float = 0.0
var _last_scrape: float = -INF
var _last_creak: float = -INF
var _open_delay: float = -1.0
var _started: bool = false
var _phase: Phase = Phase.NONE
var _goal: int = 0
var _move_from: int = 0
var _move_t: float = 0.0
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
	pick_shown = pick
	_goal = pick
	_phase = Phase.NONE
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
	target = 0.0
	tip = 0.0
	build(types, pin_seed, p_tolerance_mult, shuffle_types)
	# The old pins drop from where they were; the drawn shear lines ease to the new heights.
	for i in mini(old.size(), pins.size()):
		pins[i].height = old[i].height
		pins[i].shear_from = old[i].shown_shear
		pins[i].shown_shear = old[i].shown_shear
	relayout_t = 0.0 if tuning.relayout_time > 0.0 else 1.0
	_started = false
	elapsed = 0.0


## Mouse lift: moves the lift target by `amount` (0..1 of the range; up is positive). Ignored while
## the pick changes pins or the lock is open.
func add_lift(amount: float) -> void:
	if opened or is_changing_pin():
		return
	target = clampf(target + amount, 0.0, 1.0)


## A / D: moves the pick `direction` pins (queued while a change is under way).
func move_pick(direction: int) -> void:
	if opened or pins.is_empty() or direction == 0:
		return
	var goal := clampi(_goal + signi(direction), 0, pins.size() - 1)
	if goal == _goal:
		return
	_goal = goal
	target = 0.0
	if _phase == Phase.NONE:
		_phase = Phase.DROP


func is_changing_pin() -> bool:
	return _phase != Phase.NONE


## The pin the pick is heading to (the queued destination).
func goal() -> int:
	return _goal


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


## One tick: `tension_input` -1 / 0 / +1 (S / W), `fine` (Shift), `raking` (LMB held).
func step(dt: float, tension_input: int, fine: bool, raking: bool) -> void:
	_clock += dt
	nudge = maxf(0.0, nudge - dt * tuning.nudge_decay)
	_step_relayout(dt)
	if opened:
		open_t = minf(1.0, open_t + dt * tuning.open_rate)
		if _open_delay >= 0.0:
			_open_delay -= dt
			if _open_delay < 0.0:
				_emit(&"open", &"open", "the plug turns, unlocked")
		return
	var rate := tuning.tension_fine_rate if fine else tuning.tension_rate
	tension = clampf(tension + signi(tension_input) * rate * dt, 0.0, 1.0)
	if not _started and (tension > 0.0 or target > 0.05):
		_started = true
	if _started:
		elapsed += dt
	if pins.is_empty():
		return
	var pin := pins[pick]
	if is_changing_pin():
		_step_pin_change(dt, pin)
		_fall_others(dt)
		scraping = 0.0
	else:
		_step_lift(dt, pin)
	_step_drops(dt)
	_step_rake(dt, raking)
	if strain >= tuning.break_strain:
		_break_pick()


# The pick on `pin`: the prototype's three cases (jammed, binding, free), the other pins falling,
# the binding pin's events and the scrape.
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
		pin.height = minf(tip, pin.shear - tuning.set_pin_margin) if pin.is_set else tip
	_fall_others(dt)
	if binding and active and not pin.is_set and not pin.overset:
		_pin_events(pin)
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
	return not pins.any(func(pin: Pin) -> bool: return pin.overset) and binding_index() == pick


# The binding pin's false set, ticks, counter-rotation, set and overset.
func _pin_events(pin: Pin) -> void:
	var over := 1.0
	if tension > params.high:
		over = maxf(tuning.over_floor, 1.0 - tuning.over_slope * (tension - params.high) / (1.0 - params.high))
	var tol := (tuning.base_tolerance + params.tolerance_bonus) * tolerance_mult * over
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
	if can_set and height >= pin.shear - tol:
		if height <= pin.shear + tol:
			_set_pin(pick)
		else:
			_overset(pin)


func _set_pin(index: int) -> void:
	var pin := pins[index]
	pin.is_set = true
	if pin.type == SPOOL:
		pin.spool = Spool.SET
	pin.bump = 0.0
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
	_emit(&"overset", &"jam", "clunk, the pick hits a hard stop")


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


# A Master rakes a rakeable lock while LMB is held in the working window: a pin sets every
# `rake_time` seconds, the pick bouncing under it.
func _step_rake(dt: float, raking: bool) -> void:
	if not (params.rake and rakeable and raking and tension >= params.low and tension <= params.high):
		_rake = 0.0
		return
	_phase = Phase.NONE
	_rake += dt
	target = tuning.rake_base + tuning.rake_amplitude * absf(sin(_clock / tuning.rake_period))
	if _rake < tuning.rake_time:
		return
	_rake = 0.0
	var index := binding_index()
	if index >= 0:
		pick = index
		pick_shown = index
		_goal = index
		_set_pin(index)


func _break_pick() -> void:
	nudge = tuning.nudge_snap
	_emit(&"snap", &"snap", "SNAP, the pick breaks")
	tension = 0.0
	target = 0.0
	tip = 0.0
	_reset_progress()


# A pin change: the tip falls to the bottom (the pin under it follows, an overset stays jammed), then
# the pick moves across one pin per `pin_change_move_time` until it reaches the queued goal.
func _step_pin_change(dt: float, pin: Pin) -> void:
	target = 0.0
	force = 0.0
	strain = maxf(0.0, strain - tuning.strain_relief * dt)
	if _phase == Phase.DROP:
		var drop_time := maxf(tuning.pin_change_drop_time, 0.001)
		tip = maxf(0.0, tip - dt / drop_time)
		if not pin.overset:
			pin.height = minf(pin.height, tip)
		if tip <= 0.0:
			_start_move()
		return
	_move_t += dt
	var move_time := maxf(tuning.pin_change_move_time, 0.001)
	pick_shown = lerpf(_move_from, pick, minf(1.0, _move_t / move_time))
	if _move_t < move_time:
		return
	pick_shown = pick
	if pick != _goal:
		_start_move()
	else:
		_phase = Phase.NONE


func _start_move() -> void:
	_phase = Phase.MOVE
	_move_t = 0.0
	_move_from = pick
	pick += signi(_goal - pick)


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
	_rake = 0.0


func _emit(kind: StringName, cue: StringName, caption: String) -> void:
	events.append(Event.new(kind, cue, caption, tuning.loudness(kind)))


static func _shuffle(items: Array, rng: RandomNumberGenerator) -> void:
	for i in range(items.size() - 1, 0, -1):
		var j := floori(rng.randf() * (i + 1))
		var swap: Variant = items[i]
		items[i] = items[j]
		items[j] = swap
