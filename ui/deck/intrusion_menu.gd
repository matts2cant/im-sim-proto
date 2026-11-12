class_name IntrusionMenu
extends RefCounted
## The intrusion parts of a device's menu on the deck's Map (ADR 0115, 0121; the approved mockup
## design/prototypes/hacking_fixes.html), added by DeckDeviceMenu: "Use <kind> exploit (N left)"
## when the user carries an exploit item of the device's kind and has no access there yet (never on
## the entry point; ExploitItems), "Firewall rules" on a router the user is admin of, and the access
## an exploit item gave ("access: admin (exploit)").

const EXPLOIT_NOTE: String = "One use: admin control of this device, at once, no trace. The device logs it."


## The "Use … exploit (N left)" label for `item` with `left` carried.
static func use_label(item: ItemData, left: int) -> String:
	return "Use %s (%d left)" % [item.display_name.to_lower(), left]


## Adds the buttons and the exploit access line of `row` to `column`: `on_use(device)` uses an
## exploit item, `on_firewall(device)` opens the Firewall.
static func add_to(
	column: VBoxContainer, row: NetworkRow, session: DeckSession, on_use: Callable, on_firewall: Callable
) -> void:
	var device := row.device
	var user := session.entity
	var flow := HFlowContainer.new()
	flow.add_theme_constant_override(&"h_separation", 6)
	var item := ExploitItems.item_for(user, device)
	var usable := item != null and not row.is_self and ExploitItems.can_use(user, device)
	if usable:
		var left := ExploitItems.count(user, item.exploit_kind)
		var use := DeckStyle.button(use_label(item, left), 13, true)
		use.name = "UseExploit"
		use.pressed.connect(on_use.bind(device))
		flow.add_child(use)
	if Router.of(device.entity) != null and device.is_admin(user):
		var rules := DeckStyle.button("Firewall rules", 13, true)
		rules.pressed.connect(on_firewall.bind(device))
		flow.add_child(rules)
	if flow.get_child_count() > 0:
		column.add_child(flow)
	else:
		flow.free()
	if usable:
		column.add_child(DeckStyle.paragraph(EXPLOIT_NOTE, DeckStyle.DIM_COLOR, 12, DeckDeviceMenu.WIDTH - 24.0))
	if device.intrusion.has_exploit(NetworkSource.user_key(user)):
		column.add_child(DeckStyle.mono("access: admin (exploit)", DeckStyle.ACCESS_COLOR, 12))
