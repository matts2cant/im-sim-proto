extends Node
## Screenshot helper for reviews (not a test): the mission fixture's screens (ADR 0087). Run the
## scene in a window with `-- shot=<name> out=<png path>`; it plays the steps, saves the window image
## (UI included) and quits. Shots: `briefing` (at the start), `toast` (the main objective done),
## `summary` (extraction with every objective done: the three badges), `weapon_drop` (a knocked-out
## pistol guard and its pistol beside it, seen from 2.7 m at eye height).

const SHOTS: Array[String] = ["briefing", "toast", "summary", "weapon_drop"]
const GUARD := preload("res://actors/guard/guard_pistol.tscn")
## Review image size (the project's 16:9 default).
const SHOT_SIZE := Vector2i(1152, 648)
const ORIGIN := Vector3(-300, 0, 600)

var _shot: String = ""
var _out: String = ""
var _time: float = 0.0
var _step: int = 0

@onready var _level: Node3D = $MissionFixture


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var args := {}
	for arg in OS.get_cmdline_user_args():
		var parts := arg.split("=", true, 1)
		if parts.size() == 2:
			args[parts[0]] = parts[1]
	_shot = String(args.get("shot", "briefing"))
	_out = String(args.get("out", "res://reports/screenshots/mission_%s.png" % _shot))
	if not SHOTS.has(_shot):
		push_error("Unknown shot %s; known: %s" % [_shot, ", ".join(SHOTS)])
		get_tree().quit(1)
		return
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	# A plain window run ignores --resolution on this machine (840 x 648): force the review size.
	get_window().size = SHOT_SIZE


func _process(delta: float) -> void:
	_time += delta
	if _shot.is_empty():
		return
	var mission := _level.get_node("Mission") as Mission
	var player := _level.get_node_or_null("Player") as Player
	if player == null:
		return
	if _step == 0 and _time > 0.6 and _shot != "briefing":
		_step = 1
		player.input_enabled = false
		mission.briefing.close()
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		match _shot:
			"toast":
				_look(player, Vector3(0, 0, 8.2), Vector3(2, 0.0, 6))
				_read(player)
			"summary":
				_read(player)
				player.inventory.pick_up(ItemPickup.of(_level.get_node("Keycard")))
				(_level.get_node("Shipment/Flammable") as Flammable).ignite(null)
				_look(player, Vector3(0, 0, -12), Vector3(0, 1.2, -20))
			"weapon_drop":
				ActorState.set_tag(player, &"actor.player", false)
				var guard := GUARD.instantiate() as Node3D
				guard.name = "Guard"
				_level.add_child(guard)
				guard.global_transform = Transform3D(Basis(Vector3.UP, PI), ORIGIN + Vector3(0, 0, 6.5))
				(guard.get_node("BodyParts") as BodyParts).take_damage(&"damage.stun", 200.0)
				_look(player, Vector3(0.6, 0, 9.0), Vector3(0.2, 0.1, 6.6))
	if _time < 3.0:
		return
	var image := get_viewport().get_texture().get_image()
	image.save_png(ProjectSettings.globalize_path(_out))
	print("Saved ", _out)
	_shot = ""
	get_tree().quit()


# Puts the player's feet at fixture-local `feet`, looking at fixture-local `look` from eye height.
func _look(player: Player, feet: Vector3, look: Vector3) -> void:
	var eye := ORIGIN + feet + Vector3.UP * player.config.standing_eye_height
	var to := ORIGIN + look - eye
	var state := {
		"position": ORIGIN + feet,
		"yaw": atan2(-to.x, -to.z),
		"pitch": atan2(to.y, Vector2(to.x, to.z).length()),
		"crouched": false,
		"velocity": Vector3.ZERO,
	}
	player.load_state(state)


func _read(player: Player) -> void:
	(_level.get_node("Manifest/Readable") as Readable).use(player)
	(player.get_node("ReadingOverlay") as ReadingOverlay).close()
