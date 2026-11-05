extends CanvasLayer
## Autoload: in-game developer panel. Systems add their own tabs through register_tab().

const EVENT_LOG_TAB: PackedScene = preload("res://ui/debug_panel/tabs/event_log_tab.tscn")

var _mouse_mode_before_open: Input.MouseMode = Input.MOUSE_MODE_VISIBLE

@onready var _tabs: TabContainer = $TabContainer


func _ready() -> void:
	register_tab("Event Log", EVENT_LOG_TAB.instantiate() as Control)


# _input rather than _unhandled_input so the toggle still works while a tab's text field has focus.
func _input(event: InputEvent) -> void:
	if event.is_action_pressed(&"debug_panel_toggle"):
		set_open(not is_open())
		get_viewport().set_input_as_handled()


func register_tab(title: String, content: Control) -> void:
	_tabs.add_child(content)
	_tabs.set_tab_title(_tabs.get_tab_idx_from_control(content), title)


func is_open() -> bool:
	return visible


func set_open(open: bool) -> void:
	if open == visible:
		return
	if open:
		_mouse_mode_before_open = Input.mouse_mode
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	else:
		Input.mouse_mode = _mouse_mode_before_open
	visible = open
