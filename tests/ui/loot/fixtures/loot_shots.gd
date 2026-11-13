extends Node
## Screenshot fixture (ADR 0142; windowed runs only, through tools/run_windowed.sh): the player in a
## lit room loots a knocked-out guard stand-in (an Inventory with a pistol, ammo, a medkit and a baton,
## a keycard and a key on its keychain). Both keychains are the M14d contract's test stand-in (kinds,
## remove()) until the systems side lands. Saves the window to
## reports/screenshots/m14d_loot_<shot>.png, then quits.
## Shots: open, take_all (after Take all), drag_ok (the pistol over a free spot: green), drag_bad
## (over the player's rifle: red), keychain (the Inventory tab's keychain with a key and a card).
## Command line after `--`: shot=<name>. A real-time watchdog saves what is shown and quits.

const Helpers := preload("res://tests/ui/loot/loot_helpers.gd")
const Items := preload("res://tests/items/item_test_helpers.gd")
const RIFLE := "res://items/weapons/assault_rifle/assault_rifle_item.tres"
const OUT := "res://reports/screenshots/m14d_loot_%s.png"
const SHOTS: Array[String] = ["open", "take_all", "drag_ok", "drag_bad", "keychain"]
const ACT_AFTER := 0.8
const DRAG_AFTER := 1.1
const SHOOT_AFTER := 1.4
const WATCHDOG := 25.0

@export var player_path: NodePath

var shot: String = "open"

var _time: float = 0.0
var _acted: bool = false
var _dragged: bool = false
var _player: Player
var _guard: Node
var _screen: LootScreen


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	DisplayServer.window_set_size(Vector2i(1152, 648))
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("shot="):
			shot = arg.trim_prefix("shot=")
	if not SHOTS.has(shot):
		push_warning("loot_shots: unknown shot %s" % shot)
		get_tree().quit()
		return
	_player = get_node(player_path) as Player
	if not _player.is_node_ready():
		await _player.ready
	_player.reload_on_reset = false
	# The scene root is still adding its children: the guard joins it a frame later.
	await get_tree().process_frame
	_swap_keychain()
	_give()


func _process(delta: float) -> void:
	_time += delta
	if not _acted and _time >= ACT_AFTER:
		_acted = true
		_act()
	elif _acted and not _dragged and _time >= DRAG_AFTER:
		# After the screen's first layout: the grids' global positions are known.
		_dragged = true
		_drag()
	if _time >= SHOOT_AFTER or _time >= WATCHDOG:
		_save()


func _act() -> void:
	Screens.open(_player, Lootable.SCREEN, _guard)
	_screen = Screens.find(_player, Lootable.SCREEN) as LootScreen
	match shot:
		"take_all":
			_screen.take_all()
		"keychain":
			_screen.take_all()
			_screen.close()
			var tabs := TabInterface.of(_player)
			tabs.open(0)


func _drag() -> void:
	if not shot.begins_with("drag"):
		return
	var pistol := Helpers.inventory(_guard).grid.stacks_of(&"pistol")[0]
	_screen.begin_drag(_screen.their_grid, pistol, Vector2i.ZERO)
	var cell := Vector2i(2, 2) if shot == "drag_ok" else Vector2i(1, 0)
	_screen.move_drag(_screen.your_grid.global_cell_center(cell))


func _save() -> void:
	var image := get_viewport().get_texture().get_image()
	var path := OUT % shot
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
	image.save_png(ProjectSettings.globalize_path(path))
	set_process(false)
	get_tree().quit()


# The player's keychain becomes the contract's stand-in (kinds, remove()) for these shots.
func _swap_keychain() -> void:
	var old := Keychain.of(_player)
	_player.remove_child(old)
	old.free()
	var keys := Keychain.new()
	keys.name = "Keychain"
	_player.add_child(keys)
	(TabInterface.of(_player).page(0) as InventoryTab).keychain_list.bind(keys)


func _give() -> void:
	var inventory := _player.inventory
	inventory.add(load(RIFLE) as ItemData, 1, {"magazine": 21})
	inventory.add(Items.AMMO, 12)
	inventory.add(Items.LOCKPICK, 3)
	inventory.add(Items.BIOCELL, 1)
	Helpers.give_key(_player, "warehouse_office", "Warehouse office", Keychain.KEY)
	_guard = Helpers.downed(get_parent())
	var theirs := Helpers.inventory(_guard)
	theirs.add(Items.PISTOL, 1, {"magazine": 6})
	theirs.add(Items.AMMO, 24)
	theirs.add(Items.MEDKIT, 1)
	theirs.add(Items.BATON, 1)
	Helpers.give_key(_guard, "security_room", "Security room", Keychain.CARD)
	Helpers.give_key(_guard, "office_bay", "Office bay", Keychain.KEY)
