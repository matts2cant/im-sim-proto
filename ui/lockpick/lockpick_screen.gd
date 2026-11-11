class_name LockpickScreen
extends CanvasLayer
## The lockpicking minigame (ADR 0073, 0107), child of its user (the Player). A MechanicalLock opens
## it when the user works the lock with a lockpick (LMB with the pick selected). The game keeps
## running (it is not a pause screen): while it is open the player's input is off (no walking, no
## looking), the mouse stays captured and the camera turns to face the lock.
## A thin adapter over PinTumbler (built by the lock with the picker's LockpickParams): W / S raise
## and lower tension (Shift: fine steps; it holds where left), A / D move the pick between pins,
## relative mouse Y moves the lift target, holding LMB rakes (Master, Simple locks). Each model event
## plays its LockpickAudio cue, shows its caption (assist 2+) and makes its noise from the lock.
## The centred panel draws the front view (LockpickFrontView, with the tension gauge at assist 1+),
## the pins view under it at assist 3 (LockpickPinsView); a practice lock shows all of them and its
## layout counter.
## Leaving: E or Esc (the game menu does not open), damage, the user unable to act, the lock unlocked
## by other means, out of reach, or no lockpicks left after one breaks. Leaving loses all progress.
## A broken pick uses up one of the user's lockpicks. A picked real lock closes the screen once the
## plug has turned; a practice lock stays open, re-locks with a new layout and can be picked again.

signal closed(reason: StringName)

const DEFAULT_TUNING: LockpickTuning = preload("res://objects/locks/lockpicking/lockpick_tuning.tres")
const HINT := "W / S  tension (Shift: fine)  ·  A / D  pin  ·  Mouse  lift  ·  E / Esc  leave"
const RAKE_HINT := "  ·  Hold LMB  rake"
const OUT_OF_PICKS := "Out of lockpicks"
const NEW_LAYOUT := "new pin layout"
const CAPTION_FADE := 0.25
const PANEL_WIDTH := 0.42
## The bottom of the screen kept free for the HUD's belt (fraction of the height).
const BELT_MARGIN := 0.13
## Room for the gaps and the hint line under the views (px).
const COLUMN_EXTRA := 44.0
const PIN_VIEW_RATIO := 6.0 / 16.0

@export var tuning: LockpickTuning

var lock: MechanicalLock
## The node picking (its parent).
var user: Node
var player: Player
var model: PinTumbler
## Assist level of this attempt (LockpickParams: 0 sound, 1 gauge, 2 captions, 3 pins view).
var assist: int = 0
var caption_text: String = ""
var caption_left: float = 0.0

## Fonts and gradients of the views.
var style := LockpickStyle.new()
var front: LockpickFrontView
var pins_view: LockpickPinsView
var caption_panel: PanelContainer
var caption_label: Label
var tag_label: Label
var hint_label: Label

var _input_before: bool = true
var _mouse_before: Input.MouseMode = Input.MOUSE_MODE_CAPTURED
var _close_left: float = -1.0
var _body: BodyParts = null
var _center: CenterContainer

@onready var audio: LockpickAudio = $Audio


func _ready() -> void:
	visible = false
	if tuning == null:
		tuning = DEFAULT_TUNING
	user = get_parent()
	player = user as Player
	_build()
	get_viewport().size_changed.connect(_layout)
	_layout()


func _exit_tree() -> void:
	if visible:
		close(&"gone")


## The LockpickScreen child of `node`, or null.
static func of(node: Node) -> LockpickScreen:
	if node == null:
		return null
	for child in node.get_children():
		if child is LockpickScreen:
			return child as LockpickScreen
	return null


func is_open() -> bool:
	return visible


func shows_gauge() -> bool:
	return LockpickParams.shows_gauge(assist)


func shows_captions() -> bool:
	return LockpickParams.shows_captions(assist)


func shows_pins() -> bool:
	return LockpickParams.shows_pins(assist)


## Starts picking `p_lock` for `p_user` (its parent).
func open_for(p_lock: MechanicalLock, p_user: Node) -> void:
	if visible or p_lock == null:
		return
	lock = p_lock
	user = p_user
	var params := LockpickParams.from_entity(user, tuning)
	model = lock.new_model(params)
	assist = LockpickParams.assist_for(params.assist, lock.is_practice())
	_layout()
	_close_left = -1.0
	caption_text = ""
	caption_left = 0.0
	lock.relocked.connect(_on_relocked)
	_body = BodyParts.of(user)
	if _body != null:
		_body.damaged.connect(_on_damaged)
	visible = true
	if player != null:
		_input_before = player.input_enabled
		player.input_enabled = false
		player.face_towards(lock.noise_origin(), tuning.face_time)
	_mouse_before = Input.mouse_mode
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	lock.pick_started(user)
	refresh()


## Leaves without opening it (`reason`: left, damage, cannot_act, unlocked, out_of_reach, no_picks):
## tension is released and every pin drops.
func leave(reason: StringName = &"left") -> void:
	if not visible:
		return
	if is_instance_valid(lock):
		lock.pick_cancelled(user, reason)
	close(reason)


func close(reason: StringName = &"left") -> void:
	if not visible:
		return
	visible = false
	audio.stop_all()
	if is_instance_valid(lock) and lock.relocked.is_connected(_on_relocked):
		lock.relocked.disconnect(_on_relocked)
	if is_instance_valid(_body) and _body.damaged.is_connected(_on_damaged):
		_body.damaged.disconnect(_on_damaged)
	_body = null
	lock = null
	model = null
	if player != null:
		player.input_enabled = _input_before
		player.resync_actions()
	Input.mouse_mode = _mouse_before
	closed.emit(reason)


## Relative mouse motion of `pixels` down the screen (negative: up) moves the lift target.
func lift_by_pixels(pixels: float) -> void:
	if model != null:
		model.add_lift(-pixels * tuning.lift_per_pixel)


## Brings the labels and views up to date (also called every frame).
func refresh() -> void:
	if model == null:
		return
	pins_view.visible = shows_pins()
	caption_panel.visible = shows_captions() and caption_left > 0.0
	caption_panel.modulate.a = minf(1.0, caption_left / CAPTION_FADE)
	caption_label.text = caption_text
	tag_label.text = _tag_text()
	var raking := model.params.rake and model.rakeable
	hint_label.text = HINT + (RAKE_HINT if raking else "")
	front.queue_redraw()
	if pins_view.visible:
		pins_view.queue_redraw()


func _physics_process(delta: float) -> void:
	if not visible:
		return
	var reason := _leave_reason()
	if not reason.is_empty():
		leave(reason)
		return
	model.params = LockpickParams.from_entity(user, tuning)
	var direction := int(Input.is_action_pressed(&"lockpick_tension_up"))
	direction -= int(Input.is_action_pressed(&"lockpick_tension_down"))
	model.step(delta, direction, Input.is_action_pressed(&"lockpick_fine"), Input.is_action_pressed(&"fire"))
	audio.set_scrape(model.scraping, model.tension)
	audio.set_strain(model.strain)
	_handle(model.take_events())
	if not visible:
		return
	caption_left = maxf(0.0, caption_left - delta)
	if model.opened and not lock.is_practice():
		if _close_left < 0.0:
			_close_left = tuning.close_after_open
		_close_left -= delta
		if _close_left <= 0.0:
			close(&"picked")


func _process(_delta: float) -> void:
	if visible:
		refresh()


func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed(&"ui_cancel") or event.is_action_pressed(&"use"):
		leave(&"left")
		get_viewport().set_input_as_handled()
		return
	var motion := event as InputEventMouseMotion
	if motion != null:
		lift_by_pixels(motion.screen_relative.y)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed(&"lockpick_prev_pin"):
		model.move_pick(-1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed(&"lockpick_next_pin"):
		model.move_pick(1)
		get_viewport().set_input_as_handled()


# Why the attempt must end now, or &"" (an open lock only ends on the user's own state).
func _leave_reason() -> StringName:
	if not is_instance_valid(lock) or not is_instance_valid(user):
		return &"gone"
	if not ActorState.can_act(user):
		return &"cannot_act"
	if model.opened:
		return &""
	if not lock.is_locked():
		return &"unlocked"
	var eye := player.eye_transform().origin if player != null else (user as Node3D).global_position
	if eye.distance_to(lock.noise_origin()) > tuning.leave_distance:
		return &"out_of_reach"
	return &""


func _handle(events: Array[PinTumbler.Event]) -> void:
	for event in events:
		if not event.cue.is_empty():
			audio.play(event.cue)
		if not event.caption.is_empty():
			_caption(event.caption)
		lock.pick_noise(event.loudness)
		if event.kind == &"open":
			lock.complete_pick(user)
		elif event.kind == &"snap":
			_pick_broke()
		if not visible:
			return


# A pick snapped: one lockpick is used up; with none left the attempt ends.
func _pick_broke() -> void:
	lock.pick_broke(user)
	if player == null:
		return
	if player.inventory.use_up_tool(lock.data.tool) > 0:
		return
	var hud := player.get_node_or_null(^"Hud") as Hud
	if hud != null:
		hud.show_message(OUT_OF_PICKS)
	leave(&"no_picks")


func _caption(text: String) -> void:
	caption_text = text
	caption_left = tuning.caption_time


func _tag_text() -> String:
	if lock.is_practice():
		return "Practice lock · %s · Layout %d" % [lock.tier_name(), lock.layout_number()]
	return "Pin tumbler · %d pins" % model.pins.size()


func _on_relocked(_layout_number: int) -> void:
	if model == null:
		return
	lock.relayout(model)
	audio.play(&"relock")
	_caption(NEW_LAYOUT)


func _on_damaged(_part: StringName, _type: StringName, _amount: float) -> void:
	leave(&"damage")


func _build() -> void:
	var center := CenterContainer.new()
	center.name = "Center"
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_center = center
	add_child(center)
	var column := VBoxContainer.new()
	column.name = "Column"
	column.add_theme_constant_override(&"separation", 8)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.add_child(column)
	front = LockpickFrontView.new()
	front.name = "Front"
	front.screen = self
	front.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	column.add_child(front)
	tag_label = _label(12, Color("8d99a5"))
	tag_label.name = "Tag"
	tag_label.position = Vector2(12, 8)
	front.add_child(tag_label)
	caption_panel = PanelContainer.new()
	caption_panel.name = "Caption"
	caption_panel.add_theme_stylebox_override(&"panel", LockpickStyle.caption_box())
	caption_panel.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	caption_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	caption_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	caption_panel.offset_bottom = -14.0
	front.add_child(caption_panel)
	caption_label = _label(13, Color("e4e8ec"))
	caption_panel.add_child(caption_label)
	pins_view = LockpickPinsView.new()
	pins_view.name = "Pins"
	pins_view.screen = self
	pins_view.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	column.add_child(pins_view)
	hint_label = _label(13, Color("c9d3dc"))
	hint_label.name = "Hint"
	hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint_label.add_theme_color_override(&"font_shadow_color", Color(0, 0, 0, 0.9))
	hint_label.add_theme_constant_override(&"shadow_offset_x", 1)
	hint_label.add_theme_constant_override(&"shadow_offset_y", 1)
	column.add_child(hint_label)


func _label(font_size: int, colour: Color) -> Label:
	var label := Label.new()
	label.add_theme_font_override(&"font", style.mono_font())
	label.add_theme_font_size_override(&"font_size", font_size)
	label.add_theme_color_override(&"font_color", colour)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


# The front panel about 45 % of the screen (4:3), the pins view under it at the same width, the
# whole column centred above the HUD's belt.
func _layout() -> void:
	var screen_size := get_viewport().get_visible_rect().size
	var margin := screen_size.y * BELT_MARGIN
	_center.offset_bottom = -margin
	var stack := 0.75 + (PIN_VIEW_RATIO if shows_pins() else 0.0)
	var width := minf(screen_size.x * PANEL_WIDTH, (screen_size.y - margin - COLUMN_EXTRA) / stack)
	front.custom_minimum_size = Vector2(width, width * 0.75).round()
	pins_view.custom_minimum_size = Vector2(width, width * PIN_VIEW_RATIO).round()
	hint_label.custom_minimum_size = Vector2(width, 0)
