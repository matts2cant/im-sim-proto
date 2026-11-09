#!/usr/bin/env python3
"""Generates the warehouse's security population (M9 wave 2, design/levels/mission-warehouse.md).

Writes levels/mission/population/security.tscn: a door in every doorway of the layout (with its
locks), the keys, codes and credentials (keycards, datapads) and the security network (cameras, the
vault turret, the security console, the alarm controller, sirens, panic buttons, the radio base
station, breakers A and B, the network switch) plus the M11 hooks (access point, office wall jack,
office PCs). The scene is generated: edit this script and re-run it, never the .tscn by hand.
Coordinates come from warehouse.py (doorways, markers), so a layout change follows.

Run from the project root: py -3.12 tools/level_gen/warehouse_security.py
"""

import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import warehouse as w  # noqa: E402
from tscn import Raw, Scene, pitch_basis, mul_basis, sname, transform, vec2, yaw_basis  # noqa: E402

OUT = "levels/mission/population/security.tscn"

# Circuits (warehouse.py): breaker A = yard lights, breaker B = building lights and the network.
YARD = w.YARD
BUILDING = w.BUILDING

# Keys, codes and credentials.
SIDE_DOOR_CODE = ("warehouse_side_door", "2390")
MANAGER_CODE = ("warehouse_manager_office", "4471")
CONSOLE = ("warehouse_security_console", "dmarsh", "harbor77")
PC1 = ("warehouse_office_pc1", "lpetrova", "tulip24")
PC2 = ("warehouse_office_pc2", "kbrandt", "ferry19")
ACCESS_SECURITY = "warehouse_security"
ACCESS_VAULT = "warehouse_vault"

DOORWAYS = {name: (pos, axis) for name, pos, axis, _lock in w.DOORWAYS}

# Free sides (Lock.free_side): 1 = the door's +Z side, 2 = its -Z side.
FRONT, BACK = 1, 2

# Doors: doorway name -> spec. yaw: the door's rotation (its +X is the pocket side, +Z its front);
# wall: wall thickness (control panels on its faces); settings: DoorSettings file; locked; locks
# (kind, data, side the key is used from, free side); tags; circuit (a Powered on the door); cabled
# (linked to the security switch).
DOORS = {
    "FrontGate": {"yaw": 0, "wall": 0.4, "settings": "vehicle_gate_settings", "locks": [("electronic", None, BACK, 0)], "tags": ["door.fail_secure"], "circuit": YARD, "cabled": True},
    "BoothDoor": {"yaw": 90, "wall": 0.2},
    "BackGate": {"yaw": 0, "wall": 0.3, "settings": "fence_gate_settings", "locked": True, "locks": [("mechanical", 4, FRONT, BACK)]},
    "SideDoor": {"yaw": 90, "wall": 0.5, "locked": True, "locks": [("keypad", SIDE_DOOR_CODE, BACK, FRONT)]},
    "RollerDoor1": {"yaw": 0, "wall": 0.5, "settings": "roller_door_settings"},
    "RollerDoor2": {"yaw": 0, "wall": 0.5, "settings": "roller_door_settings"},
    "AnnexDoor": {"yaw": 90, "wall": 0.5, "locked": True, "locks": [("mechanical", 3, BACK, 0)]},
    "AnnexRoofDoor": {"yaw": -90, "wall": 0.5, "locked": True, "locks": [("mechanical", 3, FRONT, BACK)]},
    "WeakWall": {"yaw": 0, "wall": 0.5, "settings": "wall_panel_settings", "locked": True, "breakable": True},
    "FireEscapeDoor": {"yaw": 90, "wall": 0.75, "locked": True, "locks": [("mechanical", 3, FRONT, BACK)]},
    "OfficeEntrance": {"yaw": 90, "wall": 0.25},
    "BreakRoomHall": {"yaw": 0, "wall": 0.25},
    "BreakRoomCorridor": {"yaw": 0, "wall": 0.25},
    "SecurityDoor": {
        "yaw": 0, "wall": 0.25, "locked": True, "locks": [("keycard", ACCESS_SECURITY, FRONT, BACK), ("electronic", None, FRONT, BACK)],
        "tags": ["door.fail_secure"], "circuit": BUILDING, "cabled": True,
    },
    "StairsGround": {"yaw": 0, "wall": 0.25},
    "LockerRoom": {"yaw": 0, "wall": 0.25},
    "BridgeDoor": {"yaw": 90, "wall": 0.25, "locked": True, "locks": [("electronic", None, BACK, FRONT)], "tags": ["door.fail_safe"], "circuit": BUILDING, "cabled": True},
    "ManagerDoor": {"yaw": 0, "wall": 0.25, "locked": True, "locks": [("keypad", MANAGER_CODE, FRONT, BACK)]},
    "VaultDoor": {
        "yaw": 0, "wall": 0.25, "locked": True, "locks": [("keycard", ACCESS_VAULT, FRONT, BACK), ("electronic", None, FRONT, BACK)],
        "tags": ["door.fail_secure"], "circuit": BUILDING, "cabled": True,
    },
    "StairsUpper": {"yaw": 0, "wall": 0.25},
    "CatwalkStairsDoor": {"yaw": 90, "wall": 0.25},
    "OfficeTwo": {"yaw": 0, "wall": 0.25, "locked": True, "locks": [("mechanical", 2, BACK, FRONT)]},
    "BoilerStore": {"yaw": 0, "wall": 0.5},
    "BoilerTunnel": {"yaw": 90, "wall": 0.5},
    "TunnelGate": {"yaw": -90, "wall": 0.3, "locked": True, "locks": [("mechanical", 4, BACK, FRONT)]},
}


def facing(direction):
    """Yaw (degrees) whose +Z points along `direction` (x, z): wall devices face out of +Z."""
    return math.degrees(math.atan2(direction[0], direction[1]))


def towards(origin, target):
    return facing((target[0] - origin[0], target[2] - origin[2]))


# Security network devices: name -> (scene key, position, yaw of +Z, extra). Cameras look along +Z
# (tilt: degrees down), wall devices stand on the wall face with +Z out of the wall.
CAMERA_GATE = (-9.29, 2.35, -23.7)
CAMERA_YARD = (20.42, 4.0, -10.62)
CAMERA_HALL = (-1.0, 6.5, -9.98)
CAMERA_OFFICE = (19.74, 6.88, 6.0)
CAMERAS = {
    "CameraGate": (CAMERA_GATE, towards(CAMERA_GATE, (-5.0, 0.0, -22.5)), 20.0),
    "CameraYard": (CAMERA_YARD, towards(CAMERA_YARD, (8.0, 0.0, -14.0)), 20.0),
    "CameraHall": (CAMERA_HALL, 0.0, 30.0),
    "CameraOffice": (CAMERA_OFFICE, -90.0, 20.0),
}
# Sirens (heard up to 34 m of path): every guard post and patrol point in the yard and the hall,
# and the office and basement guards, is within 31 m of one (warehouse_security_network_test.gd).
# A PATH stimulus starts at the navmesh point closest to the siren: mount them low enough (2 m
# outside, 1.2 m in the upper corridor) that it is the floor in front of them, not a catwalk behind
# the wall or a roof above.
SIRENS = {
    "SirenDock": ((0.0, 2.0, -10.52), 180.0),  # hall north wall, outside: the dock apron
    "SirenEastYard": ((20.52, 2.0, -6.0), 90.0),  # hall east wall, outside
    "SirenBackStrip": ((2.0, 2.0, 15.52), 0.0),  # hall south wall, outside
    "SirenWestYard": ((-26.52, 2.0, 12.2), -90.0),  # annex west wall, outside (south of its door)
    "SirenHallNorth": ((6.0, 6.5, -9.98), 0.0),  # hall north wall, inside, over the north catwalk
    "SirenHallWest": ((-19.98, 6.5, -4.0), 90.0),  # hall west wall, inside, over the west catwalk
    "SirenOfficeGround": ((8.27, 2.0, 6.0), 90.0),  # ground corridor, west end
    "SirenOfficeUpper": ((14.0, w.OFF_UP + 1.2, 5.27), 0.0),  # upper corridor, between the manager and vault doors
    "SirenBasement": ((14.0, w.BASE_Y + 1.8, 0.02), 0.0),  # basement store, north wall
}
WALL_DEVICES = {
    # name: (scene, position, yaw)
    "AlarmController": ("controller", (19.74, 1.5, 3.0), -90.0),
    "RadioBaseStation": ("base_station", (19.74, 1.2, 1.2), -90.0),
    "PanicButtonSecurity": ("panic", (14.01, 1.3, 2.0), 90.0),
    "PanicButtonBooth": ("panic", (-12.49, 1.3, -20.6), 90.0),
}
TURRET = ((16.9, w.OFF_UP, 1.0), 0.0)
SECURITY_CONSOLE = ((16.05, 1.47, 0.26), 0.0)
SWITCH = ((19.49, w.BASE_Y + 1.6, 6.0), -90.0)
BREAKERS = {
    "BreakerA": ((-25.99, 1.4, 4.0), 90.0, YARD, "yard lights"),
    "BreakerB": ((19.49, w.BASE_Y + 1.4, 3.0), -90.0, BUILDING, "building power"),
}
# M11 hooks (M8 devices standing in for them, named so M11 upgrades them in place).
ACCESS_POINT = ((-20.52, 6.0, -2.0), -90.0)
WALL_JACK = ((19.74, w.OFF_UP + 0.4, 10.0), -90.0)
OFFICE_PCS = {
    "OfficePc1": ((14.5, w.OFF_UP + 1.45, 14.74), 180.0, PC1),
    "OfficePc2": ((18.0, w.OFF_UP + 1.45, 14.74), 180.0, PC2),
}

# Furniture (static Ledges) carrying the datapads and keycards: name -> (origin, yaw, width, depth,
# height). A Ledge's origin is the bottom centre of its lip (facing +Z), the block runs towards -Z.
FURNITURE = {
    "ManagerDesk": ((9.2, w.OFF_UP, 1.1), 0.0, 1.6, 0.8, 0.8),
    "BreakRoomTable": ((13.1, w.OFF_GROUND, 3.3), 0.0, 1.0, 1.6, 0.73),
    "LockerBench": ((13.65, w.OFF_GROUND, 11.0), 0.0, 0.6, 2.0, 0.48),
    "SecurityDesk": ((19.3, w.OFF_GROUND, 3.0), 0.0, 0.8, 1.4, 0.78),
    "OfficeDesk1": ((14.5, w.OFF_UP, 13.9), 180.0, 1.4, 0.8, 0.75),
    "OfficeDesk2": ((18.0, w.OFF_UP, 13.9), 180.0, 1.4, 0.8, 0.75),
}

# Datapads: name -> (position, entry id, title, text, codes).
DATAPADS = {
    "SideDoorCodeNote": (
        (-21.8, 0.36, -9.0),
        "warehouse.side_door_code",
        "Crumpled note",
        "Side door code changed again: %s. Stop propping it open with a pallet. - Facilities" % SIDE_DOOR_CODE[1],
        {SIDE_DOOR_CODE[0]: SIDE_DOOR_CODE[1]},
    ),
    "ShiftNotes": (
        (13.0, w.OFF_GROUND + 0.76, 2.4),
        "warehouse.shift_notes",
        "Night shift notes",
        "Hale wants his office kept shut: the door code is %s, don't leave it open. Klaus, your office PC login is %s / %s, write it somewhere better than the break room."
        % (MANAGER_CODE[1], PC2[1], PC2[2]),
        {MANAGER_CODE[0]: MANAGER_CODE[1], PC2[0]: "%s:%s" % (PC2[1], PC2[2])},
    ),
    "ManifestDatapad": (
        (8.9, w.OFF_UP + 0.83, 0.7),
        "warehouse.manifest",
        "Shipment manifest",
        "Outgoing, dock 1, tonight: 14 crates marked 'agricultural pumps'. Actual contents per the client: see the vault inventory. Boat pick-up at the river pontoon before dawn. Do not log it in the system. - E. Hale",
        {},
    ),
    "ConsoleAudit": (
        (9.6, w.OFF_UP + 0.83, 0.7),
        "warehouse.console_audit",
        "Console audit",
        "Security console in the ground-floor security room: user %s, password %s. It runs the cameras, the vault door and the vault turret. Change it after the audit. - E. Hale"
        % (CONSOLE[1], CONSOLE[2]),
        {CONSOLE[0]: "%s:%s" % (CONSOLE[1], CONSOLE[2])},
    ),
    "Pc1Note": (
        (14.1, w.OFF_UP + 0.78, 14.3),
        "warehouse.pc1_note",
        "Sticky note",
        "PC login: %s / %s" % (PC1[1], PC1[2]),
        {PC1[0]: "%s:%s" % (PC1[1], PC1[2])},
    ),
}
# Keycards: name -> (position, access id).
KEYCARDS = {
    "KeycardSecurity": ((13.65, w.OFF_GROUND + 0.51, 10.2), ACCESS_SECURITY),
    "KeycardVault": ((19.35, w.OFF_GROUND + 0.81, 2.4), ACCESS_VAULT),
}

SCENES = {
    "door": "res://objects/door/door.tscn",
    "breakable_door": "res://objects/door/breakable_door.tscn",
    "camera": "res://objects/camera/security_camera.tscn",
    "turret": "res://objects/turret/turret.tscn",
    "terminal": "res://objects/terminal/terminal.tscn",
    "controller": "res://objects/alarm/alarm_controller.tscn",
    "siren": "res://objects/alarm/siren.tscn",
    "panic": "res://objects/alarm/panic_button.tscn",
    "base_station": "res://objects/alarm/radio_base_station.tscn",
    "switch": "res://objects/devices/network_switch.tscn",
    "breaker": "res://objects/breaker_panel/breaker_panel.tscn",
    "datapad": "res://objects/datapad/datapad.tscn",
    "keycard": "res://items/keycard/keycard.tscn",
    "ledge": "res://levels/kit/ledge.tscn",
}
SCRIPTS = {
    "keypad": "res://objects/locks/keypad_lock.gd",
    "keypad_data": "res://objects/locks/keypad_lock_data.gd",
    "mechanical": "res://objects/locks/mechanical_lock.gd",
    "mechanical_data": "res://objects/locks/mechanical_lock_data.gd",
    "keycard": "res://objects/locks/keycard_lock.gd",
    "keycard_data": "res://objects/locks/keycard_lock_data.gd",
    "electronic": "res://objects/locks/electronic_lock.gd",
    "powered": "res://objects/components/powered.gd",
}
LOCK_NODE = {"keypad": "KeypadLock", "mechanical": "MechanicalLock", "keycard": "KeycardLock", "electronic": "ElectronicLock"}


def string_names(values):
    return Raw("Array[StringName]([" + ", ".join(f'&"{v}"' for v in values) + "])")


def node_paths(values):
    return Raw("Array[NodePath]([" + ", ".join(f'NodePath("{v}")' for v in values) + "])")


def codes(mapping):
    inner = ", ".join(f'&"{k}": "{v}"' for k, v in mapping.items())
    return Raw("Dictionary[StringName, String]({" + inner + "})")


def build():
    s = Scene("Security")
    scene = {key: s.ext_res("PackedScene", path) for key, path in SCENES.items()}
    script = {key: s.ext_res("Script", path) for key, path in SCRIPTS.items()}
    wall_material = s.ext_res("Material", "res://assets/materials/graybox/wall.tres")
    cabled = []

    # --- Doors ------------------------------------------------------------------------------
    s.add("Doors", ".", "Node3D")
    for name, spec in DOORS.items():
        pos, _axis = DOORWAYS[name]
        key = "breakable_door" if spec.get("breakable") else "door"
        path = s.add(name, "Doors", instance=scene[key], props={"transform": Raw(transform(pos, yaw_basis(spec["yaw"])))})
        tags = ["object.door", "material.metal"] + spec.get("tags", [])
        if spec.get("tags"):
            s.override(f"{path}/Tags", {"initial_tags": string_names(tags)})
        if spec.get("locked"):
            s.override(f"{path}/Lockable", {"locked": True})
        door_props = {"wall_thickness": spec["wall"]}
        settings_name = spec.get("settings")
        if settings_name:
            door_props["settings"] = s.ext_res("Resource", f"res://objects/door/{settings_name}.tres")
        s.override(f"{path}/Door", door_props)
        if spec.get("breakable"):
            # A weak wall: the panel looks like the wall, no control panels.
            s.override(f"{path}/PanelMesh", {"material_override": wall_material})
            for side in ("ControlFront", "ControlBack"):
                s.override(f"{path}/{side}", {"visible": False})
                s.override(f"{path}/{side}Shape", {"disabled": True})
        if spec.get("circuit"):
            s.add("Powered", path, "Node", props={"script": script["powered"], "circuit": sname(spec["circuit"])})
        width = 1.2
        if settings_name == "vehicle_gate_settings":
            width = 6.0
        elif settings_name == "roller_door_settings":
            width = 4.0
        for kind, data, key_side, free in spec.get("locks", []):
            face = (spec["wall"] * 0.5 + 0.02) * (1 if key_side == FRONT else -1)
            props = {"transform": Raw(transform((-(width * 0.5 + 0.3), 1.25, face))), "script": script[kind]}
            if kind == "keypad":
                props["data"] = s.sub_res("Resource", {"script": script["keypad_data"], "code_id": sname(data[0]), "code": data[1]}, prefix="Keypad")
            elif kind == "mechanical":
                props["data"] = s.sub_res(
                    "Resource", {"script": script["mechanical_data"], "pins": string_names(["standard"] * data)}, prefix="Pins"
                )
            elif kind == "keycard":
                props["data"] = s.sub_res("Resource", {"script": script["keycard_data"], "access_id": sname(data)}, prefix="Keycard")
            if free:
                props["free_side"] = free
            s.add(LOCK_NODE[kind], path, "Node3D", props=props)
        if spec.get("cabled"):
            cabled.append(f"Doors/{name}")

    # --- Security network ---------------------------------------------------------------------
    s.add("Devices", ".", "Node3D")
    for name, (pos, yaw, tilt) in CAMERAS.items():
        s.add(name, "Devices", instance=scene["camera"], props={"transform": Raw(transform(pos, yaw_basis(yaw)))})
        if tilt != 20.0:
            s.override(f"Devices/{name}/Pivot/Tilt", {"transform": Raw(transform((0, 0, 0), pitch_basis(-tilt)))})
        cabled.append(f"Devices/{name}")
    pos, yaw = TURRET
    s.add("VaultTurret", "Devices", instance=scene["turret"], props={"transform": Raw(transform(pos, yaw_basis(yaw)))})
    cabled.append("Devices/VaultTurret")
    pos, yaw = SECURITY_CONSOLE
    s.add("SecurityConsole", "Devices", instance=scene["terminal"], props={"transform": Raw(transform(pos, yaw_basis(yaw)))})
    s.override(
        "Devices/SecurityConsole/TerminalUse",
        {"credentials_id": sname(CONSOLE[0]), "username": CONSOLE[1], "password": CONSOLE[2], "label": "security console"},
    )
    cabled.append("Devices/SecurityConsole")
    for name, (key, pos, yaw) in WALL_DEVICES.items():
        s.add(name, "Devices", instance=scene[key], props={"transform": Raw(transform(pos, yaw_basis(yaw)))})
        cabled.append(f"Devices/{name}")
    for name, (pos, yaw) in SIRENS.items():
        s.add(name, "Devices", instance=scene["siren"], props={"transform": Raw(transform(pos, yaw_basis(yaw)))})
        cabled.append(f"Devices/{name}")
    for name, (pos, yaw, circuit, label) in BREAKERS.items():
        s.add(name, "Devices", instance=scene["breaker"], props={"transform": Raw(transform(pos, yaw_basis(yaw)))})
        s.override(f"Devices/{name}/CircuitBreaker", {"circuit": sname(circuit), "label": label})
    # The switch every security device hangs on (basement store, on breaker B): breaking or
    # unpowering it cuts the cameras, panic buttons and console from the controller and the
    # controller from the sirens (the showcase moment).
    pos, yaw = SWITCH
    s.add("SecuritySwitch", "Devices", instance=scene["switch"], props={"transform": Raw(transform(pos, yaw_basis(yaw)))})
    s.override("Devices/SecuritySwitch/Powered", {"circuit": sname(BUILDING)})
    s.override("Devices/SecuritySwitch/Device", {"links": node_paths(["../../../" + p for p in cabled])})

    # --- M11 hooks (separate networks until M11's gateway joins them) ---------------------------
    s.add("Network", ".", "Node3D")
    pos, yaw = ACCESS_POINT
    s.add("AccessPointGuest", "Network", instance=scene["switch"], props={"transform": Raw(transform(pos, yaw_basis(yaw)))})
    s.override("Network/AccessPointGuest/Powered", {"circuit": sname(YARD)})
    pos, yaw = WALL_JACK
    s.add("OfficeWallJack", "Network", instance=scene["switch"], props={"transform": Raw(transform(pos, yaw_basis(yaw)))})
    s.override("Network/OfficeWallJack/Device", {"links": node_paths([f"../../{name}" for name in OFFICE_PCS])})
    for name, (pos, yaw, creds) in OFFICE_PCS.items():
        s.add(name, "Network", instance=scene["terminal"], props={"transform": Raw(transform(pos, yaw_basis(yaw)))})
        s.override(
            f"Network/{name}/TerminalUse",
            {"credentials_id": sname(creds[0]), "username": creds[1], "password": creds[2], "label": "office PC"},
        )

    # --- Furniture, datapads, keycards ----------------------------------------------------------
    s.add("Furniture", ".", "Node3D")
    for name, (origin, yaw, width, depth, height) in FURNITURE.items():
        s.add(
            name,
            "Furniture",
            instance=scene["ledge"],
            props={"transform": Raw(transform(origin, yaw_basis(yaw))), "height": height, "width": width, "depth": depth, "surface": "wood"},
        )
    s.add("Items", ".", "Node3D")
    for name, (pos, entry, title, text, mapping) in DATAPADS.items():
        s.add(name, "Items", instance=scene["datapad"], props={"transform": Raw(transform(pos))})
        props = {"entry_id": sname(entry), "title": title, "text": text}
        if mapping:
            props["codes"] = codes(mapping)
        s.override(f"Items/{name}/Readable", props)
    for name, (pos, access) in KEYCARDS.items():
        s.add(name, "Items", instance=scene["keycard"], props={"transform": Raw(transform(pos))})
        s.override(f"Items/{name}/ItemPickup", {"state": Raw('{"key_id": "%s"}' % access)})
    return s


def main():
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    build().write(OUT)
    print("wrote", OUT)


if __name__ == "__main__":
    main()
