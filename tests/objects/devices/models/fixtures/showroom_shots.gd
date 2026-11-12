extends Node
## Screenshot helper (not a test, ADR 0130 step 0): loads the hub and photographs the device
## showroom from fixed spots (overview from 4 m at eye height, each group from 1.5 m, close-ups,
## the bays from the side, the lamps off) with the player's field of view, into SHOT_DIR (default
## reports/screenshots/m13c_showroom/). SHOTS (comma-separated names) limits the set; SHOT_SIZE
## (WxH) sets the window. Quits itself when done, with a real-time watchdog. Run:
## tools/run_windowed.sh 120 --path . res://tests/objects/devices/models/fixtures/showroom_shots.tscn

const EYE := 1.65
const FOV := 80.0
const WATCHDOG_MS := 100000
## name: [eye position, look-at point, lamps: "on" | "showroom_off" | "all_off"].
const SHOTS: Dictionary[String, Array] = {
	"overview_4m": [Vector3(11.0, EYE, -0.6), Vector3(15.0, 1.25, -0.6), "on"],
	"bays_1m5": [Vector3(13.0, EYE, -4.6), Vector3(14.6, 1.15, -4.6), "on"],
	"desk_1m5": [Vector3(13.3, EYE, -2.4), Vector3(14.7, 0.95, -2.4), "on"],
	"wall_left_1m5": [Vector3(13.5, EYE, 0.7), Vector3(15.0, 1.75, 0.7), "on"],
	"wall_right_1m5": [Vector3(13.5, EYE, 3.3), Vector3(15.0, 1.35, 3.3), "on"],
	"switch_labels_0m3": [Vector3(14.15, 1.53, -4.93), Vector3(14.45, 1.51, -4.93), "on"],
	"switch_labels_0m5": [Vector3(13.95, 1.55, -4.93), Vector3(14.45, 1.51, -4.93), "on"],
	"switch_labels_0m75": [Vector3(13.7, 1.58, -4.93), Vector3(14.45, 1.51, -4.93), "on"],
	"switch_labels_1m": [Vector3(13.45, 1.6, -4.93), Vector3(14.45, 1.51, -4.93), "on"],
	"router_uplink_0m5": [Vector3(13.95, 1.42, -4.85), Vector3(14.45, 1.40, -4.85), "on"],
	"door_keypad_0m5": [Vector3(14.5, 1.32, 0.15), Vector3(15.0, 1.3, 0.15), "on"],
	"door_control_0m5": [Vector3(14.5, 1.32, 1.8), Vector3(15.0, 1.3, 1.8), "on"],
	"wall_jack_0m5": [Vector3(14.5, 0.4, 3.8), Vector3(15.0, 0.3, 3.8), "on"],
	"turret_1m5": [Vector3(13.5, 2.0, 3.0), Vector3(14.8, 2.55, 3.6), "on"],
	"desk_gear_0m6": [Vector3(13.9, 1.1, -1.8), Vector3(14.55, 0.78, -1.8), "on"],
	"bays_side": [Vector3(13.9, EYE, -6.3), Vector3(14.7, 1.0, -4.6), "on"],
	"overview_lamps_off": [Vector3(11.0, EYE, -0.6), Vector3(15.0, 1.25, -0.6), "showroom_off"],
	"bays_dark": [Vector3(13.0, EYE, -4.6), Vector3(14.6, 1.15, -4.6), "all_off"],
}

var _camera: Camera3D
var _started_ms: int = 0


func _ready() -> void:
	_started_ms = Time.get_ticks_msec()
	var size := Vector2i(1152, 648)
	var wanted := OS.get_environment("SHOT_SIZE").split("x")
	if wanted.size() == 2:
		size = Vector2i(wanted[0].to_int(), wanted[1].to_int())
	DisplayServer.window_set_size(size)
	var hub := (load("res://levels/hub/hub.tscn") as PackedScene).instantiate() as Node3D
	add_child(hub)
	_camera = Camera3D.new()
	_camera.near = 0.02
	_camera.fov = FOV
	add_child(_camera)
	_run.call_deferred(hub)


func _process(_delta: float) -> void:
	if Time.get_ticks_msec() - _started_ms > WATCHDOG_MS:
		print("showroom_shots: watchdog")
		get_tree().quit(1)


func _run(hub: Node3D) -> void:
	for i in 20:
		await get_tree().physics_frame
	var player := hub.get_node_or_null("Player") as Node3D
	if player != null:
		player.process_mode = Node.PROCESS_MODE_DISABLED
		player.visible = false
	for layer in hub.find_children("*", "CanvasLayer", true, false):
		(layer as CanvasLayer).visible = false
	var dir := OS.get_environment("SHOT_DIR")
	if dir.is_empty():
		dir = "res://reports/screenshots/m13c_showroom"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	var only := OS.get_environment("SHOTS").split(",", false)
	var suffix := OS.get_environment("SHOT_SUFFIX")
	for shot_name: String in SHOTS:
		if not only.is_empty() and not only.has(shot_name):
			continue
		var spec: Array = SHOTS[shot_name]
		_lamps(hub, spec[2] as String)
		_camera.global_position = spec[0] as Vector3
		_camera.look_at(spec[1] as Vector3, Vector3.UP)
		_camera.make_current()
		for k in 4:
			await get_tree().process_frame
		var file := "%s/%s%s.png" % [dir, shot_name, suffix]
		get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path(file))
		print("showroom_shots: ", file)
	get_tree().quit()


func _lamps(hub: Node3D, mode: String) -> void:
	var showroom := hub.get_node("DeviceShowroom/Lights") as Node3D
	showroom.visible = mode == "on"
	(hub.get_node("Lights") as Node3D).visible = mode != "all_off"
	var environment := (hub.get_node("WorldEnvironment") as WorldEnvironment).environment
	environment.ambient_light_energy = 0.05 if mode == "all_off" else 0.4
