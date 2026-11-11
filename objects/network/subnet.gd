class_name Subnet
extends Resource
## Data (ADR 0112 amendment, 0113): how screens present one subnet: its name, address range and
## colour on the deck's Map (a flat box of that hue behind its devices). Devices name their subnet
## by `id` (Device.subnet); the routers that join it carry its Subnet (Router.subnet_data), so a
## subnet without data still works, it only shows without a box.

## The subnet id devices use (Device.subnet).
@export var id: StringName = &""
## Its name as the Map shows it ("SECURITY").
@export var label: String = ""
## Its address range ("10.0.20.0/24").
@export var address_range: String = ""
## Its hue on the Map (the box fills with it faintly and is outlined in it).
@export var map_color: Color = Color(0.5, 0.66, 0.64)


## The title the Map shows on the subnet's box: its name and range.
func title() -> String:
	var name := label if not label.is_empty() else String(id).to_upper()
	return "%s  %s" % [name, address_range] if not address_range.is_empty() else name
