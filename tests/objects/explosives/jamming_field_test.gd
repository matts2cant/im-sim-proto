extends GdUnitTestSuite
## Integration (ADR 0131, M14b): jamming fields (10 m, 20 s) over the lab network
## (network_fixtures.gd lab() + add_wireless(): AP-YARD's wireless camera CAM-YARD and laser) and a
## second, unconnected network, the annex (annex(), 30 m north: AP-ANNEX and CAM-ANNEX), with a
## cabled camera CamCable beside CAM-YARD. While a field lasts, a wireless link with an end inside
## drops: CAM-YARD reads "Jammed" in NetworkState, its StatusLight (blinking amber), the frame
## (TargetStatus) and the deck's Map (still drawn, words "jammed"), and its incidents reach no one;
## the cabled camera and a deck plugged in by cable inside a field keep working; a deck on AP-YARD's
## Wi-Fi drops; a radio dispatch is lost by a radio inside and heard outside. The annex (outside
## both fields) is untouched and stays off the Map. Everything comes back when the fields end.
## Distances are centre to centre (field centre 0.1 m up).
##   plan (x east, z south, from ORIGIN): Jack (0,0.5,0), cable deck user's eye (0,1.6,1); field F1
##   (0,0.1,1.5); AP-YARD (12,2.6,3) 10.8 m from F2, outside; CAM-YARD (14,2.5,7) 6.5 m, LASER-ROOF
##   (15,1,5) 7.7 m, CamCable (15,2.5,9) 4.5 m, Wi-Fi user's eye (12,1.6,6) 8.05 m from field F2
##   (16.5,0.1,12.5); radio station (6,1,20); radios at F2's centre (inside) and (4,0,25) (17.7 m
##   from F2, 23.8 m from F1); annex 30 m north (CAM-ANNEX (-6.5,2.5,-21), 22 m from F1).

const Net := preload("res://tests/objects/network/network_fixtures.gd")
const Fixtures := preload("res://tests/core/stimulus/stimulus_fixtures.gd")
const Grenades := preload("res://tests/objects/explosives/explosive_fixtures.gd")
const FIELD: PackedScene = preload("res://objects/explosives/jamming_field/jamming_field.tscn")
const STATION: PackedScene = preload("res://objects/alarm/radio_base_station.tscn")
const HEARD_DISPATCH: Receptron = preload("res://actors/common/awareness/receptrons/heard_dispatch.tres")
const ORIGIN := Vector3(-460, 0, 380)
const F1 := Vector3(0, 0.1, 1.5)
const F2 := Vector3(16.5, 0.1, 12.5)


class Listener:
	extends Awareness
	var searched: Array[Vector3] = []

	func search_at(at: Vector3, _why: String) -> void:
		searched.append(at)


var _root: Node3D
var _n: Dictionary[String, Node3D]


func before_test() -> void:
	EventLog.clear()
	StimulusSystem.clear()
	_root = auto_free(Node3D.new()) as Node3D
	add_child(_root)
	_n = Net.lab(_root, ORIGIN)
	Net.add_wireless(_n, _root, ORIGIN)
	var annex := Net.annex(_root, ORIGIN + Vector3(0, 0, -30))
	for entity_name: String in annex:
		_n[entity_name] = annex[entity_name]
	_n["CamCable"] = Net.body_device(_root, "CamCable", ORIGIN + Vector3(15, 2.5, 9))
	Net.link(_n["SecuritySwitch"], _n["CamCable"])
	# A lamp for CAM-YARD's status light (a device without a model shows one only on a lamp).
	var lamp := DeviceLamp.new()
	lamp.name = "DeviceLamp"
	_n["CamYard"].add_child(lamp)
	await _frames(2)
	StatusLight.attach(_dev("CamYard"))


func after_test() -> void:
	Grenades.clear_effects(get_tree())
	StimulusSystem.clear()


func test_a_jammed_wireless_device_reads_jammed_everywhere_and_cables_keep_working() -> void:
	var user := Net.user(_root, ORIGIN + Vector3(0, 1.6, 1))
	DeviceAccounts.of(_n["Rtr01"]).grant(user, "admin")
	var session := DeckSession.of(user)
	session.config = session.config.duplicate() as DeckConfig
	session.config.scan_time = 0.1
	assert_bool(session.plug(_dev("Jack"), Net.deck_stack())).is_true()
	await _frames(20)
	session.refresh()
	assert_int(_dev("CamYard").report_incident(_n["CamYard"].global_position)).is_equal(1)

	_field(F1)
	_field(F2)
	await _frames(3)
	session.refresh()
	# CAM-YARD and LASER-ROOF: jammed. NetworkState, the light, the frame.
	for entity_name: String in ["CamYard", "LaserRoof"]:
		assert_int(_state(entity_name)).override_failure_message(entity_name).is_equal(StatusLight.State.JAMMED)
	var light := StatusLight.of(_n["CamYard"])
	assert_int(light.state).is_equal(StatusLight.State.JAMMED)
	assert_bool(DeviceLamp.of(_n["CamYard"]).blinking()).is_true()
	var word := _word("CamYard")
	assert_str(TargetStatus.text(word)).is_equal("Jammed")
	assert_bool(TargetStatus.blinks(word)).is_true()
	assert_bool(TargetStatus.color(word) == StatusLight.COLORS[StatusLight.State.CUT_OFF]).is_true()
	# Its incidents reach no one; the deck no longer reaches it.
	assert_int(_dev("CamYard").report_incident(_n["CamYard"].global_position)).is_equal(0)
	assert_bool(session.is_online(_dev("CamYard"))).is_false()
	# Cables inside a field: the cabled camera and the deck on the jack keep working.
	assert_int(_state("CamCable")).is_equal(StatusLight.State.UP)
	assert_str(TargetStatus.text(_word("CamCable"))).is_equal("Online")
	assert_bool(session.is_plugged()).is_true()
	assert_bool(session.is_online(_dev("CamCable"))).is_true()
	# The annex, outside both fields: untouched.
	assert_int(_state("CamAnnex")).is_equal(StatusLight.State.UP)
	# The Map: CAM-YARD still drawn (seen, physical network), jammed; nothing from the annex.
	var rows := _map_rows(session)
	assert_int((rows["CamYard"] as NetworkRow).light).is_equal(StatusLight.State.JAMMED)
	assert_array(Array((rows["CamYard"] as NetworkRow).status)).is_equal([DeckMapView.JAMMED_WORD])
	assert_int((rows["CamCable"] as NetworkRow).light).is_equal(StatusLight.State.UP)
	for entity_name: String in ["ApAnnex", "CamAnnex", "JackB"]:
		assert_bool(rows.has(entity_name)).override_failure_message(entity_name).is_false()

	# Both fields end (skipped to their last moment): everything is back.
	for field in get_tree().get_nodes_in_group(JammingField.GROUP):
		(field as JammingField).age = 19.9
	await _frames(12)
	assert_array(get_tree().get_nodes_in_group(JammingField.GROUP)).is_empty()
	assert_int(_state("CamYard")).is_equal(StatusLight.State.UP)
	assert_int(light.state).is_equal(StatusLight.State.UP)
	assert_str(TargetStatus.text(_word("CamYard"))).is_equal("Online")
	assert_int(_dev("CamYard").report_incident(_n["CamYard"].global_position)).is_equal(1)


func test_the_deck_wifi_drops_inside_a_field() -> void:
	var user := Net.user(_root, ORIGIN + Vector3(12, 1.6, 6))
	AccessPoint.of(_n["ApYard"]).grant_key(user)
	var session := DeckSession.of(user)
	assert_bool(session.plug(_dev("ApYard"), Net.deck_stack())).is_true()
	assert_bool(session.is_wireless()).is_true()
	var field := _field(F2)
	await _frames(3)
	assert_bool(session.is_plugged()).is_false()
	assert_str(String(session.unplug_reason)).is_equal("jammed")
	# No joining again while it lasts; once it ends, the Wi-Fi works again.
	assert_bool(session.plug(_dev("ApYard"), Net.deck_stack())).is_false()
	field.end()
	await _frames(2)
	assert_bool(session.plug(_dev("ApYard"), Net.deck_stack())).is_true()


func test_a_radio_inside_gets_no_dispatch() -> void:
	var station := STATION.instantiate() as Node3D
	station.position = ORIGIN + Vector3(6, 1, 20)
	_root.add_child(station)
	var inside := _radio("Inside", F2 - Vector3(0, 0.1, 0))
	var outside := _radio("Outside", Vector3(4, 0, 25))
	_field(F2)
	await _frames(2)
	(station.get_node("RadioBaseStationBehaviour") as RadioBaseStation).dispatch(ORIGIN + Vector3(6, 0, 22))
	await _frames(3)
	assert_array(outside.searched).has_size(1)
	assert_array(inside.searched).is_empty()
	assert_array(EventLog.find(&"radio.jammed")).has_size(1)


func test_saves_its_time_and_place() -> void:
	var field := _field(F2)
	field.age = 12.0
	var copy := FIELD.instantiate() as JammingField
	_root.add_child(copy)
	copy.load_state(field.save_state())
	assert_float(copy.time_left()).is_equal_approx(8.0, 0.001)
	assert_bool(copy.covers(ORIGIN + F2 + Vector3(9.5, 0, 0))).is_true()
	assert_bool(copy.covers(ORIGIN + F2 + Vector3(11, 0, 0))).is_false()


func _field(at: Vector3) -> JammingField:
	return ExplosivePayload.spawn_in_level(FIELD, _root, ORIGIN + at) as JammingField


func _radio(radio_name: String, at: Vector3) -> Listener:
	var entity := Fixtures.entity(_root, radio_name, ORIGIN + at, [HEARD_DISPATCH], [&"equipment.radio"])
	var listener := Listener.new()
	listener.name = "Awareness"
	entity.add_child(listener)
	return listener


func _dev(entity_name: String) -> Device:
	return Device.of(_n[entity_name])


func _state(entity_name: String) -> StatusLight.State:
	return NetworkState.state_of(_dev(entity_name), NetworkState.links_of(_dev(entity_name)))


func _word(entity_name: String) -> TargetStatus.Word:
	return TargetStatus.word_of(_n[entity_name], NetworkState.links_of(_dev(entity_name)))


# The deck Map's rows by entity name.
func _map_rows(session: DeckSession) -> Dictionary:
	var view := auto_free(DeckMapView.new()) as DeckMapView
	view.session = session
	var rows := {}
	for row in view.map_rows():
		rows[String(row.device.entity.name)] = row
	return rows


func _frames(count: int) -> void:
	await Fixtures.frames(get_tree(), count)
