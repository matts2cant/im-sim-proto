class_name TargetFrame
extends Control
## HUD (ADR 0129, ADR 0130): Deus Ex's interaction frame. While the player can act and is not
## scoped, four thin white corner brackets frame, within reach (the Interactor's ray,
## `interact_reach`; a hitbox stands for its character), what the Interactor targets (something it
## can pick up, use or carry: TargetFrameRules.frames(); "Too heavy" too, never while carrying), or
## else the thing under the crosshair when it has a Device, a Powered or BodyParts (TargetStatus.shows():
## a device, a powered thing, a character). A boxed tag sits inside the frame's top-left corner:
## the name (the prompt's name, Interactor.target_name; else TargetStatus.name_of()), then a status
## line (a square and a word in the state's colour: TargetStatus.word_of(); a cut-off device's
## square blinks) and a lock line ("Locked · key or lockpick", LockRules.locked_line() of its
## Lockable while locked). Both lines update every refresh. Decided only by components: anything
## that becomes interactable or gains one of those components is framed with no extra code.
## The target's visible parts (frameable()) and its device's links are collected when the target
## changes; each refresh clips each part's current box to the camera's view
## (TargetFrameRules.clip_box) and projects it, so a falling body or a moving part stays framed and
## a lying body is framed tightly. The Hud calls refresh() every frame; tests call it too. Visual
## only, not saved.

const COLOR := Color(1, 1, 1, 0.95)
## Faint dark outline around each bar so the frame reads on bright and dark backgrounds.
const OUTLINE_COLOR := Color(0, 0, 0, 0.5)

## The frame on screen (canvas units), no area while hidden.
var frame_rect: Rect2 = Rect2()
## The entity framed now, or null.
var target: Node3D = null
## The status word shown now (TargetStatus.Word.NONE: no status line).
var word: TargetStatus.Word = TargetStatus.Word.NONE

var _parts: Array[GeometryInstance3D] = []
var _links: Array[Device] = []
var _line: float = 1.0
var _arm: float = 8.0

@onready var tag: PanelContainer = $Tag
@onready var name_label: Label = $Tag/Lines/Name
@onready var status_row: HBoxContainer = $Tag/Lines/Status
@onready var status_square: ColorRect = $Tag/Lines/Status/Square
@onready var status_label: Label = $Tag/Lines/Status/Word
@onready var lock_row: HBoxContainer = $Tag/Lines/Lock
@onready var lock_square: ColorRect = $Tag/Lines/Lock/Square
@onready var lock_label: Label = $Tag/Lines/Lock/Word


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	lock_square.color = TargetStatus.LOCKED_COLOR
	lock_label.add_theme_color_override(&"font_color", TargetStatus.LOCKED_COLOR)
	_hide()


## Shows the frame on what `player` targets or looks at now (see the class description), or hides it.
func refresh(player: Player) -> void:
	var interactor := player.interactor
	var entity: Node3D = null
	var interactable := false
	if ActorState.can_act(player) and not player.weapons.scope.scoped:
		if TargetFrameRules.frames(interactor.kind) and is_instance_valid(interactor.target):
			entity = interactor.target as Node3D
			interactable = true
		elif is_instance_valid(interactor.looked_at) and TargetStatus.shows(interactor.looked_at):
			entity = interactor.looked_at as Node3D
	if entity != target or not is_instance_valid(target):
		target = entity
		_gather(entity)
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
	name_label.text = interactor.target_name if interactable else TargetStatus.name_of(target)
	_show_status(TargetStatus.word_of(target, _links))
	_show_lock(TargetStatus.lock_line(target, player))
	tag.visible = not name_label.text.is_empty() or status_row.visible or lock_row.visible
	tag.size = tag.get_combined_minimum_size()
	tag.position = TargetFrameRules.tag_position(rect, tag.size, screen, _line, ui_scale)
	visible = true
	queue_redraw()


## The name shown in the tag ("" while hidden).
func name_text() -> String:
	return name_label.text if visible else ""


## The status word shown ("" while hidden or without a status line).
func status_text() -> String:
	return status_label.text if visible and status_row.visible else ""


## The lock line shown ("" while hidden or not locked).
func lock_text() -> String:
	return lock_label.text if visible and lock_row.visible else ""


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


# The frame of the target's visible parts seen by `camera`: each part's box clipped to the view and
# projected, the rectangle around them all; no area when nothing of it is in view.
func _project(camera: Camera3D) -> Rect2:
	var frustum := camera.get_frustum()
	var points := PackedVector2Array()
	var corners := PackedVector3Array()
	corners.resize(8)
	for part in _parts:
		if not is_instance_valid(part) or not part.is_visible_in_tree():
			continue
		var box := part.get_aabb()
		if not box.has_surface():
			continue
		var to_world := part.global_transform
		for i in 8:
			corners[i] = to_world * box.get_endpoint(i)
		for point in TargetFrameRules.clip_box(corners, frustum):
			points.append(camera.unproject_position(point))
	var screen := get_viewport_rect().size
	return TargetFrameRules.frame_rect(TargetFrameRules.rect_of(points), screen, TargetFrameRules.unit(screen.y))


func _hide() -> void:
	frame_rect = Rect2()
	visible = false
	word = TargetStatus.Word.NONE
	if name_label != null:
		name_label.text = ""
		status_label.text = ""
		lock_label.text = ""
		status_row.visible = false
		lock_row.visible = false


# The new target's visible parts and its device's links (read once: cables are level data).
func _gather(entity: Node3D) -> void:
	_parts = visual_parts(entity) if entity != null else ([] as Array[GeometryInstance3D])
	_links.clear()
	var device := Device.of(entity) if entity != null else null
	if device != null and device.is_inside_tree():
		_links = TargetStatus.network_links(device)


func _show_status(p_word: TargetStatus.Word) -> void:
	word = p_word
	status_row.visible = p_word != TargetStatus.Word.NONE
	if not status_row.visible:
		status_label.text = ""
		return
	var colour := TargetStatus.color(p_word)
	status_label.text = TargetStatus.text(p_word)
	status_label.add_theme_color_override(&"font_color", colour)
	status_square.color = colour
	var seconds := Time.get_ticks_msec() / 1000.0
	status_square.modulate.a = TargetStatus.blink_alpha(seconds) if TargetStatus.blinks(p_word) else 1.0


func _show_lock(line: String) -> void:
	lock_label.text = line
	lock_row.visible = not line.is_empty()
