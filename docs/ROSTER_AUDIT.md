# Roster audit: the game's forces against the research

This audit compares every military element of *Isles of Resistance* (enemy aircraft and munitions, naval forces, the player's installations, units and research) against the findings in [RESEARCH.md](RESEARCH.md) and its three briefs. It then lists every change made because of it. The numbers in brackets, such as (R6), refer to the numbered findings in RESEARCH.md, "What the research says, in brief".

The game stays fiction. Factions, places and hardware are invented composites, no real system is named in game text, and the research works at the level of roles, capabilities and constraints, never tactics.

## Principles

1. **Roles, not replicas.** Each unit stands for a *role* the research says matters, such as a standoff missile carrier, an airborne early-warning plane or a decoy drone. It is not a specific real aircraft.
2. **Asymmetric doctrines, not mirror balance.** The sides do not get equivalent tools. The Commonwealth has numbers, reach and the initiative. Tessera has terrain, dispersal, its own decisions and time. Balance comes from what each side can do to the other's plan, not from matching unit lists.
3. **Proportions, not inventories.** The research gives relationships the game can keep, for example that interceptors are scarce while drones are cheap, or that gas runs out in about two weeks. Exact counts do not survive abstraction to a hex map, so the game does not try to reproduce them.
4. **Every change must create a decision.** A capability goes in only if it gives the player a choice: what to shoot at, what to spend, what to move, what to risk. Realism alone is not enough.
5. **Abstract what the scale cannot carry.** Some domains are real and important but are not modeled as units, such as submarines, mines and tankers. They are listed under "Deliberately abstracted" with the reason.

## Audit

Verdicts: **Kept** means plausible as is. **Reworked** means right idea, wrong profile. **Added** means a missing category the research flags as important. **Consolidated** means folded into something else. **Departure** means the game knowingly differs from the research.

### Celestine Commonwealth (attacker)

| Element (before) | What the research says | Verdict | Action |
|---|---|---|---|
| **Magpie Recon Drone**: low, fast, fragile scout | Reconnaissance drones are high-altitude, long-endurance and persistent; ISR feeds every later strike (R8) | Reworked | **Magpie ISR Drone**: high altitude, hp 10→14, vision 3→4, endurance 4→6, speed 6→5. Harder to swat with guns, and it maps your sites for the waves that follow. |
| *(none)* | Decoys and converted old jets are used in mass to saturate and drain air defenses. Decoys were about 40% of one side's drone launches in late 2025, and about 200 converted J-6 drones are estimated near the strait (R9, Verification) | Added | **Paper Lantern** decoy (cost 1, high altitude, threat 5). It looks like a bomber to your fire control, so your SAMs spend interceptors on it. Phased in from Quarantine. |
| *(none)* | Cheap one-way attack drones and anti-radiation loitering munitions hunt radars and air defenses (R9, air brief) | Added | **Kitefang Loitering Munition** (cost 2, low altitude). It homes on emitters: radars, SAMs, EW stations. Phased in from Quarantine. |
| **Shrike Strike Fighter** | Multirole fighters sweep and escort | Kept | Description refined (escort and sweep). |
| *(none)* | Enablers multiply everything. EW aircraft jam radars and data links (R8) | Added | **Static EW Jet**. Your defenses within 2 hexes of it lose their radar bonus and 20% accuracy. From Blockade. |
| *(none)* | Airborne early warning extends the attacker's picture. There are few such planes and they are priority targets (R8) | Added | **Skylark AEW&C**. It orbits, reveals sites (vision 6) and adds 10% to every enemy attack while it flies. Spotting one creates a time-limited **objective** to shoot it down. |
| **Monsoon Heavy Bomber**: overflies the target with gravity bombs | Bombers are "missile trucks" that launch from beyond air-defense range (R7) | Reworked | **Monsoon Missile Bomber**. It never overflies your guns: it launches two Needle cruise missiles from 4 hexes out, then turns home. Killing it early matters more than shooting its missiles. |
| **Needle Sea-Skimmer**: anti-ship profile used against land, 40 damage, from wave 4 | Land-attack cruise missiles from bombers, ships and ground launchers are numerous and fast (air brief) | Reworked | **Needle Cruise Missile**: damage 40→28 because it is now more numerous. Gated by escalation (Blockade) rather than wave number, and also launched by bombers mid-raid. |
| **Inkwash Stealth Bomber** | Low-observable *fighters* in growing numbers. Their key wartime job is to suppress air defenses (air brief) | Reworked | **Inkwash Stealth Fighter**: hp 36→30, speed 4→5, damage 36→24, cost 8→7. Hunts emitters (radars, SAMs, EW). From Blockade, wave 5+. |
| **Mantis Gunship**: carrier-borne helicopter doing deep air-defense suppression | Attack helicopters support amphibious landings near the beach and are not deep-strike assets (naval brief, amphibious section) | Reworked / Consolidated | **Mantis Attack Helicopter** now flies only from landing groups, up to two per group as it nears the beach. Its suppression role passes to the Kitefang and Inkwash. |
| *(none)* | Missiles open the war. About 90% of allied aircraft losses in wargames happen on the ground, from ballistic and cruise strikes on bases, radars and air defenses (R6) | Added | **Ballistic salvos** at the Strikes rung. They open each raid against *known* runways, SAMs, radars and launchers. Only Longbows with Hit-to-Kill interceptors can engage, at 2 interceptors per try. |
| *(none)* | Amphibious lift is the invader's center of gravity and its weakness. Mobile anti-ship missiles and drones sank much of it in wargames (R11) | Added | **Landing groups** at the Assault rung. They sail a visible route to a beach on a clock, and the town behind it falls if they arrive. Strike them with air strikes, cruise missiles and drone boats. |
| *(none)* | A coast-guard "quarantine" framed as customs work, militia fleets and deniable cable cuts all stay below the threshold of war (R3, R5) | Added (non-combat) | Represented as **situations**, not units: inspections, anchor-drag cable cuts and fishing fleets, each with a choice. See "Campaign tension" below. |
| **Harmony-class carriers**: sinking all of them wins | Carriers are a sideshow near the strait. Land-based air and missiles dominate (R12) | **Departure** (kept) | Kept as Tessera's offensive objective because it gives the player a way to *end* the war rather than only survive it. The departure is softened: about 45% of every raid's budget comes from the off-map mainland and never shrinks. Landing groups are the real center of gravity at Assault. |

### Republic of Tessera (defender)

| Element (before) | What the research says | Verdict | Action |
|---|---|---|---|
| **Flak Battery** | Guns are the cheap answer to drones and decoys (R9, R10) | Kept | Now the economical counter to Paper Lanterns and Kitefangs. |
| **Radar Station** | Radars are priority targets, and emitting reveals your position (air brief) | Kept | Now hunted by Kitefangs and Inkwash fighters, and targeted by salvos once known. |
| **Longbow SAM Site**: unlimited missiles | Interceptors are scarce and expensive, cost far more than what they shoot down, and take years to replace. US stocks were drained in the 2026 Iran war, though how much is *contested* (R9) | Reworked | **National interceptor stockpile**. Every Longbow shot spends one. Stock starts at 30/24/20/18 by difficulty (cap 60) and grows +2 a turn (+1 while the Foundry stands). Emergency orders cost 15 supplies for 3, once a turn. Out of stock means silent Longbows. The site is now **mobile**. |
| **Lumen Laser**: range 2, 18/18 damage, 95% accuracy, cost 110 | Directed energy is cheap per shot but short-ranged, weaker against large targets, and degraded by rain, fog and cloud (Iron Beam entered service with exactly that caveat). It needs power (R10) | Reworked (was too strong) | Range 2→1, shots 3→4, damage 18/18→18/9 (low/high), accuracy 95→90%, cost 110→90. −15 to −40% accuracy in haze, rain, fog and storm. **Dark during blackouts.** |
| **Missile Battery**: static, anti-carrier only | Mobile shore-based anti-ship missiles were decisive against landing fleets in wargames (R11) | Reworked | **Mobile** (relocate). Strikes **landing groups** as well as carriers. |
| **Airbase / Kestrel Interceptors** | Airfields are where air power dies. Shelters, dispersal and runway repair decide recovery (R6) | Kept | Salvos put runways first. A cratered runway grounds its squadron until repaired, and storms ground aircraft on both sides. |
| **Lantern-class Corvette** | Converted coast-guard hulls with air defense | Kept | Unchanged. |
| **Shelter Network, Decoy Site** | Passive defense, hardening and deception are core to survival (air brief) | Kept | They matter more now that salvos aim at *known* sites. |
| *(none)* | Electronic warfare is the main counter-drone tool (R10) | Added | **Cicada EW Station** (cost 45, Electronic Warfare tech). Within 2 hexes, each drone, decoy and loitering munition has a 30% chance a step of losing control, and missiles, decoys and loitering munitions striking a covered site lose 20% accuracy. It is an emitter, so it reveals itself. Mobile. Dark in blackouts. |
| *(none)* | Sea drones and uncrewed surface vessels are cheap counters to ships (air brief; naval brief) | Added | **Swiftlet Drone Boats** (cost 25, Uncrewed Systems tech, up to 3 per Harbor). One-way attack on an adjacent landing group or carrier for 34 damage; escorts stop 1 in 5. |
| *(none)* | Energy is the binding constraint in a blockade: about 96% imported, LNG for about 11–12 days (R4) | Added | **Power station** and **LNG reserve** (12 days). See "Campaign tension". |
| *(none)* | Undersea cables carry nearly all traffic and are cut deniably (R5) | Added | **Cable landing station**. Losing it degrades communications and lowers intelligence confidence. |

### Hesperian Federation (distant guarantor)

| Element (before) | What the research says | Verdict | Action |
|---|---|---|---|
| **Arms shipments** after repelled waves, scaled by Commitment | Allied help is uncertain, late and finite, and constrained by politics on all sides (R13) | Kept, extended | Under blockade, shipments also bring an escorted LNG tanker (+2 days). Commitment moves with your choices in situations, for example sharing intelligence or escorting tankers. |

### Research tree

| Tech | Tier | Prerequisites | Why |
|---|---|---|---|
| **Electronic Warfare** (new) | 1 | Improved Radar | EW as the primary counter-drone tool (R10). Unlocks the Cicada EW Station. |
| **Hit-to-Kill Interceptors** (new) | 2 | Guided Missiles, Phased Array | Ballistic missile defense exists but is costly and imperfect (R6, R9). Longbows can engage salvos at 2 interceptors per try (55%, 65% with Phased Array) and get +10% against cruise missiles. |
| **Uncrewed Systems** (new) | 2 | Naval Air Defense | Sea drones against the amphibious fleet (R11). Unlocks Swiftlet Drone Boats. |

## Change list

All values are in `Scripts/core/Defs.gd` unless stated otherwise.

**Commonwealth roster**

| Unit | Before | After |
|---|---|---|
| Magpie | Recon Drone · low · hp 10 · speed 6 · vision 3 · fuel 4 | ISR Drone · **high** · hp 14 · speed 5 · vision 4 · fuel 6 |
| Paper Lantern | — | **new** · decoy · high · hp 12 · damage 16 · cost 1 · from Quarantine |
| Kitefang | — | **new** · emitter-seeking loitering munition · low · hp 10 · damage 22 · cost 2 · from Quarantine |
| Static EW Jet | — | **new** · jammer · −20% accuracy and no radar bonus within 2 hexes · from Blockade |
| Skylark AEW&C | — | **new** · +10% enemy accuracy while airborne · vision 6 · from Quarantine, wave 2+ · triggers an intercept objective |
| Monsoon | Heavy Bomber · gravity bombs · damage 32 + splash | Missile Bomber · **standoff** · launches 2 Needles from 4 hexes |
| Needle | Sea-Skimmer · damage 40 · from wave 4 | Cruise Missile · damage 28 · from Blockade · also launched by bombers |
| Inkwash | Stealth Bomber · hp 36 · speed 4 · damage 36 · cost 8 · from wave 6 | Stealth Fighter · hp 30 · speed 5 · damage 24 · cost 7 · **hunts emitters** · from Blockade, wave 5 |
| Mantis | Gunship · in carrier waves | Attack Helicopter · **flies only from landing groups** |
| Ballistic salvo | — | **new** · 2/2/3/3 missiles per raid by difficulty (+1 in the second half of the campaign) · Strikes rung and above |
| Landing group | — | **new** · 1/1/1/2 groups · hp 100/130/150/130 · 2 hexes a turn · tracked within 7 hexes of any of your sites · Assault rung |

**Tessera roster**

| Item | Before | After |
|---|---|---|
| Longbow SAM | unlimited shots | 1 interceptor per shot · national stockpile · **mobile** |
| Lumen Laser | range 2 · 3 shots · 18/18 · 95% · cost 110 | range 1 · 4 shots · 18/9 · 90% · cost 90 · weather penalties · needs power |
| Missile Battery | static · carriers only | **mobile** · carriers and landing groups |
| Cicada EW Station | — | **new** structure · cost 45 · aura 2 · mobile |
| Swiftlet Drone Boats | — | **new** unit · cost 25 · hp 12 · move 4 · strike 34 |
| Power station | — | **new** infrastructure · hp 70 · blackouts when below half strength · rebuildable from ruins (60) |
| Cable landing station | — | **new** infrastructure · hp 40 · degraded comms when below half · rebuildable (30) |
| Relocation (shoot and scoot) | — | 10 supplies · up to 2 hexes · enemy planners lose the site · it holds fire during the next raid |
| Interceptor procurement | — | 15 supplies → +3 interceptors, once a turn |
| Harbor production | 2 units of any kind | limits now per kind (2 corvettes, 3 drone-boat flotillas) |

**Difficulty table** (recruit / regular / veteran / commander)

| Parameter | Before | After |
|---|---|---|
| Starting interceptors | — | 30 / 24 / 20 / 18 |
| Escalation per wave | — | 4 / 6 / 6 / 6 pressure |
| Landing groups | — | 1 / 1 / 1 / 2 |
| Salvo size | — | 2 / 2 / 3 / 3 |
| Wave budget base / growth | 9 / 5, 16.5 / 9.1, 20 / 11, 21.5 / 11.5 | 9 / 5, 16.5 / 9.1, **19.8 / 10**, **19.5 / 9.4** (retuned for the new pressures) |
| Commander starting supplies | 95 | 100 |

## Doctrines

The sides are deliberately unlike each other.

**Celestine Commonwealth: mass, reach and escalation control.** It opens with pressure that is not quite war and climbs only when the next rung looks worth its cost. Its raids lead with cheap mass (ISR drones to find you, decoys to drain your interceptors, loitering munitions to blind you), multiplied by a few precious enablers (early warning, jammers), then deliver the real damage from standoff range. Its planner remembers which of your sites it has seen and spends its missiles on them. It is not a cartoon. Its pilots doubt, its ministries argue, and its Council can be talked down a rung.

**Republic of Tessera: deny, disperse, endure.** Tessera cannot win a war of attrition and does not try. It manages the cost exchange: guns, EW and lasers for cheap threats, scarce interceptors for fast ones. It moves what can move, hardens and repairs what cannot, protects the gas and the cables, and keeps the public behind it. It also has agency beyond the battlefield. Its decisions in situations (escort or comply, punish or return a captured pilot, ration or burn reserves) move the escalation ladder as surely as the enemy's do.

**Hesperian Federation: ambiguity with a price tag.** Help is real, but it is conditional, finite and political. Arms and tankers arrive when Commitment is high, Commitment depends on what Tessera does, and none of it arrives fast.

## Campaign tension systems built on the audit

- **Escalation ladder** (Gray Zone → Quarantine → Blockade → Strikes → Assault). Pressure starts at 30 (Quarantine) and rises with every raid and with provocative choices. Restraint, pauses, sinking a landing group and de-escalatory choices lower it. Thresholds are 18/42/64/84 with 8 points of hysteresis, so it can step down too. Each rung changes enemy targeting (cities, infrastructure), the raid interval (4→2 turns) and which weapons appear. Dropping below Assault turns landing groups back.
- **Intelligence confidence** (Low / Moderate / High), from radar, the satellite uplink, allied sharing, recon and comms. The wave forecast's timing window, size range, sector and composition all widen or sharpen with it, and at low confidence the sector can simply be wrong.
- **Sustainment.** The interceptor stockpile, the LNG reserve (12 days; it drains under Blockade and refills when the ladder steps back), blackouts, repair crews and cratered runways.
- **Weather and seasons.** Each map has a theater and season with its own weather odds. Fog shortens vision. Rain, haze and fog degrade lasers. Storms ground aircraft on both sides and delay raids.
- **Situations.** Thirteen non-combat dilemmas: inspections, cable cuts, a downed enemy pilot, evacuations, typhoons, mobilization, disinformation, a defector, blackouts, fishing fleets, a pause offer, insurance and rescue. Each has two or three options with explicit costs in supplies, gas, Resolve, Commitment, intelligence or escalation. Some create timed **objectives**: hold a city unhit while it evacuates, shoot down an AEW plane before it leaves, stop a landing group.

## Deliberately abstracted

| Domain | Why it is not a unit | Where it appears instead |
|---|---|---|
| Submarines, mines, anti-submarine warfare | The game has no undersea layer, and adding one would double the map's complexity for little decision value | Narrative (situations, codex); cable cuts |
| Tankers and aerial refueling | Folded into each aircraft's fuel range | Fuel limits on raids |
| Mainland air bases and missile garrisons | Off-map, so the player cannot reach them | The non-shrinking ~45% of each raid; ballistic salvos |
| Coast guard and maritime militia | Below the threshold of combat | Situations; ambient shipping that changes with escalation |
| Space and cyber | Too abstract for hex combat | Satellite Uplink tech; Cyber Ops; comms degradation |
| Reserves, mobilization, civil defense | Society-level resilience | Public Resolve; the mobilization and evacuation situations; Shelter Networks |

## Balance after the changes

Bots play 24 seeds per row (`godot --headless -s tests/run_tests.gd -- --balance`). Target: an even difficulty ladder close to the previous release (about 100 / 88 / 62 / 27% for the full bot).

| Difficulty | Full bot: wins | Half-hearted bot: wins | Avg. turns (full bot) | Previous release (full bot) |
|---|---|---|---|---|
| Recruit | 100% | 100% | 32.5 | ~100% |
| Regular | 91% | 50% | 40.5 | ~88% |
| Veteran | 53% (65% over 48 seeds) | 16% | 36.9 | ~62% |
| Commander | 22% | 0% | 38.1 | ~27% |

32 seeds per row, November 2026. Results move by about ±10 points between seed sets, so the veteran figure is shown for two runs. To get here, several mechanics were changed or retuned after the first balance runs:

- **Blackouts were a death spiral.** In early runs a destroyed power station meant blackouts for the rest of the war, which was over 60% of turns. Now its loss means three turns of blackouts and a faster drain, it can be rebuilt, the reserve drains every other turn until Assault, and escorted tankers refill it.
- **Landing groups were invisible until the last moment.** They are now tracked within 7 hexes of any site, spawn about 12 hexes out rather than at the map edge, and turn back if the war steps down from Assault.
- **Later rungs stacked too much.** Escalation no longer also inflates raid budgets (×1.15 at Assault became ×1.0), because the rung's new weapons are the escalation. Salvo sizes, the veteran and commander wave budgets, and landing-group strength were trimmed.

The bot is a heuristic stand-in. It does not use situations well (it picks options at random) or exploit relocation fully, so a thoughtful player should do better than it on every difficulty.

## Limits

- Ratios come from open sources, which are themselves estimates, and several are contested (interceptor stocks, amphibious lift). The game uses them for direction and proportion only.
- The ladder is a design device distilled from analysts' *alternative pathways*. It is not a prediction of how a real crisis would unfold.
- No real-world system, unit, place or person is named in the game.
