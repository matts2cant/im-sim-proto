class_name TabPage
extends Control
## One tab of the Tab interface.


## Title shown in the tab bar.
func tab_title() -> String:
	return name


## Called once by the host after the page enters the tree, with the player.
func bind(_player: Node) -> void:
	pass


## Called each time the page becomes the visible tab.
func on_shown() -> void:
	pass
