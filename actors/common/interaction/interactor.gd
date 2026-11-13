class_name Interactor
extends Node
## Component of any character (ADR 0051, ADR 0139; the player's E): the one place that decides what
## "use" does. Its controller calls refresh() every physics tick: one ray from the character's Eyes
## (`config.reach`, PhysicsLayers.INTERACT_MASK; a hitbox stands for its character) and the thing
## hit resolved by its components, in this order: ItemPickup (pick up, into the character's
## Inventory), Usable (use; a Readable is read in place, ADR 0060), Carryable (carry with the
## character's Carrier, or "Too heavy"). While carrying, use puts down ("No room" when the Carrier has
## no free spot to release into, ADR 0053). perform() does it. A character without an Inventory or a
## Carrier is offered nothing those would do. `prompt` stays as data (tests, logs): the HUD no longer
## shows it (ADR 0130); the interaction frame names the target and the failures go to the
## character's Notices. A
## Usable may write its whole prompt (`Usable.prompt()`: a door's "Locked: keycard") or be
## unavailable (`Usable.available()`: a broken door). `looked_at` is the entity under the crosshair
## within reach (ToolUse works a held tool on it, ADR 0078; the frame shows devices, powered things
## and characters there).

enum Kind { NONE, PICK_UP, USE, CARRY, TOO_HEAVY, PUT_DOWN, NO_ROOM }

const TOO_HEAVY := "Too heavy"
const NO_ROOM := "No room to put down"
const DEFAULT_CONFIG: InteractorConfig = preload("res://actors/common/interaction/interactor.tres")

@export var config: InteractorConfig = DEFAULT_CONFIG
@export var entity_path: NodePath = ^".."

## The character (`entity_path`).
var entity: Node3D
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


func _ready() -> void:
	entity = get_node_or_null(entity_path) as Node3D
	if config == null:
		config = DEFAULT_CONFIG


static func of(node: Node) -> Interactor:
	if node == null or not is_instance_valid(node):
		return null
	for child in node.get_children():
		if child is Interactor:
			return child as Interactor
	return null


## Readable name of a world entity: a network device's network name (NetworkSource.display_name(), as
## the deck's Map and its name plate show it: "SW-OFFICE"), else its `display_name` metadata, else its
## node name in words without a trailing number ("SmallCrate2" -> "Small crate").
static func display_name_of(node: Node) -> String:
	var device := Device.of(node)
	if device != null:
		return NetworkSource.display_name(device)
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


## Re-resolves the target under the crosshair (called by the character's controller every physics
## tick).
func refresh() -> void:
	kind = Kind.NONE
	target = null
	target_name = ""
	looked_at = null
	if not ActorState.can_act(entity):
		prompt = ""
		return
	var carrier := Carrier.of(entity)
	if carrier != null and carrier.is_carrying():
		var carry_kind := Kind.PUT_DOWN if carrier.has_room() else Kind.NO_ROOM
		var held_name := display_name_of(carrier.held)
		_resolve(carry_kind, carrier.held, prompt_for(carry_kind, held_name), held_name)
		return
	var seen := entity_of(_look_collider())
	looked_at = seen
	if seen == null:
		prompt = ""
		return
	var pickup := ItemPickup.of(seen) if Inventory.of(entity) != null else null
	var usable := Usable.of(seen)
	if usable != null and not usable.available(entity):
		usable = null
	var body := seen as PhysicsBody3D
	if pickup != null and pickup.count > 0:
		var item_name := pickup.item.display_name
		_resolve(
			Kind.PICK_UP, seen, prompt_for(Kind.PICK_UP, item_name, pickup.count), counted_name(item_name, pickup.count)
		)
	elif usable != null:
		# A network device goes by its network name (the frame, the Map and its plate agree).
		var usable_name := usable.target_name() if Device.of(seen) == null else ""
		if usable_name.is_empty():
			usable_name = display_name_of(seen)
		var text := usable.prompt(entity)
		if text.is_empty():
			text = prompt_for(Kind.USE, usable_name, 1, usable.verb)
		_resolve(Kind.USE, seen, text, usable_name)
	elif body != null and carrier != null and Carrier.can_offer(body):
		var heavy := not CarryRules.can_carry(Carryable.mass_of(body), carrier.mass_limit())
		var carry_kind := Kind.TOO_HEAVY if heavy else Kind.CARRY
		var body_name := display_name_of(seen)
		_resolve(carry_kind, seen, prompt_for(carry_kind, body_name), body_name)
	else:
		prompt = ""


## E: does what the prompt says. Returns true when something happened. When it did nothing, a
## short `message` says why (ADR 0130): what opens a locked thing (Usable.refusal()), why a usable
## is unavailable (Usable.unavailable_reason(): "Broken", "No power"), "Too heavy", "No room to put
## down". (A full inventory says so itself.)
func perform() -> bool:
	refresh()
	var done := false
	var why := ""
	match kind:
		Kind.PICK_UP:
			return Inventory.of(entity).pick_up(ItemPickup.of(target))
		Kind.USE:
			var usable := Usable.of(target)
			done = usable.use(entity)
			why = usable.refusal(entity) if not done else ""
		Kind.CARRY, Kind.TOO_HEAVY:
			done = Carrier.of(entity).try_pick_up_body(target as PhysicsBody3D)
			why = TOO_HEAVY if not done else ""
		Kind.PUT_DOWN, Kind.NO_ROOM:
			done = Carrier.of(entity).put_down()
			why = NO_ROOM if not done else ""
		Kind.NONE:
			var idle := Usable.of(looked_at)
			if idle != null and not idle.available(entity):
				why = idle.unavailable_reason(entity)
	if not why.is_empty():
		Notices.send(entity, why)
	return done


func _resolve(p_kind: Kind, p_target: Node, text: String, p_name: String) -> void:
	kind = p_kind
	target = p_target
	prompt = text
	target_name = p_name


## The entity under the crosshair within `reach` m (a hitbox's character), or null: what a ranged
## tool is aimed at (ToolUse, ADR 0117). One ray, cast only when asked.
func aimed_at(reach: float) -> Node:
	var carrier := Carrier.of(entity)
	if not ActorState.can_act(entity) or (carrier != null and carrier.is_carrying()):
		return null
	return entity_of(_look_collider(reach))


func _look_collider(reach: float = -1.0) -> Node:
	var eye := Eyes.view_of(entity)
	var length := reach if reach > 0.0 else config.reach
	var query := PhysicsRayQueryParameters3D.create(
		eye.origin, eye.origin - eye.basis.z * length, PhysicsLayers.INTERACT_MASK, OwnBody.rids(entity)
	)
	var hit := entity.get_world_3d().direct_space_state.intersect_ray(query)
	return hit["collider"] as Node if not hit.is_empty() else null
