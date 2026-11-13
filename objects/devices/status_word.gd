class_name StatusWord
extends Resource
## One status word (ADR 0137): what a component says about its state, the one vocabulary of the
## security screens (DeviceStatus: the deck's Map and device menus, the computer's Security app) and
## the interaction frame (TargetStatus). The shared words are `.tres` files in
## `objects/devices/status_words/`, preloaded as constants by whoever says them (DeviceStatus for the
## words several devices share, a component for its own, TargetStatus for the frame's); a word built
## at run time (a turret's "targets guards") is make().
## - `text`: as shown ("ringing", "Cut off").
## - `color` and `blink`: how a word shown on its own looks (the frame's status line: a square and the
##   word in that colour, blinking like a status LED).
## - `alert`: something is happening right now (ringing, firing, tracking...): a security screen shows
##   the device in its alert colour (DeviceStatus.tone()), never by reading the text.
## A component that puts its own word on the interaction frame joins FRAME_GROUP and answers
## `frame_word() -> StatusWord` (null: nothing to say; a mine's ProximityTrigger says "Armed").

const FRAME_GROUP: StringName = &"frame_status"

@export var text: String = ""
@export var color: Color = Color.WHITE
@export var blink: bool = false
@export var alert: bool = false


## A word built at run time.
static func make(
	p_text: String, p_alert: bool = false, p_color: Color = Color.WHITE, p_blink: bool = false
) -> StatusWord:
	var word := StatusWord.new()
	word.text = p_text
	word.alert = p_alert
	word.color = p_color
	word.blink = p_blink
	return word


## The words' texts, in order.
static func texts(words: Array[StatusWord]) -> PackedStringArray:
	var result := PackedStringArray()
	for word in words:
		if word != null:
			result.append(word.text)
	return result


## True when one of `words` is an alert word.
static func any_alert(words: Array[StatusWord]) -> bool:
	for word in words:
		if word != null and word.alert:
			return true
	return false
