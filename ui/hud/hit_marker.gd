class_name HitMarker
extends Control
## HUD hit markers on the crosshair (ADR 0126): when the watched shooter's own damage stimuli hurt a
## character (HitMarkerRules over the EventLog: not from weapon code), four short diagonal ticks
## around the aim point (white on a body hit, yellow and a little longer on a headshot, pale blue
## on a stun hit) or an X held longer (red on a kill, pale blue on a knockout), with a soft
## placeholder tick sound (the kill's stronger). No damage numbers. A stronger marker replaces a
## weaker one still showing; a weaker one waits. Fills the screen and draws at its centre plus
## `offset` (the HUD passes the reticle's aim offset). Tuning: HitMarkerConfig (`hit_marker.tres`).

const DEFAULT_CONFIG: HitMarkerConfig = preload("res://ui/hud/hit_marker.tres")
const SHADOW := Color(0, 0, 0, 0.55)
const REFERENCE_HEIGHT: float = 1080.0

@export var config: HitMarkerConfig

var rules := HitMarkerRules.new()
## The marker showing (NONE: none) and its seconds left.
var kind: HitMarkerRules.Kind = HitMarkerRules.Kind.NONE
var time_left: float = 0.0
## Offset of the aim point from the screen centre (pixels). A marker showing redraws when it changes,
## so it follows the crosshair under recoil and sway.
var offset: Vector2 = Vector2.ZERO:
	set(value):
		if value == offset:
			return
		offset = value
		if is_showing():
			queue_redraw()
## Keeps the marker showing (screenshots).
var held: bool = false
## Markers shown since the last clear (tests).
var shown: Array[HitMarkerRules.Kind] = []
## Sounds played since the last clear (tests).
var sounds: int = 0

var _audio: AudioStreamPlayer
var _since_sound: float = INF


func _ready() -> void:
	if config == null:
		config = DEFAULT_CONFIG
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_audio = AudioStreamPlayer.new()
	_audio.name = "Tick"
	_audio.bus = GameSettings.EFFECTS_BUS
	_audio.max_polyphony = 2
	add_child(_audio)
	EventLog.entry_added.connect(_on_entry)


func _exit_tree() -> void:
	if EventLog.entry_added.is_connected(_on_entry):
		EventLog.entry_added.disconnect(_on_entry)


func _process(delta: float) -> void:
	step(delta)


## Shows markers for the hits of `shooter` (the entity its stimuli name as their source).
func watch(shooter: Node) -> void:
	rules.watch(shooter)
	rules.clear()


## Shows the marker `marker_kind` unless a stronger one is still showing; plays its tick.
func show_marker(marker_kind: HitMarkerRules.Kind) -> void:
	if marker_kind == HitMarkerRules.Kind.NONE:
		return
	if time_left > 0.0 and int(marker_kind) < int(kind):
		return
	kind = marker_kind
	time_left = config.time_of(marker_kind)
	shown.append(marker_kind)
	_tick(marker_kind)
	queue_redraw()


## Counts the marker down by `delta` seconds (every frame; tests call it).
func step(delta: float) -> void:
	_since_sound += delta
	if held or time_left <= 0.0:
		return
	time_left = maxf(time_left - delta, 0.0)
	if time_left == 0.0:
		kind = HitMarkerRules.Kind.NONE
		queue_redraw()


func is_showing() -> bool:
	return time_left > 0.0 and kind != HitMarkerRules.Kind.NONE


## Hides the marker and forgets the history (tests).
func clear() -> void:
	kind = HitMarkerRules.Kind.NONE
	time_left = 0.0
	held = false
	shown.clear()
	sounds = 0
	_since_sound = INF
	rules.clear()
	queue_redraw()


## Ends of each tick or cross arm from the aim point (pixels): four diagonals.
func segments() -> Array[PackedVector2Array]:
	var result: Array[PackedVector2Array] = []
	if not is_showing():
		return result
	var cross := HitMarkerConfig.is_cross(kind)
	var scale_factor := maxf(size.y, 1.0) / REFERENCE_HEIGHT
	var inner := (config.cross_inner if cross else config.tick_inner) * scale_factor
	var outer := (config.cross_outer if cross else config.tick_outer) * scale_factor
	var aim := size * 0.5 + offset
	for diagonal: Vector2 in [Vector2(1, 1), Vector2(1, -1), Vector2(-1, 1), Vector2(-1, -1)]:
		var along := diagonal.normalized()
		result.append(PackedVector2Array([aim + along * inner, aim + along * outer]))
	return result


func _on_entry(entry: EventLogEntry) -> void:
	show_marker(rules.observe(entry))


func _tick(marker_kind: HitMarkerRules.Kind) -> void:
	if _since_sound < config.sound_gap and not HitMarkerConfig.is_cross(marker_kind):
		return
	_since_sound = 0.0
	sounds += 1
	if HitMarkerConfig.is_cross(marker_kind):
		_audio.stream = PlaceholderBeep.tone(config.kill_hz, config.kill_length)
		_audio.volume_db = config.kill_db
	else:
		_audio.stream = PlaceholderBeep.tone(config.tick_hz, config.tick_length)
		_audio.volume_db = config.tick_db
	if is_inside_tree():
		_audio.play()


func _draw() -> void:
	var lines := segments()
	if lines.is_empty():
		return
	var cross := HitMarkerConfig.is_cross(kind)
	var width := config.cross_width if cross else config.tick_width
	var color := config.color_of(kind)
	for line in lines:
		var along := (line[1] - line[0]).normalized()
		draw_line(line[0] - along, line[1] + along, SHADOW, width + 2.0)
	for line in lines:
		draw_line(line[0], line[1], color, width)
