class_name DamageNumbers
extends Node3D
## Component of any entity with BodyParts: a floating number for every hit ("torso 25"), stun
## ("stun 20") and knockout ("KO"), over the part's hitbox (Hitboxes) or above the entity's origin,
## rising and fading out (DamageNumbersConfig). Numbers in quick succession alternate sides and
## heights instead of overlapping. Restoring the body (BodyParts.restored) clears them. A training
## dummy has one; nothing in it is dummy-specific.

const KNOCKOUT_TEXT := "KO"

@export var config: DamageNumbersConfig
@export var entity_path: NodePath = ^".."

var entity: Node3D

var _stack: int = 0


func _ready() -> void:
	entity = Entities.of_component(self, entity_path) as Node3D
	if config == null:
		config = DamageNumbersConfig.new()
	var body := BodyParts.of(entity)
	if body == null:
		return
	body.damaged.connect(_on_damaged)
	body.stunned.connect(_on_stunned)
	body.knocked_out.connect(_on_knocked_out)
	body.restored.connect(clear)


## The floating number labels currently shown (newest last).
func labels() -> Array[Label3D]:
	var result: Array[Label3D] = []
	for child in get_children():
		if child is Label3D and not child.is_queued_for_deletion():
			result.append(child as Label3D)
	return result


## Their texts, newest last.
func texts() -> PackedStringArray:
	var result: PackedStringArray = []
	for label in labels():
		result.append(label.text)
	return result


func clear() -> void:
	for label in get_children():
		label.queue_free()
	_stack = 0


## "25" or "12.5".
static func amount_text(amount: float) -> String:
	return str(roundi(amount)) if is_equal_approx(amount, roundf(amount)) else "%.1f" % amount


func _on_damaged(part: StringName, type: StringName, amount: float) -> void:
	_show(part, "%s %s" % [part, amount_text(amount)], config.type_colors.get(type, config.damage_color))


func _on_stunned(amount: float, _total: float) -> void:
	_show(BodyDamageModel.HEAD, "stun %s" % amount_text(amount), config.stun_color)


func _on_knocked_out() -> void:
	_show(BodyDamageModel.HEAD, KNOCKOUT_TEXT, config.knockout_color)


func _show(part: StringName, text: String, color: Color) -> void:
	var label := Label3D.new()
	label.text = text
	label.modulate = color
	label.outline_modulate = config.outline_color
	label.font_size = config.font_size
	label.outline_size = config.outline_size
	label.pixel_size = config.pixel_size
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.fixed_size = false
	add_child(label)
	label.global_position = _anchor(part) + _offset()
	_stack += 1
	var tween := label.create_tween().set_parallel()
	tween.tween_property(label, ^"position:y", label.position.y + config.rise, config.lifetime)
	tween.tween_property(label, ^"modulate:a", 0.0, config.lifetime).set_ease(Tween.EASE_IN)
	tween.chain().tween_callback(label.queue_free)


func _anchor(part: StringName) -> Vector3:
	var hitboxes := Hitboxes.of(entity)
	var box: CollisionObject3D = hitboxes.box(part) if hitboxes != null else null
	return box.global_position if box != null else entity.global_position + Vector3.UP * config.fallback_height


# Alternating sides, climbing steps.
func _offset() -> Vector3:
	var side := config.side_offset if _stack % 2 == 0 else -config.side_offset
	return Vector3(side, config.lift + config.step_height * (_stack % maxi(config.steps, 1)), 0)
