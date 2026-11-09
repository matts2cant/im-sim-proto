# Mission: warehouse

Milestone: M9. Decisions: [ADR 0086](../decisions/0086-warehouse-mission.md).

## Goal

Break into a logistics company's warehouse at night. Read the shipment manifest in the manager's office, then reach the boat at the riverside. Two optional objectives. Every system in the game is used for a real purpose, and every main route works ghost, pacifist or loud.

## Flow

- Separate scene `levels/mission/warehouse.tscn`, loaded by walking through the hub's mission doorway (west wall, north doorway). After extraction the summary offers a way back to the hub. Nothing the player carries in the hub comes along.
- **Fixed starting kit**: baton, the loud pistol (10 in the magazine, 10 spare rounds), 1 medkit. The three augmentations (Cloak, Speed Enhancement, Combat Strength) are available, Energy at 50%. Skills at their defaults (Untrained). The mission is balanced for this kit; equipment is found along the way.
- **Start**: at a van on the north road. A short briefing (text overlay, dismissed by a key) names the objectives. Objectives are listed in the personal log; there are no on-screen waypoint markers.
- **Objectives**
  - Main: read the shipment manifest, a datapad read in place ([ADR 0060](../decisions/0060-datapads-read-in-place-personal-log.md)), in the manager's office on the upper floor of the office block.
  - Optional A: take the prototype from the vault next to the manager's office (turret; keycard or terminal).
  - Optional B: sabotage the outgoing shipment on the loading dock (blow it up or set it on fire).
- **Extraction**: a boat on the riverside behind the back gate (the back gate opens from inside). Extraction needs the main objective.
- **Summary** at extraction: time, alarms raised, kills, knockouts, optional objectives done, badges. Then "Restart mission" or "Return to hub". No route-used stat ([backlog](../backlog.md)).

| Badge | Earned when |
|---|---|
| Ghost | No guard ever reached Alerted, no alarm rang, and no body was found. Suspicious is fine. |
| Pacifist | No death caused by the player, directly or indirectly (explosions, fire, a turret the player retargeted). Knockouts are fine. |

- **Saving**: one shared quicksave slot that records the level; loading it loads that level. The knocked-out and death losing screens work as everywhere ([../game/saving.md](../game/saving.md)).
- **Reinforcements**: 30 s after the first alarm, two guards enter through the front gate (once per mission).
- **Weapon drops**: a character with a weapon (not only guards) drops it as a pickup beside the body when knocked out or killed.

## Level

Night. Built in M9 wave 1 (layout, [ADR 0089](../decisions/0089-warehouse-layout.md)) from graybox kit parts and free CSG. World axes: x west to east, z north to south (north = -Z), y up; origin at the compound centre. Every coordinate below is a world coordinate in `levels/mission/warehouse.tscn` (the area scenes sit at the origin). Lengths in metres.

### Sub-scenes

| Node in `warehouse.tscn` | Scene | Contents |
|---|---|---|
| `WorldEnvironment`, `Moon` | | Night sky, ambient 0.12 (blue), light fog; a dim shadowed moon (DirectionalLight3D: visual only, the light model ignores it) |
| `Exterior` | `levels/mission/areas/exterior.tscn` | Ground slabs, palisade fence and gates, gate booth, containers and climbing aids, cover pallets, truck, dumpster, forklift, van, water tower, river and boundaries, outdoor lights (breaker A) |
| `Hall` | `levels/mission/areas/hall.tscn` | Hall shell (doorways, skylight holes, floor holes), annex, roof (parapets, skylight rails, plant), catwalks, racks, office block, fire escape, annex roof stair, ducts A and B, building lights (breaker B) |
| `Underground` | `levels/mission/areas/underground.tscn` | Basement (boiler room, store), service stair, hatch stair, duct C, service tunnel, drain chamber, ditch and culvert, basement lights |
| `LayoutMarkers` | `levels/mission/areas/layout_markers.tscn` | Marker3D placeholders: `Doorways/` (every doorway, with its intended door below), `Guards/`, `PatrolPoints/`, `Devices/`, `Items/`, `Mission/`, `DarkSpots/`, `LitSpots/` (read by the tests). Wave 2 replaces the placeholders it fills |
| `PlayerSpawn`, `ReinforcementSpawn`, `Extraction`, `Mission` | | The mission contract (below, "Systems") |
| `Navigation` | `LevelNavigation` | Last child; bakes the whole level (about 1.1 s at load) |

**The area scenes are generated**: `tools/level_gen/warehouse.py` (with `builder.py`, `tscn.py`) writes them; edit the script and run `py -3.12 tools/level_gen/warehouse.py` from the project root, never the `.tscn` by hand. `--root` also rewrites `warehouse.tscn` (first build only: it now carries the mission nodes). Wave 2 puts guards, devices, doors, props and items in **its own scenes** instanced in `warehouse.tscn` (for example `levels/mission/population/exterior.tscn` and `interior.tscn`), so the geometry stays regenerable. Each area builds one CSG root per surface group (about 100 CSG roots and 40 lights in the whole level).

### Plan

```text
 z      x -45      -35            -8   -2                 20.5        35  36.7  41.3       50  52.4   58
 -38    [ buildings (boundary, 8 m) .......................................................................]
 -36    | ROAD (concrete) ....... van(-25..-20) S=PlayerSpawn(-19,-31.2) R=ReinforcementSpawn(-5,-31) ..... |
 -27    |grass   [OC1 outside container]       :R:                                       |ramp| [WATER TOWER]
 -25    | N  +==IC1==========[booth]===[ FRONT GATE 6 m ]=====palisade fence 3 m=========+ D  |  deck 20 m
 -22    | E  | IC1 inside  B(-12.5..-9.5)                    truck (2.75..5.25,-23.5..-12.5) | I  |  x 42..50
 -18    | I  |   YardLow/YardHigh(2 high: perch 5 m)  forklift          EastHigh/EastLow   | T  |  z -20..-12
 -15    | G  |   dumpster  side door                FloodDockW  FloodDockE      (25..31)    | C  |  stair tower
 -10.5  | H  |   (-22,-9)  ||  +==RD1(-8)=======RD2(4)==========+  FloodEast      drain  | H  |  x 50..52.4
 -6     | B  |  side door=|   | HALL 40 x 25 x 9 (interior x -20..20, z -10..15)| chamber(31..34,-9..-6.25)
 -4     | O  |             |   |   dock zone z -10..-3.5          hatch(10.5..11.7)  |~tunnel z -6..-4~~|gate
 0      | U  |   [AnnexC]  [ANNEX -26..-20.5 | racks R1 R2 R3 (x -14.2/-6.2/1.8, z -3.5..5.2 | OFFICE BLOCK |
 2      | R  |  container   z 1.5..12.5     | bridge 4.5 m z 5.25..6.75 -> office  6.8..11.0) | x 8..20      |
 6      |    |  (-29..-26.6)  roof 4.75     |                                                 | z 0..15      | (verge)
 12     |    |               (stair to roof)|   SW stair                     fire escape (x 20.5..22.9) |
 15.5   |    |                               +==weak wall(-10)================================+          |headwall
 20     |    |   Back container     pallets   gas cylinders            back strip          EC "FireEscape" 22
 25     |    +==================palisade============[BACK GATE 6.4..7.6]======================+
 33     | QUAY (concrete) ............................... [pontoon 4..10, z 33..38 + boat] E=Extraction(7,35.6)
 50     | RIVER (water at -1.0, invisible wall at the quay edge)  far bank
```

North is up. The basement (boiler room x 8..19.5, z -9..-0.5; store x 8..19.5, z 0..14.75, floor -4.0) lies under the hall's north-east and the office block; the service tunnel runs from the boiler room's east wall (z -6..-4) under the east yard and the fence to the ditch.

### Elevations

| Element | Height (top of the walkable surface) |
|---|---|
| Ground (yard, road, quay, verges) | 0 (slabs 0.3 thick) |
| Fence (palisade: 0.05 m bars every 0.22 m, rails at 0.3 and 2.7) | top 3.0; gates are gaps |
| Containers (6 x 2.5 x 2.5) | 2.5; two high 5.0 |
| Pallet stacks / crates (fixed `Ledge`s, wood) | 1.0-1.3 on the ground; 1.1-1.2 on containers |
| Annex roof | 4.75 (1.0 m parapet, open at the container chain) |
| Hall floor / catwalks / roof | 0 / 4.5 (0.2 slab) / 9.5 (0.5 slab; 1.0 m parapet) |
| Racks: decks | 2.2, 4.4 (next to the bridge), 6.6 (top); skylight goods 8.1 |
| Office block ground / upper floor / roof | 0.02 (rooms stand 2 cm proud of the hall floor) / 4.5 / 7.35 (interior 4.0 and 2.6) |
| Fire escape | bottom landing 1.44, door landing 4.5, roof landing 9.5 |
| Basement floor / ceiling | -4.0 / -1.0 (slab to -0.5 under the hall floor) |
| Tunnel floor | -4.0 at the basement, ramp (15 degrees) to -2.4 at the ditch; 2.2 high |
| Ditch and drain chamber floor | -2.4 (ditch walls to -0.01) |
| Water tower deck | 20.0 (tank above, 1.0 m railing) |
| Ducts (VentSegment, interior 1.2 x 1.2, slopes 25 degrees) | A: 5.6 (catwalk mouth) to 9.7 (roof mouth); B: 9.7 to 7.55 (office roof); C: -2.9 (boiler room mouth) to 0.1 (security room); culvert pipe 1.2 x 1.1 at -2.4 |

### Ways in and routes

Metrics used ([metrics.md](metrics.md)): mantle 1.0-1.9 m (kept at 1.1-1.44 m on every climb route; the one vertical-hole mantle, into duct B, is 1.7 m), walk-up steps 0.3 m or less, stairs 0.18 m risers, harmless drops up to 2.5 m (fall damage from 10 m/s = a 2.55 m fall at the player's 19.6 m/s²), no jump gaps on any route (the fence crossing is a hop over a top 0.5 m above the container, onto a container of the same height). Every move in this table is driven by the player in `tests/levels/mission/warehouse_climb_test.gd` and `warehouse_passage_test.gd`.

| Route | Moves (heights relative to where the player stands) |
|---|---|
| Front gate | Road -> 6 m gate lane, lit (gate flood, booth lamp), booth guard G1, gate camera |
| Over the fence | Road -> pallets (mantle 1.2) -> outside container (mantle 1.3) -> walk-and-jump the 3.0 m fence (its top is 0.5 m above the container; the jump carries over it onto the inside container, same height) -> inside pallets (drop 1.3) -> ground (drop 1.2). Dark corner behind the inside container (0.04) |
| Culvert | Road -> ditch ramp down (22 degrees, 2.4 m) -> culvert pipe (crawl 3.1 m, 1.1 m high) -> drain chamber (floor -2.4) -> step (mantle 1.2) -> east yard (mantle 1.2, under the east floodlight: risky) or doorway into the service tunnel |
| Back gate | Road -> east verge (past the water tower) -> riverside quay -> back gate (lockpick) -> back strip. Also the ditch's south end: step (mantle 1.2) -> headwall (mantle 1.2) -> verge |
| Loading dock | Yard -> roller door 1 (x -8) or 2 (x 4, behind the truck) 4 x 4 m openings: lit, the shipment inside |
| Side door | West yard -> keypad door (hall west wall, z -6), lit by its lamp; the dumpster with the code 3 m north |
| Annex roof | West yard -> pallets (mantle 1.2) -> container (mantle 1.3) -> crate on it (mantle 1.1) -> annex roof (mantle 1.15) -> roof door at z 2.1 (hall west wall, catwalk level: 0.25 m step down onto the west catwalk) |
| Main roof | Annex roof -> steel stair along the hall wall (27 x 0.176 m risers, caged) -> roof landing. Or the fire escape: east yard -> bottom landing (mantle 1.44; no stair to the ground, so guards cannot use it) -> flight up to the door landing (4.5) -> flight up to the roof (9.5) |
| Skylight drop | Roof -> walk off the open north edge of a rack skylight (railings on the other three sides) -> goods 1.4 m down -> rack top (drop 1.5) -> rack end -> bridge (drop 2.1). Harmless when walking or crouching; a sprint overshoots the goods onto the rack top (2.9 m: about 5 leg damage) |
| Duct A | Roof mouth (x 14, z 3.8; mouth floor 0.2 above the roof) -> crawl down 8.8 m at 25 degrees -> catwalk alcove off the north catwalk (x 13..15): the mouth sits on a 1.1 m pedestal (drop out 1.1; mantle in 1.1) |
| Duct B | Roof mouth (x 11, z -5.8) -> crawl down over the office block roof -> hole above the manager office -> filing cabinet (drop 1.7, then 1.35 to the floor). Back up: cabinet (mantle 1.35, ends crouched) -> stand under the hole -> mantle 1.7 into the duct (the vertical hole's edge is caught by the mantle's 1.615 m probe ray; face the near edge). The duct's far end opens onto the office block roof (7.35: a dark hiding place) |
| Duct C | Boiler room mouth (x 13.3, facing west, on a 1.1 m pedestal; mantle 1.1) -> right turn -> crawl up 6.4 m at 25 degrees -> security room north wall at floor level |
| Underground | Tunnel from the ditch (gate at the ditch: locked from outside) -> ramp -> boiler room -> (a) hatch stair (steep: 0.2 m risers, 39 degrees) up through a 1.2 x 4.5 m railed hole into the hall's north-east, or (b) store -> service stair (22 x 0.182 m) up into the office stairwell |
| Weak wall | Back strip -> breakable panel in the hall's south wall at x -10 (gas cylinders outside) |
| Inside the hall | Floor -> catwalks by the north-east stair (beside the east catwalk) or the south-west stair (beside the south catwalk), 25 x 0.18 m risers; bridge (z 5.25..6.75) from the west catwalk to the upper corridor's west doorway; south catwalk to the upper stairwell's west doorway; office stair (25 x 0.18 m, 0.25 m treads, 1.4 m landing at its foot) |

Loops: every way into the hall connects to every level: ground <-> catwalks (two stairs), catwalks <-> roof (annex door + annex stair, fire escape, duct A), roof -> catwalks (skylights, one way), roof <-> offices (fire escape door, duct B), basement <-> ground (hatch, service stair, duct C), basement <-> outside (tunnel, culvert chamber). Speed Enhancement adds shortcuts: rack decks 2.2 m apart can be mantled with it (2.5 m), and the 2.3 m-or-lower tops anywhere.

### Light (night)

Ambient only reads 0.04. Two circuits, both on breakers wave 2 places:

| Circuit | Breaker (placeholder) | Lamps |
|---|---|---|
| `warehouse_yard` (breaker A) | `Devices/BreakerA`, inside the annex (generator room), west yard | Floodlights (`objects/light_fixture/flood_lamp.tscn`): gate pole, dock west and east (on the hall's north wall), east yard pole (lights the drain chamber exit), back gate pole; side door wall lamp; booth lamp |
| `warehouse_building` (breaker B) | `Devices/BreakerB`, basement store (east wall) | Seven high-bay spots under the roof (dock, aisles, hatch, south-east), four catwalk wall lamps, a ceiling lamp in every office room (two in each corridor), annex, basement (4), tunnel |

The pontoon lamp (extraction) is on no circuit. Shadows are on for every lamp; measured frame cost about 0.8 ms per frame at 1152 x 648 (about 1200 fps with vsync off on this machine, from the yard, the catwalks, the perch and the corridor).

Measured light levels (standing; `warehouse_light_test.gd` asserts < 0.1 and >= 0.5): lit pools gate lane 0.78, dock apron 0.88, side door 0.76, dock inside 0.72, ground corridor 0.79, upper corridor 0.98, security room 0.70, break room 0.70, back gate 0.75, booth 0.92. Hiding spots 0.04 (under the trailer, crouched, 0.05): behind the inside container (-29, -20.6), west yard corner (-31, -4), behind the fire-escape container (30.5, 9), back strip (-28, 23), hall south-west corner (-18, 13), rack deck at 4.4 (-13, 9.5), the roof, the ditch, the culvert, behind the boiler, the tower deck, the annex roof. Cutting breaker A darkens every yard pool and leaves the building's lit; cutting B the reverse.

### Sightlines

- **Water tower perch** (deck 20 m, x 42..50, z -20..-12; eyes 21.65): clear lines over the fence to the gate, the west yard, the forklift, dock door 2's east side, the north-east yard and the fire escape; down through at least three skylights to guards on the catwalks or the floor (`warehouse_sightline_test.gd`). The east yard right under the tower is hidden by the deck's railing.
- **Inside the hall**: the north catwalk (36 m), the bridge (25 m), the aisles between racks (22 m) are clear lines for the rifle guard and for a sniper. The racks' open bays let partial sight through.
- **Fence**: the palisade blocks bodies but not sight, shots or light (bars only): guards and cameras see through it and the player can scout the yard from the road.
- **Blind spots for cameras**: the dumpster corner north of the side door, the gap between the truck and the hall wall, the containers' far sides.

### Doorways (doors are placed by wave 2)

All 1.2 x 2.2 m unless noted, each with at least 1.35 m of wall (or another room's wall) on both sides for a pocket door. Markers `LayoutMarkers/Doorways/<Name>` (yaw 0: wall along x; yaw 90: along z); `warehouse_layout_test.gd` checks each is open for a standing capsule.

| Name | Position (x, y, z) | Intended door / lock |
|---|---|---|
| FrontGate | (-5, 0, -25), 6 m | Vehicle gate, booth-controlled; pedestrians beside the booth |
| BoothDoor | (-9.4, 0, -22) | Plain, unlocked |
| BackGate | (7, 0, 25) | Mechanical (lockpick); opens from inside |
| SideDoor | (-20.25, 0, -6) | Keypad (code on a note in the dumpster) |
| RollerDoor1, RollerDoor2 | (-8, 0, -10.25), (4, 0, -10.25), 4 x 4 m | Roller doors (loud) |
| AnnexDoor | (-26.25, 0, 10.8) | Mechanical (generator room, breaker A) |
| AnnexRoofDoor | (-20.25, 4.75, 2.1) | Mechanical; opens from inside |
| WeakWall | (-10, 0, 15.25) | Breakable panel (explosives) |
| FireEscapeDoor | (20.1, 4.5, 6) | Mechanical |
| OfficeEntrance | (8.13, 0, 6) | Plain, unlocked |
| BreakRoomHall, BreakRoomCorridor | (11, 0, 0.13), (11, 0, 5.13) | Plain |
| SecurityDoor | (16.9, 0, 5.13) | Keycard (security) |
| StairsGround, LockerRoom | (10.65, 0, 6.88), (16.5, 0, 6.88) | Plain |
| BridgeDoor | (8.13, 4.5, 6) | Plain (catwalk bridge) |
| ManagerDoor | (11, 4.5, 5.13) | Keypad (the manifest) |
| VaultDoor | (16.9, 4.5, 5.13) | Electronic fail-secure (terminal) + keycard |
| StairsUpper, CatwalkStairsDoor | (10.65, 4.5, 6.88), (8.13, 4.5, 14.1) | Plain |
| OfficeTwo | (16.5, 4.5, 6.88) | Mechanical (office PCs) |
| BoilerStore, BoilerTunnel | (12, -4, -0.25), (19.75, -4, -5) | Plain |
| TunnelGate | (36.85, -2.4, -5) | Grille gate: mechanical from the ditch side, opens from inside |

### Rooms

| Room | Interior (x; z; floor, height) | Notes |
|---|---|---|
| Gate booth | -12.5..-9.5; -24..-20; 0, 2.6 | Windows north (road), south (yard), west at 1.0 m sill |
| Annex (generator room) | -26..-20.5; 1.5..12.5; 0, 4.25 | Shares the hall's west wall; breaker A |
| Hall | -20..20; -10..15; 0, 9 | Dock zone z -10..-3.5 (the shipment), racks, office block in the south-east corner |
| Break room / lockers | 8.25..13.75; 0.25..5 (ground) | Door to the hall and the corridor |
| Security room | 14..19.75; 0.25..5 (ground) | Window onto the hall's north-east; duct C exit in the north wall |
| Ground corridor | 8.25..19.75; 5.25..6.75 | Entrance from the hall at the west end |
| Stairwell | 8.25..13; 7..14.75 (both floors) | Service stair down (west), stair up (east) |
| Locker room | 13.25..19.75; 7..14.75 (ground) | Silencer locker |
| Manager office | 8.25..13.75; 0.25..5 (upper, carpet) | The manifest; cabinet under duct B's hole at (11, 2.8) |
| Vault | 14..19.75; 0.25..5 (upper) | Turret, prototype |
| Upper corridor | 8.25..19.75; 5.25..6.75 (carpet) | Bridge door west, fire escape door east |
| Second office | 13.25..19.75; 7..14.75 (upper, carpet) | Office PCs, wall jack |
| Boiler room | 8..19.5; -9..-0.5; -4, 3 | Boiler (x 16..19, z -8.6..-6.6), hatch stair, duct C mouth, tunnel door |
| Store | 8..19.5; 0..14.75; -4, 3 | Service stair foot; breaker B, network switch, lockpicks, G8's cot |

### Population spots (placeholders in `LayoutMarkers`)

Coordinates are feet (or the device's mount point). Yaw 0 faces north (-Z), 90 west, 180 south, -90 east.

| Group | Name | Position | Yaw | Notes |
|---|---|---|---|---|
| Guards | G1GatePost | (-9.6, 0, -23.2) | 90 | Booth door, lit; watches the gate lane |
| | G2YardPatrolWest | (-18, 0, -18) | 0 | Route YardWestA > B (-27, -9) > C (-27, 14) > D (-14, -13): west yard, side door, annex |
| | G3YardPatrolEast | (18, 0, -18) | 0 | Route YardEastA > B (33, -14) > C (24, 14) > D (12, 20): east yard, drain chamber, fire escape, back strip |
| | G4CatwalkRifle | (-10, 4.5, -9.25) | -90 | `guard_rifle.tscn`; route CatwalkA > B (-19.25, 6) > C (2, 6, bridge) > D (12, -9.25) |
| | G5SecurityOperator | (17.6, 0, 1.6) | 0 | Faces the security window |
| | G6BreakRoom | (11, 0, 2.6) | 180 | |
| | G7VaultDoor | (16, 4.5, 6) | 0 | Upper corridor, facing the vault door |
| | G8OffDuty | (17, -4, 11.5) | 90 | Basement store (asleep or idle) |
| Devices | CameraGate | (-9.5, 2.9, -23.9) | -135 | Booth roof corner, watches the gate lane |
| | CameraYard | (20.4, 6.0, -10.6) | 120 | Hall's north-east corner, looks west along the dock apron |
| | CameraHall | (-2, 6.5, -9.9) | 180 | North wall inside, looks south down the R2-R3 aisle |
| | CameraOffice | (19.6, 6.9, 5.4) | 90 | Upper corridor east end, looks along it |
| | Turret | (16.9, 4.5, 1.0) | 180 | Vault, facing its door |
| | SecurityTerminal | (16, 0, 0.3) | 0 | Security room north wall (SEC-SERVER, M11) |
| | AlarmController, RadioBaseStation | (19.7, 1.5, 3), (19.7, 1.2, 1.2) | -90 | Security room east wall |
| | SirenYard, SirenHall, SirenOffice | (0, 7, -10.55), (-19.99, 7, 3), (8.26, 2.5, 6) | | Hall north wall outside; hall west wall inside; ground corridor west end |
| | PanicButtonSecurity, PanicButtonBooth | (14.01, 1.3, 2), (-12.49, 1.3, -21) | 90 | |
| | BreakerA | (-25.99, 1.4, 4) | 90 | Annex (generator room) |
| | BreakerB | (19.49, -2.6, 3) | -90 | Basement store east wall (see ADR 0089: moved from the security room) |
| | NetworkSwitch | (19.49, -2.4, 6) | -90 | Basement store: breaking it cuts the alarm network (showcase) |
| | AccessPoint | (-20.6, 6, -2) | -90 | Hall west wall outside: covers the west yard, side door and dumpster (M11 Guest) |
| | OfficeWallJack, OfficePC1, OfficePC2 | (19.74, 4.9, 10), (14.5, 4.5, 13.5), (18, 4.5, 13.5) | | Second office (M11 Office subnet) |
| Items | ManifestDatapad | (9, 5.3, 1) | | Manager office desk; `Readable.entry_id` = `warehouse.manifest` |
| | Prototype | (19, 5.3, 3.5) | | Vault; item id `prototype` (new ItemData in wave 2) |
| | SideDoorCodeNote | (-21.8, 0.35, -9) | | Inside the dumpster |
| | Silencer | (19.4, 0, 12) | | Locker room |
| | SniperRifle | (42.5, 20, -13) | | Water tower deck |
| | Shotgun, KeycardInSecurity | (19.4, 0, 4.6), (19.4, 0.8, 2.4) | | Security room |
| | KeycardInVault | (14.5, 5.3, 4.5) | | Inside the vault (what it opens is wave 2's call) |
| | Lockpicks | (8.4, -3.1, 3) | | Basement store |
| | Biocell1, Biocell2, Ammo1, Medkit2 | (-25.5, 0, 12), (32, -2.4, -8.6), (-13, 4.4, 9), (18.5, -4, -0.9) | | Annex, drain chamber, rack deck, boiler room |
| Mission | Shipment | (0, 0, -6.5) | | Dock zone between the roller doors: every prop tagged `mission.shipment` |
| | GasCylinders | (-12.5, 0, 16.3) | | Outside the weak wall (keep 2 m from each other to chain, see objects-and-fire.md) |

Physics props to stack and throw, cover crates and the shipment are wave 2's (only fixed climbing aids are geometry here). Guard routes keep at least 1 m from the containers and racks; every post and patrol point is on the navmesh and reachable from `ReinforcementSpawn` (`warehouse_navigation_test.gd`).

### Equipment to find

| Item | Where |
|---|---|
| Silencer | Locker room (ground floor) |
| Sniper rifle | Water tower perch |
| Shotgun | Security room |
| Assault rifle | The rifle guard (weapon drop) |
| Lockpicks | Basement store |
| Two keycards | In the vault, in the security room |
| Biocells x2, ammo, a second medkit | Annex, drain chamber, rack deck, boiler room |

Every main route works without any of them; each find opens an option.

### Guards

About 8, mixed baton / pistol / rifle ([../game/perception-and-ai.md](../game/perception-and-ai.md)); posts and routes in "Population spots".

### Devices

Cameras (gate, yard, hall, office), the vault turret, a security terminal, an alarm controller with sirens and panic buttons, a radio base station, breakers A (yard) and B (building), and a network switch whose breaking cuts the alarm network ([../game/security.md](../game/security.md), [ADR 0075](../decisions/0075-alarms-as-network-devices.md)).

### Systems used for a purpose

Light and breakers, floor noise (metal catwalks, containers and ducts are loud, the manager office carpet quiet), physics props to stack and throw, fire and explosives, carrying and hiding bodies, every door and lock type, keypad codes from notes, cameras, turret, terminal, alarm network, radio base station, augmentations, the new weapons including long sniper sightlines and the silencer. Two showcase moments: cutting the alarm network by breaking a switch; the sniper perch.

## Targets

- Every main route is doable ghost, pacifist and loud, and covered by scenario tests.
- Ghost run 10-15 min, loud about 5 min.
- A careful first-time player gets spotted at least once but can recover.
- No route needs a precise jump or tight timing.
- Hiding spots read below 0.1 light; patrols leave crossing gaps of at least 4 s.
- Tests measure these (time to detect, run times); the numbers above are first guesses.

## Systems (M9 wave 1)

How the level uses the mission systems ([ADR 0087](../decisions/0087-mission-systems.md), [ADR 0088](../decisions/0088-weapon-drops-and-bursts.md)). Everything lives in `levels/mission/mission_kit/` (scenes, scripts, data) and `ui/mission/` (screens); the level only places nodes:

| Node in `warehouse.tscn` | What | Notes |
|---|---|---|
| `PlayerSpawn` | Marker3D | The player starts here facing the marker's -Z (the van on the north road). The level does **not** place a Player: the Mission spawns `actors/player/player.tscn` there (a placed player tagged `actor.player` would be used instead). |
| `ReinforcementSpawn` | Marker3D | Outside the front gate; the two reinforcements appear here, 1.5 m apart along the marker's X, facing its -Z. Keep 1 m of free navmesh on both sides. |
| `Extraction` | instance of `mission_kit/extraction_zone.tscn` | Invisible box standing on the node's origin; in the warehouse 5.6 x 3 x 4.6 m on the pontoon by the boat (7, 0, 35.6). Ends the mission once the main objective is done; before that it shows "Read the manifest first". |
| `Mission` | instance of `mission_kit/mission.tscn` | `data` = `mission_kit/warehouse_mission.tres`. One per level. |

- **Data** (`warehouse_mission.tres`, a `MissionData`): briefing text; objectives: main `manifest` (`ReadEntryObjective`, entry id `warehouse.manifest`), optional `prototype` (`PickUpObjective`, item id `prototype`), optional `shipment` (`SabotageObjective`, tag `mission.shipment`); kit: baton, pistol (10 in the magazine), 10 pistol ammo, 1 medkit; energy 50%; augmentations Cloak, Speed Enhancement, Combat Strength; reinforcements: two `guard_pistol.tscn`, 30 s after the first alarm.
- **What wave 2 must match**: the manifest datapad's `Readable.entry_id` is `warehouse.manifest`; the prototype is an item with id `prototype` (a new `ItemData` in the catalogue, placed as a pickup in the vault); every part of the shipment carries the tag `mission.shipment` (add it to the props' `Tags.initial_tags`; any one of them broken, exploded or burning completes the objective).
- **Guards**: `guard_baton.tscn`, `guard_pistol.tscn`, and `guard_rifle.tscn` for the catwalk guard (G4; bursts of 3-5 rounds). Every guard drops its weapon as a pickup beside the body when knocked out or killed, so the assault rifle is found on G4.
- **Alarms**: any alarm controller's first ring starts the reinforcement timer; the reinforcements search where that alarm was raised.
- **Flow**: hub west north doorway (`MissionExit`, a `LevelExit`) -> warehouse (briefing, paused) -> extraction -> summary -> "Restart mission" or "Return to hub". The summary shows time, alarms raised, kills, knockouts, optional objectives done and the Ghost and Pacifist badges.
- **Test fixture**: `tests/levels/mission/mission_kit/fixtures/mission_fixture.tscn` is a small mission level with the same contract (see `mission_helpers.gd`); screens can be reviewed with `fixtures/mission_shots.tscn` (`-- shot=briefing|toast|summary|weapon_drop out=<png>`).

## Network (M11)

A sketch, not a layout ([../game/hacking.md](../game/hacking.md)). M9 places the hooks as M8 devices: a wireless access point spot covering the yard, an office wall jack, two office computers (credentials-placeholder terminals), the security console. Three subnets behind one gateway, FW-01, which runs the "Sentry" tracer watching Guest and Office:

```text
  [AP Guest] ~~ range reaches the yard (side door, dumpster)
      |
  Guest 10.0.1.0/24 ---+
                       |
  Office 10.0.2.0/24 --+-- FW-01 (Sentry tracer: Guest, Office) -- rules: Guest -> Office deny,
    office PC x2       |                                             Office -> Security deny,
    (mail with clues)  |                                             SEC-SERVER -> any allow
                       |
  Security 10.0.3.0/24 +   (unwatched by Sentry)
    SEC-SERVER (security room console; cameras, doors, turret trust it)
    3 cameras, security room door, vault turret, alarm controller, sirens, radio base station
```

- Entry: wireless from the yard (Guest), the office wall jack (Office), the office PCs bare-handed, the security console.
- Example routes: sniff a guard's login on the Guest wireless, use it on an office PC, read the mail with the security console's password hint; or break the Security switch to kill the cameras and sirens (the security room door is fail-secure, so it then needs another way in); or crack FW-01's admin account (Medium) and add a rule "you -> Security allow".
- Numbers (passwords, tracer tuning, software versions) are set in M11.

## Rules

- Success: extraction after reading the manifest (its entry is in the personal log, `PersonalLog.has(entry_id)`). Fail: death, then reload or restart.
- Route relevance: movement ([../game/movement.md](../game/movement.md)), physics and explosives ([../game/objects-and-fire.md](../game/objects-and-fire.md)), abilities ([../game/abilities.md](../game/abilities.md)).
- Scenario tests cover the routes ([../tech/testing.md](../tech/testing.md)).
- No difficulty settings.

## Milestone plan

1. Wave 1, in parallel: systems (level change, briefing and objectives, summary and badges, weapon drops, reinforcements) and the layout blockout.
2. Wave 2: population, exterior and interior in parallel (guards, devices, props, equipment).
3. Wave 3: route scenario tests and polish.

## Open questions

- Patrol timings and device placement: wave 2 settles them from the spots above (patrol crossing gaps of at least 4 s are still untested).
- The roller doors and the 6 m front gate need door objects wider than `door.tscn` (1.2 x 2.2 m): a new door size, or bars/barriers that open (wave 2).
- Whether the vertical-hole mantle at duct B (1.7 m, caught by the 1.615 m probe ray) feels reliable enough in play, or the cabinet should become two steps.
- Skylights are open holes: glass panes (breakable, noisy) would make the drop a choice with a cost.
- Network layout and which guards use devices on patrol: M11.
