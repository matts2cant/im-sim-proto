class_name DeckTraceBars
extends RefCounted
## The trace bars (ADR 0113, 0114's slot): one bar per tracer watching the user, in the deck's
## header (WindowFrame.trace_slot) and in the computer overlay's header. Bars update in place while
## the tracers stay the same (show_bars()), so the controls around a still cursor stay put.

## A remote desktop's header is narrower: its bars go without a name (the deck's own bar above shows
## the named ones).
const COMPACT_BAR_WIDTH: float = 48.0
const BAR_WIDTH: float = 120.0
const BAR_HEIGHT: float = 8.0
## Above this trace (%) a bar turns red.
const HOT: float = 70.0
const UNKNOWN: String = "unknown tracer"


## One trace bar: `label`, a `width` px bar of `value` % (red above HOT %), "N %" and "blocked N s"
## while `lockout_left` > 0.
static func trace_bar(label: String, value: float, lockout_left: float, width: float = BAR_WIDTH) -> HBoxContainer:
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override(&"separation", WindowFrame.metric(&"space_s"))
	if not label.is_empty():
		bar.add_child(DeckStyle.mono(label, DeckStyle.DIM_COLOR, 12))
	var color := DeckStyle.ERROR_COLOR if value > HOT else DeckStyle.ALERT_COLOR
	var track := DeckStyle.track(width, BAR_HEIGHT, value / 100.0, color)
	track.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bar.add_child(track)
	var text := "%d %%" % roundi(value)
	if lockout_left > 0.0:
		text += " · blocked %d s" % ceili(lockout_left)
	bar.add_child(DeckStyle.mono(text, DeckStyle.DIM_COLOR, 12))
	return bar


## Shows the new trace `bars` in `box`: the bars already there take their texts, fills and tooltips
## in place when they match one for one (one bar per tracer, the same parts), else `box` is refilled.
## A trace that rises adds and frees nothing, so the controls around a still cursor stay put.
static func show_bars(box: Node, bars: Array[HBoxContainer]) -> void:
	var olds: Array[Node] = []
	for child in box.get_children():
		if not child.is_queued_for_deletion():
			olds.append(child)
	var same := olds.size() == bars.size()
	if same:
		for i in olds.size():
			same = same and olds[i].get_child_count() == bars[i].get_child_count()
	if not same:
		for child in olds:
			DeckStyle.discard(child)
		for bar in bars:
			box.add_child(bar)
		return
	for i in olds.size():
		var old := olds[i] as Control
		old.tooltip_text = bars[i].tooltip_text
		for j in old.get_child_count():
			var part := old.get_child(j)
			var fresh := bars[i].get_child(j)
			if part is Label and fresh is Label:
				(part as Label).text = (fresh as Label).text
			elif part.get_child_count() > 0 and fresh.get_child_count() > 0:
				var fill := part.get_child(0) as ColorRect
				var fresh_fill := fresh.get_child(0) as ColorRect
				if fill != null and fresh_fill != null:
					fill.color = fresh_fill.color
					fill.size = fresh_fill.size
		bars[i].free()


## The deck header's bars: the tracers watching `session`'s user at its address (on the Wi-Fi key
## screen, `wifi`: those watching the access point `wireless` aims at), named by `namer`
## (Callable(Tracer) -> String).
static func deck_bars(
	session: DeckSession, wireless: WirelessTool, wifi: bool, namer: Callable
) -> Array[HBoxContainer]:
	var bars: Array[HBoxContainer] = []
	var plugged := session.source.address if session.is_plugged() else ""
	var address := WifiPanel.aim_address(wireless) if wifi else plugged
	for tracer in WifiPanel.tracers(wireless) if wifi else session.tracers():
		var left := tracer.model.lockout_left(address)
		bars.append(trace_bar(namer.call(tracer) as String, tracer.trace_of(session.entity), left))
	return bars


## The computer overlay's bars for `viewer`: remote, the deck's tracers (`session`); bare-handed,
## those watching that computer for its address.
static func computer_bars(screen: ComputerScreen, session: DeckSession, viewer: Node) -> Array[HBoxContainer]:
	var bars: Array[HBoxContainer] = []
	var computer := screen.computer
	var address := computer.address()
	var tracers: Array[Tracer] = []
	if screen.is_remote() and session != null and session.is_plugged():
		address = session.source.address
		tracers = session.tracers()
	elif computer.device != null:
		var seen: Array[Device] = [computer.device]
		tracers = Tracer.bars_for(viewer.get_tree(), viewer, seen, address)
	for tracer in tracers:
		var known := tracer.device == computer.device or (session != null and session.map_devices().has(tracer.device))
		var label := tracer.label if known else UNKNOWN
		var left := tracer.model.lockout_left(address)
		var bar: HBoxContainer
		if screen.is_remote():
			# Compact: the deck's own bar right above names it.
			bar = trace_bar("", tracer.trace_of(viewer), left, COMPACT_BAR_WIDTH)
			bar.tooltip_text = label
		else:
			bar = trace_bar(label, tracer.trace_of(viewer), left)
		bars.append(bar)
	return bars
