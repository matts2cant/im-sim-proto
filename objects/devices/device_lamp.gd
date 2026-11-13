class_name DeviceLamp
extends Node
## Component (M13 one light, ADR 0122 amendment 2): a device's own lamp, a light that already means
## something (a camera's watch lamp, a door's lock light on its wall boxes). A device has one light:
## when its entity has a DeviceLamp with at least one lamp mesh, its StatusLight adds no LED and
## shows the network state on the lamp instead. The owner (any component) sets its own colour with
## show_own(); the StatusLight sets the network state with show_network(); the lamp shows, by
## priority:
##   1. dark: unpowered, or switched off by a command or broken (StatusLight DARK or DISABLED);
##   2. blinking amber: cut off from its network (CUT_OFF; the only blinking state);
##   3. otherwise the owner's colour (dark while the owner says it is unlit).
## Without a StatusLight (a device on no network) it shows the owner's colour alone.
## Lamp meshes come from `lamps` (paths to meshes, or to a device model's StatusLed: its LED, ADR 0130
## step 2: the camera's lamp) and set_meshes() (hardware built in code); each gets the
## shared status light material (status_light.gdshader), so a lamp looks and blinks like the LED.
## Cheap: repainted only when a colour or state changes, never per frame.

signal lamps_changed

## No StatusLight drives the lamp (show_network() not called, or released).
const NO_NETWORK: int = -1
const MATERIAL: Material = preload("res://objects/devices/status_light_material.tres")

## Lamp meshes (MeshInstance3D) of the entity.
@export var lamps: Array[NodePath] = []
@export var entity_path: NodePath = ^".."

var entity: Node
## The owner's colour and whether it is lit (show_own()).
var own_color: Color = StatusLight.COLORS[StatusLight.State.DARK]
var own_lit: bool = false
## The StatusLight's state (StatusLight.State), or NO_NETWORK.
var network: int = NO_NETWORK

var _meshes: Array[MeshInstance3D] = []


func _ready() -> void:
	entity = get_node_or_null(entity_path)
	if lamps.is_empty():
		_paint()
		return
	# Keeps the meshes an owner registered before this node was ready.
	var found := _meshes.duplicate()
	for path in lamps:
		var node := get_node_or_null(path)
		# A device model's StatusLed lends its built LED (it is ready first: the model comes before
		# this node in the scene).
		var mesh := (node as StatusLed).led if node is StatusLed else node as MeshInstance3D
		if mesh != null and not found.has(mesh):
			found.append(mesh)
	set_meshes(found)


## The DeviceLamp of `node` (an entity, or its Device), or null.
static func of(node: Node) -> DeviceLamp:
	if node == null or not is_instance_valid(node):
		return null
	var holder := node
	if node is Device and is_instance_valid((node as Device).entity):
		holder = (node as Device).entity
	for child in holder.get_children():
		if child is DeviceLamp:
			return child as DeviceLamp
	return null


## True when it has a lamp mesh to show (the device then shows no LED).
func has_lamps() -> bool:
	for mesh in _meshes:
		if is_instance_valid(mesh):
			return true
	return false


## Its lamp meshes (freed ones left out).
func meshes() -> Array[MeshInstance3D]:
	var result: Array[MeshInstance3D] = []
	for mesh in _meshes:
		if is_instance_valid(mesh):
			result.append(mesh)
	return result


## Replaces the lamp meshes (hardware rebuilt in code); tells the StatusLight (lamps_changed).
func set_meshes(p_meshes: Array[MeshInstance3D]) -> void:
	_meshes = p_meshes.duplicate()
	for mesh in _meshes:
		if is_instance_valid(mesh):
			mesh.material_override = MATERIAL
			mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_paint()
	lamps_changed.emit()


## The owner's colour; `lit` false: dark.
func show_own(color: Color, lit: bool) -> void:
	if color == own_color and lit == own_lit:
		return
	own_color = color
	own_lit = lit
	_paint()


## The network state (a StatusLight.State; NO_NETWORK: none, the owner's colour alone).
func show_network(state: int) -> void:
	if state == network:
		return
	network = state
	_paint()


## The colour the lamps show now (see the class description).
func color() -> Color:
	match network:
		StatusLight.State.DARK, StatusLight.State.DISABLED:
			return StatusLight.COLORS[StatusLight.State.DARK]
		StatusLight.State.CUT_OFF:
			return StatusLight.COLORS[StatusLight.State.CUT_OFF]
	return own_color if own_lit else StatusLight.COLORS[StatusLight.State.DARK]


## True while the lamps blink (cut off from the network).
func blinking() -> bool:
	return network == StatusLight.State.CUT_OFF


func _paint() -> void:
	var shown := color()
	var blink := 1.0 if blinking() else 0.0
	for mesh in _meshes:
		if is_instance_valid(mesh):
			mesh.set_instance_shader_parameter(&"led_color", shown)
			mesh.set_instance_shader_parameter(&"blink", blink)
