class_name PerceptionConfig
extends Resource
## Tuning of PerceptionSensor and of who a character perceives as what (ADR 0067, ADR 0069). The
## guard's: `actors/guard/guard_perception.tres`. Angles are horizontal, measured from the facing;
## distances are horizontal, from the eyes to the target's centre.

@export_group("Allegiance")
## Entities with any of these tags are watched for and alert on sight; damage from them alerts.
@export var hostile_tags: Array[StringName] = [&"actor.player"]
## Entities with any of these tags are ignored: their noise is not investigated.
@export var ally_tags: Array[StringName] = [&"actor.guard"]
## Entities with any of these tags are never seen (Cloak).
@export var hidden_tags: Array[StringName] = [&"state.cloaked"]
## An ally with any of these tags is a body to discover (ADR 0071).
@export var body_tags: Array[StringName] = [&"state.unconscious", &"state.dead"]

@export_group("Eyes")
## Eye height above the feet (the body's origin), m.
@export var eye_height: float = 1.6
## What blocks the view: world (layer 1) and physics props (layer 4).
@export_flags_3d_physics var view_mask: int = 9

@export_group("Cones")
@export var focus_half_angle: float = 30.0
@export var focus_range: float = 20.0
@export var peripheral_half_angle: float = 60.0
@export var peripheral_range: float = 10.0
## Gain multiplier in the peripheral zone (outside the focus cone).
@export var peripheral_factor: float = 0.4

@export_group("Gain")
## Suspicion gained per second by a fully lit, standing target within `distance_full` in focus.
@export var base_gain: float = 1.25
## Light factor = clamp((L - light_min) / (light_full - light_min), 0, 1), L the target's light level.
@export var light_min: float = 0.1
@export var light_full: float = 0.5
## Within this horizontal distance (centre to centre) the light factor is at least `close_light`.
@export var close_distance: float = 2.0
@export var close_light: float = 0.5
## A target moving faster than `moving_speed` (horizontal, m/s, from its body's velocity) keeps a
## light factor of at least `moving_light`, however dark it is (ADR 0095): movement gives a target
## away in the dark, standing still does not. 0 turns the floor off (cameras, turrets).
@export var moving_light: float = 0.0
@export var moving_speed: float = 0.5
## Distance factor: 1 up to `distance_full`, linear down to `distance_far_factor` at `distance_far`.
@export var distance_full: float = 5.0
@export var distance_far: float = 20.0
@export var distance_far_factor: float = 0.25
## Gain multiplier while the target has `crouch_tag`.
@export var crouch_factor: float = 0.7
@export var crouch_tag: StringName = &"stance.crouch"
## Gain multiplier while the watcher is wary (after an alert or a search).
@export var wary_factor: float = 1.5
