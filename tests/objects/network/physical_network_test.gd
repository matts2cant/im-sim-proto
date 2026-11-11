extends GdUnitTestSuite
## Integration (M12b map fix, ADR 0113 amendment): DeviceNetwork.physical_network() on two networks
## with no link between them (network_fixtures.gd lab() with add_wireless(), and annex()): cables
## both ways and holding wireless links join devices, up or down, through routers whatever their
## rules; a wireless device out of its access point's range is not on it; the other network never is.

const Net := preload("res://tests/objects/network/network_fixtures.gd")
const ORIGIN := Vector3(500, 0, -340)

var _a: Dictionary[String, Node3D]
var _b: Dictionary[String, Node3D]


func before_test() -> void:
	var root: Node3D = auto_free(Node3D.new())
	add_child(root)
	_a = Net.lab(root, ORIGIN)
	Net.add_wireless(_a, root, ORIGIN)
	_b = Net.annex(root, ORIGIN)


func _names(entity: Node3D) -> Array[String]:
	var found: Array[String] = []
	for device in DeviceNetwork.physical_network(Device.of(entity)):
		found.append(String(device.entity.name))
	return found


func test_the_network_joins_cables_and_radio_both_ways_through_routers() -> void:
	var lab := _names(_a["Jack"])
	assert_str(lab[0]).is_equal("Jack")
	assert_int(lab.size()).is_equal(_a.size() - 1)  # Every lab device but the Kiosk (no cables).
	assert_array(lab).contains(["Rtr01", "Console", "FileServer", "ApYard", "CamYard", "LaserRoof"])
	assert_bool(lab.has("Kiosk")).is_false()
	# From a wireless device: the same network, the access point and its cables reached both ways.
	assert_array(_names(_a["CamYard"])).contains_exactly_in_any_order(lab)
	assert_array(_names(_b["JackB"])).contains_exactly_in_any_order(
		["JackB", "SwitchB", "PcB", "PrinterB", "TerminalB", "ApAnnex", "CamAnnex"]
	)
	assert_array(_names(_a["Kiosk"])).is_equal(["Kiosk"])


func test_down_devices_stay_on_it_and_an_out_of_range_radio_does_not() -> void:
	Powered.of(_a["SecuritySwitch"]).on = false
	Powered.of(_a["ApYard"]).on = false
	Breakable.of(_b["PrinterB"]).take_damage(&"damage.ballistic", 100.0)
	assert_array(_names(_a["Jack"])).contains(["Console", "FileServer", "CamYard"])
	assert_array(_names(_b["JackB"])).contains(["PrinterB"])
	# 30 m from AP-YARD (15 m range): the radio link does not hold.
	_a["CamYard"].global_position = ORIGIN + Vector3(12, 2.5, 33)
	assert_bool(_names(_a["Jack"]).has("CamYard")).is_false()
	assert_array(_names(_a["CamYard"])).is_equal(["CamYard"])
	assert_array(DeviceNetwork.physical_network(null)).is_empty()
