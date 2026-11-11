extends GdUnitTestSuite
## Integration (the shared window frame, ADR 0113 / 0114 amendments): the deck's screen and the
## Halcyon OS overlay (login, desktop) in a WindowFrame sized as their 85 % panel in a 1152 x 648
## and a 2560 x 1440 window. Nothing with a background of its own (a panel, a button, a styled label,
## a colour rect, a map backdrop) reaches into the frame's rounded corners or covers its border, and
## the frame's border is drawn last; the header title, the sidebar items' text and the ✕ share the
## frame's inset, and the body's content starts one inset inside the body.

const WINDOWS: Array[Vector2] = [Vector2(1152, 648), Vector2(2560, 1440)]

var _holder: Node


func before_test() -> void:
	_holder = auto_free(Node.new())
	add_child(_holder)


func test_the_deck_frame_keeps_its_corners_and_insets() -> void:
	var screen := DeckScreen.new()
	_holder.add_child(screen)
	# No user or session here: keep it from closing itself.
	screen.set_process(false)
	screen.set_physics_process(false)
	screen.visible = true
	screen.show_tool(DeckScreen.Tool.ICEBREAKER)
	screen.ice_view.visible = true
	screen.ice_view.column.add_child(DeckStyle.label("Icebreaker", DeckStyle.TITLE_COLOR, 20))
	for window in WINDOWS:
		await _size(screen.frame, window)
		_assert_corners_clear(screen.frame, window)
		_assert_insets(screen.frame, screen.map_button, window)
		var inset := WindowFrame.metric(&"inset")
		var content := screen.ice_view.column.get_global_rect().position - screen.frame.body.get_global_rect().position
		assert_vector(content).override_failure_message("%s: body content at %s" % [window, content]).is_equal(
			Vector2(inset, inset)
		)
		assert_bool(screen.graph.draw_backdrop).is_false()


func test_the_computer_frame_keeps_its_corners_and_insets() -> void:
	var screen := ComputerScreen.new()
	_holder.add_child(screen)
	# No user or session here: keep it from closing itself.
	screen.set_process(false)
	screen.set_physics_process(false)
	screen.visible = true
	for desktop: bool in [false, true]:
		screen.login.visible = not desktop
		screen.desktop.visible = desktop
		screen.panel.set_sidebar_visible(desktop)
		for window in WINDOWS:
			await _size(screen.panel, window)
			var label := "%s %s" % ["desktop" if desktop else "login", window]
			_assert_corners_clear(screen.panel, label)
			_assert_insets(screen.panel, screen.dock_buttons[0] if desktop else null, label)
			if desktop:
				var list := screen.mail_app.get_child(0) as Control
				var content := (list.get_child(0) as Control).global_position - screen.panel.body.global_position
				assert_float(content.x).override_failure_message("%s: list at %s" % [label, content]).is_equal(
					float(WindowFrame.metric(&"inset"))
				)


# Places `frame` as an 85 % panel of `window` and lets the containers lay it out.
func _size(frame: WindowFrame, window: Vector2) -> void:
	frame.set_anchors_preset(Control.PRESET_TOP_LEFT)
	frame.position = window * 0.075
	frame.size = (window * 0.85).floor()
	for i in 3:
		await get_tree().process_frame


func _assert_corners_clear(frame: WindowFrame, label: Variant) -> void:
	var rect := frame.get_global_rect()
	var reach := float(WindowFrame.metric(&"radius") + WindowFrame.metric(&"border"))
	var corners: Array[Rect2] = [
		Rect2(rect.position, Vector2(reach, reach)),
		Rect2(Vector2(rect.end.x - reach, rect.position.y), Vector2(reach, reach)),
		Rect2(Vector2(rect.position.x, rect.end.y - reach), Vector2(reach, reach)),
		Rect2(rect.end - Vector2(reach, reach), Vector2(reach, reach)),
	]
	var inner := rect.grow(-WindowFrame.metric(&"border"))
	var painted := 0
	for node in frame.find_children("*", "Control", true, false):
		var control := node as Control
		if not control.is_visible_in_tree() or not _paints(control):
			continue
		painted += 1
		var area := control.get_global_rect()
		for corner in corners:
			(
				assert_bool(area.intersects(corner))
				. override_failure_message(
					"%s: %s %s reaches into corner %s" % [label, control.get_path(), area, corner]
				)
				. is_false()
			)
		(
			assert_bool(inner.encloses(area))
			. override_failure_message(
				"%s: %s %s covers the border (inside %s)" % [label, control.get_path(), area, inner]
			)
			. is_true()
		)
	assert_int(painted).is_greater(0)
	# The border is the frame's last child: drawn over everything inside.
	assert_str(frame.get_child(frame.get_child_count() - 1).name).is_equal("Border")


func _assert_insets(frame: WindowFrame, first_item: Button, label: Variant) -> void:
	var inset := float(WindowFrame.metric(&"inset"))
	var rect := frame.get_global_rect()
	var title := frame.title_label.get_global_rect()
	var close := frame.close_button.get_global_rect()
	assert_float(title.position.x - rect.position.x).override_failure_message("%s: title" % label).is_equal(inset)
	assert_float(rect.end.x - close.end.x).override_failure_message("%s: ✕ right" % label).is_equal(inset)
	assert_float(close.position.y).override_failure_message("%s: ✕ top %s, title %s" % [label, close, title]).is_equal(
		title.position.y
	)
	if first_item == null:
		return
	var text_x := first_item.global_position.x + first_item.get_theme_stylebox(&"normal").content_margin_left
	assert_float(text_x - rect.position.x).override_failure_message("%s: sidebar item text" % label).is_equal(inset)


# True when `control` paints a background of its own.
func _paints(control: Control) -> bool:
	if control is NetworkGraph:
		return (control as NetworkGraph).draw_backdrop
	if control is ColorRect:
		return (control as ColorRect).color.a > 0.0
	var style: StyleBox = null
	if control is PanelContainer or control is Panel:
		style = control.get_theme_stylebox(&"panel")
	elif control is Button and not (control as Button).flat:
		style = control.get_theme_stylebox(&"normal")
	elif control is Label or control is LineEdit:
		style = control.get_theme_stylebox(&"normal")
	var flat := style as StyleBoxFlat
	if flat == null:
		return false
	return (flat.draw_center and flat.bg_color.a > 0.0) or flat.border_width_left > 0
