extends "res://tests/actors/player/player_driver.gd"
## Test helper (not a suite): drives the player on the movement course in course-local coordinates.
## The walkthrough suites load the course alone with a player (fixtures/course_with_player.tscn):
## the course's geometry is what they test, the hub around it only costs load and frame time.

const FIXTURE := "res://tests/levels/gallery/movement/fixtures/course_with_player.tscn"

var course: Node3D


func _init(p_runner: GdUnitSceneRunner) -> void:
	super(p_runner)
	course = runner.find_child("MovementCourse") as Node3D


## Puts the player at rest at a course-local position facing `yaw`, lets it land, clears the log.
func place_local(local_position: Vector3, yaw: float = 0.0) -> void:
	await place(course.to_global(local_position), yaw)


## The player's position in course space.
func local() -> Vector3:
	return course.to_local(player.global_position)


## The player's own footsteps (other characters log theirs too: EventLog source = body name).
func player_steps() -> Array[EventLogEntry]:
	var steps: Array[EventLogEntry] = []
	for step in EventLog.find(&"actor.footstep"):
		if step.source == String(player.name):
			steps.append(step)
	return steps
