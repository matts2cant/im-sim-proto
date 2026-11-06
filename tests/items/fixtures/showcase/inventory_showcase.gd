extends Node
## Showcase helper (screenshots only, runs while paused): gives the player a mixed loadout (every
## footprint), draws the pistol, then per `mode` opens the inventory (hovering an item for its
## tooltip), drags an item over a blocked spot, looks at a pickup for its prompt, reads the world
## datapad in place (`reading`, ADR 0060),
## or shows the belt HUD (`belt`: two wheel steps from the pistol, so the medkit is highlighted and
## its name shows above the belt). Saves the window's image (UI included) to `capture_path` after
## `capture_after` seconds and quits. Command line overrides after `--`: mode=<mode> out=<res path>.

const Items := preload("res://tests/items/item_test_helpers.gd")
const NOTE := (
	"Shift change moved to 22:00. The east loading door keypad is 0451 until maintenance resets it."
	+ "\n\nKeep the warehouse office locked; the spare keycard is in the foreman's desk."
)

@export var player_path: NodePath
@export var pickup_path: NodePath
## The world datapad `reading` reads (its Readable gets NOTE).
@export var datapad_path: NodePath = ^"../Datapad"
## inventory | drag | belt | prompt | reading
@export var mode: String = "inventory"
@export var capture_path: String = "res://reports/screenshots/m5_inventory.png"
@export var capture_after: float = 1.0

var _time: float = 0.0
var _acted: bool = false
var _player: Player


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("mode="):
			mode = arg.trim_prefix("mode=")
		elif arg.begins_with("out="):
			capture_path = arg.trim_prefix("out=")
	_player = get_node(player_path) as Player
	if not _player.is_node_ready():
		await _player.ready
	_player.reload_on_reset = false
	var inventory := _player.inventory
	inventory.give(Items.PISTOL, 1, {"magazine": 7})
	inventory.give(Items.BATON, 1)
	inventory.give(Items.AMMO, 64)
	inventory.give(Items.MEDKIT, 5)
	inventory.give(Items.MULTITOOL, 3)
	inventory.give(Items.LOCKPICK, 2)
	inventory.give(Items.BIOCELL, 4)
	inventory.give(Items.KEYCARD, 1, {"key_id": "warehouse_office"})
	inventory.select_slot(0)
	if mode == "prompt":
		var target := get_node(pickup_path) as Node3D
		_aim_at(target.global_position)


func _process(delta: float) -> void:
	_time += delta
	if not _acted and _time >= capture_after * 0.4:
		_acted = true
		_act()
	if capture_path.is_empty() or _time < capture_after:
		return
	var image := get_viewport().get_texture().get_image()
	image.save_png(ProjectSettings.globalize_path(capture_path))
	capture_path = ""
	get_tree().quit()


func _act() -> void:
	var screen := _player.get_node("InventoryScreen") as InventoryScreen
	match mode:
		"inventory":
			screen.open()
			_mouse(screen.view, screen.view.cell_center(Vector2i(4, 0)), false)
		"drag":
			screen.open()
			var view := screen.view
			_mouse(view, view.cell_center(Vector2i(2, 0)), true)
			_mouse(view, view.cell_center(Vector2i(4, 1)), false)
		"belt":
			_player.inventory.cycle(1)
			_player.inventory.cycle(1)
		"reading":
			var readable := Usable.of(get_node(datapad_path)) as Readable
			readable.entry_id = &"showcase.foreman_note"
			readable.title = "Foreman's note"
			readable.text = NOTE
			readable.use(_player)


static func _mouse(view: InventoryView, at: Vector2, press: bool) -> void:
	if press:
		var button := InputEventMouseButton.new()
		button.button_index = MOUSE_BUTTON_LEFT
		button.pressed = true
		button.position = at
		view._gui_input(button)
	var motion := InputEventMouseMotion.new()
	motion.position = at
	view._gui_input(motion)


func _aim_at(target: Vector3) -> void:
	var feet := _player.global_position
	var to := target - (feet + Vector3.UP * _player.eye_height())
	var state := {
		"position": feet,
		"yaw": atan2(-to.x, -to.z),
		"pitch": atan2(to.y, Vector2(to.x, to.z).length()),
		"crouched": false,
		"velocity": Vector3.ZERO,
	}
	_player.load_state(state)
