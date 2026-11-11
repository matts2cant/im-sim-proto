class_name NetworkOverlay
extends Node3D
## Debug overlay (ADR 0083): the device network drawn over the world, through walls. A Label3D above
## every Device (any entity with the component) with its name and status words: DeviceStatus, the
## same query the computers use, "online" plus its components' words while the device is up, else
## "offline" and, as this is a developer view, why (unpowered, broken), then the size of its device
## log and its newest entry (M12b: logins, exploit runs, remote actions). A line along every cable
## (Device.links, each once): green while both ends are up, red otherwise. Shows every device
## whatever the player knows. Toggled by the Overlays tab's "Network" checkbox; refreshed every
## REFRESH seconds while on; off, it holds no labels, draws nothing and does not process.

## Seconds between refreshes while on.
const REFRESH: float = 0.25
## Label height above the device's origin.
const LABEL_OFFSET: Vector3 = Vector3(0, 0.45, 0)
const UP_COLOR: Color = Color(0.3, 1.0, 0.45)
const DOWN_COLOR: Color = Color(1.0, 0.25, 0.2)
const LABEL_COLOR: Color = Color(0.55, 0.9, 1.0)
const OFFLINE_LABEL_COLOR: Color = Color(0.7, 0.7, 0.7)

var enabled: bool = false:
	set = set_enabled

# Device instance id -> its label.
var _labels: Dictionary[int, Label3D] = {}
# Each cable as [Device, Device, up].
var _links: Array[Array] = []
var _lines := MeshInstance3D.new()
var _immediate := ImmediateMesh.new()
var _material := StandardMaterial3D.new()
var _refresh_left: float = 0.0


func _init() -> void:
	name = "NetworkOverlay"
	_lines.name = "Cables"
	_lines.mesh = _immediate
	_lines.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_material.vertex_color_use_as_albedo = true
	_material.no_depth_test = true
	_material.render_priority = 10
	add_child(_lines)
	set_process(false)


func set_enabled(value: bool) -> void:
	enabled = value
	set_process(enabled)
	_refresh_left = 0.0
	if enabled:
		if is_inside_tree():
			refresh()
		return
	for label: Label3D in _labels.values():
		label.queue_free()
	_labels.clear()
	_links.clear()
	_immediate.clear_surfaces()


func _process(delta: float) -> void:
	_refresh_left -= delta
	if _refresh_left <= 0.0:
		refresh()


## Reads every device and cable again.
func refresh() -> void:
	_refresh_left = REFRESH
	if not enabled or not is_inside_tree():
		return
	var devices := Device.all(get_tree())
	var seen: Dictionary[int, bool] = {}
	for device in devices:
		if not is_instance_valid(device.entity):
			continue
		var id := device.get_instance_id()
		seen[id] = true
		var label: Label3D = _labels.get(id)
		if label == null:
			label = _make_label()
			_labels[id] = label
		label.global_position = device.entity.global_position + LABEL_OFFSET
		label.text = "%s\n%s" % [Computer.display_name(device), status_text(device)]
		var last := device.intrusion.device_log.last()
		if not last.is_empty():
			label.text += "\nlog %d: %s" % [device.intrusion.device_log.size(), DeviceLog.line(last)]
		label.modulate = LABEL_COLOR if device.is_up() else OFFLINE_LABEL_COLOR
	for id: int in _labels.keys():
		if not seen.has(id):
			_labels[id].queue_free()
			_labels.erase(id)
	_links = cables(devices)
	_redraw()


## The status line of `device`: DeviceStatus words, with the reason when it is down.
static func status_text(device: Device) -> String:
	var up := device.is_up()
	var text := HalcyonStyle.status_text(DeviceStatus.of(device.entity, up))
	if up:
		return text
	var reasons := PackedStringArray()
	if not device.is_powered():
		reasons.append("unpowered")
	if device.broken:
		reasons.append("broken")
	return "%s (%s)" % [text, ", ".join(reasons)] if not reasons.is_empty() else text


## Every cable between `devices` (each once) as [Device, Device, up]; up when both ends are.
static func cables(devices: Array[Device]) -> Array[Array]:
	var found: Array[Array] = []
	var done: Dictionary[String, bool] = {}
	for device in devices:
		for other in device.linked():
			if not devices.has(other):
				continue
			var a := device.get_instance_id()
			var b := other.get_instance_id()
			var key := "%d-%d" % [mini(a, b), maxi(a, b)]
			if done.has(key):
				continue
			done[key] = true
			found.append([device, other, device.is_up() and other.is_up()])
	return found


## The label above `device`, or null.
func label_for(device: Device) -> Label3D:
	return _labels.get(device.get_instance_id())


func label_count() -> int:
	return _labels.size()


## Cables drawn now.
func cable_count() -> int:
	return _links.size()


## 1 when the cable between `a` and `b` is drawn up, 0 down, -1 when there is none.
func cable_state(a: Device, b: Device) -> int:
	for link in _links:
		if (link[0] == a and link[1] == b) or (link[0] == b and link[1] == a):
			return 1 if bool(link[2]) else 0
	return -1


## Line vertices in the mesh (two per cable).
func vertex_count() -> int:
	return _links.size() * 2 if _immediate.get_surface_count() > 0 else 0


func _redraw() -> void:
	_immediate.clear_surfaces()
	if _links.is_empty():
		return
	_immediate.surface_begin(Mesh.PRIMITIVE_LINES, _material)
	for link in _links:
		var a := link[0] as Device
		var b := link[1] as Device
		_immediate.surface_set_color(UP_COLOR if bool(link[2]) else DOWN_COLOR)
		_immediate.surface_add_vertex(a.entity.global_position)
		_immediate.surface_add_vertex(b.entity.global_position)
	_immediate.surface_end()


func _make_label() -> Label3D:
	var label := Label3D.new()
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.fixed_size = true
	label.pixel_size = 0.0008
	label.font_size = 36
	label.outline_size = 12
	label.render_priority = 11
	add_child(label)
	return label
