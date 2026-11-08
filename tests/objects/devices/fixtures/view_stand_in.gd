extends Node
## Test stand-in (not a suite, ADR 0083): a behaviour component that offers a view (DeviceStatus):
## `view` while `seeing`, else null.

var view: Node3D
var seeing: bool = true


func device_view() -> Node3D:
	return view if seeing else null
