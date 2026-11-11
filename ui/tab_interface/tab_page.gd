class_name TabPage
extends Control
## One page of the Tab interface. The host calls bind() once with the player, then on_shown() each
## time the page becomes the visible tab; pages update themselves in their own _process while visible.


## The tab's title in the tab bar.
func tab_title() -> String:
	return ""


## Called once with the player the interface belongs to.
func bind(_player: Node) -> void:
	pass


## Called each time the page becomes the visible tab.
func on_shown() -> void:
	pass
