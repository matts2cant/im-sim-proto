extends RefCounted
## A synthetic security network for the terminal's map (ADR 0099): SWITCHES switches, each with
## devices around it on a 70 x 40 m site, COUNT devices in all (the terminal first, on the first
## switch). The first switch is cabled to every other one; two devices hang on another device (a
## chain: switch - controller - base station), so the map has a deeper column. Statuses are long
## and varied (a few offline). Rows as Terminal.devices() gives them: build() parents a Node3D entity
## per device under `parent`; the Device nodes stay out of the tree (free() frees them).

const COUNT := 60
const SWITCHES := 4
const KINDS: Array[String] = [
	"Camera", "Siren", "Laser", "Door", "Turret", "Panic Button", "Alarm Controller", "Radio Base Station"
]
const PLACES: Array[String] = ["North", "South", "East", "West", "Dock", "Store", "Office", "Roof", "Yard", "Hall"]
const STATUSES: Array[PackedStringArray] = [
	["online", "enabled", "sweeping"],
	["online", "silent"],
	["online", "enabled", "clear"],
	["online", "locked", "closed"],
	["online", "enabled", "targets intruders", "idle"],
	["online"],
	["online", "armed", "silent"],
	["online", "idle"],
]

var rows: Array[Terminal.Row] = []
var cables: Array[Vector2i] = []
var _devices: Array[Device] = []


func build(parent: Node3D) -> void:
	var switch_at: Array[Vector3] = [Vector3(-20, 0, -10), Vector3(25, 0, -12), Vector3(-22, 0, 15), Vector3(20, 0, 14)]
	_add(parent, "Terminal", switch_at[0] + Vector3(2, 0, 3), ["online", "logged in"], true)
	for s in SWITCHES:
		_add(parent, "Switch %d" % (s + 1), switch_at[s], ["online"])
	for s in range(1, SWITCHES):
		cables.append(Vector2i(1, 1 + s))
	cables.append(Vector2i(0, 1))
	var members := COUNT - 1 - SWITCHES
	var per_switch := floori(float(members) / SWITCHES)
	var index := 0
	for s in SWITCHES:
		var hub := 1 + s
		var count := per_switch + (1 if s < members % SWITCHES else 0)
		for k in count:
			var kind := index % KINDS.size()
			var place := (index * 7 + s) % PLACES.size()
			var angle := float(k) / count * TAU + s
			var at := switch_at[s] + Vector3(cos(angle) * (6 + k % 4), 0, sin(angle) * (5 + k % 3))
			var status := STATUSES[kind]
			if index % 13 == 5:
				status = PackedStringArray(["offline"])
			var label := "%s %s %d" % [KINDS[kind], PLACES[place], index + 1]
			_add(parent, label, at, status)
			var node := rows.size() - 1
			# Two devices hang on the device before them instead of the switch.
			cables.append(Vector2i(node - 1 if k == 3 and s < 2 else hub, node))
			index += 1


func release() -> void:
	for device in _devices:
		if is_instance_valid(device):
			device.free()
	_devices.clear()


func _add(parent: Node3D, label: String, at: Vector3, status: PackedStringArray, is_self: bool = false) -> void:
	var entity := Node3D.new()
	entity.name = label.replace(" ", "")
	parent.add_child(entity)
	entity.global_position = at
	var device := Device.new()
	device.entity = entity
	_devices.append(device)
	var row := Terminal.Row.new()
	row.device = device
	row.name = label
	row.status = status
	row.online = not status.has("offline")
	row.is_self = is_self
	rows.append(row)
