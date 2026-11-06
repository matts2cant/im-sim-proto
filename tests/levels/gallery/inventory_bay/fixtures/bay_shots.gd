extends Node3D
## Screenshot helper for reviews (not a test): first-person shots of gallery room 7 (inventory bay)
## and the hub's loadout table. Run the scene in a window with `-- shot=<name> out=<png path>`: it
## puts the hub player at a spot (eye height 1.65 m), optionally picks up the whole item table and
## opens the inventory screen, or reads the pedestal datapads and opens the log screen (ADR 0060),
## waits, saves the window image (UI included) and quits. Positions are room-local (origin on the
## hub wall, -Z into the room) unless `hub` is set.

## feet / look: points; hub: hub coordinates; take_table: pick up every item table pickup;
## inventory: open the inventory screen; read_pads: read every datapad on the pedestal (closing
## the reading overlay); log: open the log screen; augs: augmentation ids switched on; energy: the
## charge; tiers: skill -> tier; pistol: draw a pistol; stats: open the debug panel's Stats tab;
## wait: seconds.
const SHOTS: Dictionary[String, Dictionary] = {
	"spawn": {"hub": true, "feet": Vector3(0, 0, 10), "look": Vector3(0, 1.65, 0)},
	"hub_loadout": {"hub": true, "feet": Vector3(1.6, 0, 9.5), "look": Vector3(1.9, 1.0, 8.05)},
	"hub_doorway": {"hub": true, "feet": Vector3(-9, 0, 7.5), "look": Vector3(-16, 1.6, 7.5)},
	"corridor_entry": {"feet": Vector3(0, 0, 3.0), "look": Vector3(0, 1.6, -6)},
	"corridor_exit": {"feet": Vector3(0.3, 0, -2.4), "look": Vector3(0, 1.4, -12)},
	"hall_door_back": {"feet": Vector3(1.5, 0, -6.5), "look": Vector3(-0.5, 2.2, -3.6)},
	"overview": {"feet": Vector3(4.2, 0, -4.6), "look": Vector3(-3, 0.8, -16)},
	"overview_back": {"feet": Vector3(-0.5, 0, -16.5), "look": Vector3(1, 1.0, -4)},
	"item_table": {"feet": Vector3(-4.6, 0, -6.4), "look": Vector3(-5.6, 1.03, -6.0)},
	"item_table_long": {"feet": Vector3(-3.2, 0, -4.6), "look": Vector3(-5.6, 1.1, -12)},
	"stacks": {"feet": Vector3(4.0, 0, -6.6), "look": Vector3(5.6, 1.1, -6.6)},
	"fill_grid": {"feet": Vector3(3.4, 0, -12.0), "look": Vector3(5.5, 1.0, -12.0)},
	"datapad": {"feet": Vector3(3.75, 0, -17.3), "look": Vector3(3.75, 1.12, -18.7)},
	"datapads": {"feet": Vector3(2.5, 0, -16.6), "look": Vector3(3.5, 1.2, -18.7)},
	"log": {"feet": Vector3(3.5, 0, -17.3), "look": Vector3(3.5, 1.12, -18.7), "read_pads": true, "log": true},
	"drop_zone_dais": {"feet": Vector3(1, 0, -7.5), "look": Vector3(-1.5, 0.2, -16)},
	"station": {"feet": Vector3(1.5, 0, -9.0), "look": Vector3(-3.0, 1.0, -18.5)},
	"station_strip": {"feet": Vector3(-1.0, 0, -4.6), "look": Vector3(-3.4, 0.0, -12)},
	"ledge_foot": {"feet": Vector3(-5.1, 0, -16.6), "look": Vector3(-5.1, 2.0, -18.5)},
	"on_dais": {"feet": Vector3(-2.15, 0.3, -17.8), "look": Vector3(-2.15, 0.5, -19.0)},
	"on_ledge": {"feet": Vector3(-5.1, 2.3, -18.0), "look": Vector3(0, 1.0, -12)},
	"heavy_crate": {"feet": Vector3(4.6, 0, -16.6), "look": Vector3(5.2, 0.8, -18.6)},
	"hud_augs":
	{
		"feet": Vector3(1.5, 0, -9.0),
		"look": Vector3(-3.0, 1.0, -18.5),
		"augs": [&"run_silent", &"speed_enhancement", &"regeneration", &"combat_strength"],
		"energy": 73.0,
		"pistol": true,
	},
	"cloak": {"feet": Vector3(1.5, 0, -9.0), "look": Vector3(-3.0, 1.0, -18.5), "augs": [&"cloak"], "pistol": true},
	"stats":
	{
		"feet": Vector3(1.5, 0, -9.0),
		"look": Vector3(-3.0, 1.0, -18.5),
		"augs": [&"speed_enhancement"],
		"tiers": {&"pistols": 3, &"low_tech": 2, &"medicine": 1},
		"energy": 64.0,
		"stats": true,
	},
	"inventory":
	{"feet": Vector3(-4.6, 0, -10.2), "look": Vector3(-5.6, 1.0, -10.2), "take_table": true, "inventory": true},
}

const PISTOL: ItemData = preload("res://items/weapons/pistol/pistol_item.tres")

## Review image size (the project's 16:9 default).
const SHOT_SIZE := Vector2i(1152, 648)

var _shot: Dictionary = {}
var _out: String = ""
var _time: float = 0.0
var _acted: bool = false

@onready var _hub: Node3D = $Hub
@onready var _room: Node3D = $Hub/InventoryBayRoom
@onready var _player: Player = $Hub/Player


func _ready() -> void:
	# The inventory screen pauses the tree: keep counting time and saving the image.
	process_mode = Node.PROCESS_MODE_ALWAYS
	var args := {}
	for arg in OS.get_cmdline_user_args():
		var parts := arg.split("=", true, 1)
		if parts.size() == 2:
			args[parts[0]] = parts[1]
	_shot = SHOTS.get(String(args.get("shot", "overview")), {})
	_out = String(args.get("out", "res://reports/screenshots/bay_shot.png"))
	if _shot.is_empty():
		push_error("Unknown shot %s; known: %s" % [args.get("shot"), ", ".join(SHOTS.keys())])
		get_tree().quit(1)
		return
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	# A plain window run ignores --resolution on this machine (840 x 648): force the review size.
	get_window().size = SHOT_SIZE


func _physics_process(_delta: float) -> void:
	if _shot.is_empty() or _acted:
		return
	# Re-place every tick so the player never drifts; the first ticks let CSG build collision.
	_place_player()


func _process(delta: float) -> void:
	_time += delta
	if _shot.is_empty():
		return
	if not _acted and _time > 0.6:
		_acted = true
		_act()
	if _time < float(_shot.get("wait", 1.2)):
		return
	var image := get_viewport().get_texture().get_image()
	image.save_png(ProjectSettings.globalize_path(_out))
	print("Saved ", _out)
	_shot = {}
	get_tree().quit()


func _act() -> void:
	if _shot.get("take_table", false):
		for child: Node in _room.get_node("ItemTable").get_children():
			var pickup := ItemPickup.of(child)
			if pickup != null:
				_player.inventory.pick_up(pickup)
	if _shot.get("inventory", false):
		_player.input_enabled = true
		(_player.get_node("InventoryScreen") as InventoryScreen).open()
	if _shot.get("read_pads", false):
		for child: Node in _room.get_node("DatapadPedestal").get_children():
			var readable := Usable.of(child) as Readable
			if readable != null:
				readable.use(_player)
		(_player.get_node("ReadingOverlay") as ReadingOverlay).close()
	if _shot.get("log", false):
		_player.input_enabled = true
		(_player.get_node("LogScreen") as LogScreen).open()
	_act_abilities()


func _act_abilities() -> void:
	if _shot.has("energy"):
		_player.energy.set_current(float(_shot["energy"]))
	var tiers: Dictionary = _shot.get("tiers", {})
	for skill: Variant in tiers:
		_player.skills.set_tier(StringName(str(skill)), int(tiers[skill]))
	for id: Variant in _shot.get("augs", []):
		_player.augmentations.activate(StringName(str(id)))
	if _shot.get("pistol", false):
		_player.inventory.give(PISTOL, 1)
		_player.inventory.use_stack(_player.inventory.inventory.stacks_of(&"pistol")[0])
	if _shot.get("stats", false):
		DebugPanel.set_open(true)
		var tabs := DebugPanel.get_node("TabContainer") as TabContainer
		for index in tabs.get_tab_count():
			if tabs.get_tab_title(index) == "Stats":
				tabs.current_tab = index


func _place_player() -> void:
	var space: Node3D = _hub if _shot.get("hub", false) else _room
	var feet := space.to_global(_shot["feet"] as Vector3)
	var eye := feet + Vector3.UP * _player.config.standing_eye_height
	var to := space.to_global(_shot["look"] as Vector3) - eye
	var state := {
		"position": feet,
		"yaw": atan2(-to.x, -to.z),
		"pitch": atan2(to.y, Vector2(to.x, to.z).length()),
		"crouched": false,
		"velocity": Vector3.ZERO,
	}
	_player.load_state(state)
