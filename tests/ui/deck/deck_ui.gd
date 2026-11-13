extends RefCounted
## Test queries on a DeckScreen (moved out of the screen: tests only). Preload as `DeckUi`.


## The visible button labelled `text` anywhere on the screen, or null.
static func find_button(deck: DeckScreen, text: String) -> Button:
	return UiQuery.find_button(deck.root, text)


## The open device menu's button labelled `text`, or null.
static func menu_button(deck: DeckScreen, text: String) -> Button:
	return UiQuery.find_button(deck.graph.menu, text) if deck.graph.menu.visible else null


## Every visible button label on the open menu.
static func menu_texts(deck: DeckScreen) -> Array[String]:
	return UiQuery.texts(deck.graph.menu) if deck.graph.menu.visible else [] as Array[String]


## The text of the trace bars, one "<name> <n> %" per tracer.
static func trace_texts(deck: DeckScreen) -> Array[String]:
	var found: Array[String] = []
	for bar in deck.trace_box.get_children():
		if bar.is_queued_for_deletion():
			continue
		var parts := PackedStringArray()
		for child in bar.get_children():
			if child is Label:
				parts.append((child as Label).text)
		found.append(" ".join(parts))
	return found


## The Icebreaker's visible text lines.
static func ice_texts(deck: DeckScreen) -> Array[String]:
	return UiQuery.texts(deck.ice_view.column)


## The rows the Map shows now.
static func map_rows(deck: DeckScreen) -> Array[NetworkRow]:
	return deck.map_view.map_rows()
