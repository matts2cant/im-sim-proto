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
## (a grille's bars leave gaps the view ray passes through; the panel always takes it).
func use_door(path: String) -> bool:
	var entity := route.level.get_node(path) as Node3D
	var local := entity.global_transform.affine_inverse() * route.player.global_position
	var side := "ControlFrontShape" if local.z > 0.0 else "ControlBackShape"
	return await use_at((entity.get_node(side) as Node3D).global_position)


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
