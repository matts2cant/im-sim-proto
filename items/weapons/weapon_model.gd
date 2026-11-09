class_name WeaponModel
extends Node3D
## Root of a weapon's model scene (ADR 0085), used both as the first-person view model
## (WeaponData.view_scene, under the WeaponHolder's grip pivot) and inside the weapon's world pickup.
## Points along -Z. `muzzle` marks the barrel's end (muzzle flash, shot noise); AttachmentMount
## children take fitted attachments' models; with a muzzle attachment fitted the muzzle moves to
## its end (AttachmentData.length). An ItemPickup fits the attachments its stack state records.

## Barrel end: the flash and the shot noise start here.
@export var muzzle: Node3D

var _fitted: Array[Node3D] = []
var _muzzle_end: Node3D


## Shows `attachments` at their mounts (replacing what was fitted before).
func fit(attachments: Array[AttachmentData]) -> void:
	for node in _fitted:
		node.free()
	_fitted.clear()
	if is_instance_valid(_muzzle_end):
		_muzzle_end.free()
	_muzzle_end = null
	for attachment in attachments:
		var mount := mount_for(attachment.slot)
		if mount == null:
			continue
		if attachment.model != null:
			var model := attachment.model.instantiate() as Node3D
			model.name = "Fitted_%s" % attachment.slot
			mount.add_child(model)
			_fitted.append(model)
		if mount.extends_muzzle and attachment.length > 0.0:
			_muzzle_end = Node3D.new()
			_muzzle_end.name = "MuzzleEnd"
			mount.add_child(_muzzle_end)
			_muzzle_end.position = Vector3(0, 0, -attachment.length)


## The mount of `slot`, or null.
func mount_for(slot: StringName) -> AttachmentMount:
	for node in find_children("*", "Marker3D", true, false):
		var mount := node as AttachmentMount
		if mount != null and mount.slot == slot:
			return mount
	return null


## Models fitted now (tests, screenshots).
func fitted_models() -> Array[Node3D]:
	return _fitted.duplicate()


## Where shots leave the weapon: the end of a fitted muzzle attachment, else `muzzle`, else the root.
func muzzle_point() -> Node3D:
	if is_instance_valid(_muzzle_end):
		return _muzzle_end
	return muzzle if muzzle != null else self


## Every mesh of the model and its attachments (the holder fades them while the user is cloaked).
func geometry() -> Array[GeometryInstance3D]:
	var result: Array[GeometryInstance3D] = []
	for node in find_children("*", "GeometryInstance3D", true, false):
		result.append(node as GeometryInstance3D)
	return result
