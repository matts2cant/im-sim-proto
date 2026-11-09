class_name MuzzleFlash
extends MeshInstance3D
## Placeholder muzzle flash of a ranged weapon (ADR 0070), a child of WeaponHolder's view model: a
## bright unshaded box of WeaponData.muzzle_flash_size (through the weapon's attachments: a silencer
## hides it, ADR 0085) at the front of the box or at the model's muzzle, with a short-range light,
## shown for TIME on each shot (none when the size is 0). The light is a real OmniLight3D, so
## LightExposure counts it: a firing guard lights itself up for a moment.

## Seconds a flash stays visible.
const TIME: float = 0.06
const LIGHT_ENERGY: float = 2.0
## Light range (m).
const LIGHT_RANGE: float = 4.0

var light: OmniLight3D
## Distance (m) from the parent's origin to the muzzle along -Z: 0 at a model's muzzle marker; < 0:
## the front of the placeholder box (half of WeaponData.view_size.z).
var front: float = -1.0

var _left: float = 0.0
var _held: bool = false


func _ready() -> void:
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color(1.0, 0.85, 0.4)
	material_override = material
	mesh = BoxMesh.new()
	light = OmniLight3D.new()
	light.name = "Light"
	light.light_color = Color(1.0, 0.8, 0.5)
	light.light_energy = LIGHT_ENERGY
	light.omni_range = LIGHT_RANGE
	add_child(light)
	visible = false


## A shot of `data`: shows a flash of `size` (< 0: the weapon's muzzle_flash_size) at its muzzle
## for TIME.
func fire(data: WeaponData, size: float = -1.0) -> void:
	_held = false
	var edge := data.muzzle_flash_size if size < 0.0 else size
	if data.is_melee() or edge <= 0.0:
		return
	(mesh as BoxMesh).size = Vector3.ONE * edge
	var muzzle := data.view_size.z * 0.5 if front < 0.0 else front
	position = Vector3(0, 0, -muzzle - edge * 0.5)
	visible = true
	_left = TIME


## Keeps the flash of `data` on until the next shot or clear() (screenshots).
func hold(data: WeaponData, size: float = -1.0) -> void:
	fire(data, size)
	_held = visible


func clear() -> void:
	_left = 0.0
	_held = false
	visible = false


func step(delta: float) -> void:
	if not visible or _held:
		return
	_left -= delta
	if _left <= 0.0:
		clear()
