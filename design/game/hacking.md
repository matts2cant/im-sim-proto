# Hacking

Milestones: M12a (network, computers, the deck's Map and Icebreaker, tracers) and M12b (exploits, Firewall, Logs, wireless) ([ADR 0112](../decisions/0112-hacking-reconciled-with-the-built-game.md)); guards logging in, the security operator and the Sniffer move to M16. M8 builds the security devices, the alarm devices and a remote command interface wired by physical links: see [security.md](security.md) and [ADR 0075](../decisions/0075-alarms-as-network-devices.md). Design decision: [ADR 0074](../decisions/0074-network-hacking.md). Skill: [ADR 0076](../decisions/0076-computer-skill-multitool-removed.md).

Approved mockup: [hacking_screens.html](../prototypes/hacking_screens.html) (supersedes the old wireframes).

## Purpose

Hacking as a believable network, not a minigame. The level has real devices with addresses, subnets, firewalls and accounts. The player wins by finding clues, choosing an entry point and understanding what each machine can reach. Several approaches solve the same problem: crack a password, find it on a sticky note, cut the power to a switch, or shoot the siren.

## Player-facing behaviour

- **Real time**: the world keeps running while you hack. Hacking is silent (no `noise` stimulus), but guards can see you standing at a computer or holding the deck.
- **Screens are overlays** like the Tab interface: an 85 % panel over the dimmed, running world; the player stands still; Esc or the ✕ leaves.
- **The deck** is an inventory item (one model, no upgrades). Exploring the network and hacking happen only on the deck: computers have no network map.
- **Computers** run a simple desktop (placeholder name "Halcyon OS") with three apps: Mail, Files, Security. You can use any computer bare-handed, but only its own desktop. A computer you have an account on can also be used **remotely** from the deck.

### Entry points

| Entry point | Needs | Your address | Leaving it | Milestone |
|---|---|---|---|---|
| Any computer, bare-handed | its credentials (or an unlocked session) | none: you use its desktop only | Running actions continue; you cannot start new ones | M12a |
| Wall network jack | the deck | the deck's address on the jack's subnet | Tethered: walking away unplugs the deck and stops its tools | M12a |
| Autonomous device's maintenance port | the deck | a direct link to that device only | Tethered, like a jack | M12a |
| Plugging the deck into a computer | the deck | the computer's address | Tethered, like a jack | M12a |
| Wireless, within an access point's range | the deck, and the access point's Wi-Fi key (aim the deck at the access point and crack the key with the Icebreaker; deck range by Computer skill: 8 / 12 / 18 / 25 m) | the deck's address on the access point's subnet (its client address) | You can lower the deck; tools keep running while you stay in range. Leaving the range drops the Wi-Fi and stops them | M12b (built: [Wireless as built](#wireless-as-built-m12b)) |

- "You" in a firewall rule is the address the deck currently uses (its own, or the computer's when plugged into one).
- Lowering the deck (Esc) while plugged in keeps its tools running.

### Deck tools

| Tool | What it does | Milestone |
|---|---|---|
| Map | Shows the devices you can see (see [Discovery](#discovery)), drawn like the old terminal's Network tab (grouped by hub, pan and zoom: [ADR 0099](../decisions/0099-network-map-layout-pan-zoom.md)). Clicking a device opens its menu: its address, status and account names; per account "Log in" (a login the Journal knows) or the Icebreaker; on a device you have access to, its actions; on a computer you have an account on, "Open its desktop (remote)" | M12a |
| Icebreaker | Brute-forces an account's password. Deterministic, no randomness. Adds trace while it runs | M12a |
| Exploit items | One-use inventory items by device kind, used from a device's menu on the Map: admin at once, no trace. No tool of their own | M12b (rebuilt: [Exploit items as built](#exploit-items-as-built-adr-0121)) |
| Firewall | As admin of a router: view and edit its rules | M12b (built) |
| Logs | As admin of a device: read its log and erase entries | M16 (M12b records the logs) |
| Sniffer | Wireless only. Captures the logins guards make on devices connected through the same access point | M16 (needs guards logging in) |

## Network model

- **Devices** have IP addresses and are grouped into **subnets** (never "segments"). A subnet is a logical address range; **switches are the physical wiring**: a subnet can span several switches, cabled up to one another, and how many depends on the building (a switch per room or area, one large switch per floor in a wiring closet, or one for a small office). A device can also plug straight into a router port. Losing one switch cuts only the devices behind it. No VLANs.
- **Physical links**: cable or wireless. Any device except network devices (switches, routers, access points) can link wirelessly to an access point within the access point's range (M12b); wireless links show as dashed light-blue lines on the Map; breaking or unpowering an access point takes its wireless devices offline. **Jamming** (a jamming grenade, M14) drops every wireless link in its radius for a while. A device can also be **autonomous** (no link at all); it has a maintenance port ([ADR 0112 amendment](../decisions/0112-hacking-reconciled-with-the-built-game.md#amendment-switches-routers-and-access-points-2026-11-11)).
- **Routers** (firewalls) are nodes between subnets. Rules are an ordered list of from / to / allow or deny; the first match wins. From and To are a subnet, a device or "you". No ports.
- **Power and damage**: switches, access points and routers have `Powered` and `Breakable` like any prop ([ADR 0066](../decisions/0066-power-circuits-shootable-lights.md)). Unpowering or breaking one cuts everything behind it. A device that loses its link falls back to standalone behaviour (see [Devices](#devices-and-their-remote-actions)).
- **Doors on power loss**: a door's tag says fail-safe (unlocks on power loss) or fail-secure (stays locked). Breaking a switch can disable security, but it can also stop you opening a door remotely.
- **Access is per machine**: local accounts with user or admin rights. No domain accounts.
- **Reach**: what a machine can do depends on its subnet, the firewall rules for its address, and which devices trust it. Example: cameras trust the security console, so the console's Security app controls them; an office PC cannot reach them.
- A device accepts a command from a session logged in on the device itself, or from a machine on its trust list that can reach it.

```mermaid
flowchart LR
    AP["Access point (Guest)"] --- SWG["Switch: Guest"]
    SWG --- FW["Router RTR-01 (tracer: Sentry)"]
    SWO["Switch: Office"] --- FW
    SWS["Switch: Security"] --- FW
    SWO --- PC["Office PC"]
    SWS --- SC["Security console"]
    SWS --- CAM["Camera"]
    SWS --- AC["Alarm controller"]
    AC -.-> SIR["Siren"]
    CAM -.trusts.-> SC
```

### Discovery

- From an entry point the Map shows every device on your own subnet, plus its router. **What lies behind a router is hidden**: no node, no count.
- **Hacking a router** (gaining an account on it, by a known login or the Icebreaker) reveals the subnets behind it and their devices. A router inside those subnets can be hacked in turn: you hack your way through several subnets in a row.
- **The Map shows the network you are plugged into, only.** It draws the seen devices physically connected to your entry point (the wall jack, the access point you joined, the device whose port you use): joined by cables or holding wireless links, either way, whether they are up, powered or broken, and whatever the routers' rules ([ADR 0113 amendment](../decisions/0113-network-layer-tracers-and-the-deck.md#amendment-the-map-draws-the-plugged-network-only-2026-11-11)). The rules above still apply on top: a subnet shows once scanned, and what lies behind an unhacked router stays hidden. The deck remembers every device it has seen elsewhere: plug back into that other network and its map shows again at once, without a new scan. Unplugged (the Map reached from the Wi-Fi key screen), the Map draws nothing and says "Plug the deck into a device to see its network."
- Devices once seen stay on the map, greyed out, when you lose access. Node colours follow the network map's rule ([ADR 0099 amendment](../decisions/0099-network-map-layout-pan-zoom.md#amendment-node-colours-m9h)): grey out of reach, red disabled, else green; devices you have access to are drawn amber.

## Credentials and clues

- **Explicit clues** (a sticky note, a datapad, an email with a password): the credential is learned automatically and listed in the Journal's **Codes and logins** ([ADR 0110](../decisions/0110-tab-interface.md)). Login screens offer the logins known for that machine with "Fill in"; the deck's Map offers "Log in" with them.
- **Implicit clues** (an email "my cat's name plus the year we moved in" and a photo "Mishka, 2029"): nothing is learned. They go to the Journal's Notes; the player types the guess. A wrong guess adds trace.
- Clues never lower a password's strength.
- Logging in with correct credentials adds no trace. Failed logins, scans of subnets behind a router and the Icebreaker add trace; an exploit item adds none.
- The Journal is the one list of what you know: codes and logins, and notes (exploits are inventory items since ADR 0121).

## Icebreaker

Brute force, deterministic. The letters lock in one by one.

| Password strength | Base time |
|---|---|
| Weak | 10 s |
| Medium | 24 s |
| Strong | 50 s |

| Computer skill | Crack time | Trace gain | Strongest password it cracks |
|---|---|---|---|
| Untrained | ×1 | ×1 | Weak |
| Trained | ×0.75 | ×0.8 | Medium |
| Advanced | ×0.5 | ×0.6 | Strong |
| Master | ×0.3 | ×0.4 | Strong |

Resulting crack times (the longest is 25 s: no crack should make the player wait much longer):

| Computer skill | Weak | Medium | Strong |
|---|---|---|---|
| Untrained | 10 s | can't | can't |
| Trained | 7.5 s | 18 s | can't |
| Advanced | 5 s | 12 s | 25 s |
| Master | 3 s | 7 s | 15 s |

- **Skill assists** (shown on the deck, tier by tier like lockpicking, [ADR 0112](../decisions/0112-hacking-reconciled-with-the-built-game.md)): Trained: time estimates (crack time per account, time left); Advanced: + the trace an action will add ("about +30 %"); Master: + how many hidden subnets a router routes to.
- Stopping keeps the progress on the deck (saved with the game). Running it on the same account later resumes. If the password has changed since, the progress is lost.
- The skill affects only the deck's tools. Admin access allows every admin action: no action is skill-gated.

## Exploits

- Exploits are one-use inventory items of one kind: camera, turret, door, alarm (alarm controllers, sirens, panic buttons, radio base stations, laser arrays), computer, router ([ADR 0121](../decisions/0121-exploits-as-items-and-map-fixes.md)). Found in levels; later loot on guards and in shops (M19).
- Used from a reached device's menu on the Map: admin access at once, like an admin account, no trace; the device logs it. Scarcity is their cost.
- Details: [Exploit items as built](#exploit-items-as-built-adr-0121).

## Tracers

- A tracer is not a property of a subnet. It is an app running on a computer, server or router. Example: "Sentry tracer" on firewall RTR-01 watches the Guest and Office subnets. A subnet with no tracer is unwatched.
- Tuning is a `.tres` on the tracer: trace gain rate, the amount a failed login or a scan adds, drain rate while you are idle, lockout duration. Starting values in [Tuning](#tuning).
- Activity against a device adds trace to every running tracer that watches the device's subnet. The Computer skill scales the gain.
- Trace drains while nothing adds to it.
- **Full trace**: the tracer behaves like a camera. It sends an incident to the alarm controller (location: your entry point, not your position) and blocks your address for the lockout duration. While blocked, the watched devices refuse your address and tools running against them stop (Icebreaker progress stays on the deck).
- **Disabling a tracer**: if its host is disabled, unpowered or cut off, its subnets are unwatched. If only its link to the alarm controller is cut, it still detects and blocks you, but nothing rings. An admin of its host can stop the app; the security console then shows "Tracer offline" to an operator.
- No subnet tiers: difficulty comes from what the level designer places (tracers, exploit items, firewall rules).

## Alarms

The alarm is made of devices ([ADR 0075](../decisions/0075-alarms-as-network-devices.md), built in M8, details in [security.md](security.md)):

- An **alarm controller** receives incidents from sensors (cameras, tracers, panic buttons) and sends "ring" to every siren it can reach.
- A **siren** emits a loud siren stimulus; guards who hear it go into Searching.
- A **radio base station**, if the controller reaches it, broadcasts the incident location to guards with radio equipment (`equipment.radio`, [ADR 0072](../decisions/0072-shouts-radio-level-alarm.md)).
- If every siren is broken, disabled or disconnected, nothing rings.

## Devices and their remote actions

| Device | Remote actions | Standalone (link lost) |
|---|---|---|
| Door | open, close, lock, unlock, grant access (adds the deck's owner to its access list: it then opens for them like for a keyholder and stays locked for others) | Works locally (key, keycard, keypad); power loss follows its fail-safe or fail-secure tag |
| Camera | view feed, stop sweep, pan, disable (M8 commands: `command.stop_sweep`, `resume_sweep`, `pan_left`, `pan_right`, `disable`, `enable`; [ADR 0079](../decisions/0079-security-cameras-and-turret.md)) | Keeps watching; its incidents reach no controller |
| Turret | disable, edit target tags (its hostile tags, [ADR 0069](../decisions/0069-hostile-and-ally-tags.md); M8: preset commands `command.target_intruders`, `target_guards`, `target_everyone`) | Keeps its target tags |
| Siren | silence, test | Cannot be rung |
| Alarm controller | disarm, reset, trigger | Rings the sirens it still reaches |
| Computer | mail, files | Its own desktop only |
| Keypad | read its code, open its door | Accepts its code |
| Laser array | disable, enable | Keeps tripping; its incidents reach no controller |
| Panic button | disable, enable (M12a) | Pressing it reaches no controller |
| Radio base station | disable, enable (M12a); the alarm controller sends it `broadcast` | Guards get no radio broadcast |

- There is no camera feed loop (removed from the design).
- **Quiet vs loud**: panning a camera away is quiet. Disabling it makes its feed go dark; from M16 a security operator (a guard at the monitors) radios someone to check it.

### Desktop apps

| App | What it shows |
|---|---|
| Mail | The account's emails |
| Files | The machine's files |
| Security | Only on computers that have it installed (security consoles, the booth computer). Replaces the old terminal's Camera tab. A list grouped by kind (cameras and turrets; doors; alarm: controller, sirens, radio base stations, panic buttons; laser arrays), an icon per device kind and its status; the selected device's detail pane with its status, actions and, for cameras and turrets, the live view. It lists **only the devices this computer controls** (they trust it and it reaches them); a computer that controls none says so and points to the deck |

- **Apps are installed per computer** (data: its `ComputerData.apps`, in dock order); the dock shows only those. A computer whose data lists none has Mail and Files. Office PCs have no Security app.
- Reading a mail or file adds it to the Journal automatically, like a datapad ([ADR 0060](../decisions/0060-datapads-read-in-place-personal-log.md)). Credentials and codes inside are learned; implicit clues are kept as notes.
- **Remote desktop**: from the deck's Map, a computer you have an account on opens its desktop inside the deck ("Back to the map" returns). Its Security app controls the devices that trust that computer, from wherever the deck is plugged in.
- "Copy to deck" (in the game UI) exists only for objectives that need the file itself. Deleting a file can also be an objective.

#### Computers as built (M12a, [ADR 0114](../decisions/0114-computers-halcyon-os.md))

- **Components**: a computer is a device entity with `Computer`, `DeviceAccounts` and `ComputerUse` (E). `objects/computer/computer.tscn` is the wall unit; per instance its accounts, its `ComputerData` `.tres` (installed apps, mail and files), its `credentials_id`, host name and label; `session_user` starts it unlocked.
- **Mail** belongs to an account (a mail with no account is in every inbox); **files** belong to the machine. Each document is a `ComputerDocument`: title (subject or file name), sender, text, codes and code labels like a datapad, and an `implicit_clue` flag (nothing learned, kept as a note). The first item is read when the app opens; clicking another reads it. The reader's last line says what it taught ("Learned: Office PC 2 login kbrandt / ferry19 · added to the Journal.") or that a clue teaches nothing.
- **Login**: Fill in lists every login the Journal knows under the computer's code id, one per user (the latest learned); the Journal's Codes and logins lists them the same way. A wrong guess shows "Wrong user or password." and a quiet beep (a sound, never a noise stimulus); the trace it adds is the tracers' (`DeviceAccounts.try_login()`).
- **Title bar**: host name, the address a component offers through `device_address()`, the account and "user" or "admin", the trace bar slot (`ComputerScreen.add_trace_bar()`, filled on `opened`), ✕.
- **Security app**: kinds, groups and icons are data (`ComputerConfig.kinds`, by entity tag); the list is `Computer.devices()`, filtered by `Computer.controls()` (trust, at the network integration). Offline devices stay listed, grey, without actions. Panic buttons and radio base stations are listed but have no disable / enable yet (their components do not accept those commands).
- **Remote**: the desktop draws above the deck in its content area (`ComputerScreen.remote_area`); Esc or Back to the map closes it (the deck stays open) and emits `Computer.desktop_closed`.

### NPCs and logs

- Devices keep logs: logins (successful and failed), exploit items used, remote actions, with the source address (recorded since M12b). An admin can erase entries with the deck's Logs tool (M16). An exploit item used leaves an entry. In v0 only the player reads logs (operators reading them: [backlog](../backlog.md)).
- **M16** (AI overhaul): guards log in to devices through a "use device" action at patrol waypoints (feeding the Sniffer and the logs), and a security operator watches the monitors.

## UI

Overlays, like the Tab interface ([mockup](../prototypes/hacking_screens.html)):

| Screen | Contents |
|---|---|
| Computer (Halcyon OS) | Title bar (host, address, account and access level, trace bars, ✕). Login: user and password, "Fill in" for the logins known for this machine, an error line ("+15 % trace" on a wrong guess). Desktop: the apps installed on it (Mail, Files, and Security on security consoles) in a dock |
| Deck | Title bar (entry point and address, trace bars, ✕). Tools on the left (Map, Icebreaker, Firewall; Logs greyed until M16); the Map's device menus; the Icebreaker with the letters locking in and Start / Stop; remote desktops inside the deck |

- One trace bar per tracer watching you (an undiscovered tracer shows as "unknown tracer"), only inside these screens.
- Skill assists appear on the deck (see [Icebreaker](#icebreaker)).

Controls ([controls.md](controls.md)):

- E on a computer uses it bare-handed. With the deck in hand (belt), LMB on a wall jack, maintenance port or computer plugs it in; LMB aimed at an access point within the deck's Wi-Fi range raises it on the Wi-Fi key screen (M12b, [ADR 0117](../decisions/0117-wireless-access-points-and-the-decks-wifi.md); [ADR 0059](../decisions/0059-belt-selects-lmb-uses.md): the belt selects, LMB uses).
- Esc (or the ✕) always steps away from the screen or lowers the deck, also while typing. It never also opens the game menu.
- E does not step away: only Esc leaves a computer-like screen ([ADR 0083](../decisions/0083-security-terminal-redesign.md)).
- The mouse drives the cursor on the screen.

## Rules

- **Systemic**: every behaviour comes from components and data on devices (address, subnet, links, accounts, trust list, kind by tags (DeviceKinds), `Powered`, `Breakable`, tags). A new device that combines existing behaviours is a scene and `.tres`, no new code. Remote commands are stimuli delivered to the device; its receptrons decide what they do ([ADR 0075](../decisions/0075-alarms-as-network-devices.md)).
- **Skill**: the deck reads its user's Computer skill attributes, so any actor with the skill gets the same tool timings ([abilities.md](abilities.md)).
- **Deterministic**: no randomness anywhere in hacking.
- **Saving** ([saving.md](saving.md)): network state (device power and links, firewall rules, exploit grants, logs, discovered devices, who knows each Wi-Fi key), known credentials (PersonalLog), exploit items (inventory), the deck's contents (copied files, crack progress, Wi-Fi crack progress), tracer trace and lockouts. Wireless links come from level data.

## M12a implementation details

Settled while building the network layer and the deck ([ADR 0113](../decisions/0113-network-layer-tracers-and-the-deck.md)):

- **Discovery is reach.** A router passes a user's traffic only once the user has an account on it (rules from "you" first, and an exploit item's grant counts too: ADR 0121). So the Map shows what the deck's traffic reaches (plus dead devices right behind a reached one), and hacking a router (a known login, the Icebreaker or a router exploit item) is what reveals the subnets behind it; a router inside them is hacked in turn. Routers show at once, and so does the subnet the deck is plugged into or joined over Wi-Fi (ADR 0121: no scan, no trace); the other devices show once their subnet is scanned (2 s, +10 % on the tracers watching it, once per subnet per deck). The scan shows on the Map where the subnet will appear: a blinking dashed box with "Scanning <NAME> <range>…", a progress bar and the seconds left, and a marching dashed link from the router; the world keeps running.
- **Addresses**: a wall jack gives the deck the jack's address on its subnet; a maintenance port `port:<device address>` (that device only); a computer its own address. A tracer blocks the address it caught: plugging in elsewhere is a new address.
- **Tethered**: more than 3 m (horizontal, the player's origin to the plugged entity) unplugs the deck; so do being unable to act and losing the deck. The screen lowers with Esc or ✕; LMB on the port raises it again.
- **Accounts**: logging in gives the account until its password changes. The Journal files a device's logins under one code id per device (its `credentials_id`: on `DeviceAccounts`, else its `Computer`, else its node name in snake_case), one entry per login "user:password"; a cracked login is learned that way, in an entry "Cracked: user@HOST".
- **Commands with an account**: the deck sends a device's commands (its menu) as a session on the device itself, from wherever it is plugged in; trust lists do not apply to it. No trace (logging in with the right password adds none either).
- **Tracers**: trace is per user; a full trace reports once, then drains as usual; it cannot fill again while the address is locked out. A tracer whose host is cut from the watched device (a dead switch between them) does not watch it. Trace bars (deck and computer screens) show every tracer that has trace for you, blocks your address, or watches a device on your map.
- **Icebreaker**: one account at a time; picking another stops the current one (progress kept). A password changed while it runs makes it start over on the new one.
- **Assists** (deck only): Trained: each crackable account's crack time in its menu, time left in the Icebreaker; Advanced: + "about +N % trace" for a crack (from the highest tracer gain watching the device); Master: + "routes to N hidden subnets" on a router you have not hacked.
- **Names**: the Map and the Security app name a device by its entity's `display_name` metadata ("CAM-CLOSET"), else its node name in words (`NetworkSource.display_name()`).
- **Routers** (renamed from gateways after the M12a levels, [ADR 0112 amendment](../decisions/0112-hacking-reconciled-with-the-built-game.md#amendment-switches-routers-and-access-points-2026-11-11)): `objects/network/router.tscn` with the `Router` component (`RouterRule` rules) and the network data of the subnets it joins: `subnet_data` (`Subnet` resources: id, name, address range, Map colour; shared ones in `objects/network/subnets/`) and `side_addresses` (its address on each subnet besides its Device's own). Routers are named `RTR-nn`.
- **Subnets on the Map**: the Map lays the network out by subnet. Each subnet whose data a router carries is a flat box of its colour (fill 10 %, a 1 px border) behind its devices, its name and range at the top-left ("SECURITY  10.0.20.0/24"); a box appears only while a device of its subnet is on the map, so a hidden subnet has none. Boxes stand side by side along the router chain, from the deck's own subnet; a router stands between the two boxes it joins, labelled "router", with both addresses on its status line. Inside a box the switches form a tidy tree: a switch's devices hang on it as before ([ADR 0099](../decisions/0099-network-map-layout-pan-zoom.md)), the switches cabled to it stand in rows below it, so a tree network never crosses a cable; a link off the tree (a loop) runs above every box and may cross (`NetworkLayout.extra`). The layout is computed from the topology only, nothing per level. Fit zoom in the deck at 1152 x 648: about 0.48 for the whole warehouse network, 0.51 for the network lab.

## Wireless as built (M12b)

Settled while building it ([ADR 0117](../decisions/0117-wireless-access-points-and-the-decks-wifi.md)):

- **Access points**: `objects/network/access_point.tscn` (`AccessPoint` on a device: `wireless_range` 15 m by default, the Wi-Fi `key` and its strength, `client_address`), powered and breakable like a switch, cabled into one subnet. Network gear (switches, routers, access points: the `object.network_gear` tag or a `Router` / `AccessPoint` component) never links wirelessly.
- **Wireless links** are level data on the device: `Device.wireless` names its access point; the link holds while the device stands within the access point's range (centre to centre). It is a link of the reach graph: a broken or unpowered access point takes its wireless devices offline (their incidents reach no one) while a cabled device beside it stays online. A wireless device takes its access point's subnet and has no maintenance port.
- **Aiming the deck**: with the deck in hand, LMB on an access point you can see, up to 40 m away. Beyond the deck's range (8 / 12 / 18 / 25 m by Computer skill, straight line from the eye) the HUD says so; in range the deck rises on the **Wi-Fi key** screen (or, with the key known, joins at once and shows the Map).
- **Cracking the key**: Crack the key runs the Icebreaker on it (the account base times: Weak 10 s, Medium 24 s, Strong 50 s, times the skill; only keys the skill cracks). It advances only while the access point is in range, in sight (a ray from the eye blocked by world geometry, not by props or people), up and your would-be address is not locked out; otherwise it **pauses** ("Paused: line of sight lost", "out of range", "no signal", "blocked by a tracer") and goes on by itself. It adds trace like any tool on the tracers watching the access point's subnet, keeps running with the deck lowered, and its progress stays on the deck (saved; a changed key starts over).
- **Joined**: a cracked key joins the deck to the access point's subnet over Wi-Fi with the access point's client address (an entry point like a wall jack: the access point is "your entry point", a full trace reports there). Discovery, the Map, the tools and remote desktops work from it. You can lower the deck and walk around; leaving the deck's range of the access point drops the connection and stops its tools; aiming at the access point again in range rejoins (the key is known, saved).
- **On the Map** wireless links are dashed light blue (#7fd4ff), dashed grey with an end offline; wireless devices hang on their access point in the tidy tree (computed from the topology, no crossings); an access point reads "AP-YARD · access point" and a wireless device's menu says "wireless via AP-YARD".
- Levels: the network lab's annex Wi-Fi station (AP-LAB, a wireless camera and laser, floor marks at 6 m and 10 m, a pillar that hides the access point) and the warehouse's AP-YARD (the yard camera and both roof lasers; crack spots on the roof and behind the truck): see [Levels](#levels).

## Exploit items as built (ADR 0121)

Replaces the software, exploit runs and burning of [ADR 0116](../decisions/0116-exploits-firewall-tool-and-device-logs.md) (approved mockup [hacking_fixes.html](../prototypes/hacking_fixes.html)):

- **Kinds are data.** `DeviceKinds` (`objects/devices/device_kinds.tres`) lists every kind of device by entity tag (a `SecurityKind`: name, icon, the Security app's group, `exploit`): a device's kind is the first kind whose tag its entity has. The Security app lists the kinds with a group; the Map draws every box with its kind's icon (switch, router, access point, computer and wall jack included); `exploit` names the item kind that opens it (camera, turret, door, alarm, computer, router; none for switches, access points and jacks).
- **Items**: one ItemData per kind (`items/exploit/<kind>_exploit.tres`, `exploit_kind`), stack to 5, one square, a chip icon (`ItemData.icon`, DeviceIcon strokes); one world pickup scene (`exploit_chip.tscn`) whose ItemPickup names the item.
- **Use** (`ExploitItems`): a reached device's menu shows "Use <kind> exploit (N left)" and a one-line note while you carry one of its kind and have no access there (never on your entry point). Using it is instant, adds no trace, consumes one and gives you admin there for good (`Device.intrusion`, saved; `has_access()` and `is_admin()` read it beside accounts); the menu then says "access: admin (exploit)". A router opens its Firewall and lets your traffic through, so the subnets behind it get scanned; a computer opens its remote desktop as admin. The device's log records "exploit <address> <you> <item>"; EventLog `deck.exploit_used {device, item, kind, left}`.
- **Removed**: the Exploits tool, `Exploit` and `Software` resources, software on devices and on the Map, version matching, burning and patching, exploits taught by mails, files and datapads, the Journal's Exploits section, the tracers' exploit amount.

## Firewall and logs as built (M12b)

Settled while building them ([ADR 0116](../decisions/0116-exploits-firewall-tool-and-device-logs.md)):

- **Firewall rules** (`Router`): first match wins. Your traffic (the deck, on a jack, a port, a computer or Wi-Fi) is judged only by rules from "you"; without one it passes a router you have access to (the M12a rule). Devices' traffic (commands, incidents, ringing, everything sent over the network) is judged by the other rules, else the router's default (allow). So "ALARM → SIREN-OFFICE · DENY" silences that siren when the alarm rings without breaking anything, and "you → SEC-CONSOLE · DENY" is how you would cut yourself off.
- **The Firewall tool** (`FirewallView`, as admin of a router the deck reaches; the router's menu offers "Firewall rules", the tool button opens the last picked router or the first you are admin of): a table of rules (number: click to select; From and To lists: any, "you" (From only), the subnets and devices on your map; ALLOW / DENY toggles), Add a rule (appends "any → any" with the router's default, a no-op until edited), Move up, Move down, Delete, and a line saying what happens without a match. Every edit is logged on the router with your address.
- **Device logs** (`DeviceLog` in `Device.intrusion`, newest 50, saved): logins and failed logins with the source address (a computer's own address bare-handed), exploit items used, commands received (from a device or the deck), remote desktops opened from the deck, firewall edits. Nothing reads them in the game until M16; the debug panel's Network overlay shows each device's log size and newest entry.
- Levels: the lab annex's exploits station (a camera and a router exploit item on its table, the CCTV cameras behind RTR-03 and its Watchdog tracer) and firewall station (RTR-04 between an alarm controller and its sirens: a DENY rule silences them); the warehouse's camera exploit (office desk 1) and alarm exploit (water tower deck) and RTR-01's rules: see [Levels](#levels).

## Levels

- **Network lab** (gallery room 8, M12a, built: [../levels/hub-and-gallery.md](../levels/hub-and-gallery.md#8-network-lab)): behind a ninth hub doorway on the west wall. Office, Security and Servers subnets; RTR-01 (Weak admin, the Icebreaker cracks it Untrained) runs the Sentry tracer watching Office and Security; RTR-02 inside Security leads to a file server with one file (chained discovery; RTR-02's login is in the console's files). A deck on a table at the entrance, a wall jack on the Office subnet, office PC 1 with a sticky note and a mail with an implicit clue to office PC 2's login (the cat's name from a photo and the year), PC 2's mail with the security console's login; the console's Security app commands a camera and a closet door that trust it (two biocells inside); a subnet can span several switches: the camera and the door hang on a closet room switch whose breaker cuts only them while the rest of the Security subnet stays up. A sign at each station. **M12b annex** (a 14 x 14 m room behind the hall's far wall, two networks of its own): the Wi-Fi station (AP-LAB, Weak key, on the Wi-Fi subnet with a wireless camera and laser; floor marks at 6 m, in Untrained range, and 10 m, Trained only; a pillar to step behind; its own breaker), the exploits station (a datapad teaching the Helix camera and EdgeGuard router exploits; CCTV cameras at Helix 2.1 and 2.0 that match and 2.4 that does not; RTR-03, EdgeGuard 1.8, joins CCTV to the Wi-Fi subnet and runs the Watchdog tracer watching CCTV, so a run there patches the other camera while the same run on the Wi-Fi camera burns nothing) and the firewall station (RTR-04, Weak login on a note, between the alarm controller and panic button and the two sirens: deny the controller to the Sirens subnet and the panic button rings nothing).
- **Security wing** (gallery room 5, rebuilt in the M12a format in M12b, [../levels/hub-and-gallery.md](../levels/hub-and-gallery.md#5-security-wing)): Operations (the booth computer, a wall jack in the entry hall) and Security behind RTR-05 (Weak admin, its login in the booth computer's mail, or cracked Untrained); Security spans the main switch on breaker B and an area switch for the booth, the laser hall, the corridor and the vault; every device has a kind (its Map icon) and the security devices trust the booth computer. No tracer.
- **Warehouse** (M12a, built: [../levels/mission-warehouse.md](../levels/mission-warehouse.md#network-m12a)): Office (the office switch, both office PCs, the office wall jack, now a real wall jack) and Security (the console and every security device, on five switches: a main one in the basement store and area switches for the security room, the vault, the yard and the roof) behind RTR-01 in the store, which runs the one tracer (default tuning) watching both. RTR-01's Medium admin login is written nowhere: crack it Trained, or use the console bare-handed with its known login. Security devices trust the console (sirens and the radio base station also the alarm controllers); the office PCs control nothing. The deck is found on office PC 2's desk. M12b ([../levels/mission-warehouse.md](../levels/mission-warehouse.md#wireless-and-intrusion-m12b)): the access point AP-YARD (Weak key) on the north parapet over the dock, cabled to the yard's switch; the yard camera and both roof lasers link to it by radio, so breaking it cuts only them. Cracked from the roof (6.4 m, Untrained) or from the gap behind the truck (10.5 m, Trained), it joins the Security subnet without passing RTR-01 (the Sentry tracer still watches it). Every device has a kind (its Map icon); a camera exploit item lies on office desk 1 and an alarm exploit item on the water tower deck (ADR 0121); RTR-01's rules keep the office off Security except the console (no rule can silence the sirens: they share the controllers' subnet).

## Interactions

- Devices, alarm controller, sirens, radio base station, doors and keypads: [security.md](security.md).
- Guards hearing sirens, radio, the security operator, "use device": [perception-and-ai.md](perception-and-ai.md).
- Power and breaking: [objects-and-fire.md](objects-and-fire.md), [light-and-visibility.md](light-and-visibility.md).
- Deck item: [inventory.md](inventory.md). Skill: [abilities.md](abilities.md). Controls: [controls.md](controls.md).
- Parked: [../backlog.md](../backlog.md) (terminal app, deck upgrades, VLANs, gamepad hacking, remote-hacking augmentation, buying exploits, NPCs noticing changed firewall rules, network app on computers).

## Tuning

Starting values, to be checked by feel in playtest ([playtest checklist](../tech/playtest-checklist.md)). Rule of thumb: no single wait longer than about 25 s, and trace drains fast enough that waiting it out takes seconds, not a minute.

| Value | Start | Result |
|---|---|---|
| Icebreaker base time | Weak 10 s, Medium 24 s, Strong 50 s | See the crack time table above |
| Map scan of a subnet behind a router | 2 s, +10 % trace | The subnet you plug into or join shows at once, no scan (ADR 0121) |
| Exploit item | Instant, no trace, one use | Scarce instead of costly (ADR 0121) |
| Failed login (wrong guess) | +15 % trace | About six wrong guesses fill a tracer |
| Tracer gain while a tool runs against a watched device | 4 %/s | One crack fits: Trained Medium 18 s × 4 × 0.8 = 58 %; Advanced Strong 25 s × 4 × 0.6 = 60 %; two in a row without a pause fill it |
| Sensitive tracer variant (`.tres`) | 7 %/s | Trained Medium 18 s × 7 × 0.8 = 101 %: find the password, use an exploit item or train the skill |
| Trace drain | 10 %/s, starting 2 s after the last gain | 60 % drains in 8 s |
| Lockout after full trace | 30 s | Short: the alarm is the real penalty |

All trace gains are multiplied by the Computer skill's trace gain (×1 / 0.8 / 0.6 / 0.4).

- **Account names**: the Map lists the account names of every device you have seen (like a login banner). Passwords are the secret; clues, the Sniffer and Icebreaker supply them.
- **Security operator's radio call** (M16): on a dark camera feed or "Tracer offline", the operator radios the nearest guard with `equipment.radio`, who goes to investigate the device. Other guards are not alerted.

## M12b and M12c design notes

Settled in [ADR 0115](../decisions/0115-m12b-intrusion-and-m12c-consequences.md) (M12b: exploits, Firewall rules, wireless; M12c: readability and the tradeoffs: mail server routes, loss-of-signal alarms, fail-secure vaults, "Clean hands"). The notes below are the readability details and the candidates as first discussed.

Agreed with the user (2026-11-11), to design with M12b:

- **Readability**:
  - **Status lights**: every networked device has an LED with one colour language: green online, blinking amber lost network, red disabled, dark unpowered; network gear shows port lights that go dark with it.
  - **Labels**: switches, routers and access points carry a plate naming them and what they feed ("SW-VAULT · feeds: vault turret, office camera, alarm"); wiring closets share one look (rack, lights, a "NETWORK CLOSET" sign).
  - **Deck AR view**: with the deck in hand, the links of devices on the Map are drawn in the world, generated from the link data (no per-level routing): "ceiling runs" (up from the device to ceiling height, across, down to its switch), drawn on top of the world in the subnet's colour, fading with distance. No physical cables modelled in levels.
  - **Feedback after an action**: a HUD line when equipment drops ("SW-VAULT offline · 5 devices lost"), sirens announcing a network fault, Mail saying which route is down.
  - Rejected: warnings on the Map before acting (babysitting); physical cables in levels (clutter).
- **Teaching**: the future Deus Ex-style training level teaches the network rules ([../backlog.md](../backlog.md)).
- **Tradeoffs against breaking everything** (candidates, to choose from; the four chosen are built, see [M12c consequences as built](#m12c-consequences-as-built)): mail on a mail server (in the building or on the internet through an edge router's internet link: cut the route and unread mail is out of reach); loss-of-signal alarms (the alarm controller raises a "network fault" incident when several devices drop at once); fail-secure vault doors; cameras as the player's own intel; fail-dangerous standalone devices (a turret that targets everyone without its link); broken gear as evidence for guards (M16); a "Clean hands" badge and payout or XP penalties (M18, M19).

## M12c consequences as built

[ADR 0115](../decisions/0115-m12b-intrusion-and-m12c-consequences.md), M12c's tradeoffs (the readability half, status LEDs, plates, the deck's AR view and the HUD line, is a separate brief).

- **Mail needs a route to its server.** A mail server is any entity with a Device and a `MailServer` component (`objects/network/mail_server.gd`; the wall-mounted box `mail_server.tscn`), named by its `host` (else its display name). "The internet" is data on an edge router: an `InternetLink` component (`internet_link.gd`) listing the off-site hosts reached through it (empty: any). A computer's `Computer.mail_server` names its host (empty: the mail is on the computer, always there, as before M12c). `MailRoute.of(device, host)`: an in-house server is reached while the computer's Device reaches the server's (the reach graph with the routers' rules); an off-site host while it reaches an edge router serving it. While the route is cut, Mail lists only the mail the reader already read (their PersonalLog has it; the Journal keeps it as before) and an amber line above the list says what is down: "Can't reach MAIL-01: no route (RTR-01 is down)", the first down device on the shortest cabled path (`NetworkRoute.first_down()`), or "no route" when nothing on the way is down (a firewall rule, a missing server). An open Mail refills when the route comes or goes (checked every `refresh_interval`). A remote desktop follows the same rule: the route is the remote computer's.
- **Loss-of-signal alarms**: alarm controllers supervise the devices whose incidents would reach them; each drop is a trouble note on the security console, 3 drops within 10 s one "network fault" incident at the switch or router that cut them, sirens announcing it with a fault pattern ([security.md](security.md#loss-of-signal-m12c-adr-0115)).
- **Fail-secure vault doors**: the rule and the plates in [security.md](security.md) (player-facing behaviour).
- **"Clean hands"**: the mission summary's third badge, earned when the player broke nothing at all, directly or not ([ADR 0087](../decisions/0087-mission-systems.md)'s attribution; [mission-warehouse.md](../levels/mission-warehouse.md#consequences-m12c)).
- **Levels**: the warehouse's MAIL-01 in the basement network closet ([mission-warehouse.md](../levels/mission-warehouse.md#consequences-m12c)); the network lab's mail route station ([hub-and-gallery.md](../levels/hub-and-gallery.md#8-network-lab)).

