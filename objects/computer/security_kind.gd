class_name SecurityKind
extends Resource
## One kind of device (ADR 0114, 0121): the devices whose entity has `tag` are this kind. Data in
## DeviceKinds (`objects/devices/device_kinds.tres`); nothing in code names a kind. A kind with a
## `group` is listed in a computer's Security app under it; every kind gives the deck's Map its icon;
## `exploit` names the exploit items that open it.

## The entity tag that makes a device this kind (`object.camera`).
@export var tag: StringName = &""
## What the detail pane calls the kind ("Camera").
@export var name: String = ""
## The Security app's group it is listed under ("Cameras and turrets"; ComputerConfig.groups);
## empty: not listed (network gear, computers).
@export var group: String = ""
## A small line icon on a 24 x 24 grid (DeviceIcon draws it): one stroke per string.
@export var icon: PackedStringArray = []
## The exploit item kind that gives admin access to it (ItemData.exploit_kind: camera, turret, door,
## alarm, computer, router); empty: no exploit item opens it.
@export var exploit: StringName = &""
