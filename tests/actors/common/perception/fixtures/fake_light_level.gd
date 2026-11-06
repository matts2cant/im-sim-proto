extends Node
## Test fixture: stands in for the light system's component (a child of a lit entity in group
## `light_exposure` with a public `level` in [0, 1]) until the two branches merge.

var level: float = 1.0


func _init() -> void:
	add_to_group(&"light_exposure")
