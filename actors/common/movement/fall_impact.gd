class_name FallImpact
extends Node
## Component of a CharacterBody3D (its parent): when the body touches down (LandingTracker, sampled
## after the body moved), emits `damage.fall` CONTACT on the body itself with intensity = the impact
## speed in m/s (downwards) and source = the body. What a fall does is up to the entity's
## receptrons: the `fall_damage` receptron (include_self) turns it into leg damage above 10 m/s;
## the generic `body_damage` receptron ignores it because the entity is its own source (ADR 0056).
## Landings slower than `config.min_speed` are not reported (FallImpactConfig, ADR 0138).

const DEFAULT_CONFIG: FallImpactConfig = preload("res://actors/common/movement/fall_impact.tres")

@export var config: FallImpactConfig = DEFAULT_CONFIG

var body: CharacterBody3D
var last_impact_speed: float = 0.0

var _landing := LandingTracker.new()


func _ready() -> void:
	body = Entities.of_component(self) as CharacterBody3D
	if config == null:
		config = DEFAULT_CONFIG
	if body == null:
		push_warning("FallImpact %s: the parent is not a CharacterBody3D" % get_path())
		set_physics_process(false)


func _physics_process(_delta: float) -> void:
	var impact := _landing.step(body.is_on_floor(), body.velocity.y)
	if impact >= config.min_speed:
		last_impact_speed = impact
		StimulusSystem.emit(Stimulus.make_contact(&"damage.fall", impact, body, body))


## Forgets the landing history (teleports, loading a save).
func reset() -> void:
	_landing.reset(body.is_on_floor() if body != null else true)
