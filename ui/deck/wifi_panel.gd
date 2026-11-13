class_name WifiPanel
extends MarginContainer
## The deck's Wi-Fi key screen (M12b, ADR 0117; the approved mockup intrusion_screens.html, "Deck
## aimed at AP-YARD"), DeckScreen's Wi-Fi view: the access point its WirelessTool aims at, the key's
## strength and the user's range (Computer skill tier), the signal (bars fall with distance; "out of
## range" past it) and line of sight, the crack's progress bar, Crack the key / Resume / Stop (keeps
## progress), "Paused: ..." while a running crack cannot advance (the button greyed with "Cannot
## crack: ..." before it runs), the Trained assist (time left), and once the key is known, the subnet
## the deck joined over Wi-Fi with its address and a Map button (`map_requested`).
## show_for() refills it only when what it shows changed, reconciled (DeckStyle.reconcile()) so the
## button under a still cursor keeps its hover and a click held across a refresh lands.
## Static helpers give the deck's title bar its text and trace bars while aiming.

## The Map button was pressed (the deck joined the access point's subnet).
signal map_requested

## Signal bars drawn, the highest lit at distance 0.
const BARS: int = 5
const BAR_WIDTH: float = 6.0
const BAR_STEP: float = 4.0
const PROGRESS_WIDTH: float = 520.0
const TEXT_WIDTH: float = 520.0
const NOTE: String = (
	"Keep the access point in sight and in range while cracking; losing it pauses the crack."
	+ " Breaking or unpowering an access point takes its wireless devices offline."
)

var wireless: WirelessTool
var column: VBoxContainer

var _signature: String = ""


func _init() -> void:
	name = "Wifi"
	visible = false
	set_anchors_preset(Control.PRESET_FULL_RECT)
	theme_type_variation = &"WindowBody"
	column = VBoxContainer.new()
	column.add_theme_constant_override(&"separation", 14)
	add_child(column)


## How many of BARS a signal at `distance` within `reach` lights (0 out of range, at least 1 in it).
static func signal_bars(distance: float, reach: float) -> int:
	if reach <= 0.0 or distance > reach:
		return 0
	return clampi(roundi(BARS * (1.0 - distance / reach) + 1.0), 1, BARS)


## The words for a pause reason (WirelessTool.pause_reason()).
static func pause_text(reason: StringName) -> String:
	match reason:
		WirelessTool.OUT_OF_RANGE:
			return "out of range"
		WirelessTool.NO_SIGHT:
			return "line of sight lost"
		WirelessTool.NO_SIGNAL:
			return "no signal (the access point is down)"
		WirelessTool.BLOCKED:
			return "blocked by a tracer"
	return ""


## The deck's title bar while aiming: "Aimed at AP-YARD · access point · 10 m".
static func title_text(p_wireless: WirelessTool) -> String:
	if p_wireless == null or not is_instance_valid(p_wireless.target):
		return "Wi-Fi"
	var distance := _number(p_wireless.distance_to(p_wireless.target))
	return "Aimed at %s · access point · %s m" % [EntityNames.device_name(p_wireless.target), distance]


## The address a crack of the aimed access point counts as (the deck's would-be Wi-Fi address).
static func aim_address(p_wireless: WirelessTool) -> String:
	if p_wireless == null or not is_instance_valid(p_wireless.target):
		return ""
	return NetworkSource.wireless(p_wireless.entity, p_wireless.target).address


## The tracers the title bar shows while aiming: those watching the access point, with trace for
## the user, or blocking the would-be address.
static func tracers(p_wireless: WirelessTool) -> Array[Tracer]:
	if p_wireless == null or not is_instance_valid(p_wireless.target):
		return [] as Array[Tracer]
	var aimed: Array[Device] = [p_wireless.target]
	return Tracer.bars_for(p_wireless.get_tree(), p_wireless.entity, aimed, aim_address(p_wireless))


## Shows `p_wireless`'s target now (refilled only when what it shows changed).
func show_for(p_wireless: WirelessTool) -> void:
	wireless = p_wireless
	if wireless == null:
		return
	var tier := _tier_name()
	var signature := _signature_of(tier)
	if signature == _signature:
		return
	_signature = signature
	var fresh := VBoxContainer.new()
	_fill(fresh, tier)
	DeckStyle.reconcile(column, fresh)


## Refills at the next show_for().
func invalidate() -> void:
	_signature = ""


## Every visible label and button text shown, in order (tests).
func texts() -> Array[String]:
	var found: Array[String] = []
	_collect(column, found)
	return found


static func _collect(node: Node, found: Array[String]) -> void:
	for child in node.get_children():
		if child.is_queued_for_deletion() or (child is CanvasItem and not (child as CanvasItem).visible):
			continue
		if child is Button:
			found.append((child as Button).text)
		elif child is Label:
			found.append((child as Label).text)
		_collect(child, found)


func _on_toggle() -> void:
	if wireless == null:
		return
	if wireless.is_running():
		wireless.stop()
	else:
		wireless.start()
	_signature = ""
	show_for(wireless)


# The user's Computer skill tier name ("Trained"), or "" without Skills.
func _tier_name() -> String:
	var skills := Skills.of(wireless.entity)
	if skills == null or skills.table == null:
		return ""
	return skills.table.tier_name(skills.tier(&"computer"))


func _signature_of(tier: String) -> String:
	var target := wireless.target
	if target == null or not is_instance_valid(target):
		return "none"
	var radio := AccessPoint.of(target)
	var session := wireless.session
	return str(
		[
			DeckSession.key_of(target),
			_number(wireless.distance_to(target)),
			wireless.has_sight(target),
			wireless.is_running(),
			wireless.pause_reason(),
			wireless.reason_for(target),
			roundi(_progress_of(target) * 200.0),
			radio.knows_key(wireless.entity) if radio != null else false,
			session.is_wireless() and session.port == target,
			Icebreaker.assist(wireless.entity),
			roundi(wireless.wireless_range()),
			tier,
		]
	)


func _progress_of(target: Device) -> float:
	return wireless.job.progress if wireless.job != null else wireless.saved_progress(target)


func _fill(into: VBoxContainer, tier: String) -> void:
	var target := wireless.target
	var radio := AccessPoint.of(target) if is_instance_valid(target) else null
	if radio == null:
		into.add_child(DeckStyle.label("Wi-Fi", DeckStyle.TITLE_COLOR, 20))
		var hint := "Aim the deck at an access point (LMB) to crack its Wi-Fi key."
		into.add_child(DeckStyle.paragraph(hint, DeckStyle.DIM_COLOR, 14, TEXT_WIDTH))
		return
	var reach := wireless.wireless_range()
	into.add_child(DeckStyle.label("Wi-Fi key · %s" % EntityNames.device_name(target), DeckStyle.TITLE_COLOR, 20))
	var skill := " (Computer skill: %s)" % tier if not tier.is_empty() else ""
	var strength := DeviceAccount.strength_name(radio.key_strength)
	var facts := "key strength %s · your range %d m%s" % [strength, roundi(reach), skill]
	into.add_child(DeckStyle.mono(facts, DeckStyle.DIM_COLOR, 12))
	into.add_child(_signal_line(wireless.distance_to(target), reach, wireless.has_sight(target)))
	var known := radio.knows_key(wireless.entity)
	into.add_child(_progress(1.0 if known else _progress_of(target)))
	var actions := HFlowContainer.new()
	actions.name = "Actions"
	actions.add_theme_constant_override(&"h_separation", 10)
	actions.add_theme_constant_override(&"v_separation", 8)
	if known:
		_fill_known(actions, target)
	else:
		_fill_crack(actions, target)
	into.add_child(actions)
	into.add_child(DeckStyle.paragraph(NOTE, DeckStyle.DIM_COLOR, 12, TEXT_WIDTH))


func _fill_known(actions: HFlowContainer, target: Device) -> void:
	var session := wireless.session
	var joined := session.is_wireless() and session.port == target
	var text := "Key cracked: aim the deck at %s within range to join its subnet" % EntityNames.device_name(target)
	if joined:
		text = (
			"Key cracked: joined the %s subnet over Wi-Fi (%s) while in range"
			% [WirelessTool.subnet_name(target), session.source.address]
		)
	actions.add_child(DeckStyle.label(text, DeckStyle.ACCESS_COLOR, 14))
	if joined:
		var map := DeckStyle.button("Map", 13, true)
		map.pressed.connect(map_requested.emit)
		actions.add_child(map)


func _fill_crack(actions: HFlowContainer, target: Device) -> void:
	var running := wireless.is_running()
	var reason := wireless.pause_reason() if running else wireless.reason_for(target)
	var can := wireless.can_crack(target)
	var progress := _progress_of(target)
	var label := "Stop (keeps progress)" if running else ("Resume" if progress > 0.0 else "Crack the key")
	if not can:
		label = "too strong"
	var toggle := DeckStyle.button(label, 13, not running and can)
	toggle.disabled = not can or (not running and not reason.is_empty())
	toggle.pressed.connect(_on_toggle)
	actions.add_child(toggle)
	if not reason.is_empty() and can:
		var prefix := "Paused: " if running else "Cannot crack: "
		actions.add_child(DeckStyle.mono(prefix + pause_text(reason), DeckStyle.ALERT_COLOR, 12))
	if can and Icebreaker.assist(wireless.entity) >= Icebreaker.ASSIST_TIMES:
		var left := (1.0 - progress) * wireless.crack_time(target)
		actions.add_child(DeckStyle.assist("%s s left" % _number(left)))


# "Signal" and its bars (or "out of range") and the distance, "Line of sight" clear / blocked.
static func _signal_line(distance: float, reach: float, sight: bool) -> Control:
	var line := HBoxContainer.new()
	line.name = "Signal"
	line.add_theme_constant_override(&"separation", 10)
	line.add_child(DeckStyle.mono("Signal", DeckStyle.TEXT_COLOR, 13))
	var lit := signal_bars(distance, reach)
	if lit == 0:
		line.add_child(DeckStyle.mono("out of range", DeckStyle.ERROR_COLOR, 13))
	else:
		var bars := HBoxContainer.new()
		bars.name = "Bars"
		bars.add_theme_constant_override(&"separation", 3)
		bars.size_flags_vertical = Control.SIZE_SHRINK_END
		for i in BARS:
			var bar := ColorRect.new()
			bar.custom_minimum_size = Vector2(BAR_WIDTH, 4.0 + BAR_STEP * i)
			bar.size_flags_vertical = Control.SIZE_SHRINK_END
			bar.color = DeckStyle.ONLINE_COLOR if i < lit else Color(DeckStyle.OFFLINE_COLOR, 0.8)
			bars.add_child(bar)
		line.add_child(bars)
	line.add_child(DeckStyle.mono("%s m" % _number(distance), DeckStyle.DIM_COLOR, 13))
	var gap := Control.new()
	gap.custom_minimum_size.x = 18.0
	line.add_child(gap)
	line.add_child(DeckStyle.mono("Line of sight", DeckStyle.TEXT_COLOR, 13))
	var sight_color := DeckStyle.ONLINE_COLOR if sight else DeckStyle.ERROR_COLOR
	line.add_child(DeckStyle.mono("clear" if sight else "blocked", sight_color, 13))
	return line


static func _progress(value: float) -> Control:
	var track := DeckStyle.track(PROGRESS_WIDTH, 10.0, value, DeckStyle.TITLE_COLOR)
	track.name = "Progress"
	track.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	return track


static func _number(value: float) -> String:
	var rounded := snappedf(value, 0.1)
	if is_equal_approx(rounded, roundf(rounded)):
		return str(roundi(rounded))
	return "%.1f" % rounded
