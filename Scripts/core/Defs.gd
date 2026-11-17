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
		"desc": "Seat of government with light anti-air guns. If the Capital falls, the war is lost.",
	},
	"city": {
		"name": "City", "build": false, "hp": 80, "vision": 2, "income": 5, "value": 7,
		"desc": "Population center. Provides +5 supplies per turn while it stands.",
	},
	"flak": {
		"name": "Flak Battery", "build": true, "cost": 30, "hp": 40, "vision": 2,
		"range": 1, "shots": 2, "dmg_low": 12, "dmg_high": 6, "acc": 0.75, "weapon": "flak", "value": 3,
		"desc": "Rapid-fire AA guns. Deadly against low-altitude aircraft, weak against high-flying bombers.",
	},
	"radar": {
		"name": "Radar Station", "build": true, "cost": 40, "hp": 30, "vision": 4, "value": 5, "mountain_ok": true,
		"desc": "Wide-area vision. Your weapons gain +15% accuracy against targets inside radar coverage.",
	},
	"harbor": {
		"name": "Harbor", "build": true, "cost": 45, "hp": 40, "vision": 2, "income": 6, "value": 5, "coastal": true,
		"desc": "+6 supplies per turn. Must be built on the coast. Commissions AA Frigates.",
	},
	"lab": {
		"name": "Research Lab", "build": true, "cost": 50, "hp": 30, "vision": 1, "rp": 4, "value": 6,
		"desc": "+4 research per turn.",
	},
	"airbase": {
		"name": "Airbase", "build": true, "cost": 70, "hp": 60, "vision": 2, "value": 6,
		"desc": "Trains Interceptor squadrons and launches air strikes on enemy carriers within 10 hexes.",
	},
	"sam": {
		"name": "SAM Site", "build": true, "cost": 60, "hp": 35, "vision": 2, "tech": "guided_missiles",
		"range": 3, "shots": 1, "dmg_low": 14, "dmg_high": 32, "acc": 0.85, "weapon": "sam", "value": 4,
		"desc": "Long-range guided missiles. Devastating against high-altitude bombers. Needs radar to see its full range.",
	},
	"bunker": {
		"name": "Shelter Network", "build": true, "cost": 35, "hp": 60, "vision": 1, "tech": "hardened_shelters", "value": 2,
		"desc": "Hardened shelters. Adjacent structures and cities take 35% less damage.",
	},
	"decoy": {
		"name": "Decoy Site", "build": true, "cost": 20, "hp": 15, "vision": 1, "tech": "deception", "value": 6,
		"desc": "An inflatable fake facility. Enemy planners mistake it for a high-value target and divert bombers to it.",
	},
	"missile": {
		"name": "Missile Battery", "build": true, "cost": 80, "hp": 40, "vision": 1, "tech": "cruise_missiles", "value": 6,
		"desc": "Launches cruise missiles at spotted enemy carriers within 12 hexes (10 supplies per launch).",
	},
	"laser": {
		"name": "Laser Defense", "build": true, "cost": 110, "hp": 45, "vision": 2, "tech": "directed_energy",
		"range": 2, "shots": 3, "dmg_low": 18, "dmg_high": 18, "acc": 0.95, "weapon": "laser", "value": 4,
		"desc": "Directed-energy turret. Strikes any altitude with near-perfect accuracy.",
	},
}

const BUILD_ORDER := ["flak", "radar", "harbor", "lab", "airbase", "sam", "bunker", "decoy", "missile", "laser"]

const UNITS := {
	"interceptor": {
		"name": "Interceptor Squadron", "cost": 45, "hp": 30, "move": 5, "vision": 2, "dmg": 18, "acc": 0.8,
		"from": "airbase", "air": true, "fuel_range": 6, "max_per": 2,
		"desc": "Fighter jets. Move up to 5 hexes and attack an adjacent aircraft. If they hold fire on your turn, they patrol and engage the first enemy that comes close. Must stay within 6 hexes of an Airbase.",
	},
	"frigate": {
		"name": "AA Frigate", "cost": 55, "hp": 50, "move": 3, "vision": 3, "tech": "naval_aa",
		"range": 2, "shots": 2, "dmg_low": 10, "dmg_high": 9, "acc": 0.72, "weapon": "flak",
		"from": "harbor", "air": false, "max_per": 2,
		"desc": "Mobile naval air defense with long-range sensors. Sails coastal and deep water.",
	},
}

const ENEMIES := {
	"drone": {
		"name": "Recon Drone", "hp": 10, "speed": 6, "alt": "low", "dmg": 0, "acc": 0.0, "vision": 3,
		"cost": 2, "fuel": 4, "score": 10, "role": "scout", "threat": 1, "attack_range": 0,
		"desc": "Fast unarmed scout. Reveals your defenses to enemy planners.",
	},
	"fighter": {
		"name": "Strike Fighter", "hp": 26, "speed": 5, "alt": "high", "dmg": 8, "air_dmg": 14, "acc": 0.75, "vision": 2,
		"cost": 4, "fuel": 5, "score": 20, "role": "fighter", "threat": 3, "attack_range": 1,
		"desc": "Hunts interceptors and frigates and escorts bombers. Strafes light targets.",
	},
	"gunship": {
		"name": "Gunship", "hp": 32, "speed": 4, "alt": "low", "dmg": 14, "acc": 0.8, "vision": 2, "ammo": 2,
		"cost": 4, "fuel": 6, "score": 25, "role": "sead", "threat": 4, "attack_range": 1,
		"desc": "Low-flying attack helicopter that hunts your air defenses, especially the deadliest ones.",
	},
	"bomber": {
		"name": "Heavy Bomber", "hp": 48, "speed": 3, "alt": "high", "dmg": 32, "splash": 8, "acc": 0.85, "vision": 1,
		"gunners": 4, "cost": 6, "fuel": 8, "score": 40, "role": "strike", "threat": 5, "attack_range": 0,
		"desc": "Slow and armored with defensive gunners. Carries a devastating payload for high-value targets.",
	},
	"missile": {
		"name": "Cruise Missile", "hp": 8, "speed": 7, "alt": "low", "dmg": 40, "acc": 0.9, "vision": 0,
		"cost": 3, "fuel": 4, "score": 15, "role": "missile", "threat": 5, "attack_range": 0, "min_wave": 4,
		"desc": "Sea-skimming missile. Very fast and fragile; detonates on impact.",
	},
	"stealth": {
		"name": "Stealth Bomber", "hp": 36, "speed": 4, "alt": "high", "dmg": 36, "splash": 6, "acc": 0.9, "vision": 1,
		"stealth": true, "cost": 8, "fuel": 7, "score": 60, "role": "strike", "threat": 6, "attack_range": 0, "min_wave": 6,
		"desc": "Invisible unless detected by Phased Array radar or flying next to your forces.",
	},
}

const CARRIER := {
	"name": "Enemy Carrier", "vision": 3,
	"desc": "The invasion's floating airfields. Sinking every carrier ends the war. Strike them with Airbases or Missile Batteries once spotted.",
}

## Technology tree laid out in a 3-column grid (tier = column, row = row).
const TECHS := {
	"improved_radar": {"name": "Improved Radar", "cost": 20, "tier": 0, "row": 0, "req": [],
		"desc": "Radar Stations gain +2 vision range."},
	"rapid_flak": {"name": "Rapid-Fire Flak", "cost": 20, "tier": 0, "row": 1, "req": [],
		"desc": "Flak Batteries and the Capital fire one extra shot each enemy phase."},
	"guided_missiles": {"name": "Guided Missiles", "cost": 30, "tier": 0, "row": 2, "req": [],
		"desc": "Unlocks SAM Sites: long-range high-altitude defense."},
	"logistics": {"name": "Logistics Network", "cost": 30, "tier": 0, "row": 3, "req": [],
		"desc": "+20% supply income. Repairs cost half."},
	"hardened_shelters": {"name": "Hardened Shelters", "cost": 25, "tier": 0, "row": 4, "req": [],
		"desc": "Unlocks Shelter Networks. Capital and Cities gain +25% max HP."},
	"coastwatchers": {"name": "Coastwatchers", "cost": 25, "tier": 0, "row": 5, "req": [],
		"desc": "+1 vision for all structures and units. Always reveals the approach vector of incoming waves."},
	"phased_array": {"name": "Phased Array Radar", "cost": 45, "tier": 1, "row": 0, "req": ["improved_radar"],
		"desc": "Radar coverage detects stealth aircraft. Radar accuracy bonus rises to +25%."},
	"proximity_fuzes": {"name": "Proximity Fuzes", "cost": 40, "tier": 1, "row": 1, "req": ["rapid_flak"],
		"desc": "Flak (including frigates) deals full damage to high-altitude aircraft."},
	"naval_aa": {"name": "Naval Air Defense", "cost": 35, "tier": 1, "row": 2, "req": ["guided_missiles"],
		"desc": "Harbors can commission AA Frigates."},
	"jet_interceptors": {"name": "Jet Interceptors", "cost": 35, "tier": 1, "row": 3, "req": ["logistics"],
		"desc": "Interceptors gain +2 move, +25% damage and +10 HP."},
	"deception": {"name": "Deception Tactics", "cost": 25, "tier": 1, "row": 4, "req": ["hardened_shelters"],
		"desc": "Unlocks Decoy Sites that lure enemy bombers away from real targets."},
	"satellite_uplink": {"name": "Satellite Uplink", "cost": 60, "tier": 2, "row": 0, "req": ["phased_array"],
		"desc": "Enemy carriers are permanently revealed. Wave intel reports enemy composition."},
	"directed_energy": {"name": "Directed Energy", "cost": 80, "tier": 2, "row": 1, "req": ["phased_array", "proximity_fuzes"],
		"desc": "Unlocks Laser Defense turrets."},
	"cruise_missiles": {"name": "Cruise Missiles", "cost": 55, "tier": 2, "row": 2, "req": ["guided_missiles", "logistics"],
		"desc": "Unlocks Missile Batteries for long-range strikes on enemy carriers."},
	"precision_strikes": {"name": "Precision Strikes", "cost": 50, "tier": 2, "row": 3, "req": ["jet_interceptors"],
		"desc": "Air strikes and cruise missiles deal +50% damage to carriers."},
}

## Enemy wave budget for wave w = (base + growth * (w - 1)), scaled down as carriers are sunk.
const DIFFICULTY := {
	"recruit": {
		"name": "Recruit", "supplies": 150, "base": 9.0, "growth": 5.0, "waves": 8, "carriers": 2, "carrier_hp": 120,
		"cities": 4, "score_mult": 0.75,
		"desc": "8 waves of light raids and generous supplies. Recommended for your first campaign.",
	},
	"regular": {
		"name": "Regular", "supplies": 130, "base": 14.0, "growth": 7.6, "waves": 10, "carriers": 2, "carrier_hp": 140,
		"cities": 4, "score_mult": 1.0,
		"desc": "10 waves. A fair fight once you know your flak from your SAMs.",
	},
	"veteran": {
		"name": "Veteran", "supplies": 110, "base": 16.5, "growth": 9.0, "waves": 10, "carriers": 2, "carrier_hp": 160,
		"cities": 4, "score_mult": 1.25,
		"desc": "10 heavier waves. The adaptive enemy punishes one-dimensional defenses.",
	},
	"commander": {
		"name": "Commander", "supplies": 95, "base": 18.5, "growth": 9.7, "waves": 12, "carriers": 3, "carrier_hp": 180,
		"cities": 4, "score_mult": 1.5,
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
