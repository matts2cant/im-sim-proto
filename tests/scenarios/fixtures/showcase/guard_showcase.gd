extends Node
## Showcase helper (screenshots only, tools/screenshot.sh): sets up the guard fixture with the
## player for one picture. The guard holds its post. Optionally cloaks the player (the guard does
## not see it), makes a noise at the player's feet after `noise_after` seconds (the guard turns to
## it, Suspicious) and switches the debug state text on.

@export var player_path: NodePath
@export var guard_path: NodePath
@export var cloak_player: bool = false
## Seconds until a noise (loudness 8) at the player's feet; < 0: none.
@export var noise_after: float = -1.0
@export var show_state: bool = false

var _time: float = 0.0
var _noise_made: bool = false
var _player: Player
var _guard: NavWalker


func _ready() -> void:
	_player = get_node(player_path) as Player
	_guard = get_node(guard_path) as NavWalker
	if not _player.is_node_ready():
		await _player.ready
	_player.input_enabled = false
	(_guard.get_node("Behaviour") as AwarenessBehaviour).route = null
	if cloak_player:
		ActorState.set_tag(_player, ActorState.CLOAKED, true)
	AwarenessIndicator.show_state = show_state


func _physics_process(delta: float) -> void:
	_time += delta
	if noise_after >= 0.0 and not _noise_made and _time >= noise_after:
		_noise_made = true
		StimulusSystem.emit(Stimulus.make_noise(8.0, _player.global_position, _player))
