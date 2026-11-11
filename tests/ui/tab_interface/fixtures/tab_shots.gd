extends Node
## Screenshot fixture (ADR 0110; windowed runs only, through tools/run_windowed.sh): a lit room with
## the player carrying a mixed loadout, a personal log with codes and logins, and an inert Mission
## with the warehouse data (one secondary objective done). Opens the Tab interface on the tab of
## `shot` and saves the window (UI included) to reports/screenshots/m11_<shot>.png, then quits.
## Shots: inventory, inventory_medkit, health, augmentations, skills, objectives, codes, exploits, notes, hit
## (the inventory during a hit's edge flash). Command line after `--`: shot=<name>.
## A real-time watchdog saves what is shown and quits after WATCHDOG seconds.

const Items := preload("res://tests/items/item_test_helpers.gd")
const MISSION_SCENE := "res://levels/mission/mission_kit/mission.tscn"
const MISSION_DATA := "res://levels/mission/mission_kit/warehouse_mission.tres"
const SILENCER := "res://items/attachments/silencer/silencer.tres"
const RIFLE := "res://items/weapons/assault_rifle/assault_rifle_item.tres"
const RIFLE_ROUNDS := "res://items/rifle_rounds/rifle_rounds.tres"
const PROTOTYPE := "res://items/prototype/prototype.tres"
const OUT := "res://reports/screenshots/m11_%s.png"
const ACT_AFTER := 0.8
const SHOOT_AFTER := 1.6
const WATCHDOG := 25.0
## shot -> [tab index, journal section or -1].
const SHOTS := {
	"inventory": [0, -1],
	"inventory_medkit": [0, -1],
	"health": [1, -1],
	"augmentations": [2, -1],
	"skills": [3, -1],
	"objectives": [4, 0],
	"codes": [4, 1],
	"exploits": [4, 2],
	"notes": [4, 3],
	"hit": [0, -1],
}

@export var player_path: NodePath

var shot: String = "inventory"

var _time: float = 0.0
var _acted: bool = false
var _hit_frames: int = -1
var _player: Player


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	DisplayServer.window_set_size(Vector2i(1152, 648))
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("shot="):
			shot = arg.trim_prefix("shot=")
	if not SHOTS.has(shot):
		push_warning("tab_shots: unknown shot %s" % shot)
		get_tree().quit()
		return
	_player = get_node(player_path) as Player
	if not _player.is_node_ready():
		await _player.ready
	_player.reload_on_reset = false
	_give()
	_fill_log()
	var mission := (load(MISSION_SCENE) as PackedScene).instantiate() as Mission
	mission.data = load(MISSION_DATA) as MissionData
	get_parent().add_child.call_deferred(mission)
	mission.ready.connect(func() -> void: mission.tracker.done.append(&"prototype"))


func _process(delta: float) -> void:
	_time += delta
	if not _acted and _time >= ACT_AFTER:
		_acted = true
		_act()
	if shot == "hit" and _hit_frames < 0 and _time >= SHOOT_AFTER - 0.1:
		_player.body.take_damage(&"damage.blunt", 4.0, &"torso")
		_hit_frames = 0
	if _hit_frames >= 0:
		_hit_frames += 1
		if _hit_frames >= 2:
			_save()
			return
	if shot != "hit" and _time >= SHOOT_AFTER:
		_save()
	elif _time >= WATCHDOG:
		_save()


func _act() -> void:
	var tabs := TabInterface.of(_player)
	var spec: Array = SHOTS[shot]
	tabs.open(int(spec[0]))
	if shot == "inventory_medkit":
		(tabs.page(0) as InventoryTab).select(_player.inventory.inventory.stacks_of(&"medkit")[0])
	elif shot.begins_with("inventory") or shot == "hit":
		(tabs.page(0) as InventoryTab).select(_player.inventory.inventory.stacks_of(&"pistol")[0])
	if int(spec[1]) >= 0:
		var journal := tabs.page(4) as JournalTab
		journal.show_section(JournalTab.Section.values()[int(spec[1])])
		if shot == "notes":
			journal.open_note(&"warehouse.shift_notes")


func _save() -> void:
	var image := get_viewport().get_texture().get_image()
	var path := OUT % shot
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
	image.save_png(ProjectSettings.globalize_path(path))
	set_process(false)
	get_tree().quit()


func _give() -> void:
	var inventory := _player.inventory
	inventory.give(Items.PISTOL, 1, {"magazine": 8})
	inventory.give(load(RIFLE) as ItemData, 1, {"magazine": 21})
	inventory.give(Items.KEYCARD, 1, {"key_id": "vault"})
	inventory.give(Items.BATON, 1)
	inventory.give(Items.AMMO, 10)
	inventory.give(Items.MEDKIT, 2)
	inventory.give(load(RIFLE_ROUNDS) as ItemData, 24)
	inventory.give(Items.LOCKPICK, 2)
	inventory.give(Items.BIOCELL, 1)
	inventory.give(load(PROTOTYPE) as ItemData, 1)
	inventory.give(load(SILENCER) as ItemData, 1)
	_player.body.take_damage(&"damage.blunt", 30.0, &"arm_l")


func _fill_log() -> void:
	var reader_log := PersonalLog.of(_player)
	reader_log.add(
		LogEntry.make(
			&"warehouse.side_door_code",
			"Crumpled note",
			"Side door code changed again: 2390. Stop propping it open with a pallet. - Facilities",
			"Datapad",
			{&"warehouse_side_door": "2390"},
			{&"warehouse_side_door": "Side door"}
		)
	)
	(
		reader_log
		. add(
			(
				LogEntry
				. make(
					&"warehouse.console_audit",
					"Console audit",
					"Security console in the ground-floor security room: user dmarsh, password harbor77. Change it after the audit.",
					"Datapad",
					{&"warehouse_security_console": "dmarsh:harbor77"},
					{&"warehouse_security_console": "Security console login"}
				)
			)
		)
	)
	var helix := Exploit.make(
		&"helix_default_login", "Helix default service login", "Helix", "CAM-3", "2.0", "2.1", Exploit.Access.ADMIN
	)
	var halcyon := Exploit.make(&"halcyon_share_overflow", "Halcyon share overflow", "Halcyon", "OS", "4.0", "4.3")
	reader_log.add(
		LogEntry.make(
			&"warehouse.camera_firmware",
			"Camera firmware",
			"From IT\n\nThe Helix cameras still answer on the factory service login. Update them before the audit.",
			"Mail",
			{},
			{},
			[helix]
		)
	)
	reader_log.add(
		LogEntry.make(
			&"warehouse.usb_stick",
			"Klaus's USB stick",
			"halcyon_smb.txt: overflow in the file share of Halcyon OS 4.0 to 4.3. Gets you a user session.",
			"Datapad",
			{},
			{},
			[halcyon]
		)
	)
	reader_log.add(
		LogEntry.make(
			&"warehouse.shift_notes",
			"Night shift notes",
			"Hale wants his office kept shut: the door code is 4471. Klaus, your office PC login is kbrandt / ferry19.",
			"Datapad",
			{&"warehouse_manager_office": "4471", &"warehouse_office_pc2": "kbrandt:ferry19"},
			{&"warehouse_manager_office": "Manager's office door", &"warehouse_office_pc2": "Office PC 2 login"}
		)
	)
