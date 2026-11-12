class_name Interactor
extends Node
## Component of the Player (ADR 0051): the one place that decides what E does. Every physics tick
## it casts one ray from the eyes (`interact_reach`, PhysicsLayers.INTERACT_MASK; a hitbox stands
## for its character) and resolves the thing hit by its components, in this order: ItemPickup
## (pick up), Usable (use; a Readable is read in place, ADR 0060), Carryable (carry, or "Too
## heavy"). While carrying, E puts down ("No room" when PlayerCarry has no free spot to release
## into, ADR 0053). The HUD shows `prompt`; perform() does it. A Usable may write its whole prompt
## (`Usable.prompt()`: a door's "Locked: keycard") or be unavailable (`Usable.available()`: a broken
## door). `looked_at` is the entity under the crosshair (ToolUse works a held tool on it, ADR 0078).

enum Kind { NONE, PICK_UP, USE, CARRY, TOO_HEAVY, PUT_DOWN, NO_ROOM }

var player: Player
var kind: Kind = Kind.NONE
## The entity the prompt is about (the pickup's / usable's / body's owner), or null.
var target: Node = null
## HUD text, "" when there is nothing to do.
var prompt: String = ""
## The name the prompt uses for `target` (a stack's count included: "Lockpick (3)"), "" without one.
## The HUD's interaction frame shows it (ADR 0129).
var target_name: String = ""
## The entity under the crosshair within reach (a hitbox's character), or null; null while carrying.
var looked_at: Node = null


## HUD prompt for an interaction kind with the target's name and count.
static func prompt_for(p_kind: Kind, target_name: String, count: int = 1, verb: String = "use") -> String:
	match p_kind:
		Kind.PICK_UP:
			return "E: pick up %s" % counted_name(target_name, count)
		Kind.USE:
			return "E: %s %s" % [verb, target_name]
		Kind.CARRY:
			return "E: carry %s" % target_name
		Kind.TOO_HEAVY:
			return "Too heavy"
		Kind.PUT_DOWN:
			return "E: put down %s" % target_name
		Kind.NO_ROOM:
			return "No room to put down %s" % target_name
	return ""


## A stack's name with its count when above 1 ("Lockpick (3)").
static func counted_name(item_name: String, count: int) -> String:
	return item_name if count <= 1 else "%s (%d)" % [item_name, count]


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
	target_name = ""
	looked_at = null
	if not ActorState.can_act(player):
		prompt = ""
		return
	if player.carry.is_carrying():
		var carry_kind := Kind.PUT_DOWN if player.carry.has_room() else Kind.NO_ROOM
		var held_name := display_name_of(player.carry.held)
		_resolve(carry_kind, player.carry.held, prompt_for(carry_kind, held_name), held_name)
		return
	var entity := entity_of(_look_collider())
	looked_at = entity
	if entity == null:
		prompt = ""
		return
	var pickup := ItemPickup.of(entity)
	var usable := Usable.of(entity)
	if usable != null and not usable.available(player):
		usable = null
	var body := entity as PhysicsBody3D
	if pickup != null and pickup.count > 0:
		var item_name := pickup.item.display_name
		_resolve(
			Kind.PICK_UP,
			entity,
			prompt_for(Kind.PICK_UP, item_name, pickup.count),
			counted_name(item_name, pickup.count)
		)
	elif usable != null:
		var usable_name := usable.target_name()
		if usable_name.is_empty():
			usable_name = display_name_of(entity)
		var text := usable.prompt(player)
		if text.is_empty():
			text = prompt_for(Kind.USE, usable_name, 1, usable.verb)
		_resolve(Kind.USE, entity, text, usable_name)
	elif body != null and PlayerCarry.can_offer(body):
		var heavy := not CarryRules.can_carry(Carryable.mass_of(body), player.carry.mass_limit())
		var carry_kind := Kind.TOO_HEAVY if heavy else Kind.CARRY
		var body_name := display_name_of(entity)
		_resolve(carry_kind, entity, prompt_for(carry_kind, body_name), body_name)
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
			return player.carry.try_pick_up_body(target as PhysicsBody3D)
		Kind.PUT_DOWN, Kind.NO_ROOM:
			return player.carry.put_down()
	return false


func _resolve(p_kind: Kind, p_target: Node, text: String, p_name: String) -> void:
	kind = p_kind
	target = p_target
	prompt = text
	target_name = p_name


## The entity under the crosshair within `reach` m (a hitbox's character), or null: what a ranged
## tool is aimed at (ToolUse, ADR 0117). One ray, cast only when asked.
func aimed_at(reach: float) -> Node:
	if not ActorState.can_act(player) or player.carry.is_carrying():
		return null
	return entity_of(_look_collider(reach))


func _look_collider(reach: float = -1.0) -> Node:
	var eye := player.eye_transform()
	var exclude: Array[RID] = [player.get_rid()]
	exclude.append_array(Hitboxes.rids_of(player))
	var length := reach if reach > 0.0 else player.config.interact_reach
	var query := PhysicsRayQueryParameters3D.create(
		eye.origin, eye.origin - eye.basis.z * length, PhysicsLayers.INTERACT_MASK, exclude
	)
	var hit := player.get_world_3d().direct_space_state.intersect_ray(query)
	return hit["collider"] as Node if not hit.is_empty() else null
