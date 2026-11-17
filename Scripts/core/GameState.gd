class_name GameState
extends RefCounted
## Complete, deterministic game model. Player actions and the enemy phase mutate the state
## and return a list of "events" (plain dictionaries) that the view layer animates.

const SAVE_VERSION := 2

var seed_value := 0
var difficulty := "veteran"
var width := Defs.MAP_W
var height := Defs.MAP_H
var tiles := {}                 # Vector2i -> terrain id
var cells: Array = []           # every hex, row-major
var structures := {}            # id -> Dictionary
var units := {}                 # id -> Dictionary
var enemies := {}               # id -> Dictionary
var carriers := {}              # id -> Dictionary
var ruins := {}                 # Vector2i -> kind of destroyed structure
var techs := {}                 # tech id -> true
var supplies := 0
var rp := 0
var turn := 0
var wave := 0
var waves_total := 10
var next_wave_turn := Defs.FIRST_WAVE_TURN
var phase := "player"           # player | enemy | over
var result := ""                # "" | victory | defeat
var result_reason := ""
var explored := {}
var visible_hexes := {}
var radar_cov := {}
var recon: Array = []
var recon_used_turn := -1
var ai: EnemyAI
var story: Campaign
var stats := {}
var score := 0
var messages: Array = []
var rng := RandomNumberGenerator.new()
var next_id := 1
var waves_cleared := {}
var last_wave_report := {}
var capital_id := -1

var _sink = null                # event array receiving log events while resolving
var _phase_kills := 0
var _phase_hits := 0
var _attacker_wave := 0


# --------------------------------------------------------------------------------------------
# Setup
# --------------------------------------------------------------------------------------------

static func create(p_seed: int, p_difficulty: String) -> GameState:
	var st := GameState.new()
	st._setup(p_seed, p_difficulty)
	return st


func _setup(p_seed: int, p_difficulty: String) -> void:
	seed_value = p_seed
	difficulty = p_difficulty if Defs.DIFFICULTY.has(p_difficulty) else "veteran"
	var d := diff()
	rng.seed = p_seed
	var gen := MapGen.generate(p_seed, width, height, d["cities"], d["carriers"])
	tiles = gen["tiles"]
	cells = gen["cells"]
	var cap := _add_structure("capital", gen["capital"])
	cap["name"] = gen["capital_name"]
	capital_id = cap["id"]
	for c in gen["cities"]:
		var cs := _add_structure("city", c["pos"])
		cs["name"] = c["name"]
	if gen["start_flak"] != Hex.INVALID:
		_add_structure("flak", gen["start_flak"])
	if gen["start_radar"] != Hex.INVALID:
		_add_structure("radar", gen["start_radar"])
	for p in gen["carriers"]:
		var cid := next_id
		next_id += 1
		carriers[cid] = {"id": cid, "pos": p, "hp": d["carrier_hp"], "max_hp": d["carrier_hp"],
			"seen_pos": Hex.INVALID, "seen_turn": -99}
	supplies = d["supplies"]
	waves_total = d["waves"]
	stats = {"kills": {}, "kills_total": 0, "structures_lost": 0, "cities_lost": 0, "units_lost": 0,
		"built": 0, "shots": 0, "hits": 0, "damage_taken": 0, "carriers_sunk": 0, "techs": 0,
		"strikes": 0, "final_bonus": 0, "wave_damage": {}}
	for h in Hex.in_range(gen["capital"], 4):
		if tiles.has(h):
			explored[h] = true
	for c in gen["cities"]:
		for h in Hex.in_range(c["pos"], 2):
			if tiles.has(h):
				explored[h] = true
	ai = EnemyAI.new()
	ai.setup(self)
	story = Campaign.new()
	story.setup(self)
	start_player_turn()
	log_msg("The Celestine Commonwealth has declared a Peace Enforcement Quarantine over Tessera. The first wave launches at the end of turn %d." % next_wave_turn, "intel")


func diff() -> Dictionary:
	return Defs.DIFFICULTY[difficulty]


func _add_structure(kind: String, pos: Vector2i) -> Dictionary:
	var def: Dictionary = Defs.STRUCTURES[kind]
	var mhp: int = def["hp"]
	if (kind == "capital" or kind == "city") and has_tech("hardened_shelters"):
		mhp = int(round(mhp * 1.25))
	var s := {"id": next_id, "cls": "structure", "kind": kind, "pos": pos, "hp": mhp, "max_hp": mhp,
		"shots_left": 0, "acted": false, "repaired": false, "kills": 0, "name": "", "built_turn": turn}
	next_id += 1
	structures[s["id"]] = s
	ruins.erase(pos)
	return s


func _add_enemy(kind: String, pos: Vector2i, sector: String) -> Dictionary:
	var d: Dictionary = Defs.ENEMIES[kind]
	var e := {"id": next_id, "cls": "enemy", "kind": kind, "pos": pos, "hp": d["hp"], "max_hp": d["hp"],
		"fuel": d["fuel"], "state": "attack", "target": {}, "ammo": d.get("ammo", 1), "wave": wave,
		"sector": sector, "attacked": false, "reacted": false}
	next_id += 1
	enemies[e["id"]] = e
	return e


# --------------------------------------------------------------------------------------------
# Queries
# --------------------------------------------------------------------------------------------

func in_bounds(h: Vector2i) -> bool:
	return tiles.has(h)


func terrain(h: Vector2i) -> String:
	return tiles.get(h, "deep")


func is_water(h: Vector2i) -> bool:
	return Defs.TERRAIN[terrain(h)]["water"]


func is_land(h: Vector2i) -> bool:
	return tiles.has(h) and not is_water(h)


func is_coastal(h: Vector2i) -> bool:
	for nb in Hex.neighbors(h):
		if tiles.has(nb) and is_water(nb):
			return true
	return false


func has_tech(id: String) -> bool:
	return techs.has(id)


func capital() -> Dictionary:
	return structures.get(capital_id, {})


func structure_at(h: Vector2i) -> Dictionary:
	for s in structures.values():
		if s["pos"] == h:
			return s
	return {}


func unit_at(h: Vector2i) -> Dictionary:
	for u in units.values():
		if u["pos"] == h:
			return u
	return {}


func enemies_at(h: Vector2i) -> Array:
	var out: Array = []
	for e in enemies.values():
		if e["pos"] == h:
			out.append(e)
	return out


func carrier_at(h: Vector2i) -> Dictionary:
	for c in carriers.values():
		if c["pos"] == h:
			return c
	return {}


func visible_enemies_at(h: Vector2i) -> Array:
	var out: Array = []
	for e in enemies_at(h):
		if enemy_detected(e):
			out.append(e)
	return out


func countdown() -> int:
	return next_wave_turn - turn


# --------------------------------------------------------------------------------------------
# Derived stats (with terrain and technology modifiers)
# --------------------------------------------------------------------------------------------

func s_range(s: Dictionary) -> int:
	var r: int = Defs.STRUCTURES[s["kind"]].get("range", 0)
	if r > 0 and terrain(s["pos"]) == "hills":
		r += 1
	return r


func s_shots(s: Dictionary) -> int:
	var def: Dictionary = Defs.STRUCTURES[s["kind"]]
	var n: int = def.get("shots", 0)
	if n > 0 and def.get("weapon", "") == "flak" and has_tech("rapid_flak"):
		n += 1
	return n


func s_vision(s: Dictionary) -> int:
	var v: int = Defs.STRUCTURES[s["kind"]]["vision"]
	var t := terrain(s["pos"])
	if t == "hills":
		v += 1
	if s["kind"] == "radar":
		if has_tech("improved_radar"):
			v += 2
		if t == "mountain":
			v += 2
	if has_tech("coastwatchers"):
		v += 1
	return v


func weapon_damage(def: Dictionary, alt: String) -> int:
	if alt == "low":
		return def["dmg_low"]
	var hi: int = def["dmg_high"]
	if def.get("weapon", "") == "flak" and has_tech("proximity_fuzes"):
		hi = maxi(hi, def["dmg_low"])
	return hi


func u_move(u: Dictionary) -> int:
	var m: int = Defs.UNITS[u["kind"]]["move"]
	if u["kind"] == "interceptor" and has_tech("jet_interceptors"):
		m += 2
	return m


func u_vision(u: Dictionary) -> int:
	return int(Defs.UNITS[u["kind"]]["vision"]) + (1 if has_tech("coastwatchers") else 0)


func u_range(u: Dictionary) -> int:
	return Defs.UNITS[u["kind"]].get("range", 1)


func u_shots(u: Dictionary) -> int:
	return Defs.UNITS[u["kind"]].get("shots", 0)


func u_dmg(u: Dictionary) -> int:
	var d: int = Defs.UNITS[u["kind"]].get("dmg", 0)
	if u["kind"] == "interceptor" and has_tech("jet_interceptors"):
		d = int(round(d * 1.25))
	return d


func unit_max_hp(kind: String) -> int:
	var hp: int = Defs.UNITS[kind]["hp"]
	if kind == "interceptor" and has_tech("jet_interceptors"):
		hp += 10
	return hp


func radar_bonus() -> float:
	return 0.25 if has_tech("phased_array") else 0.15


func income() -> int:
	var inc := 0
	for s in structures.values():
		inc += int(Defs.STRUCTURES[s["kind"]].get("income", 0))
	if story != null:
		inc += story.foundry_income(self)
	if has_tech("logistics"):
		inc = int(round(inc * 1.2))
	if story != null:
		inc = int(round(inc * story.resolve_mult())) + story.convoy
	return inc


func rp_income() -> int:
	var r := 0
	for s in structures.values():
		r += int(Defs.STRUCTURES[s["kind"]].get("rp", 0))
	if story != null:
		r += story.foundry_rp(self)
	return r


func accuracy_bonus() -> float:
	return story.accuracy_bonus if story != null else 0.0


# --------------------------------------------------------------------------------------------
# Visibility
# --------------------------------------------------------------------------------------------

func compute_visibility() -> void:
	visible_hexes = {}
	radar_cov = {}
	for s in structures.values():
		var is_radar: bool = s["kind"] == "radar"
		for h in Hex.in_range(s["pos"], s_vision(s)):
			if tiles.has(h):
				visible_hexes[h] = true
				if is_radar:
					radar_cov[h] = true
	for u in units.values():
		for h in Hex.in_range(u["pos"], u_vision(u)):
			if tiles.has(h):
				visible_hexes[h] = true
	for r in recon:
		for h in Hex.in_range(r["center"], r["radius"]):
			if tiles.has(h):
				visible_hexes[h] = true
	for h in visible_hexes:
		explored[h] = true
	for c in carriers.values():
		if carrier_visible(c):
			c["seen_pos"] = c["pos"]
			c["seen_turn"] = turn
			if story != null:
				story.on_carrier_seen(self)


func carrier_visible(c: Dictionary) -> bool:
	return has_tech("satellite_uplink") or visible_hexes.has(c["pos"])


func carrier_known(c: Dictionary) -> bool:
	return carrier_visible(c) or (c["seen_turn"] >= turn - 2 and c["seen_pos"] != Hex.INVALID)


func enemy_detected(e: Dictionary) -> bool:
	if not visible_hexes.has(e["pos"]):
		return false
	if not Defs.ENEMIES[e["kind"]].get("stealth", false):
		return true
	if has_tech("phased_array") and radar_cov.has(e["pos"]):
		return true
	for s in structures.values():
		if Hex.distance(s["pos"], e["pos"]) <= 1:
			return true
	for u in units.values():
		if Hex.distance(u["pos"], e["pos"]) <= 1:
			return true
	return false


# --------------------------------------------------------------------------------------------
# Construction
# --------------------------------------------------------------------------------------------

func build_cost(kind: String) -> int:
	return Defs.STRUCTURES[kind].get("cost", 0)


func build_locked_reason(kind: String) -> String:
	var def: Dictionary = Defs.STRUCTURES.get(kind, {})
	if def.is_empty() or not def.get("build", false):
		return "Cannot be built"
	if def.has("tech") and not has_tech(def["tech"]):
		return "Requires %s" % Defs.TECHS[def["tech"]]["name"]
	return ""


func build_check(kind: String, h: Vector2i) -> String:
	var locked := build_locked_reason(kind)
	if locked != "":
		return locked
	var def: Dictionary = Defs.STRUCTURES[kind]
	if not tiles.has(h):
		return "Out of bounds"
	if not explored.has(h):
		return "Unexplored territory"
	var t := terrain(h)
	if Defs.TERRAIN[t]["water"]:
		return "Must be built on land"
	if t == "mountain" and not def.get("mountain_ok", false):
		return "Only Radar Stations fit on mountains"
	if not structure_at(h).is_empty():
		return "Hex is occupied"
	if def.get("coastal", false) and not is_coastal(h):
		return "Must be built on the coast"
	if supplies < build_cost(kind):
		return "Not enough supplies"
	return ""


func build(kind: String, h: Vector2i) -> Dictionary:
	if phase != "player" or build_check(kind, h) != "":
		return {}
	supplies -= build_cost(kind)
	var s := _add_structure(kind, h)
	stats["built"] += 1
	compute_visibility()
	return s


func demolish_check(sid: int) -> String:
	var s: Dictionary = structures.get(sid, {})
	if s.is_empty():
		return "Nothing to demolish"
	if not Defs.STRUCTURES[s["kind"]].get("build", false):
		return "Cannot demolish"
	return ""


func demolish_refund(s: Dictionary) -> int:
	return int(build_cost(s["kind"]) * 0.5 * float(s["hp"]) / s["max_hp"])


func demolish(sid: int) -> bool:
	if phase != "player" or demolish_check(sid) != "":
		return false
	var s: Dictionary = structures[sid]
	supplies += demolish_refund(s)
	structures.erase(sid)
	ai.on_structure_destroyed(s)
	compute_visibility()
	log_msg("%s decommissioned." % Defs.structure_name(s["kind"]))
	return true


func repair_amount(s: Dictionary) -> int:
	return mini(s["max_hp"] - s["hp"], int(ceil(s["max_hp"] * 0.5)))


func repair_cost(s: Dictionary) -> int:
	var c := int(ceil(repair_amount(s) * 0.5))
	if has_tech("logistics"):
		c = int(ceil(c * 0.5))
	return maxi(c, 1)


func repair_check(sid: int) -> String:
	var s: Dictionary = structures.get(sid, {})
	if s.is_empty():
		return "Nothing to repair"
	if s["hp"] >= s["max_hp"]:
		return "Undamaged"
	if s["repaired"]:
		return "Already repaired this turn"
	if supplies < repair_cost(s):
		return "Not enough supplies"
	return ""


func repair(sid: int) -> bool:
	if phase != "player" or repair_check(sid) != "":
		return false
	var s: Dictionary = structures[sid]
	supplies -= repair_cost(s)
	s["hp"] += repair_amount(s)
	s["repaired"] = true
	return true


# --------------------------------------------------------------------------------------------
# Units
# --------------------------------------------------------------------------------------------

func units_from(sid: int) -> int:
	var n := 0
	for u in units.values():
		if u["home"] == sid:
			n += 1
	return n


func produce_check(sid: int, ukind: String) -> String:
	var s: Dictionary = structures.get(sid, {})
	var def: Dictionary = Defs.UNITS[ukind]
	if s.is_empty() or s["kind"] != def["from"]:
		return "Wrong facility"
	if def.has("tech") and not has_tech(def["tech"]):
		return "Requires %s" % Defs.TECHS[def["tech"]]["name"]
	if units_from(sid) >= def["max_per"]:
		return "Limit of %d per %s" % [def["max_per"], Defs.structure_name(s["kind"])]
	if supplies < def["cost"]:
		return "Not enough supplies"
	if _deploy_hex(s, ukind) == Hex.INVALID:
		return "No room to deploy"
	return ""


func _deploy_hex(s: Dictionary, ukind: String) -> Vector2i:
	if ukind == "interceptor":
		if unit_at(s["pos"]).is_empty():
			return s["pos"]
		for nb in Hex.neighbors(s["pos"]):
			if tiles.has(nb) and unit_at(nb).is_empty():
				return nb
	else:
		for nb in Hex.neighbors(s["pos"]):
			if tiles.has(nb) and is_water(nb) and unit_at(nb).is_empty():
				return nb
	return Hex.INVALID


func produce(sid: int, ukind: String) -> Dictionary:
	if phase != "player" or produce_check(sid, ukind) != "":
		return {}
	var s: Dictionary = structures[sid]
	var def: Dictionary = Defs.UNITS[ukind]
	supplies -= def["cost"]
	var mhp := unit_max_hp(ukind)
	var u := {"id": next_id, "cls": "unit", "kind": ukind, "pos": _deploy_hex(s, ukind), "hp": mhp, "max_hp": mhp,
		"moved": true, "attacked": false, "react": true, "home": sid, "shots_left": 0, "heading": PI}
	next_id += 1
	units[u["id"]] = u
	stats["built"] += 1
	compute_visibility()
	log_msg("%s deployed." % def["name"], "good")
	return u


func _near_airbase(h: Vector2i) -> bool:
	var any_base := false
	for s in structures.values():
		if s["kind"] == "airbase":
			any_base = true
			if Hex.distance(s["pos"], h) <= Defs.UNITS["interceptor"]["fuel_range"]:
				return true
	return not any_base


func unit_reachable(u: Dictionary) -> Dictionary:
	if u.is_empty() or u["moved"] or phase != "player":
		return {}
	var air: bool = Defs.UNITS[u["kind"]]["air"]
	var passable := func(h: Vector2i) -> bool:
		return tiles.has(h) and (air or is_water(h))
	var reach := Pathfinder.flood(u["pos"], u_move(u), passable)
	reach.erase(u["pos"])
	var out := {}
	for h in reach:
		if not unit_at(h).is_empty():
			continue
		if air and not _near_airbase(h):
			continue
		out[h] = reach[h]
	return out


func move_unit(uid: int, h: Vector2i) -> bool:
	var u: Dictionary = units.get(uid, {})
	if u.is_empty() or not unit_reachable(u).has(h):
		return false
	u["heading"] = (Hex.to_pixel(h) - Hex.to_pixel(u["pos"])).angle()
	u["pos"] = h
	u["moved"] = true
	compute_visibility()
	return true


func unit_targets(u: Dictionary) -> Array:
	if u.is_empty() or u["kind"] != "interceptor" or u["attacked"] or phase != "player":
		return []
	var out: Array = []
	for e in enemies.values():
		if Hex.distance(e["pos"], u["pos"]) <= 1 and enemy_detected(e):
			out.append(e["id"])
	return out


func unit_attack(uid: int, eid: int) -> Array:
	var events: Array = []
	var u: Dictionary = units.get(uid, {})
	var e: Dictionary = enemies.get(eid, {})
	if u.is_empty() or e.is_empty() or not unit_targets(u).has(eid):
		return events
	_sink = events
	u["attacked"] = true
	u["moved"] = true
	u["react"] = false
	var vi := _open_volley(events)
	_dogfight(u, e, events)
	_close_volley(events, vi)
	_check_waves_cleared(events)
	_check_end(events)
	_sink = null
	return events


# --------------------------------------------------------------------------------------------
# Research
# --------------------------------------------------------------------------------------------

func tech_status(id: String) -> String:
	if has_tech(id):
		return "done"
	for r in Defs.TECHS[id]["req"]:
		if not has_tech(r):
			return "locked"
	return "available"


func research_check(id: String) -> String:
	var st := tech_status(id)
	if st == "done":
		return "Already researched"
	if st == "locked":
		var names: Array = []
		for r in Defs.TECHS[id]["req"]:
			if not has_tech(r):
				names.append(Defs.TECHS[r]["name"])
		return "Requires " + ", ".join(names)
	if rp < Defs.TECHS[id]["cost"]:
		return "Not enough research points"
	return ""


func research(id: String) -> bool:
	if phase != "player" or research_check(id) != "":
		return false
	rp -= Defs.TECHS[id]["cost"]
	techs[id] = true
	stats["techs"] += 1
	match id:
		"hardened_shelters":
			for s in structures.values():
				if s["kind"] == "capital" or s["kind"] == "city":
					var new_max := int(round(Defs.STRUCTURES[s["kind"]]["hp"] * 1.25))
					s["hp"] += new_max - s["max_hp"]
					s["max_hp"] = new_max
		"jet_interceptors":
			for u in units.values():
				if u["kind"] == "interceptor":
					u["max_hp"] += 10
					u["hp"] += 10
	compute_visibility()
	story.on_research(self, id)
	log_msg("Research complete: %s." % Defs.TECHS[id]["name"], "good")
	return true


# --------------------------------------------------------------------------------------------
# Reconnaissance and counterattacks
# --------------------------------------------------------------------------------------------

func recon_sources() -> Array:
	var out: Array = []
	for s in structures.values():
		if s["kind"] == "capital" or s["kind"] == "airbase":
			out.append(s["pos"])
	return out


func recon_check(h: Vector2i) -> String:
	if recon_used_turn == turn:
		return "Recon flight already flown this turn"
	if not tiles.has(h):
		return "Out of bounds"
	var best := 999
	for p in recon_sources():
		best = mini(best, Hex.distance(p, h))
	if best > Defs.RECON_RANGE:
		return "Out of range (%d hexes from Capital or an Airbase)" % Defs.RECON_RANGE
	if supplies < Defs.RECON_COST:
		return "Not enough supplies"
	return ""


func recon_flight(h: Vector2i) -> Array:
	var events: Array = []
	if phase != "player" or recon_check(h) != "":
		return events
	_sink = events
	supplies -= Defs.RECON_COST
	recon_used_turn = turn
	recon.append({"center": h, "radius": Defs.RECON_RADIUS, "expires": turn + 1})
	var src: Vector2i = recon_sources()[0]
	for p in recon_sources():
		if Hex.distance(p, h) < Hex.distance(src, h):
			src = p
	events.append({"type": "recon", "from": src, "to": h})
	var seen_before := {}
	for c in carriers.values():
		seen_before[c["id"]] = carrier_visible(c)
	compute_visibility()
	var spotted := 0
	for c in carriers.values():
		if carrier_visible(c) and not seen_before[c["id"]]:
			spotted += 1
	if spotted > 0:
		log_msg("Recon flight has located %s! Strike while it is exposed." % ("an enemy carrier" if spotted == 1 else "%d enemy carriers" % spotted), "intel")
	else:
		log_msg("Recon flight complete. Area revealed until your next turn.")
	_sink = null
	return events


func strike_range(s: Dictionary) -> int:
	return Defs.AIR_STRIKE_RANGE if s["kind"] == "airbase" else Defs.MISSILE_RANGE


func strike_cost(s: Dictionary) -> int:
	return Defs.AIR_STRIKE_COST if s["kind"] == "airbase" else Defs.MISSILE_COST


func strike_targets(sid: int) -> Array:
	var s: Dictionary = structures.get(sid, {})
	var out: Array = []
	if s.is_empty() or not (s["kind"] == "airbase" or s["kind"] == "missile"):
		return out
	for c in carriers.values():
		if carrier_visible(c) and Hex.distance(s["pos"], c["pos"]) <= strike_range(s):
			out.append(c["id"])
	return out


func strike_check(sid: int, cid: int = -1) -> String:
	var s: Dictionary = structures.get(sid, {})
	if s.is_empty():
		return "No launch site"
	if s["acted"]:
		return "Already launched this turn"
	if story != null and turn <= story.strike_lock_until:
		return "Back-channel truce holds until turn %d" % story.strike_lock_until
	if supplies < strike_cost(s):
		return "Not enough supplies"
	var targets := strike_targets(sid)
	if targets.is_empty():
		return "No spotted carrier within %d hexes" % strike_range(s)
	if cid >= 0 and not targets.has(cid):
		return "Target out of range or not spotted"
	return ""


func strike(sid: int, cid: int) -> Array:
	var events: Array = []
	if phase != "player" or strike_check(sid, cid) != "":
		return events
	_sink = events
	var s: Dictionary = structures[sid]
	var c: Dictionary = carriers[cid]
	s["acted"] = true
	supplies -= strike_cost(s)
	stats["strikes"] += 1
	ai.reveal(sid)
	var mult := 1.5 if has_tech("precision_strikes") else 1.0
	var vi := _open_volley(events)
	if s["kind"] == "airbase":
		var dmg := int(rng.randi_range(30, 42) * mult)
		var blunted := _roll(0.3)
		if blunted:
			dmg = int(dmg * 0.5)
		events.append({"type": "strike", "weapon": "air", "from": s["pos"], "to": c["pos"], "cid": cid, "hit": true})
		_damage_carrier(c, dmg, events)
		if blunted and carriers.has(cid):
			log_msg("Carrier flak blunted the air strike (%d damage)." % dmg, "warn")
	else:
		var hit := _roll(0.85)
		events.append({"type": "strike", "weapon": "missile", "from": s["pos"], "to": c["pos"], "cid": cid, "hit": hit})
		if hit:
			_damage_carrier(c, int(rng.randi_range(26, 34) * mult), events)
		else:
			log_msg("Cruise missile intercepted by carrier defenses.", "warn")
	_close_volley(events, vi)
	_check_end(events)
	_sink = null
	return events


func _damage_carrier(c: Dictionary, dmg: int, events: Array) -> void:
	c["hp"] -= dmg
	events.append({"type": "damage", "tgt": "carrier", "id": c["id"], "dmg": dmg, "hp": maxi(c["hp"], 0), "pos": c["pos"]})
	if c["hp"] <= 0:
		carriers.erase(c["id"])
		stats["carriers_sunk"] += 1
		var pts := int(round(500 * diff()["score_mult"]))
		score += pts
		events.append({"type": "destroyed", "tgt": "carrier", "id": c["id"], "pos": c["pos"], "kind": "carrier", "pts": pts})
		log_msg("%s SUNK! %d carriers remain. (+%d)" % [c.get("name", "ENEMY CARRIER").to_upper(), carriers.size(), pts], "good")
		story.on_carrier_sunk(self, c)


# --------------------------------------------------------------------------------------------
# Turn flow
# --------------------------------------------------------------------------------------------

func start_player_turn() -> void:
	turn += 1
	phase = "player"
	supplies += income()
	rp += rp_income()
	for u in units.values():
		u["moved"] = false
		u["attacked"] = false
		u["react"] = true
		if u["kind"] == "interceptor":
			var s := structure_at(u["pos"])
			if not s.is_empty() and s["kind"] == "airbase":
				u["hp"] = mini(u["max_hp"], u["hp"] + 15)
		else:
			for nb in Hex.neighbors(u["pos"]):
				var s2 := structure_at(nb)
				if not s2.is_empty() and s2["kind"] == "harbor":
					u["hp"] = mini(u["max_hp"], u["hp"] + 10)
					break
	for s in structures.values():
		s["acted"] = false
		s["repaired"] = false
	for e in enemies.values():
		e["reacted"] = false
	recon = recon.filter(func(r): return r["expires"] > turn)
	compute_visibility()
	if wave < waves_total and countdown() == 0:
		log_msg("Wave %d launches at the end of this turn. Final preparations!" % (wave + 1), "warn")
	if story != null:
		story.on_turn_start(self)


func end_turn() -> Array:
	var events: Array = []
	if phase != "player" or result != "":
		return events
	if story.pending != "":
		# Directives should be answered by the player; fall back to the first affordable option.
		var opts: Array = story.pending_data()["options"]
		for i in opts.size():
			if story.choose(self, i):
				break
	_sink = events
	phase = "enemy"
	_enemy_phase(events)
	if result == "":
		start_player_turn()
		events.append({"type": "turn", "turn": turn})
	else:
		phase = "over"
	_sink = null
	return events


func _enemy_phase(events: Array) -> void:
	events.append({"type": "phase", "text": "ENEMY PHASE"})
	_phase_kills = 0
	_phase_hits = 0
	for s in structures.values():
		s["shots_left"] = s_shots(s)
	for u in units.values():
		u["shots_left"] = u_shots(u)
	for e in enemies.values():
		e["reacted"] = false
		e["attacked"] = false
	ai.begin_phase(self)
	_move_carriers(events)
	ai.assign_targets(self)
	var paths: Dictionary = ai.plan_paths(self)
	var max_len := 0
	for p in paths.values():
		max_len = maxi(max_len, p.size())
	_process_exits(events)
	for step in range(0, max_len + 1):
		if step > 0:
			events.append({"type": "beat_start"})
			for id in paths:
				if not enemies.has(id):
					continue
				var p: Array = paths[id]
				if step - 1 >= p.size():
					continue
				var e: Dictionary = enemies[id]
				var from: Vector2i = e["pos"]
				e["pos"] = p[step - 1]
				events.append({"type": "move", "ent": "enemy", "id": id, "from": from, "to": e["pos"], "vis": enemy_detected(e)})
			events.append({"type": "beat_end"})
			ai.update_known(self)
			_process_exits(events)
		var vi := _open_volley(events)
		_reaction_fire(events)
		_close_volley(events, vi)
		var vi2 := _open_volley(events)
		for id in paths:
			if enemies.has(id):
				_enemy_try_attack(enemies[id], events)
		_close_volley(events, vi2)
		if result != "":
			return
	for e in enemies.values():
		e["fuel"] -= 1
		if e["fuel"] <= 0 and e["state"] != "rtb":
			e["state"] = "rtb"
			e["target"] = {}
	if wave < waves_total and turn >= next_wave_turn:
		_launch_wave(events)
	for c in carriers.values():
		c["hp"] = mini(c["max_hp"], c["hp"] + 3)
	ai.update_known(self)
	ai.assign_targets(self)
	_check_waves_cleared(events)
	if _phase_kills > 0 or _phase_hits > 0:
		var kind := "good" if _phase_kills >= _phase_hits else "warn"
		log_msg("Enemy phase report: %d aircraft downed, %d hits taken." % [_phase_kills, _phase_hits], kind)
	if result == "":
		story.on_enemy_phase_end(self, events)
	_check_end(events)


func _process_exits(events: Array) -> void:
	for e in enemies.values():
		if e["state"] == "rtb" and ai.is_exit(self, e["pos"]):
			enemies.erase(e["id"])
			events.append({"type": "exit", "id": e["id"], "pos": e["pos"]})


func _move_carriers(events: Array) -> void:
	var batteries: Array = []
	for id in ai.known:
		var s: Dictionary = structures.get(id, {})
		if not s.is_empty() and s["kind"] == "missile":
			batteries.append(s["pos"])
	for c in carriers.values():
		var threatened := false
		for b in batteries:
			if Hex.distance(b, c["pos"]) <= Defs.MISSILE_RANGE:
				threatened = true
		if rng.randf() < (0.25 if threatened else 0.55):
			continue
		var best := Hex.INVALID
		var best_sc := -INF
		for nb in Hex.neighbors(c["pos"]):
			if terrain(nb) != "deep" or not tiles.has(nb):
				continue
			var o := Hex.axial_to_offset(nb)
			if o.x < width - Defs.CARRIER_ZONE or o.x >= width - 1 or o.y < 1 or o.y > height - 2:
				continue
			if not carrier_at(nb).is_empty():
				continue
			var sc := rng.randf()
			for b in batteries:
				sc += Hex.distance(b, nb) * 0.4
			if sc > best_sc:
				best_sc = sc
				best = nb
		if best == Hex.INVALID:
			continue
		var from: Vector2i = c["pos"]
		c["pos"] = best
		events.append({"type": "move", "ent": "carrier", "id": c["id"], "from": from, "to": best, "vis": carrier_visible(c)})
		if carrier_visible(c):
			c["seen_pos"] = best
			c["seen_turn"] = turn


func _launch_wave(events: Array) -> void:
	wave += 1
	var plan: Dictionary = ai.plan_wave(self, wave)
	var spawn_hexes: Array = ai.sector_hexes(self, plan["sector"])
	var carrier_list: Array = carriers.values()
	var comp := {}
	var sector_seen := has_tech("coastwatchers")
	for kind in plan["units"]:
		var pos: Vector2i
		if not carrier_list.is_empty() and kind in ["fighter", "drone", "gunship", "missile"] and rng.randf() < 0.5:
			pos = carrier_list[rng.randi_range(0, carrier_list.size() - 1)]["pos"]
		else:
			pos = spawn_hexes[rng.randi_range(0, spawn_hexes.size() - 1)]
			if visible_hexes.has(pos):
				sector_seen = true
		var e := _add_enemy(kind, pos, plan["sector"])
		comp[kind] = comp.get(kind, 0) + 1
		events.append({"type": "spawn", "id": e["id"], "kind": kind, "pos": pos, "vis": enemy_detected(e)})
	next_wave_turn = turn + Defs.WAVE_INTERVAL
	var report := {
		"wave": wave, "total": waves_total, "count": plan["units"].size(),
		"sector": plan["sector"] if sector_seen else "",
		"doctrine": plan["doctrine"],
		"composition": comp if has_tech("satellite_uplink") else {},
	}
	story.on_wave_launched(self, report)
	if report.get("revealed", false):
		report["composition"] = comp
	last_wave_report = report
	events.append({"type": "wave", "report": report})
	var where := ("from the %s" % plan["sector"]) if sector_seen else "(approach vector unknown)"
	log_msg("WAVE %d/%d INBOUND %s: %d aircraft." % [wave, waves_total, where, plan["units"].size()], "bad")
	log_msg("Intel: " + plan["doctrine"], "intel")


func _check_waves_cleared(events: Array) -> void:
	for w in range(1, wave + 1):
		if waves_cleared.has(w):
			continue
		var remaining := false
		for e in enemies.values():
			if e["wave"] == w:
				remaining = true
				break
		if not remaining:
			waves_cleared[w] = true
			var pts := int(round(100 * diff()["score_mult"]))
			score += pts
			events.append({"type": "wave_cleared", "wave": w})
			log_msg("Wave %d repelled! (+%d)" % [w, pts], "good")
			story.on_wave_cleared(self, w)


func _check_end(events: Array) -> void:
	if result != "":
		return
	if not structures.has(capital_id):
		result = "defeat"
		result_reason = "Lumen has fallen. The Quarantine becomes an occupation."
	elif carriers.is_empty():
		result = "victory"
		result_reason = "Every Harmony-class carrier lies at the bottom of the strait. The Quarantine is broken."
	elif wave >= waves_total and enemies.is_empty():
		result = "victory"
		result_reason = "All %d waves repelled. Tessera still stands." % waves_total
	if result != "":
		phase = "over"
		_finalize()
		events.append({"type": "game_over", "result": result})


func _finalize() -> void:
	if result != "victory":
		return
	var mult: float = diff()["score_mult"]
	var bonus := 1000.0 * mult
	for s in structures.values():
		if s["kind"] == "capital" or s["kind"] == "city":
			bonus += 100.0 * mult * float(s["hp"]) / s["max_hp"]
	stats["final_bonus"] = int(round(bonus))
	score += stats["final_bonus"]


# --------------------------------------------------------------------------------------------
# Combat
# --------------------------------------------------------------------------------------------

func _roll(p: float) -> bool:
	return rng.randf() < clampf(p, 0.05, 0.97)


func _vary(dmg: float) -> int:
	return maxi(1, int(round(dmg * rng.randf_range(0.85, 1.15))))


func _open_volley(events: Array) -> int:
	events.append({"type": "volley_start"})
	return events.size()


func _close_volley(events: Array, start_size: int) -> void:
	if events.size() == start_size:
		events.pop_back()
	else:
		events.append({"type": "volley_end"})


func _reaction_fire(events: Array) -> void:
	var shooters: Array = []
	for s in structures.values():
		if s["shots_left"] > 0 and Defs.STRUCTURES[s["kind"]].has("weapon"):
			shooters.append(s)
	for u in units.values():
		if u["shots_left"] > 0 and Defs.UNITS[u["kind"]].has("weapon"):
			shooters.append(u)
	for sh in shooters:
		var is_struct: bool = sh["cls"] == "structure"
		if is_struct and not structures.has(sh["id"]):
			continue
		if not is_struct and not units.has(sh["id"]):
			continue
		var wdef: Dictionary = Defs.STRUCTURES[sh["kind"]] if is_struct else Defs.UNITS[sh["kind"]]
		var r := s_range(sh) if is_struct else u_range(sh)
		var target := _pick_target(sh["pos"], r, wdef)
		if not target.is_empty():
			_fire(sh, wdef, target, events)
	for u in units.values():
		if u["kind"] != "interceptor" or not u["react"] or not units.has(u["id"]):
			continue
		var best := {}
		var best_sc := -INF
		for e in enemies.values():
			if Hex.distance(e["pos"], u["pos"]) <= 2 and enemy_detected(e):
				var sc: float = Defs.ENEMIES[e["kind"]]["threat"] * 10.0 - Hex.distance(e["pos"], u["pos"]) - e["hp"] * 0.05
				if sc > best_sc:
					best_sc = sc
					best = e
		if not best.is_empty():
			u["react"] = false
			_dogfight(u, best, events)


func _pick_target(pos: Vector2i, r: int, wdef: Dictionary) -> Dictionary:
	var best := {}
	var best_sc := -INF
	for e in enemies.values():
		if Hex.distance(e["pos"], pos) > r or not enemy_detected(e):
			continue
		var edef: Dictionary = Defs.ENEMIES[e["kind"]]
		var dmg := weapon_damage(wdef, edef["alt"])
		var sc: float = edef["threat"] * 6.0 + dmg * 0.8
		if e["hp"] <= dmg:
			sc += 12.0
		if e["state"] != "rtb":
			sc += 6.0
		sc -= e["hp"] * 0.05
		if sc > best_sc:
			best_sc = sc
			best = e
	return best


func _fire(sh: Dictionary, wdef: Dictionary, e: Dictionary, events: Array) -> void:
	sh["shots_left"] -= 1
	var edef: Dictionary = Defs.ENEMIES[e["kind"]]
	var acc: float = wdef["acc"] + accuracy_bonus()
	if radar_cov.has(e["pos"]):
		acc += radar_bonus()
	if edef.get("stealth", false):
		acc -= 0.2
	var hit := _roll(acc)
	var dmg := _vary(weapon_damage(wdef, edef["alt"]))
	events.append({"type": "shot", "weapon": wdef["weapon"], "src": sh["cls"], "src_id": sh["id"], "from": sh["pos"],
		"to": e["pos"], "dst": "enemy", "dst_id": e["id"], "hit": hit, "dmg": dmg})
	stats["shots"] += 1
	var source: String = sh["kind"]
	if sh["cls"] == "structure":
		ai.reveal(sh["id"])
	else:
		ai.saw_unit(sh, turn)
	if hit:
		stats["hits"] += 1
		_damage_enemy(e, dmg, events, source, sh)


func _dogfight(u: Dictionary, e: Dictionary, events: Array) -> void:
	var edef: Dictionary = Defs.ENEMIES[e["kind"]]
	var acc: float = Defs.UNITS["interceptor"]["acc"] + accuracy_bonus()
	if radar_cov.has(e["pos"]):
		acc += radar_bonus()
	if edef.get("stealth", false):
		acc -= 0.2
	var dmg := float(u_dmg(u))
	if edef["role"] == "strike":
		dmg *= 1.2
	var hit := _roll(acc)
	var rolled := _vary(dmg)
	u["heading"] = (Hex.to_pixel(e["pos"]) - Hex.to_pixel(u["pos"])).angle() if e["pos"] != u["pos"] else u["heading"]
	events.append({"type": "shot", "weapon": "cannon", "src": "unit", "src_id": u["id"], "from": u["pos"], "to": e["pos"],
		"dst": "enemy", "dst_id": e["id"], "hit": hit, "dmg": rolled})
	stats["shots"] += 1
	ai.saw_unit(u, turn)
	if hit:
		stats["hits"] += 1
		_damage_enemy(e, rolled, events, "interceptor", u)
	if enemies.has(e["id"]):
		if edef.get("gunners", 0) > 0 and _roll(0.5):
			_enemy_shoot_unit(e, u, int(edef["gunners"]), "gun", events)
		elif e["kind"] == "fighter" and _roll(0.55):
			_enemy_shoot_unit(e, u, int(edef["air_dmg"] * 0.7), "gun", events)
	if units.has(u["id"]):
		for f in enemies.values():
			if f["kind"] == "fighter" and f["id"] != e["id"] and not f["reacted"] and Hex.distance(f["pos"], e["pos"]) <= 2:
				f["reacted"] = true
				var fd: Dictionary = Defs.ENEMIES["fighter"]
				if _roll(fd["acc"]):
					_enemy_shoot_unit(f, u, _vary(fd["air_dmg"]), "gun", events)
				else:
					events.append({"type": "shot", "weapon": "gun", "src": "enemy", "src_id": f["id"], "from": f["pos"],
						"to": u["pos"], "dst": "unit", "dst_id": u["id"], "hit": false, "dmg": 0})
				break


func _enemy_shoot_unit(e: Dictionary, u: Dictionary, dmg: int, weapon: String, events: Array) -> void:
	events.append({"type": "shot", "weapon": weapon, "src": "enemy", "src_id": e["id"], "from": e["pos"], "to": u["pos"],
		"dst": "unit", "dst_id": u["id"], "hit": true, "dmg": dmg})
	_damage_unit(u, dmg, events)


func _enemy_try_attack(e: Dictionary, events: Array) -> void:
	if e["attacked"] or e["state"] == "rtb" or e["target"].is_empty():
		return
	var edef: Dictionary = Defs.ENEMIES[e["kind"]]
	if edef["role"] == "scout":
		return
	var t: Dictionary = e["target"]
	var rng_att: int = edef["attack_range"]
	if t.get("type", "") == "escort":
		# Escorting fighters strafe whatever known structure they pass over.
		for s in structures.values():
			if Hex.distance(e["pos"], s["pos"]) <= rng_att and ai.known.has(s["id"]):
				_enemy_strike_structure(e, s, events)
				return
		return
	match t.get("type", ""):
		"structure":
			var s: Dictionary = structures.get(t["id"], {})
			if s.is_empty() or Hex.distance(e["pos"], s["pos"]) > rng_att:
				return
			_enemy_strike_structure(e, s, events)
		"unit":
			var u: Dictionary = units.get(t["id"], {})
			if u.is_empty() or Hex.distance(e["pos"], u["pos"]) > rng_att:
				return
			_enemy_strike_unit(e, u, events)


func _enemy_weapon(kind: String) -> String:
	match kind:
		"bomber", "stealth":
			return "bombs"
		"gunship":
			return "rockets"
		"missile":
			return "impact"
	return "guns"


func _enemy_strike_structure(e: Dictionary, s: Dictionary, events: Array) -> void:
	e["attacked"] = true
	_attacker_wave = e["wave"]
	var edef: Dictionary = Defs.ENEMIES[e["kind"]]
	var hit := _roll(edef["acc"])
	events.append({"type": "attack", "id": e["id"], "kind": e["kind"], "weapon": _enemy_weapon(e["kind"]),
		"from": e["pos"], "to": s["pos"], "hit": hit, "vis": enemy_detected(e)})
	if hit:
		_phase_hits += 1
		story.on_hit()
		var center: Vector2i = s["pos"]
		_damage_structure(s, _vary(edef["dmg"]), events)
		if edef.has("splash"):
			for s2 in structures.values():
				if structures.has(s2["id"]) and Hex.distance(s2["pos"], center) == 1:
					_damage_structure(s2, int(edef["splash"]), events)
	_after_attack(e, events)


func _enemy_strike_unit(e: Dictionary, u: Dictionary, events: Array) -> void:
	e["attacked"] = true
	_attacker_wave = e["wave"]
	var edef: Dictionary = Defs.ENEMIES[e["kind"]]
	var dmg: int = edef.get("air_dmg", edef["dmg"]) if u["kind"] == "interceptor" else edef["dmg"]
	var hit := _roll(edef["acc"])
	events.append({"type": "attack", "id": e["id"], "kind": e["kind"], "weapon": _enemy_weapon(e["kind"]),
		"from": e["pos"], "to": u["pos"], "hit": hit, "vis": enemy_detected(e)})
	if hit:
		_phase_hits += 1
		story.on_hit()
		_damage_unit(u, _vary(dmg), events)
	if units.has(u["id"]) and u["kind"] == "interceptor" and enemies.has(e["id"]) and _roll(0.6):
		var rd := _vary(u_dmg(u) * 0.7)
		events.append({"type": "shot", "weapon": "cannon", "src": "unit", "src_id": u["id"], "from": u["pos"], "to": e["pos"],
			"dst": "enemy", "dst_id": e["id"], "hit": true, "dmg": rd})
		_damage_enemy(e, rd, events, "interceptor", u)
	if enemies.has(e["id"]):
		_after_attack(e, events)


func _after_attack(e: Dictionary, events: Array) -> void:
	match Defs.ENEMIES[e["kind"]]["role"]:
		"strike":
			e["state"] = "rtb"
			e["target"] = {}
		"missile":
			enemies.erase(e["id"])
			events.append({"type": "destroyed", "tgt": "enemy", "id": e["id"], "pos": e["pos"], "kind": e["kind"], "pts": 0, "quiet": true})
		"sead":
			e["ammo"] -= 1
			e["target"] = {}
			if e["ammo"] <= 0:
				e["state"] = "rtb"
		"fighter":
			if e["target"].get("type", "") != "unit":
				e["target"] = {}


func _damage_structure(s: Dictionary, dmg: int, events: Array) -> void:
	var shielded := false
	if s["kind"] != "bunker":
		for b in structures.values():
			if b["kind"] == "bunker" and Hex.distance(b["pos"], s["pos"]) == 1:
				shielded = true
				break
	if shielded:
		dmg = int(round(dmg * 0.65))
	dmg = maxi(dmg, 1)
	s["hp"] -= dmg
	stats["damage_taken"] += dmg
	_track_wave_damage(dmg)
	events.append({"type": "damage", "tgt": "structure", "id": s["id"], "dmg": dmg, "hp": maxi(s["hp"], 0), "pos": s["pos"], "shielded": shielded})
	if s["hp"] <= 0:
		_destroy_structure(s, events)


func _track_wave_damage(dmg: int) -> void:
	if not stats.has("wave_damage"):
		stats["wave_damage"] = {}
	var wd: Dictionary = stats["wave_damage"]
	wd[_attacker_wave] = wd.get(_attacker_wave, 0) + dmg


func _destroy_structure(s: Dictionary, events: Array) -> void:
	structures.erase(s["id"])
	ruins[s["pos"]] = s["kind"]
	ai.on_structure_destroyed(s)
	story.on_structure_destroyed(self, s)
	match s["kind"]:
		"capital":
			log_msg("%s HAS FALLEN!" % s["name"], "bad")
		"city":
			stats["cities_lost"] += 1
			log_msg("The city of %s has been destroyed!" % s["name"], "bad")
		_:
			stats["structures_lost"] += 1
			log_msg("%s destroyed." % Defs.structure_name(s["kind"]), "bad")
	events.append({"type": "destroyed", "tgt": "structure", "id": s["id"], "pos": s["pos"], "kind": s["kind"]})
	compute_visibility()
	if s["kind"] == "capital":
		_check_end(events)


func _damage_unit(u: Dictionary, dmg: int, events: Array) -> void:
	if not units.has(u["id"]):
		return
	u["hp"] -= dmg
	_track_wave_damage(dmg)
	events.append({"type": "damage", "tgt": "unit", "id": u["id"], "dmg": dmg, "hp": maxi(u["hp"], 0), "pos": u["pos"]})
	if u["hp"] <= 0:
		units.erase(u["id"])
		stats["units_lost"] += 1
		events.append({"type": "destroyed", "tgt": "unit", "id": u["id"], "pos": u["pos"], "kind": u["kind"]})
		log_msg("%s lost!" % Defs.unit_name(u["kind"]), "bad")
		compute_visibility()


func _damage_enemy(e: Dictionary, dmg: int, events: Array, source: String, shooter) -> void:
	if not enemies.has(e["id"]):
		return
	e["hp"] -= dmg
	events.append({"type": "damage", "tgt": "enemy", "id": e["id"], "dmg": dmg, "hp": maxi(e["hp"], 0), "pos": e["pos"]})
	if e["hp"] <= 0:
		enemies.erase(e["id"])
		var kills: Dictionary = stats["kills"]
		kills[e["kind"]] = kills.get(e["kind"], 0) + 1
		stats["kills_total"] += 1
		var pts := int(round(Defs.ENEMIES[e["kind"]]["score"] * diff()["score_mult"]))
		score += pts
		_phase_kills += 1
		if shooter is Dictionary and shooter.get("cls", "") == "structure":
			shooter["kills"] += 1
		ai.on_enemy_lost(self, e, source, shooter)
		story.on_enemy_lost(self, e)
		events.append({"type": "destroyed", "tgt": "enemy", "id": e["id"], "pos": e["pos"], "kind": e["kind"], "pts": pts})


# --------------------------------------------------------------------------------------------
# Messages and persistence
# --------------------------------------------------------------------------------------------

func choose_directive(idx: int) -> bool:
	if phase != "player" or result != "":
		return false
	return story.choose(self, idx)


func run_op(op: String) -> bool:
	return story.run_op(self, op)


func log_msg(text: String, kind: String = "info") -> void:
	messages.append({"turn": turn, "text": text, "kind": kind})
	if messages.size() > 200:
		messages.pop_front()
	if _sink != null:
		_sink.append({"type": "log", "text": text, "kind": kind})


func to_dict() -> Dictionary:
	return {
		"version": SAVE_VERSION, "seed": seed_value, "difficulty": difficulty, "width": width, "height": height,
		"tiles": tiles, "cells": cells, "structures": structures, "units": units, "enemies": enemies,
		"carriers": carriers, "ruins": ruins, "techs": techs, "supplies": supplies, "rp": rp, "turn": turn,
		"wave": wave, "waves_total": waves_total, "next_wave_turn": next_wave_turn, "phase": phase,
		"result": result, "result_reason": result_reason, "explored": explored, "recon": recon,
		"recon_used_turn": recon_used_turn, "stats": stats, "score": score, "messages": messages,
		"rng_seed": rng.seed, "rng_state": rng.state, "next_id": next_id, "waves_cleared": waves_cleared,
		"last_wave_report": last_wave_report, "capital_id": capital_id, "ai": ai.to_dict(),
		"story": story.to_dict(),
	}


static func from_dict(d: Dictionary) -> GameState:
	if d.get("version", 0) != SAVE_VERSION:
		return null
	var st := GameState.new()
	st.seed_value = d["seed"]
	st.difficulty = d["difficulty"]
	st.width = d["width"]
	st.height = d["height"]
	st.tiles = d["tiles"]
	st.cells = d["cells"]
	st.structures = d["structures"]
	st.units = d["units"]
	st.enemies = d["enemies"]
	st.carriers = d["carriers"]
	st.ruins = d["ruins"]
	st.techs = d["techs"]
	st.supplies = d["supplies"]
	st.rp = d["rp"]
	st.turn = d["turn"]
	st.wave = d["wave"]
	st.waves_total = d["waves_total"]
	st.next_wave_turn = d["next_wave_turn"]
	st.phase = d["phase"]
	st.result = d["result"]
	st.result_reason = d["result_reason"]
	st.explored = d["explored"]
	st.recon = d["recon"]
	st.recon_used_turn = d["recon_used_turn"]
	st.stats = d["stats"]
	st.score = d["score"]
	st.messages = d["messages"]
	st.rng.seed = d["rng_seed"]
	st.rng.state = d["rng_state"]
	st.next_id = d["next_id"]
	st.waves_cleared = d["waves_cleared"]
	st.last_wave_report = d["last_wave_report"]
	st.capital_id = d["capital_id"]
	st.ai = EnemyAI.new()
	st.ai.from_dict(d["ai"])
	st.story = Campaign.new()
	st.story.from_dict(d["story"])
	st.compute_visibility()
	return st
