extends Node3D
## Screenshot helper for reviews (not a test): first-person shots of the warehouse mission at eye
## height (1.65 m) and free-camera overviews. Run the scene in a window with
## `-- shots=<name>,<name> out=<folder>` (or `shots=all`): for each shot it places the player (or the
## overview camera), waits, saves `<folder>/<name>.png` and quits after the last one. Positions are
## warehouse coordinates (x east, z south, origin at the compound centre). `crouch`: crouched eye
## height. `cam`: a free camera at `eye` instead of the player (HUD hidden). User args: `dark=1`
## turns breakers A and B off; `perf=1` prints frames per second (vsync off); `lit=1` raises the
## ambient light and clears the fog (layout review only: it is not what the player sees).

const SHOTS: Dictionary[String, Dictionary] = {
	# Overviews (free camera).
	"overview_north": {"cam": true, "eye": Vector3(-10, 45, -75), "look": Vector3(0, 0, 0)},
	"overview_south": {"cam": true, "eye": Vector3(15, 40, 70), "look": Vector3(0, 0, -2)},
	"overview_top": {"cam": true, "eye": Vector3(5, 110, 4), "look": Vector3(5, 0, 3)},
	"overview_east": {"cam": true, "eye": Vector3(75, 35, 5), "look": Vector3(10, 0, 0)},
	"hall_cutaway": {"cam": true, "eye": Vector3(-30, 22, -2), "look": Vector3(0, 3, 4), "hide": ["Hall/Shell/Hall"]},
	"office_cutaway": {"cam": true, "eye": Vector3(4, 14, -14), "look": Vector3(14, 2, 6), "hide": ["Hall/Shell/Hall"]},
	"basement_cutaway":
	{"cam": true, "eye": Vector3(4, 10, -20), "look": Vector3(16, -4, 0), "hide": ["Hall", "Exterior/Ground"]},
	# Start and the approach.
	"start": {"feet": Vector3(-19, 0, -31.2), "look": Vector3(-4, 1.5, -16)},
	"start_east": {"feet": Vector3(-19, 0, -31.2), "look": Vector3(40, 8, -20)},
	"gate_road": {"feet": Vector3(-5, 0, -31), "look": Vector3(-5, 1.4, -15)},
	"gate_inside": {"feet": Vector3(-5, 0, -19), "look": Vector3(-5, 1.4, -26)},
	"booth": {"feet": Vector3(-8.6, 0, -22), "look": Vector3(-11, 1.4, -22)},
	"fence_container_out": {"feet": Vector3(-29, 0, -30.5), "look": Vector3(-29, 2.2, -25)},
	"fence_container_top": {"feet": Vector3(-29, 2.5, -26.6), "look": Vector3(-29, 2.0, -20)},
	"fence_container_in": {"feet": Vector3(-29, 0, -19.5), "look": Vector3(-29, 2.3, -25)},
	"yard_from_gate": {"feet": Vector3(-4, 0, -23), "look": Vector3(0, 2, -10)},
	"yard_west": {"feet": Vector3(-20, 0, -21), "look": Vector3(-6, 2, -10)},
	"yard_east": {"feet": Vector3(14, 0, -22), "look": Vector3(28, 2, -10)},
	"yard_perch": {"feet": Vector3(-27, 5.0, -14), "look": Vector3(-5, 0, -14)},
	"dock_apron": {"feet": Vector3(-14, 0, -18), "look": Vector3(-4, 2, -10.5)},
	"under_trailer": {"feet": Vector3(4, 0, -16.5), "look": Vector3(4, 0.5, -10), "crouch": true},
	"side_door": {"feet": Vector3(-25, 0, -7), "look": Vector3(-20.5, 1.2, -6)},
	"dumpster": {"feet": Vector3(-23.5, 0, -11), "look": Vector3(-21.8, 0.6, -9)},
	"west_yard": {"feet": Vector3(-28, 0, -10), "look": Vector3(-24, 2, 6)},
	"annex_chain": {"feet": Vector3(-32.5, 0, 6), "look": Vector3(-27, 3.0, 6)},
	"annex_crate": {"feet": Vector3(-28.3, 2.5, 6), "look": Vector3(-25, 4.6, 6)},
	"annex_roof": {"feet": Vector3(-25, 4.75, 2.6), "look": Vector3(-20.5, 5.8, 2.1)},
	"annex_roof_stair": {"feet": Vector3(-24, 4.75, 12.2), "look": Vector3(-21.2, 7, 6)},
	"east_yard": {"feet": Vector3(32, 0, 18), "look": Vector3(22, 3, 4)},
	"drain_chamber_top": {"feet": Vector3(29.5, 0, -7.6), "look": Vector3(33, -2.4, -7.6)},
	"fire_escape_bottom": {"feet": Vector3(21.2, 0, 15.5), "look": Vector3(21.2, 1.6, 10)},
	"fire_escape_door": {"feet": Vector3(22.3, 4.5, 6.5), "look": Vector3(20, 5.6, 6)},
	"fire_escape_up": {"feet": Vector3(21.2, 4.5, 4.6), "look": Vector3(21.2, 8, -3)},
	"back_strip": {"feet": Vector3(-25, 0, 23), "look": Vector3(-8, 1.5, 16)},
	"weak_wall": {"feet": Vector3(-10, 0, 20), "look": Vector3(-10, 1.2, 15.5)},
	"back_gate_out": {"feet": Vector3(7, 0, 28), "look": Vector3(7, 1.4, 22)},
	"riverside": {"feet": Vector3(0, 0, 28.5), "look": Vector3(10, 0.5, 37)},
	"ditch_ramp": {"feet": Vector3(39, 0, -29), "look": Vector3(39, -2, -18)},
	"ditch_floor": {"feet": Vector3(39, -2.4, -9), "look": Vector3(36.5, -1.4, -6)},
	"ditch_south": {"feet": Vector3(39, -2.4, 17), "look": Vector3(39, -1, 23)},
	"culvert_in": {"feet": Vector3(35.6, -2.4, -7.6), "look": Vector3(31, -1.8, -7.6), "crouch": true},
	"tower_base": {"feet": Vector3(50.6, 0, -6.5), "look": Vector3(51, 5, -12)},
	"tower_perch": {"feet": Vector3(42.8, 20, -16), "look": Vector3(0, 6, -10)},
	"tower_skylights": {"feet": Vector3(42.8, 20, -16), "look": Vector3(-4, 8.5, 3)},
	# Roof.
	"roof_arrival": {"feet": Vector3(19.5, 9.5, -3.9), "look": Vector3(0, 9, 4)},
	"roof_skylight": {"feet": Vector3(-5, 9.5, 0.6), "look": Vector3(-5, 7.5, 3.8)},
	"roof_vent_a": {"feet": Vector3(14, 9.5, 2.0), "look": Vector3(14, 10, -1)},
	"roof_vent_b": {"feet": Vector3(11, 9.5, -6.0), "look": Vector3(11, 10, -3)},
	# Hall interior.
	"hall_dock": {"feet": Vector3(-8, 0, -12), "look": Vector3(-6, 3, 5)},
	"hall_floor_aisle": {"feet": Vector3(-9, 0, -4), "look": Vector3(-9, 2, 14)},
	"hall_from_catwalk": {"feet": Vector3(-19.2, 4.5, -9.2), "look": Vector3(10, 1, 8)},
	"catwalk_north": {"feet": Vector3(-17, 4.5, -9.25), "look": Vector3(20, 4.5, -9.25)},
	"bridge": {"feet": Vector3(-18, 4.5, 6), "look": Vector3(8, 5, 6)},
	"bridge_rack": {"feet": Vector3(-5, 4.5, 6), "look": Vector3(-5, 5.5, 2)},
	"skylight_landing": {"feet": Vector3(-5, 8.0, 3.8), "look": Vector3(-5, 4.5, 7)},
	"rack_deck": {"feet": Vector3(-13, 4.4, 9.5), "look": Vector3(-13, 5, 6)},
	"stair_ne": {"feet": Vector3(17.8, 0, 0), "look": Vector3(17.8, 3, -8)},
	"stair_sw": {"feet": Vector3(-8, 0, 12.8), "look": Vector3(-18, 4, 12.8)},
	"duct_alcove": {"feet": Vector3(14, 4.5, -9.0), "look": Vector3(14, 5.6, -7)},
	"annex_door_inside": {"feet": Vector3(-19.2, 4.5, 4), "look": Vector3(-20.5, 5.6, 2.1)},
	"hatch": {"feet": Vector3(11.1, 0, -8.5), "look": Vector3(11.1, -1, -4)},
	"duct_c_hall": {"feet": Vector3(12.5, 0, -3.5), "look": Vector3(15, 0.6, -0.5)},
	"office_front": {"feet": Vector3(4, 0, 6), "look": Vector3(8, 1.5, 6)},
	"weak_wall_inside": {"feet": Vector3(-10, 0, 11.8), "look": Vector3(-10, 1.2, 15)},
	"side_door_inside": {"feet": Vector3(-16, 0, -6), "look": Vector3(-20, 1.2, -6)},
	# Office block.
	"ground_corridor": {"feet": Vector3(9, 0, 6), "look": Vector3(19, 1.5, 6)},
	"security_room": {"feet": Vector3(15, 0, 4.5), "look": Vector3(18, 1.2, 0.5)},
	"security_duct": {"feet": Vector3(16.5, 0, 3), "look": Vector3(15, 0.5, 0.3)},
	"stairwell": {"feet": Vector3(10.6, 0, 7.6), "look": Vector3(10.6, 0.5, 14)},
	"upper_corridor": {"feet": Vector3(9, 4.5, 6), "look": Vector3(19, 6, 6)},
	"manager_office": {"feet": Vector3(9, 4.5, 4.4), "look": Vector3(12, 5.5, 1)},
	"cabinet": {"feet": Vector3(11, 4.5, 4.5), "look": Vector3(11, 6.5, 2.8)},
	"vault": {"feet": Vector3(16.9, 4.5, 4.5), "look": Vector3(17, 5.3, 0.5)},
	# Underground.
	"service_stair": {"feet": Vector3(8.9, 0, 7.6), "look": Vector3(8.9, -2, 12)},
	"basement_store": {"feet": Vector3(10, -4, 14), "look": Vector3(16, -2.5, 2)},
	"boiler_room": {"feet": Vector3(9, -4, -8), "look": Vector3(17, -2.5, -3)},
	"hatch_stair": {"feet": Vector3(11.1, -4, 0.5), "look": Vector3(11.1, -1.5, -6)},
	"duct_c_mouth": {"feet": Vector3(15, -4, -7.5), "look": Vector3(15, -2.4, -5)},
	"tunnel": {"feet": Vector3(20.5, -4, -5), "look": Vector3(36, -2, -5)},
	"tunnel_east": {"feet": Vector3(35.5, -2.4, -5), "look": Vector3(25, -3, -5)},
	"chamber": {"feet": Vector3(33.4, -2.4, -6.6), "look": Vector3(31, -1, -8)},
	# Population (wave 2): guards at their posts or moved onto a point of their route (`guard`,
	# `guard_at`), the equipment, the mission props.
	"people_g1_gate": {"feet": Vector3(-5, 0, -18.5), "look": Vector3(-8.6, 1.3, -22.2)},
	"people_g2_side_door":
	{
		"feet": Vector3(-28, 0, -1),
		"look": Vector3(-23, 1.2, -8),
		"guard": "G2YardPatrolWest",
		"guard_at": Vector3(-24.5, 0, -8.5)
	},
	"people_g3_drain_exit":
	{
		"feet": Vector3(24, 0, -15),
		"look": Vector3(30, 1.2, -7.5),
		"guard": "G3YardPatrolEast",
		"guard_at": Vector3(30, 0, -7.5)
	},
	"people_g3_back_gate":
	{
		"feet": Vector3(7, 0, 28),
		"look": Vector3(8, 1.2, 20.5),
		"guard": "G3YardPatrolEast",
		"guard_at": Vector3(8, 0, 20.5)
	},
	"people_g4_catwalk": {"feet": Vector3(-18.5, 4.5, -9.25), "look": Vector3(-10, 5.6, -9.25)},
	"people_g4_bridge":
	{
		"feet": Vector3(-14, 4.5, 6),
		"look": Vector3(2, 5.6, 6),
		"guard": "G4CatwalkRifle",
		"guard_at": Vector3(2, 4.5, 6)
	},
	"people_g5_security": {"feet": Vector3(15, 0, 4.5), "look": Vector3(17.6, 1.2, 1.6)},
	"people_g6_break_room": {"feet": Vector3(11, 0, 6.2), "look": Vector3(11, 1.2, 2.6)},
	"people_g7_vault_door": {"feet": Vector3(9.5, 4.5, 6), "look": Vector3(16, 5.6, 6)},
	"people_g8_store": {"feet": Vector3(10, -4, 13.5), "look": Vector3(16.2, -3, 11.5)},
	"people_perch_rifle": {"feet": Vector3(44.2, 20, -14.8), "look": Vector3(42.6, 20.1, -13.2)},
	"people_shipment": {"feet": Vector3(-4, 0, -9.6), "look": Vector3(0.3, 1.0, -6.6)},
	"people_shipment_apron": {"feet": Vector3(4, 0, -15), "look": Vector3(1.5, 1.0, -7)},
	"people_gas_cylinders": {"feet": Vector3(-8.4, 0, 19.0), "look": Vector3(-10.9, 0.8, 15.6)},
	"people_vault_prototype": {"feet": Vector3(16.9, 4.5, 4.5), "look": Vector3(19, 5.3, 3.5)},
	"people_duct_b_cabinet": {"feet": Vector3(11, 4.5, 4.7), "look": Vector3(11, 6.6, 2.4)},
	"people_duct_b_hatch": {"feet": Vector3(11, 6.1, 3.0), "look": Vector3(11, 7.4, 1.8), "crouch": true},
	"people_silencer_locker": {"feet": Vector3(17.5, 0, 12.2), "look": Vector3(19.45, 1.0, 12.4)},
	"people_lockpicks": {"feet": Vector3(10, -4, 3.2), "look": Vector3(8.4, -3.1, 3)},
	"people_boat": {"feet": Vector3(5.5, 0, 34), "look": Vector3(11.6, 0.6, 37.5)},
}

## Review image size (the project's 16:9 default).
const SHOT_SIZE := Vector2i(1152, 648)
const WAIT := 1.2

var _queue: Array[String] = []
var _out := "res://reports/screenshots/warehouse"
var _shot: Dictionary = {}
var _time := 0.0
var _camera: Camera3D
## `perf=1`: vsync off, and each shot prints the frames per second while it waits.
var _perf := false
var _frames := 0

@onready var _level: Node3D = $Warehouse
@onready var _player: Player = $Warehouse/Player
@onready var _mission: Mission = $Warehouse/Mission


func _ready() -> void:
	# Keeps running while the mission briefing pauses the tree, and closes it.
	process_mode = Node.PROCESS_MODE_ALWAYS
	var args := {}
	for arg in OS.get_cmdline_user_args():
		var parts := arg.split("=", true, 1)
		if parts.size() == 2:
			args[parts[0]] = parts[1]
	var names := String(args.get("shots", "start"))
	var wanted: Array = SHOTS.keys() if names == "all" else Array(names.split(","))
	for shot_name: String in wanted:
		if not SHOTS.has(shot_name):
			push_error("Unknown shot %s" % shot_name)
			continue
		_queue.append(shot_name)
	_out = String(args.get("out", _out))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_out))
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_window().size = SHOT_SIZE
	_camera = Camera3D.new()
	_camera.far = 400.0
	add_child(_camera)
	if args.get("lit", "") == "1":
		var environment := (_level.get_node("WorldEnvironment") as WorldEnvironment).environment
		environment.ambient_light_energy = 1.2
		environment.fog_enabled = false
	if args.get("perf", "") == "1":
		_perf = true
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	if args.get("dark", "") == "1":
		Powered.set_circuit(get_tree(), &"warehouse_yard", false)
		Powered.set_circuit(get_tree(), &"warehouse_building", false)
	_next()


func _next() -> void:
	if _queue.is_empty():
		get_tree().quit()
		return
	var shot_name: String = _queue.pop_front()
	_shot = SHOTS[shot_name].duplicate()
	_shot["name"] = shot_name
	_time = 0.0
	for path: String in _shot.get("hide", []):
		(_level.get_node(path) as Node3D).visible = false
	if _shot.has("guard"):
		var guard := _level.get_node("Population/People/Guards/" + String(_shot["guard"])) as Node3D
		guard.global_position = _shot["guard_at"]


func _physics_process(_delta: float) -> void:
	if _shot.is_empty():
		return
	ActorState.set_tag(_player, &"actor.player", false)
	(_player.get_node("Hud") as CanvasLayer).visible = not _shot.get("cam", false)
	if _shot.get("cam", false):
		_camera.current = true
		_camera.global_transform = Transform3D.IDENTITY.translated(_shot["eye"] as Vector3)
		_camera.look_at(_shot["look"] as Vector3)
		return
	_camera.current = false
	_place_player()


func _process(delta: float) -> void:
	if _mission.briefing.is_open():
		_mission.briefing.close()
	if _shot.is_empty() or get_tree().paused:
		return
	_time += delta
	if _time > 0.5:
		_frames += 1
	if _time < WAIT:
		return
	if _perf:
		print("%s: %.0f fps" % [_shot["name"], _frames / (_time - 0.5)])
	_frames = 0
	var path := "%s/%s.png" % [_out, _shot["name"]]
	get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path(path))
	print("Saved ", path)
	for hidden: String in _shot.get("hide", []):
		(_level.get_node(hidden) as Node3D).visible = true
	_shot = {}
	_next()


func _place_player() -> void:
	var crouched: bool = _shot.get("crouch", false)
	var feet: Vector3 = _shot["feet"]
	var eye_height := _player.config.crouched_eye_height if crouched else _player.config.standing_eye_height
	var to: Vector3 = (_shot["look"] as Vector3) - (feet + Vector3.UP * eye_height)
	(
		_player
		. load_state(
			{
				"position": feet,
				"yaw": atan2(-to.x, -to.z),
				"pitch": atan2(to.y, Vector2(to.x, to.z).length()),
				"crouched": crouched,
				"velocity": Vector3.ZERO,
			}
		)
	)
