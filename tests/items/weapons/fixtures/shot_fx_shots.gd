extends Node3D
## Screenshot helper for reviews (not a test, ADR 0126): the shot feedback seen from the player's eye
## (1.65 m) in a small yard: a concrete and a metal kit wall, a training dummy with the guards' body
## and a side shooter (a WeaponHolder on a bare body, assault rifle, a tracer every round) firing
## across the view. Run the scene in a window with `-- shot=<name> out=<png path>`: it fires, freezes
## the effects and the hit marker a moment later, saves the window image and quits (a real-time
## watchdog saves and quits after WATCHDOG seconds whatever happens).
## Shots: kill_marker (pistol headshot: a kill), head_marker (SMG headshot), impacts (pistol holes and
## puffs on concrete and metal), tracer (the side shooter's tracer mid-flight).

const SHOTS: Dictionary[String, Dictionary] = {
	"kill_marker": {"weapon": "pistol", "look": Vector3(-3.0, 1.65, -3.0), "fire": "head", "freeze": 0.05},
	"head_marker": {"weapon": "smg", "look": Vector3(-3.0, 1.65, -3.0), "fire": "head", "freeze": 0.05},
	"impacts":
	{"weapon": "pistol", "look": Vector3(0.0, 1.5, -6.0), "fire": "walls", "freeze": 0.06, "feet": Vector3(0, 0, -3.8)},
	"tracer": {"weapon": "pistol", "look": Vector3(0.0, 1.5, -6.0), "fire": "side", "freeze": 9.0, "trace_head": 4.0},
}
const RIFLE: WeaponData = preload("res://items/weapons/assault_rifle/assault_rifle.tres")
const AIM: AimConfig = preload("res://items/weapons/aim_untrained.tres")
const SHOT_SIZE := Vector2i(1152, 648)
## Seconds (game time) before the shot, and from the freeze to the image.
const FIRE_AT: float = 0.6
const SAVE_AFTER: float = 0.25
const WATCHDOG: float = 25.0
## Seconds between the impact shot's first shots and its last two.
const VOLLEY_GAP: float = 0.45
## Points the impact shot hits: on the concrete wall (left) and the metal wall (right); the last two
## are fired together VOLLEY_GAP later, just before the freeze, so their puffs show.
const WALL_POINTS: Array[Vector3] = [
	Vector3(-1.2, 1.9, -6.0),
	Vector3(-0.9, 1.3, -6.0),
	Vector3(-1.6, 1.1, -6.0),
	Vector3(1.0, 1.9, -6.0),
	Vector3(1.4, 1.2, -6.0),
	Vector3(0.8, 0.9, -6.0),
	Vector3(-0.7, 1.7, -6.0),
	Vector3(0.6, 1.6, -6.0),
]

var _shot: Dictionary = {}
var _out: String = ""
var _time: float = 0.0
var _fired_at: float = -1.0
var _frozen_at: float = -1.0
var _volley_at: float = -1.0
var _started_msec: int = 0
var _side_holder: WeaponHolder

@onready var _player: Player = $Player
@onready var _dummy: TrainingDummy = $TrainingDummy


func _ready() -> void:
	_started_msec = Time.get_ticks_msec()
	var args := {}
	for arg in OS.get_cmdline_user_args():
		var parts := arg.split("=", true, 1)
		if parts.size() == 2:
			args[parts[0]] = parts[1]
	_shot = SHOTS.get(String(args.get("shot", "kill_marker")), {})
	_out = String(args.get("out", "res://reports/screenshots/shot_fx.png"))
	if _shot.is_empty():
		push_error("Unknown shot %s; known: %s" % [args.get("shot"), ", ".join(SHOTS.keys())])
		get_tree().quit(1)
		return
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_window().size = SHOT_SIZE
	_side_holder = _side_shooter()


func _physics_process(delta: float) -> void:
	if _shot.is_empty():
		return
	_time += delta
	_look(_shot["look"] as Vector3)
	if _time > 0.2 and not _player.weapons.is_armed():
		_arm(StringName(_shot["weapon"]))
	if _player.weapons.is_armed() and _fired_at < 0.0:
		_player.weapons.settle()
	var walls := String(_shot["fire"]) == "walls"
	if _fired_at < 0.0 and _time >= FIRE_AT:
		_fired_at = _time
		_fire(String(_shot["fire"]))
	elif walls and _fired_at >= 0.0 and _volley_at < 0.0 and _time >= _fired_at + VOLLEY_GAP:
		# The last two together, so both puffs show when the effects freeze.
		_volley_at = _time
		for i in range(WALL_POINTS.size() - 2, WALL_POINTS.size()):
			_shoot_at(WALL_POINTS[i])
	var last := _volley_at if walls else _fired_at
	if last >= 0.0 and _frozen_at < 0.0 and _time >= last + float(_shot["freeze"]):
		_frozen_at = _time
		ShotFx.in_world(self).frozen = true
		_player.get_node("Hud/HitMarker").set(&"held", true)


func _process(_delta: float) -> void:
	if _shot.is_empty():
		return
	if _shot.has("trace_head") and _fired_at >= 0.0 and _frozen_at < 0.0:
		# Freeze once the tracer's head is this far out (mid-flight), whatever the frame timing.
		var segment := ShotFx.in_world(self).last_tracer_segment()
		var motion := ShotFx.in_world(self).last_tracer()
		if motion != null and segment[1].distance_to(motion.start) >= float(_shot["trace_head"]):
			_frozen_at = _time
			ShotFx.in_world(self).frozen = true
	var late := Time.get_ticks_msec() - _started_msec > WATCHDOG * 1000.0
	if not late and (_frozen_at < 0.0 or _time < _frozen_at + SAVE_AFTER):
		return
	var image := get_viewport().get_texture().get_image()
	image.save_png(ProjectSettings.globalize_path(_out))
	print("Saved ", _out)
	_shot = {}
	get_tree().quit()


func _fire(kind: String) -> void:
	match kind:
		"head":
			_shoot_at(_dummy.hitboxes.box(&"head").global_position)
		"walls":
			for i in WALL_POINTS.size() - 2:
				_shoot_at(WALL_POINTS[i])
		"side":
			_side_holder.state().cooldown = 0.0
			_side_holder.trigger()


# One exact shot of the player's weapon at `point` (the eye turned to it for the shot).
func _shoot_at(point: Vector3) -> void:
	_look(point)
	var holder := _player.weapons
	holder.settle()
	holder.aim.spread = 0.0
	holder.state().cooldown = 0.0
	holder.trigger()
	_look(_shot["look"] as Vector3)


# Gives the weapon `id` and its ammo and draws it.
func _arm(id: StringName) -> void:
	var inventory := _player.inventory
	var item := inventory.catalog.find(id)
	inventory.add(item, 1)
	inventory.add(inventory.catalog.find(item.weapon.ammo_item), 30)
	inventory.hold(inventory.grid.stacks[0])


# A bare body at the right of the yard holding the assault rifle with a tracer every round, aimed
# across the view to the left.
func _side_shooter() -> WeaponHolder:
	var body := StaticBody3D.new()
	body.name = "SideShooter"
	add_child(body)
	body.global_position = Vector3(4.0, 0.0, -3.5)
	var eye := Node3D.new()
	eye.name = "Eye"
	body.add_child(eye)
	eye.position.y = 1.5
	var holder := WeaponHolder.new()
	holder.aim_config = AIM
	holder.tracer_every = 1
	holder.rng_seed = 3
	holder.weapons = [RIFLE] as Array[WeaponData]
	eye.add_child(holder)
	holder.setup(body, eye)
	holder.equip(0)
	eye.look_at(Vector3(-4.0, 1.4, -6.5))
	return holder


func _look(point: Vector3) -> void:
	var feet: Vector3 = _shot.get("feet", Vector3.ZERO)
	var eye := feet + Vector3.UP * _player.config.standing_eye_height
	var to := point - eye
	var state := {
		"position": feet,
		"yaw": atan2(-to.x, -to.z),
		"pitch": atan2(to.y, Vector2(to.x, to.z).length()),
		"crouched": false,
		"velocity": Vector3.ZERO,
	}
	_player.load_state(state)
