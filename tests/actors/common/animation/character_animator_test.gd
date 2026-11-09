extends GdUnitTestSuite
## Integration (ADR 0103): a CharacterAnimator on a minimal character built in code (the test
## walker, BodyParts, Tags, a Kenney blocky model, an eye with a WeaponHolder), no guard: walking
## plays walk at a rate scaled to the ground speed, running sprints, a shot plays the grip's shoot
## clip over the hold pose with the weapon in the hand, a downed character plays the down clip and
## holds it lying on the floor, waking returns to idle, and a loaded save shows the downed pose at
## once.

const Characters := preload("res://tests/actors/common/character_fixtures.gd")
const MODEL: PackedScene = preload("res://assets/models/kenney_blocky_characters/character-j.glb")
const CONFIG: CharacterAnimConfig = preload("res://actors/common/animation/blocky_character_anim.tres")
const PISTOL: WeaponData = preload("res://items/weapons/pistol/pistol_unsilenced.tres")
const RIFLE: WeaponData = preload("res://items/weapons/assault_rifle/assault_rifle.tres")
const ORIGIN := Vector3(-260, 0, 260)
const MODEL_SCALE: float = 0.66

var _root: Node3D


func before_test() -> void:
	EventLog.clear()
	StimulusSystem.clear()
	_root = auto_free(Node3D.new()) as Node3D
	add_child(_root)
	var floor_body := Characters.floor_box(_root)
	floor_body.position.x = ORIGIN.x
	floor_body.position.z = ORIGIN.z


func test_walking_plays_walk_at_a_scaled_rate() -> void:
	var body := await _character("Walker")
	var animator := _animator(body)
	body.set("drive", Vector3(0, 0, -1.5))
	await _physics(30)
	assert_float(animator.weight_of(CONFIG.walk_clip)).is_equal(1.0)
	assert_float(animator.base.current.rate).is_equal_approx(1.5 / CONFIG.walk_clip_speed, 0.02)
	# The legs swing (not at rest).
	var leg := animator.part(&"leg-left")
	var swing := absf(leg.rotation.x) + absf(animator.part(&"leg-right").rotation.x)
	assert_float(swing).is_greater(0.05)
	body.set("drive", Vector3.ZERO)
	await _physics(30)
	assert_float(animator.weight_of(CONFIG.idle_clip)).is_equal(1.0)


func test_running_sprints() -> void:
	var body := await _character("Runner")
	var animator := _animator(body)
	body.set("drive", Vector3(4.0, 0, 0))
	await _physics(30)
	assert_float(animator.weight_of(CONFIG.sprint_clip)).is_equal(1.0)
	assert_float(animator.base.current.rate).is_equal_approx(4.0 / CONFIG.sprint_clip_speed, 0.02)


func test_a_shot_plays_the_shoot_clip_with_the_weapon_in_hand() -> void:
	var body := await _character("Shooter")
	var animator := _animator(body)
	var holder := body.get_node("Aim/WeaponHolder") as WeaponHolder
	holder.equip(0)
	await _physics(20)
	assert_float(animator.weight_of(CONFIG.hold_one_hand_clip)).is_equal(1.0)
	# The view hangs from the hand mount, at its true size.
	var view := holder.view_pivot()
	assert_object(view.get_parent()).is_same(animator.hand_mount)
	assert_bool(view.in_hand).is_true()
	assert_float(view.global_basis.get_scale().x).is_equal_approx(1.0, 0.01)
	# Hold pose: the right arm points ahead (-Z), the hand at about chest height.
	var hand := view.global_position - body.global_position
	assert_float(hand.z).is_less(-0.35)
	assert_float(hand.y).is_between(0.95, 1.45)
	assert_int(holder.trigger()).is_equal(WeaponState.Result.FIRED)
	await _physics(2)
	assert_str(String(animator.action.current.clip)).is_equal(String(CONFIG.shoot_one_hand_clip))
	await _physics(30)
	assert_str(String(animator.action.current.clip)).is_empty()
	assert_float(animator.weight_of(CONFIG.hold_one_hand_clip)).is_equal(1.0)
	# A two-handed weapon holds with both arms and sits between the hands.
	holder.equip(1)
	await _physics(20)
	assert_float(animator.weight_of(CONFIG.hold_two_hand_clip)).is_equal(1.0)
	var centre := view.global_position - body.global_position
	assert_float(absf(centre.x)).is_less(0.1)


func test_a_downed_character_lies_on_the_floor_then_wakes_to_idle() -> void:
	var body := await _character("Sleeper")
	var animator := _animator(body)
	var parts := Characters.body_parts(body)
	parts.take_damage(&"damage.stun", 500.0, &"head")
	assert_bool(ActorState.can_act(body)).is_false()
	await _physics(60)
	assert_float(animator.weight_of(CONFIG.unconscious_clip)).is_equal(1.0)
	assert_float(animator.down.current.progress()).is_equal(1.0)
	_assert_lying(body, animator)
	# Held: still lying a second later.
	await _physics(60)
	_assert_lying(body, animator)
	parts.revive("test")
	await _physics(60)
	assert_float(animator.weight_of(CONFIG.unconscious_clip)).is_equal(0.0)
	assert_float(animator.weight_of(CONFIG.idle_clip)).is_equal(1.0)
	assert_float(animator.model.position.y).is_equal_approx(0.0, 0.001)
	assert_float(_top(body, animator)).is_greater(1.7)


func test_a_loaded_save_shows_the_downed_pose_at_once() -> void:
	var original := await _character("Original")
	Characters.body_parts(original).take_damage(&"damage.ballistic", 500.0, &"torso")
	assert_bool(ActorState.is_dead(original)).is_true()
	var tags_state := Characters.tags_of(original).save_state()
	var body_state := Characters.body_parts(original).save_state()
	original.queue_free()
	# A fresh character (a reloaded level) gets the saved state before its first tick...
	var loaded := await _character("Loaded", false)
	Characters.tags_of(loaded).load_state(tags_state)
	Characters.body_parts(loaded).load_state(body_state)
	var animator := _animator(loaded)
	await _physics(2)
	# ...and lies at once: no fall replayed.
	assert_float(animator.weight_of(CONFIG.dead_clip)).is_equal(1.0)
	assert_float(animator.down.current.progress()).is_equal(1.0)
	_assert_lying(loaded, animator)
	# A quickload onto a character that already ticked standing also snaps.
	var standing := await _character("Standing")
	var other := _animator(standing)
	ActorState.set_tag(standing, ActorState.DEAD, true)
	other.on_quickloaded()
	await _physics(2)
	assert_float(other.weight_of(CONFIG.dead_clip)).is_equal(1.0)
	assert_float(other.down.current.progress()).is_equal(1.0)


func _assert_lying(body: Node3D, animator: CharacterAnimator) -> void:
	var lowest := INF
	for mesh in _figure(animator):
		lowest = minf(lowest, _box(body, mesh).position.y)
	# The lowest part rests on the floor; nothing reaches the 0.7 m of a lying capsule.
	assert_float(lowest).is_equal_approx(0.0, 0.03)
	assert_float(_top(body, animator)).is_less(0.65)


func _top(body: Node3D, animator: CharacterAnimator) -> float:
	var top := -INF
	for mesh in _figure(animator):
		top = maxf(top, _box(body, mesh).end.y)
	return top


# The model's own meshes (not the weapon hanging from the hand).
func _figure(animator: CharacterAnimator) -> Array[MeshInstance3D]:
	var meshes: Array[MeshInstance3D] = []
	for mesh: MeshInstance3D in animator.model.find_children("*", "MeshInstance3D", true, false):
		if animator.hand_mount == null or not animator.hand_mount.is_ancestor_of(mesh):
			meshes.append(mesh)
	return meshes


func _box(body: Node3D, mesh: MeshInstance3D) -> AABB:
	return (body.global_transform.affine_inverse() * mesh.global_transform) * mesh.get_aabb()


# A walker with the model ("Model", facing -Z, 0.66 scale), an eye ("Aim") with a WeaponHolder
# (pistol, rifle) and a CharacterAnimator; settled on the floor when `settle`.
func _character(character_name: String, settle: bool = true) -> CharacterBody3D:
	var feet := ORIGIN + Vector3(_root.get_child_count() * 3.0, 0, 0)
	var body := Characters.character(_root, character_name, feet, [])
	var model := MODEL.instantiate() as Node3D
	model.name = "Model"
	model.transform = Transform3D(Basis(Vector3.UP, PI).scaled(Vector3.ONE * MODEL_SCALE), Vector3.ZERO)
	body.add_child(model)
	var eye := Node3D.new()
	eye.name = "Aim"
	eye.position.y = 1.6
	body.add_child(eye)
	var holder := WeaponHolder.new()
	holder.name = "WeaponHolder"
	holder.aim_config = AimConfig.new()
	holder.weapons = [PISTOL, RIFLE] as Array[WeaponData]
	eye.add_child(holder)
	holder.setup(body, eye)
	if settle:
		_add_animator(body)
		await _physics(3)
	return body


func _animator(body: Node) -> CharacterAnimator:
	var animator := body.get_node_or_null("Animator") as CharacterAnimator
	return animator if animator != null else _add_animator(body)


func _add_animator(body: Node) -> CharacterAnimator:
	var animator := CharacterAnimator.new()
	animator.name = "Animator"
	animator.config = CONFIG
	body.add_child(animator)
	return animator


func _physics(frames: int) -> void:
	for i in frames:
		await get_tree().physics_frame
