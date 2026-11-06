class_name CommsRules
extends RefCounted
## Pure rules of guard communication (ADR 0072): when a character shouts or radios, and how it
## answers the level alarm. No scene tree.


## Shouts on entering Alerted (and on finding a body: BodyDiscovery).
static func should_shout(from: AwarenessModel.State, to: AwarenessModel.State) -> bool:
	return to == AwarenessModel.State.ALERTED and from != AwarenessModel.State.ALERTED


## Radios on entering Alerted, with a radio.
static func should_radio(from: AwarenessModel.State, to: AwarenessModel.State, has_radio: bool) -> bool:
	return has_radio and should_shout(from, to)


## A shout of `loudness` perceived `path_distance` metres away along the navmesh is heeded when
## the margin (loudness - distance) is at least `min_margin` (the `heard_shout` receptron).
static func shout_heard(loudness: float, path_distance: float, min_margin: float) -> bool:
	return loudness - path_distance >= min_margin


## A radio call reaches a radio within `radio_range` metres in a straight line, walls or not.
static func radio_heard(straight_distance: float, radio_range: float) -> bool:
	return straight_distance <= radio_range


## While the level alarm is raised, a character in `state` starts a search (Unaware, Suspicious);
## Searching and Alerted ones carry on.
static func alarm_searches(state: AwarenessModel.State) -> bool:
	return state == AwarenessModel.State.UNAWARE or state == AwarenessModel.State.SUSPICIOUS
