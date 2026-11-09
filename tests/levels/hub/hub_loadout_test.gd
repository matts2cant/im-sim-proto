extends GdUnitTestSuite
## The hub's loadout table (the player starts with an empty inventory since M5): a 1.0 m wooden
## table near PlayerSpawn holding the starting kit as item pickups (since ADR 0085 the pistol is loud
## and a silencer lies beside it), signed "Loadout", clear of the spawn, the walk straight ahead from
## it and the hub doorways; neighbouring pickups do not overlap.

const HUB_SCENE: PackedScene = preload("res://levels/hub/hub.tscn")
const PLAYER_RADIUS := 0.35
const LOADOUT: Dictionary[StringName, int] = {
	&"pistol": 1,
	&"silencer": 1,
	&"baton": 1,
	&"pistol_ammo": 60,
	&"medkit": 2,
	&"lockpick": 2,
	&"biocell": 2,
}

var _hub: Node3D


func before_test() -> void:
	_hub = auto_free(HUB_SCENE.instantiate())


func test_table_holds_the_starting_kit() -> void:
	var table := _hub.get_node("Loadout/Table") as Ledge
	var counts: Dictionary[StringName, int] = {}

	assert_float(table.height).is_equal(1.0)
	assert_str(table.surface).is_equal("wood")
	for child: Node in _hub.get_node("Loadout").get_children():
		var pickup := ItemPickup.of(child)
		if pickup == null:
			continue
		counts[pickup.item.id] = counts.get(pickup.item.id, 0) + pickup.count
		# Resting on the table top, inside its footprint.
		var body := child as RigidBody3D
		var local := table.transform.affine_inverse() * body.transform.origin
		var shape := (body.get_node("Collision") as CollisionShape3D).shape as BoxShape3D
		assert_float(local.y - shape.size.y * 0.5).override_failure_message(child.name).is_equal_approx(
			table.height, 0.001
		)
		assert_float(absf(local.x)).override_failure_message(child.name).is_less(table.width * 0.5)
		assert_bool(local.z < 0.0 and local.z > -table.depth).override_failure_message(child.name).is_true()

	assert_int(counts.size()).is_equal(LOADOUT.size())
	# The pistol is not silenced: the silencer is a separate pickup to fit in the inventory.
	assert_dict(Attachments.fitted_ids(ItemPickup.of(_hub.get_node("Loadout/Pistol")).stack_state())).is_empty()
	for id: StringName in LOADOUT:
		assert_int(counts.get(id, 0)).override_failure_message(String(id)).is_equal(LOADOUT[id])
	assert_str((_hub.get_node("Loadout/Sign") as Sign).text).is_equal("Loadout")


func test_table_is_near_the_spawn_but_blocks_nothing() -> void:
	var table := _hub.get_node("Loadout/Table") as Ledge
	var spawn := (_hub.get_node("PlayerSpawn") as Node3D).position
	# Table footprint in hub x / z (unrotated: lip at its origin, block towards -Z).
	var rect := Rect2(table.position.x - table.width * 0.5, table.position.z - table.depth, table.width, table.depth)
	var nearest := Vector2(clampf(spawn.x, rect.position.x, rect.end.x), clampf(spawn.z, rect.position.y, rect.end.y))

	var gap := nearest.distance_to(Vector2(spawn.x, spawn.z)) - PLAYER_RADIUS
	assert_float(gap).is_between(0.5, 3.0)
	# The walk straight ahead from the spawn (towards doorways 1 and 2) passes beside it.
	assert_float(rect.position.x - spawn.x).is_greater(PLAYER_RADIUS)
	for doorway: Node in _hub.get_node("Doorways").get_children():
		var at := (doorway as Node3D).position
		assert_bool(rect.grow(5.0).has_point(Vector2(at.x, at.z))).override_failure_message(doorway.name).is_false()


func test_pickups_do_not_overlap() -> void:
	var boxes: Array[Rect2] = []
	for child: Node in _hub.get_node("Loadout").get_children():
		if ItemPickup.of(child) == null:
			continue
		var body := child as RigidBody3D
		var size := ((body.get_node("Collision") as CollisionShape3D).shape as BoxShape3D).size
		var at := body.transform.origin
		var rect := Rect2(at.x - size.x * 0.5, at.z - size.z * 0.5, size.x, size.z)
		for other in boxes:
			assert_bool(rect.intersects(other)).override_failure_message(child.name).is_false()
		boxes.append(rect)
