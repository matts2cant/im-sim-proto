extends Node
## Showcase helper (screenshots only): puts the player at `feet` facing `yaw_deg` and looking down
## `pitch_deg` (eye height 1.65 m), downs `body` with `body_tag`, lets it fall, then holds
## move_forward; saves the window's image to `capture_path` once the player's feet pass
## `capture_z` (standing over the body: ADR 0082), or after `timeout` seconds, and quits.

@export var player_path: NodePath
@export var body: NodePath
@export var body_tag: StringName = &"state.dead"
@export var feet: Vector3
@export var yaw_deg: float = 0.0
@export var pitch_deg: float = 0.0
@export var walk_after: float = 1.0
@export var capture_z: float = 0.0
@export var timeout: float = 4.0
@export var capture_path: String = ""

var _time: float = 0.0
var _player: Player


func _ready() -> void:
	DisplayServer.window_set_size(Vector2i(1152, 648))
	_player = get_node(player_path) as Player
	_player.load_state(
		{"position": feet, "yaw": deg_to_rad(yaw_deg), "pitch": deg_to_rad(pitch_deg), "velocity": Vector3.ZERO}
	)
	ActorState.set_tag(get_node(body), body_tag, true)


func _physics_process(delta: float) -> void:
	_time += delta
	if _time >= walk_after and not Input.is_action_pressed(&"move_forward"):
		Input.action_press(&"move_forward")


func _process(_delta: float) -> void:
	if capture_path.is_empty():
		return
	if _time < timeout and (_time < walk_after or _player.global_position.z > capture_z):
		return
	var image := get_viewport().get_texture().get_image()
	image.save_png(ProjectSettings.globalize_path(capture_path))
	print("walk_over_body: player at ", _player.global_position, " after ", _time, " s")
	capture_path = ""
	Input.action_release(&"move_forward")
	get_tree().quit()
