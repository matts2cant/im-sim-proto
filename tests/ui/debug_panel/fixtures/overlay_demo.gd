extends Node3D
## Screenshot fixture (not a suite): bakes the two-rooms navmesh, turns the stimulus overlay on and
## keeps emitting a noise in the left room (heard round the wall) and a fire, so
## tools/screenshot.sh shows spheres and a path. `open_panel` shows the Overlays tab instead.

@export var open_panel: bool = false

var _frame: int = 0

@onready var _region: NavigationRegion3D = $TwoRooms/NavigationRegion


func _ready() -> void:
	_region.navigation_mesh = _region.navigation_mesh.duplicate() as NavigationMesh
	_region.bake_navigation_mesh(false)
	DebugPanel.stimulus_overlay.enabled = true
	if open_panel:
		DebugPanel.set_open(true)
		var tabs: TabContainer = DebugPanel.get_node("TabContainer")
		for i in tabs.get_tab_count():
			if tabs.get_tab_title(i) == "Overlays":
				tabs.current_tab = i
				var checkbox: CheckBox = tabs.get_tab_control(i).get_node("Stimuli")
				checkbox.set_pressed_no_signal(true)


func _physics_process(_delta: float) -> void:
	_frame += 1
	if _frame % 30 != 10:
		return
	StimulusSystem.emit(Stimulus.make_noise(20.0, Vector3(-3, 0, -3)))
	StimulusSystem.emit(Stimulus.make_radius(&"fire", 1.0, Vector3(5, 0.5, 2), 2.0))
