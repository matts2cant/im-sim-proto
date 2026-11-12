extends GdUnitTestSuite
## Unit (ADR 0113, amended 2026-11-12): the Icebreaker view's scramble, driven by animate() on a view
## built in code (no deck, no lab). While the crack runs, the next letter's cell (locked_letters())
## cycles through random characters (about 22 a second, never the real letter, the colour
## alternating title / assist blue); cells after it stay dots; a letter that locks shows itself and
## flashes for 0.25 s while the scramble moves on. Stopped or done: no scramble.

const PASSWORD := "ferry19"
const STEP := 1.0 / 60.0


func _view(progress: float, running: bool) -> DeckIceView:
	var session := auto_free(DeckSession.new()) as DeckSession
	var ice := auto_free(IcebreakerTool.new()) as IcebreakerTool
	ice.job = Icebreaker.make("lab|kbrandt", "kbrandt", "OFFICE-PC", PASSWORD, 0, 10.0)
	ice.job.progress = progress
	ice.job.running = running
	var view := auto_free(DeckIceView.new()) as DeckIceView
	add_child(view)
	# Driven by hand: animate() steps, not the frame loop.
	view.set_process(false)
	view.rng.seed = 7
	view.bind(session, ice)
	view.refresh()
	return view


func _texts(view: DeckIceView) -> Array[String]:
	var texts: Array[String] = []
	for cell in view.letter_cells():
		texts.append(cell.text)
	return texts


func test_the_next_letter_scrambles_while_running() -> void:
	# 0.3 x 7 letters: "fe" locked, the third ("r") scrambles.
	var view := _view(0.3, true)
	var seen := {}
	var colors := {}
	for i in 30:
		view.animate(STEP)
		var texts := _texts(view)
		assert_array(texts.slice(0, 2)).is_equal(["f", "e"])
		assert_str(texts[2]).is_not_equal("r")
		assert_str(texts[2]).is_not_equal(DeckIceView.DOT)
		assert_array(texts.slice(3)).is_equal([DeckIceView.DOT, DeckIceView.DOT, DeckIceView.DOT, DeckIceView.DOT])
		seen[texts[2]] = true
		colors[view.letter_cells()[2].get_theme_color(&"font_color")] = true
	# Half a second at 22 a second: about 11 characters, in both colours.
	assert_int(seen.size()).is_greater_equal(6)
	assert_bool(colors.has(DeckStyle.TITLE_COLOR) and colors.has(DeckStyle.SELF_COLOR)).is_true()


func test_a_refresh_keeps_the_scrambling_character() -> void:
	var view := _view(0.3, true)
	view.animate(STEP)
	var shown := view.scramble_char
	view.invalidate()
	view.refresh()
	assert_str(_texts(view)[2]).is_equal(shown)


func test_stopped_or_done_shows_no_scramble() -> void:
	var view := _view(0.3, false)
	for i in 5:
		view.animate(STEP)
	assert_array(_texts(view)).is_equal(
		["f", "e", DeckIceView.DOT, DeckIceView.DOT, DeckIceView.DOT, DeckIceView.DOT, DeckIceView.DOT]
	)
	assert_str(view.scramble_char).is_empty()
	# Running, then stopped (Stop or a lost connection): the cell goes back to a dot.
	view.ice.job.running = true
	view.animate(STEP)
	assert_str(_texts(view)[2]).is_not_equal(DeckIceView.DOT)
	view.ice.job.running = false
	view.animate(STEP)
	assert_str(_texts(view)[2]).is_equal(DeckIceView.DOT)
	# Done: every letter, no scramble.
	view.ice.job.progress = 1.0
	view.refresh()
	view.animate(STEP)
	assert_str("".join(_texts(view))).is_equal(PASSWORD)


func test_a_locking_letter_flashes_and_the_scramble_moves_on() -> void:
	var view := _view(0.4, true)
	view.animate(STEP)
	# 0.45 x 7 = 3.15: the "r" at index 2 locks.
	view.ice.job.progress = 0.45
	view.animate(STEP)
	var cells := view.letter_cells()
	assert_str(cells[2].text).is_equal("r")
	assert_float(view.flash_amount(2)).is_greater(0.9)
	assert_object(cells[2].get_node_or_null(^"Flash")).is_not_null()
	assert_str(cells[3].text).is_not_equal("r")
	assert_str(cells[3].text).is_not_equal(DeckIceView.DOT)
	# A refresh mid-flash keeps it.
	view.invalidate()
	view.refresh()
	assert_object(view.letter_cells()[2].get_node_or_null(^"Flash")).is_not_null()
	# 0.25 s later: faded and gone.
	for i in 18:
		view.animate(STEP)
	assert_float(view.flash_amount(2)).is_equal(0.0)
	assert_object(view.letter_cells()[2].get_node_or_null(^"Flash")).is_null()
	assert_str(view.letter_cells()[2].text).is_equal("r")
