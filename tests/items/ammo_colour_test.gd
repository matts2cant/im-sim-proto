extends GdUnitTestSuite
## Unit (ADR 0101): each ammo box is its weapon's colour, in the world and on its inventory and belt
## icon (ItemIcon draws ItemData.colour): shotgun shells yellow, assault rifle rounds green, sniper
## rounds purple, pistol ammo red. The world box's material is the item's colour.

const CATALOG: ItemCatalog = preload("res://items/item_catalog.tres")
## Weapon item -> hue band (Color.h, 0..1) of its ammo.
const HUES := {
	&"shotgun": Vector2(0.10, 0.17),  # yellow
	&"assault_rifle": Vector2(0.28, 0.40),  # green
	&"sniper_rifle": Vector2(0.72, 0.85),  # purple
	&"pistol": Vector2(-0.03, 0.03),  # red (wraps at 0)
}


func test_each_weapons_ammo_has_its_hue() -> void:
	for weapon_id: StringName in HUES:
		var ammo := _ammo_of(weapon_id)
		var hue := ammo.colour.h
		if hue > 0.5 and HUES[weapon_id].x < 0.0:
			hue -= 1.0
		assert_float(hue).override_failure_message("%s: hue %.3f" % [ammo.id, hue]).is_between(
			HUES[weapon_id].x, HUES[weapon_id].y
		)
		# Saturated enough to read as a colour, not a grey.
		assert_float(ammo.colour.s).override_failure_message(String(ammo.id)).is_greater(0.5)


func test_the_world_box_is_the_icon_colour() -> void:
	for weapon_id: StringName in HUES:
		var ammo := _ammo_of(weapon_id)
		var box := (load(ammo.world_scene) as PackedScene).instantiate()
		var mesh := (box.get_node("Mesh") as MeshInstance3D).mesh
		var material := mesh.surface_get_material(0) as StandardMaterial3D
		assert_object(material).override_failure_message(String(ammo.id)).is_not_null()
		(
			assert_bool(material.albedo_color.is_equal_approx(ammo.colour))
			. override_failure_message(String(ammo.id))
			. is_true()
		)
		box.free()


func _ammo_of(weapon_id: StringName) -> ItemData:
	var weapon := CATALOG.find(weapon_id)
	return CATALOG.find(weapon.weapon.ammo_item)
