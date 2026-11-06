class_name CircuitBreaker
extends Usable
## Component: a breaker that switches power circuit `circuit` (ADR 0066). Using it (E) opens or
## closes it: every Powered on the circuit turns off or on (Powered.set_circuit(), found through
## the circuit's group: the breaker knows no lamps), the lever moves, it clunks (a `noise` stimulus
## from the entity, and the `sound_path` player) and the change is logged (`power.switched`).
## Saveable (`closed`).

const LOG_KIND: StringName = &"power.switched"
## Lever angle (degrees about its X axis, from pointing up) when closed (up, tilted out) and open (down).
const LEVER_CLOSED_DEG: float = 35.0
const LEVER_OPEN_DEG: float = 145.0

@export var circuit: StringName = &""
## Closed = power flows. A breaker placed open cuts its circuit when the level starts.
@export var closed: bool = true
## What the prompt calls it ("E: switch off <label>").
@export var label: String = "lights"
## Loudness of the clunk (audible metres, noise stimulus).
@export var noise_loudness: float = 6.0
@export var lever_path: NodePath = ^""
## AudioStreamPlayer3D played on every throw (optional).
@export var sound_path: NodePath = ^""
@export var entity_path: NodePath = ^".."

var entity: Node3D


func _ready() -> void:
	add_to_group(&"saveable")
	entity = get_node_or_null(entity_path) as Node3D
	_update_visuals()
	if not closed:
		# Lamps later in the tree are not ready yet.
		_apply.call_deferred()


func target_name() -> String:
	return label


## Toggles the breaker: the circuit switches, the lever moves, a clunk is heard.
func use(user: Node) -> bool:
	set_closed(not closed, user)
	used.emit(user)
	return true


## Opens (false) or closes (true) the breaker; `user` is logged as the cause.
func set_closed(value: bool, user: Node = null) -> void:
	closed = value
	_update_visuals()
	var count := _apply()
	var origin := entity.global_position if entity != null and entity.is_inside_tree() else Vector3.ZERO
	StimulusSystem.emit(Stimulus.make_noise(noise_loudness, origin, entity))
	var sound := get_node_or_null(sound_path) as AudioStreamPlayer3D
	if sound != null and sound.is_inside_tree():
		sound.play()
	var by := String(user.name) if user != null else ""
	var data := {"circuit": circuit, "on": closed, "powered": count}
	EventLog.record(LOG_KIND, by, String(entity.name) if entity != null else "", data)


func _apply() -> int:
	if not is_inside_tree() or circuit.is_empty():
		return 0
	return Powered.set_circuit(get_tree(), circuit, closed)


func _update_visuals() -> void:
	verb = "switch off" if closed else "switch on"
	var lever := get_node_or_null(lever_path) as Node3D
	if lever != null:
		lever.rotation_degrees.x = LEVER_CLOSED_DEG if closed else LEVER_OPEN_DEG


func save_state() -> Dictionary:
	return {"closed": closed}


## Restores the breaker and puts its circuit in the matching state (no noise, nothing logged).
func load_state(data: Dictionary) -> void:
	closed = bool(data.get("closed", closed))
	_update_visuals()
	_apply()
