class_name RangedFire
extends WeaponDelivery
## A gun's shot (WeaponData.Kind.RANGED): from the holder's aim transform (sway and recoil applied),
## a direction sampled inside the aim cone, spread into WeaponData.pellets projectiles inside the
## pellet cone (PelletPattern, narrowed by the user's `<class>_spread_mult`). Each projectile emits
## a `damage.*` RAY per damage entry (scaled by distance, WeaponData.damage_scale_at(), and the
## user's `<class>_damage_mult`) and a `force.impact` RAY (WeaponData.impact_impulse; ADR 0057) along
## PhysicsLayers.WEAPON_MASK, the user's own colliders left out (OwnBody). A muzzle noise
## (`fire_noise`) and, where the first projectile struck, one impact noise (`impact_noise`) and hit
## sound; both noises are WeaponState.stat()s, so attachments change them. Then the impacts and
## tracers (ShotFeedback), the cone's bloom, the shot sound and the muzzle flash; logs
## `weapon.fired`. aimed_hit() is the ray of a shot through the centre of the cone.


func deliver(holder: WeaponHolder, data: WeaponData) -> void:
	var weapon_state := holder.state()
	var aim := holder.aim
	var from := holder.aim_transform()
	var centre := aim.sample_direction(from.basis)
	var spread := aim.spread
	var spread_mult := data.class_value(holder.user, "spread_mult", 1.0)
	var directions := PelletPattern.spread(
		centre, from.basis.y, data.pellets, data.pellet_spread_deg * spread_mult, aim.rng
	)
	var exclude := OwnBody.rids(holder.user)
	var space := holder.get_world_3d().direct_space_state
	var rays: Dictionary[StringName, float] = data.damage.duplicate()
	if data.impact_impulse > 0.0:
		rays[&"force.impact"] = data.impact_impulse
	var hits: Array[Dictionary] = []
	var ends: Array[Vector3] = []
	# Each projectile: one ray per damage entry and the push, along its own direction.
	for direction in directions:
		var query := _query(from.origin, direction, data.max_range, exclude)
		var hit := space.intersect_ray(query)
		var falloff := 1.0
		ends.append(query.to if hit.is_empty() else hit["position"] as Vector3)
		if not hit.is_empty():
			hits.append(hit)
			falloff = data.damage_scale_at(from.origin.distance_to(hit["position"] as Vector3))
		for type: StringName in rays:
			var intensity := rays[type] * falloff if data.damage.has(type) else rays[type]
			var ray := Stimulus.make_ray(
				type, intensity, from.origin, direction, data.max_range, holder.user, PhysicsLayers.WEAPON_MASK
			)
			ray.exclude = exclude
			if data.damage.has(type):
				ray.scale_attribute = data.class_attribute("damage_mult")
			emit(holder, ray)
	emit(holder, Stimulus.make_noise(weapon_state.stat(&"fire_noise"), muzzle(holder), holder.user))
	holder.last_hit = {}
	var hit_name := ""
	if not hits.is_empty():
		# One impact noise and sound per shot, where the first projectile struck.
		var point: Vector3 = hits[0]["position"]
		var collider := hits[0]["collider"] as Node
		hit_name = String(collider.name)
		holder.last_hit = {"collider": collider, "position": point}
		emit(holder, Stimulus.make_noise(weapon_state.stat(&"impact_noise"), point, holder.user))
		holder.audio.play_hit(data, point)
	holder.feedback.shot(data, muzzle(holder), ends, hits, holder.tracer_every)
	aim.add_shot(spread_mult)
	holder.audio.play_shot(weapon_state)
	holder.flash.fire(data, weapon_state.stat(&"muzzle_flash_size"))
	var logged := {
		"weapon": data.id,
		"magazine": weapon_state.magazine,
		"spread": spread,
		"hit": hit_name,
		"projectiles": directions.size(),
		"hits": hits.size(),
		"noise": weapon_state.stat(&"fire_noise"),
	}
	log_event(holder, &"weapon.fired", logged)


## The first thing on the line through the centre of the aim cone (the holder's aim transform: sway
## and the unfollowed recoil) within the weapon's range: the intersect_ray() result, {} on nothing.
func aimed_hit(holder: WeaponHolder, data: WeaponData) -> Dictionary:
	var from := holder.aim_transform()
	var query := _query(from.origin, -from.basis.z, data.max_range, OwnBody.rids(holder.user))
	return holder.get_world_3d().direct_space_state.intersect_ray(query)


# A weapon ray from `origin` along `direction` over `reach` metres.
static func _query(
	origin: Vector3, direction: Vector3, reach: float, exclude: Array[RID]
) -> PhysicsRayQueryParameters3D:
	return PhysicsRayQueryParameters3D.create(origin, origin + direction * reach, PhysicsLayers.WEAPON_MASK, exclude)
