class_name FirewallView
extends MarginContainer
## The deck's Firewall tool (ADR 0115, 0116; the approved mockup design/prototypes/
## intrusion_screens.html): as admin of a router the deck reaches (an admin account or an exploit
## item), its ordered rules as a table: number (click to select), From, To (each a
## choice of any, "you" (From only), a subnet or a device on the map), ALLOW / DENY (click to
## toggle); Add a rule (appended: any -> any with the router's default, so it changes nothing until
## edited), Move up, Move down, Delete. The first rule that matches decides (Router.passes()); a
## line under the table says what happens without a match. Every edit goes through the Router
## (Router.add_rule(), ...) with the deck's source, so it is logged on the router. Rebuilt only when
## what it shows changes (the rules, the selection, the choices, access).

const TEXT_WIDTH: float = 660.0
const CHOICE_WIDTH: float = 190.0
const INTRO := (
	"Rules are checked from the top; the first one that matches decides. They decide which devices reach"
	+ " which through this router: commands, alarm incidents and sirens ringing."
)
const NO_ROUTER := "Get an admin account on a router (the Map: its menu's Firewall rules) to see and edit its rules."
const NOT_ADMIN := "You need admin access to %s to see its rules."
const NO_CONNECTION := "No connection to %s."
const NO_RULES := "No rules yet."
const ANY := "any"
const YOU := "you"

var session: DeckSession
## The router's device whose rules it shows (null: none picked).
var router_device: Device
## The selected rule (Move up / down and Delete act on it).
var selected: int = 0

var _column: VBoxContainer
var _signature: String = ""


func _init() -> void:
	name = "Firewall"
	set_anchors_preset(Control.PRESET_FULL_RECT)
	theme_type_variation = &"WindowBody"
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	_column = VBoxContainer.new()
	_column.name = "Column"
	_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_column.add_theme_constant_override(&"separation", 10)
	scroll.add_child(_column)


func bind(p_session: DeckSession) -> void:
	session = p_session
	_signature = ""


## Shows `device`'s rules (a router).
func show_router(device: Device) -> void:
	if device != router_device:
		selected = 0
	router_device = device
	_signature = ""
	refresh()


## The Router whose rules the user may edit now (online and admin), else null.
func router() -> Router:
	if session == null or not is_instance_valid(router_device):
		return null
	var found := Router.of(router_device.entity)
	if found == null or not session.is_online(router_device) or not router_device.is_admin(session.entity):
		return null
	return found


## The first router on the map the user is admin of and reaches (the tool opened from its button).
func default_router() -> Device:
	if session == null:
		return null
	for device in session.map_devices():
		if is_instance_valid(device) and Router.of(device.entity) != null and device.is_admin(session.entity):
			if session.is_online(device):
				return device
	return null


## Brings it up to date (rebuilt only when something it shows changed).
func refresh() -> void:
	if session == null:
		return
	var signature := _signature_now()
	if signature == _signature:
		return
	_signature = signature
	for child in _column.get_children():
		DeckStyle.discard(child)
	_fill(_column)


## The choices a rule's From (`from_side`) or To can name: each {label, kind, value}: any,
## "you" (From only), every subnet a router on the map joins or a map device is on, every device on
## the map with an address (rules name devices by address, ADR 0140) but the deck's entry point.
func endpoints(from_side: bool) -> Array[Dictionary]:
	var found: Array[Dictionary] = [{"label": ANY, "kind": RouterRule.Match.ANY, "value": ""}]
	if from_side:
		found.append({"label": YOU, "kind": RouterRule.Match.YOU, "value": ""})
	var info := Router.subnet_info(session.get_tree())
	var subnets: Array[StringName] = []
	var devices := session.map_devices()
	for device in devices:
		if not is_instance_valid(device):
			continue
		var router_here := Router.of(device.entity)
		var own: Array[StringName] = [DeviceNetwork.subnet_of(device)]
		if router_here != null:
			own = router_here.subnets()
		for each: StringName in own:
			if not each.is_empty() and not subnets.has(each):
				subnets.append(each)
	for each: StringName in subnets:
		found.append({"label": subnet_label(each, info), "kind": RouterRule.Match.SUBNET, "value": String(each)})
	for device in devices:
		if not is_instance_valid(device) or device.address.is_empty() or device == session.port:
			continue
		var label := EntityNames.device_name(device)
		found.append({"label": label, "kind": RouterRule.Match.DEVICE, "value": device.address})
	return found


## "OFFICE subnet" (its data's label, else its id in capitals).
static func subnet_label(id: StringName, info: Dictionary[StringName, Subnet]) -> String:
	var data: Subnet = info.get(id, null)
	var label := data.label if data != null and not data.label.is_empty() else String(id).to_upper()
	return "%s subnet" % label


## How a rule's end shows (`from_side`: its From): the matching choice's label, else the raw value.
func end_label(rule: RouterRule, from_side: bool) -> String:
	var choices := endpoints(from_side)
	var at := _choice_index(choices, rule, from_side)
	return str(choices[at]["label"]) if at >= 0 else _raw(rule, from_side)


## "1 OFFICE subnet -> SECURITY subnet DENY" per rule (tests).
func rule_lines() -> Array[String]:
	var found: Array[String] = []
	var current := router()
	if current == null:
		return found
	for i in current.rules.size():
		var rule := current.rules[i]
		var verdict := "ALLOW" if rule.allow else "DENY"
		found.append("%d %s -> %s %s" % [i + 1, end_label(rule, true), end_label(rule, false), verdict])
	return found


## Every visible text (tests).
func texts() -> Array[String]:
	var found: Array[String] = []
	_collect(_column, found)
	return found


## Sets rule `index`'s From (`from_side`) or To to the choice labelled `label`; false without one.
func choose(index: int, from_side: bool, label: String) -> bool:
	var choices := endpoints(from_side)
	for i in choices.size():
		if str(choices[i]["label"]) == label:
			_on_choice(i, index, from_side, choices)
			return true
	return false


## Adds a rule (appended: any -> any with the router's default verdict) and selects it.
func add_rule() -> void:
	var current := router()
	if current == null:
		return
	var rule := RouterRule.make(RouterRule.Match.ANY, "", RouterRule.Match.ANY, "", current.default_allow)
	selected = current.add_rule(rule, -1, session.source)
	_changed()


## Moves the selected rule up (-1) or down (1).
func move_selected(by: int) -> void:
	var current := router()
	if current == null:
		return
	selected = current.move_rule(selected, by, session.source)
	_changed()


func delete_selected() -> void:
	var current := router()
	if current == null or current.rules.is_empty():
		return
	current.remove_rule(selected, session.source)
	selected = clampi(selected, 0, maxi(0, current.rules.size() - 1))
	_changed()


func toggle(index: int) -> void:
	var current := router()
	if current == null:
		return
	selected = index
	current.toggle_rule(index, session.source)
	_changed()


func select_rule(index: int) -> void:
	selected = index
	_signature = ""
	refresh()


func _signature_now() -> String:
	var current := router()
	var parts := PackedStringArray([DeckSession.key_of(router_device), str(current != null), str(selected)])
	if current == null:
		if is_instance_valid(router_device):
			parts.append("%s|%s" % [session.is_online(router_device), router_device.is_admin(session.entity)])
		return "\n".join(parts)
	parts.append(str(current.save_state()))
	for side: bool in [true, false]:
		for choice in endpoints(side):
			parts.append(str(choice["label"]))
	return "\n".join(parts)


func _fill(column: VBoxContainer) -> void:
	var current := router()
	var title := "Firewall"
	if is_instance_valid(router_device):
		title += " · %s" % EntityNames.device_name(router_device)
	column.add_child(DeckStyle.label(title, DeckStyle.TITLE_COLOR, 20))
	if current == null:
		var text := NO_ROUTER
		if is_instance_valid(router_device) and Router.of(router_device.entity) != null:
			var shown := EntityNames.device_name(router_device)
			if not session.is_online(router_device):
				text = NO_CONNECTION % shown
			elif not router_device.is_admin(session.entity):
				text = NOT_ADMIN % shown
		column.add_child(DeckStyle.paragraph(text, DeckStyle.DIM_COLOR, 14, TEXT_WIDTH))
		return
	column.add_child(DeckStyle.paragraph(INTRO, DeckStyle.DIM_COLOR, 14, TEXT_WIDTH))
	selected = clampi(selected, 0, maxi(0, current.rules.size() - 1))
	column.add_child(_table(current))
	var actions := HFlowContainer.new()
	actions.add_theme_constant_override(&"h_separation", 8)
	actions.add_theme_constant_override(&"v_separation", 8)
	var add := DeckStyle.button("Add a rule", 13)
	add.pressed.connect(add_rule)
	actions.add_child(add)
	var up := DeckStyle.button("Move up", 13)
	up.disabled = current.rules.is_empty() or selected <= 0
	up.pressed.connect(move_selected.bind(-1))
	actions.add_child(up)
	var down := DeckStyle.button("Move down", 13)
	down.disabled = current.rules.is_empty() or selected >= current.rules.size() - 1
	down.pressed.connect(move_selected.bind(1))
	actions.add_child(down)
	var delete := DeckStyle.button("Delete", 13)
	delete.disabled = current.rules.is_empty()
	delete.add_theme_color_override(&"font_hover_color", DeckStyle.ERROR_COLOR)
	delete.pressed.connect(delete_selected)
	actions.add_child(delete)
	column.add_child(actions)
	var fallback := "allowed" if current.default_allow else "denied"
	var yours := "you have one" if router_device.has_access(session.entity) else "you have none"
	var note := "No rule matches: devices' traffic is %s; " % fallback
	note += 'yours passes with an account on this router (%s). Only rules from "you" judge your traffic.' % yours
	column.add_child(DeckStyle.paragraph(note, DeckStyle.DIM_COLOR, 12, TEXT_WIDTH))


func _table(current: Router) -> GridContainer:
	var grid := GridContainer.new()
	grid.name = "Rules"
	grid.columns = 5
	grid.add_theme_constant_override(&"h_separation", 10)
	grid.add_theme_constant_override(&"v_separation", 6)
	for header: String in ["#", "FROM", "", "TO", "ACTION"]:
		grid.add_child(DeckStyle.mono(header, DeckStyle.DIM_COLOR, 11))
	if current.rules.is_empty():
		for text: String in [NO_RULES, "", "", "", ""]:
			grid.add_child(DeckStyle.label(text, DeckStyle.DIM_COLOR, 13))
		return grid
	var from_choices := endpoints(true)
	var to_choices := endpoints(false)
	for i in current.rules.size():
		var rule := current.rules[i]
		var number := DeckStyle.button(str(i + 1), 12, i == selected)
		number.custom_minimum_size.x = 34.0
		number.tooltip_text = "Select rule %d" % (i + 1)
		number.pressed.connect(select_rule.bind(i))
		grid.add_child(number)
		grid.add_child(_choice(from_choices, rule, i, true))
		grid.add_child(DeckStyle.label("→", DeckStyle.DIM_COLOR, 14))
		grid.add_child(_choice(to_choices, rule, i, false))
		var verdict := DeckStyle.button("ALLOW" if rule.allow else "DENY", 12)
		verdict.custom_minimum_size.x = 76.0
		verdict.tooltip_text = "Switch rule %d between allow and deny" % (i + 1)
		var colour := DeckStyle.ONLINE_COLOR if rule.allow else DeckStyle.ERROR_COLOR
		verdict.add_theme_color_override(&"font_color", colour)
		verdict.add_theme_color_override(&"font_hover_color", colour)
		verdict.pressed.connect(toggle.bind(i))
		grid.add_child(verdict)
	return grid


func _choice(choices: Array[Dictionary], rule: RouterRule, index: int, from_side: bool) -> OptionButton:
	var option := OptionButton.new()
	option.custom_minimum_size = Vector2(CHOICE_WIDTH, 30)
	option.focus_mode = Control.FOCUS_NONE
	option.fit_to_longest_item = false
	option.clip_text = true
	option.add_theme_font_override(&"font", DeckStyle.mono_font())
	option.add_theme_font_size_override(&"font_size", 13)
	option.add_theme_color_override(&"font_color", DeckStyle.TEXT_COLOR)
	option.theme_type_variation = &"DeckField"
	var list := choices.duplicate()
	var at := _choice_index(list, rule, from_side)
	if at < 0:
		var kind := rule.from_kind if from_side else rule.to_kind
		list.append({"label": _raw(rule, from_side), "kind": kind, "value": rule.from if from_side else rule.to})
		at = list.size() - 1
	for each: Dictionary in list:
		option.add_item(str(each["label"]))
	option.select(at)
	option.item_selected.connect(func(item: int) -> void: _on_choice(item, index, from_side, list))
	return option


func _on_choice(item: int, index: int, from_side: bool, choices: Array[Dictionary]) -> void:
	var current := router()
	if current == null or index < 0 or index >= current.rules.size() or item < 0 or item >= choices.size():
		return
	var rule := current.rules[index].duplicate() as RouterRule
	var choice := choices[item]
	if from_side:
		rule.from_kind = int(choice["kind"]) as RouterRule.Match
		rule.from = str(choice["value"])
	else:
		rule.to_kind = int(choice["kind"]) as RouterRule.Match
		rule.to = str(choice["value"])
	selected = index
	current.set_rule(index, rule, session.source)
	_changed()


static func _choice_index(choices: Array[Dictionary], rule: RouterRule, from_side: bool) -> int:
	var kind := rule.from_kind if from_side else rule.to_kind
	var value := rule.from if from_side else rule.to
	for i in choices.size():
		var choice := choices[i]
		if int(choice["kind"]) != int(kind):
			continue
		if kind == RouterRule.Match.ANY or kind == RouterRule.Match.YOU:
			return i
		if str(choice["value"]) == value:
			return i
	return -1


static func _raw(rule: RouterRule, from_side: bool) -> String:
	var value := rule.from if from_side else rule.to
	return value if not value.is_empty() else "?"


func _changed() -> void:
	_signature = ""
	session.refresh()
	refresh()


func _collect(node: Node, found: Array[String]) -> void:
	for child in node.get_children():
		if child.is_queued_for_deletion():
			continue
		var canvas := child as CanvasItem
		if canvas != null and not canvas.visible:
			continue
		if child is Button:
			found.append((child as Button).text)
		elif child is Label:
			found.append((child as Label).text)
		_collect(child, found)
