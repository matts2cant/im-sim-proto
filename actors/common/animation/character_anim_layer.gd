class_name CharacterAnimLayer
extends RefCounted
## One layer of a CharacterAnimator's pose (ADR 0103), pure: the clip it plays (empty: it passes the
## pose below through), its time, rate and the parts it drives (empty: all), and a cross-fade from
## the clip it played before. Looping clips wrap, the others stop on their last frame and hold it.


class Slot:
	extends RefCounted
	## Empty: this slot shows the pose below.
	var clip: StringName = &""
	var time: float = 0.0
	var rate: float = 1.0
	var loops: bool = false
	var length: float = 0.0
	## Parts it drives; empty: every part.
	var parts: Array[StringName] = []

	func drives(part: StringName) -> bool:
		return not clip.is_empty() and (parts.is_empty() or parts.has(part))

	func advance(delta: float) -> void:
		if clip.is_empty():
			return
		time += delta * rate
		if length <= 0.0:
			time = 0.0
		elif loops:
			time = fposmod(time, length)
		else:
			time = minf(time, length)

	## Share of the clip played, 0..1 (1 for an empty slot).
	func progress() -> float:
		if clip.is_empty() or length <= 0.0:
			return 1.0
		return clampf(time / length, 0.0, 1.0)


var current := Slot.new()
var previous := Slot.new()
## Weight of `current` over `previous`: 0 at a change, 1 once the fade is over.
var blend: float = 1.0
var fade_time: float = 0.18


## Plays `clip` on `parts` (from `start_time`), fading from what played before over `fade` (< 0:
## the last fade time). The same clip on the same parts keeps playing (only its rate changes) unless
## `restart` (a second shot) starts it again at once.
func play(
	clip: StringName,
	parts: Array[StringName],
	length: float,
	loops: bool,
	rate: float = 1.0,
	fade: float = -1.0,
	start_time: float = 0.0,
	restart: bool = false,
) -> void:
	if clip == current.clip and parts == current.parts:
		current.rate = rate
		if restart:
			current.time = start_time
		return
	previous = current
	current = Slot.new()
	current.clip = clip
	current.parts = parts
	current.length = length
	current.loops = loops
	current.rate = rate
	current.time = start_time
	blend = 0.0
	if fade >= 0.0:
		fade_time = fade


## Shows `clip` at once, no fade, at `time` (its end for a held pose: a loaded save).
func snap(clip: StringName, parts: Array[StringName], length: float, loops: bool, time: float) -> void:
	previous = Slot.new()
	current = Slot.new()
	current.clip = clip
	current.parts = parts
	current.length = length
	current.loops = loops
	current.time = time
	blend = 1.0


func step(delta: float) -> void:
	current.advance(delta)
	if blend < 1.0:
		previous.advance(delta)
		blend = 1.0 if fade_time <= 0.0 else minf(blend + delta / fade_time, 1.0)
	if blend >= 1.0:
		previous = Slot.new()


## The layer shows nothing of its own (an empty clip, faded in).
func is_idle() -> bool:
	return current.clip.is_empty() and blend >= 1.0


## How much of `clip` the layer shows now (0..1), through the fade.
func weight_of(clip: StringName) -> float:
	var weight := 0.0
	if current.clip == clip:
		weight += blend
	if previous.clip == clip:
		weight += 1.0 - blend
	return weight
