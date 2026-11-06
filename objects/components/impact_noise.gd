class_name ImpactNoise
extends Node
## Component of a RigidBody3D: turns hard collisions into `noise` and `damage.blunt`.
## Enables the body's contact monitor and reads its contacts every physics tick. A contact that is
## new this tick counts as an impact at the speed the body approached it along the contact normal
## (its velocity before the step, relative to the other body). Impacts of at least
## `settings.min_speed`, at most one per `settings.throttle` seconds and never while carried:
## `object.impact` log entry, `noise` (PATH) of ImpactRules.loudness(), material impact sound,
## `damage.blunt` CONTACT = kinetic energy / divisor to the body itself and to what it hit. Glass
## (material.break_impact_speed) breaks outright on a fast enough impact.

@export var material: MaterialProfile
@export var settings: ImpactSettings

var body: RigidBody3D
var last_speed: float = 0.0
var last_loudness: float = 0.0

var _previous_velocity: Vector3 = Vector3.ZERO
var _contacts: Dictionary[int, bool] = {}
var _cooldown: float = 0.0
var _audio: AudioStreamPlayer3D


func _ready() -> void:
	body = get_parent() as RigidBody3D
	body.contact_monitor = true
	body.max_contacts_reported = maxi(body.max_contacts_reported, 8)
	_audio = AudioStreamPlayer3D.new()
	_audio.name = "ImpactAudio"
	_audio.max_polyphony = 2
	_audio.unit_size = 4.0
	body.add_child.call_deferred(_audio)


func _physics_process(delta: float) -> void:
	_cooldown -= delta
	var state := PhysicsServer3D.body_get_direct_state(body.get_rid())
	if state == null:
		return
	var current: Dictionary[int, bool] = {}
	var best_speed := 0.0
	var best_other: Object = null
	for i in state.get_contact_count():
		var id := state.get_contact_collider_id(i)
		var is_new := not _contacts.has(id) and not current.has(id)
		current[id] = true
		if not is_new:
			continue
		var relative := _previous_velocity - state.get_contact_collider_velocity_at_position(i)
		var speed := -relative.dot(state.get_contact_local_normal(i))
		if speed > best_speed:
			best_speed = speed
			best_other = state.get_contact_collider_object(i)
	_contacts = current
	if best_speed >= settings.min_speed and _cooldown <= 0.0 and not _is_carried():
		impact(best_speed, best_other as Node)
	_previous_velocity = body.linear_velocity


## Reports an impact at `speed` m/s against `other` (may be null). Returns the loudness.
func impact(speed: float, other: Node) -> float:
	_cooldown = settings.throttle
	var loudness := ImpactRules.loudness(speed, body.mass, material.impact_loudness, settings)
	last_speed = speed
	last_loudness = loudness
	var other_name := String(other.name) if is_instance_valid(other) else ""
	var data := {"object": String(body.name), "other": other_name, "speed": speed, "loudness": loudness}
	EventLog.record(&"object.impact", String(body.name), other_name, data)
	StimulusSystem.emit(Stimulus.make_noise(loudness, body.global_position, body))
	_play(loudness)
	var damage := ImpactRules.damage(speed, body.mass, settings)
	if damage > 0.0:
		StimulusSystem.emit(Stimulus.make_contact(&"damage.blunt", damage, body, other))
		if is_instance_valid(other):
			StimulusSystem.emit(Stimulus.make_contact(&"damage.blunt", damage, other, body))
	if material.break_impact_speed > 0.0 and speed >= material.break_impact_speed:
		var breakable := Breakable.of(body)
		if breakable != null:
			breakable.break_apart(&"impact")
	return loudness


func _is_carried() -> bool:
	var carryable := Carryable.of(body)
	return carryable != null and carryable.is_carried()


func _play(loudness: float) -> void:
	var stream := material.impact_sound(ImpactRules.tier(loudness, settings))
	if stream == null or not _audio.is_inside_tree():
		return
	_audio.stream = stream
	_audio.volume_db = ImpactRules.volume_db(loudness, settings)
	_audio.play()
