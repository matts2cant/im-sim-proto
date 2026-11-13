extends GdUnitTestSuite
## Integration (ADR 0131): the four shipped grenades (frag, gas, EMP, jamming) are composed the same
## way: a 1x1 item stacking to 5 on the belt, a THROWN weapon whose entity has Explosive, Breakable,
## ImpactNoise, Fuse (2.5 s), Sticky, ProximityTrigger (2 s, 2.5 m, 1 m crouched), MineDisarm giving
## the item back and the `Payload` slot; a bounce makes impact noise; a blast chains to a grenade.

const Wait := preload("res://tests/helpers/wait.gd")
const Grenades := preload("res://tests/items/grenades/grenade_helpers.gd")
const CATALOG: ItemCatalog = preload("res://items/item_catalog.tres")
const ITEMS: Array[String] = [
	"res://items/grenades/frag/frag_grenade_item.tres",
	"res://items/grenades/gas/gas_grenade_item.tres",
	"res://items/grenades/emp/emp_grenade_item.tres",
	"res://items/grenades/jamming/jamming_grenade_item.tres",
]
const ORIGIN := Vector3(940, 0, 0)

var _root: Node3D


func before_test() -> void:
	EventLog.clear()
	StimulusSystem.clear()
	_root = auto_free(Node3D.new()) as Node3D
	add_child(_root)


func after_test() -> void:
	StimulusSystem.clear()


func test_every_grenade_item_is_a_thrown_weapon_whose_entity_is_a_mine() -> void:
	for path in ITEMS:
		var item := load(path) as ItemData
		assert_object(CATALOG.find(item.id)).is_same(item)
		assert_int(item.max_stack).is_equal(5)
		assert_bool(item.footprint == Vector2i.ONE and item.auto_belt).is_true()
		assert_int(item.use_action).is_equal(ItemData.UseAction.EQUIP_WEAPON)
		assert_bool(item.weapon.is_thrown()).is_true()
		assert_object(item.weapon.view_scene).is_not_null()
		var entity := (load(item.weapon.thrown_scene) as PackedScene).instantiate()
		assert_str(str(entity.get_meta(&"display_name"))).is_equal(item.display_name)
		assert_object(Explosive.of(entity)).is_not_null()
		# The blast comes from its payload (M14b): none of its own.
		assert_object(Explosive.of(entity).config).is_null()
		assert_object(ExplosivePayload.of(entity).config).is_not_null()
		assert_object(Breakable.of(entity)).is_not_null()
		assert_object(entity.get_node_or_null("ImpactNoise")).is_not_null()
		assert_object(Fuse.of(entity).config).is_same(Fuse.DEFAULT_CONFIG)
		assert_float(Fuse.of(entity).config.time).is_equal(2.5)
		assert_bool(Fuse.of(entity).config.hits_characters).is_true()
		assert_object(Sticky.of(entity)).is_not_null()
		var trigger := ProximityTrigger.of(entity).config
		assert_array([trigger.arm_time, trigger.radius, trigger.crouched_radius]).is_equal([2.0, 2.5, 1.0])
		# Every character sets it off (no tag filter).
		assert_array(trigger.required_tags).is_empty()
		assert_array(trigger.ignored_tags).is_empty()
		assert_object((Usable.of(entity) as MineDisarm).item).is_same(item)
		assert_object(entity.get_node_or_null("Payload")).is_same(ExplosivePayload.of(entity))
		assert_bool(Breakable.of(entity).break_on_depleted).is_false()
		var pickup := (load(item.world_scene) as PackedScene).instantiate()
		assert_object(ItemPickup.of(pickup).item).is_same(item)
		pickup.free()
		entity.free()


func test_a_bounce_makes_impact_noise() -> void:
	Grenades.box(_root, ORIGIN + Vector3(0, -0.5, 0), Vector3(10, 1, 10))
	var frag := _frag(ORIGIN + Vector3(0, 1.5, 0))

	await Grenades.seconds(get_tree(), 0.8)

	assert_array(Grenades.logged(&"object.impact", String(frag.name))).is_not_empty()


func test_a_blast_sets_off_a_grenade_nearby() -> void:
	var first := _frag(ORIGIN + Vector3(0, 5, 20))
	var second := _frag(ORIGIN + Vector3(1.5, 5, 20))
	first.freeze = true
	second.freeze = true
	await Wait.frames(get_tree(), 1)

	Explosive.of(first).explode()
	await Wait.frames(get_tree(), 4)

	assert_bool(is_instance_valid(second)).is_false()
	assert_array(EventLog.find(&"object.exploded")).has_size(2)


func _frag(at: Vector3) -> RigidBody3D:
	var body := (load("res://items/grenades/frag/frag_grenade.tscn") as PackedScene).instantiate() as RigidBody3D
	body.position = at
	_root.add_child(body, true)
	return body
