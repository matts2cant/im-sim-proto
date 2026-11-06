@tool
class_name GrayboxMaterials
extends RefCounted
## Graybox grid materials (assets/materials/graybox/) and the floor surfaces they stand for.
## A surface name is both the footstep surface (`surface` metadata, ADR 0033) and a material.

const DIR := "res://assets/materials/graybox/"
## Floor surfaces known to the footstep table (actors/common/movement/surface_table.tres).
const SURFACES: PackedStringArray = ["concrete", "carpet", "wood", "metal", "grass"]
const DEFAULT_SURFACE := "concrete"
const WALL := "wall"
const CEILING := "ceiling"
const HAZARD := "hazard"
const INTERACTIVE := "interactive"


static func is_surface(surface: String) -> bool:
	return SURFACES.has(surface)


## Material of a floor surface; unknown names fall back to concrete.
static func for_surface(surface: String) -> Material:
	return named(surface if is_surface(surface) else DEFAULT_SURFACE)


## Any graybox material by file name: a surface, "wall", "ceiling", "hazard" or "interactive".
static func named(material_name: String) -> Material:
	return load(DIR + material_name + ".tres") as Material
