class_name ShotFxConfig
extends Resource
## Tuning of the shot feedback in the world (ADR 0126, `items/weapons/fx/shot_fx.tres`): which
## impact look (ImpactPuff) a hit gets by the material of what it hit, the holes' cap and fade, and
## the tracers' look. The material is data on the surface, never its name:
## - a character (a hitbox, or an entity with BodyParts): BODY;
## - the collider's `wall_surface` metadata when the hit face is not a floor (a kit Room's walls and
##   ceiling are concrete whatever its floor), else its `surface` metadata (kit parts, ADR 0033);
## - the `material.*` tags of the nearest entity above the collider with Tags (props: a crate's
##   `material.wood`, a barrel's `material.metal`);
## - else `default_group` (concrete).

const BODY: StringName = &"body"
## A stun hit on a body (a baton): a blue-white spark.
const STUN: StringName = &"stun"
const SURFACE_META: StringName = &"surface"
## Metadata of the material a collider's walls are made of, when it differs from its floor's.
const WALL_SURFACE_META: StringName = &"wall_surface"
## A face whose normal points up more than this (cosine) is a floor; any other face reads
## `wall_surface` when the collider has it.
const FLOOR_MIN_UP: float = 0.7

## Material group -> its impact look.
@export var puffs: Dictionary[StringName, ImpactPuff] = {}
## Surface name (metadata) -> material group.
@export var surfaces: Dictionary[StringName, StringName] = {}
## Tag (`material.metal`) -> material group; the first one the entity has wins, in this order.
@export var tags: Dictionary[StringName, StringName] = {}
@export var default_group: StringName = &"concrete"

@export_group("Holes")
## Holes kept in the world; past it the oldest is reused.
@export_range(1, 2000) var max_holes: int = 200
## Seconds a hole stays fully visible, then the seconds it takes to fade out.
@export_range(0.0, 600.0, 0.5) var hole_life: float = 30.0
@export_range(0.1, 30.0, 0.1) var hole_fade: float = 3.0

@export_group("Tracers")
## Speed of a tracer's head (m/s): 300 crosses 30 m in 0.1 s.
@export_range(10.0, 2000.0, 1.0) var tracer_speed: float = 300.0
## Length of the bright streak (m).
@export_range(0.1, 20.0, 0.1) var tracer_length: float = 3.0
## Thickness of the streak (m).
@export_range(0.002, 0.1, 0.001) var tracer_width: float = 0.02
@export var tracer_color: Color = Color(1.0, 0.9, 0.62)
## Seconds the streak takes to fade once its head has arrived.
@export_range(0.0, 1.0, 0.01) var tracer_fade: float = 0.06
## A tracer of a shot that hit nothing stops this far from the muzzle (m).
@export_range(5.0, 500.0, 1.0) var tracer_max_distance: float = 120.0


## The material group of `collider` hit on a face with `normal`.
func group_for(collider: Node, normal: Vector3 = Vector3.ZERO) -> StringName:
	if collider == null:
		return default_group
	if is_body(collider):
		return BODY
	if collider.has_meta(WALL_SURFACE_META) and normal.normalized().y < FLOOR_MIN_UP:
		return _surface_group(StringName(str(collider.get_meta(WALL_SURFACE_META))))
	if collider.has_meta(SURFACE_META):
		return _surface_group(StringName(str(collider.get_meta(SURFACE_META))))
	var entity_tags := _tags_above(collider)
	if entity_tags != null:
		for tag: StringName in tags:
			if entity_tags.has(tag):
				return tags[tag]
	return default_group


## The impact look of `group` (the default group's for an unknown one; null without either).
func puff(group: StringName) -> ImpactPuff:
	if puffs.has(group):
		return puffs[group]
	return puffs.get(default_group) as ImpactPuff


## A character's body: a hitbox (`body_part` metadata) or an entity with BodyParts.
static func is_body(collider: Node) -> bool:
	return not Hitboxes.part_of(collider).is_empty() or BodyParts.of(collider) != null


func _surface_group(surface: StringName) -> StringName:
	return surfaces.get(surface, default_group)


# The Tags of the collider or of its nearest ancestor that has them (a prop's collider may be a child
# of the entity).
static func _tags_above(node: Node) -> Tags:
	while node != null:
		var found := node.get_node_or_null(^"Tags") as Tags
		if found != null:
			return found
		node = node.get_parent()
	return null
