extends Node3D
## Screenshot helper (not a test, ADR 0130 step 2): a small lit room with a locked linking bay
## holding the rack scenes (switch, router, server, alarm controller, cabled to each other and to a
## wall jack), a sounding siren, a panic button and the jack on its wall. Photographs at eye height
## (1.65 m) with the player's field of view into SHOT_DIR (default
## reports/screenshots/m13c_devices/); SHOTS (comma-separated) limits the set. The bay's door is
## opened (picked) before the shots that say so: put them last. Quits itself, with a watchdog. Run:
## tools/run_windowed.sh 90 --path . res://tests/objects/devices/fixtures/device_scene_shots.tscn

const EYE := 1.65
const FOV := 80.0
const WATCHDOG_MS := 60000
const BAY := "res://objects/devices/linking_bay_locked.tscn"
## name: [eye, look-at, door open].
const SHOTS: Dictionary[String, Array] = {
	"bay_closed_1m5": [Vector3(0, EYE, -1.0), Vector3(0, 1.1, -2.6), false],
	"bay_closed_0m6": [Vector3(0.1, EYE, -1.85), Vector3(0.0, 1.45, -2.45), false],
	"siren_on": [Vector3(1.6, EYE, -1.3), Vector3(1.6, 2.35, -2.95), false],
	"wall_devices": [Vector3(1.6, EYE, -1.6), Vector3(1.6, 1.0, -2.95), false],
	"bay_open_1m5": [Vector3(0.3, EYE, -1.0), Vector3(0, 1.1, -2.6), true],
	"bay_units_0m5": [Vector3(0.05, 1.6, -1.95), Vector3(0.0, 1.45, -2.45), true],
}

var _camera: Camera3D
var _bay: Node3D
var _started_ms: int = 0


func _ready() -> void:
	_started_ms = Time.get_ticks_msec()
	DisplayServer.window_set_size(Vector2i(1152, 648))
	_room()
	_bay = (load(BAY) as PackedScene).instantiate() as Node3D
	_bay.position = Vector3(0, 0, -2.9)
	var units: Array[Node3D] = []
	for spec: Array in [
		["res://objects/network/switch_rack.tscn", 8, "SW-CORE"],
		["res://objects/network/router_rack.tscn", 10, "RTR-01"],
		["res://objects/computer/server_rack.tscn", 13, "SRV-01"],
		["res://objects/alarm/alarm_controller_rack.tscn", 16, "ALM-CTRL"],
	]:
		var unit := (load(spec[0] as String) as PackedScene).instantiate() as Node3D
		unit.position.y = LinkingBay.slot_y(spec[1] as int, 2)
		unit.set_meta(&"display_name", spec[2])
		_bay.add_child(unit)
		units.append(unit)
	add_child(_bay)
	var siren := _wall("res://objects/alarm/siren.tscn", Vector3(1.6, 2.4, -3.0), "SIREN-1")
	var button := _wall("res://objects/alarm/panic_button.tscn", Vector3(1.2, 1.3, -3.0), "PANIC-1")
	var jack := _wall("res://objects/network/wall_jack.tscn", Vector3(2.0, 0.4, -3.0), "JACK-OFFICE")
	for other: Node3D in [units[1], units[2], units[3], siren, button, jack]:
		_cable(other, units[0])
	_camera = Camera3D.new()
	_camera.near = 0.02
	_camera.fov = FOV
	add_child(_camera)
	_run.call_deferred(siren)


func _process(_delta: float) -> void:
	if Time.get_ticks_msec() - _started_ms > WATCHDOG_MS:
		print("device_scene_shots: watchdog")
		get_tree().quit(1)


func _run(siren: Node3D) -> void:
	for i in 10:
		await get_tree().physics_frame
	(siren.get_node("SirenBehaviour") as Siren).ring(60.0)
	var dir := OS.get_environment("SHOT_DIR")
	if dir.is_empty():
		dir = "res://reports/screenshots/m13c_devices"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	var only := OS.get_environment("SHOTS").split(",", false)
	for shot_name: String in SHOTS:
		if not only.is_empty() and not only.has(shot_name):
			continue
		var spec: Array = SHOTS[shot_name]
		var door := HingedDoor.of(_bay.get_node("GlassDoor"))
		if spec[2] and not door.open:
			(_bay.get_node("GlassDoor/MechanicalLock") as MechanicalLock).complete_pick(self)
			for i in 60:
				await get_tree().physics_frame
		_camera.global_position = spec[0] as Vector3
		_camera.look_at(spec[1] as Vector3, Vector3.UP)
		_camera.make_current()
		for k in 6:
			await get_tree().process_frame
		var file := "%s/%s.png" % [dir, shot_name]
		get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path(file))
		print("device_scene_shots: ", file)
	get_tree().quit()


func _wall(path: String, at: Vector3, shown: String) -> Node3D:
	var entity := (load(path) as PackedScene).instantiate() as Node3D
	entity.position = at
	entity.set_meta(&"display_name", shown)
	add_child(entity)
	return entity


func _cable(from: Node3D, to: Node3D) -> void:
	var device := Device.of(from)
	device.links.append(device.get_path_to(to))


# A 6 x 6 m room: floor, back wall (z -3), side walls, two lamps and a dim ambient.
func _room() -> void:
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.55, 0.56, 0.55)
	for spec: Array in [
		[Vector3(0, -0.05, 0), Vector3(6, 0.1, 6)],
		[Vector3(0, 1.75, -3.05), Vector3(6, 3.5, 0.1)],
		[Vector3(-3.05, 1.75, 0), Vector3(0.1, 3.5, 6)],
		[Vector3(3.05, 1.75, 0), Vector3(0.1, 3.5, 6)],
	]:
		var box := CSGBox3D.new()
		box.size = spec[1] as Vector3
		box.position = spec[0] as Vector3
		box.material = material
		box.use_collision = true
		add_child(box)
	for at: Vector3 in [Vector3(-1, 3.0, -1), Vector3(1.5, 3.0, -0.5)]:
		var lamp := OmniLight3D.new()
		lamp.position = at
		lamp.omni_range = 7.0
		lamp.light_energy = 1.2
		add_child(lamp)
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.1, 0.1, 0.12)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(1, 1, 1)
	environment.ambient_light_energy = 0.35
	var world := WorldEnvironment.new()
	world.environment = environment
	add_child(world)
