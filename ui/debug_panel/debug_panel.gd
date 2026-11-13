extends CanvasLayer
## Autoload: in-game developer panel. Systems add their own tabs through register_tab().

const EVENT_LOG_TAB: PackedScene = preload("res://ui/debug_panel/tabs/event_log_tab.tscn")
const OVERLAYS_TAB: PackedScene = preload("res://ui/debug_panel/tabs/overlays_tab.tscn")
const SPAWN_TAB: PackedScene = preload("res://ui/debug_panel/tabs/spawn_tab.tscn")
const TIME_TAB: PackedScene = preload("res://ui/debug_panel/tabs/time_tab.tscn")

## World-space stimulus drawing; lives outside the tabs so it shows while the panel is closed.
var stimulus_overlay: StimulusOverlay
## Heat / fuel labels above flammables and explosives; also outside the tabs.
var heat_overlay: HeatOverlay
## Device labels and cables (ADR 0083); also outside the tabs.
var network_overlay: NetworkOverlay

@onready var _tabs: TabContainer = $TabContainer


func _ready() -> void:
	stimulus_overlay = StimulusOverlay.new()
	add_child(stimulus_overlay)
	heat_overlay = HeatOverlay.new()
	add_child(heat_overlay)
	network_overlay = NetworkOverlay.new()
	add_child(network_overlay)
	var overlays := OVERLAYS_TAB.instantiate() as OverlaysTab
	overlays.stimulus_overlay = stimulus_overlay
	overlays.heat_overlay = heat_overlay
	overlays.network_overlay = network_overlay
	register_tab("Overlays", overlays)
	register_tab("Spawn", SPAWN_TAB.instantiate() as Control)
	register_tab("Time", TIME_TAB.instantiate() as Control)
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


## Open, it holds every player's focus (OverlayFocus: their input off, the mouse free); closed, the
## mouse goes back to its mode from before.
func set_open(open: bool) -> void:
	if open == visible:
		return
	visible = open
	if open:
		OverlayFocus.acquire_all(self)
	else:
		OverlayFocus.release(self)
