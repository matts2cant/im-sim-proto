class_name SecurityKind
extends Resource
## One kind of device in a computer's Security app (ADR 0114): the devices whose entity has `tag`
## are listed under `group` with `icon`. Data in ComputerConfig.kinds; nothing in code names a
## kind.

## The entity tag that makes a device this kind (`object.camera`).
@export var tag: StringName = &""
## What the detail pane calls the kind ("Camera").
@export var name: String = ""
## The Security app's group it is listed under ("Cameras and turrets"; ComputerConfig.groups).
@export var group: String = ""
## A small line icon on a 24 x 24 grid (DeviceIcon draws it): one stroke per string.
@export var icon: PackedStringArray = []
