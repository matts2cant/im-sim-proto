class_name BarkLines
extends Resource
## Text barks spoken on awareness state changes (ADR 0022, ADR 0068). One list per transition; a
## line is picked at random. The guard's: `actors/guard/guard_barks.tres`.

## Unaware -> Suspicious.
@export var suspicious: Array[String] = []
## Any -> Alerted.
@export var alerted: Array[String] = []
## Alerted -> Searching.
@export var searching: Array[String] = []
## Suspicious -> Unaware (nothing found).
@export var calm: Array[String] = []
## Searching -> Unaware (the search is over).
@export var gave_up: Array[String] = []
## Searching because a downed ally was found (reason `body`, ADR 0071).
@export var body_found: Array[String] = []
## Searching because of an ally's shout or radio call, a dispatch or a siren (reasons `shout`, `radio`,
## `alarm`, ADR 0072).
@export var called: Array[String] = []
## Searching right after being woken (reason `woken`).
@export var woken: Array[String] = []


## The list for a change from `from` to `to` for `reason` (empty: no bark, e.g. a reset when
## knocked out).
func lines_for(from: AwarenessModel.State, to: AwarenessModel.State, reason: String = "") -> Array[String]:
	if to == AwarenessModel.State.SEARCHING:
		var by_reason := _reason_lines(reason)
		if not by_reason.is_empty():
			return by_reason
	match to:
		AwarenessModel.State.SUSPICIOUS:
			return suspicious
		AwarenessModel.State.ALERTED:
			return alerted
		AwarenessModel.State.SEARCHING:
			return searching
		AwarenessModel.State.UNAWARE:
			return _calm_lines(from)
	return []


# Back to Unaware from `from`: the search is over, or nothing was found ([] after a reset).
func _calm_lines(from: AwarenessModel.State) -> Array[String]:
	match from:
		AwarenessModel.State.SEARCHING:
			return gave_up
		AwarenessModel.State.SUSPICIOUS:
			return calm
	return []


# Searching for a reason other than a lost target: its own list ([] for others).
func _reason_lines(reason: String) -> Array[String]:
	match reason:
		"body":
			return body_found
		"shout", "radio", "alarm":
			return called
		"woken":
			return woken
	return []


## A random line for the change, or "".
func pick(
	from: AwarenessModel.State, to: AwarenessModel.State, rng: RandomNumberGenerator, reason: String = ""
) -> String:
	var lines := lines_for(from, to, reason)
	if lines.is_empty():
		return ""
	return lines[rng.randi_range(0, lines.size() - 1)]
