extends Node
## Screenshot helper (not a test): poses the player in the security showcase for the shot named by
## the SHOT environment variable, saves the window's image (UI included) to SHOT_PATH and quits.
## Shots: wall (the devices on the back wall), camera (the camera seeing the player: red lamp),
## camera_mount, turret (winding up, laser on the player), turret_base, door (the cabled door),
## terminal (the terminal up close), terminal_login (the login screen with the Known line),
## terminal_camera (Camera tab: the camera's live feed), terminal_network (Network tab: camera and
## turret unpowered, the siren ringing, its menu open), terminal_cut (Network tab: the switch
## unpowered, everything behind it offline, the camera's menu open).

const SIZE := Vector2i(1152, 648)

@export var showcase_path: NodePath = ^"../Showcase"

var _show: Node3D
var _player: Player
var _shot: String = ""
var _time: float = 0.0
var _capture_at: float = 1.0
var _done: bool = false


func _ready() -> void:
	DisplayServer.window_set_size(SIZE)
	_show = get_node(showcase_path) as Node3D
	_player = _show.get_node("Player") as Player
	_player.input_enabled = false
	_shot = OS.get_environment("SHOT")
	if _shot.is_empty():
		_shot = "wall"
	await get_tree().physics_frame
	_pose()


func _pose() -> void:
	match _shot:
		"wall":
			_place(Vector3(-1, 0, -1.5), 0.15, 8.0)
			_command(Device.DISABLE, "Turret")
			_capture_at = 1.0
		"camera":
			_command(Device.DISABLE, "Turret")
			_command(Device.STOP_SWEEP, "Camera")
			_place(Vector3(4.3, 0, -6.0), 0.0, 24.0, 0.149)
			_capture_at = 3.0
		"camera_mount":
			_command(Device.DISABLE, "Turret")
			_command(Device.DISABLE, "Camera")
			_place(Vector3(4.9, 0, -6.6), 0.0, 30.0, 0.571)
			_capture_at = 1.0
		"turret":
			_command(Device.DISABLE, "Camera")
			_place(Vector3(13.0, 0, -1.6), 0.0, -5.0, 1.297)
			_capture_at = 1.4
		"turret_base":
			_command(Device.DISABLE, "Camera")
			_command(Device.DISABLE, "Turret")
			_place(Vector3(9.6, 0, -4.4), 0.0, -30.0, 2.29)
			_capture_at = 1.0
		"door":
			_command(Device.DISABLE, "Turret")
			_place(Vector3(-9.9, 0, -0.8), 0.0, 0.0, 0.26)
			_capture_at = 1.0
		"terminal":
			_command(Device.DISABLE, "Turret")
			_place(Vector3(-5.6, 0, -6.9), 0.0, -10.0, 0.349)
			_capture_at = 1.0
		"terminal_login", "terminal_camera", "terminal_network", "terminal_cut":
			_command(Device.DISABLE, "Turret")
			_place(Vector3(-6, 0, -7), 0.0, -8.0)
			_capture_at = 1.2
			await get_tree().create_timer(0.3).timeout
			Usable.of(_show.get_node("Datapad")).use(_player)
			(_player.get_node("ReadingOverlay") as ReadingOverlay).close()
			Terminal.of(_show.get_node("Terminal")).use(_player)
			if _shot != "terminal_login":
				_terminal_session(TerminalScreen.of(_player))


func _terminal_session(screen: TerminalScreen) -> void:
	screen.fill_in()
	screen.submit_login()
	match _shot:
		"terminal_camera":
			screen.select_camera("Camera")
		"terminal_network":
			screen.show_tab(TerminalScreen.Tab.NETWORK)
			(_show.get_node("Camera/Powered") as Powered).on = false
			(_show.get_node("Turret/Powered") as Powered).on = false
			screen.press(Device.TEST, Device.of(_show.get_node("Siren")))
			screen.graph.select("Siren")
		"terminal_cut":
			screen.show_tab(TerminalScreen.Tab.NETWORK)
			(_show.get_node("Switch/Powered") as Powered).on = false
			screen.refresh_devices(true)
			screen.graph.select("Camera")


func _place(local: Vector3, yaw: float, pitch_deg: float, extra_yaw: float = 0.0) -> void:
	var state := {
		"position": _show.to_global(local),
		"yaw": yaw + extra_yaw,
		"pitch": deg_to_rad(pitch_deg),
		"crouched": false,
		"velocity": Vector3.ZERO,
	}
	_player.load_state(state)


func _command(type: StringName, path: String) -> void:
	StimulusSystem.emit(Device.command_stimulus(type, _show.get_node(path)))


func _process(delta: float) -> void:
	_time += delta
	if _done or _time < _capture_at:
		return
	_done = true
	var path := OS.get_environment("SHOT_PATH")
	if path.is_empty():
		path = "res://reports/screenshots/security_%s.png" % _shot
	get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path(path))
	get_tree().quit()
