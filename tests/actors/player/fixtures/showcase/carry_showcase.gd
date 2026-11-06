extends Node
## Showcase helper (screenshots only): puts the player at `feet` facing `yaw` (eye height 1.65 m,
## level view), makes it pick up `target` after `pick_up_after` seconds, then saves the window's
## image (HUD included) to `capture_path` after `capture_after` seconds and quits.

@export var player_path: NodePath
@export var target: NodePath
@export var feet: Vector3
@export var yaw_deg: float = 0.0
@export var pitch_deg: float = 0.0
@export var pick_up_after: float = 0.3
@export var capture_path: String = ""
@export var capture_after: float = 1.2

var _time: float = 0.0
var _picked: bool = false
var _player: Player


func _ready() -> void:
	DisplayServer.window_set_size(Vector2i(1152, 648))
	_player = get_node(player_path) as Player
	_player.load_state(
		{"position": feet, "yaw": deg_to_rad(yaw_deg), "pitch": deg_to_rad(pitch_deg), "velocity": Vector3.ZERO}
	)


func _physics_process(delta: float) -> void:
	_time += delta
	if _picked or _time < pick_up_after:
		return
	_picked = true
	_player.carry.pick_up(get_node(target) as RigidBody3D)


func _process(_delta: float) -> void:
	if capture_path.is_empty() or _time < capture_after:
		return
	var image := get_viewport().get_texture().get_image()
	image.save_png(ProjectSettings.globalize_path(capture_path))
	capture_path = ""
	get_tree().quit()
