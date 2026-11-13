class_name StatusLight
extends Node3D
## Component (M12c readability, ADR 0115, ADR 0122, ADR 0130): a device's status light and port
## lights. Nothing in a scene asks for it: every Device attaches one to its entity (attach(), deferred
## from Device._ready). It places nothing: it drives lights the entity already has.
## - A device built from a device model (ModelFace, ADR 0130 step 2) always gets one: it drives the
##   model's own StatusLed (none when the model has none: jacks, panic buttons, lasers), writes the far
##   end's name on the socket each cable takes and lights its port light (lit() rule below), and puts
##   the device's name on the model's name plates.
## - A device without a model gets one only when its entity has a lamp (DeviceLamp) and it is on a
##   network (a cable either way, a wireless link or wireless clients, or an access point named): the
##   lamp shows the state. Otherwise it shows none (the placed LEDs, port light rows and gear plates of
##   the retired wall gear went with ADR 0130 step 3).
## - The state (one colour language): green steady = up and on its network; amber blinking = powered
##   but cut off (none of the network gear it is linked to is up: its switch, router or access point;
##   a device linked to no gear: none of its links is up; an access point named but out of range);
##   red = broken but powered, or switched off by a command (DeviceStatus.is_disabled()); dark =
##   unpowered (or gone with its entity); amber blinking too while its wireless link is jammed
##   (JAMMED, M14b: the frame and the Map say "Jammed"). The rule lives in NetworkState (the frame and
##   the Map read it too). A jamming field starting or ending refreshes every light (refresh_all()).
## - One light per device (ADR 0122 amendment 2): a model LED lent to the entity's DeviceLamp (a
##   camera's watch lamp, a door controller's lock lights) shows the lamp's colours; the state goes to
##   the lamp instead (DeviceLamp.show_network(): dark, amber blinking when cut off, else the owner's
##   colours).
## - Port lights: one per socket of the model's port rows, green while the device is up and the
##   device at the other end of the cable in that socket is up, dark otherwise.
## - Cheap: refreshed on the device's and its links' signals (state, power, breakage, commands), never
##   per frame; the blink is the shader's (status_light.gdshader, per-instance colour and blink).
## Links are read once when attached (cables are level data).

enum State { UP, CUT_OFF, DISABLED, DARK, JAMMED }

const NODE_NAME: StringName = &"StatusLight"
const COLORS: Dictionary[State, Color] = {
	State.UP: Color(0.15, 1.0, 0.3),
	State.CUT_OFF: Color(1.0, 0.62, 0.05),
	State.DISABLED: Color(1.0, 0.12, 0.08),
	State.DARK: Color(0.06, 0.07, 0.06),
	State.JAMMED: Color(1.0, 0.62, 0.05),
}
const PORT_ON: Color = Color(0.15, 1.0, 0.3)

var device: Device
var state: State = State.DARK
## The devices this one is linked to: cables both ways, its access point, its wireless clients.
var links: Array[Device] = []
## The far ends of its cabled links (a model's sockets; empty without a model).
var ports: Array[Device] = []
## Built from a device model (ModelFace): it drives the model's own lights.
var model: bool = false
## The model's status lights it drives (its StatusLed meshes not lent to the lamp).
var model_leds: Array[MeshInstance3D] = []
## The entity's own lamp (DeviceLamp), or null.
var lamp: DeviceLamp
var port_lights: Array[MeshInstance3D] = []


## Attaches a StatusLight to `device`'s entity when it has a model, or a lamp and a network; returns
## it (null: nothing to show it on, gone, or not a 3D entity). Idempotent.
static func attach(device: Device) -> StatusLight:
	if device == null or not is_instance_valid(device) or not device.is_inside_tree():
		return null
	var entity := device.entity
	if not is_instance_valid(entity) or entity.is_queued_for_deletion():
		return null
	var existing := of(entity)
	if existing != null:
		return existing
	var found := NetworkState.links_of(device)
	var model := ModelFace.has_model(entity)
	if not model:
		if DeviceLamp.of(entity) == null or (found.is_empty() and device.wireless.is_empty()):
			return null
	var light := StatusLight.new()
	light.name = NODE_NAME
	light.device = device
	light.links = found
	light.model = model
	entity.add_child(light)
	return light


## The StatusLight of `node` (an entity or its Device), or null.
static func of(node: Node) -> StatusLight:
	if node == null or not is_instance_valid(node):
		return null
	var holder := node
	if node is Device and is_instance_valid((node as Device).entity):
		holder = (node as Device).entity
	return holder.get_node_or_null(NodePath(String(NODE_NAME))) as StatusLight


## True for the states that blink (cut off, jammed).
static func blinks(value: State) -> bool:
	return value == State.CUT_OFF or value == State.JAMMED


## Refreshes the light of every device in `tree` (a change no device signals: a jamming field).
static func refresh_all(tree: SceneTree) -> void:
	for device in Device.all(tree):
		var light := StatusLight.of(device)
		if light != null:
			light.refresh()


func _ready() -> void:
	if device == null:
		device = Device.of(get_parent())
	if device == null:
		return
	if links.is_empty():
		links = NetworkState.links_of(device)
	if not model:
		model = ModelFace.has_model(device.entity)
	if model:
		ports = DeviceNetwork.cabled(device)
	lamp = DeviceLamp.of(device.entity)
	if lamp != null:
		lamp.lamps_changed.connect(_sync_lamp)
	if model:
		_build_model()
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


func _notification(what: int) -> void:
	# The lamp goes back to its owner's colours.
	if what == NOTIFICATION_PREDELETE and is_instance_valid(lamp):
		lamp.show_network(DeviceLamp.NO_NETWORK)


## Reads the state again and repaints the model's light, the lamp and the port lights.
func refresh() -> void:
	state = NetworkState.state_of(device, links)
	for mesh in model_leds:
		if is_instance_valid(mesh):
			_paint(mesh, COLORS[state], blinks(state))
	if is_instance_valid(lamp):
		lamp.show_network(state)
	var lit := port_states()
	for i in mini(port_lights.size(), lit.size()):
		if is_instance_valid(port_lights[i]):
			_paint(port_lights[i], PORT_ON if lit[i] else COLORS[State.DARK], false)


## For each port light (cable order): lit (the gear and the far end both up).
func port_states() -> Array[bool]:
	var lit: Array[bool] = []
	var gear_up := device != null and is_instance_valid(device) and device.is_up()
	for other in ports:
		lit.append(gear_up and is_instance_valid(other) and other.is_up())
	return lit


## The meshes that show the device's state: its model's own lights and its lamp's meshes.
func indicators() -> Array[MeshInstance3D]:
	var result: Array[MeshInstance3D] = []
	for mesh in model_leds:
		if is_instance_valid(mesh):
			result.append(mesh)
	if _uses_lamp():
		result.append_array(lamp.meshes())
	return result


func _on_link_changed(_up: bool) -> void:
	refresh()


func _uses_lamp() -> bool:
	return is_instance_valid(lamp) and lamp.has_lamps()


# The lamp gained or lost its meshes: a model's lent LEDs change hands.
func _sync_lamp() -> void:
	if device == null or not is_instance_valid(device) or not is_instance_valid(device.entity):
		return
	if model:
		model_leds = _model_leds()
	refresh()


# A command's effect lands in the component's own handler of the same signal: read it after.
func _refresh_later() -> void:
	refresh.call_deferred()


# A device built from a model (ModelFace): its name on the plates, the far ends' names on the
# sockets, and the model's own status lights (none when the model has none).
func _build_model() -> void:
	ModelFace.name_plates(device)
	var rows := ModelFace.rows(device.entity)
	if not rows.is_empty():
		port_lights = ModelFace.label_rows(rows, ports)
	model_leds = _model_leds()


# The model's StatusLed meshes, but those the entity's lamp (DeviceLamp) shows its own colours on.
func _model_leds() -> Array[MeshInstance3D]:
	var found: Array[MeshInstance3D] = []
	var lent: Array[MeshInstance3D] = []
	if is_instance_valid(lamp):
		lent = lamp.meshes()
	for part in ModelFace.leds(device.entity):
		if is_instance_valid(part.led) and not lent.has(part.led):
			found.append(part.led)
	return found


static func _paint(instance: MeshInstance3D, color: Color, blinking: bool) -> void:
	if instance == null:
		return
	instance.set_instance_shader_parameter(&"led_color", color)
	instance.set_instance_shader_parameter(&"blink", 1.0 if blinking else 0.0)
