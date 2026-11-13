class_name ThrowRelease
extends WeaponDelivery
## A thrown weapon (WeaponData.Kind.THROWN, a grenade; ADR 0131): the user's Thrower sticks it on
## the surface in front of the eye or throws it; a whoosh (the fire sound) and its small noise
## (`fire_noise`) at the eye. Without a Thrower the trigger does nothing (can_deliver()). Whoever owns
## the stack takes one off on WeaponHolder.fired. Logs `weapon.thrown`.


func can_deliver(holder: WeaponHolder, _data: WeaponData) -> bool:
	return Thrower.of(holder.user) != null


func deliver(holder: WeaponHolder, data: WeaponData) -> void:
	var weapon_state := holder.state()
	var outcome := Thrower.of(holder.user).release(data)
	var noise := weapon_state.stat(&"fire_noise")
	if noise > 0.0:
		emit(holder, Stimulus.make_noise(noise, holder.eye.global_position, holder.user))
	holder.audio.play_fire(weapon_state)
	log_event(holder, EventKinds.WEAPON_THROWN, {"weapon": data.id, "outcome": outcome})
