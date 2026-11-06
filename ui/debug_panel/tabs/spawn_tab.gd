class_name SpawnTab
extends VBoxContainer
## Debug panel tab: spawns catalogue objects in front of the player and pokes the object under the
## crosshair (ignite with a strong CONTACT `fire`, hit with `damage.blunt`).

const CATALOG: ObjectCatalog = preload("res://objects/object_catalog.tres")
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
@onready var _status: Label = $Status


func _ready() -> void:
	for scene in CATALOG.scenes:
		var button := Button.new()
		button.text = ObjectCatalog.label_of(scene)
		button.name = button.text.capitalize().replace(" ", "")
		button.pressed.connect(spawn.bind(scene))
		_buttons.add_child(button)
	_ignite.pressed.connect(ignite_looked_at)
	_damage.pressed.connect(damage_looked_at)


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
	EventLog.record(&"debug.spawned", "DebugPanel", String(node.name), data)
	_report("Spawned %s" % node.name)
	return node


## Sends a CONTACT `fire` of intensity 100 to what the player looks at. Returns the node hit.
func ignite_looked_at() -> Node:
	return _poke(&"fire", IGNITE_INTENSITY)


## Sends a CONTACT `damage.blunt` of 10 to what the player looks at. Returns the node hit.
func damage_looked_at() -> Node:
	return _poke(&"damage.blunt", DAMAGE_AMOUNT)


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
