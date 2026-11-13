class_name AccessPointConfig
extends Resource
## Tuning of an AccessPoint (ADR 0115, ADR 0138): `objects/network/access_point.tres` (the default);
## a level gives an access point a longer reach with its own config (the warehouse's AP-YARD:
## `levels/mission/population/ap_yard_access_point.tres`).

## How far its radio reaches a wireless device (m, centre to centre: the entities' origins).
@export var wireless_range: float = 15.0
