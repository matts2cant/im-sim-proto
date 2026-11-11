class_name DeckDeviceMenu
extends RefCounted
## What the deck's Map shows in a device's menu (NetworkGraph.menu_builder; ADR 0113, 0116): its
## software once its subnet is scanned, "Exploits (n)" and "Firewall rules" (IntrusionMenu), a
## wireless device's access point, its accounts (access / "Log in (from <note>)" / Icebreaker /
## "too strong"), a router's note, "Open its desktop (remote)" on a computer with access, its
## commands with access, else who it trusts. Skill assists (Icebreaker.assist()): Trained crack
## times; Advanced + the trace a crack adds; Master + how many hidden subnets a router routes to.

## "Exploits (n)" pressed on `device`.
signal exploits_requested(device: Device)
## "Firewall rules" pressed on router `device`.
signal firewall_requested(device: Device)
## An Icebreaker crack started from an account row.
signal crack_started
## A line for the deck's toast.
signal notice(text: String)
## A command was sent: the map redraws.
signal map_changed

const WIDTH: float = 300.0

var session: DeckSession
var ice: IcebreakerTool
var exploit_tool: ExploitTool


func bind(p_session: DeckSession, p_ice: IcebreakerTool, p_exploit_tool: ExploitTool) -> void:
	session = p_session
	ice = p_ice
	exploit_tool = p_exploit_tool


## Fills `column` with the menu of `row`.
func build(row: NetworkRow, column: VBoxContainer) -> void:
	var device := row.device
	var text_width := WIDTH - 24.0
	var software := IntrusionMenu.software_line(row, session)
	if software != null:
		column.add_child(software)
	if device.wireless_link() != null:
		var via := "wireless via %s" % NetworkSource.display_name(device.wireless_link())
		column.add_child(DeckStyle.mono(via, NetworkGraph.WIRELESS_COLOR, 12))
	if row.is_self:
		column.add_child(DeckStyle.paragraph("Your entry point.", DeckStyle.DIM_COLOR, 12, text_width))
		if session.source.kind == NetworkSource.Kind.JACK:
			return
	if not row.online:
		column.add_child(DeckStyle.label("No connection.", DeckStyle.DIM_COLOR, 13))
		return
	if session.is_blocked(device):
		var left := 0.0
		for tracer in Tracer.watching(device):
			left = maxf(left, tracer.model.lockout_left(session.source.address))
		column.add_child(DeckStyle.label("Blocked by a tracer: %d s" % ceili(left), DeckStyle.ERROR_COLOR, 13))
		return
	IntrusionMenu.add_to(column, row, session, exploit_tool, exploits_requested.emit, firewall_requested.emit)
	var assist := Icebreaker.assist(session.entity)
	var accounts := DeviceAccounts.of(device.entity)
	if accounts != null and not accounts.accounts.is_empty():
		column.add_child(DeckStyle.mono("ACCOUNTS", DeckStyle.DIM_COLOR, 11))
		for each in accounts.accounts:
			column.add_child(_account_row(device, accounts, each, assist))
	var router := Router.of(device.entity)
	if router != null:
		var note := "Hacked: the subnets behind it are on the map."
		if not row.access:
			note = "A router between subnets. Hack it to see what lies behind it; a subnet behind may hide another router."
		column.add_child(DeckStyle.paragraph(note, DeckStyle.DIM_COLOR, 12, text_width))
		if assist >= Icebreaker.ASSIST_ROUTES and not row.access:
			var routes := session.hidden_routes(device)
			column.add_child(DeckStyle.assist("routes to %d hidden subnet%s" % [routes, "" if routes == 1 else "s"]))
	if row.access and Computer.of(device.entity) != null:
		var remote := DeckStyle.button("Open its desktop (remote)", 13, true)
		remote.pressed.connect(func() -> void: session.open_remote(device))
		column.add_child(remote)
	if row.access:
		_add_commands(column, row)
	elif accounts == null or accounts.accounts.is_empty():
		var trusted := DeviceNetwork.trusted(device)
		var note := "No accounts."
		if not trusted.is_empty():
			var names := PackedStringArray()
			for each in trusted:
				names.append(NetworkSource.display_name(each))
			note = "No accounts. Trusts %s: control it from that computer's Security app." % ", ".join(names)
		column.add_child(DeckStyle.paragraph(note, DeckStyle.DIM_COLOR, 12, text_width))


func _add_commands(column: VBoxContainer, row: NetworkRow) -> void:
	var commands := DeviceStatus.applicable(session.commands_for(row.device), row.status, row.disabled)
	if commands.is_empty():
		return
	var flow := HFlowContainer.new()
	flow.add_theme_constant_override(&"h_separation", 6)
	flow.add_theme_constant_override(&"v_separation", 6)
	for command in commands:
		var button := DeckStyle.button(session.config.label_for(command), 13)
		button.pressed.connect(_on_command.bind(command, row.device))
		flow.add_child(button)
	column.add_child(flow)


func _account_row(device: Device, accounts: DeviceAccounts, account: DeviceAccount, assist: int) -> Control:
	var line := HBoxContainer.new()
	line.add_theme_constant_override(&"separation", 8)
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_theme_constant_override(&"separation", 0)
	var known := accounts.knows_login(session.entity, account.user)
	var has := accounts.has_access(session.entity, account.user)
	var detail := DeviceAccount.strength_name(account.strength)
	var can := ice.can_crack(device, account.user)
	if not known and not has and can and assist >= Icebreaker.ASSIST_TIMES:
		detail += " · %s" % DeckStyle.seconds(ice.crack_time(device, account.user))
	info.add_child(DeckStyle.mono(account.user, DeckStyle.TEXT_COLOR, 13))
	info.add_child(DeckStyle.mono(detail, DeckStyle.DIM_COLOR, 11))
	if not known and not has and can and assist >= Icebreaker.ASSIST_TRACE:
		var gain := Tracer.highest_gain(device)
		var progress := ice.saved_progress(device, account.user)
		var trace := (
			(1.0 - progress) * ice.crack_time(device, account.user) * gain * Icebreaker.trace_mult(session.entity)
		)
		info.add_child(
			DeckStyle.mono(DeckStyle.ASSIST_PREFIX + "about +%d %% trace" % roundi(trace), DeckStyle.SELF_COLOR, 11)
		)
	line.add_child(info)
	if has:
		line.add_child(DeckStyle.label("access", DeckStyle.ACCESS_COLOR, 13))
	elif known:
		var source := accounts.known_source(session.entity, account.user)
		var login := DeckStyle.button("Log in (from %s)" % source if not source.is_empty() else "Log in", 12, true)
		login.pressed.connect(func() -> void: session.log_in(device, account.user))
		login.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		line.add_child(login)
	else:
		var progress := ice.saved_progress(device, account.user)
		var text := "Icebreaker" if can else "too strong"
		if can and progress > 0.0:
			text = "Icebreaker (%d %%)" % roundi(progress * 100.0)
		var crack := DeckStyle.button(text, 12)
		crack.disabled = not can
		crack.pressed.connect(_on_crack.bind(device, account.user))
		crack.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		line.add_child(crack)
	return line


func _on_crack(device: Device, user: String) -> void:
	if ice.start(device, user):
		crack_started.emit()


func _on_command(command: StringName, device: Device) -> void:
	var label := session.config.label_for(command)
	var target := NetworkSource.display_name(device)
	notice.emit("%s: %s sent." % [target, label] if session.send(command, device) else "%s: no connection." % target)
	map_changed.emit()
