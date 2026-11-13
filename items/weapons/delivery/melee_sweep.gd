class_name MeleeSweep
extends WeaponDelivery
## A melee swing (WeaponData.Kind.MELEE): a sphere of WeaponData.sweep_radius swept from the eye
## along its -Z until its front reaches `max_range`, on PhysicsLayers.WEAPON_MASK without the user's
## own colliders (OwnBody). The first thing it meets gets the weapon's `damage.*` as CONTACT stimuli
## (a hitbox carries its part; scaled by the user's `<class>_damage_mult`). A swing noise at the eye
## (`fire_noise`) and, on a hit, an impact noise (`impact_noise`) and the hit sound there; both
## noises are WeaponState.stat()s like a gun's, so attachments change them. Logs `weapon.swung`.


func deliver(holder: WeaponHolder, data: WeaponData) -> void:
	var weapon_state := holder.state()
	var from := holder.eye.global_transform
	var forward := -from.basis.z.normalized()
	var sphere := SphereShape3D.new()
	sphere.radius = data.sweep_radius
	var params := PhysicsShapeQueryParameters3D.new()
	params.shape = sphere
	params.collision_mask = PhysicsLayers.WEAPON_MASK
	params.exclude = OwnBody.rids(holder.user)
	params.transform = Transform3D(Basis.IDENTITY, from.origin)
	# The sphere's front reaches max_range from the eye.
	params.motion = forward * maxf(data.max_range - data.sweep_radius, 0.0)
	var space := holder.get_world_3d().direct_space_state
	var fractions := space.cast_motion(params)
	emit(holder, Stimulus.make_noise(weapon_state.stat(&"fire_noise"), from.origin, holder.user))
	holder.audio.play_fire(weapon_state)
	holder.last_hit = {}
	var hit_name := ""
	if fractions.size() == 2 and fractions[1] < 1.0:
		params.transform.origin += params.motion * fractions[1]
		params.motion = Vector3.ZERO
		var info := space.get_rest_info(params)
		var collider: Node = null
		if not info.is_empty():
			collider = instance_from_id(int(info["collider_id"])) as Node
		if collider != null:
			var point: Vector3 = info["point"]
			hit_name = String(collider.name)
			holder.last_hit = {"collider": collider, "position": point}
			for type: StringName in data.damage:
				var hit_stimulus := Stimulus.make_contact(type, data.damage[type], collider, holder.user)
				hit_stimulus.scale_attribute = data.class_attribute("damage_mult")
				emit(holder, hit_stimulus)
			emit(holder, Stimulus.make_noise(weapon_state.stat(&"impact_noise"), point, holder.user))
			holder.audio.play_hit(data, point)
			holder.feedback.swing_hit(data, collider, point, info.get("normal", Vector3.ZERO) as Vector3)
	log_event(holder, &"weapon.swung", {"weapon": data.id, "hit": hit_name})
