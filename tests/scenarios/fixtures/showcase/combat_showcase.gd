extends Node
## Showcase helper (screenshots only, tools/screenshot.sh): the player stands still (no input) where
## an armed guard sees it; once the guard has attacked, every frame freezes the attack's look for
## the picture: a ranged weapon's muzzle flash (MuzzleFlash.hold) or a melee weapon at
## `swing_progress` of its swing (WeaponHolder.preview_swing). The player cannot die meanwhile
## (its body is reset after each hit). An optional `camera_path` camera (at eye height, 1.65 m) shows
## both from the side instead of the player's view.

@export var player_path: NodePath
@export var guard_path: NodePath
@export var camera_path: NodePath
## The point the showcase camera looks at.
@export var camera_target: Vector3 = Vector3.ZERO
## Melee: the frozen point of the swing (0.25-0.35: the bottom of the chop).
@export var swing_progress: float = 0.3

var _player: Player
var _guard: NavWalker
var _holder: WeaponHolder


func _ready() -> void:
	_player = get_node(player_path) as Player
	_guard = get_node(guard_path) as NavWalker
	if not _player.is_node_ready():
		await _player.ready
	if not _guard.is_node_ready():
		await _guard.ready
	_player.input_enabled = false
	(_guard.get_node("Behaviour") as AwarenessBehaviour).route = null
	_holder = CombatBehaviour.of(_guard).holder
	BodyParts.of(_player).changed.connect(_keep_player_up)
	DisplayServer.window_set_size(Vector2i(1152, 648))
	if not camera_path.is_empty():
		var camera := get_node(camera_path) as Camera3D
		camera.look_at(camera_target, Vector3.UP)
		camera.make_current()


func _process(_delta: float) -> void:
	var data := _holder.weapon()
	if data == null:
		return
	if data.is_melee():
		if not EventLog.find(&"weapon.swung").is_empty():
			_holder.preview_swing(swing_progress)
	elif not EventLog.find(&"weapon.fired").is_empty():
		_holder.flash.hold(data)


func _keep_player_up() -> void:
	var parts := BodyParts.of(_player)
	if parts.is_dead() or parts.stun > 0.0:
		parts.reset.call_deferred()
