class_name DeckIceView
extends MarginContainer
## The deck's Icebreaker tool (ADR 0113): the picked account's letters locking in, the progress bar,
## Start / Stop / Resume, and the Computer skill's assists (Trained: time left; Advanced: + the trace
## to finish). Filled aside and reconciled (DeckStyle.reconcile()): Start / Stop keeps its node while
## the crack runs, so a still cursor keeps its hover.

## "Back to the map" after a crack.
signal map_requested
## Start / Stop / Resume pressed: the deck refreshes.
signal refresh_requested

const TEXT_WIDTH: float = 480.0
const BAR_WIDTH: float = 520.0

var session: DeckSession
var ice: IcebreakerTool
var column: VBoxContainer

var _signature: String = ""


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
	var locked := job.locked_letters()
	for i in job.password.length():
		var shown := job.password[i] if i < locked else "·"
		var cell := DeckStyle.mono(shown, DeckStyle.TITLE_COLOR if i < locked else DeckStyle.DIM_COLOR, 20)
		cell.custom_minimum_size = Vector2(34, 44)
		cell.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cell.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		cell.theme_type_variation = &"DeckLetterLocked" if i < locked else &"DeckLetter"
		letters.add_child(cell)
	return letters


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
