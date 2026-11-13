extends Node3D
## Screenshot helper for reviews (not a test, ADR 0131 M14b): the grenade effects seen from the eye
## (1.65 m) in a small grey room built in code (12 x 14 m, 3 m ceiling): two ceiling lamps, a security
## camera on the far wall, a wooden crate. Run in a window with `-- shot=<name> out=<png path>`: it
## sets the shot up, waits, saves the window image and quits (a real-time watchdog saves and quits
## after WATCHDOG seconds whatever happens).
## Shots: frag (a frag stand-in goes off 4 m ahead; saved 0.12 s later), gas (a gas cloud 3.5 m
## ahead, 1.5 s after its release), gas_inside (standing in the cloud), emp_before and emp_after (an
## EMP 3 m ahead: the camera's lamp and the room's lamps go dark, 0.5 s later).

const SHOT_SIZE := Vector2i(1152, 648)
const WATCHDOG: float = 25.0
const EYE: float = 1.65
const Grenades := preload("res://tests/objects/explosives/explosive_fixtures.gd")
const LAMP: PackedScene = preload("res://objects/light_fixture/ceiling_lamp.tscn")
const CAMERA: PackedScene = preload("res://objects/camera/security_camera.tscn")
const CRATE: PackedScene = preload("res://objects/small_crate/small_crate.tscn")
const CLOUD: PackedScene = preload("res://objects/explosives/gas_cloud/gas_cloud.tscn")
## name -> {feet, look, act: frag | gas | emp | none, at (the effect's place), save (s after the act)}
const SHOTS: Dictionary[String, Dictionary] = {
	"frag":
	{"feet": Vector3(0, 0, 3), "look": Vector3(0, 1.0, -2), "act": "frag", "at": Vector3(0, 0.1, -1), "save": 0.12},
	"gas":
	{"feet": Vector3(0, 0, 3), "look": Vector3(0, 1.2, -2), "act": "gas", "at": Vector3(0, 0.1, -0.5), "save": 1.5},
	"gas_inside":
	{"feet": Vector3(0, 0, 0), "look": Vector3(0, 1.4, -5), "act": "gas", "at": Vector3(0.3, 0.1, -0.3), "save": 1.5},
	"emp_before": {"feet": Vector3(0, 0, 2), "look": Vector3(1.0, 2.0, -6.5), "act": "none", "save": 0.5},
	"emp_after":
	{"feet": Vector3(0, 0, 2), "look": Vector3(1.0, 2.0, -6.5), "act": "emp", "at": Vector3(0.5, 0.1, -3), "save": 0.5},
	"emp_camera_before": {"feet": Vector3(0.4, 0, -5.2), "look": Vector3(1.0, 2.5, -7.0), "act": "none", "save": 0.5},
	"emp_camera_after":
	{
		"feet": Vector3(0.4, 0, -5.2),
		"look": Vector3(1.0, 2.5, -7.0),
		"act": "emp",
		"at": Vector3(0.5, 0.1, -3),
		"save": 0.5
	},
}
## Seconds before the act (lamps and camera settle).
const ACT_AT: float = 0.8

var _shot: Dictionary = {}
var _out: String = "res://reports/screenshots/explosives/frag.png"
var _time: float = 0.0
var _acted: bool = false
var _saved: bool = false
var _camera: Camera3D


func _ready() -> void:
	var args := {}
	for arg in OS.get_cmdline_user_args():
		var parts := arg.split("=", true, 1)
		if parts.size() == 2:
			args[parts[0]] = parts[1]
	var shot_name := String(args.get("shot", "frag"))
	_shot = SHOTS.get(shot_name, {})
	_out = String(args.get("out", "res://reports/screenshots/explosives/%s.png" % shot_name))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_out).get_base_dir())
	get_window().size = SHOT_SIZE
	get_tree().create_timer(WATCHDOG, true, false, true).timeout.connect(_save_and_quit)
	if _shot.is_empty():
		push_error("Unknown shot %s; known: %s" % [shot_name, ", ".join(SHOTS.keys())])
		get_tree().quit.call_deferred()
		return
	_build_room()
	_camera = Camera3D.new()
	_camera.current = true
	add_child(_camera)
	var eye := (_shot["feet"] as Vector3) + Vector3.UP * EYE
	_camera.look_at_from_position(eye, _shot["look"] as Vector3)


func _physics_process(delta: float) -> void:
	if _shot.is_empty() or _saved:
		return
	_time += delta
	if not _acted and _time >= ACT_AT:
		_acted = true
		_act()
	if _acted and _time >= ACT_AT + float(_shot["save"]):
		_save_and_quit()


func _act() -> void:
	var at := _shot.get("at", Vector3.ZERO) as Vector3
	match String(_shot["act"]):
		"frag":
			var grenade := Grenades.grenade(self, "Frag", at, Grenades.FRAG)
			Explosive.of(grenade).explode()
		"gas":
			var cloud := ExplosivePayload.spawn_in_level(CLOUD, self, at) as GasCloud
			cloud.drift = Vector3.ZERO
		"emp":
			var grenade := Grenades.grenade(self, "Emp", at, Grenades.EMP)
			Explosive.of(grenade).explode()


func _save_and_quit() -> void:
	if _saved:
		return
	_saved = true
	get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path(_out))
	print("Saved ", _out)
	get_tree().quit()


func _build_room() -> void:
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.05, 0.05, 0.06)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.5, 0.52, 0.55)
	environment.ambient_light_energy = 0.25
	var world := WorldEnvironment.new()
	world.environment = environment
	add_child(world)
	var grey := StandardMaterial3D.new()
	grey.albedo_color = Color(0.55, 0.56, 0.58)
	_box(Vector3(0, -0.1, 0), Vector3(12, 0.2, 14), grey)
	_box(Vector3(0, 3.1, 0), Vector3(12, 0.2, 14), grey)
	_box(Vector3(0, 1.5, -7.1), Vector3(12, 3, 0.2), grey)
	_box(Vector3(0, 1.5, 7.1), Vector3(12, 3, 0.2), grey)
	_box(Vector3(-6.1, 1.5, 0), Vector3(0.2, 3, 14), grey)
	_box(Vector3(6.1, 1.5, 0), Vector3(0.2, 3, 14), grey)
	for x: float in [-1.8, 1.8]:
		var lamp := LAMP.instantiate() as Node3D
		lamp.position = Vector3(x, 3.0, -2.5)
		add_child(lamp)
	var camera := CAMERA.instantiate() as Node3D
	camera.position = Vector3(1.0, 2.6, -7.0)
	add_child(camera)
	var crate := CRATE.instantiate() as Node3D
	crate.position = Vector3(-2.2, 0.3, -3.5)
	add_child(crate)


func _box(centre: Vector3, size: Vector3, material: Material) -> void:
	var body := StaticBody3D.new()
	body.collision_layer = PhysicsLayers.WORLD
	body.collision_mask = 0
	body.position = centre
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	var mesh := MeshInstance3D.new()
	var cube := BoxMesh.new()
	cube.size = size
	cube.material = material
	mesh.mesh = cube
	body.add_child(mesh)
	add_child(body)
