extends RefCounted
## Test helper (not a suite): the waits the suites share, instead of a copy in each suite.
## Wait for physics frames (game time), never for a count of process frames standing in for time
## (design/tech/testing.md "Writing fast tests").


## Waits `count` physics frames of `tree` (1/60 s of game time each, at any time factor).
static func frames(tree: SceneTree, count: int) -> void:
	for i in count:
		await tree.physics_frame
