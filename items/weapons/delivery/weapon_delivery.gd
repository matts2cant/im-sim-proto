class_name WeaponDelivery
extends RefCounted
## How a fired trigger reaches the world, one per WeaponData.Kind (WeaponData.delivery()): RangedFire
## (rays along the aim cone), MeleeSweep (a sphere swept along the view), ThrowRelease (the user's
## Thrower). The WeaponHolder coordinates the shot (who may fire, the cycle, ammo, the view's kick,
## recoil, `fired`) and hands the delivery itself; the delivery emits the stimuli, plays the sounds
## (WeaponHolder.audio), leaves the feedback (WeaponHolder.feedback), sets WeaponHolder.last_hit and
## logs it. Stateless: one instance serves every holder.


## False when the trigger cannot do anything now (a throw without a Thrower); the holder then does
## not cycle the weapon.
func can_deliver(_holder: WeaponHolder, _data: WeaponData) -> bool:
	return true


## Delivers one fired trigger pull of `data`, the holder's equipped weapon.
func deliver(_holder: WeaponHolder, _data: WeaponData) -> void:
	pass


## What the weapon's aim is on now (the crosshair's target): {} for a weapon that does not aim rays.
func aimed_hit(_holder: WeaponHolder, _data: WeaponData) -> Dictionary:
	return {}


## Emits `stimulus` with the holder's cause (WeaponHolder.cause_id) when one is set.
static func emit(holder: WeaponHolder, stimulus: Stimulus) -> void:
	if holder.cause_id != 0:
		stimulus.cause_id = holder.cause_id
	StimulusSystem.emit(stimulus)


## Where the shot leaves: the view model's muzzle while it shows, else the eye.
static func muzzle(holder: WeaponHolder) -> Vector3:
	var view := holder.view_pivot()
	if view.visible:
		return view.muzzle_position()
	return holder.eye.global_position


## Records `kind` in the EventLog with the holder's user as the source.
static func log_event(holder: WeaponHolder, kind: StringName, data: Dictionary) -> void:
	var source := String(holder.user.name) if is_instance_valid(holder.user) else ""
	EventLog.record(kind, source, "", data)
