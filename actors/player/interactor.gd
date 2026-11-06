class_name Interactor
extends Node
## Component of the Player (ADR 0051): the one place that decides what E does. Every physics tick
## it casts one ray from the eyes (`interact_reach`, PhysicsLayers.INTERACT_MASK; a hitbox stands
## for its character) and resolves the thing hit by its components, in this order: ItemPickup
## (pick up), Usable (use), Carryable (carry, or "Too heavy"). While carrying, E puts down. The HUD
## shows `prompt`; perform() does it.

enum Kind { NONE, PICK_UP, USE, CARRY, TOO_HEAVY, PUT_DOWN }

var player: Player
var kind: Kind = Kind.NONE
## The entity the prompt is about (the pickup's / usable's / body's owner), or null.
var target: Node = null
## HUD text, "" when there is nothing to do.
var prompt: String = ""


## HUD prompt for an interaction kind with the target's name and count.
static func prompt_for(p_kind: Kind, target_name: String, count: int = 1, verb: String = "use") -> String:
	match p_kind:
		Kind.PICK_UP:
			return "E: pick up %s" % (target_name if count <= 1 else "%s (%d)" % [target_name, count])
		Kind.USE:
			return "E: %s %s" % [verb, target_name]
		Kind.CARRY:
			return "E: carry %s" % target_name
		Kind.TOO_HEAVY:
			return "Too heavy"
		Kind.PUT_DOWN:
			return "E: put down %s" % target_name
	return ""


## Readable name of a world entity: its `display_name` metadata, else its node name in words
## without a trailing number ("SmallCrate2" -> "Small crate").
static func display_name_of(node: Node) -> String:
	if node.has_meta(&"display_name"):
		return str(node.get_meta(&"display_name"))
	var words := String(node.name).capitalize()
	while not words.is_empty() and (words[-1].is_valid_int() or words[-1] == " "):
		words = words.left(-1)
	return words.left(1) + words.substr(1).to_lower()


## The entity a collider stands for: a hitbox's character, otherwise the collider itself.
static func entity_of(collider: Node) -> Node:
	if collider != null and Hitboxes.part_of(collider) != &"" and collider.get_parent() is Hitboxes:
		return collider.get_parent().get_parent()
	return collider


## Re-resolves the target under the crosshair (called by the Player every physics tick).
func refresh() -> void:
	kind = Kind.NONE
	target = null
	if not player.body.can_act():
		prompt = ""
		return
	if player.carry.is_carrying():
		_resolve(Kind.PUT_DOWN, player.carry.held, prompt_for(Kind.PUT_DOWN, display_name_of(player.carry.held)))
		return
	var entity := entity_of(_look_collider())
	if entity == null:
		prompt = ""
		return
	var pickup := ItemPickup.of(entity)
	var usable := Usable.of(entity)
	var body := entity as RigidBody3D
	if pickup != null and pickup.count > 0:
		_resolve(Kind.PICK_UP, entity, prompt_for(Kind.PICK_UP, pickup.item.display_name, pickup.count))
	elif usable != null:
		_resolve(Kind.USE, entity, prompt_for(Kind.USE, display_name_of(entity), 1, usable.verb))
	elif body != null and PlayerCarry.can_offer(body):
		var heavy := not CarryRules.can_carry(body.mass, player.carry.mass_limit())
		var carry_kind := Kind.TOO_HEAVY if heavy else Kind.CARRY
		_resolve(carry_kind, entity, prompt_for(carry_kind, display_name_of(entity)))
	else:
		prompt = ""


## E: does what the prompt says. Returns true when something happened.
func perform() -> bool:
	refresh()
	match kind:
		Kind.PICK_UP:
			return player.inventory.pick_up(ItemPickup.of(target))
		Kind.USE:
			return Usable.of(target).use(player)
		Kind.CARRY, Kind.TOO_HEAVY:
			return player.carry.try_pick_up_body(target as RigidBody3D)
		Kind.PUT_DOWN:
			player.carry.put_down()
			return true
	return false


func _resolve(p_kind: Kind, p_target: Node, text: String) -> void:
	kind = p_kind
	target = p_target
	prompt = text


func _look_collider() -> Node:
	var eye := player.eye_transform()
	var exclude: Array[RID] = [player.get_rid()]
	exclude.append_array(Hitboxes.rids_of(player))
	var query := PhysicsRayQueryParameters3D.create(
		eye.origin, eye.origin - eye.basis.z * player.config.interact_reach, PhysicsLayers.INTERACT_MASK, exclude
	)
	var hit := player.get_world_3d().direct_space_state.intersect_ray(query)
	return hit["collider"] as Node if not hit.is_empty() else null
