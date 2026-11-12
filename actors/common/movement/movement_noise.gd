class_name MovementNoise
extends Node3D
## Component of a CharacterBody3D (its parent; sits at the body's origin, the feet): the noise the
## character's movement makes. Every physics tick, after the body moved (parents process first), it
## reads the body's floor state and velocity and the stance tags (`stance.crouch`, `stance.sprint`,
## ActorState): on the ground every stride of horizontal travel is a footstep, a touchdown is a
## landing (LandingTracker). Each one is logged (`actor.footstep`, `actor.landed`), emitted as a
## `noise` stimulus from the feet (source: the body) and played on the `Audio` child (created when
## missing). The floor's surface comes from a short downward probe (ADR 0033). Tuning: `config`.
## Any character controller gets this by adding the node and setting its stance tags (ADR 0056).
## The body's attributes `footstep_noise_mult` and `landing_noise_mult` (base 1) scale the loudness
## (Run Silent x0, Speed Enhancement landings x1.5; ADR 0061); a noise scaled to 0 is not made at all
## (no log entry, stimulus or sound).

## Probe start above the feet and length below that, as the player's old floor ray.
const PROBE_UP: float = 0.1
const PROBE_LENGTH: float = 0.4
const FOOTSTEP_MULT: StringName = &"footstep_noise_mult"
const LANDING_MULT: StringName = &"landing_noise_mult"

@export var config: MovementNoiseConfig

var body: CharacterBody3D
## Surface of the floor last stood on.
var surface: StringName = &""
var last_footstep_loudness: float = 0.0
var last_landing_loudness: float = 0.0

var _footsteps := FootstepTracker.new()
var _landing := LandingTracker.new()
var _audio: AudioStreamPlayer3D


func _ready() -> void:
	body = get_parent() as CharacterBody3D
	if body == null:
		push_warning("MovementNoise %s: the parent is not a CharacterBody3D" % get_path())
		set_physics_process(false)
	surface = config.surfaces.default_surface
	_audio = get_node_or_null(^"Audio") as AudioStreamPlayer3D
	if _audio == null:
		_audio = AudioStreamPlayer3D.new()
		_audio.bus = GameSettings.EFFECTS_BUS
		_audio.name = "Audio"
		_audio.max_polyphony = 2
		add_child(_audio)


func _physics_process(delta: float) -> void:
	var grounded := body.is_on_floor()
	var impact := _landing.step(grounded, body.velocity.y)
	if not grounded:
		return
	_update_surface()
	if impact >= 0.0:
		_footsteps.reset()
		landed(impact)
		return
	var stance := current_stance()
	var travelled := Vector2(body.velocity.x, body.velocity.z).length() * delta
	if _footsteps.advance(travelled, MovementNoiseRules.stride(stance, config)):
		footstep(stance)


## Stance from the body's stance tags.
func current_stance() -> MovementNoiseRules.Stance:
	return MovementNoiseRules.stance_of(
		ActorState.has(body, ActorState.CROUCHING), ActorState.has(body, ActorState.SPRINTING)
	)


## Returns the footstep loudness; 0 (and no noise) when the body's attributes silence it.
func footstep(stance: MovementNoiseRules.Stance) -> float:
	var loudness := MovementNoiseRules.footstep_loudness(stance, surface, config)
	loudness *= Attributes.read(body, FOOTSTEP_MULT, 1.0)
	last_footstep_loudness = loudness
	if loudness <= 0.0:
		return 0.0
	var data := {"mode": MovementNoiseRules.stance_name(stance), "surface": surface, "loudness": loudness}
	_make_noise(&"actor.footstep", loudness, data)
	return loudness


## Returns the landing loudness; 0 (and no noise) for soft touchdowns or when the body's attributes
## silence it.
func landed(impact_speed: float) -> float:
	var loudness := MovementNoiseRules.landing_loudness(impact_speed, surface, config)
	loudness *= Attributes.read(body, LANDING_MULT, 1.0)
	if loudness <= 0.0:
		return 0.0
	last_landing_loudness = loudness
	_make_noise(&"actor.landed", loudness, {"impact_speed": impact_speed, "surface": surface, "loudness": loudness})
	return loudness


## Forgets stride progress and the landing history (teleports, loading a save).
func reset() -> void:
	_footsteps.reset()
	_landing.reset(body.is_on_floor() if body != null else true)


func _make_noise(kind: StringName, loudness: float, data: Dictionary) -> void:
	EventLog.record(kind, String(body.name), "", data)
	StimulusSystem.emit(Stimulus.make_noise(loudness, global_position, body))
	_play(loudness)


func _update_surface() -> void:
	var from := body.global_position + Vector3.UP * PROBE_UP
	var query := PhysicsRayQueryParameters3D.create(
		from, from + Vector3.DOWN * PROBE_LENGTH, config.surface_probe_mask, [body.get_rid()]
	)
	query.hit_back_faces = false
	var hit := body.get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		surface = config.surfaces.surface_of(hit["collider"] as Object)


func _play(loudness: float) -> void:
	var stream := config.surfaces.sound(surface)
	if stream == null or not _audio.is_inside_tree():
		return
	_audio.stream = stream
	_audio.pitch_scale = config.surfaces.pitch(surface)
	_audio.volume_db = MovementNoiseRules.volume_db(loudness, config)
	_audio.play()
