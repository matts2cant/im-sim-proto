extends RefCounted
## Test helper (not a suite): a small network built in code from components (ADR 0113), to show
## the network behaviour is generic: any entity with a Device, and a Router, DeviceAccounts, Tracer
## or Computer component, behaves the same. lab() builds the network of the approved mockup
## (positions in metres from `origin`, plan view: x east, z south):
##
##   Jack ── OfficeSwitch ── Rtr01 ── SecuritySwitch ── Rtr02 ── ServerSwitch ── FileServer
##   (0,0)   (2,0)   │       (5,0)   (8,0) │ │ │       (8,-3)  (11,-3)          (12,-5)
##                OfficePc               Console Camera Alarm
##                (2,3)                  (7,3)   (9,3)  (10,1)
##   Kiosk (0,4): autonomous (no cables), a maintenance port.
##
## Subnets: office (Jack, OfficeSwitch, OfficePc, Rtr01), security (SecuritySwitch, Console, Camera,
## Alarm, Rtr02), servers (ServerSwitch, FileServer). Rtr01 runs the "Sentry tracer" watching office
## and security. Camera trusts Console. Accounts (user, password, strength, admin):
## OfficePc kbrandt / ferry19 Weak; Rtr01 admin / Gh7vQx2e Medium admin; Console dmarsh / harbor77
## Medium; Rtr02 admin / k3epOut9 Medium admin; FileServer hale / Riverside#1 Strong; Kiosk service /
## kiosk1 Weak. OfficePc and Console are computers (Computer component). Screens show the mockup's
## names (SHOWN: `display_name` metadata).

const Devices := preload("res://tests/objects/devices/device_fixtures.gd")
const Fixtures := preload("res://tests/core/stimulus/stimulus_fixtures.gd")
const SWITCH: PackedScene = preload("res://objects/devices/network_switch.tscn")
const JACK: PackedScene = preload("res://objects/network/wall_jack.tscn")
const ROUTER: PackedScene = preload("res://objects/network/router.tscn")
## Added to the alarm stand-in by every incident it receives.
const ALARMED: StringName = &"test.alarmed"
const WEAK := DeviceAccount.Strength.WEAK
const MEDIUM := DeviceAccount.Strength.MEDIUM
const STRONG := DeviceAccount.Strength.STRONG
## The names screens show (`display_name` metadata), as in the mockup.
const SHOWN: Dictionary[String, String] = {
	"Jack": "OFFICE-JACK",
	"OfficeSwitch": "SW-OFFICE",
	"OfficePc": "OFFICE-PC",
	"Rtr01": "RTR-01",
	"SecuritySwitch": "SW-SECURITY",
	"Console": "SEC-CONSOLE",
	"Camera": "CAM-GATE",
	"Alarm": "ALARM",
	"Rtr02": "RTR-02",
	"ServerSwitch": "SW-SERVERS",
	"FileServer": "FILE-SERVER",
	"Kiosk": "KIOSK",
}


## A device entity on a StaticBody3D root (a 0.4 m box collider, so a crosshair can target it) under
## `parent` at `position`, with `receptrons`, a Device and optionally a Powered and a Breakable.
static func body_device(
	parent: Node,
	entity_name: String,
	position: Vector3,
	receptrons: Array[Receptron] = [],
	powered: bool = false,
	health: float = 0.0,
) -> StaticBody3D:
	var root := StaticBody3D.new()
	root.collision_mask = 0
	var collision := CollisionShape3D.new()
	collision.name = "Collision"
	var box := BoxShape3D.new()
	box.size = Vector3.ONE * 0.4
	collision.shape = box
	root.add_child(collision)
	var mesh := MeshInstance3D.new()
	mesh.name = "Mesh"
	var cube := BoxMesh.new()
	cube.size = Vector3.ONE * 0.4
	mesh.mesh = cube
	root.add_child(mesh)
	if powered:
		var power := Powered.new()
		power.name = "Powered"
		root.add_child(power)
	if health > 0.0:
		var breakable := Breakable.new()
		breakable.name = "Breakable"
		breakable.break_on_depleted = false
		root.add_child(breakable)
	var component := Device.new()
	component.name = "Device"
	root.add_child(component)
	var entity := Fixtures.compose(root, parent, entity_name, position, receptrons) as StaticBody3D
	if health > 0.0:
		(entity.get_node("Attributes") as Attributes).attribute_set.set_base(Breakable.HEALTH, health)
	return entity


## A shipped scene instance under `parent` at `position`, its Device on `subnet` at `address`.
static func instance(
	parent: Node, scene: PackedScene, entity_name: String, position: Vector3, subnet: StringName, address: String
) -> Node3D:
	var entity := scene.instantiate() as Node3D
	entity.name = entity_name
	entity.position = position
	var device := Device.of(entity)
	device.subnet = subnet
	device.address = address
	parent.add_child(entity)
	return entity


## Gives `entity` its accounts: each [user, password, strength, admin].
static func add_accounts(entity: Node, accounts: Array) -> DeviceAccounts:
	var component := DeviceAccounts.of(entity)
	var fresh := component == null
	if fresh:
		component = DeviceAccounts.new()
		component.name = "DeviceAccounts"
	var list: Array[DeviceAccount] = []
	for each: Array in accounts:
		var account := DeviceAccount.new()
		account.user = str(each[0])
		account.password = str(each[1])
		account.strength = int(each[2]) as DeviceAccount.Strength
		account.admin = bool(each[3]) if each.size() > 3 else false
		list.append(account)
	component.accounts = list
	if fresh:
		entity.add_child(component)
	return component


## A Tracer on `entity` watching `watched`.
static func add_tracer(entity: Node, label: String, watched: Array[StringName], config: TracerConfig = null) -> Tracer:
	var tracer := Tracer.new()
	tracer.name = "Tracer"
	tracer.label = label
	tracer.watched = watched
	tracer.config = config
	entity.add_child(tracer)
	return tracer


## A Computer component on `entity`.
static func add_computer(entity: Node) -> Computer:
	var computer := Computer.new()
	computer.name = "Computer"
	computer.config = load("res://objects/computer/computer.tres") as ComputerConfig
	computer.label = "computer"
	entity.add_child(computer)
	return computer


## Cables `a` to `b`.
static func link(a: Node3D, b: Node3D) -> void:
	Devices.link(a, b)


## The lab network (see the class description) under `parent`, by entity name.
static func lab(parent: Node, origin: Vector3) -> Dictionary[String, Node3D]:
	var n: Dictionary[String, Node3D] = {}
	n["Jack"] = instance(parent, JACK, "Jack", origin + Vector3(0, 0.5, 0), &"office", "10.0.10.40")
	n["OfficeSwitch"] = instance(parent, SWITCH, "OfficeSwitch", origin + Vector3(2, 1.2, 0), &"office", "10.0.10.2")
	n["OfficePc"] = body_device(parent, "OfficePc", origin + Vector3(2, 1, 3))
	_address(n["OfficePc"], &"", "10.0.10.12")
	add_computer(n["OfficePc"])
	add_accounts(n["OfficePc"], [["kbrandt", "ferry19", WEAK]])
	n["Rtr01"] = instance(parent, ROUTER, "Rtr01", origin + Vector3(5, 1.2, 0), &"office", "10.0.10.1")
	add_accounts(n["Rtr01"], [["admin", "Gh7vQx2e", MEDIUM, true]])
	add_tracer(n["Rtr01"], "Sentry tracer", [&"office", &"security"])
	n["SecuritySwitch"] = instance(
		parent, SWITCH, "SecuritySwitch", origin + Vector3(8, 1.2, 0), &"security", "10.0.20.2"
	)
	n["Console"] = body_device(parent, "Console", origin + Vector3(7, 1, 3))
	_address(n["Console"], &"", "10.0.20.5")
	add_computer(n["Console"])
	add_accounts(n["Console"], [["dmarsh", "harbor77", MEDIUM]])
	var camera_receptrons: Array[Receptron] = [
		Devices.action_receptron(Device.DISABLE), Devices.action_receptron(Device.ENABLE)
	]
	n["Camera"] = body_device(parent, "Camera", origin + Vector3(9, 2.5, 3), camera_receptrons)
	_address(n["Camera"], &"", "10.0.20.21")
	var switch := DeviceSwitch.new()
	switch.name = "DeviceSwitch"
	n["Camera"].add_child(switch)
	ActorState.set_tag(n["Camera"], &"object.camera", true)
	var alarm_receptrons: Array[Receptron] = [Devices.command_receptron(Device.INCIDENT, [Fixtures.add_tag(ALARMED)])]
	n["Alarm"] = body_device(parent, "Alarm", origin + Vector3(10, 1.5, 1), alarm_receptrons)
	_address(n["Alarm"], &"", "10.0.20.40")
	n["Rtr02"] = instance(parent, ROUTER, "Rtr02", origin + Vector3(8, 1.2, -3), &"security", "10.0.20.1")
	add_accounts(n["Rtr02"], [["admin", "k3epOut9", MEDIUM, true]])
	n["ServerSwitch"] = instance(parent, SWITCH, "ServerSwitch", origin + Vector3(11, 1.2, -3), &"servers", "10.0.30.2")
	n["FileServer"] = body_device(parent, "FileServer", origin + Vector3(12, 1, -5))
	_address(n["FileServer"], &"", "10.0.30.8")
	add_accounts(n["FileServer"], [["hale", "Riverside#1", STRONG]])
	n["Kiosk"] = body_device(parent, "Kiosk", origin + Vector3(0, 1, 4))
	_address(n["Kiosk"], &"", "10.0.40.9")
	add_accounts(n["Kiosk"], [["service", "kiosk1", WEAK]])
	link(n["Jack"], n["OfficeSwitch"])
	link(n["OfficeSwitch"], n["OfficePc"])
	link(n["OfficeSwitch"], n["Rtr01"])
	link(n["Rtr01"], n["SecuritySwitch"])
	link(n["SecuritySwitch"], n["Console"])
	link(n["SecuritySwitch"], n["Camera"])
	link(n["SecuritySwitch"], n["Alarm"])
	link(n["SecuritySwitch"], n["Rtr02"])
	link(n["Rtr02"], n["ServerSwitch"])
	link(n["ServerSwitch"], n["FileServer"])
	var camera := Device.of(n["Camera"])
	camera.trusted.append(camera.get_path_to(n["Console"]))
	for entity_name: String in SHOWN:
		n[entity_name].set_meta(&"display_name", SHOWN[entity_name])
	for entity_name: String in ["OfficePc", "Console"]:
		Computer.of(n[entity_name]).host_name = SHOWN[entity_name]
	return n


## A user entity (Node3D with Tags, Attributes, a PersonalLog, a DeckSession and an
## IcebreakerTool) under `parent` at `position`, its Computer skill attributes at `tier`
## (0 Untrained .. 3 Master: crack time, trace gain, strongest password, assist).
static func user(parent: Node, position: Vector3, tier: int = 0) -> Node3D:
	var root := Node3D.new()
	var reader_log := PersonalLog.new()
	reader_log.name = "PersonalLog"
	root.add_child(reader_log)
	var session := DeckSession.new()
	session.name = "DeckSession"
	root.add_child(session)
	var ice := IcebreakerTool.new()
	ice.name = "IcebreakerTool"
	root.add_child(ice)
	var entity := Fixtures.compose(root, parent, "Hacker", position, [])
	set_tier(entity, tier)
	return entity


## Sets `entity`'s Computer skill to tier `tier`: the shipped skill table's modifiers, as the
## Skills component applies them (source `skill.computer`).
static func set_tier(entity: Node, tier: int) -> void:
	var attribute_set := (entity.get_node("Attributes") as Attributes).attribute_set
	attribute_set.remove_by_source(&"skill.computer")
	var table := load("res://actors/common/abilities/skill_table.tres") as SkillTable
	for skill in table.skills:
		if skill.id != &"computer":
			continue
		for effect in skill.effects:
			var modifier := effect.modifier_for(tier, &"skill.computer")
			if modifier != null:
				attribute_set.add_modifier(modifier)


## A deck stack (the shipped item) with an empty state.
static func deck_stack() -> ItemStack:
	return ItemStack.new(load("res://items/deck/deck.tres") as ItemData, 1, {})


static func _address(entity: Node3D, subnet: StringName, address: String) -> void:
	var device := Device.of(entity)
	device.subnet = subnet
	device.address = address
