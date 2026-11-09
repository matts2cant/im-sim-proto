extends RefCounted
## Test helper (not a suite) for the route scenario tests on the warehouse roof (ADR 0097): when a
## careful player crosses duct B's forecourt. The forecourt is lit by the roof lamp and watched by
## the roof camera's sweep and, up through the east skylight, by the north catwalk's guard G4
## while it walks east along the catwalk's west half (x -10 to 1). Used with a
## WarehouseRouteDriver (`warehouse_route_driver.gd`).

const Driver := preload("res://tests/levels/mission/warehouse_route_driver.gd")
const CAMERA := "CameraRoof"
const G4 := "G4CatwalkRifle"


## The security camera `device_name` of the route's level.
static func camera(route: Driver, device_name: String) -> SecurityCamera:
	return SecurityCamera.of(route.level.get_node(Driver.DEVICES + "/" + device_name))


## True while camera `device_name` sweeps past `yaw` degrees from its rest yaw turning toward
## `direction` (1: its left, -1: its right), not holding: a spot on its other side then stays out
## of its view while it turns on to the end of its sweep, holds there and comes back.
static func camera_turning_past(route: Driver, device_name: String, yaw: float, direction: float) -> bool:
	var model := camera(route, device_name).model
	return (
		model.sweeping
		and model.direction == direction
		and (model.yaw - yaw) * direction > 0.0
		and model.hold_left <= CameraModel.EPSILON
	)


## True when the roof camera has just turned east, away from the forecourt (it looks back about 8 s
## later: rest yaw +-40 degrees at 15 degrees/s, a 2 s hold), and G4 is unaware and walking west
## (facing west; it then waits 3 s at its west end, 28 m from the forecourt, and needs about 4 s
## more to reach x -10) or already east of the catwalk's west half.
static func forecourt_clear(route: Driver) -> bool:
	if not camera_turning_past(route, CAMERA, -5.0, 1.0):
		return false
	var g4 := route.guard(G4)
	if not ActorState.can_act(g4) or GradedAwareness.of_node(g4).state() != AwarenessModel.State.UNAWARE:
		return false
	var heading := route.patrol_target(G4)
	return heading == "CatwalkB" or (heading == "CatwalkA" and g4.global_position.x > 2.0)


## Waits (at most `max_seconds` of game time) until forecourt_clear(); notes the camera and G4 when
## it never comes.
static func wait_for_forecourt(route: Driver, max_seconds: float = 90.0) -> bool:
	var clear := func() -> bool: return forecourt_clear(route)
	if await route.wait_until(clear, max_seconds, "duct B's forecourt to clear"):
		return true
	var model := camera(route, CAMERA).model
	var g4 := route.guard(G4)
	route.notes.append(
		(
			"%s yaw %.1f direction %.0f; G4 at %s heading %s"
			% [CAMERA, model.yaw, model.direction, g4.global_position, route.patrol_target(G4)]
		)
	)
	return false
