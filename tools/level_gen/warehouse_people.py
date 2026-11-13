#!/usr/bin/env python3
"""Generates the warehouse's people, items and mission props (M9 wave 2, design/levels/mission-warehouse.md).

Writes levels/mission/population/people.tscn, instanced in levels/mission/warehouse.tscn as
`Population/People`: guards with their patrol routes, the equipment to find, the mission props (the
prototype, the shipment, the gas cylinders and the weak-wall panel they breach), throwable props,
the furniture items rest on and the lamps the guard posts need. Doors, locks, keycards, devices and
notes are another scene's (`Population/Security`).

Positions come from the layout markers (warehouse.py POPULATION): a guard stands on its marker, a
route runs through its PatrolPoints, an item lies on (or rests on furniture under) its marker. Edit
this script (or the markers in warehouse.py) and re-run it, never the .tscn by hand.
Run from the project root: py -3.12 tools/level_gen/warehouse_people.py
"""

import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import warehouse as wh  # noqa: E402
from builder import Builder, box  # noqa: E402
from tscn import Raw, transform, yaw_basis  # noqa: E402

OUT = "levels/mission/population/people.tscn"
GUARDS = "res://actors/guard/"
SHIPMENT_TAG = "mission.shipment"


def marker(group, name):
    for entry_name, pos, yaw in wh.POPULATION[group]:
        if entry_name == name:
            return pos, yaw
    raise KeyError(f"{group}/{name}")


def yaw_towards(a, b):
    """Yaw (degrees, 0 = facing -Z) from point a towards point b."""
    return math.degrees(math.atan2(-(b[0] - a[0]), -(b[2] - a[2])))


def tag_list(tags):
    return Raw("Array[StringName]([" + ", ".join(f'&"{t}"' for t in tags) + "])")


# --- guards -------------------------------------------------------------------------------------

GUARD_TAGS = ["actor.guard", "equipment.radio"]
# name, scene, extra tags, route (PatrolPoints names with the wait in seconds at each), or None.
GUARD_SPECS = [
    ("G1GatePost", "guard_pistol", [], None),
    ("G2YardPatrolWest", "guard_baton", [], [("YardWestA", 2.0), ("YardWestB", 2.0), ("YardWestC", 3.0), ("YardWestD", 2.0)]),
    ("G3YardPatrolEast", "guard_smg", [], [("YardEastA", 2.0), ("YardEastB", 2.0), ("YardEastC", 3.0), ("YardEastD", 2.0)]),
    ("G4CatwalkRifle", "guard_rifle", [], [("CatwalkA", 3.0), ("CatwalkB", 3.0)]),
    ("G5SecurityOperator", "guard_pistol", ["access.warehouse_security"], None),
    ("G6BreakRoom", "guard_baton", [], None),
    ("G7VaultDoor", "guard_smg", ["access.warehouse_vault"], None),
    ("G8OffDuty", "guard_baton", [], None),
    ("G9BackStrip", "guard_baton", [], [("BackStripA", 3.0), ("BackStripB", 3.0)]),
    ("G10CatwalkWest", "guard_pistol", [], [("CatwalkWestA", 1.0), ("CatwalkWestB", 3.0)]),
]
# M9g (ADR 0095): every guard's flashlight (guard.tscn) is on while Searching or Alerted; the yard
# patrols (routes outside the buildings) also keep it on while patrolling.
FLASHLIGHT_PATROLS = {"G2YardPatrolWest", "G3YardPatrolEast", "G9BackStrip"}

# M14d (ADR 0142): what guards carry beyond one magazine of their weapon's ammo (guard.tscn's
# ItemLoadout), looted with E once they are down. Keys and keycards go onto their keychain.
# (item kind, count or None, state or None)
KEY_ID = "key_id"
KEY_NAME = "key_name"
GUARD_LOOT = {
    # The break room guard keeps the shift's security keycard (the security door across the corridor).
    "G6BreakRoom": [("keycard", None, {KEY_ID: "warehouse_security", KEY_NAME: "Security keycard"})],
    # The vault door guard carries the vault's keycard.
    "G7VaultDoor": [("keycard", None, {KEY_ID: "warehouse_vault", KEY_NAME: "Vault keycard"})],
    # The off-duty guard's own locker in the locker room.
    "G8OffDuty": [("key", None, {KEY_ID: "warehouse_locker", KEY_NAME: "Locker key"})],
    # The west catwalk patrol carries the office bay key (the bay is on the far side of its bridge).
    "G10CatwalkWest": [("key", None, {KEY_ID: "warehouse_bay", KEY_NAME: "Office bay key"})],
}


def build_guards(b):
    s = b.scene
    routes = b.group("Routes")
    guards = b.group("Guards")
    for name, scene, extra_tags, route in GUARD_SPECS:
        pos, yaw = marker("Guards", name)
        route_path = None
        if route:
            route_script = s.ext_res("Script", "res://actors/common/behaviour/patrol_route.gd")
            route_name = name + "Route"
            route_path = s.add(route_name, routes, "Node3D", props={"script": route_script})
            points = [marker("PatrolPoints", point)[0] for point, _wait in route]
            for index, (point, wait) in enumerate(route):
                at = points[index]
                facing = yaw_towards(at, points[(index + 1) % len(points)])
                s.add(point, route_path, "Marker3D", props={"transform": Raw(transform(at, yaw_basis(facing))), "metadata/wait": float(wait)})
            yaw = yaw_towards(points[0], points[1])
        inst = s.ext_res("PackedScene", GUARDS + scene + ".tscn")
        # M14d: screens name them "Guard" (the interaction frame, the loot screen), not "G 7 vault door".
        props = {"transform": Raw(transform(pos, yaw_basis(yaw))), "metadata/display_name": "Guard"}
        path = s.add(name, guards, instance=inst, props=props)
        if route_path:
            s.override(path + "/Behaviour", {"patrol_route": Raw(f'NodePath("../../../{route_path}")')})
        if extra_tags:
            s.override(path + "/Tags", {"initial_tags": tag_list(GUARD_TAGS + extra_tags)})
        if name in FLASHLIGHT_PATROLS:
            s.override(path + "/Aim/Flashlight", {"on_while_patrolling": Raw("true")})
        if name in GUARD_LOOT:
            s.override(path + "/ItemLoadout", {"items": starting_items(s, name, GUARD_LOOT[name])})


# --- loot (M14d) ----------------------------------------------------------------------------------

ITEM_DATA = {
    "keycard": "keycard/keycard.tres",
    "key": "key/key.tres",
    "medkit": "medkit/medkit.tres",
    "pistol_ammo": "pistol_ammo/pistol_ammo.tres",
    "rifle_rounds": "rifle_rounds/rifle_rounds.tres",
    "shotgun_shells": "shotgun_shells/shotgun_shells.tres",
    "frag_grenade": "grenades/frag/frag_grenade_item.tres",
    "gas_grenade": "grenades/gas/gas_grenade_item.tres",
    "jamming_grenade": "grenades/jamming/jamming_grenade_item.tres",
}


def state_text(state):
    return "{" + ", ".join(f'"{k}": "{v}"' for k, v in state.items()) + "}"


def starting_items(s, owner, entries):
    """An ItemLoadout's `items`: one StartingItem sub-resource per (kind, count, state) entry."""
    script = s.ext_res("Script", "res://items/inventory/starting_item.gd")
    refs = []
    for index, (kind, count, state) in enumerate(entries):
        props = {"script": script, "item": s.ext_res("Resource", "res://items/" + ITEM_DATA[kind])}
        if count is not None:
            props["count"] = count
        if state:
            props["state"] = Raw(state_text(state))
        refs.append(s.sub_res("Resource", props, prefix=f"Loot_{owner}_{index}").text)
    return Raw(f'Array[{script.text}]([' + ", ".join(refs) + "])")


# Inner faces of the office block's north (manager office) and south (locker room, second office) walls.
OFFICE_NORTH, OFFICE_SOUTH = 0.25, 14.75
CONTAINER_SCENES = {
    "supply_crate": "res://objects/containers/supply_crate.tscn",
    "locker": "res://objects/containers/locker.tscn",
    "desk_drawers": "res://objects/containers/desk_drawers.tscn",
}
# Back from the origin to the back face (the scenes' front is +Z), plus 2 cm off the wall.
CONTAINER_BACK = {"supply_crate": 0.33, "locker": 0.27, "desk_drawers": 0.34}
# (name, kind, wall the back stands against: (x or z of its face, "N"/"S"/"E"/"W" = the wall's side
# of the container), the coordinate along the wall, floor y, items, lock: None (scene default),
# "open" (unlocked) or a key id (locked with that key).
CONTAINERS = [
    # Hall, dock: against the north wall east of roller door 2, beside the metal crate (FragDock moved in).
    ("SupplyCrateDock", "supply_crate", (wh.HALL_Z0, "N"), 8.3, 0.0, [("frag_grenade", None, None), ("pistol_ammo", 10, None), ("rifle_rounds", 15, None)], None),
    # Basement store: against the west wall south of the lockpick shelf.
    ("SupplyCrateStore", "supply_crate", (8.0, "W"), 4.85, wh.BASE_Y, [("medkit", None, None), ("pistol_ammo", 10, None), ("shotgun_shells", 6, None)], None),
    # Back strip: a stash in the dark behind the back container (south face z 21.5), east of the hiding spot.
    ("SupplyCrateBackStrip", "supply_crate", (21.5, "N"), -25.0, 0.0, [("medkit", None, None), ("pistol_ammo", 10, None)], None),
    # Locker room, south wall: G8's locker (locked; his key, or lockpicks: the gas grenade moved in) and an open one.
    ("LockerOffDuty", "locker", (OFFICE_SOUTH, "S"), 14.6, wh.OFF_GROUND, [("gas_grenade", None, None), ("medkit", None, None), ("pistol_ammo", 10, None)], "warehouse_locker"),
    ("LockerSpare", "locker", (OFFICE_SOUTH, "S"), 15.3, wh.OFF_GROUND, [("shotgun_shells", 6, None)], "open"),
    # Manager office: drawers right of the desk (the manager's jammer moved in) with the second office's key.
    ("DrawersManager", "desk_drawers", (OFFICE_NORTH, "N"), 10.35, wh.OFF_UP, [("jamming_grenade", None, None), ("key", None, {KEY_ID: "warehouse_office_two", KEY_NAME: "Office two key"})], None),
    # Second office: drawers between the two desks (south wall).
    ("DrawersOffice", "desk_drawers", (OFFICE_SOUTH, "S"), 16.25, wh.OFF_UP, [("medkit", None, None), ("pistol_ammo", 6, None)], None),
]
# Front (the scenes' +Z) facing away from the wall the back stands against.
CONTAINER_YAW = {"N": 0.0, "S": 180.0, "W": 90.0, "E": -90.0}


def build_containers(b):
    s = b.scene
    group = b.group("Containers")
    for name, kind, (face, side), along, floor_y, items, lock in CONTAINERS:
        back = CONTAINER_BACK[kind]
        if side == "N":
            pos = (along, floor_y, face + back)
        elif side == "S":
            pos = (along, floor_y, face - back)
        elif side == "W":
            pos = (face + back, floor_y, along)
        else:
            pos = (face - back, floor_y, along)
        inst = s.ext_res("PackedScene", CONTAINER_SCENES[kind])
        path = s.add(name, group, instance=inst, props={"transform": Raw(transform(pos, yaw_basis(CONTAINER_YAW[side])))})
        s.override(path + "/ItemLoadout", {"items": starting_items(s, name, items)})
        if lock == "open":
            s.override(path + "/Lockable", {"locked": Raw("false")})
        elif lock is not None:
            data = s.sub_res(
                "Resource",
                {
                    "script": s.ext_res("Script", "res://objects/locks/mechanical_lock_data.gd"),
                    "pins": Raw('Array[StringName]([&"standard", &"standard", &"standard"])'),
                    "pin_seed": 1420 + len(name),
                    "key_id": Raw(f'&"{lock}"'),
                },
                prefix=f"Lock_{name}",
            )
            s.override(path + "/MechanicalLock", {"data": data})


# --- furniture, items and props -------------------------------------------------------------------

OBJECTS = "res://objects/"
ITEMS = "res://items/"
# Half heights of the pickups' collision boxes (they rest on a surface at their centre minus this).
PICKUPS = {
    "silencer": (ITEMS + "attachments/silencer/silencer_pickup.tscn", 0.056),
    "shotgun": (ITEMS + "weapons/shotgun/shotgun_pickup.tscn", 0.108),
    "sniper_rifle": (ITEMS + "weapons/sniper_rifle/sniper_rifle_pickup.tscn", 0.077),
    "sniper_rounds": (ITEMS + "sniper_rounds/sniper_rounds.tscn", 0.025),
    "shotgun_shells": (ITEMS + "shotgun_shells/shotgun_shells.tscn", 0.035),
    "rifle_rounds": (ITEMS + "rifle_rounds/rifle_rounds.tscn", 0.035),
    "pistol_ammo": (ITEMS + "pistol_ammo/pistol_ammo.tscn", 0.03),
    "lockpick": (ITEMS + "lockpick/lockpick.tscn", 0.01),
    "biocell": (ITEMS + "biocell/biocell.tscn", 0.06),
    "medkit": (ITEMS + "medkit/medkit.tscn", 0.045),
    "prototype": (ITEMS + "prototype/prototype.tscn", 0.08),
    "deck": (ITEMS + "deck/deck.tscn", 0.02),
    "frag_grenade": (ITEMS + "grenades/frag/frag_grenade_pickup.tscn", 0.0525),
    "gas_grenade": (ITEMS + "grenades/gas/gas_grenade_pickup.tscn", 0.0525),
    "emp_grenade": (ITEMS + "grenades/emp/emp_grenade_pickup.tscn", 0.0525),
    "jamming_grenade": (ITEMS + "grenades/jamming/jamming_grenade_pickup.tscn", 0.0525),
}
PROPS = {
    "small_crate": (OBJECTS + "small_crate/small_crate.tscn", 0.3, ["material.wood", "object.crate"]),
    "large_crate": (OBJECTS + "large_crate/large_crate.tscn", 0.6, ["material.wood", "object.crate"]),
    "metal_crate": (OBJECTS + "metal_crate/metal_crate.tscn", 0.4, ["material.metal", "object.crate"]),
    "cardboard_box": (OBJECTS + "cardboard_box/cardboard_box.tscn", 0.25, ["material.cardboard", "object.box"]),
    "explosive_barrel": (OBJECTS + "explosive_barrel/explosive_barrel.tscn", 0.45, ["material.metal", "object.barrel", "object.explosive"]),
    "glass_bottle": (OBJECTS + "glass_bottle/glass_bottle.tscn", 0.15, ["material.glass", "object.bottle"]),
    "gas_cylinder": (OBJECTS + "gas_cylinder/gas_cylinder.tscn", 0.65, ["material.metal", "object.gas_cylinder", "object.explosive"]),
}
# Clearance between a resting body and the surface under it (no impact noise at load).
REST = 0.005

# Furniture (static Ledge blocks: x0, x1, z0, z1, height, floor y, surface).
FURNITURE = [
    ("VaultPedestal", 18.6, 19.4, 3.1, 3.9, 0.8, wh.OFF_UP, "metal"),
    ("SecurityGunTable", 18.85, 19.74, 3.75, 4.74, 0.9, wh.OFF_GROUND, "metal"),
    ("StoreShelf", 8.01, 8.8, 2.3, 3.7, 0.9, wh.BASE_Y, "metal"),
    ("BreakRoomTable", 8.8, 10.0, 3.4, 4.2, 0.75, wh.OFF_GROUND, "wood"),
    ("OffDutyCot", 17.5, 19.4, 10.6, 11.4, 0.45, wh.BASE_Y, "wood"),
]
# The lockers in the locker room (east wall): a bank with two open lockers, a shelf at LOCKER_SHELF.
LOCKER_X0, LOCKER_X1, LOCKER_Z0, LOCKER_Z1 = 19.2, 19.74, 10.2, 13.8
LOCKER_H = 1.9
LOCKER_SHELF = 0.95
OPEN_LOCKERS = [11.4, 12.6]  # centre z of the open lockers (0.5 m wide)

# (name, kind, position of the bottom centre, yaw, count or None, extra state or None)
ITEM_SPECS = [
    ("Silencer", "silencer", (19.45, wh.OFF_GROUND + LOCKER_SHELF, 12.6), 90.0, None),
    ("RifleRounds", "rifle_rounds", (19.45, wh.OFF_GROUND + LOCKER_SHELF, 11.4), 90.0, 30),
    ("SniperRifle", "sniper_rifle", (42.6, wh.TOWER_DECK_Y, -13.2), 0.0, None),
    ("SniperRounds", "sniper_rounds", (43.2, wh.TOWER_DECK_Y, -13.6), 30.0, 8),
    ("Shotgun", "shotgun", (19.3, wh.OFF_GROUND + 0.9, 4.4), 90.0, None),
    ("ShotgunShells", "shotgun_shells", (19.1, wh.OFF_GROUND + 0.9, 3.95), 0.0, 12),
    ("Lockpicks", "lockpick", (8.4, wh.BASE_Y + 0.9, 3.0), 90.0, 2),
    ("Biocell1", "biocell", (-25.5, 0.0, 12.0), 0.0, None),
    ("Biocell2", "biocell", (32.0, wh.DITCH_Y, -8.6), 0.0, None),
    ("PistolAmmoRack", "pistol_ammo", (-13.0, wh.RACK_DECKS[1], 9.0), 0.0, 10),
    ("PistolAmmoBreakRoom", "pistol_ammo", (9.6, wh.OFF_GROUND + 0.75, 3.7), 15.0, 6),
    ("Medkit2", "medkit", (18.5, wh.BASE_Y, -0.9), 0.0, None),
    ("Prototype", "prototype", (19.0, wh.OFF_UP + 0.8, 3.5), 90.0, None),
    # M12: the deck on the upper office desk.
    ("Deck", "deck", (17.45, 5.245, 14.1), 0.0, None),
    # M9f: the cache shed behind the large crate (Combat Strength), back strip, south-west corner.
    ("CacheMedkit", "medkit", (-33.95, 0.0, 23.45), 0.0, None),
    ("CacheAmmo", "pistol_ammo", (-33.6, 0.0, 23.4), 20.0, 10),
    # M14c (ADR 0131): grenades as loot, none on guards. A frag on the security room's gun table by the
    # shotgun shells; EMP on the basement store shelf by the lockpicks. M14d: the dock's frag, the
    # locker room's gas grenade and the manager's jammer moved into containers (CONTAINERS).
    ("FragSecurity", "frag_grenade", (19.5, wh.OFF_GROUND + 0.9, 3.95), 0.0, None),
    ("EmpStore", "emp_grenade", (8.4, wh.BASE_Y + 0.9, 2.6), 0.0, None),
]

# The outgoing shipment on the dock (between the roller doors, around the Shipment marker).
SHIPMENT = [
    ("LargeCrate1", "large_crate", (-0.7, 0.0, -6.5)),
    ("LargeCrate2", "large_crate", (0.55, 0.0, -6.5)),
    ("LargeCrate3", "large_crate", (-0.1, 1.2, -6.5)),
    ("SmallCrate1", "small_crate", (1.65, 0.0, -6.2)),
    ("SmallCrate2", "small_crate", (1.65, 0.0, -6.85)),
    ("CardboardBox1", "cardboard_box", (-1.65, 0.0, -6.15)),
    ("CardboardBox2", "cardboard_box", (-1.65, 0.0, -6.75)),
    ("FuelDrum", "explosive_barrel", (2.5, 0.0, -7.3)),
]
# Gas cylinders outside the weak wall: close enough to chain (0.4 m apart) and to breach the panel.
GAS_CYLINDERS = [(-11.25, 15.73), (-11.65, 15.75), (-11.45, 16.1)]
WEAK_WALL = (-10.0, 0.0, 15.25)
# Loose props: cover, things to throw (noise), to stack or to carry.
LOOSE_PROPS = [
    ("BoothBox1", "cardboard_box", (-14.0, 0.0, -21.0), 10.0),
    ("BoothBox2", "cardboard_box", (-14.3, 0.0, -20.4), -20.0),
    ("DockMetalCrate", "metal_crate", (7.0, 0.0, -8.0), 0.0),
    ("DockBox", "cardboard_box", (7.8, 0.0, -7.5), 15.0),
    ("BackStripCrate1", "small_crate", (-15.5, 0.0, 17.2), 0.0),
    ("BackStripCrate2", "small_crate", (-14.8, 0.0, 17.3), 10.0),
    ("BreakRoomBottle1", "glass_bottle", (9.2, wh.OFF_GROUND + 0.75, 3.65), 0.0),
    ("BreakRoomBottle2", "glass_bottle", (9.3, wh.OFF_GROUND + 0.75, 3.95), 0.0),
    # M9f (ADR 0093): the large crate (60 kg) closing the cache shed's opening: carried away only with
    # Combat Strength (70 kg limit); two small crates to stack under the annex's high window.
    ("CacheCrate", "large_crate", (-33.8, 0.0, 22.5), 0.0),
    ("WindowCrate1", "small_crate", (-21.7, 0.0, 14.1), 0.0),
    ("WindowCrate2", "small_crate", (-21.1, 0.0, 14.9), 15.0),
]
# Extra lamps (building circuit) for guard posts that need light: the rifle guard's catwalk.
LAMPS = [
    ("wall_lamp", "CatwalkNorthMid", (-10.0, wh.CW + 2.0, wh.HALL_Z0 + 0.02), 0.0, 1.0, 6.0),
    ("ceiling_lamp", "BridgeLamp", (1.0, wh.HALL_H - 0.05, 6.0), 0.0, 1.2, 6.0),
    # M9e: the second catwalk patrol turns at the bridge's east end, the rifle guard at the east catwalk.
    ("ceiling_lamp", "BridgeEastLamp", (5.5, wh.HALL_H - 0.05, 6.0), 0.0, 1.2, 6.0),
    ("wall_lamp", "CatwalkEast", (wh.HALL_X1 - 0.02, wh.CW + 2.0, -3.0), -90.0, 1.0, 6.0),
]


def build_items(b):
    s = b.scene
    furniture = b.group("Furniture")
    for name, x0, x1, z0, z1, height, y0, surface in FURNITURE:
        b.block(name, furniture, x0, x1, z0, z1, height, y0=y0, surface=surface)
    # Locker bank: a solid block with two open lockers (west faces) cut down to the shelf.
    cuts = []
    for index, centre in enumerate(OPEN_LOCKERS):
        cuts.append(box((LOCKER_X0 - 0.05, wh.OFF_GROUND + LOCKER_SHELF, centre - 0.22), (LOCKER_X1 - 0.06, wh.OFF_GROUND + LOCKER_H - 0.06, centre + 0.22), op="subtraction", name=f"Open{index + 1}"))
    b.csg(
        "Lockers",
        furniture,
        "metal",
        [box((LOCKER_X0, wh.OFF_GROUND, LOCKER_Z0), (LOCKER_X1, wh.OFF_GROUND + LOCKER_H, LOCKER_Z1), name="Bank")] + cuts,
    )
    items = b.group("Items")
    for name, kind, pos, yaw, count in ITEM_SPECS:
        scene, half = PICKUPS[kind]
        inst = s.ext_res("PackedScene", scene)
        centre = (pos[0], pos[1] + half + REST, pos[2])
        path = s.add(name, items, instance=inst, props={"transform": Raw(transform(centre, yaw_basis(yaw)))})
        if count is not None:
            s.override(path + "/ItemPickup", {"count": count})


def add_prop(b, parent, name, kind, pos, yaw=0.0, extra_tags=None):
    scene, half, tags = PROPS[kind]
    inst = b.scene.ext_res("PackedScene", scene)
    centre = (pos[0], pos[1] + half + REST, pos[2])
    path = b.scene.add(name, parent, instance=inst, props={"transform": Raw(transform(centre, yaw_basis(yaw)))})
    if extra_tags:
        b.scene.override(path + "/Tags", {"initial_tags": tag_list(tags + extra_tags)})
    return path


def build_props(b):
    s = b.scene
    shipment = b.group("Shipment")
    for name, kind, pos in SHIPMENT:
        add_prop(b, shipment, name, kind, pos, extra_tags=[SHIPMENT_TAG])
    # The label faces north (the roller doors): "OUTGOING" tells the player this is the shipment.
    sign = s.ext_res("PackedScene", "res://levels/kit/sign.tscn")
    s.add("Label", shipment, instance=sign, props={"transform": Raw(transform((-0.1, 2.8, -6.5), yaw_basis(180.0))), "text": "OUTGOING\nPier 4, 02:00", "size": 1})
    weak = b.group("WeakWall")
    panel = s.ext_res("PackedScene", OBJECTS + "breach_panel/breach_panel.tscn")
    s.add("BreachPanel", weak, instance=panel, props={"transform": Raw(transform(WEAK_WALL))})
    for index, (x, z) in enumerate(GAS_CYLINDERS):
        add_prop(b, weak, f"GasCylinder{index + 1}", "gas_cylinder", (x, 0.0, z))
    loose = b.group("Props")
    for name, kind, pos, yaw in LOOSE_PROPS:
        add_prop(b, loose, name, kind, pos, yaw)
    lamps = b.group("Lamps")
    for kind, name, pos, yaw, energy, rng in LAMPS:
        b.lamp(kind, name, lamps, pos, wh.BUILDING, energy, rng, yaw_basis(yaw))


def build():
    b = Builder("People")
    build_guards(b)
    build_items(b)
    build_props(b)
    build_containers(b)
    return b


def main():
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    build().scene.write(OUT)
    print("wrote", OUT)


if __name__ == "__main__":
    main()
