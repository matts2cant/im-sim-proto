# 115. M12b intrusion (exploits, firewall rules, wireless) and M12c consequences (readability, tradeoffs)

Status: Accepted (extends [ADR 0112](0112-hacking-reconciled-with-the-built-game.md))

Date: 2026-11-11

## Context

M12a shipped the network, computers, the deck's Map and Icebreaker, tracers and the network lab ([ADR 0113](0113-network-layer-tracers-and-the-deck.md), [ADR 0114](0114-computers-halcyon-os.md)). The user and the chief engineer settled the rest of hacking in a design review: what M12b adds to intrusion, and how M12c makes breaking the network a readable choice with a cost rather than the best answer to everything.

## Decision

**M12b, intrusion**

- **Exploits**: found in files, mails and datapads and learned into a new **Exploits** section of the Journal. Each targets a vendor, a product and a version range and grants user or admin access. Once a subnet is scanned, the deck's Map shows each device's vendor, product and version in its menu, and the deck's **Exploits** tool lists the exploits that match the selected device. A run takes 4 s and adds 10 % trace. **Burned when detected**: if a tracer watching the subnet sees the run, every device on that subnet with the targeted product is patched against that exploit.
- **Firewall tool**: as admin of a router, view and edit its ordered rules (from / to: a subnet, a device or "you"; allow or deny; first match wins). Rules decide which devices reach which through that router: commands, incidents and "ring" (blocking the alarm controller from the sirens silences them without breaking anything). An account on a router still lets the player's own traffic through, as in M12a; requiring an "allow me" rule may come later.
- **Wireless**: access points have a range; any device except network gear (switches, routers, access points) can link wirelessly to one instead of by cable; wireless links show as dashed light-blue lines on the Map; breaking or unpowering an access point takes its wireless devices offline. **Hacking an access point**: aim the deck at it, within range (8 / 12 / 18 / 25 m by Computer skill) and with a clear line of sight, and crack its Wi-Fi key with the Icebreaker; losing sight pauses the crack (progress kept). Once cracked, the deck joins its subnet from anywhere in range.
- **Logs**: devices record logins, failed logins, exploit runs and remote actions with the source address. The tool to read and erase them moves to M16, with the guards who read logs.

**M12c, consequences**

- **Readability**: status LEDs on every networked device (green online, blinking amber lost network, red disabled, dark unpowered; port lights on network gear); plates on network gear naming what it feeds, and wiring closets with one shared look; the deck's AR view drawing links in the world as "ceiling runs" in the subnet's colour, generated from the link data; feedback after an action (a HUD line, Mail saying which route is down, a siren announcement for a network fault).
- **Mail needs a route to its server**: per level, the mail server is in-house (its own subnet) or on the internet through an edge router's internet link. Mail already read stays in the Journal; unread mail is out of reach while the route is cut.
- **Loss-of-signal alarms** (the alarm controller): each supervised device that drops is a "trouble" note on the console; 3 or more within 10 s (tuning) raise a "network fault" incident at the failed equipment.
- **Fail-secure vault doors** placed in levels.
- **"Clean hands" badge**: earned only when nothing at all was broken in the mission.

## Alternatives considered

- **An account on a router needing an "allow me" rule** (more realistic): deferred; it can replace the M12a rule later.
- **The Logs tool in M12b**: no one reads logs before M16, so erasing them would have no effect.
- **Fail-dangerous turrets** (cut off, they target everyone): left out until the readability cues are proven.
- **Loss of signal on every dropped device**: picking off one device quietly would be impossible.
- **Exploit versions found only in documents**: matching should be a quick read; finding the exploit is the challenge.

## Consequences

- [hacking.md](../game/hacking.md) gains the M12b and M12c sections; the roadmap splits M12b and M12c.
- An HTML mockup of the Exploits tool, the Firewall tool, the Map's software lines and wireless precedes M12b's agents.
- M12c starts after the user plays M12b.
