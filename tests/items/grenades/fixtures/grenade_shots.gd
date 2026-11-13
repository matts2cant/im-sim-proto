extends Node3D
## Screenshot helper for reviews (not a test): first person at eye height (1.65 m; 0.9 m crouched)
## in a lit room with a wall face 1.0 m ahead (-Z) and open floor along -X. `-- shot=<name>
## out=<res path>` saves the window (HUD included) and quits. Shots: hand_frag, hand_gas, hand_emp,
## hand_jamming (the grenade drawn, 3 in the stack), hud_count (one thrown: x2), ghost_wall (the
## ghost on the wall), ghost_floor (crouched, looking down: the ghost on the floor), mine_blink (a
## frag mine on the wall, armed, its light lit, crouched 1.6 m back with the frame on it),
## thrown_midair (a frag just thrown), highlight_dark (lights off, Demolition Advanced: an armed mine
## on the floor 5 m away highlighted). It always quits: after saving, on an unknown shot, and after
## WATCHDOG real seconds (saving what is shown).

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
	if not SHOTS.has(_shot):
		push_error("grenade_shots: unknown shot '%s'" % _shot)
		get_tree().quit(1)
		return
	_player = get_node("Player") as Player
	_player.input_enabled = false
	await Wait.frames(get_tree(), 5)
	await _setup()
	_save()


func _setup() -> void:
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
	_player.inventory.give(item, count)
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


# A frag stuck on `on` at `at` (surface normal `normal`), arming.
func _mine(on: Node3D, at: Vector3, normal: Vector3) -> RigidBody3D:
	var mine := (load(FRAG_SCENE) as PackedScene).instantiate() as RigidBody3D
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
