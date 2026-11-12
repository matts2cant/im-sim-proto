class_name DeckIceView
extends MarginContainer
## The deck's Icebreaker tool (ADR 0113): the picked account's letters locking in, the progress bar,
## Start / Stop / Resume, and the Computer skill's assists (Trained: time left; Advanced: + the trace
## to finish). Filled aside and reconciled (DeckStyle.reconcile()): Start / Stop keeps its node while
## the crack runs, so a still cursor keeps its hover.
## The scramble (playtest 2026-11-12, approved mockup design/prototypes/icebreaker_scramble.html):
## while the crack runs, the next letter's cell cycles through random characters (SCRAMBLE_RATE a
## second, never the real letter, its colour alternating title / assist blue), and a letter that
## locks flashes (DeckLetterFlash, fading over FLASH_TIME). Display only: animate() updates those
## cells in place every frame; the timing is the Icebreaker's.

## "Back to the map" after a crack.
signal map_requested
## Start / Stop / Resume pressed: the deck refreshes.
signal refresh_requested

const TEXT_WIDTH: float = 480.0
const BAR_WIDTH: float = 520.0
## Characters the scrambling cell shows a second, and what it draws them from.
const SCRAMBLE_RATE: float = 22.0
const SCRAMBLE_CHARS: String = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789#$%&@!?*"
## Seconds a locked letter's flash takes to fade out.
const FLASH_TIME: float = 0.25
const DOT: String = "·"

var session: DeckSession
var ice: IcebreakerTool
var column: VBoxContainer
## Draws the scramble's characters (seed it for a deterministic test).
var rng := RandomNumberGenerator.new()
## What the scrambling cell shows now ("" while nothing scrambles).
var scramble_char: String = ""

var _signature: String = ""
var _letters_box: HBoxContainer
var _scramble_blue: bool = false
var _scramble_left: float = 0.0
var _flash_index: int = -1
var _flash_left: float = 0.0
var _seen_key: String = ""
var _seen_locked: int = -1


func _init() -> void:
	name = "Icebreaker"
	theme_type_variation = &"WindowBody"
	set_anchors_preset(Control.PRESET_FULL_RECT)
	column = VBoxContainer.new()
	column.add_theme_constant_override(&"separation", WindowFrame.metric(&"space_l"))
	add_child(column)


func bind(p_session: DeckSession, p_ice: IcebreakerTool) -> void:
	session = p_session
	ice = p_ice
	_signature = ""


## Forgets what it shows: the next refresh rebuilds.
func invalidate() -> void:
	_signature = ""


func refresh() -> void:
	if session == null or ice == null:
		return
	var job := ice.job
	var assist := Icebreaker.assist(session.entity)
	var mult := Icebreaker.crack_mult(session.entity)
	var signature := "none"
	if job != null:
		signature = (
			"%s|%d|%s|%s|%d" % [job.key, job.locked_letters(), job.running, job.is_done(), roundi(job.progress * 200.0)]
		)
	signature += "|%d|%s" % [assist, mult]
	if signature == _signature:
		return
	_signature = signature
	# Filled aside, then reconciled: Start / Stop keeps its node while the crack runs.
	var fresh := VBoxContainer.new()
	_fill(fresh, job, assist, mult)
	DeckStyle.reconcile(column, fresh)


func _process(delta: float) -> void:
	animate(delta)


## Advances the scramble and the lock flash by `delta` seconds and updates their cells in place
## (called every frame; tests call it directly). Hidden, nothing scrambles or flashes: a letter that
## locked while the view was not shown does not flash when it opens.
func animate(delta: float) -> void:
	var job := ice.job if ice != null else null
	if job == null or not is_visible_in_tree():
		_seen_key = job.key if job != null else ""
		_seen_locked = job.locked_letters() if job != null else -1
		scramble_char = ""
		_flash_left = 0.0
		return
	var locked := job.locked_letters()
	var previous_flash := _flash_index
	if job.key == _seen_key and locked > _seen_locked:
		_flash_index = locked - 1
		_flash_left = FLASH_TIME
		_scramble_left = 0.0
	elif _flash_left > 0.0:
		_flash_left = maxf(0.0, _flash_left - delta)
	_seen_key = job.key
	_seen_locked = locked
	if is_scrambling(job):
		_scramble_left -= delta
		if _scramble_left <= 0.0 or scramble_char.is_empty():
			_roll(job.password[locked])
			# Never more than one change a frame, and no catching up after a long frame.
			_scramble_left = maxf(_scramble_left + 1.0 / SCRAMBLE_RATE, 0.5 / SCRAMBLE_RATE)
	else:
		scramble_char = ""
	_update_cells(job, [previous_flash, _flash_index, locked - 1, locked])


## Whether `job`'s next letter scrambles: the crack runs and letters are left.
func is_scrambling(job: Icebreaker) -> bool:
	return job != null and job.running and not job.is_done() and job.locked_letters() < job.password.length()


## The letter cells shown now (Labels; empty without a job).
func letter_cells() -> Array[Label]:
	var cells: Array[Label] = []
	if is_instance_valid(_letters_box) and not _letters_box.is_queued_for_deletion():
		for child in _letters_box.get_children():
			cells.append(child as Label)
	return cells


## How far the flash on cell `index` has left to fade (1 just locked, 0 none).
func flash_amount(index: int) -> float:
	return _flash_left / FLASH_TIME if index == _flash_index else 0.0


# A random character other than `real` for the scrambling cell; its colour alternates.
func _roll(real: String) -> void:
	var picked := real
	while picked == real:
		picked = SCRAMBLE_CHARS[rng.randi_range(0, SCRAMBLE_CHARS.length() - 1)]
	scramble_char = picked
	_scramble_blue = not _scramble_blue


# Updates the scrambling cell and the flashing one in place (the rest only change on a refresh).
func _update_cells(job: Icebreaker, indices: Array[int]) -> void:
	var cells := letter_cells()
	if cells.size() != job.password.length():
		return
	for i in indices:
		if i >= 0 and i < cells.size():
			_show_cell(cells[i], i, job)


func _fill(target: VBoxContainer, job: Icebreaker, assist: int, mult: float) -> void:
	if job == null:
		target.add_child(DeckStyle.label("Icebreaker", DeckStyle.TITLE_COLOR, 20))
		target.add_child(
			DeckStyle.paragraph(
				"Pick an account on the Map to crack its password. Progress stays on the deck if you stop.",
				DeckStyle.DIM_COLOR,
				14,
				TEXT_WIDTH
			)
		)
		var names := PackedStringArray()
		for strength in range(Icebreaker.max_strength(session.entity) + 1):
			names.append(DeviceAccount.strength_name(strength as DeviceAccount.Strength))
		target.add_child(
			DeckStyle.paragraph(
				"What your Computer skill can crack: %s." % ", ".join(names), DeckStyle.DIM_COLOR, 14, TEXT_WIDTH
			)
		)
		return
	target.add_child(DeckStyle.label("Icebreaker · %s@%s" % [job.user, job.host], DeckStyle.TITLE_COLOR, 20))
	var strength_line := (
		"Password strength %s · base %s · deterministic"
		% [DeviceAccount.strength_name(job.strength as DeviceAccount.Strength), DeckStyle.seconds(job.base_time)]
	)
	target.add_child(DeckStyle.mono(strength_line, DeckStyle.DIM_COLOR, 12))
	target.add_child(_letters(job))
	var bar := DeckStyle.track(BAR_WIDTH, 10.0, job.progress, DeckStyle.TITLE_COLOR)
	bar.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	target.add_child(bar)
	target.add_child(_actions(job, assist, mult))
	var note := "Adds trace while it runs (4 %%/s x your skill's trace gain) to every tracer watching %s." % job.host
	if is_instance_valid(ice.device):
		var gain := Tracer.highest_gain(ice.device)
		if gain > 0.0:
			note = (
				"Adds trace while it runs (%s %%/s x your skill's trace gain) to every tracer watching %s."
				% [DeckStyle.number(gain), job.host]
			)
	target.add_child(DeckStyle.paragraph(note, DeckStyle.DIM_COLOR, 12, TEXT_WIDTH))


func _letters(job: Icebreaker) -> HBoxContainer:
	var letters := HBoxContainer.new()
	letters.name = "Letters"
	letters.add_theme_constant_override(&"separation", 6)
	for i in job.password.length():
		var cell := DeckStyle.mono(DOT, DeckStyle.DIM_COLOR, 20)
		cell.custom_minimum_size = Vector2(34, 44)
		cell.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cell.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_show_cell(cell, i, job)
		letters.add_child(cell)
	_letters_box = letters
	return letters


# Shows cell `i` of `job`: locked (the letter, flashing just after it locked), scrambling (a random
# character) or not yet found (a dot). Sets only what changed.
func _show_cell(cell: Label, i: int, job: Icebreaker) -> void:
	var locked := job.locked_letters()
	var text := DOT
	var color := DeckStyle.DIM_COLOR
	var variation := &"DeckLetter"
	if i < locked:
		text = job.password[i]
		color = DeckStyle.TITLE_COLOR.lerp(Color.WHITE, flash_amount(i))
		variation = &"DeckLetterLocked"
	elif i == locked and is_scrambling(job) and not scramble_char.is_empty():
		text = scramble_char
		color = DeckStyle.SELF_COLOR if _scramble_blue else DeckStyle.TITLE_COLOR
		variation = &"DeckLetterActive"
	if cell.text != text:
		cell.text = text
	if cell.get_theme_color(&"font_color") != color:
		cell.add_theme_color_override(&"font_color", color)
	if cell.theme_type_variation != variation:
		cell.theme_type_variation = variation
	var flash := cell.get_node_or_null(^"Flash") as Panel
	var amount := flash_amount(i) if i < locked else 0.0
	if amount <= 0.0:
		if flash != null:
			cell.remove_child(flash)
			flash.free()
		return
	if flash == null:
		# Over the cell (a Label draws its box and text in one go): the theme's translucent teal fill.
		flash = Panel.new()
		flash.name = "Flash"
		flash.theme_type_variation = &"DeckLetterFlash"
		flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
		flash.set_anchors_preset(Control.PRESET_FULL_RECT)
		cell.add_child(flash)
	flash.modulate.a = amount


func _actions(job: Icebreaker, assist: int, mult: float) -> HFlowContainer:
	var actions := HFlowContainer.new()
	actions.add_theme_constant_override(&"h_separation", WindowFrame.metric(&"space_s"))
	actions.add_theme_constant_override(&"v_separation", WindowFrame.metric(&"space_s"))
	if job.is_done():
		actions.add_child(
			DeckStyle.label("Cracked: added to the Journal (Codes and logins)", DeckStyle.ACCESS_COLOR, 14)
		)
		var back := DeckStyle.button("Back to the map", 13)
		back.pressed.connect(map_requested.emit)
		actions.add_child(back)
		return actions
	var text := "Stop (keeps progress)" if job.running else ("Resume" if job.progress > 0.0 else "Start")
	var toggle := DeckStyle.button(text, 13, not job.running)
	toggle.pressed.connect(_on_toggle)
	actions.add_child(toggle)
	if assist >= Icebreaker.ASSIST_TIMES:
		actions.add_child(DeckStyle.assist("%s left" % DeckStyle.seconds(job.time_left(mult))))
	if assist >= Icebreaker.ASSIST_TRACE and is_instance_valid(ice.device):
		var trace := job.trace_to_finish(Tracer.highest_gain(ice.device), mult, Icebreaker.trace_mult(session.entity))
		actions.add_child(DeckStyle.assist("about +%d %% trace to finish" % roundi(trace)))
	return actions


func _on_toggle() -> void:
	if ice.job == null:
		return
	if ice.job.running:
		ice.stop()
	else:
		ice.resume()
	_signature = ""
	refresh_requested.emit()
