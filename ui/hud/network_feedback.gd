class_name NetworkFeedback
extends Node
## HUD feedback after an action (M12c readability, ADR 0115, ADR 0122): when a device goes down and
## takes others off the network (NetworkDrops.offline_after(): a switch, router or access point
## broken or unpowered), the HUD's message line says so for SHOW_TIME s ("SW-VAULT down: 5 devices
## offline (CAM-OFFICE, DOOR-VAULT, +3)"). Only for drops within RANGE m of the player or caused by
## the player: the player broke it (MissionTally's attribution: a shot, a blast the player set off)
## or switched a breaker off in the same tick (a `power.switched` whose source entity is a player,
## by tag). Drops within SETTLE_FRAMES of the HUD starting (the level's own starting state) are
## ignored. Several drops in one tick: the line with the most devices.
## Reads EventLog entries as they are recorded (`device.state`, `power.switched`, and what
## MissionTally observes), with their entities (ADR 0136: never by name).

const RANGE: float = 30.0
const SHOW_TIME: float = 4.0
const SETTLE_FRAMES: int = 10

var hud: Hud
## The last line shown ("" before any).
var last_line: String = ""

var _tally: MissionTally
## Instance ids of the devices that went down this tick -> the tick.
var _pending: Dictionary[int, int] = {}
var _player_switch_tick: int = -1
var _started_frame: int = 0


func _ready() -> void:
	hud = get_parent() as Hud
	_started_frame = Engine.get_physics_frames()
	_tally = MissionTally.new()
	EventLog.entry_added.connect(_on_entry)


func _player() -> Node3D:
	return hud.player if hud != null and is_instance_valid(hud.player) else null


func _on_entry(entry: EventLogEntry) -> void:
	if _player() == null:
		return
	_tally.observe(entry)
	match entry.kind:
		EventKinds.POWER_SWITCHED:
			if _tally.is_player(entry.source_entity()) and not bool(entry.data.get("on", true)):
				_player_switch_tick = entry.tick
		EventKinds.DEVICE_STATE:
			if bool(entry.data.get("up", true)):
				return
			if Engine.get_physics_frames() - _started_frame < SETTLE_FRAMES:
				return
			var device := Device.of(entry.source_entity())
			if device == null:
				return
			if _pending.is_empty():
				_flush.call_deferred()
			_pending[device.get_instance_id()] = entry.tick


# After the tick's entries (a breaker logs its switch after the drops it caused).
func _flush() -> void:
	var player := _player()
	var best := ""
	var best_count := 0
	for device_id: int in _pending:
		var device := instance_from_id(device_id) as Device
		if player == null or device == null or device.is_up() or not is_instance_valid(device.entity):
			continue
		var caused := _tally.has_broken(device.entity) or _player_switch_tick == _pending[device_id]
		var near := player.global_position.distance_to(device.entity.global_position) <= RANGE
		if not caused and not near:
			continue
		var offline := NetworkDrops.offline_after(device)
		if offline.size() > best_count:
			best_count = offline.size()
			var names: Array[String] = []
			for other in offline:
				names.append(NetworkSource.display_name(other))
			best = NetworkDrops.line(NetworkSource.display_name(device), names)
	_pending.clear()
	if best.is_empty():
		return
	last_line = best
	hud.show_message(best, SHOW_TIME)
