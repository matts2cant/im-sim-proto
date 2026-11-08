extends Node
## Showcase helper (screenshots only): loads the hub as the current scene, saves to a test slot
## (never the player's save), then after `delay` seconds shows the game menu, its quit question or
## the death or knocked-out screen.

enum Mode { MENU, QUIT, DEAD, KNOCKED_OUT }

const HUB := "res://levels/hub/hub.tscn"
const SLOT := "user://test_saves/showcase.save"

@export var mode: Mode = Mode.MENU
@export var delay: float = 1.0

var _hub: Node
var _time: float = 0.0
var _done: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	QuickSave.path = SLOT
	_hub = (load(HUB) as PackedScene).instantiate()
	get_tree().root.add_child.call_deferred(_hub)


func _process(delta: float) -> void:
	_time += delta
	if _done or _time < delay:
		return
	_done = true
	get_tree().current_scene = _hub
	var player := _hub.get_node("Player") as Player
	var menu := player.get_node("GameMenu") as GameMenu
	QuickSave.save_game(get_tree())
	match mode:
		Mode.MENU:
			menu.open()
		Mode.QUIT:
			menu.open()
			menu.ask_quit()
		Mode.DEAD:
			player.body.take_damage(&"damage.blunt", 1000.0, &"head")
		Mode.KNOCKED_OUT:
			player.body.take_damage(&"damage.stun", 1000.0)
