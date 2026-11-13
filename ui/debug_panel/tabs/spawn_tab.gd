class_name SpawnTab
extends VBoxContainer
## Debug panel tab: spawns catalogue objects in front of the player, pokes the object under the
## crosshair (ignite with a strong CONTACT `fire`, hit with `damage.blunt`), resets the level, and
## gives items from the item catalogue to the player's inventory (one, or a full stack). Grenade
## effects at the crosshair (M14b): a gas cloud, an EMP pulse, a jamming field.

const CATALOG: ObjectCatalog = preload("res://objects/object_catalog.tres")
const GAS_CLOUD: PackedScene = preload("res://objects/explosives/gas_cloud/gas_cloud.tscn")
const JAMMING_FIELD: PackedScene = preload("res://objects/explosives/jamming_field/jamming_field.tscn")
const EMP: EmpConfig = preload("res://objects/explosives/emp/emp.tres")
const ITEMS: ItemCatalog = preload("res://items/item_catalog.tres")
## Horizontal distance in front of the player where objects appear.
const SPAWN_DISTANCE: float = 2.0
## Physics objects (origin at their centre) appear this high above the feet and drop.
const SPAWN_LIFT: float = 0.7
const LOOK_LENGTH: float = 20.0
const IGNITE_INTENSITY: float = 100.0
const DAMAGE_AMOUNT: float = 10.0

@onready var _buttons: GridContainer = $Buttons
@onready var _ignite: Button = $Actions/Ignite
@onready var _damage: Button = $Actions/Damage
@onready var _reset: Button = $Actions/Reset
@onready var _status: Label = $Status
@onready var _items: GridContainer = $Items


func _ready() -> void:
	for scene in CATALOG.scenes:
		var button := Button.new()
		button.text = ObjectCatalog.label_of(scene)
		button.name = button.text.capitalize().replace(" ", "")
		button.pressed.connect(spawn.bind(scene))
		_buttons.add_child(button)
	_ignite.pressed.connect(ignite_looked_at)
	_damage.pressed.connect(damage_looked_at)
	_reset.pressed.connect(reset_level)
	var effects: Dictionary[String, Callable] = {
		"Gas": spawn_effect.bind(GAS_CLOUD), "Emp": emp_looked_at, "Jam": spawn_effect.bind(JAMMING_FIELD)
	}
	for label: String in effects:
		var button := Button.new()
		button.name = label
		button.text = label.to_upper() if label == "Emp" else label
		button.tooltip_text = "At the crosshair"
		button.pressed.connect(effects[label])
		_ignite.get_parent().add_child(button)
	for item in ITEMS.items:
		var label := Label.new()
		label.text = item.display_name
		_items.add_child(label)
		var one := Button.new()
		one.name = "Give%s" % String(item.id).to_pascal_case()
		one.text = "+1"
		one.pressed.connect(give.bind(item, 1))
		_items.add_child(one)
		var full := Button.new()
		full.name = "Stack%s" % String(item.id).to_pascal_case()
		full.text = "Stack (%d)" % item.max_stack
		full.pressed.connect(give.bind(item, item.max_stack))
		_items.add_child(full)


## Spawns `scene` 2 m in front of the player, facing the same way; null without a player.
func spawn(scene: PackedScene) -> Node3D:
	var player := _player()
	if player == null:
		_report("No player")
		return null
	var forward := -player.global_basis.z
	forward.y = 0.0
	var node := scene.instantiate() as Node3D
	var position := player.global_position + forward.normalized() * SPAWN_DISTANCE
	if node is RigidBody3D:
		position += Vector3.UP * SPAWN_LIFT
	player.get_parent().add_child(node, true)
	node.global_transform = Transform3D(player.global_basis, position)
	var data := {"object": String(node.name), "scene": scene.resource_path}
	EventLog.record(EventKinds.DEBUG_SPAWNED, "DebugPanel", String(node.name), data)
	_report("Spawned %s" % node.name)
	return node


## Sends a CONTACT `fire` of intensity 100 to what the player looks at. Returns the node hit.
func ignite_looked_at() -> Node:
	return _poke(&"fire", IGNITE_INTENSITY)


## Sends a CONTACT `damage.blunt` of 10 to what the player looks at. Returns the node hit.
func damage_looked_at() -> Node:
	return _poke(&"damage.blunt", DAMAGE_AMOUNT)


## Adds `count` of `item` to the player's inventory; returns how many did not fit (-1: no player).
func give(item: ItemData, count: int) -> int:
	var player := _player()
	if player == null:
		_report("No player")
		return -1
	var left := player.inventory.give(item, count)
	var data := {"item": String(item.id), "count": count - left}
	EventLog.record(EventKinds.DEBUG_GAVE_ITEM, "DebugPanel", String(player.name), data)
	if left >= count:
		_report("No room for %s" % item.display_name)
	elif left > 0:
		_report("Gave %d %s (%d did not fit)" % [count - left, item.display_name, left])
	else:
		_report("Gave %d %s" % [count, item.display_name])
	return left


## Button handler: reloads the level through LevelReset (drops queued stimuli, logs
## `debug.reset_level`) and closes the panel; reports and does nothing without a current scene.
func reset_level() -> Error:
	var error := LevelReset.reload_level(get_tree(), EventKinds.DEBUG_RESET_LEVEL)
	if error == ERR_UNAVAILABLE:
		_report("No level to reset")
	else:
		DebugPanel.set_open(false)
	return error


## Spawns a grenade effect `scene` (a gas cloud, a jamming field) in the level where the crosshair
## hits (within 20 m); null when it hits nothing.
func spawn_effect(scene: PackedScene) -> Node3D:
	var point := _looked_at_point()
	if point == Vector3.INF:
		return null
	var node := ExplosivePayload.spawn_in_level(scene, _player(), point)
	EventLog.record(EventKinds.DEBUG_SPAWNED, "DebugPanel", String(node.name), {"object": String(node.name)})
	_report("Spawned %s" % node.name)
	return node


## Sends an EMP pulse (emp.tres: 6 m, 20 s) where the crosshair hits; false when it hits nothing.
func emp_looked_at() -> bool:
	var point := _looked_at_point()
	if point == Vector3.INF:
		return false
	StimulusSystem.emit(EmpPulse.make(EMP, point))
	_report("EMP at %.0f, %.0f, %.0f" % [point.x, point.y, point.z])
	return true


# Where the crosshair hits (a little off the surface), or INF.
func _looked_at_point() -> Vector3:
	var player := _player()
	if player == null:
		_report("No player")
		return Vector3.INF
	var hit := player.look_hit(LOOK_LENGTH)
	if hit.is_empty():
		_report("Nothing under the crosshair")
		return Vector3.INF
	return (hit["position"] as Vector3) + (hit["normal"] as Vector3) * 0.1


func _poke(type: StringName, intensity: float) -> Node:
	var player := _player()
	if player == null:
		_report("No player")
		return null
	var hit := player.look_hit(LOOK_LENGTH)
	if hit.is_empty():
		_report("Nothing under the crosshair")
		return null
	var target := hit["collider"] as Node
	StimulusSystem.emit(Stimulus.make_contact(type, intensity, target, player))
	_report("%s %.0f -> %s" % [type, intensity, target.name])
	return target


func _player() -> Player:
	return get_tree().get_first_node_in_group(Player.GROUP) as Player


func _report(text: String) -> void:
	_status.text = text
