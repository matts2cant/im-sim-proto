extends RefCounted
## Test helper (not a suite): the hands of WarehouseRouteDriver's player: look at things (the view
## ray is corrected against the camera's real position), press E on them, read datapads, use doors
## from the player's side, swing and shoot, carry and put down bodies. Every action returns false
## and adds a note to the driver when it finds nothing to act on.

const Driver := preload("res://tests/levels/mission/warehouse_route_driver.gd")

var route: Driver
var _head: Node3D


func _init(p_route: Driver) -> void:
	route = p_route
	_head = route.player.get_node("Head") as Node3D


## The middle of the first collision shape under the level node at `path` (where to look to use
## it), else its origin.
func aim_point(path: String) -> Vector3:
	var node := route.level.get_node(path) as Node3D
	for shape in node.find_children("*", "CollisionShape3D", true, false):
		return (shape as Node3D).global_position
	return node.global_position


## Looks at the level node at `path` and presses E.
func use_node(path: String) -> bool:
	return await use_at(aim_point(path))


## The Door component of the door entity at `path` (a level node).
func door(path: String) -> Door:
	return route.level.get_node(path + "/Door") as Door


## Presses E on the control panel of the door at `path` (a level node) on the player's side of it
## (a grille's bars leave gaps the view ray passes through; the panel always takes it), walking up
## to it first when it is out of reach.
func use_door(path: String) -> bool:
	var entity := route.level.get_node(path) as Node3D
	var local := entity.global_transform.affine_inverse() * route.player.global_position
	var front := local.z > 0.0
	var panel := (entity.get_node("ControlFrontShape" if front else "ControlBackShape") as Node3D).global_position
	if route.player.eye_transform().origin.distance_to(panel) > 1.7:
		# Out of reach: walk up to 1.1 m in front of the panel, on this side of the door.
		var out := entity.global_basis.z * (1.1 if front else -1.1)
		var stand := Vector3(panel.x + out.x, route.player.global_position.y, panel.z + out.z)
		if not await route.go([stand]):
			return false
	return await use_at(panel)


## Reads the datapad at `path` (a level node) from where the player stands (E) and closes the
## reading.
func read(path: String) -> bool:
	if not await use_node(path):
		return false
	var overlay := route.player.get_node("ReadingOverlay") as ReadingOverlay
	if overlay.is_open():
		overlay.close()
	await route.frames(2)
	return true


## Turns the view to look at `point` (world).
func aim_at(point: Vector3) -> void:
	# The camera sits off the head's pivot: correct the turn a few times against its real ray.
	for i in 4:
		var eye := route.player.eye_transform()
		var to := point - eye.origin
		var forward := -eye.basis.z
		var yaw_error := atan2(-to.x, -to.z) - atan2(-forward.x, -forward.z)
		var pitch_error := (
			atan2(to.y, Vector2(to.x, to.z).length()) - atan2(forward.y, Vector2(forward.x, forward.z).length())
		)
		route.player.rotation.y = wrapf(route.player.rotation.y + wrapf(yaw_error, -PI, PI), -PI, PI)
		route.player.pitch += pitch_error
		_head.rotation.x = route.player.pitch


## Waits (at most a second) until the eyes stop moving: they ease to a new stance's height.
func settle_eyes() -> void:
	for i in 60:
		var before := route.player.eye_transform().origin
		await route.player.get_tree().physics_frame
		if route.player.eye_transform().origin.distance_to(before) < 0.001:
			return


## Presses and releases `action` (one press edge).
func press(action: StringName, hold: int = 2) -> void:
	route.runner.simulate_action_press(action)
	await route.frames(hold)
	route.runner.simulate_action_release(action)
	await route.frames(2)


## Looks at `point` and presses E.
func use_at(point: Vector3) -> bool:
	await settle_eyes()
	aim_at(point)
	await route.frames(2)
	var target := route.player.interactor.target
	if target == null:
		var hit := route.player.look_hit(3.0)
		route.notes.append(
			(
				"nothing to use at %s from %s: the view ray hits %s at %s"
				% [point, route.player.eye_transform().origin, hit.get("collider"), hit.get("position")]
			)
		)
		return false
	await press(&"use")
	return true


## Takes the belt item `item_id` in hand (its belt key); false when the belt has none.
func draw(item_id: StringName) -> bool:
	var inventory := route.player.inventory
	for index in inventory.belt.size():
		var stack := inventory.belt.stack_in(index)
		if stack == null or stack.item.id != item_id:
			continue
		if inventory.in_hand() != stack:
			await press(Player.BELT_ACTIONS[index])
		return inventory.in_hand() == stack
	route.notes.append("no %s on the belt" % item_id)
	return false


## Where to aim at `character`: its head hitbox (or its origin + 1.6 m).
static func head_of(character: Node3D) -> Vector3:
	var hitboxes := Hitboxes.of(character)
	if hitboxes != null:
		var head := hitboxes.box(&"head")
		if head != null:
			return head.global_position
	return character.global_position + Vector3.UP * 1.6


## True when a shot from the eyes at `point` would hit `character` first (weapon mask: world, props
## and hitboxes).
func clear_shot(character: Node3D, point: Vector3) -> bool:
	var eye := route.player.eye_transform().origin
	var query := PhysicsRayQueryParameters3D.create(
		eye, point + (point - eye).normalized() * 0.5, PhysicsLayers.WEAPON_MASK
	)
	query.exclude = _own_rids()
	var hit := route.player.get_world_3d().direct_space_state.intersect_ray(query)
	return not hit.is_empty() and Interactor.entity_of(hit["collider"] as Node) == character


## The first of `spots` (feet) from which a standing player's eyes have a clear shot at `point` on
## `target` (its first hit along the line is `target`), with 0.15 m to spare on both sides; the
## last spot when none has.
func shooting_spot(spots: Array[Vector3], target: Node3D, point: Vector3) -> Vector3:
	var space := route.player.get_world_3d().direct_space_state
	for feet in spots:
		var eye := feet + Vector3.UP * 1.65
		var side := (point - eye).cross(Vector3.UP).normalized() * 0.15
		var clear := true
		for offset: Vector3 in [-side, Vector3.ZERO, side]:
			var query := PhysicsRayQueryParameters3D.create(eye + offset, point, PhysicsLayers.WEAPON_MASK)
			query.exclude = _own_rids()
			var hit := space.intersect_ray(query)
			clear = clear and not hit.is_empty() and Interactor.entity_of(hit["collider"] as Node) == target
		if clear:
			return feet
	route.notes.append("no clear shot at %s from any spot" % target.name)
	return spots[-1]


## Holds the view on `point` until the aim cone stops narrowing (it widens while moving), at most
## 3 s.
func settle_aim(point: Vector3) -> void:
	var aim := route.player.weapons.aim
	for i in 180:
		aim_at(point)
		var before := aim.spread
		await route.frames(1)
		if aim.spread >= before - 0.0005:
			return


## Fires the weapon in hand once at `point` (when ready and the line to `target` is clear).
func shoot_at(target: Node3D, point: Vector3) -> bool:
	await settle_eyes()
	await settle_aim(point)
	for i in 240:
		aim_at(point)
		var state := route.player.weapons.state()
		if state != null and state.magazine == 0 and state.reload_left <= 0.0:
			await press(&"reload")
			continue
		if state != null and state.cooldown <= 0.0 and state.magazine > 0 and clear_shot(target, point):
			var target_name := String(target.name)
			await press(&"fire", 1)
			var hit := route.player.weapons.last_hit
			route.notes.append("shot at %s hit %s at %s" % [target_name, hit.get("collider"), hit.get("position")])
			return true
		await route.frames(1)
	route.notes.append("no shot at %s: %s" % [target.name, _shot_report(target)])
	return false


## Shoots the weapon in hand at `character`'s head until it cannot act or `max_seconds` pass:
## fires when the line is clear and the weapon is ready, reloads when the magazine is empty.
func shoot_down(character: Node3D, max_seconds: float = 6.0) -> bool:
	for i in roundi(max_seconds / route.TICK):
		if not ActorState.can_act(character):
			return true
		await _shoot_step(character)
	route.notes.append(
		"%s still up after %.0f s of shooting: %s" % [character.name, max_seconds, _shot_report(character)]
	)
	return false


## Holds the position with the weapon in hand and shoots every guard that can act, is Searching or
## Alerted and stands in a clear line within `max_range` (nearest first), until `done` (no
## arguments, returns bool) holds or `max_seconds` pass.
func fight(done: Callable, max_seconds: float, max_range: float = 30.0) -> bool:
	for i in roundi(max_seconds / route.TICK):
		if done.call():
			return true
		var target := _nearest_threat(max_range)
		if target == null:
			await route.player.get_tree().physics_frame
		else:
			await _shoot_step(target)
	if done.call():
		return true
	route.notes.append("fight not over after %.0f s" % max_seconds)
	return false


## Swings the melee weapon in hand at `character` (its torso) once.
func swing_at(character: Node3D) -> void:
	aim_at(character.global_position + Vector3.UP * 1.2)
	await route.frames(1)
	await press(&"fire")


## Carries the downed body `character` (E on it).
func carry(character: Node3D) -> bool:
	await use_at(character.global_position + Vector3.UP * 0.2)
	await route.frames(2)
	if not route.player.carry.is_carrying():
		route.notes.append("not carrying %s" % character.name)
		return false
	return true


## Puts down what the player carries (the drop key), looking level along `yaw` (the held object
## hangs in front of the view: looking down would set it at the feet).
func put_down(yaw: float) -> bool:
	route.player.rotation.y = yaw
	route.player.pitch = 0.0
	_head.rotation.x = 0.0
	await route.frames(10)
	await press(&"drop_throw")
	await route.frames(10)
	if route.player.carry.is_carrying():
		route.notes.append("could not put down: '%s'" % route.player.interactor.prompt)
		return false
	return true


# What a shot at `character`'s head would hit first, and the weapon's state.
func _shot_report(character: Node3D) -> String:
	var eye := route.player.eye_transform().origin
	var point := head_of(character)
	var query := PhysicsRayQueryParameters3D.create(
		eye, point + (point - eye).normalized() * 0.5, PhysicsLayers.WEAPON_MASK
	)
	query.exclude = _own_rids()
	var hit := route.player.get_world_3d().direct_space_state.intersect_ray(query)
	var state := route.player.weapons.state()
	return (
		"from %s to %s the ray hits %s at %s; weapon %s magazine %d"
		% [
			eye,
			point,
			hit.get("collider"),
			hit.get("position"),
			route.player.weapons.weapon(),
			state.magazine if state != null else -1
		]
	)


# The player's body and hitboxes (a shot never hits its own shooter).
func _own_rids() -> Array[RID]:
	var rids: Array[RID] = [route.player.get_rid()]
	rids.append_array(Hitboxes.rids_of(route.player))
	return rids


func _nearest_threat(max_range: float) -> Node3D:
	var best: Node3D = null
	var best_distance := INF
	for node in route.guards():
		var character := node as Node3D
		var awareness := GradedAwareness.of_node(character)
		if not ActorState.can_act(character) or awareness == null or not awareness.is_aware():
			continue
		var distance := character.global_position.distance_to(route.player.global_position)
		if distance < best_distance and distance < max_range and clear_shot(character, head_of(character)):
			best = character
			best_distance = distance
	return best


func _shoot_step(character: Node3D) -> void:
	var weapons := route.player.weapons
	var state := weapons.state()
	if state == null:
		await route.player.get_tree().physics_frame
		return
	if state.magazine == 0 and state.reload_left <= 0.0:
		await press(&"reload")
		return
	var point := head_of(character)
	aim_at(point)
	if state.cooldown <= 0.0 and state.reload_left <= 0.0 and state.magazine > 0 and clear_shot(character, point):
		route.runner.simulate_action_press(&"fire")
		await route.player.get_tree().physics_frame
		route.runner.simulate_action_release(&"fire")
	await route.player.get_tree().physics_frame


## Logs in at the terminal entity at `path` (E on it) with the credentials the player's personal log
## knows (the screen fills them in), sends each [command, device entity path] of `commands` from
## its screen and closes it. False when a step fails.
func run_terminal(path: String, commands: Array) -> bool:
	if not await use_node(path):
		return false
	var screen := TerminalScreen.of(route.player)
	if screen == null or not screen.is_open():
		route.notes.append("no terminal screen at %s" % path)
		return false
	screen.fill_in()
	screen.submit_login()
	await route.frames(2)
	var ok := screen.terminal != null and screen.terminal.logged_in
	if not ok:
		route.notes.append("login refused at %s" % path)
	for entry: Array in commands:
		var device := Device.of(route.level.get_node(String(entry[1])))
		if ok and device != null:
			screen.press(entry[0] as StringName, device)
			await route.frames(2)
	screen.close()
	await route.frames(2)
	return ok
