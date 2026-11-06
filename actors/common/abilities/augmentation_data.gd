class_name AugmentationData
extends Resource
## One augmentation (`augmentations/<id>.tres`): what it does while on, as data. While on it applies
## `modifiers` (copies, source `aug.<id>`) and `tags` to its entity and sends `pulse_stimuli` to the
## entity every `pulse_interval` seconds when they would do something (StimulusSystem.would_affect()).
## A toggle drains `drain_per_second` energy while on; a passive one is on whenever installed and
## costs nothing (ADR 0061).

@export var id: StringName = &""
@export var display_name: String = ""
@export_multiline var description: String = ""
## Toggle key: action `aug_<slot>` (1 = F1 ... 4 = F4, 5 = F6: F5 is quicksave). 0: no key (passive).
@export var slot: int = 0
@export var passive: bool = false
@export var drain_per_second: float = 0.0
@export var modifiers: Array[Modifier] = []
@export var tags: Array[StringName] = []

@export_group("Pulse")
## CONTACT stimuli sent to the entity itself (source: the entity) while on, type -> intensity
## (Regeneration: `heal` 2).
@export var pulse_stimuli: Dictionary[StringName, float] = {}
@export var pulse_interval: float = 0.5


## Modifier source of this augmentation's modifiers (`aug.cloak`).
func source() -> StringName:
	return StringName("aug.%s" % id)


## Fresh copies of `modifiers` with this augmentation as their source.
func make_modifiers() -> Array[Modifier]:
	var result: Array[Modifier] = []
	for modifier in modifiers:
		if modifier != null:
			result.append(
				Modifier.create(modifier.attribute, modifier.op, modifier.magnitude, source(), modifier.priority)
			)
	return result


## Name of the key bound to `aug_<slot>` ("F1" for slot 1, "F6" for slot 5), "" without a key;
## "F<slot>" when the action has no key event.
func key_label() -> String:
	if slot <= 0:
		return ""
	var action := StringName("aug_%d" % slot)
	if InputMap.has_action(action):
		for event in InputMap.action_get_events(action):
			var key := event as InputEventKey
			if key == null:
				continue
			var code := key.physical_keycode if key.physical_keycode != KEY_NONE else key.keycode
			if code != KEY_NONE:
				return OS.get_keycode_string(code)
	return "F%d" % slot
