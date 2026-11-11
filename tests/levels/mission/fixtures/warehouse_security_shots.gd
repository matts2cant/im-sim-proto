extends RefCounted
## Review shots of the warehouse's doors and security devices (M9c), merged into
## warehouse_shots.gd's list: run `warehouse_shots.tscn -- shots=<name>,... out=<folder>`. Keys as
## there, plus `view`: a free camera at the eye of a device's view node (a camera's point of view,
## HUD hidden), and `computer`: the player uses that computer, logged in as its first account, on
## `app` (security, mail or files; default security) with `select` selected (a device's name in the
## Security app, a mail's subject or a file's name). Before a shot, `off` turns those circuits off
## and `disable` sends `command.disable` to those devices (both last for the rest of the run: put
## such shots last). `deck` (M12a): a deck plugged into that device, its Map shown (`hack`: those
## routers hacked first; the access lasts for the rest of the run).

const DEVICES := "Population/Security/Devices/"
const NETWORK := "Population/Security/Network/"

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
	# M9h: wall devices clear of doorways and signs: the ground corridor's west end (the office
	# entrance and its siren) and the upper corridor's east end (the FIRE EXIT sign).
	"siren_office_ground": {"feet": Vector3(11.5, 0, 6.0), "look": Vector3(8.3, 1.6, 6.0)},
	"fire_exit_sign": {"feet": Vector3(16.5, 4.5, 6.0), "look": Vector3(19.7, 6.2, 6.0)},
	# Each camera's point of view.
	"view_camera_gate": {"cam": true, "view": DEVICES + "CameraGate"},
	"view_camera_yard": {"cam": true, "view": DEVICES + "CameraYard"},
	"view_camera_hall": {"cam": true, "view": DEVICES + "CameraHall"},
	"view_camera_office": {"cam": true, "view": DEVICES + "CameraOffice"},
	"view_vault_turret": {"cam": true, "view": DEVICES + "VaultTurret"},
	"view_camera_roof": {"cam": true, "view": DEVICES + "CameraRoof"},
	# M9g roof security (ADR 0097): each gap's high beam from the stair landing where the player
	# arrives, standing and crouched; the roof camera and duct B's lit forecourt from the east gap
	# and from the dark beside duct B's housing.
	"roof_beam_west": {"feet": Vector3(-21.4, 9.5, 3.2), "look": Vector3(-19.0, 10.4, 2.97)},
	"roof_beam_west_crouch": {"feet": Vector3(-21.4, 9.5, 3.2), "look": Vector3(-19.0, 10.4, 2.97), "crouch": true},
	"roof_beam_east": {"feet": Vector3(21.4, 9.5, -3.6), "look": Vector3(19.0, 10.4, -3.92)},
	"roof_beam_east_crouch": {"feet": Vector3(21.4, 9.5, -3.6), "look": Vector3(19.0, 10.4, -3.92), "crouch": true},
	"roof_camera_east": {"feet": Vector3(19.2, 9.5, -3.9), "look": Vector3(14.5, 10.6, -8.2)},
	"roof_camera_east_crouch": {"feet": Vector3(19.2, 9.5, -3.9), "look": Vector3(14.5, 10.6, -8.2), "crouch": true},
	"roof_camera_west": {"feet": Vector3(9.4, 9.5, -3.0), "look": Vector3(13.5, 10.8, -8.8)},
	"roof_camera_west_crouch": {"feet": Vector3(9.4, 9.5, -3.0), "look": Vector3(13.5, 10.8, -8.8), "crouch": true},
	"roof_west_arrival": {"feet": Vector3(-18.5, 9.5, 3.0), "look": Vector3(10, 10.5, -6)},
	# M12a (ADR 0114): the security console's Security app on a camera, a door and the alarm group;
	# the office PCs' Mail (an implicit clue), Files, and a Security app that controls nothing.
	"console_cameras":
	{
		"feet": Vector3(16.05, 0, 1.0),
		"look": Vector3(16.05, 1.45, 0.25),
		"computer": DEVICES + "SecurityConsole",
		"select": "Camera Hall",
	},
	"console_door":
	{
		"feet": Vector3(16.05, 0, 1.0),
		"look": Vector3(16.05, 1.45, 0.25),
		"computer": DEVICES + "SecurityConsole",
		"select": "Vault Door",
	},
	"console_alarm":
	{
		"feet": Vector3(16.05, 0, 1.0),
		"look": Vector3(16.05, 1.45, 0.25),
		"computer": DEVICES + "SecurityConsole",
		"select": "Alarm Controller",
	},
	"office_pc2_mail":
	{
		"feet": Vector3(18, 4.5, 14.0),
		"look": Vector3(18, 5.95, 14.74),
		"computer": NETWORK + "OfficePc2",
		"app": "mail",
		"select": "Re: password reset",
	},
	"office_pc2_files":
	{
		"feet": Vector3(18, 4.5, 14.0),
		"look": Vector3(18, 5.95, 14.74),
		"computer": NETWORK + "OfficePc2",
		"app": "files",
		"select": "birthday_card_lena.jpg",
	},
	"office_pc1_security":
	{
		"feet": Vector3(14.5, 4.5, 14.0),
		"look": Vector3(14.5, 5.95, 14.74),
		"computer": NETWORK + "OfficePc1",
	},
	# M12a network: the office wall jack, the network closet in the basement store (RTR-01 between the
	# office and security switches), the deck's Map from the jack before and after hacking RTR-01.
	"office_jack": {"feet": Vector3(18.6, 4.5, 10.3), "look": Vector3(19.74, 4.9, 10)},
	"network_closet": {"feet": Vector3(17.0, -4, 7.0), "look": Vector3(19.49, -2.5, 7.0)},
	# The Security subnet's area switches (a subnet can span several switches).
	"security_room_switch": {"feet": Vector3(16.0, 0, 3.4), "look": Vector3(14.0, 1.4, 3.0)},
	"vault_switch": {"feet": Vector3(16.2, 4.5, 2.2), "look": Vector3(14.0, 5.9, 1.5)},
	"roof_switch": {"feet": Vector3(15.6, 9.5, -8.2), "look": Vector3(16.3, 10.2, -10.0)},
	"deck_map_office":
	{
		"feet": Vector3(18.9, 4.5, 10),
		"look": Vector3(19.74, 4.9, 10),
		"deck": NETWORK + "OfficeWallJack",
		"wait": 2.5,
	},
	"deck_map_hacked":
	{
		"feet": Vector3(18.9, 4.5, 10),
		"look": Vector3(19.74, 4.9, 10),
		"deck": NETWORK + "OfficeWallJack",
		"hack": [NETWORK + "Rtr01"],
		"wait": 3.0,
	},
	# Breaker A's circuit off (the yard devices unreachable: grey) and the hall camera disabled (red).
	"console_states":
	{
		"feet": Vector3(16.05, 0, 1.0),
		"look": Vector3(16.05, 1.45, 0.25),
		"computer": DEVICES + "SecurityConsole",
		"off": ["warehouse_yard"],
		"disable": [DEVICES + "CameraHall"],
		"select": "Camera Hall",
	},
}
