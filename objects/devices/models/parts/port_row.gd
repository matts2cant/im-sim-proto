@tool
class_name PortRow
extends ModelPart
## A device model's row of network ports (ADR 0130): one socket per entry of `labels`, a small port
## light above each (green when it has a label, dark otherwise; the shared status light material) and
## the label naming the connected device under its socket, running vertically (read top to bottom),
## or flat under it (`flat_labels`: a wall jack). `uplink` rings one socket in the kind's colour.
## Origin: the top-left corner of the first socket on the surface; sockets run along +X, everything
## sits proud of the surface (+Z). Step 2 drives the lights from the device's cables.

const SOCKET_DEPTH: float = 0.001
const LIGHT_SIZE := Vector2(0.0022, 0.0015)
## The port light's centre above the sockets' top edge.
const LIGHT_RISE: float = 0.0034
const RING: float = 0.0012

## One socket per entry: the connected device's name, empty for a free socket.
@export var labels: PackedStringArray = PackedStringArray(["", ""]):
	set(value):
		labels = value
		rebuild()
## From one socket's left edge to the next's (m).
@export var pitch: float = 0.0128:
	set(value):
		pitch = value
		rebuild()
## Socket width and height (m); a width of 0 uses 0.78 of the pitch.
@export var socket_size: Vector2 = Vector2(0.0, 0.009):
	set(value):
		socket_size = value
		rebuild()
## The labels' em height (m).
@export var text_height: float = 0.0034:
	set(value):
		text_height = value
		rebuild()
## From the sockets' bottom edge to the labels (m).
@export var label_gap: float = 0.003:
	set(value):
		label_gap = value
		rebuild()
@export var label_color: Color = ModelStyle.LABEL_LIGHT:
	set(value):
		label_color = value
		rebuild()
@export var flat_labels: bool = false:
	set(value):
		flat_labels = value
		rebuild()
## The socket ringed in the kind's colour (a router's uplink); -1: none.
@export var uplink: int = -1:
	set(value):
		uplink = value
		rebuild()

var lights: Array[MeshInstance3D] = []
var label_nodes: Array[ModelText] = []


## The number of sockets.
func socket_count() -> int:
	return labels.size()


## Whether each port light is lit (a label names a connected device).
func lit() -> Array[bool]:
	var result: Array[bool] = []
	for text in labels:
		result.append(not text.strip_edges().is_empty())
	return result


## The socket's size after the default width.
func socket() -> Vector2:
	return Vector2(socket_size.x if socket_size.x > 0.0 else pitch * 0.78, socket_size.y)


func _build() -> void:
	lights.clear()
	label_nodes.clear()
	var sock := socket()
	var sockets: Array[AABB] = []
	for i in labels.size():
		sockets.append(AABB(Vector3(i * pitch, -sock.y, 0.0), Vector3(sock.x, sock.y, SOCKET_DEPTH)))
	_mesh("Sockets", ModelStyle.boxes_mesh(sockets, ModelStyle.SOCKET), Vector3.ZERO)
	if uplink >= 0 and uplink < labels.size():
		_ring(uplink * pitch, sock)
	var on := lit()
	var light_mesh := ModelStyle.box(Vector3(sock.x * 0.4, LIGHT_SIZE.x, LIGHT_SIZE.y), ModelStyle.STATUS_MATERIAL)
	for i in labels.size():
		var centre := i * pitch + sock.x * 0.5
		var light := _mesh("PortLight%d" % i, light_mesh, Vector3(centre, LIGHT_RISE, LIGHT_SIZE.y * 0.5))
		light.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		light.set_instance_shader_parameter(&"led_color", ModelStyle.ONLINE if on[i] else ModelStyle.DARK)
		lights.append(light)
		if on[i]:
			label_nodes.append(_label(i, centre, sock))


func _label(i: int, centre: float, sock: Vector2) -> ModelText:
	var top := -sock.y - label_gap
	var at := Transform3D(Basis.IDENTITY, Vector3(centre, top, 0.0004))
	if not flat_labels:
		# Turned clockwise (seen from the front): the text starts under the socket and reads down.
		at.basis = Basis(Vector3.BACK, -PI * 0.5)
	var label := _text("PortLabel%d" % i, labels[i].strip_edges(), text_height, label_color, at)
	if flat_labels:
		label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	else:
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	return label


# A frame of RING-wide bars around the socket at `left`, in the kind's colour.
func _ring(left: float, sock: Vector2) -> void:
	var bars: Array[AABB] = [
		AABB(Vector3(left - RING, 0.0, 0.0), Vector3(sock.x + RING * 2.0, RING, SOCKET_DEPTH)),
		AABB(Vector3(left - RING, -sock.y - RING, 0.0), Vector3(sock.x + RING * 2.0, RING, SOCKET_DEPTH)),
		AABB(Vector3(left - RING, -sock.y, 0.0), Vector3(RING, sock.y, SOCKET_DEPTH)),
		AABB(Vector3(left + sock.x, -sock.y, 0.0), Vector3(RING, sock.y, SOCKET_DEPTH)),
	]
	_mesh("UplinkRing", ModelStyle.boxes_mesh(bars, ModelStyle.kind_material(_kind_color())), Vector3.ZERO)
