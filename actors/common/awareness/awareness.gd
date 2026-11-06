class_name Awareness
extends Node
## Component: whether the character has noticed a threat, and the inputs that make it notice.
## The knockout rule (ADR 0049) asks is_aware(). This base is the exported flag (training dummies:
## false, so a baton hit from behind knocks them out) and ignores the inputs; GradedAwareness
## (ADR 0068) implements them with the graded states. The inputs arrive through stimuli
## (AwarenessEffect on the character's receptrons) or from other systems: alert_at() is the hook
## for alarms, radio and shouts.

@export var aware: bool = false


static func of(node: Node) -> Awareness:
	if node == null:
		return null
	for child in node.get_children():
		if child is Awareness:
			return child as Awareness
	return null


func is_aware() -> bool:
	return aware


## A noise from `source` (may be null or freed) was heard at `at` with `perceived` metres of margin.
func notice_noise(_at: Vector3, _perceived: float, _source: Node) -> void:
	pass


## The character was hurt by `source` (may be null or freed); `at` is where the harm came from.
func notice_harm(_source: Node, _at: Vector3) -> void:
	pass


## An external alert about a threat at `at` (alarm, radio, a shout).
func alert_at(_at: Vector3) -> void:
	pass
