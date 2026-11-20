*The Lantern Strait is closed. A carrier group is holding station in the deep. Tessera's Air Defense Command needs a commander.*

**Isles of Resistance** is a turn-based air defense campaign on a hex archipelago. You face an adaptive AI air invasion, in a neon near-future where three powers argue over an island that makes the world's chips.

## Download

| Your PC | Installer (recommended) | No-install zip |
|---|---|---|
| **Windows 10 or 11, Intel or AMD** (most PCs) | **[IslesOfResistance-Setup-x64.exe](https://github.com/JonathanJiWu/Isles-of-Resistance/releases/download/v{VERSION}/IslesOfResistance-Setup-x64.exe)** | [IslesOfResistance-Windows-x64.zip](https://github.com/JonathanJiWu/Isles-of-Resistance/releases/download/v{VERSION}/IslesOfResistance-Windows-x64.zip) |
| **Windows on ARM** (Snapdragon-powered laptops and tablets, such as many Copilot+ PCs) | **[IslesOfResistance-Setup-ARM64.exe](https://github.com/JonathanJiWu/Isles-of-Resistance/releases/download/v{VERSION}/IslesOfResistance-Setup-ARM64.exe)** | [IslesOfResistance-Windows-ARM64.zip](https://github.com/JonathanJiWu/Isles-of-Resistance/releases/download/v{VERSION}/IslesOfResistance-Windows-ARM64.zip) |

**Which one do I need?** Open **Settings → System → About** and look at **System type**. *x64-based processor* means x64; *ARM-based processor* means ARM64.

- **The installer** sets the game up for your account only, so no administrator prompt appears. It adds Start menu and desktop shortcuts. Uninstall it from **Settings → Apps**.
- **The zip** needs no installation: extract it anywhere and run `IslesOfResistance.exe`.
- **"Windows protected your PC"?** The game isn't code-signed yet, so SmartScreen warns about new downloads. Click **More info → Run anyway**. You can compare each file against `SHA256SUMS.txt` with `Get-FileHash <file>` in PowerShell.
- **Saves, Hall of Fame and settings** are kept in `%APPDATA%\Isles of Resistance` and survive updates. To update, run the newer installer over the old one.

**Requirements:** 64-bit Windows 10 or 11, and a graphics card with OpenGL 3.3 or Direct3D 11. The game falls back to Direct3D 11 automatically when OpenGL isn't available, as on many ARM laptops. About 150 MB of free disk space.

## What's new in 1.1

- **A war that escalates.** The conflict climbs and falls through five rungs: Gray Zone, Quarantine, Blockade, Strikes and Assault. Each rung changes what the enemy sends and what it will hit: decoy swarms and loitering munitions, jammers and cruise missiles, ballistic salvos against known bases, and finally landing groups racing for the beaches. Restraint and diplomacy can bring it back down.
- **Pressure off the battlefield.** A national interceptor stockpile that every SAM shot draws down. An LNG reserve that drains under blockade, with rolling blackouts. Undersea cables whose loss blinds your intelligence. Raid forecasts that are only as good as your intelligence. Thirteen situations, from a tanker stopped for "inspection" to an enemy pilot pulled from the sea, each with real trade-offs and some with deadlines.
- **New tools.** Shoot-and-scoot SAM and missile launchers, Cicada EW stations, Swiftlet drone boats, hit-to-kill interceptors, emergency interceptor orders, and rebuilding destroyed infrastructure. The enemy gains early-warning planes, EW jets, missile bombers, stealth fighters and amphibious landing groups.
- **A living archipelago.** Installations you can read at a glance, roads, villages, lighthouses and wind farms, shipping that thins out as the blockade tightens, seasons and weather that matter, and battle damage that stays.
- **Field Training.** A one-minute interactive tutorial at the start of your first campaign, replayable any time.
- **Research-based.** The forces and escalation are modeled on open-source analysis of the Taiwan Strait at the level of roles and capabilities, then fictionalized. See [docs/RESEARCH.md](https://github.com/JonathanJiWu/Isles-of-Resistance/blob/v{VERSION}/docs/RESEARCH.md) and [docs/ROSTER_AUDIT.md](https://github.com/JonathanJiWu/Isles-of-Resistance/blob/v{VERSION}/docs/ROSTER_AUDIT.md).
- **Faster rendering.** Static map layers now draw in a handful of draw calls instead of thousands.

Saves from 1.0 can't be continued in 1.1, because the campaign state has changed. Your Hall of Fame and settings carry over, and returning players aren't sent through Field Training automatically: it's in the main menu.

## What's in the game

- **Adaptive enemy.** The invader has its own fog of war, routes around your known defenses, and rebuilds each wave to counter your favorite weapons.
- **Story you play.** Four acts, eight political directives and thirteen situations, each with explicit consequences. You manage Public Resolve, Hesperian Commitment and the Glass Shield over Silica Point. Spend research on cyber ops, follow a live news ticker and intercepted pilot chatter, open the Intel Archive, and reach one of several epilogues.
- **Strategy.** Generated archipelagos with meaningful terrain, recon flights, an 18-technology research tree, interceptor squadrons, and carrier strikes.
- **Polish.** Skippable battle animations, procedural music and sound, four difficulty levels with an even ramp, autosave, and a Hall of Fame.

Full details are in the [README](https://github.com/JonathanJiWu/Isles-of-Resistance#readme). The world bible is in [docs/WORLD.md](https://github.com/JonathanJiWu/Isles-of-Resistance/blob/v{VERSION}/docs/WORLD.md).

Built with [Godot Engine](https://godotengine.org) 4.4.1. Third-party licenses are in `THIRD-PARTY-NOTICES.txt` next to the game.
