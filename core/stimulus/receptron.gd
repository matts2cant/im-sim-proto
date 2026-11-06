class_name Receptron
extends Resource
## One reaction of a StimulusReceiver: when a stimulus of `stimulus_type` arrives inside the
## intensity window and the entity's tags allow it, `effects` run in order.

## Matches exactly or by hierarchy: `damage` matches `damage.fire`. Empty matches nothing.
@export var stimulus_type: StringName = &""
## Inclusive bounds on the perceived intensity.
@export var min_intensity: float = 0.0
## <= 0: no upper bound.
@export var max_intensity: float = 0.0
## The entity must have all of these (hierarchical match).
@export var required_tags: Array[StringName] = []
## The entity must have none of these (hierarchical match).
@export var blocked_tags: Array[StringName] = []
## When true, also reacts to stimuli its own entity emitted.
@export var include_self: bool = false
@export var effects: Array[Effect] = []


func matches_type(type: StringName) -> bool:
	return TagContainer.matches(type, stimulus_type)


func matches_intensity(perceived: float) -> bool:
	if perceived < min_intensity:
		return false
	return max_intensity <= 0.0 or perceived <= max_intensity


## `tags` may be null for entities without a Tags component (treated as no tags).
func matches_tags(tags: TagContainer) -> bool:
	if tags == null:
		return required_tags.is_empty()
	return tags.has_all(required_tags) and not tags.has_any(blocked_tags)


func matches(type: StringName, perceived: float, tags: TagContainer) -> bool:
	return matches_type(type) and matches_intensity(perceived) and matches_tags(tags)


## Class names of the effects, for EventLog entries.
func effect_names() -> Array[String]:
	var names: Array[String] = []
	for effect in effects:
		names.append(effect.effect_name() if effect != null else "<null>")
	return names
