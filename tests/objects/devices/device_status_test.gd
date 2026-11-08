extends GdUnitTestSuite
## Unit (ADR 0083): DeviceStatus collects what a security screen shows from any entity's components
## (stand-ins here, not shipped devices): offline hides everything, online lists each component's
## words in tree order without duplicates, a view comes from whichever component offers one.

const StatusStandIn := preload("res://tests/objects/devices/fixtures/status_stand_in.gd")
const ViewStandIn := preload("res://tests/objects/devices/fixtures/view_stand_in.gd")


func _entity(words_per_component: Array[PackedStringArray]) -> Node3D:
	var entity: Node3D = auto_free(Node3D.new())
	for words in words_per_component:
		var component: Node = StatusStandIn.new()
		component.set("words", words)
		entity.add_child(component)
	return entity


func test_offline_is_only_offline() -> void:
	var words := DeviceStatus.summarize(false, PackedStringArray(["enabled", "ringing"]))
	assert_array(Array(words)).contains_exactly(["offline"])


func test_online_comes_first_then_the_words_without_duplicates() -> void:
	var words := DeviceStatus.summarize(
		true, PackedStringArray(["enabled", "", "online", "enabled", "offline", "alert"])
	)
	assert_array(Array(words)).contains_exactly(["online", "enabled", "alert"])


func test_words_come_from_every_component_in_tree_order() -> void:
	var entity := _entity([PackedStringArray(["open"]), PackedStringArray(["locked"])])
	# A child without the method adds nothing.
	entity.add_child(Node.new())
	assert_array(Array(DeviceStatus.of(entity, true))).contains_exactly(["online", "open", "locked"])
	assert_array(Array(DeviceStatus.of(entity, false))).contains_exactly(["offline"])
	# A device with no status component is just online.
	assert_array(Array(DeviceStatus.of(_entity([]), true))).contains_exactly(["online"])


func test_a_view_comes_from_the_component_that_offers_one() -> void:
	var entity := _entity([PackedStringArray(["enabled"])])
	assert_bool(DeviceStatus.has_view(entity)).is_false()
	assert_object(DeviceStatus.view_of(entity)).is_null()
	var eye: Node3D = auto_free(Node3D.new())
	var component: Node = ViewStandIn.new()
	component.set("view", eye)
	entity.add_child(component)
	assert_bool(DeviceStatus.has_view(entity)).is_true()
	assert_object(DeviceStatus.view_of(entity)).is_same(eye)
	# Seeing nothing (disabled): it still has a view, but there is nothing to show.
	component.set("seeing", false)
	assert_bool(DeviceStatus.has_view(entity)).is_true()
	assert_object(DeviceStatus.view_of(entity)).is_null()
