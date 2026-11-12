class_name TargetFrame
extends Control
## HUD (ADR 0129): Deus Ex's interaction frame. While the player's Interactor targets something it
## can pick up, use or carry (TargetFrameRules.frames(); "Too heavy" too, never while carrying) and
## the player can act and is not scoped, four thin white corner brackets frame the target's visible
## geometry on screen and a small boxed name tag (the prompt's name, Interactor.target_name) sits
## inside the frame's top-left corner. Decided only by the Interactor's components: anything that
## becomes interactable is framed with no extra code.
## The target's visible parts (frameable()) are collected when the target changes; each refresh
## merges their current boxes in the target's frame (a falling body or a moving part stays framed),
## clips that box to the camera's near plane and projects it. The Hud calls refresh() every frame;
## tests call it too. Visual only, not saved.

const COLOR := Color(1, 1, 1, 0.95)
## Faint dark outline around each bar so the frame reads on bright and dark backgrounds.
const OUTLINE_COLOR := Color(0, 0, 0, 0.5)

## The frame on screen (canvas units), no area while hidden.
var frame_rect: Rect2 = Rect2()
## The entity framed now, or null.
var target: Node3D = null

var _parts: Array[GeometryInstance3D] = []
var _line: float = 1.0
var _arm: float = 8.0

@onready var tag: Label = $Tag


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hide()


## Shows the frame on what `player`'s Interactor targets now, or hides it.
func refresh(player: Player) -> void:
	var interactor := player.interactor
	var entity: Node3D = null
	var shown := ActorState.can_act(player) and not player.weapons.scope.scoped
	if shown and TargetFrameRules.frames(interactor.kind) and is_instance_valid(interactor.target):
		entity = interactor.target as Node3D
	if entity != target or not is_instance_valid(target):
		target = entity
		_parts = visual_parts(entity) if entity != null else ([] as Array[GeometryInstance3D])
	var camera := get_viewport().get_camera_3d()
	var rect := _project(camera) if target != null and camera != null else Rect2()
	if not rect.has_area():
		_hide()
		return
	var screen := get_viewport_rect().size
	var ui_scale := TargetFrameRules.unit(screen.y)
	frame_rect = rect
	_line = TargetFrameRules.line_width(ui_scale, get_viewport().get_stretch_transform().get_scale().y)
	_arm = TargetFrameRules.arm_length(rect, ui_scale)
	tag.text = interactor.target_name
	tag.visible = not tag.text.is_empty()
	tag.size = tag.get_combined_minimum_size()
	tag.position = TargetFrameRules.tag_position(rect, tag.size, screen, _line, ui_scale)
	visible = true
	queue_redraw()


## The name shown in the tag ("" while hidden).
func name_text() -> String:
	return tag.text if visible else ""


## Geometry of `entity` that shows it on screen: its GeometryInstance3D descendants (itself
## included) that frameable() accepts.
static func visual_parts(entity: Node) -> Array[GeometryInstance3D]:
	var parts: Array[GeometryInstance3D] = []
	_collect(entity, parts)
	return parts


## True for geometry that is part of a thing's look: not text or sprites (labels, icons over a
## character), particles (fire), shadow-only proxies, nodes placed on their own (`top_level`: an AR
## overlay) or the operand shapes inside a CSG tree. Hidden nodes are skipped at each refresh.
static func frameable(geometry: GeometryInstance3D) -> bool:
	if geometry is SpriteBase3D or geometry is Label3D or geometry is GPUParticles3D or geometry is CPUParticles3D:
		return false
	if geometry.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY:
		return false
	return not (geometry is CSGShape3D and not (geometry as CSGShape3D).is_root_shape())


static func _collect(node: Node, parts: Array[GeometryInstance3D]) -> void:
	var geometry := node as GeometryInstance3D
	if geometry != null and frameable(geometry):
		parts.append(geometry)
	for child in node.get_children(true):
		if child is Node3D and (child as Node3D).top_level:
			continue
		_collect(child, parts)


func _draw() -> void:
	if not frame_rect.has_area():
		return
	var bars := TargetFrameRules.bracket_rects(frame_rect, _arm, _line)
	for bar in bars:
		draw_rect(bar.grow(_line), OUTLINE_COLOR)
	for bar in bars:
		draw_rect(bar, COLOR)


# The frame of the target's visible box seen by `camera`, no area when nothing of it is in front.
func _project(camera: Camera3D) -> Rect2:
	var bounds := _local_bounds()
	if not bounds.has_surface():
		return Rect2()
	var to_camera := camera.global_transform.affine_inverse() * target.global_transform
	var corners := PackedVector3Array()
	for i in 8:
		corners.append(to_camera * bounds.get_endpoint(i))
	var front := TargetFrameRules.clip_to_front(corners, camera.near * 1.01)
	var points := PackedVector2Array()
	for point in front:
		points.append(camera.unproject_position(camera.global_transform * point))
	var screen := get_viewport_rect().size
	return TargetFrameRules.frame_rect(TargetFrameRules.rect_of(points), screen, TargetFrameRules.unit(screen.y))


# The merged box of the visible parts in the target's own frame (no surface without any).
func _local_bounds() -> AABB:
	var to_target := target.global_transform.affine_inverse()
	var merged := AABB()
	var found := false
	for part in _parts:
		if not is_instance_valid(part) or not part.is_visible_in_tree():
			continue
		var box := part.get_aabb()
		if not box.has_surface():
			continue
		box = (to_target * part.global_transform) * box
		merged = merged.merge(box) if found else box
		found = true
	return merged


func _hide() -> void:
	frame_rect = Rect2()
	visible = false
	if tag != null:
		tag.text = ""
