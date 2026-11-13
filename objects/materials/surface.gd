@tool
class_name Surface
extends RefCounted
## The one place that says what a collider's surface is made of (ADR 0138), read by footsteps
## (SurfaceTable, MovementNoise) and bullet impacts (ShotFxConfig):
## 1. static geometry: the collider's `wall_surface` metadata on a face that is not a floor (a kit
##    Room's walls and ceiling over its floor), else its `surface` metadata (kit parts, ADR 0033;
##    for CSG the root with use_collision);
## 2. entities: the `material.*` tag of the collider's nearest ancestor (or itself) with Tags
##    (`material.metal` -> `metal`; a metal crate, a wooden door);
## 3. else &"" (each reader falls back to its default).
## Surface names are plain words (`concrete`, `metal`, `wood`, `carpet`, `grass`, `glass`,
## `cardboard`, `electronics`); each reader maps them to its own data (footstep sounds, impact looks).

## Metadata of a collider's surface (its floor's, for a kit Room).
const META: StringName = &"surface"
## Metadata of the material a collider's walls are made of, when it differs from its floor's.
const WALL_META: StringName = &"wall_surface"
## The parent tag of the material tags (`material.metal`).
const MATERIAL_TAG: StringName = &"material"
## A face whose normal points up more than this (cosine) is a floor; any other face reads
## WALL_META when the collider has it.
const FLOOR_MIN_UP: float = 0.7


## The surface name of `collider` hit on a face with `normal` (a floor by default), or &"".
static func of(collider: Object, normal: Vector3 = Vector3.UP) -> StringName:
	if collider == null or not is_instance_valid(collider):
		return &""
	if collider.has_meta(WALL_META) and normal.normalized().y < FLOOR_MIN_UP:
		return StringName(str(collider.get_meta(WALL_META)))
	if collider.has_meta(META):
		return StringName(str(collider.get_meta(META)))
	if collider is Node:
		var tags := tags_above(collider as Node)
		if tags != null:
			return of_tags(tags.container)
	return &""


## The surface name a tag set gives: the first `material.*` tag's first level (`material.metal.steel`
## -> `metal`), or &"".
static func of_tags(tags: TagContainer) -> StringName:
	var prefix := String(MATERIAL_TAG) + "."
	for tag in tags.tags():
		var text := String(tag)
		if text.begins_with(prefix):
			return StringName(text.substr(prefix.length()).get_slice(".", 0))
	return &""


## The Tags of `node` or of its nearest ancestor that has them (a prop's collider may be a child of
## the entity), or null.
static func tags_above(node: Node) -> Tags:
	while node != null:
		var found := node.get_node_or_null(^"Tags") as Tags
		if found != null:
			return found
		node = node.get_parent()
	return null
