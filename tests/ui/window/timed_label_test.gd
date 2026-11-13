extends GdUnitTestSuite
## Unit (ADR 0133): TimedLabel, the feedback line that clears itself. Its text shows for its
## seconds, then empties; with `hide_when_empty` (a toast) it hides too, else it stays in the layout.
## clear_text() empties it at once; a new text restarts the time.

const Wait := preload("res://tests/helpers/wait.gd")


func test_text_clears_and_hides_after_its_seconds() -> void:
	var label := _label(true)
	assert_bool(label.visible).is_false()

	label.show_text("Energy depleted", 0.5)
	assert_bool(label.visible).is_true()
	await Wait.frames(get_tree(), 15)
	assert_str(label.text).is_equal("Energy depleted")
	await Wait.frames(get_tree(), 30)

	assert_str(label.text).is_empty()
	assert_bool(label.visible).is_false()
	assert_float(label.time_left()).is_equal(0.0)


func test_without_hiding_it_stays_visible_and_empty() -> void:
	var label := _label(false)
	label.show_text("Energy depleted", 0.25)
	await Wait.frames(get_tree(), 30)

	assert_str(label.text).is_empty()
	assert_bool(label.visible).is_true()


func test_a_new_text_restarts_the_time_and_clear_text_empties_it() -> void:
	var label := _label(true)
	label.show_text("one", 0.5)
	await Wait.frames(get_tree(), 18)
	label.show_text("two", 0.5)
	await Wait.frames(get_tree(), 18)
	assert_str(label.text).is_equal("two")

	label.clear_text()
	assert_str(label.text).is_empty()
	assert_bool(label.visible).is_false()


func _label(hides: bool) -> TimedLabel:
	var label := TimedLabel.new()
	label.hide_when_empty = hides
	add_child(label)
	auto_free(label)
	return label
