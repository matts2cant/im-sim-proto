class_name HeatModel
extends RefCounted
## Heat accumulation (ADR 0046): received fire adds its perceived intensity, heat cools
## continuously at `cool_rate` per second, and the threshold is reached when heat >= threshold.
## Pure logic, shared by Flammable (ignition) and Explosive (detonation).

var heat: float = 0.0
var threshold: float
## Heat lost per second.
var cool_rate: float


func _init(p_threshold: float, p_cool_rate: float) -> void:
	threshold = p_threshold
	cool_rate = p_cool_rate


## Adds `amount` (negative amounts are ignored); returns true when the threshold is reached.
func add(amount: float) -> bool:
	heat += maxf(amount, 0.0)
	return reached()


func cool(delta: float) -> void:
	heat = maxf(heat - cool_rate * delta, 0.0)


func reached() -> bool:
	return threshold > 0.0 and heat >= threshold


## Seconds from the first pulse until the pulse that reaches `threshold`, when pulses of
## `perceived` heat arrive every `interval` seconds and heat cools in between; -1 when it never does.
static func seconds_to_reach(perceived: float, threshold: float, cool_rate: float, interval: float) -> float:
	var model := HeatModel.new(threshold, cool_rate)
	for pulse in 10000:
		if model.add(perceived):
			return pulse * interval
		# Cooling eats a whole pulse or more: heat never builds past one pulse.
		if perceived <= cool_rate * interval:
			return -1.0
		model.cool(interval)
	return -1.0
