class_name Defs
extends RefCounted
## Static game data: terrain, structures, units, enemy aircraft, technologies, difficulty.

const VERSION := "1.0.0"
const MAP_W := 24
const MAP_H := 16
const WAVE_INTERVAL := 3
const FIRST_WAVE_TURN := 2
const CARRIER_ZONE := 6          # carriers patrol the easternmost N columns
const RECON_COST := 15
const RECON_RANGE := 12
const RECON_RADIUS := 3
const AIR_STRIKE_COST := 30
const AIR_STRIKE_RANGE := 10
const MISSILE_COST := 10
const MISSILE_RANGE := 12
const RELOCATE_COST := 10
const RELOCATE_RANGE := 2
const PROCURE_COST := 15
const PROCURE_AMOUNT := 3
const INTERCEPTOR_CAP := 60
const BMD_COST := 2               # interceptors spent per attempt on a ballistic missile
const REPAIR_CREWS := 2
const ENERGY_DAYS := 12           # LNG reserve when the blockade starts (CSIS: ~11-12 days)
const LANDING_SPEED := 2
const BOAT_RANGE := 1

const PLAYER_COLOR := Color(0.31, 0.82, 0.77)
const PLAYER_DARK := Color(0.11, 0.44, 0.47)
const ENEMY_COLOR := Color(1.0, 0.35, 0.37)
const ENEMY_DARK := Color(0.55, 0.11, 0.17)
const GOLD := Color(1.0, 0.82, 0.4)
const GOOD := Color(0.49, 0.89, 0.53)
const BAD := Color(1.0, 0.42, 0.42)
const WARN := Color(1.0, 0.75, 0.3)
const INTEL := Color(0.55, 0.75, 1.0)
const MUTED := Color(0.62, 0.69, 0.78)

const TERRAIN := {
	"deep": {
		"name": "Deep Ocean", "water": true, "color": Color(0.07, 0.24, 0.39), "elev": 0,
		"desc": "Open sea. Only AA Frigates can sail here. The enemy carrier fleet lurks in the far eastern deep.",
	},
	"shallow": {
		"name": "Shallows", "water": true, "color": Color(0.16, 0.44, 0.59), "elev": 0,
		"desc": "Coastal waters. AA Frigates can sail here.",
	},
	"beach": {
		"name": "Beach", "water": false, "color": Color(0.85, 0.77, 0.54), "side": Color(0.62, 0.53, 0.33), "elev": 0,
		"desc": "Sandy coast. Buildable.",
	},
	"plains": {
		"name": "Grassland", "water": false, "color": Color(0.48, 0.64, 0.35), "side": Color(0.31, 0.43, 0.22), "elev": 0,
		"desc": "Open ground. Buildable.",
	},
	"forest": {
		"name": "Forest", "water": false, "color": Color(0.25, 0.48, 0.24), "side": Color(0.16, 0.31, 0.16), "elev": 0,
		"desc": "Buildable. Camouflage: enemy aircraft only spot structures here from an adjacent hex.",
	},
	"hills": {
		"name": "Hills", "water": false, "color": Color(0.56, 0.6, 0.36), "side": Color(0.39, 0.42, 0.24), "elev": 4,
		"desc": "Buildable. Elevation: weapons gain +1 range and structures +1 vision.",
	},
	"mountain": {
		"name": "Mountains", "water": false, "color": Color(0.55, 0.52, 0.5), "side": Color(0.36, 0.34, 0.32), "elev": 8,
		"desc": "Only Radar Stations can be built here (+2 vision). Low-altitude aircraft cannot fly over mountains.",
	},
}

## Structures. "build": false marks the Capital and Cities which are placed by the map generator.
const STRUCTURES := {
	"capital": {
		"name": "Capital", "build": false, "hp": 150, "vision": 3, "income": 12, "rp": 3,
		"range": 1, "shots": 1, "dmg_low": 8, "dmg_high": 5, "acc": 0.65, "weapon": "flak", "value": 10,
		"desc": "Seat of the Assembly of Tiles, with light anti-air guns. If the Capital falls, the war is lost.",
	},
	"city": {
		"name": "City", "build": false, "hp": 80, "vision": 2, "income": 5, "value": 7,
		"desc": "Population center. Provides +5 supplies per turn while it stands. Losing one shakes Public Resolve.",
	},
	"power": {
		"name": "Power Station", "build": false, "hp": 70, "vision": 1, "value": 6,
		"desc": "LNG-fired turbines and the terminal that feeds them: most of the island's electricity. If it is knocked out the grid browns out: lasers go dark, radars lose range and the Foundry slows.",
	},
	"cable": {
		"name": "Cable Landing Station", "build": false, "hp": 40, "vision": 1, "value": 4,
		"desc": "Where the undersea data cables come ashore, with a microwave relay as backup. If it is lost, communications degrade and your intelligence becomes less reliable.",
	},
	"flak": {
		"name": "Flak Battery", "build": true, "cost": 30, "hp": 40, "vision": 2,
		"range": 1, "shots": 2, "dmg_low": 12, "dmg_high": 6, "acc": 0.75, "weapon": "flak", "value": 3,
		"desc": "Rapid-fire 35mm guns: cheap to fire, deadly against drones, loitering munitions, helicopters and sea-skimming missiles, weak against anything flying high. The barrels are older than the gunners.",
	},
	"radar": {
		"name": "Radar Station", "build": true, "cost": 40, "hp": 30, "vision": 4, "value": 5, "mountain_ok": true,
		"desc": "Wide-area vision. Your weapons gain +15% accuracy against targets inside radar coverage. It is also an emitter: anti-radiation drones and stealth fighters hunt it. Rule one: the radar is never wrong.",
	},
	"harbor": {
		"name": "Harbor", "build": true, "cost": 45, "hp": 40, "vision": 2, "income": 6, "value": 5, "coastal": true,
		"desc": "+6 supplies per turn. Must be built on the coast. Commissions Lantern-class corvettes. Insured, for now, by Meridian Mutual.",
	},
	"lab": {
		"name": "Research Lab", "build": true, "cost": 50, "hp": 30, "vision": 1, "rp": 4, "value": 6,
		"desc": "+4 research per turn. Staffed by TLW engineers on loan, and on caffeine.",
	},
	"airbase": {
		"name": "Airbase", "build": true, "cost": 70, "hp": 60, "vision": 2, "value": 6,
		"desc": "Trains Kestrel interceptor squadrons and launches air strikes on carriers and landing groups within 10 hexes. If the runway is cratered (below half HP) its squadrons are grounded until it is repaired.",
	},
	"sam": {
		"name": "Longbow SAM Site", "build": true, "cost": 60, "hp": 35, "vision": 2, "tech": "guided_missiles",
		"range": 3, "shots": 1, "dmg_low": 14, "dmg_high": 32, "acc": 0.85, "weapon": "sam", "value": 4,
		"desc": "Halberd-licensed long-range missiles, devastating against high-flying aircraft. Every shot spends one interceptor from the national stockpile, and cheap decoys are built to drain it. Mobile: relocate it to hide from enemy planners.",
	},
	"bunker": {
		"name": "Shelter Network", "build": true, "cost": 35, "hp": 60, "vision": 1, "tech": "hardened_shelters", "value": 2,
		"desc": "Hardened shelters and subway bunkers. Adjacent structures and cities take 35% less damage.",
	},
	"decoy": {
		"name": "Decoy Site", "build": true, "cost": 20, "hp": 15, "vision": 1, "tech": "deception", "value": 6,
		"desc": "An inflatable fake facility, made by a toy company that used to export to the Commonwealth. Enemy planners mistake it for a high-value target.",
	},
	"missile": {
		"name": "Missile Battery", "build": true, "cost": 80, "hp": 40, "vision": 1, "tech": "cruise_missiles", "value": 6,
		"desc": "Truck-mounted anti-ship missiles: strike spotted carriers and landing groups within 12 hexes (10 supplies per launch). Mobile launchers survive by moving: relocate after firing.",
	},
	"laser": {
		"name": "Lumen Laser", "build": true, "cost": 90, "hp": 45, "vision": 2, "tech": "directed_energy",
		"range": 1, "shots": 4, "dmg_low": 18, "dmg_high": 9, "acc": 0.9, "weapon": "laser", "value": 4,
		"desc": "Halberd Dynamics directed-energy point defense: almost free per shot and superb against drones, decoys and missiles, but short-ranged, weaker against big aircraft, degraded by rain, fog and haze, and dark when the grid fails. The firing key is a subscription.",
	},
	"ewar": {
		"name": "Cicada EW Station", "build": true, "cost": 45, "hp": 30, "vision": 2, "tech": "electronic_warfare", "value": 4,
		"aura": 2,
		"desc": "Jams the links and navigation of drones, decoys and loitering munitions within 2 hexes (each may lose control every step) and throws incoming missiles off by 20%. An emitter: it gives its position away. Mobile.",
	},
}

const BUILD_ORDER := ["flak", "radar", "harbor", "lab", "airbase", "sam", "bunker", "decoy", "missile", "laser", "ewar"]
## Structures that can relocate (mobile launchers and emitters).
const MOBILE := ["sam", "missile", "ewar"]

const UNITS := {
	"interceptor": {
		"name": "Kestrel Interceptors", "cost": 45, "hp": 30, "move": 5, "vision": 2, "dmg": 18, "acc": 0.8,
		"from": "airbase", "air": true, "fuel_range": 6, "max_per": 2,
		"desc": "Fighter jets. Move up to 5 hexes and attack an adjacent aircraft. If they hold fire on your turn, they patrol and engage the first enemy that comes close. Must stay within 6 hexes of an Airbase.",
	},
	"frigate": {
		"name": "Lantern-class Corvette", "cost": 55, "hp": 50, "move": 3, "vision": 3, "tech": "naval_aa",
		"range": 2, "shots": 2, "dmg_low": 10, "dmg_high": 9, "acc": 0.72, "weapon": "flak",
		"from": "harbor", "air": false, "max_per": 2,
		"desc": "Converted coast guard hull with AA guns and long-range sensors. Sails coastal and deep water.",
	},
	"droneboat": {
		"name": "Swiftlet Drone Boats", "cost": 25, "hp": 12, "move": 4, "vision": 2, "tech": "uncrewed_systems",
		"from": "harbor", "air": false, "max_per": 3, "strike_dmg": 34,
		"desc": "A flotilla of explosive uncrewed boats. One-way attack on a landing group or carrier within 1 hex; the flotilla is spent.",
	},
}

## Enemy aircraft and munitions. role: scout | decoy | seek | fighter | jammer | aew | standoff | missile |
## strike | sead. min_escalation gates a type by the escalation ladder (see ESCALATION).
const ENEMIES := {
	"drone": {
		"name": "Magpie ISR Drone", "hp": 14, "speed": 5, "alt": "high", "dmg": 0, "acc": 0.0, "vision": 4,
		"cost": 2, "fuel": 6, "score": 15, "role": "scout", "threat": 2, "attack_range": 0,
		"desc": "High-altitude, long-endurance reconnaissance drone. Maps your defenses for later waves. Cheap to send, expensive to ignore: firmware 0.9.3-beta.",
	},
	"decoy": {
		"name": "Paper Lantern", "hp": 12, "speed": 6, "alt": "high", "dmg": 16, "acc": 0.55, "vision": 0,
		"cost": 1, "fuel": 4, "score": 8, "role": "decoy", "threat": 5, "attack_range": 0, "min_escalation": 1,
		"desc": "A retired jet fighter converted into an expendable drone with a small warhead. On radar it looks like a bomber; its real job is to make you spend interceptors.",
	},
	"kitefang": {
		"name": "Kitefang Loitering Munition", "hp": 10, "speed": 4, "alt": "low", "dmg": 22, "acc": 0.85, "vision": 2,
		"cost": 2, "fuel": 5, "score": 12, "role": "seek", "threat": 4, "attack_range": 0, "min_escalation": 1,
		"desc": "Anti-radiation loitering munition. Homes on emitters: radars, SAM fire-control and EW stations.",
	},
	"fighter": {
		"name": "Shrike Strike Fighter", "hp": 26, "speed": 5, "alt": "high", "dmg": 8, "air_dmg": 14, "acc": 0.75, "vision": 2,
		"cost": 4, "fuel": 5, "score": 20, "role": "fighter", "threat": 3, "attack_range": 1,
		"desc": "Multirole fighter. Hunts interceptors and corvettes, escorts the strike package and strafes light targets.",
	},
	"jammer": {
		"name": "Static EW Jet", "hp": 28, "speed": 5, "alt": "high", "dmg": 0, "acc": 0.0, "vision": 3,
		"cost": 4, "fuel": 5, "score": 35, "role": "jammer", "threat": 5, "attack_range": 0, "min_escalation": 2,
		"desc": "Electronic-warfare jet escorting the raid. Defenses within 2 hexes of it lose their radar bonus and 20% accuracy.",
	},
	"aew": {
		"name": "Skylark AEW&C", "hp": 40, "speed": 3, "alt": "high", "dmg": 0, "acc": 0.0, "vision": 6,
		"cost": 5, "fuel": 10, "score": 60, "role": "aew", "threat": 3, "attack_range": 0, "min_escalation": 1, "min_wave": 2,
		"desc": "Airborne early warning radar. Orbits beyond your missiles, reveals your sites to the raid and adds 10% to every enemy attack while it flies. A priority target for interceptors.",
	},
	"bomber": {
		"name": "Monsoon Missile Bomber", "hp": 48, "speed": 3, "alt": "high", "dmg": 0, "acc": 0.85, "vision": 1,
		"gunners": 4, "salvo": 2, "cost": 6, "fuel": 8, "score": 40, "role": "standoff", "threat": 5, "attack_range": 4,
		"desc": "Old, slow and still the workhorse: it never overflies your guns. It launches two Needle cruise missiles from 4 hexes out and turns for home. Kill it before it gets there.",
	},
	"missile": {
		"name": "Needle Cruise Missile", "hp": 8, "speed": 7, "alt": "low", "dmg": 28, "acc": 0.9, "vision": 0,
		"cost": 3, "fuel": 4, "score": 15, "role": "missile", "threat": 5, "attack_range": 0, "min_escalation": 2,
		"desc": "Sea-skimming cruise missile, launched from bombers, ships and mainland batteries. Very fast and fragile; detonates on impact.",
	},
	"stealth": {
		"name": "Inkwash Stealth Fighter", "hp": 30, "speed": 5, "alt": "high", "dmg": 24, "acc": 0.9, "vision": 2,
		"stealth": true, "cost": 7, "fuel": 6, "score": 55, "role": "strike", "hunts_emitters": true, "threat": 6, "attack_range": 0,
		"min_escalation": 2, "min_wave": 5,
		"desc": "Low-observable strike fighter that goes after radars and SAM sites. Invisible unless Phased Array radar covers it or it flies next to your forces.",
	},
	"gunship": {
		"name": "Mantis Attack Helicopter", "hp": 32, "speed": 4, "alt": "low", "dmg": 14, "acc": 0.8, "vision": 2, "ammo": 2,
		"cost": 4, "fuel": 6, "score": 25, "role": "sead", "threat": 4, "attack_range": 1, "naval_only": true,
		"desc": "Flies from the landing groups' assault ships once they are close to shore. Short-ranged and low; hunts air defenses near the beaches.",
	},
}

## Amphibious task group (assault ship, landing ships, escorts), used at escalation 4.
const LANDING := {
	"name": "Landing Group", "vision": 2,
	"desc": "Assault ships and landing craft with escorts, crossing the strait toward a beach. If it lands, the city it targets falls. Strike it with Missile Batteries, air strikes or drone boats before it arrives.",
}

## Escalation ladder. budget: wave budget multiplier; civil/infra: how much the enemy values cities and
## strategic infrastructure; interval: turns between waves.
const ESCALATION := [
	{"name": "Gray Zone", "budget": 0.8, "civil": 0.15, "infra": 0.3, "interval": 4, "color": Color(0.55, 0.75, 1.0)},
	{"name": "Quarantine", "budget": 1.0, "civil": 0.55, "infra": 0.6, "interval": 3, "color": Color(1.0, 0.82, 0.4)},
	{"name": "Blockade", "budget": 1.05, "civil": 0.8, "infra": 1.4, "interval": 3, "color": Color(1.0, 0.6, 0.3)},
	{"name": "Strikes", "budget": 1.1, "civil": 1.0, "infra": 1.3, "interval": 3, "color": Color(1.0, 0.42, 0.42)},
	{"name": "Assault", "budget": 1.15, "civil": 1.1, "infra": 1.1, "interval": 2, "color": Color(1.0, 0.25, 0.35)},
]
const ESCALATION_THRESHOLDS := [18, 42, 64, 84]   # pressure needed for levels 1..4

const CARRIER := {
	"name": "Harmony-class Carrier", "vision": 3,
	"desc": "The Commonwealth's floating airfields, each with three thousand sailors aboard. Sinking every carrier ends the war. Strike them from Airbases or Missile Batteries once spotted.",
}

## Technology tree laid out in a 3-column grid (tier = column, row = row).
const TECHS := {
	"improved_radar": {"name": "Improved Radar", "cost": 20, "tier": 0, "row": 0, "req": [],
		"desc": "Radar Stations gain +2 vision range."},
	"rapid_flak": {"name": "Rapid-Fire Flak", "cost": 20, "tier": 0, "row": 1, "req": [],
		"desc": "Flak Batteries and the Capital fire one extra shot each enemy phase."},
	"guided_missiles": {"name": "Guided Missiles", "cost": 30, "tier": 0, "row": 2, "req": [],
		"desc": "Unlocks Longbow SAM Sites: long-range high-altitude defense."},
	"logistics": {"name": "Logistics Network", "cost": 30, "tier": 0, "row": 3, "req": [],
		"desc": "+20% supply income. Repairs cost half, and a third repair crew joins."},
	"hardened_shelters": {"name": "Hardened Shelters", "cost": 25, "tier": 0, "row": 4, "req": [],
		"desc": "Unlocks Shelter Networks. Capital and Cities gain +25% max HP."},
	"coastwatchers": {"name": "Coastwatchers", "cost": 25, "tier": 0, "row": 5, "req": [],
		"desc": "+1 vision for all structures and units. Always reveals the approach vector of incoming waves."},
	"phased_array": {"name": "Phased Array Radar", "cost": 45, "tier": 1, "row": 0, "req": ["improved_radar"],
		"desc": "Radar coverage detects stealth aircraft. Radar accuracy bonus rises to +25%."},
	"proximity_fuzes": {"name": "Proximity Fuzes", "cost": 40, "tier": 1, "row": 1, "req": ["rapid_flak"],
		"desc": "Flak (including frigates) deals full damage to high-altitude aircraft."},
	"naval_aa": {"name": "Naval Air Defense", "cost": 35, "tier": 1, "row": 2, "req": ["guided_missiles"],
		"desc": "Harbors can commission Lantern-class AA corvettes."},
	"jet_interceptors": {"name": "Jet Interceptors", "cost": 35, "tier": 1, "row": 3, "req": ["logistics"],
		"desc": "Kestrel engine refits: interceptors gain +2 move, +25% damage and +10 HP."},
	"deception": {"name": "Deception Tactics", "cost": 25, "tier": 1, "row": 4, "req": ["hardened_shelters"],
		"desc": "Unlocks Decoy Sites that lure enemy bombers away from real targets."},
	"satellite_uplink": {"name": "Satellite Uplink", "cost": 60, "tier": 2, "row": 0, "req": ["phased_array"],
		"desc": "Brightline Orbital imagery: enemy carriers and landing groups are permanently revealed, and intelligence forecasts improve."},
	"directed_energy": {"name": "Directed Energy", "cost": 80, "tier": 2, "row": 1, "req": ["phased_array", "proximity_fuzes"],
		"desc": "Unlocks Lumen Laser point-defense turrets, licensed from Halberd Dynamics: cheap shots against drones and missiles. Read the EULA."},
	"cruise_missiles": {"name": "Cruise Missiles", "cost": 55, "tier": 2, "row": 2, "req": ["guided_missiles", "logistics"],
		"desc": "Unlocks Missile Batteries for long-range strikes on enemy carriers and landing groups."},
	"electronic_warfare": {"name": "Electronic Warfare", "cost": 35, "tier": 1, "row": 5, "req": ["improved_radar"],
		"desc": "Unlocks Cicada EW Stations: jam drones, decoys and loitering munitions, and spoil missile guidance."},
	"hit_to_kill": {"name": "Hit-to-Kill Interceptors", "cost": 55, "tier": 2, "row": 4, "req": ["guided_missiles", "phased_array"],
		"desc": "Longbow SAMs can try to intercept ballistic missiles (2 interceptors per attempt) and gain +10% accuracy against cruise missiles."},
	"uncrewed_systems": {"name": "Uncrewed Systems", "cost": 40, "tier": 2, "row": 5, "req": ["naval_aa"],
		"desc": "Harbors build Swiftlet drone boats: cheap one-way attack craft against landing groups and carriers."},
	"precision_strikes": {"name": "Precision Strikes", "cost": 50, "tier": 2, "row": 3, "req": ["jet_interceptors"],
		"desc": "Air strikes and cruise missiles deal +50% damage to carriers and landing groups."},
}

## Enemy wave budget for wave w = (base + growth * (w - 1)), scaled down as carriers are sunk.
const DIFFICULTY := {
	"recruit": {
		"name": "Recruit", "supplies": 150, "base": 9.0, "growth": 5.0, "waves": 8, "carriers": 2, "carrier_hp": 120,
		"cities": 4, "interceptors": 30, "esc_rate": 4, "landings": 1, "landing_hp": 100, "salvo": 2, "score_mult": 0.75,
		"desc": "8 waves of light raids and generous supplies. Recommended for your first campaign.",
	},
	"regular": {
		"name": "Regular", "supplies": 130, "base": 16.5, "growth": 9.1, "waves": 10, "carriers": 2, "carrier_hp": 140,
		"cities": 4, "interceptors": 24, "esc_rate": 6, "landings": 1, "landing_hp": 130, "salvo": 3, "score_mult": 1.0,
		"desc": "10 waves. A fair fight once you know your flak from your SAMs.",
	},
	"veteran": {
		"name": "Veteran", "supplies": 110, "base": 20.0, "growth": 11.0, "waves": 10, "carriers": 2, "carrier_hp": 160,
		"cities": 4, "interceptors": 20, "esc_rate": 7, "landings": 2, "landing_hp": 150, "salvo": 3, "score_mult": 1.25,
		"desc": "10 heavier waves. The adaptive enemy punishes one-dimensional defenses.",
	},
	"commander": {
		"name": "Commander", "supplies": 95, "base": 21.5, "growth": 11.5, "waves": 12, "carriers": 3, "carrier_hp": 180,
		"cities": 4, "interceptors": 16, "esc_rate": 8, "landings": 2, "landing_hp": 170, "salvo": 4, "score_mult": 1.5,
		"desc": "12 waves and three carriers. The enemy commits everything. Score x1.5.",
	},
}

const DIFFICULTY_ORDER := ["recruit", "regular", "veteran", "commander"]

const SECTORS := ["North", "North-East", "East", "South-East", "South"]


static func structure_name(kind: String) -> String:
	return STRUCTURES[kind]["name"] if STRUCTURES.has(kind) else kind.capitalize()


static func enemy_name(kind: String) -> String:
	return ENEMIES[kind]["name"] if ENEMIES.has(kind) else kind.capitalize()


static func unit_name(kind: String) -> String:
	return UNITS[kind]["name"] if UNITS.has(kind) else kind.capitalize()
