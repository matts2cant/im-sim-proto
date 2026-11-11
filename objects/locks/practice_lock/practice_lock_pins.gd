class_name PracticeLockPins
extends Node3D
## The visible pins of a see-through lock prop (the acrylic practice lock): one key pin and one
## driver per pin of the entity's MechanicalLock (its pin_count(): a practice lock's tier), side by
## side `spacing` m apart and centred on this node, built at ready. Their heights are only a look:
## they change when a practice lock re-locks with a new layout. Knows nothing about tiers or
## specific locks; any entity with a MechanicalLock can show its pins this way.

## Mesh of a key pin (centred, along Y).
@export var key_pin_mesh: Mesh
## Mesh of a driver pin (centred, along Y).
@export var driver_mesh: Mesh
## Centre to centre distance between neighbouring pins (m, along X).
@export var spacing: float = 0.03
## Centre height of a key pin at its lowest (m); key pins rise up to `key_pin_rise` above it.
@export var key_pin_low: float = -0.015
@export var key_pin_rise: float = 0.012
## Gap between a key pin's top and its driver's bottom (m).
@export var driver_gap: float = 0.002
@export var entity_path: NodePath = ^".."

var _lock: MechanicalLock = null
var _key_pins: Array[MeshInstance3D] = []
var _drivers: Array[MeshInstance3D] = []


func _ready() -> void:
	_lock = _mechanical_lock(get_node_or_null(entity_path))
	if _lock == null:
		return
	_build(_lock.pin_count())
	_lock.relocked.connect(_on_relocked)


## Pins shown (one key pin and one driver each).
func shown_count() -> int:
	return _key_pins.size()


## The key pins, left to right.
func key_pins() -> Array[MeshInstance3D]:
	return _key_pins


static func _mechanical_lock(entity: Node) -> MechanicalLock:
	for lock in Lock.locks_of(entity):
		if lock is MechanicalLock:
			return lock as MechanicalLock
	return null


func _build(count: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	var left := -spacing * (count - 1) * 0.5
	for index in count:
		var key_pin := MeshInstance3D.new()
		key_pin.name = "KeyPin%d" % (index + 1)
		key_pin.mesh = key_pin_mesh
		add_child(key_pin)
		var driver := MeshInstance3D.new()
		driver.name = "Driver%d" % (index + 1)
		driver.mesh = driver_mesh
		add_child(driver)
		_key_pins.append(key_pin)
		_drivers.append(driver)
		key_pin.position.x = left + spacing * index
		driver.position.x = key_pin.position.x
	_lay_out(rng)


# Key pins at random heights, each driver resting on its key pin.
func _lay_out(rng: RandomNumberGenerator) -> void:
	for index in _key_pins.size():
		var key_pin := _key_pins[index]
		key_pin.position.y = key_pin_low + rng.randf() * key_pin_rise
		var key_top := key_pin.position.y + _half_height(key_pin_mesh)
		_drivers[index].position.y = key_top + driver_gap + _half_height(driver_mesh)


func _on_relocked(layout: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = layout
	_lay_out(rng)


static func _half_height(mesh: Mesh) -> float:
	return mesh.get_aabb().size.y * 0.5 if mesh != null else 0.0
