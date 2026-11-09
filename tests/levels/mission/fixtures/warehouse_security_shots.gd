extends RefCounted
## Review shots of the warehouse's doors and security devices (M9c), merged into
## warehouse_shots.gd's list: run `warehouse_shots.tscn -- shots=<name>,... out=<folder>`. Keys as
## there, plus `view`: a free camera at the eye of a device's view node (a camera's point of view,
## HUD hidden), and `terminal`: the player uses that terminal, logged in, on its Network tab.

const DEVICES := "Population/Security/Devices/"

const SHOTS: Dictionary[String, Dictionary] = {
	# Doors.
	"door_front_gate_road": {"feet": Vector3(-5, 0, -31), "look": Vector3(-5, 1.4, -25)},
	"door_front_gate_inside": {"feet": Vector3(-5, 0, -21), "look": Vector3(-5, 1.5, -26)},
	"door_booth": {"feet": Vector3(-7.4, 0, -22), "look": Vector3(-9.4, 1.2, -22)},
	"door_back_gate_inside": {"feet": Vector3(7, 0, 22.5), "look": Vector3(7, 1.4, 26)},
	"door_back_gate_out": {"feet": Vector3(8.5, 0, 27.5), "look": Vector3(7, 1.4, 25)},
	"door_roller_yard": {"feet": Vector3(-2, 0, -17), "look": Vector3(-2, 2.2, -10.25)},
	"door_roller_inside": {"feet": Vector3(-5, 0, -5), "look": Vector3(-8, 2.2, -10.5)},
	"door_side": {"feet": Vector3(-23.5, 0, -6), "look": Vector3(-20.25, 1.2, -6)},
	"door_annex": {"feet": Vector3(-29.5, 0, 11.5), "look": Vector3(-26.25, 1.2, 10.8)},
	"door_annex_roof": {"feet": Vector3(-24, 4.75, 2.1), "look": Vector3(-20.25, 5.8, 2.1)},
	"door_weak_wall": {"feet": Vector3(-10, 0, 18.5), "look": Vector3(-10, 1.2, 15.25)},
	"door_fire_escape": {"feet": Vector3(22.4, 4.5, 6.2), "look": Vector3(20.1, 5.6, 6)},
	"door_office_entrance": {"feet": Vector3(5, 0, 6), "look": Vector3(8.13, 1.3, 6)},
	"door_security": {"feet": Vector3(16.3, 0, 6.5), "look": Vector3(16.9, 1.2, 5.1)},
	"door_manager": {"feet": Vector3(10.4, 4.5, 6.4), "look": Vector3(11, 5.6, 5.1)},
	"door_vault": {"feet": Vector3(14.2, 4.5, 6.2), "look": Vector3(16.9, 5.6, 5.1)},
	"door_office_two": {"feet": Vector3(15.6, 4.5, 6.0), "look": Vector3(16.5, 5.6, 6.9)},
	"door_bridge": {"feet": Vector3(4, 4.5, 6), "look": Vector3(8.13, 5.6, 6)},
	"door_tunnel_gate": {"feet": Vector3(39, -2.4, -5), "look": Vector3(36.85, -1.4, -5)},
	"door_tunnel_gate_inside": {"feet": Vector3(34, -2.5, -5), "look": Vector3(36.85, -1.4, -5)},
	"door_boiler_tunnel": {"feet": Vector3(16.5, -4, -5), "look": Vector3(19.75, -3, -5)},
	# Rooms, keys and devices.
	"security_room_desk": {"feet": Vector3(16, 0, 3.8), "look": Vector3(19.4, 1.2, 2.2)},
	"security_console": {"feet": Vector3(16.05, 0, 1.6), "look": Vector3(16.05, 1.3, 0.25)},
	"vault_turret": {"feet": Vector3(16.9, 4.5, 4.4), "look": Vector3(16.9, 5.2, 1.0)},
	"manager_desk": {"feet": Vector3(10.8, 4.5, 3.6), "look": Vector3(9.2, 5.1, 0.7)},
	"break_room_table": {"feet": Vector3(9.6, 0, 3.8), "look": Vector3(13.1, 0.7, 2.4)},
	"locker_bench": {"feet": Vector3(15.5, 0, 9), "look": Vector3(13.65, 0.4, 10.2)},
	"office_pcs": {"feet": Vector3(16.2, 4.5, 9.5), "look": Vector3(16.2, 5.6, 14.7)},
	"network_switch": {"feet": Vector3(17.2, -4, 4.5), "look": Vector3(19.49, -2.5, 4.6)},
	# M9e: corridor-side control panels on the corridors' side walls, the barred gates.
	"panel_office_entrance": {"feet": Vector3(10.2, 0, 6.2), "look": Vector3(8.4, 1.25, 6.6)},
	"panel_bridge_door": {"feet": Vector3(10.2, 4.5, 6.2), "look": Vector3(8.4, 5.75, 6.6)},
	"panel_fire_escape_door": {"feet": Vector3(17.8, 4.5, 6.2), "look": Vector3(19.6, 5.75, 6.6)},
	"panel_catwalk_stairs_in": {"feet": Vector3(10.0, 4.5, 13.4), "look": Vector3(8.4, 5.75, 14.6)},
	"panel_catwalk_stairs_out": {"feet": Vector3(5.6, 4.5, 14.0), "look": Vector3(7.8, 5.75, 14.8)},
	"gate_bars_road": {"feet": Vector3(-6.5, 0, -29), "look": Vector3(-5, 1.4, -18)},
	"back_gate_bars_out": {"feet": Vector3(7.5, 0, 29), "look": Vector3(7, 1.4, 20)},
	# M9e: the yard's switch and controller in the gate booth, and the switch seen through the west window.
	"yard_switch": {"feet": Vector3(-11.6, 0, -21.8), "look": Vector3(-9.5, 1.5, -22.0)},
	"yard_switch_window": {"feet": Vector3(-16, 0, -21), "look": Vector3(-9.5, 1.5, -23.4)},
	"breaker_a": {"feet": Vector3(-23.5, 0, 5.5), "look": Vector3(-26, 1.4, 4)},
	"sirens_dock": {"feet": Vector3(0, 0, -16), "look": Vector3(0, 2.0, -10.5)},
	# Each camera's point of view.
	"view_camera_gate": {"cam": true, "view": DEVICES + "CameraGate"},
	"view_camera_yard": {"cam": true, "view": DEVICES + "CameraYard"},
	"view_camera_hall": {"cam": true, "view": DEVICES + "CameraHall"},
	"view_camera_office": {"cam": true, "view": DEVICES + "CameraOffice"},
	"view_vault_turret": {"cam": true, "view": DEVICES + "VaultTurret"},
	# The security console's Network tab.
	"terminal_network":
	{"feet": Vector3(16.05, 0, 1.0), "look": Vector3(16.05, 1.45, 0.25), "terminal": DEVICES + "SecurityConsole"},
}
