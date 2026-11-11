class_name IntrusionMenu
extends RefCounted
## The M12b parts of a device's menu on the deck's Map (ADR 0115, 0116; the approved mockup
## design/prototypes/intrusion_screens.html), added by DeckScreen: the software line ("Helix CAM-3
## 2.1", once the device's subnet is scanned), "Exploits (n)" for the known exploits that match it
## (never on the entry point), "Firewall rules" on a router the user is admin of, and the access an
## exploit gave ("access: admin (exploit)").


## The software line of `row`'s device, or null (no software, or its subnet not scanned yet).
static func software_line(row: NetworkRow, session: DeckSession) -> Label:
	var device := row.device
	if device.software == null or not DeckSession.has_scanned(session.stack, row.subnet):
		return null
	var line := DeckStyle.mono(device.software.label(), DeckStyle.TITLE_COLOR, 12)
	line.name = "Software"
	return line


## Adds the buttons and the exploit access line of `row` to `column`: `on_exploits(device)` and
## `on_firewall(device)` open the tools.
static func add_to(
	column: VBoxContainer,
	row: NetworkRow,
	session: DeckSession,
	tool: ExploitTool,
	on_exploits: Callable,
	on_firewall: Callable
) -> void:
	var device := row.device
	var flow := HFlowContainer.new()
	flow.add_theme_constant_override(&"h_separation", 6)
	var count := tool.matching(device).size() if tool != null and not row.is_self else 0
	if count > 0:
		var exploits := DeckStyle.button("Exploits (%d)" % count, 13)
		exploits.pressed.connect(on_exploits.bind(device))
		flow.add_child(exploits)
	if Router.of(device.entity) != null and device.is_admin(session.entity):
		var rules := DeckStyle.button("Firewall rules", 13, true)
		rules.pressed.connect(on_firewall.bind(device))
		flow.add_child(rules)
	if flow.get_child_count() > 0:
		column.add_child(flow)
	else:
		flow.free()
	var granted := device.intrusion.exploit_access(NetworkSource.user_key(session.entity))
	if granted >= 0:
		var level := "admin" if granted == Exploit.Access.ADMIN else "user"
		column.add_child(DeckStyle.mono("access: %s (exploit)" % level, DeckStyle.ACCESS_COLOR, 12))
