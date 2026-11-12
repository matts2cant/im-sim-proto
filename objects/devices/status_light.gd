class_name StatusLight
extends Node3D
## Component (M12c readability, ADR 0115, ADR 0122): a networked device's status LED, and on network
## gear (DeviceNetwork.is_network_gear()) a row of port lights. Nothing in a scene asks for it: every
## Device attaches one to its entity (attach(), deferred from Device._ready) when the device is on a
## network (it has a cable either way, a wireless link or wireless clients, or names an access
## point); a standalone device shows none. Gear also gets its plate (GearPlate).
## - The LED (one colour language): green steady = up and on its network; amber blinking = powered
##   but cut off (none of the network gear it is linked to is up: its switch, router or access point;
##   a device linked to no gear: none of its links is up; an access point named but out of range);
##   red = broken but powered, or switched off by a command (DeviceStatus.is_disabled()); dark =
##   unpowered (or gone with its entity).
## - Port lights: one per cabled link (up to MAX_PORTS, then a "+"), green while the gear is up and
##   the device at the other end is up, dark otherwise.
## - Placement: a child Marker3D of the entity named LED_MARKER / PORTS_MARKER (its +Z faces out),
##   else the top-front of the entity's visible bounds (+Z is the front, as wall-mounted devices are
##   built), the LED near the left edge and the ports centred below it.
## - Cheap: refreshed on the device's and its links' signals (state, power, breakage, commands), never
##   per frame; the blink is the shader's (status_light.gdshader, per-instance colour and blink).
## Links are read once when attached (cables are level data).

enum State { UP, CUT_OFF, DISABLED, DARK }

const NODE_NAME: StringName = &"StatusLight"
## Optional markers on the entity.
const LED_MARKER: NodePath = ^"StatusLedMarker"
const PORTS_MARKER: NodePath = ^"PortLightsMarker"
const MAX_PORTS: int = 8
const COLORS: Dictionary[State, Color] = {
	State.UP: Color(0.15, 1.0, 0.3),
	State.CUT_OFF: Color(1.0, 0.62, 0.05),
	State.DISABLED: Color(1.0, 0.12, 0.08),
	State.DARK: Color(0.06, 0.07, 0.06),
}
const PORT_ON: Color = Color(0.15, 1.0, 0.3)
## The LED (24 mm) and port light (14 mm) boxes, with the shared status_light.gdshader material.
const LED_MESH: Mesh = preload("res://objects/devices/status_light_led.tres")
const PORT_MESH: Mesh = preload("res://objects/devices/status_light_port.tres")
const PORT_PITCH: float = 0.024
## From the top edge to the LED's centre, and from the LED down to the port row (m).
const TOP_INSET: float = 0.025
const ROW_DROP: float = 0.035
## Out of the front face (m).
const FRONT_OFFSET: float = 0.003

var device: Device
var state: State = State.DARK
## The devices this one is linked to: cables both ways, its access point, its wireless clients.
var links: Array[Device] = []
## The far ends of its cabled links (network gear only; empty otherwise).
var ports: Array[Device] = []
var led: MeshInstance3D
var port_lights: Array[MeshInstance3D] = []
## "+" past MAX_PORTS cabled links (null otherwise).
var more: Label3D
## The entity's visible bounds in its own frame, before the light was added.
var bounds: AABB = AABB()


## Attaches a StatusLight (and a GearPlate on network gear) to `device`'s entity when the device is
## on a network; returns it (null: standalone, gone, or not a 3D entity). Idempotent.
static func attach(device: Device) -> StatusLight:
	if device == null or not is_instance_valid(device) or not device.is_inside_tree():
		return null
	var entity := device.entity
	if not is_instance_valid(entity) or entity.is_queued_for_deletion():
		return null
	var existing := of(entity)
	if existing != null:
		return existing
	var found := links_of(device)
	if found.is_empty() and device.wireless.is_empty():
		return null
	var light := StatusLight.new()
	light.name = NODE_NAME
	light.device = device
	light.links = found
	light.bounds = local_bounds(entity)
	entity.add_child(light)
	if DeviceNetwork.is_network_gear(device):
		GearPlate.attach(device, light.bounds)
	return light


## The StatusLight of `node` (an entity or its Device), or null.
static func of(node: Node) -> StatusLight:
	if node == null or not is_instance_valid(node):
		return null
	var holder := node
	if node is Device and is_instance_valid((node as Device).entity):
		holder = (node as Device).entity
	return holder.get_node_or_null(NodePath(String(NODE_NAME))) as StatusLight


## The devices `device` is linked to: cables both ways, the access point it links to by radio, and
## (an access point) the devices linked to it by radio.
static func links_of(device: Device) -> Array[Device]:
	var found := DeviceNetwork.cabled(device)
	var radio := device.wireless_link()
	if radio != null and not found.has(radio):
		found.append(radio)
	if AccessPoint.of(device) != null:
		for other in DeviceNetwork.wireless_devices(device):
			if not found.has(other):
				found.append(other)
	return found


## The LED state of `device` linked to `p_links` (see the class description).
static func state_of(p_device: Device, p_links: Array[Device]) -> State:
	if p_device == null or not is_instance_valid(p_device) or not is_instance_valid(p_device.entity):
		return State.DARK
	if not p_device.is_powered():
		return State.DARK
	if p_device.broken or DeviceStatus.is_disabled(p_device.entity):
		return State.DISABLED
	return State.UP if on_network(p_device, p_links) else State.CUT_OFF


## True when `p_device` still has its network: one of the gear it is linked to is up (linked to no
## gear: one of its links is up). Linked to nothing: true, unless it names an access point.
static func on_network(p_device: Device, p_links: Array[Device]) -> bool:
	var live: Array[Device] = []
	for other in p_links:
		if is_instance_valid(other):
			live.append(other)
	if live.is_empty():
		return p_device.wireless.is_empty()
	var gear_linked := false
	var any_up := false
	for other in live:
		var up := other.is_up()
		if DeviceNetwork.is_network_gear(other):
			if up:
				return true
			gear_linked = true
		elif up:
			any_up = true
	return any_up and not gear_linked


## `entity`'s visible geometry (meshes, labels) boxed in its own frame; a 0.2 m cube without any.
static func local_bounds(entity: Node3D) -> AABB:
	var to_local := entity.global_transform.affine_inverse()
	var result := AABB()
	var first := true
	for node in entity.find_children("*", "GeometryInstance3D", true, false):
		var part := node as GeometryInstance3D
		if not part.visible:
			continue
		var box := to_local * part.global_transform * part.get_aabb()
		result = box if first else result.merge(box)
		first = false
	return result if not first else AABB(Vector3.ONE * -0.1, Vector3.ONE * 0.2)


func _ready() -> void:
	if device == null:
		device = Device.of(get_parent())
	if device == null:
		return
	if links.is_empty():
		links = links_of(device)
	if DeviceNetwork.is_network_gear(device):
		ports = DeviceNetwork.cabled(device)
	_build()
	device.state_changed.connect(refresh.unbind(1))
	device.action_received.connect(_refresh_later.unbind(2))
	if device.powered != null:
		device.powered.power_changed.connect(refresh.unbind(1))
	if device.breakable != null:
		device.breakable.depleted.connect(refresh.unbind(1))
	for other in links + ports:
		if is_instance_valid(other) and not other.state_changed.is_connected(_on_link_changed):
			other.state_changed.connect(_on_link_changed)
	refresh()


## Reads the state again and repaints the LED and the port lights.
func refresh() -> void:
	state = state_of(device, links)
	_paint(led, COLORS[state], state == State.CUT_OFF)
	var lit := port_states()
	for i in port_lights.size():
		_paint(port_lights[i], PORT_ON if lit[i] else COLORS[State.DARK], false)


## For each port light (cable order): lit (the gear and the far end both up).
func port_states() -> Array[bool]:
	var lit: Array[bool] = []
	var gear_up := device != null and is_instance_valid(device) and device.is_up()
	for i in mini(ports.size(), MAX_PORTS):
		var other := ports[i]
		lit.append(gear_up and is_instance_valid(other) and other.is_up())
	return lit


func _on_link_changed(_up: bool) -> void:
	refresh()


# A command's effect lands in the component's own handler of the same signal: read it after.
func _refresh_later() -> void:
	refresh.call_deferred()


func _build() -> void:
	var front := bounds.end.z + FRONT_OFFSET
	var top := bounds.end.y - minf(TOP_INSET, bounds.size.y * 0.5)
	var left := bounds.position.x + minf(0.03, bounds.size.x * 0.5)
	var led_at := _marker(LED_MARKER, Transform3D(Basis.IDENTITY, Vector3(left, top, front)))
	led = _light(LED_MESH, led_at, "Led")
	if ports.is_empty():
		return
	var row_default := Vector3(bounds.get_center().x, top - ROW_DROP, front)
	var row := _marker(PORTS_MARKER, Transform3D(Basis.IDENTITY, row_default))
	var count := mini(ports.size(), MAX_PORTS)
	for i in count:
		var along := (float(i) - float(count - 1) * 0.5) * PORT_PITCH
		port_lights.append(_light(PORT_MESH, row * Transform3D(Basis.IDENTITY, Vector3(along, 0.0, 0.0)), "Port%d" % i))
	if ports.size() > MAX_PORTS:
		more = Label3D.new()
		more.name = "More"
		more.text = "+"
		more.font_size = 24
		more.pixel_size = 0.001
		more.outline_size = 4
		more.modulate = PORT_ON
		more.transform = row * Transform3D(Basis.IDENTITY, Vector3((float(count) * 0.5 + 0.4) * PORT_PITCH, 0.0, 0.0))
		add_child(more)


# The transform of the marker `path` in the entity's frame, else `fallback`.
func _marker(path: NodePath, fallback: Transform3D) -> Transform3D:
	var entity := device.entity
	var marker := entity.get_node_or_null(path) as Node3D
	if marker == null:
		return fallback
	return entity.global_transform.affine_inverse() * marker.global_transform


func _light(mesh: Mesh, at: Transform3D, node_name: String) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.mesh = mesh
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	instance.transform = at
	add_child(instance)
	return instance


static func _paint(instance: MeshInstance3D, color: Color, blinking: bool) -> void:
	if instance == null:
		return
	instance.set_instance_shader_parameter(&"led_color", color)
	instance.set_instance_shader_parameter(&"blink", 1.0 if blinking else 0.0)
