extends Node
## Showcase helper (screenshots only): drives the player of the combat showcase scene, then saves the
## window's image (HUD included) to `capture_path` after `capture_after` seconds and quits.
## Modes: equip a weapon, sprint forward, shoot dummy parts in turn, or die.

const Items := preload("res://tests/items/item_test_helpers.gd")

@export var player_path: NodePath
@export var dummy_path: NodePath
## 0 = nothing, 1 = pistol, 2 = baton.
@export var equip: int = 1
## Holds sprint + forward from the start.
@export var sprint: bool = false
## Dummy body parts shot in turn, one every `shot_interval` seconds, starting at `first_shot`.
@export var shots: Array[StringName] = []
@export var first_shot: float = 0.3
@export var shot_interval: float = 0.4
## Seconds after which the player takes a deadly hit; < 0 = never.
@export var die_at: float = -1.0
@export var capture_path: String = ""
@export var capture_after: float = 1.0

var _time: float = 0.0
var _shot: int = 0
var _died: bool = false
var _player: Player
var _dummy: TrainingDummy


func _ready() -> void:
	_player = get_node(player_path) as Player
	_dummy = get_node_or_null(dummy_path) as TrainingDummy
	if not _player.is_node_ready():
		await _player.ready
	_player.reload_on_reset = false
	_player.weapons.seed_rng(7)
	Items.arm(_player)
	if equip > 0:
		_player.inventory.select_slot(equip - 1)
	if sprint:
		Input.action_press(&"move_forward")
		Input.action_press(&"sprint")


func _physics_process(delta: float) -> void:
	_time += delta
	if _dummy != null and _shot < shots.size() and _time >= first_shot + _shot * shot_interval:
		_aim_at(_dummy.hitboxes.box(shots[_shot]).global_position)
		_player.weapons.trigger()
		_shot += 1
	if die_at >= 0.0 and not _died and _time >= die_at:
		_died = true
		StimulusSystem.emit(Stimulus.make_contact(&"damage.explosive", 400.0, _player))


func _process(_delta: float) -> void:
	if capture_path.is_empty() or _time < capture_after:
		return
	Input.action_release(&"move_forward")
	Input.action_release(&"sprint")
	var image := get_viewport().get_texture().get_image()
	image.save_png(ProjectSettings.globalize_path(capture_path))
	capture_path = ""
	get_tree().quit()


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
