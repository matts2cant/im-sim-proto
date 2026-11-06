@tool
class_name SurfaceFloor
extends KitPart
## A floor slab of one surface (concrete, carpet, wood, metal, grass).
## Origin: centre of the top face. The slab extends `thickness` downwards.
## To overlay a surface on an existing floor, raise it 2 cm so its collider is the one hit.

## Footprint along x and z, in metres.
@export var size := Vector2(4.0, 4.0):
	set(value):
		size = value
		rebuild()
@export_range(0.02, 10.0, 0.01, "or_greater", "suffix:m") var thickness := 0.2:
	set(value):
		thickness = value
		rebuild()
@export_enum("concrete", "carpet", "wood", "metal", "grass") var surface := "concrete":
	set(value):
		surface = value
		rebuild()


func _surface_name() -> String:
	return surface if GrayboxMaterials.is_surface(surface) else GrayboxMaterials.DEFAULT_SURFACE


func _build() -> void:
	var x := _clamped("Size x", size.x, 0.1, 500.0)
	var z := _clamped("Size z", size.y, 0.1, 500.0)
	var t := _clamped("Thickness", thickness, 0.02, 10.0)
	var material := GrayboxMaterials.for_surface(_checked_surface(surface))
	_add_box("Slab", Vector3(x, t, z), Vector3(0.0, -t * 0.5, 0.0), material)
