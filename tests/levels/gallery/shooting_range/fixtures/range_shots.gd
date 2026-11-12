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
	# M13a (ADR 0125): the widened range, its tools and the connections of the new east part.
	"lanes": {"feet": Vector3(9.5, 0, -7.45), "look": Vector3(13.0, 1.4, -30), "spray": true},
	"spray_wall": {"feet": Vector3(12.5, 0, -7.45), "look": Vector3(12.5, 1.6, -18), "spray": true},
	# Beside the line of fire (the spray comes from the firing line).
	"spray_close": {"feet": Vector3(13.7, 0, -14.0), "look": Vector3(12.5, 1.9, -18), "spray": true},
	"stats_board": {"feet": Vector3(14.5, 0, -7.45), "look": Vector3(14.5, 3.2, -12), "spray": true},
	"controls": {"feet": Vector3(14.6, 0, -7.25), "look": Vector3(14.6, 1.0, -8.4)},
	"tuning_panel":
	{"feet": Vector3(15, 0, -7.45), "look": Vector3(15, 1.27, -8.3), "weapon": "assault_rifle", "tune": true},
	"walker": {"feet": Vector3(17.5, 0, -7.45), "look": Vector3(17.5, 1.2, -23), "pistol": true},
	"booth_east": {"feet": Vector3(11.0, 0, -5.0), "look": Vector3(20.5, 1.4, -6.5)},
	"rack2": {"feet": Vector3(5.2, 0, -6.4), "look": Vector3(5.2, 1.0, -4.3)},
	"counter_east_end": {"feet": Vector3(19.4, 0, -7.2), "look": Vector3(20.5, 1.0, -8.6)},
	"east_wall_far": {"feet": Vector3(18.5, 0, -44.0), "look": Vector3(20.5, 1.2, -52)},
	"booth_south_east": {"feet": Vector3(18.0, 0, -6.8), "look": Vector3(20.5, 2.0, -4.0)},
	# M13a weapon feel (ADR 0123): the SMG at eye height; the crosshair on nothing, and mid-spray
	# (fire: the trigger held from the start, the recoil climbing the camera) on the 10 m dummy.
	"fp_smg": {"feet": Vector3(4.25, 0, -7.45), "look": Vector3(4.25, 1.21, -18), "weapon": "smg"},
	"fp_smg_silenced":
	{"feet": Vector3(4.25, 0, -7.45), "look": Vector3(4.25, 1.21, -18), "weapon": "smg", "silencer": true},
	"fp_smg_spray":
	{"feet": Vector3(4.25, 0, -7.45), "look": Vector3(4.25, 1.21, -18), "weapon": "smg", "fire": true, "wait": 0.75},
	"fp_rifle_spray":
	{
		"feet": Vector3(4.25, 0, -7.45),
		"look": Vector3(4.25, 1.21, -18),
		"weapon": "assault_rifle",
		"fire": true,
		"wait": 0.75
	},
	"crosshair_nothing": {"feet": Vector3(4.25, 0, -7.45), "look": Vector3(6.5, 0.0, -12), "weapon": "pistol"},
	# M13b weapon motion (ADR 0128): the pistol halfway through its 1.6 s reload (dipped out of view),
	# the assault rifle and the shotgun halfway through their draws (0.4 s, 0.45 s).
	"fp_pistol_reload":
	{
		"feet": Vector3(4.25, 0, -7.45),
		"look": Vector3(4.25, 1.21, -18),
		"weapon": "pistol",
		"reload": true,
		"wait": 1.0
	},
	"fp_rifle_draw":
	{"feet": Vector3(4.25, 0, -7.45), "look": Vector3(4.25, 1.21, -18), "weapon": "assault_rifle", "wait": 0.42},
	"fp_shotgun_draw":
	{"feet": Vector3(4.25, 0, -7.45), "look": Vector3(4.25, 1.21, -18), "weapon": "shotgun", "wait": 0.45},
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
		if _shot.get("spray", false):
			_spray()
		if _shot.get("tune", false):
			var desk := _room.get_node("FiringLine/TuningTerminal/TuningDesk") as TuningDesk
			desk.use(_player)
	if _started and _shot.get("fire", false):
		# The trigger kept down: the weapon fires each cycle (recoil climbing the camera) until the shot.
		_player.weapons.trigger()
	if _started and (_shot.get("pistol", false) or _shot.has("weapon")) and not _shot.get("fire", false):
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
	if _shot.get("reload", false):
		_player.weapons.state().magazine = 2
		_player.weapons.reload()


# A scripted 30-round spray from the firing line in lane 5 at the spray wall's aim mark (a climbing,
# drifting pattern with a little noise), through bullet ray stimuli like a weapon's: marks on the
# wall, counts on the stats board.
func _spray() -> void:
	var eye := _room.to_global(Vector3(12.5, 1.65, -7.45))
	var aim := _room.to_global(Vector3(12.5, 1.4, -18)) - eye
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in 30:
		var climb := deg_to_rad(minf(i, 12) * 0.55 + rng.randf_range(-0.2, 0.2))
		var drift := deg_to_rad((sin(i * 0.45) * 1.6 if i > 8 else 0.0) + rng.randf_range(-0.25, 0.25))
		var direction := aim.normalized().rotated(Vector3.UP, drift)
		direction = direction.rotated(direction.cross(Vector3.UP).normalized(), climb)
		StimulusSystem.emit(Stimulus.make_ray(&"damage.ballistic", 14.0, eye, direction, 60.0, null))


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
