class_name ProximityTriggerConfig
extends Resource
## Tuning of a ProximityTrigger (ADR 0131, ADR 0138): `items/grenades/proximity_trigger.tres`.

## Seconds from sticking (or arm()) to armed.
@export var arm_time: float = 2.0
## Gap (m) from its centre to a character's collision shape that sets it off...
@export var radius: float = 2.5
## ...or, for a crouched character (its `stance.crouch` tag), this one.
@export var crouched_radius: float = 1.0
## Physics ticks between two looks for characters.
@export var check_ticks: int = 4
## What it looks for: bodies on these layers (players and guards).
@export_flags_3d_physics var character_mask: int = PhysicsLayers.CHARACTER_LAYERS
## What blocks its line of sight to a character.
@export_flags_3d_physics var sight_mask: int = PhysicsLayers.WORLD | PhysicsLayers.OBJECTS
## When not empty, only characters with one of these tags set it off (empty: every character).
@export var required_tags: Array[StringName] = []
## Characters with one of these tags never set it off.
@export var ignored_tags: Array[StringName] = []

@export_group("Light")
## Blink period (s) of the armed light and the lit share of it.
@export var blink_period: float = 1.0
@export_range(0.0, 1.0) var blink_lit_share: float = 0.3


## True when a character with `tags` (null: no Tags) may set it off.
func accepts(tags: TagContainer) -> bool:
	if not required_tags.is_empty() and (tags == null or not tags.has_any(required_tags)):
		return false
	return tags == null or not tags.has_any(ignored_tags)
