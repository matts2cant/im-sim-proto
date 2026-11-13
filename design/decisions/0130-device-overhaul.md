# 130. Device overhaul: one design language, rack and desk versions, door controllers, frame status (M13c)

Status: Accepted (built in three steps; step 0, the 3D models in a hub showroom, waits for the user's approval of the look before the rest)

Date: 2026-11-13

## Context

After the M13 playtest the user found network gear hard to tell apart (routers, switches and the mail server were similar dark boxes on walls), some devices showing two lights, and the interaction frame useful enough to carry more information. The user and the chief engineer settled the overhaul in a design review (grilling, two rounds) and three mockups: [network_gear_looks.html](../prototypes/network_gear_looks.html) (the first look, the linking bay, the frame's status line) and [device_language.html](../prototypes/device_language.html) (every device in every version, the bays, the deck's Map and the keychain), approved with "no ports on small devices".

## Decision

**One design language for every device** ([device_language.html](../prototypes/device_language.html)):
- a strip in the device kind's colour (on a rack unit, its left ear; on a standalone device, along its top): switch blue, router orange, access point cyan, wall jack slate, computer green, alarm system red (controller, siren, radio base station, panic button), door controller violet, security yellow (camera, turret, laser);
- the kind's Map icon (`DeviceKinds`) on its front in that colour; the rack server uses the computer icon (the server icon is retired);
- one status light, none on wall jacks, panic buttons and lasers (their status shows in the frame);
- visible network ports on network gear (switches, routers, access points), computers, alarm controllers and wall jacks, each with a port light (lit while cabled and both ends up) and a label naming the connected device, running vertically under its socket (the wall jack's label sits flat under its socket); small single-purpose devices (camera, turret, siren, radio base station, panic button, laser, door controller) show no port;
- a name plate.
The deck's Map draws the same colour strip and icon on every node, with the status square in the light's colours.

**Devices come in versions with the same behaviour**:
- routers and switches: a rack unit (switch 1U, 24 sockets; router 2U, uplink + 8) or a small desk box (switch 5 sockets; router uplink + 4); wall-mounted routers and switches are retired; versions differ only in looks, and the sockets on the model are the most cables it takes (a level test checks it); desk gear is fixed in place;
- computers: desktop (today), rack server (2U; E opens its OS screen like a desktop) and later a laptop;
- alarm controllers: the wall panel (today) or a 2U rack unit.

**Linking bays**: a floor-standing rack (60 x 190 cm) holding the network gear of an area, cables bundled to the ceiling, a name plate on top. Furniture, not a device: each unit inside is powered and cabled on its own. Some bays are open; others have a glass door locked with a mechanical lock (key or lockpick). A closed door blocks reaching the units (their lights show through the glass; the frame on the door reads "Locked · key or lockpick").

**Servers are computers**: there is no mail server. The mail host logic and the M12c mail routes are removed; mail returns once the network is settled.

**Door controllers**: a door is not a network device; its controller on the wall beside it is (its keypad, card reader, status box or control box; the boxes on both faces are one controller device: one cable, one name, one status, one light, the lock light). A door is on a network only through a controller; doors without one are mechanical. A broken or unpowered controller follows the door's power rule (fail-secure stays locked, fail-safe unlocks).

**Keys and the keychain**: a key item opens the mechanical locks that name it (doors and bays); a lock opens with its key or by picking it. Keys go to a keychain in the Inventory tab (a list of the keys collected, where each was found), never into the grid: no space, cannot be dropped or thrown.

**The interaction frame** ([ADR 0129](0129-interaction-frame.md)):
- every device and every character gets the frame, within reach (2 m) only;
- its tag gets a status line: network devices Online / Cut off (blinking) / Disabled or Broken / No power in the status light's colours; powered things off any network Powered / No power; characters Unconscious / Dead (awake: the name only); locks what opens them ("Locked · keycard", "Locked · key or lockpick");
- the "E: ..." prompts are removed; when E fails, a short message says why ("Locked: needs a keycard", "Too heavy", "No room to put down").

**Levels**: the network lab gets a showroom (an open bay, a locked bay, desk gear); the security wing one bay (its switch, router and the rack alarm controller); the warehouse a locked bay in the office and a small switch on the office desk. Every wall-mounted router, switch and mail server moves into a bay, or onto a desk for small ones.

**Steps**: 0) the 3D models in the new language, shown in a showroom in the hub, for the user's approval; 1) door controllers, the frame changes, the removed lights, removing mail hosting; 2) in parallel, the device scenes from the approved models (bays with locks, rack and desk versions, rack servers, rack alarm controller, port lights and labels, the key item and keychain, the Map's strips and icons); 3) the levels.

## Alternatives considered

- **Gear on walls with only a colour band**: the first mockup; the user asked for bays and versions to tidy rooms.
- **A frame visible up to 8 m with dimmed brackets beyond reach**: the user wants the frame at interaction distance only.
- **A mail host app on servers**: deferred; removed until the network is settled.
- **A door as the network device (M12 to M13)**: the controller is what a cable reaches in real buildings and gives the light a sensible place.
- **Bays locked by keycards**: mechanical locks pair with the new key and the lockpicking minigame.
- **Port labels as numbers with a legend card**: the user chose vertical labels; their legibility is checked in the showroom.

## Consequences

- Device scenes are rebuilt from shared model parts (kind strip, icon, port row with labels, name plate); `DeviceKinds` gains a colour per kind.
- Door hacking, the Map's door entries and the door exploit item move to door controllers; levels add controllers to every networked door.
- The M12c mail route mechanic, its tests and the mail-route consequences in the warehouse are removed.
- ADR 0122 (lights) and 0129 (frame) get amendments in step 1.

## As built (step 0: models)

- **Folders**: shared parts in `objects/devices/models/parts/` (scripts, `materials/`, `model_font.tres`); the models in `objects/devices/models/`: `switch_rack`, `switch_desk`, `router_rack`, `router_desk`, `computer_desktop`, `computer_rack` (rack server), `computer_laptop`, `alarm_panel`, `alarm_rack`, `access_point`, `wall_jack`, `door_controller_keypad` / `_card_reader` / `_status_box` / `_control_box`, `camera`, `turret`, `siren`, `radio_base_station`, `panic_button`, `laser_emitter`, `laser_receiver` and `linking_bay` (one scene; `glass_door` makes the locked variant). Look only: no components, collision only on the bay. The temporary showroom is `levels/hub/device_showroom.tscn`, instanced in the hub as `DeviceShowroom` ([hub-and-gallery.md](../levels/hub-and-gallery.md#hub)).
- **Kind colours**: `SecurityKind.color` in `device_kinds.tres` (the kinds, their icons and now their colours in one place). The door controller models use the door kind (violet) until step 1 moves doors to their controllers; the server kind is green like the computer kind and the rack server uses the computer kind and icon.
- **How a model is composed**: the root is a `DeviceModel` naming its kind by tag (and its rack units); plain box, prism and cylinder meshes in the shared `materials/` make the body; the shared parts are nodes placed on its front (+Z) and build their own meshes when they enter the tree, reading the kind from the `DeviceModel` above them: `KindStrip` (a box in the kind's colour: a rack unit's left ear, a top band elsewhere), `KindIcon` (the kind's Map icon strokes turned into a thin line mesh by `IconMesh`), `StatusLed` (one LED in the shared status light material, green; red on door controllers), `PortRow` (sockets from a list of names, a port light above each, green when named, labels vertical under the socket or flat on the wall jack, an optional uplink ring in the kind's colour) and `NamePlate`; printed text is `ModelText` (a Label3D with the models' signed-distance-field mono font, lit by the room; displays glow). Parts are tool scripts, so models show in the editor; nothing they build is saved in the scenes. Step 2 composes these models into the device scenes and drives the LED and port lights from the device.
- **Linking bay**: 0.6 x 1.9 x 0.6 m, 38 slots of 1U (0.0445 m) between a 0.1 m plinth and a 0.1 m top cap; rack units are its children and snap to the nearest slot on the rails on load (`snap_units()`, `slot_y()`, `slot_for()`); every free slot gets a 1U blank panel; cables rise `cable_height` from its top; a box body on the world layer. The glass door is closed and visual only.
- **Port labels**: enlarged within the mockup's layout to the most that fits a unit's front (a 24-port 1U switch: 5.2 mm em, sockets 7.5 mm high; the 2U router 6.5 mm). Readable at the player's 80 degree field of view: the switch's labels from about 0.4 m at 1080 p (about 0.25 to 0.3 m at 648 p), the router's and the single-port devices' from about 0.5 m at 1080 p (0.3 m at 648 p). Name plates read from about 1 m. Readability up close is a playtest question (checklist "M13c showroom").
- **Second pass (user review of the showroom)**: the access point is a round white ceiling-style disc (20 cm, 3.5 cm tall: a flat rim and a gentle dome), a flat centre disc with the kind icon, a glowing status ring round it (`StatusLed` shape `RING`) and a thin cyan band round the rim (`KindStrip` shape `BAND`); no plate, antennas or visible port (its cable enters from the back). The camera and the turret are the existing `security_camera.tscn` and `turret.tscn` looks (same meshes, proportions and materials; the camera's lamp is a `StatusLed` of shape `LAMP`, the turret's light sits where its `StatusLedMarker` is) with only a yellow band round the top of the head; the turret stands on the floor. The laser post is gone: `laser_emitter` and `laser_receiver` are today's laser head and receiver box with a yellow top band, no light, port or plate. The siren's horn is replaced by a beacon (a dark base ring, a translucent red-orange cover over a dark core) on top of its box, unlit for now. Door controllers lost their name plates; the desktop and laptop lost their icons; the laptop's lid is as wide as its base.
- **Tests**: `tests/objects/devices/models/` (every model's size, strip colour, icon, light, ports and no coplanar faces; the port row; the icon mesh; the bay's slots, blanks and door) and `tests/levels/hub/device_showroom_test.gd`; `KitGeometry.coplanar_mesh_overlaps()` is the mesh version of the CSG check. Review shots: `tests/objects/devices/models/fixtures/showroom_shots.tscn`.
