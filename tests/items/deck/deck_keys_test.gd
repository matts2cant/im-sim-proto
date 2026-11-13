extends GdUnitTestSuite
## Device keys (ADR 0141) on the lab network (network_fixtures.gd): every device has a stable key
## (Device.device_id: a random one made when it enters the tree and saved, or a fixed one set in a
## level) that the deck keeps its state under and the Journal files logins under when the device
## names no credentials id. Saves from before kept entity node paths (the deck) or the snake_case
## node name (the Journal): both still resolve.

const Net := preload("res://tests/objects/network/network_fixtures.gd")
const ORIGIN := Vector3(340, 0, -380)

var _root: Node3D
var _n: Dictionary[String, Node3D]
var _user: Node3D


func before_test() -> void:
	EventLog.clear()
	StimulusSystem.clear()
	_root = auto_free(Node3D.new())
	add_child(_root)
	_n = Net.lab(_root, ORIGIN)
	_user = Net.user(_root, ORIGIN + Vector3(0, 0, 1))


func after_test() -> void:
	StimulusSystem.clear()


func _device(entity_name: String) -> Device:
	return Device.of(_n[entity_name])


func test_every_device_has_its_own_key_saved_with_it() -> void:
	var pc := _device("OfficePc")
	var jack := _device("Jack")
	assert_str(pc.device_id).starts_with("d")
	assert_str(pc.device_id).is_not_equal(jack.device_id)
	assert_str(DeckSession.key_of(pc)).is_equal(pc.device_id)
	var saved := pc.save_state()
	pc.device_id = "d_other"
	pc.load_state(saved)
	assert_str(pc.device_id).is_equal(str(saved["id"]))
	# A save without a key (before ADR 0141) keeps the one made on entering the tree.
	var before := jack.device_id
	jack.load_state({"broken": false})
	assert_str(jack.device_id).is_equal(before)


func test_a_key_set_in_the_level_is_kept() -> void:
	var entity := Node3D.new()
	entity.name = "Fixed"
	var tags := Tags.new()
	tags.name = "Tags"
	entity.add_child(tags)
	var device := Device.new()
	device.device_id = "lab_fixed_device"
	device.status_light = false
	entity.add_child(device)
	_root.add_child(entity)
	assert_str(device.device_id).is_equal("lab_fixed_device")
	assert_object(DeckDiscovery.devices_by_key(get_tree())["lab_fixed_device"]).is_same(device)


func test_node_paths_from_old_saves_resolve_to_device_keys() -> void:
	var pc := _device("OfficePc")
	var path := String(_n["OfficePc"].get_path())
	assert_str(DeckDiscovery.migrated_key(_root, path)).is_equal(pc.device_id)
	assert_str(DeckDiscovery.migrated_key(_root, pc.device_id)).is_equal(pc.device_id)
	assert_str(DeckDiscovery.migrated_key(_root, "/root/NoSuchLevel/Gone")).is_equal("/root/NoSuchLevel/Gone")

	var cracks := {path + "|kbrandt": {"progress": 0.5}, "/root/NoSuchLevel/Gone|x": {}, "d_kept|y": {}}
	assert_bool(DeckDiscovery.migrate_keys(cracks, _root, "|")).is_true()
	assert_array(cracks.keys()).contains_exactly_in_any_order(
		[pc.device_id + "|kbrandt", "/root/NoSuchLevel/Gone|x", "d_kept|y"]
	)
	assert_float(float((cracks[pc.device_id + "|kbrandt"] as Dictionary)["progress"])).is_equal(0.5)
	var wifi := {path: {"progress": 0.25}}
	DeckDiscovery.migrate_keys(wifi, _root)
	assert_array(wifi.keys()).contains_exactly([pc.device_id])


func test_a_journal_from_before_still_knows_a_cracked_login() -> void:
	var accounts := DeviceAccounts.of(_n["OfficePc"])
	assert_str(String(accounts.code_id())).is_equal(_device("OfficePc").device_id)
	# A crack filed under the node name (the legacy code id) by a save from before ADR 0141.
	var legacy := LogEntry.make(&"icebreaker.old", "Cracked", "", "Deck", {&"office_pc": "kbrandt:ferry19"})
	PersonalLog.of(_user).add(legacy)
	assert_bool(accounts.knows_login(_user, "kbrandt")).is_true()
	assert_str(accounts.known_password(_user, "kbrandt")).is_equal("ferry19")
	# Two devices with the same node name no longer share their logins.
	var cracked := LogEntry.make(&"icebreaker.new", "Cracked", "", "Deck", {accounts.code_id(): "dmarsh:tide88"})
	PersonalLog.of(_user).add(cracked)
	assert_str(accounts.known_password(_user, "dmarsh")).is_equal("tide88")
