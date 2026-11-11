extends Node3D
## Test fixture (ADR 0113): the lab network of tests/objects/network/network_fixtures.gd built at
## ORIGIN in a lit room with the real Player, for the deck's integration tests and review shots. The
## jack sits on the wall's face (z = ORIGIN.z) 0.5 m up; the Kiosk (autonomous, a maintenance port)
## stands 4 m south of it. The Player starts 1.2 m in front of the jack.

const Net := preload("res://tests/objects/network/network_fixtures.gd")
const ORIGIN := Vector3(-300, 0, 300)
## In front of the jack, and 1 m in front of the kiosk.
const AT_JACK := Vector3(0, 0, 1.2)
const AT_KIOSK := Vector3(0, 0, 5.0)

var network: Dictionary[String, Node3D] = {}


func _ready() -> void:
	network = Net.lab(self, ORIGIN)


## The lab entity named `entity_name`.
func node(entity_name: String) -> Node3D:
	return network[entity_name]


func device(entity_name: String) -> Device:
	return Device.of(network[entity_name])


func tracer() -> Tracer:
	return network["Fw01"].get_node("Tracer") as Tracer
