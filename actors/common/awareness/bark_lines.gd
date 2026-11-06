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


## The list for a change from `from` to `to` (empty: no bark, e.g. a reset when knocked out).
func lines_for(from: AwarenessModel.State, to: AwarenessModel.State) -> Array[String]:
	match to:
		AwarenessModel.State.SUSPICIOUS:
			return suspicious
		AwarenessModel.State.ALERTED:
			return alerted
		AwarenessModel.State.SEARCHING:
			return searching
		AwarenessModel.State.UNAWARE:
			if from == AwarenessModel.State.SEARCHING:
				return gave_up
			if from == AwarenessModel.State.SUSPICIOUS:
				return calm
	return []


## A random line for the change, or "".
func pick(from: AwarenessModel.State, to: AwarenessModel.State, rng: RandomNumberGenerator) -> String:
	var lines := lines_for(from, to)
	if lines.is_empty():
		return ""
	return lines[rng.randi_range(0, lines.size() - 1)]
