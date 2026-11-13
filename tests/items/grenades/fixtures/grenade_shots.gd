extends Node3D
## Screenshot helper for reviews (not a test): first person at eye height (1.65 m; 0.9 m crouched)
## in a lit room with a wall face 1.0 m ahead (-Z) and open floor along -X. `-- shot=<name>
## out=<res path>` saves the window (HUD included) and quits. Shots: hand_frag, hand_gas, hand_emp,
## hand_jamming (the grenade drawn, 3 in the stack), hud_count (one thrown: x2), ghost_wall (the
## ghost on the wall), ghost_floor (crouched, looking down: the ghost on the floor), mine_blink (a
## frag mine on the wall, armed, its light lit, crouched 1.6 m back with the frame on it),
## thrown_midair (a frag just thrown), highlight_dark (lights off, Demolition Advanced: an armed mine
## on the floor 5 m away highlighted), and the STUCK shots (grenades stuck through Sticky.pose_on(),
## the view on them: upright beside the wall, on the floor, the ceiling and a door). It always
## quits: after saving, on an unknown shot, and after WATCHDOG real seconds (saving what is shown).

const Wait := preload("res://tests/helpers/wait.gd")
const SIZE := Vector2i(1152, 648)
const WATCHDOG := 25.0
const ITEMS: Dictionary[String, String] = {
	"frag": "res://items/grenades/frag/frag_grenade_item.tres",
	"gas": "res://items/grenades/gas/gas_grenade_item.tres",
	"emp": "res://items/grenades/emp/emp_grenade_item.tres",
	"jamming": "res://items/grenades/jamming/jamming_grenade_item.tres",
}
const SHOTS: Array[String] = [
	"hand_frag",
	"hand_gas",
	"hand_emp",
	"hand_jamming",
	"hud_count",
	"ghost_wall",
	"ghost_floor",
	"mine_blink",
	"thrown_midair",
	"highlight_dark",
]
const FRAG_SCENE := "res://items/grenades/frag/frag_grenade.tscn"
## Four types side by side on the near wall (face z -1.0), 1.45 m up.
const ROW: Array = [
	["frag", "WallNear", Vector3(1.7, 1.45, -1.0), Vector3.BACK],
	["gas", "WallNear", Vector3(1.9, 1.45, -1.0), Vector3.BACK],
	["emp", "WallNear", Vector3(2.1, 1.45, -1.0), Vector3.BACK],
	["jamming", "WallNear", Vector3(2.3, 1.45, -1.0), Vector3.BACK],
]
## Stuck shots: grenades [type, surface node, surface point, outward normal], the feet, the point
## looked at and the stance. Eye to grenade: about 0.7 m close, 2 m far.
const STUCK: Dictionary[String, Dictionary] = {
	"wall_frag": {"mines": [["frag", "WallNear", Vector3(0, 1.45, -1.0), Vector3.BACK]], "feet": Vector3(0, 0, -0.3)},
	"wall_gas": {"mines": [["gas", "WallNear", Vector3(0, 1.45, -1.0), Vector3.BACK]], "feet": Vector3(0, 0, -0.3)},
	"wall_emp": {"mines": [["emp", "WallNear", Vector3(0, 1.45, -1.0), Vector3.BACK]], "feet": Vector3(0, 0, -0.3)},
	"wall_jamming":
	{"mines": [["jamming", "WallNear", Vector3(0, 1.45, -1.0), Vector3.BACK]], "feet": Vector3(0, 0, -0.3)},
	"wall_row_close": {"mines": ROW, "feet": Vector3(2.0, 0, -0.3), "look": Vector3(2.0, 1.45, -1.0)},
	"wall_row_far": {"mines": ROW, "feet": Vector3(2.0, 0, 1.0), "look": Vector3(2.0, 1.45, -1.0)},
	# Along the wall, 0.4 m off it: the side of each against the wall.
	"wall_row_side": {"mines": ROW, "feet": Vector3(3.0, 0, -0.6), "look": Vector3(2.0, 1.45, -0.96)},
	"wall_row_side_close": {"mines": ROW, "feet": Vector3(1.25, 0, -0.62), "look": Vector3(1.7, 1.45, -0.97)},
	"floor_frag":
	{"mines": [["frag", "Floor", Vector3(-2, 0, 0), Vector3.UP]], "feet": Vector3(-2, 0, 0.6), "crouched": true},
	# Under the ceiling slab (bottom 2.4 m).
	"ceiling_frag": {"mines": [["frag", "Ceiling", Vector3(7, 2.4, 2), Vector3.DOWN]], "feet": Vector3(7, 0, 2.5)},
	# On the door leaf's +Z face (z -0.97), beside the handle.
	"door_frag":
	{"mines": [["frag", "Door/Panel", Vector3(10.2, 1.3, -0.97), Vector3.BACK]], "feet": Vector3(10.2, 0, -0.3)},
}

var _shot: String = "hand_frag"
var _out: String = "res://reports/screenshots/grenade_shot.png"
var _player: Player
var _done: bool = false


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("shot="):
			_shot = arg.trim_prefix("shot=")
		elif arg.begins_with("out="):
			_out = arg.trim_prefix("out=")
	DisplayServer.window_set_size(SIZE)
	get_tree().create_timer(WATCHDOG, true, false, true).timeout.connect(_save)
	if not SHOTS.has(_shot) and not STUCK.has(_shot):
		push_error("grenade_shots: unknown shot '%s'" % _shot)
		get_tree().quit(1)
		return
	_player = get_node("Player") as Player
	_player.input_enabled = false
	await Wait.frames(get_tree(), 5)
	await _setup()
	_save()


func _setup() -> void:
	if STUCK.has(_shot):
		await _stuck_shot(STUCK[_shot])
		return
	if _shot.begins_with("hand_"):
		_give(_shot.trim_prefix("hand_"), 3)
		_place(Vector3.ZERO, PI * 0.5, -0.05, false)
		await Wait.frames(get_tree(), 40)
		return
	match _shot:
		"hud_count":
			_give("frag", 3)
			_place(Vector3.ZERO, PI * 0.5, 0.05, false)
			await Wait.frames(get_tree(), 30)
			_player.weapons.trigger()
			await Wait.frames(get_tree(), 70)
		"ghost_wall":
			_give("frag", 3)
			_place(Vector3.ZERO, 0.35, -0.15, false)
			await Wait.frames(get_tree(), 40)
		"ghost_floor":
			_give("frag", 3)
			_place(Vector3(0, 0, 2), PI * 0.5, deg_to_rad(-62.0), true)
			await Wait.frames(get_tree(), 40)
		"thrown_midair":
			_give("frag", 3)
			_place(Vector3.ZERO, PI * 0.5, 0.1, false)
			await Wait.frames(get_tree(), 30)
			_player.weapons.trigger()
			await Wait.frames(get_tree(), 8)
		"mine_blink":
			var mine := _mine(get_node("WallNear") as Node3D, Vector3(0.0, 1.45, -1.0), Vector3.BACK)
			_place(Vector3(0.3, 0, 0.6), 0.0, 0.0, true)
			await Wait.frames(get_tree(), 140)
			_look_at(mine.global_position)
			await _until_lit(mine)
		"highlight_dark":
			(get_node("Sun") as DirectionalLight3D).visible = false
			var environment := (get_node("WorldEnvironment") as WorldEnvironment).environment
			environment.ambient_light_energy = 0.02
			environment.background_color = Color(0.01, 0.01, 0.015)
			var dark_mine := _mine(get_node("Floor") as Node3D, Vector3(-5, 0, 0.3), Vector3.UP)
			_player.skills.set_tier(&"demolition", 2)
			_place(Vector3.ZERO, PI * 0.5, -0.25, false)
			await Wait.frames(get_tree(), 140)
			(_player.get_node("MineSense") as MineSense).refresh()
			await _until_lit(dark_mine)


func _give(kind: String, count: int) -> void:
	var item := load(ITEMS[kind]) as ItemData
	_player.inventory.add(item, count)
	_player.inventory.select_slot(0)


func _place(feet: Vector3, yaw: float, pitch: float, crouched: bool) -> void:
	_player.load_state({"position": feet, "yaw": yaw, "pitch": pitch, "crouched": crouched, "velocity": Vector3.ZERO})


func _look_at(point: Vector3) -> void:
	var eye := _player.eye_transform().origin
	var to := point - eye
	var state := {
		"position": _player.global_position,
		"yaw": atan2(-to.x, -to.z),
		"pitch": atan2(to.y, Vector2(to.x, to.z).length()),
		"crouched": _player.crouched,
		"velocity": Vector3.ZERO,
	}
	_player.load_state(state)


func _stuck_shot(spec: Dictionary) -> void:
	var stuck: Array[RigidBody3D] = []
	for mine: Array in spec["mines"]:
		var scene := "res://items/grenades/%s/%s_grenade.tscn" % [mine[0], mine[0]]
		stuck.append(_mine(get_node(String(mine[1])) as Node3D, mine[2] as Vector3, mine[3] as Vector3, scene))
	_place(spec["feet"] as Vector3, 0.0, 0.0, bool(spec.get("crouched", false)))
	await Wait.frames(get_tree(), 20)
	_look_at(spec["look"] as Vector3 if spec.has("look") else stuck[0].global_position)
	await Wait.frames(get_tree(), 20)


# A grenade (a frag by default) stuck on `on` at `at` (surface normal `normal`), arming.
func _mine(on: Node3D, at: Vector3, normal: Vector3, scene: String = FRAG_SCENE) -> RigidBody3D:
	var mine := (load(scene) as PackedScene).instantiate() as RigidBody3D
	add_child(mine, true)
	var sticky := Sticky.of(mine)
	sticky.stick(on, sticky.pose_on(at, normal, -normal))
	return mine


func _until_lit(mine: Node) -> void:
	var trigger := ProximityTrigger.of(mine)
	for i in 120:
		await get_tree().physics_frame
		if trigger.is_light_on():
			await get_tree().process_frame
			return


func _save() -> void:
	if _done:
		return
	_done = true
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path(_out))
	print("Saved ", _out)
	get_tree().quit()
