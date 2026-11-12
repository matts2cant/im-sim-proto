extends Node3D
## Screenshot helper for reviews (not a test): the animated character models (ADR 0103) from a
## third-person camera about 4 m away at eye height (1.65 m), lit. Run the scene in a window with
## `-- shots=<name>,<name> out=<folder>` (or `shots=all`): each shot builds its actors on a lit floor,
## waits, saves `<folder>/<name>.png` and the run quits after the last one. Guards have their AI
## switched off and are driven directly (NavWalker.move_to(), WeaponHolder.equip() / trigger()); a
## shot or swing is frozen at `freeze` seconds into its clip, with the muzzle flash held.
## ADR 0105: `weapon` draws that WeaponData instead of the scene's loadout, `light` lights the
## guard's flashlight, `dark` swaps the daylight for a night (no sun, dim ambient).

const GUARD_PISTOL: PackedScene = preload("res://actors/guard/guard_pistol.tscn")
const GUARD_RIFLE: PackedScene = preload("res://actors/guard/guard_rifle.tscn")
const GUARD_BATON: PackedScene = preload("res://actors/guard/guard_baton.tscn")
const DUMMY: PackedScene = preload("res://actors/dummy/training_dummy.tscn")
const PLAYER: PackedScene = preload("res://actors/player/player.tscn")
const SHOT_SIZE := Vector2i(1152, 648)
const EYE: float = 1.65

const SHOTS: Dictionary[String, Dictionary] = {
	"idle": {"guard": "pistol", "cam": Vector3(2.6, EYE, -3.0), "wait": 1.0},
	"walk": {"guard": "pistol", "walk": 1.5, "from": Vector3(0, 0, 2.0), "cam": Vector3(4.0, EYE, 0), "wait": 1.25},
	"sprint": {"guard": "pistol", "walk": 4.0, "from": Vector3(0, 0, 4.5), "cam": Vector3(4.0, EYE, 0), "wait": 1.15},
	"walk_armed":
	{
		"guard": "rifle",
		"draw": true,
		"walk": 1.5,
		"from": Vector3(0, 0, 2.0),
		"cam": Vector3(4.0, EYE, 0),
		"wait": 1.25
	},
	"aim_pistol":
	{"guard": "pistol", "draw": true, "fire": true, "freeze": 0.06, "cam": Vector3(3.6, EYE, -1.8), "face": -0.2},
	"aim_rifle":
	{"guard": "rifle", "draw": true, "fire": true, "freeze": 0.06, "cam": Vector3(3.6, EYE, -1.8), "face": -0.2},
	"aim_rifle_side": {"guard": "rifle", "draw": true, "cam": Vector3(4.0, EYE, 0)},
	"swing_baton":
	{"guard": "baton", "draw": true, "fire": true, "freeze": 0.18, "cam": Vector3(3.6, EYE, -1.8), "face": -0.2},
	"swing_baton_chop":
	{"guard": "baton", "draw": true, "fire": true, "freeze": 0.3, "cam": Vector3(3.6, EYE, -1.8), "face": -0.2},
	"dead": {"guard": "pistol", "kill": true, "cam": Vector3(3.4, EYE, -2.0), "look": Vector3(0, 0.3, 0.9)},
	"carried": {"guard": "pistol", "carry": true, "cam": Vector3(3.6, EYE, -1.6), "look": Vector3(0, 1.1, 0)},
	"dummy": {"dummy": true, "cam": Vector3(2.4, EYE, -3.2)},
	# ADR 0105: every weapon held one-handed (side three-quarter view of the right arm).
	"hold_baton":
	{"guard": "pistol", "weapon": "baton/baton", "draw": true, "cam": Vector3(3.2, EYE, -1.6), "face": 0.6},
	"hold_pistol":
	{"guard": "pistol", "weapon": "pistol/pistol", "draw": true, "cam": Vector3(3.2, EYE, -1.6), "face": 0.6},
	"hold_rifle":
	{
		"guard": "pistol",
		"weapon": "assault_rifle/assault_rifle",
		"draw": true,
		"cam": Vector3(3.2, EYE, -1.6),
		"face": 0.6
	},
	"hold_shotgun":
	{"guard": "pistol", "weapon": "shotgun/shotgun", "draw": true, "cam": Vector3(3.2, EYE, -1.6), "face": 0.6},
	"hold_sniper":
	{
		"guard": "pistol",
		"weapon": "sniper_rifle/sniper_rifle",
		"draw": true,
		"cam": Vector3(3.2, EYE, -1.6),
		"face": 0.6
	},
	"hold_smg": {"guard": "pistol", "weapon": "smg/smg", "draw": true, "cam": Vector3(3.2, EYE, -1.6), "face": 0.6},
	# Close side view of the SMG in the fist (its grip and stock against the hand).
	"hold_smg_side":
	{"guard": "pistol", "weapon": "smg/smg", "draw": true, "cam": Vector3(1.5, 1.45, -0.6), "face": 0.0},
	"aim_smg":
	{
		"guard": "pistol",
		"weapon": "smg/smg",
		"draw": true,
		"fire": true,
		"freeze": 0.06,
		"cam": Vector3(3.6, EYE, -1.8),
		"face": -0.2
	},
	"hold_baton_front": {"guard": "pistol", "weapon": "baton/baton", "draw": true, "cam": Vector3(1.0, EYE, -3.4)},
	"hold_rifle_top":
	{
		"guard": "pistol",
		"weapon": "assault_rifle/assault_rifle",
		"draw": true,
		"cam": Vector3(2.0, 3.2, -1.0),
		"face": 0.3
	},
	# The flashlight in the off hand at night: a patrol walking towards the camera from 6 m and 15 m,
	# aiming with it lit, downed with it, and off (hung at the belt).
	"patrol_light_6m":
	{
		"guard": "pistol",
		"light": true,
		"dark": true,
		"walk": 1.5,
		"from": Vector3(0, 0, 3.0),
		"cam": Vector3(0.6, EYE, -6.0),
		"wait": 1.25
	},
	"patrol_light_15m":
	{
		"guard": "pistol",
		"light": true,
		"dark": true,
		"walk": 1.5,
		"from": Vector3(0, 0, 3.0),
		"cam": Vector3(1.5, EYE, -15.0),
		"wait": 1.25
	},
	"patrol_light_side":
	{
		"guard": "pistol",
		"light": true,
		"walk": 1.5,
		"from": Vector3(0, 0, 2.0),
		"cam": Vector3(4.0, EYE, 0),
		"wait": 1.25
	},
	"aim_light":
	{
		"guard": "pistol",
		"light": true,
		"draw": true,
		"fire": true,
		"freeze": 0.06,
		"cam": Vector3(3.6, EYE, -1.8),
		"face": -0.2
	},
	"aim_light_dark":
	{"guard": "rifle", "light": true, "dark": true, "draw": true, "cam": Vector3(2.6, EYE, -3.6), "face": 0.2},
	"light_pose_front": {"guard": "pistol", "light": true, "draw": true, "cam": Vector3(-1.4, EYE, -3.2), "face": -0.3},
	"light_pose_top": {"guard": "pistol", "light": true, "draw": true, "cam": Vector3(-1.0, 3.6, -1.4), "face": 0.0},
	"light_off_belt": {"guard": "pistol", "cam": Vector3(1.6, 1.2, -2.2), "look": Vector3(0, 0.9, 0)},
	"dead_light":
	{
		"guard": "pistol",
		"light": true,
		"kill_at": 0.8,
		"cam": Vector3(-1.6, 2.4, -0.6),
		"look": Vector3(0, 0.2, 0.8),
		"wait": 2.2
	},
	"dummy_down": {"dummy": true, "kill": true, "cam": Vector3(3.4, EYE, -2.0), "look": Vector3(0, 0.3, 0.9)},
	"doorway":
	{
		"guard": "pistol",
		"door": true,
		"from": Vector3(0, 0, 1.2),
		"cam": Vector3(0.6, EYE, -2.8),
		"look": Vector3(0, 1.1, 1.2)
	},
}

var _queue: Array[String] = []
var _out := "res://reports/screenshots/characters"
var _shot: Dictionary = {}
var _time := 0.0
var _camera: Camera3D
var _stage: Node3D
var _guard: NavWalker
var _subject: Node3D
var _environment: Environment
var _sun: DirectionalLight3D


func _ready() -> void:
	var args := {}
	for arg in OS.get_cmdline_user_args():
		var parts := arg.split("=", true, 1)
		if parts.size() == 2:
			args[parts[0]] = parts[1]
	var names := String(args.get("shots", "idle"))
	var wanted: Array = SHOTS.keys() if names == "all" else Array(names.split(","))
	for shot_name: String in wanted:
		if SHOTS.has(shot_name):
			_queue.append(shot_name)
		else:
			push_error("Unknown shot %s" % shot_name)
	_out = String(args.get("out", _out))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_out))
	get_window().size = SHOT_SIZE
	DisplayServer.window_set_size(SHOT_SIZE)
	_build_world()
	_next()


func _build_world() -> void:
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.32, 0.36, 0.42)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.6, 0.62, 0.66)
	environment.ambient_light_energy = 0.6
	var world := WorldEnvironment.new()
	world.environment = environment
	add_child(world)
	_environment = environment
	_sun = DirectionalLight3D.new()
	_sun.rotation_degrees = Vector3(-50, 35, 0)
	_sun.shadow_enabled = true
	add_child(_sun)
	var floor_body := StaticBody3D.new()
	floor_body.collision_layer = PhysicsLayers.WORLD
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(40, 1, 40)
	shape.shape = box
	floor_body.add_child(shape)
	var mesh := MeshInstance3D.new()
	var plane := BoxMesh.new()
	plane.size = box.size
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.45, 0.45, 0.43)
	plane.material = material
	mesh.mesh = plane
	floor_body.add_child(mesh)
	floor_body.position.y = -0.5
	add_child(floor_body)
	_camera = Camera3D.new()
	_camera.fov = 60.0
	add_child(_camera)
	_camera.make_current()


func _next() -> void:
	if _stage != null:
		_stage.free()
	if _queue.is_empty():
		get_tree().quit()
		return
	var shot_name: String = _queue.pop_front()
	_shot = SHOTS[shot_name].duplicate()
	_shot["name"] = shot_name
	_time = 0.0
	_stage = Node3D.new()
	_stage.name = "Stage"
	add_child(_stage)
	_guard = null
	_subject = null
	var dark: bool = _shot.get("dark", false)
	_sun.visible = not dark
	_environment.background_color = Color(0.02, 0.02, 0.03) if dark else Color(0.32, 0.36, 0.42)
	_environment.ambient_light_energy = 0.08 if dark else 0.6
	if _shot.has("guard"):
		_guard = _spawn_guard(String(_shot["guard"]))
		_subject = _guard
	if _shot.get("dummy", false):
		_subject = DUMMY.instantiate() as Node3D
		_stage.add_child(_subject)
		# Turned towards the camera side a little, like the guards.
		_subject.rotation.y = deg_to_rad(-150)
	if _shot.get("door", false):
		_build_doorway()
	_start.call_deferred()


func _spawn_guard(kind: String) -> NavWalker:
	var scene: PackedScene = {"pistol": GUARD_PISTOL, "rifle": GUARD_RIFLE, "baton": GUARD_BATON}[kind]
	var guard := scene.instantiate() as NavWalker
	guard.name = "Guard"
	guard.position = _shot.get("from", Vector3.ZERO)
	_stage.add_child(guard)
	for node_name: String in [
		"Behaviour", "Combat", "Perception", "Awareness", "BodyDiscovery", "Comms", "AlarmHearing"
	]:
		var node := guard.get_node_or_null(node_name)
		if node != null:
			node.process_mode = Node.PROCESS_MODE_DISABLED
	return guard


func _start() -> void:
	if _guard != null:
		var cam: Vector3 = _shot["cam"]
		if _shot.has("walk"):
			_guard.move_to(Vector3(0, 0, -20), float(_shot["walk"]))
		else:
			# Faces a point between the camera and straight ahead (-Z): a three-quarter view
			# (`face`: the sideways share instead, for a side view of the arms).
			_guard.face_direction(Vector3(float(_shot.get("face", cam.x * 0.35)), 0, -1).normalized())
		var holder := _guard.get_node("Aim/WeaponHolder") as WeaponHolder
		if _shot.has("weapon"):
			var data := load("res://items/weapons/%s.tres" % _shot["weapon"]) as WeaponData
			holder.equip_state(WeaponState.new(data))
		elif _shot.get("draw", false):
			holder.equip(0)
		if _shot.get("light", false):
			Flashlight.of(_guard).on_while_patrolling = true
	if _shot.get("kill", false):
		BodyParts.of(_subject).take_damage(&"damage.ballistic", 500.0, &"torso")
	if _shot.get("carry", false):
		_carry()


func _carry() -> void:
	var player := PLAYER.instantiate() as Player
	player.name = "Player"
	_stage.add_child(player)
	player.input_enabled = false
	(player.get_node("Hud") as CanvasLayer).visible = false
	player.global_position = Vector3(0, 0, 0)
	_guard.global_position = Vector3(0, 0, -1.2)
	BodyParts.of(_guard).take_damage(&"damage.stun", 500.0, &"head")
	_subject = player
	_shot["pick_up"] = true


func _physics_process(_delta: float) -> void:
	if _shot.is_empty():
		return
	if _shot.has("kill_at") and _time > float(_shot["kill_at"]):
		_shot.erase("kill_at")
		BodyParts.of(_subject).take_damage(&"damage.ballistic", 500.0, &"torso")
	if _shot.get("pick_up", false) and _time > 0.8:
		_shot.erase("pick_up")
		var player := _subject as Player
		player.carry.pick_up(_guard)
	if _shot.get("fire", false) and _time > 0.5:
		_shot.erase("fire")
		var holder := _guard.get_node("Aim/WeaponHolder") as WeaponHolder
		holder.trigger()
		_shot["frozen"] = true
	if _shot.get("frozen", false):
		var animator := _guard.get_node("Animator") as CharacterAnimator
		var slot := animator.action.current
		if not slot.clip.is_empty() and slot.time >= float(_shot["freeze"]):
			slot.rate = 0.0
			slot.time = float(_shot["freeze"])
		# The state keeps the action playing while it is frozen.
		animator.state.action_left = 1.0
		var holder := _guard.get_node("Aim/WeaponHolder") as WeaponHolder
		if not holder.weapon().is_melee():
			holder.flash.hold(holder.weapon())


func _process(delta: float) -> void:
	if _shot.is_empty():
		return
	_time += delta
	var target: Vector3 = _shot.get("look", Vector3(0, 1.0, 0))
	var cam: Vector3 = _shot["cam"]
	if _shot.has("walk") and _guard != null:
		# Follows the walker from the side.
		target = _guard.global_position + Vector3(0, 1.0, 0)
		cam.z += _guard.global_position.z
	_camera.current = true
	_camera.global_position = cam
	_camera.look_at(target, Vector3.UP)
	if _time < float(_shot.get("wait", 1.6)):
		return
	var path := "%s/%s.png" % [_out, _shot["name"]]
	get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path(path))
	print("Saved ", path)
	_shot = {}
	_next.call_deferred()


# A 1.2 x 2.2 m doorway (the narrow doors of the levels, design/levels/metrics.md) in a 0.2 m wall,
# the guard standing in it: the scale check against a door.
func _build_doorway() -> void:
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.6, 0.58, 0.52)
	for side: float in [-1.0, 1.0]:
		_wall_box(Vector3(1.5, 2.6, 0.2), Vector3(side * 1.35, 1.3, 1.2), material)
	_wall_box(Vector3(1.2, 0.4, 0.2), Vector3(0, 2.4, 1.2), material)


func _wall_box(size: Vector3, centre: Vector3, material: Material) -> void:
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	box.material = material
	mesh.mesh = box
	mesh.position = centre
	_stage.add_child(mesh)
