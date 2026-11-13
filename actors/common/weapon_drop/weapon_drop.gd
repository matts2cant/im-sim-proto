class_name WeaponDrop
extends Node
## Component of any character with a WeaponHolder (ADR 0087): once the character can no longer act
## (`state.dead` or `state.unconscious`, ActorState.can_act, from any source), every weapon of the
## holder's fixed loadout leaves the holder as its item (WeaponData.item_id in the ItemCatalog) with
## its current magazine: into the character's own Inventory when it has one with room (ADR 0142: a
## downed guard is looted for it; EventLog `weapon.stowed`), else as a world pickup beside the body.
## The holder no longer has it (WeaponHolder.remove_from_loadout()), so a woken character stays
## unarmed (CombatBehaviour does not engage without a loadout).
## Weapons armed from an inventory (WeaponHolder.equip_state(), the player's) belong to that
## inventory and stay in it: only weapons the holder owns are dropped.
## The pickup is added next to the character (under its parent, so saves keep it as a spawned
## entity), `side_distance` to its right at `drop_height` (left, then at its feet, when a wall is in
## the way), with a small sideways toss. A weapon without an item (a turret's gun) is not dropped.
## Polled every physics tick, so a quickload (tree paused while the holder restores its saved
## loadout) never drops twice. EventLog: `weapon.dropped {actor, weapon, item, magazine}`,
## `weapon.stowed {actor, weapon, item, magazine}`.

@export var holder_path: NodePath = ^"../Aim/WeaponHolder"
@export var entity_path: NodePath = ^".."
@export var catalog: ItemCatalog
## Centre of the body to centre of the pickup, sideways (m).
@export var side_distance: float = 0.6
## Spawn height above the character's feet (m).
@export var drop_height: float = 0.4
## Sideways speed given to the pickup (m/s).
@export var toss_speed: float = 0.8

var entity: Node3D
var holder: WeaponHolder


static func of(node: Node) -> WeaponDrop:
	if node == null:
		return null
	for child in node.get_children():
		if child is WeaponDrop:
			return child as WeaponDrop
	return null


func _ready() -> void:
	entity = Entities.of_component(self, entity_path) as Node3D
	holder = get_node_or_null(holder_path) as WeaponHolder
	if catalog == null:
		catalog = ItemCatalog.default()
	if entity == null or holder == null:
		push_warning("WeaponDrop %s: needs an entity and a WeaponHolder" % get_path())
		set_physics_process(false)


func _physics_process(_delta: float) -> void:
	if ActorState.can_act(entity) or holder.states.is_empty() or _leaving():
		return
	drop_all()


# The character or the level it is in is on its way out (freed with its level): nothing to drop.
func _leaving() -> bool:
	var node: Node = entity
	while node != null:
		if node.is_queued_for_deletion():
			return true
		node = node.get_parent()
	return false


## Takes every fixed-loadout weapon from the holder: into the character's Inventory when it fits,
## else dropped beside the body. Returns the dropped pickups' bodies.
func drop_all() -> Array[RigidBody3D]:
	var bodies: Array[RigidBody3D] = []
	var loadout: Array[WeaponState] = holder.states.duplicate()
	for weapon_state in loadout:
		var item := _item_of(weapon_state)
		if item != null and _stow(weapon_state, item):
			continue
		var body := _drop(weapon_state, item, bodies.size())
		if body != null:
			bodies.append(body)
	return bodies


func _item_of(weapon_state: WeaponState) -> ItemData:
	return catalog.find(weapon_state.data.item_id) if not weapon_state.data.item_id.is_empty() else null


func _state_of(weapon_state: WeaponState) -> Dictionary:
	return {ItemStack.MAGAZINE: weapon_state.magazine} if weapon_state.data.uses_ammo() else {}


# Into the character's own Inventory (with its magazine); false when it has none or no room.
func _stow(weapon_state: WeaponState, item: ItemData) -> bool:
	var inventory := Inventory.of(entity)
	if inventory == null or inventory.add(item, 1, _state_of(weapon_state)) > 0:
		return false
	holder.remove_from_loadout(weapon_state)
	EventLog.record(EventKinds.WEAPON_STOWED, String(entity.name), "", _log_data(weapon_state, item))
	return true


func _drop(weapon_state: WeaponState, item: ItemData, index: int) -> RigidBody3D:
	if item == null or item.world_scene.is_empty() or entity.get_parent() == null:
		holder.remove_from_loadout(weapon_state)
		return null
	var body := (load(item.world_scene) as PackedScene).instantiate() as RigidBody3D
	var pickup := ItemPickup.of(body)
	pickup.item = item
	pickup.count = 1
	if weapon_state.data.uses_ammo():
		pickup.state = _state_of(weapon_state)
	var side := _side()
	entity.get_parent().add_child(body, true)
	body.global_transform = Transform3D(entity.global_basis, _drop_point(side, index))
	body.linear_velocity = side * toss_speed
	holder.remove_from_loadout(weapon_state)
	EventLog.record(EventKinds.WEAPON_DROPPED, String(entity.name), String(body.name), _log_data(weapon_state, item))
	return body


func _log_data(weapon_state: WeaponState, item: ItemData) -> Dictionary:
	return {
		"actor": String(entity.name),
		"weapon": String(weapon_state.data.id),
		"item": String(item.id),
		"magazine": weapon_state.magazine,
	}


# The character's right, flat.
func _side() -> Vector3:
	var right := entity.global_basis.x
	right.y = 0.0
	return right.normalized() if right.length_squared() > 0.0001 else Vector3.RIGHT


# Beside the body (right, else left, else at its feet) where no wall or object is in the way from
# its chest. Further weapons go a little further out.
func _drop_point(side: Vector3, index: int) -> Vector3:
	var feet := entity.global_position
	var chest := feet + Vector3.UP * 1.0
	var reach := side_distance + 0.3 * index
	var space := entity.get_world_3d().direct_space_state
	var mask := PhysicsLayers.WORLD | PhysicsLayers.OBJECTS
	for direction: Vector3 in [side, -side]:
		var point := feet + Vector3.UP * drop_height + direction * reach
		if PhysicsLayers.segment_clear(space, chest, point, mask):
			return point
	return feet + Vector3.UP * drop_height
