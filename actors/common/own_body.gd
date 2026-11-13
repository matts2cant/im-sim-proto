class_name OwnBody
extends RefCounted
## What a character's own rays leave out (audit Q10): its body and its hitboxes (Hitboxes, ADR
## 0047), so a shot, a melee sweep, a line-of-fire check, an interaction ray or the crosshair's
## target never stop on whoever casts them. One rule for every caster: weapon holders, combat,
## turrets, the Interactor.


## RIDs of `entity`'s own body (when it is a CollisionObject3D) and of every hitbox under it; empty
## for a freed or null entity.
static func rids(entity: Node) -> Array[RID]:
	var result: Array[RID] = []
	if not is_instance_valid(entity):
		return result
	if entity is CollisionObject3D:
		result.append((entity as CollisionObject3D).get_rid())
	result.append_array(Hitboxes.rids_of(entity))
	return result
