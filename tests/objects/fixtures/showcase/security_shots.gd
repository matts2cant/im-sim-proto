extends Node
## Screenshot helper (not a test): poses the player in the security showcase for the shot named by
## the SHOT environment variable, saves the window's image (UI included) to SHOT_PATH and quits.
## Shots: wall (the devices on the back wall), camera (the camera seeing the player: red lamp),
## camera_mount, turret (winding up, laser on the player), turret_base, door (the cabled door),
## console (the computer up close), console_login (Halcyon OS login with Fill in), console_camera
## (Security app: the camera's live view), console_mail, console_files, console_cut (Security app:
## the switch unpowered, everything behind it offline), console_remote (the same desktop as a remote
## desktop inside a stand-in of the deck's panel: ADR 0114).

const SIZE := Vector2i(1152, 648)
const DeckShots := preload("res://tests/ui/deck/fixtures/deck_shots.gd")

@export var showcase_path: NodePath = ^"../Showcase"

var _show: Node3D
var _player: Player
var _shot: String = ""
var _time: float = 0.0
var _capture_at: float = 1.0
var _done: bool = false


func _ready() -> void:
	DisplayServer.window_set_size(DeckShots.shot_size(SIZE))
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
		"console":
			_command(Device.DISABLE, "Turret")
			_place(Vector3(-5.6, 0, -6.9), 0.0, -10.0, 0.349)
			_capture_at = 1.0
		"console_login", "console_camera", "console_mail", "console_files", "console_cut", "console_remote":
			_command(Device.DISABLE, "Turret")
			_place(Vector3(-6, 0, -7), 0.0, -8.0)
			_capture_at = 1.2
			await get_tree().create_timer(0.3).timeout
			Usable.of(_show.get_node("Datapad")).use(_player)
			(_player.get_node("ReadingOverlay") as ReadingOverlay).close()
			var computer := Computer.of(_show.get_node("Console"))
			if _shot == "console_remote":
				_deck_stand_in()
				computer.open_desktop(_player, "jmercer", true)
				ComputerScreen.of(_player).show_app(ComputerScreen.App.SECURITY)
				ComputerScreen.of(_player).security_app.select("Camera")
				return
			computer.use_by(_player)
			if _shot != "console_login":
				_console_session(ComputerScreen.of(_player))
			else:
				ComputerScreen.of(_player).fill_in(0)


func _console_session(screen: ComputerScreen) -> void:
	screen.fill_in(0)
	screen.submit_login()
	match _shot:
		"console_camera":
			screen.show_app(ComputerScreen.App.SECURITY)
			screen.security_app.select("Camera")
		"console_mail":
			screen.show_app(ComputerScreen.App.MAIL)
		"console_files":
			screen.show_app(ComputerScreen.App.FILES)
		"console_cut":
			(_show.get_node("Switch/Powered") as Powered).on = false
			await get_tree().physics_frame
			screen.show_app(ComputerScreen.App.SECURITY)
			screen.security_app.select("Camera")


# A stand-in of the deck's overlay (the other M12a brief builds the real one): dimmed world, the
# 85 % panel, its title bar and tools column, under the remote desktop's layer.
func _deck_stand_in() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 24
	add_child(layer)
	var dim := ColorRect.new()
	dim.color = TabStyle.WORLD_DIM
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(dim)
	var panel := Panel.new()
	panel.anchor_left = 0.075
	panel.anchor_top = 0.075
	panel.anchor_right = 0.925
	panel.anchor_bottom = 0.925
	panel.add_theme_stylebox_override(&"panel", HalcyonStyle.box(HalcyonStyle.OS_BG, HalcyonStyle.LINE, 1, 6))
	layer.add_child(panel)
	var bar := HalcyonStyle.label("Deck    Plugged into the office wall jack · 10.0.10.40", 13, HalcyonStyle.TEAL, true)
	bar.position = Vector2(12, 9)
	panel.add_child(bar)
	var tools := VBoxContainer.new()
	tools.position = Vector2(12, 52)
	panel.add_child(tools)
	for tool: String in ["Map", "Icebreaker", "Exploits", "Firewall", "Logs"]:
		tools.add_child(
			HalcyonStyle.label(tool, 13, HalcyonStyle.TEXT if tool in ["Map", "Icebreaker"] else HalcyonStyle.DIM)
		)


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
