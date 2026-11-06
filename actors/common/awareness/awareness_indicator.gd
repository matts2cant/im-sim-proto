class_name AwarenessIndicator
extends Node3D
## Component: awareness feedback above a character's head (ADR 0022, ADR 0068), placed where the
## icon floats. Reads the sibling GradedAwareness:
## - Icon (billboard Label3D, drawn through walls): `?` yellow while Suspicious, `?` orange while
##   Searching, `!` red while Alerted; nothing while Unaware or when the character cannot act.
##   Shown while `show_icons` (on by default; debug panel Overlays tab).
## - Status (debug): state, meter and wary time, shown while `show_state` (Overlays tab).
## - Bark: on each state change a line from `barks` shows below the icon for `bark_time` seconds
##   with a generated placeholder beep, logged `actor.bark {actor, line, from, to}`. A reset
##   (knocked out) does not bark.
## The toggles are static: one switch for every character.

const SUSPICIOUS_COLOR := Color(1.0, 0.85, 0.1)
const SEARCHING_COLOR := Color(1.0, 0.55, 0.1)
const ALERTED_COLOR := Color(1.0, 0.15, 0.1)
## Beep pitch (Hz) per state entered.
const BEEP_HZ: Array[float] = [440.0, 660.0, 520.0, 990.0]

## Show the `?` / `!` icons.
static var show_icons: bool = true
## Show each character's state and meter as text.
static var show_state: bool = false

@export var barks: BarkLines
@export var bark_time: float = 2.0

var entity: Node3D
var awareness: GradedAwareness
var icon: Label3D
var status: Label3D
var bark: Label3D
var audio: AudioStreamPlayer3D
## Seconds the current bark stays up.
var bark_left: float = 0.0

var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	entity = get_parent() as Node3D
	awareness = GradedAwareness.of_node(entity)
	_rng.seed = hash(String(entity.name)) if entity != null else 0
	icon = _label("Icon", 96, Vector3.ZERO)
	status = _label("Status", 28, Vector3(0, 0.3, 0))
	bark = _label("Bark", 36, Vector3(0, -0.28, 0))
	bark.modulate = Color(0.95, 0.95, 0.95)
	audio = AudioStreamPlayer3D.new()
	audio.name = "Audio"
	add_child(audio)
	if awareness != null:
		awareness.state_changed.connect(_on_state_changed)
	refresh()


func _process(delta: float) -> void:
	advance(delta)


## Counts the bark down by `delta` seconds and refreshes the labels.
func advance(delta: float) -> void:
	if bark_left > 0.0:
		bark_left = maxf(bark_left - delta, 0.0)
	refresh()


## Updates the labels from the awareness state and the toggles.
func refresh() -> void:
	var text := icon_text()
	icon.text = text
	icon.modulate = icon_color()
	icon.visible = show_icons and not text.is_empty()
	status.visible = show_state and awareness != null
	if status.visible:
		status.text = status_text()
	bark.visible = bark_left > 0.0


## "?", "!" or "" for the current state.
func icon_text() -> String:
	if awareness == null or (entity != null and not ActorState.can_act(entity)):
		return ""
	match awareness.state():
		AwarenessModel.State.SUSPICIOUS, AwarenessModel.State.SEARCHING:
			return "?"
		AwarenessModel.State.ALERTED:
			return "!"
	return ""


func icon_color() -> Color:
	if awareness == null:
		return SUSPICIOUS_COLOR
	match awareness.state():
		AwarenessModel.State.SEARCHING:
			return SEARCHING_COLOR
		AwarenessModel.State.ALERTED:
			return ALERTED_COLOR
	return SUSPICIOUS_COLOR


## "suspicious 0.42", plus "wary 37s" while wary.
func status_text() -> String:
	var model := awareness.model
	var text := "%s %.2f" % [model.state_name(), model.meter]
	if model.is_wary():
		text += " wary %ds" % ceili(model.wary_time)
	return text


## Shows `line` for bark_time seconds with a beep for `to`.
func say(line: String, to: AwarenessModel.State) -> void:
	bark.text = line
	bark_left = bark_time
	bark.visible = true
	if audio.is_inside_tree():
		audio.stream = PlaceholderBeep.tone(BEEP_HZ[to])
		audio.play()


func _on_state_changed(from: AwarenessModel.State, to: AwarenessModel.State, reason: String) -> void:
	refresh()
	if reason == "reset" or barks == null:
		return
	var line := barks.pick(from, to, _rng)
	if line.is_empty():
		return
	var data := {
		"actor": String(entity.name),
		"line": line,
		"from": AwarenessModel.STATE_NAMES[from],
		"to": AwarenessModel.STATE_NAMES[to],
	}
	EventLog.record(&"actor.bark", String(entity.name), "", data)
	say(line, to)
	refresh()


func _label(label_name: String, font_size: int, offset: Vector3) -> Label3D:
	var label := Label3D.new()
	label.name = label_name
	label.font_size = font_size
	label.outline_size = maxi(int(font_size / 6.0), 4)
	label.outline_modulate = Color(0, 0, 0, 0.9)
	label.pixel_size = 0.004
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.fixed_size = false
	label.position = offset
	label.visible = false
	add_child(label)
	return label
