extends Node3D
## Screenshot helper for reviews (not a test): first-person shots of the shooting range in the hub.
## Run the scene in a window with `-- shot=<name> out=<png path>`: it puts the hub player at a
## station (eye height 1.65 m), optionally draws the pistol or baton (settled reticle) or any weapon
## item (`weapon`: its id; `silencer`: fit one first; `scope`: scope in, ADR 0085), waits, saves the
## window image and quits. Positions are room-local (origin on the hub wall, -Z into the room).

## feet / look: room-local points; pistol: draw it so the reticle shows; wait: game seconds.
const SHOTS: Dictionary[String, Dictionary] = {
	"corridor_entry": {"feet": Vector3(0, 0, 3.0), "look": Vector3(0, 1.6, -6)},
	"corridor_exit": {"feet": Vector3(0.4, 0, -2.4), "look": Vector3(0.5, 1.6, -10)},
	"hall_door_back": {"feet": Vector3(1.5, 0, -6.8), "look": Vector3(-0.5, 2.4, -3.6)},
	"firing_line": {"feet": Vector3(4.25, 0, -7.4), "look": Vector3(4.25, 1.0, -30)},
	"lane_40m": {"feet": Vector3(9.25, 0, -7.45), "look": Vector3(9.25, 1.21, -48), "pistol": true},
	"lane_10m": {"feet": Vector3(4.25, 0, -7.45), "look": Vector3(4.25, 1.21, -18), "pistol": true},
	"hurt_lane_10m": {"feet": Vector3(4.25, 0, -7.45), "look": Vector3(4.25, 1.21, -18), "pistol": true, "hurt": true},
	"baton_rest": {"feet": Vector3(4.25, 0, -7.45), "look": Vector3(4.25, 1.21, -18), "baton": true},
	"baton_swing": {"feet": Vector3(4.25, 0, -7.45), "look": Vector3(4.25, 1.21, -18), "baton": true, "swing": 0.15},
	"baton_swing_late":
	{"feet": Vector3(4.25, 0, -7.45), "look": Vector3(4.25, 1.21, -18), "baton": true, "swing": 0.4},
	"melee_corner": {"feet": Vector3(4.6, 0, -6.6), "look": Vector3(8.6, 1.2, -5.6)},
	"melee_behind": {"feet": Vector3(8.6, 0, -5.6), "look": Vector3(9.9, 1.2, -5.6)},
	"blast_lane": {"feet": Vector3(-1.5, 0, -11.0), "look": Vector3(-1.5, 0.3, -20)},
	"blast_line_6m": {"feet": Vector3(-1.5, 0, -14.0), "look": Vector3(-1.5, 0.2, -20)},
	"blast_gap": {"feet": Vector3(-2.9, 0, -6.0), "look": Vector3(-2.2, 0.8, -13)},
	"far_wall": {"feet": Vector3(3.5, 0, -40.0), "look": Vector3(2.6, 0.8, -51.6)},
	"medkits": {"feet": Vector3(3.0, 0, -6.2), "look": Vector3(3.0, 1.0, -4.3)},
	"fp_pistol": {"feet": Vector3(4.25, 0, -7.45), "look": Vector3(4.25, 1.21, -18), "weapon": "pistol"},
	"fp_pistol_silenced":
	{"feet": Vector3(4.25, 0, -7.45), "look": Vector3(4.25, 1.21, -18), "weapon": "pistol", "silencer": true},
	"fp_shotgun": {"feet": Vector3(4.25, 0, -7.45), "look": Vector3(4.25, 1.21, -18), "weapon": "shotgun"},
	"fp_sniper": {"feet": Vector3(9.25, 0, -7.45), "look": Vector3(9.25, 1.21, -48), "weapon": "sniper_rifle"},
	"fp_sniper_silenced":
	{"feet": Vector3(9.25, 0, -7.45), "look": Vector3(9.25, 1.21, -48), "weapon": "sniper_rifle", "silencer": true},
	"fp_sniper_scope":
	{"feet": Vector3(9.25, 0, -7.45), "look": Vector3(9.25, 1.21, -48), "weapon": "sniper_rifle", "scope": true},
	"fp_rifle": {"feet": Vector3(4.25, 0, -7.45), "look": Vector3(4.25, 1.21, -18), "weapon": "assault_rifle"},
	"fp_rifle_silenced":
	{"feet": Vector3(4.25, 0, -7.45), "look": Vector3(4.25, 1.21, -18), "weapon": "assault_rifle", "silencer": true},
	"fp_rifle_flash":
	{"feet": Vector3(4.25, 0, -7.45), "look": Vector3(4.25, 1.21, -18), "weapon": "assault_rifle", "flash": true},
	"rack": {"feet": Vector3(-2.2, 0, -6.2), "look": Vector3(-2.2, 1.0, -4.3)},
	"rack_signs": {"feet": Vector3(-1.2, 0, -7.0), "look": Vector3(-2.4, 1.9, -4.0)},
}

const PISTOL: ItemData = preload("res://items/weapons/pistol/pistol_item.tres")
const BATON: ItemData = preload("res://items/weapons/baton/baton_item.tres")
const AMMO: ItemData = preload("res://items/pistol_ammo/pistol_ammo.tres")
const SILENCER: ItemData = preload("res://items/attachments/silencer/silencer.tres")

## Review image size (the project's 16:9 default).
const SHOT_SIZE := Vector2i(1152, 648)

var _shot: Dictionary = {}
var _out: String = ""
var _time: float = 0.0
var _started: bool = false

@onready var _room: Node3D = $Hub/ShootingRangeRoom
@onready var _player: Player = $Hub/Player


func _ready() -> void:
	var args := {}
	for arg in OS.get_cmdline_user_args():
		var parts := arg.split("=", true, 1)
		if parts.size() == 2:
			args[parts[0]] = parts[1]
	_shot = SHOTS.get(String(args.get("shot", "firing_line")), {})
	_out = String(args.get("out", "res://reports/screenshots/range_shot.png"))
	if _shot.is_empty():
		push_error("Unknown shot %s; known: %s" % [args.get("shot"), ", ".join(SHOTS.keys())])
		get_tree().quit(1)
		return
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	# A plain window run ignores --resolution on this machine (840 x 648): force the review size.
	get_window().size = SHOT_SIZE


func _physics_process(delta: float) -> void:
	_time += delta
	if _shot.is_empty():
		return
	# Re-place every tick so the player never drifts; the first ticks let CSG build collision.
	_place_player()
	if not _started and _time > 0.2:
		_started = true
		if _shot.get("pistol", false):
			# M5: the player starts empty; the pistol goes to belt slot 1 (index 0).
			_player.inventory.give(PISTOL, 1)
			_player.inventory.give(AMMO, 30)
			_player.inventory.select_slot(0)
		if _shot.get("baton", false):
			_player.inventory.give(BATON, 1)
			_player.inventory.select_slot(0)
		if _shot.has("weapon"):
			_arm(StringName(_shot["weapon"]))
		if _shot.get("hurt", false):
			# A blast on the player through the stimulus path: the HUD silhouette must show it.
			var origin := _player.global_position + Vector3(0, 1.2, 0)
			StimulusSystem.emit(Stimulus.make_radius(&"damage.explosive", 100.0, origin, 4.0))
	if _started and (_shot.get("pistol", false) or _shot.has("weapon")):
		_player.weapons.settle()


func _process(_delta: float) -> void:
	if _shot.is_empty():
		return
	if _started and _shot.has("swing"):
		# Freeze the swing animation at this progress (0..1) every frame (the physics step resets it).
		_player.weapons.view_pivot().preview_swing(float(_shot["swing"]))
	if _time < float(_shot.get("wait", 1.0)):
		return
	var image := get_viewport().get_texture().get_image()
	image.save_png(ProjectSettings.globalize_path(_out))
	print("Saved ", _out)
	_shot = {}
	get_tree().quit()


# Gives the weapon `id` (and its ammo), fits a silencer if asked, draws it, scopes in if asked.
func _arm(id: StringName) -> void:
	var inventory := _player.inventory
	var item := inventory.catalog.find(id)
	inventory.give(item, 1)
	inventory.give(inventory.catalog.find(item.weapon.ammo_item), 30)
	var weapon := inventory.inventory.stacks[0]
	if _shot.get("silencer", false):
		inventory.give(SILENCER, 1)
		inventory.attach(inventory.inventory.stacks[-1], weapon)
	inventory.hold(weapon)
	if _shot.get("scope", false):
		_player.weapons.toggle_scope()
	if _shot.get("flash", false):
		_player.weapons.flash.hold(item.weapon, _player.weapons.state().stat(&"muzzle_flash_size"))


func _place_player() -> void:
	var feet := _room.to_global(_shot["feet"] as Vector3)
	var eye := feet + Vector3.UP * _player.config.standing_eye_height
	var to := _room.to_global(_shot["look"] as Vector3) - eye
	var state := {
		"position": feet,
		"yaw": atan2(-to.x, -to.z),
		"pitch": atan2(to.y, Vector2(to.x, to.z).length()),
		"crouched": false,
		"velocity": Vector3.ZERO,
	}
	_player.load_state(state)
