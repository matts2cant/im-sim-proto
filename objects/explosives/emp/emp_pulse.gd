class_name EmpPulse
extends Node
## Component of a payload (a child of an ExplosivePayload, ADR 0131): when the payload is released
## it sends an electromagnetic pulse from the blast centre: an `emp` stimulus (RADIUS
## `config.radius`, STRAIGHT: walls do not stop it; uniform) whose intensity is `config.seconds`.
## Whatever is electronic inside (an EMP-reactive component: EmpEffect) loses power for that long
## and comes back by itself; characters lose half their energy; nothing is damaged. The pulse is a
## child of the stimulus that set the explosive off (chains trace back).

@export var config: EmpConfig

var payload: ExplosivePayload


func _ready() -> void:
	payload = get_parent() as ExplosivePayload
	if payload == null or config == null:
		push_warning("EmpPulse %s: needs an ExplosivePayload parent and a config" % get_path())
		return
	payload.released.connect(_on_released)


## The `emp` stimulus of `p_config` at `origin` from `source` (may be null).
static func make(p_config: EmpConfig, origin: Vector3, source: Node = null) -> Stimulus:
	var stimulus := Stimulus.make_radius(EmpEffect.TYPE, p_config.seconds, origin, p_config.radius, source)
	stimulus.uniform = true
	return stimulus


func _on_released(origin: Vector3, cause: Stimulus) -> void:
	StimulusSystem.emit(EmpPulse.make(config, origin, payload.entity), cause)
