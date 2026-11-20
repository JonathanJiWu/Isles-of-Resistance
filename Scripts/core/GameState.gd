class_name GameState
extends RefCounted
## Complete, deterministic game model. Player actions and the enemy phase mutate the state
## and return a list of "events" (plain dictionaries) that the view layer animates.

const SAVE_VERSION := 3

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
var env := {}                   # generated scenery and the campaign's theater (see EnvGen)
var weather := "clear"
var weather_rng := RandomNumberGenerator.new()
var interceptors := 0           # national stockpile of SAM interceptors
var landings := {}              # id -> landing group (escalation 4)
var objectives: Array = []      # timed objectives (see Campaign)
var forecast := {}              # intelligence forecast for the next wave
var energy := Defs.ENERGY_DAYS  # LNG reserve in days; drains under blockade
var brownout_turns := 0         # imposed rolling blackouts
var comms_turns := 0            # communications degraded (cable cuts)
var confidence_turns := 0       # temporary intelligence bonus
var repairs_used := 0
var procured_turn := -1
var landings_spawned := false
var intel_rng := RandomNumberGenerator.new()
var infra_names := {}            # names of the power station and cable landing, for rebuilding
var forced_weather := ""        # a forecast storm that will arrive next turn

var _sink = null                # event array receiving log events while resolving
var _phase_kills := 0
var _phase_hits := 0
var _attacker_wave := 0
var _dry_logged := false


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
	if gen.get("power", Hex.INVALID) != Hex.INVALID:
		var ps := _add_structure("power", gen["power"])
		ps["name"] = Lore.POWER_NAMES[rng.randi_range(0, Lore.POWER_NAMES.size() - 1)]
		infra_names["power"] = ps["name"]
	if gen.get("cable", Hex.INVALID) != Hex.INVALID:
		var cs2 := _add_structure("cable", gen["cable"])
		cs2["name"] = Lore.CABLE_NAMES[rng.randi_range(0, Lore.CABLE_NAMES.size() - 1)]
		infra_names["cable"] = cs2["name"]
	var hubs: Array = [gen["capital"]]
	var occupied: Array = [gen["capital"]]
	for c in gen["cities"]:
		hubs.append(c["pos"])
		occupied.append(c["pos"])
	for k in ["power", "cable"]:
		if gen.get(k, Hex.INVALID) != Hex.INVALID:
			hubs.append(gen[k])
			occupied.append(gen[k])
	for k in ["start_flak", "start_radar"]:
		if gen.get(k, Hex.INVALID) != Hex.INVALID:
			occupied.append(gen[k])
	env = EnvGen.generate(p_seed, tiles, cells, width, height, hubs, occupied)
	weather_rng.seed = p_seed * 17 + 3
	weather = EnvGen.next_weather(env, "", weather_rng)
	for p in gen["carriers"]:
		var cid := next_id
		next_id += 1
		carriers[cid] = {"id": cid, "pos": p, "hp": d["carrier_hp"], "max_hp": d["carrier_hp"],
			"seen_pos": Hex.INVALID, "seen_turn": -99}
	supplies = d["supplies"]
	interceptors = d["interceptors"]
	intel_rng.seed = p_seed * 29 + 11
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
		"shots_left": 0, "acted": false, "repaired": false, "kills": 0, "name": "", "built_turn": turn,
		"facing": _facing_for(pos)}
	if kind == "airbase":
		s["axis"] = _runway_axis(pos)
	next_id += 1
	structures[s["id"]] = s
	ruins.erase(pos)
	return s


const _DIR_X := [1.0, 0.5, -0.5, -1.0, -0.5, 0.5]


## Hex direction (0-5) a coastal installation faces: toward open water, preferring the side
## opposite solid land and, slightly, the eastern threat axis. -1 when the hex is inland.
func _facing_for(pos: Vector2i) -> int:
	var best := -1
	var best_sc := -INF
	for i in 6:
		var nb: Vector2i = pos + Hex.DIRS[i]
		if not tiles.has(nb) or not is_water(nb):
			continue
		var sc: float = _DIR_X[i] * 0.3
		var opp: Vector2i = pos + Hex.DIRS[(i + 3) % 6]
		if tiles.has(opp) and not is_water(opp):
			sc += 2.0
		if terrain(nb) == "deep":
			sc += 0.4
		if sc > best_sc:
			best_sc = sc
			best = i
	return best


## Runway axis for an airbase: the long hex diagonal (+-30 degrees) with more land at its ends.
func _runway_axis(pos: Vector2i) -> float:
	var score := func(dirs: Array) -> int:
		var n := 0
		for i in dirs:
			if is_land(pos + Hex.DIRS[i]):
				n += 1
		return n
	var down: int = score.call([0, 5, 3, 2])
	var up: int = score.call([0, 1, 3, 4])
	if down == up:
		return 0.5236 if (pos.x + pos.y) % 2 == 0 else -0.5236
	return 0.5236 if down > up else -0.5236


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
		if brownout():
			v -= 1
	if has_tech("coastwatchers"):
		v += 1
	if weather == "fog":
		v -= 1
	return maxi(v, 1)


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
	var v: int = int(Defs.UNITS[u["kind"]]["vision"]) + (1 if has_tech("coastwatchers") else 0)
	return maxi(1, v - (1 if weather == "fog" else 0))


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
	if brownout():
		inc = int(round(inc * 0.85))
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
	for lg in landings.values():
		if naval_visible(lg):
			lg["seen_pos"] = lg["pos"]
			lg["seen_turn"] = turn
			explored[lg["pos"]] = true


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
	if repairs_used >= repair_crews():
		return "All %d repair crews are busy this turn" % repair_crews()
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
	repairs_used += 1
	return true


func repair_crews() -> int:
	return Defs.REPAIR_CREWS + (1 if has_tech("logistics") else 0)


# --------------------------------------------------------------------------------------------
# Units
# --------------------------------------------------------------------------------------------

func units_from(sid: int, kind: String = "") -> int:
	var n := 0
	for u in units.values():
		if u["home"] == sid and (kind == "" or u["kind"] == kind):
			n += 1
	return n


func produce_check(sid: int, ukind: String) -> String:
	var s: Dictionary = structures.get(sid, {})
	var def: Dictionary = Defs.UNITS[ukind]
	if s.is_empty() or s["kind"] != def["from"]:
		return "Wrong facility"
	if def.has("tech") and not has_tech(def["tech"]):
		return "Requires %s" % Defs.TECHS[def["tech"]]["name"]
	if s["kind"] == "airbase" and not airbase_operational(s):
		return "Runway cratered: repair the airbase first"
	if units_from(sid, ukind) >= def["max_per"]:
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
	if u.is_empty() or u["moved"] or phase != "player" or unit_grounded(u) != "":
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
	if u.is_empty() or u["kind"] != "interceptor" or u["attacked"] or phase != "player" or unit_grounded(u) != "":
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


## Why a unit cannot fly or sail this turn ("" if it can).
func unit_grounded(u: Dictionary) -> String:
	if u.is_empty():
		return ""
	if u["kind"] == "interceptor":
		if weather == "storm":
			return "Grounded by the storm"
		var home: Dictionary = structures.get(u["home"], {})
		if home.is_empty() or not airbase_operational(home):
			return "Grounded: home runway cratered"
	return ""


func airbase_operational(s: Dictionary) -> bool:
	return s["hp"] * 2 >= s["max_hp"]


## Drone boats: one-way attack on a landing group or carrier within reach.
func boat_targets(u: Dictionary) -> Array:
	var out: Array = []
	if u.is_empty() or u["kind"] != "droneboat" or u["attacked"] or phase != "player":
		return out
	for t in naval_targets():
		if naval_visible(t) and Hex.distance(t["pos"], u["pos"]) <= Defs.BOAT_RANGE:
			out.append(t["id"])
	return out


func boat_attack(uid: int, tid: int) -> Array:
	var events: Array = []
	var u: Dictionary = units.get(uid, {})
	if u.is_empty() or not boat_targets(u).has(tid):
		return events
	_sink = events
	var t: Dictionary = naval_by_id(tid)
	var mult := 1.5 if has_tech("precision_strikes") else 1.0
	var hit := _roll(0.8)
	var vi := _open_volley(events)
	events.append({"type": "strike", "weapon": "boat", "from": u["pos"], "to": t["pos"], "cid": tid, "uid": uid, "hit": hit})
	units.erase(uid)
	events.append({"type": "destroyed", "tgt": "unit", "id": uid, "pos": u["pos"], "kind": u["kind"], "quiet": true})
	if hit:
		_damage_naval(t, int(Defs.UNITS["droneboat"]["strike_dmg"] * mult), events)
	else:
		log_msg("The drone boats were stopped by escort fire.", "warn")
	_close_volley(events, vi)
	compute_visibility()
	_check_end(events)
	_sink = null
	return events


# --------------------------------------------------------------------------------------------
# Mobile launchers, interceptor stocks, infrastructure
# --------------------------------------------------------------------------------------------

func relocate_check(sid: int, h: Vector2i = Hex.INVALID) -> String:
	var s: Dictionary = structures.get(sid, {})
	if s.is_empty() or not Defs.MOBILE.has(s["kind"]):
		return "Cannot relocate"
	if phase != "player":
		return "Only on your turn"
	if s["acted"]:
		return "Already acted this turn"
	if supplies < Defs.RELOCATE_COST:
		return "Not enough supplies"
	if h == Hex.INVALID:
		return "" if not relocate_sites(sid).is_empty() else "No free site within %d hexes" % Defs.RELOCATE_RANGE
	if Hex.distance(h, s["pos"]) > Defs.RELOCATE_RANGE or h == s["pos"]:
		return "Out of reach"
	var why := _site_check(s["kind"], h)
	return why


func _site_check(kind: String, h: Vector2i) -> String:
	if not tiles.has(h) or not explored.has(h):
		return "Unexplored territory"
	if is_water(h):
		return "Must be on land"
	if terrain(h) == "mountain" and not Defs.STRUCTURES[kind].get("mountain_ok", false):
		return "No room on the mountain"
	if not structure_at(h).is_empty():
		return "Hex is occupied"
	return ""


func relocate_sites(sid: int) -> Array:
	var s: Dictionary = structures.get(sid, {})
	var out: Array = []
	if s.is_empty():
		return out
	for h in Hex.in_range(s["pos"], Defs.RELOCATE_RANGE):
		if h != s["pos"] and _site_check(s["kind"], h) == "":
			out.append(h)
	return out


## Shoot and scoot: the site moves, enemy planners lose track of it, and it sits out the next
## enemy phase while it sets up again.
func relocate(sid: int, h: Vector2i) -> bool:
	if relocate_check(sid, h) != "":
		return false
	var s: Dictionary = structures[sid]
	supplies -= Defs.RELOCATE_COST
	var from: Vector2i = s["pos"]
	s["pos"] = h
	s["facing"] = _facing_for(h)
	s["acted"] = true
	s["redeploying"] = true
	ai.known.erase(sid)
	ai.struct_kills.erase(sid)
	compute_visibility()
	log_msg("%s relocated: enemy planners have lost track of it. It sets up again during the next raid." % Defs.structure_name(s["kind"]))
	set_meta("relocated_from", from)
	return true


## Interceptors delivered each turn by the Halberd line (more while the Foundry stands).
func interceptor_regen() -> int:
	return 2 + (1 if story != null and story.foundry_alive(self) else 0)


func landing_at(h: Vector2i) -> Dictionary:
	for lg in landings.values():
		if lg["pos"] == h and naval_visible(lg):
			return lg
	return {}


func rebuild_check(h: Vector2i) -> String:
	var kind: String = ruins.get(h, "")
	if not Defs.REBUILD.has(kind):
		return "Nothing to rebuild"
	if phase != "player":
		return "Only on your turn"
	if not structure_of_kind(kind).is_empty():
		return "Already have one"
	if not structure_at(h).is_empty() or not unit_at(h).is_empty():
		return "Hex is occupied"
	if supplies < int(Defs.REBUILD[kind]):
		return "Not enough supplies"
	return ""


func rebuild(h: Vector2i) -> Dictionary:
	if rebuild_check(h) != "":
		return {}
	var kind: String = ruins[h]
	supplies -= int(Defs.REBUILD[kind])
	var s := _add_structure(kind, h)
	s["hp"] = int(s["max_hp"] / 2)
	s["name"] = infra_names.get(kind, "")
	stats["built"] += 1
	compute_visibility()
	log_msg("%s rebuilt at half strength. Repair crews can finish the job." % Defs.structure_name(kind), "good")
	return s


func procure_check() -> String:
	if phase != "player":
		return "Only on your turn"
	if procured_turn == turn:
		return "Already ordered this turn"
	if interceptors >= Defs.INTERCEPTOR_CAP:
		return "Stockpile full"
	if supplies < Defs.PROCURE_COST:
		return "Not enough supplies"
	return ""


func procure() -> bool:
	if procure_check() != "":
		return false
	supplies -= Defs.PROCURE_COST
	procured_turn = turn
	interceptors = mini(Defs.INTERCEPTOR_CAP, interceptors + Defs.PROCURE_AMOUNT)
	log_msg("Emergency order: +%d interceptors from the Halberd line in Saltmere." % Defs.PROCURE_AMOUNT, "good")
	return true


func escalation() -> int:
	return story.escalation if story != null else 1


func structure_of_kind(kind: String) -> Dictionary:
	for s in structures.values():
		if s["kind"] == kind:
			return s
	return {}


## Rolling blackouts: the power station is down or badly damaged, the LNG reserve is empty, or
## blackouts were ordered. Lasers go dark, radars lose range, income and the Foundry suffer.
func brownout() -> bool:
	if brownout_turns > 0:
		return true
	var ps := structure_of_kind("power")
	if not ps.is_empty() and ps["hp"] * 2 < ps["max_hp"]:
		return true
	return escalation() >= 2 and energy <= 0


## Days of LNG used this turn. Under blockade and strikes a day every other turn, every turn once
## the landing groups sail, and a day more while the power station is down (smaller plants burn it
## faster). Below blockade the tankers get through and the reserve refills.
func energy_drain() -> int:
	var esc := escalation()
	if esc < 2:
		return -1 if energy < Defs.ENERGY_DAYS else 0
	var d := 1 if (esc >= 4 or turn % 2 == 0) else 0
	if structure_of_kind("power").is_empty():
		d += 1
	return d


## Communications degraded: cable landing lost or cut. Intelligence confidence drops a level.
func comms_degraded() -> bool:
	if comms_turns > 0:
		return true
	var cs := structure_of_kind("cable")
	return cs.is_empty() or cs["hp"] * 2 < cs["max_hp"]


## 0 Low, 1 Moderate, 2 High.
func intel_confidence() -> int:
	var score := 0
	for s in structures.values():
		if s["kind"] == "radar":
			score += 1
			break
	if has_tech("satellite_uplink"):
		score += 1
	if story != null and story.ally >= 60:
		score += 1
	if recon_used_turn == turn:
		score += 1
	if confidence_turns > 0:
		score += 1
	if comms_degraded():
		score -= 1
	if score <= 1:
		return 0
	if score <= 2:
		return 1
	return 2


static func confidence_label(c: int) -> String:
	return ["Low", "Moderate", "High"][clampi(c, 0, 2)]


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
	# Fresh eyes sharpen the raid forecast.
	if not forecast.is_empty() and intel_confidence() > int(forecast.get("confidence", 0)):
		_update_forecast()
		log_msg("Recon has sharpened the raid forecast (%s confidence)." % confidence_label(intel_confidence()).to_lower(), "intel")
	_sink = null
	return events


func strike_range(s: Dictionary) -> int:
	return Defs.AIR_STRIKE_RANGE if s["kind"] == "airbase" else Defs.MISSILE_RANGE


func strike_cost(s: Dictionary) -> int:
	return Defs.AIR_STRIKE_COST if s["kind"] == "airbase" else Defs.MISSILE_COST


func naval_targets() -> Array:
	var out: Array = carriers.values()
	out.append_array(landings.values())
	return out


func naval_by_id(id: int) -> Dictionary:
	if carriers.has(id):
		return carriers[id]
	return landings.get(id, {})


func naval_visible(t: Dictionary) -> bool:
	if has_tech("satellite_uplink") or visible_hexes.has(t["pos"]):
		return true
	return landings.has(t["id"]) and _landing_tracked(t)


## A landing group is a dozen large ships: coastal radars and patrols track it once it is within
## LANDING_TRACK hexes of any of your sites.
func _landing_tracked(lg: Dictionary) -> bool:
	for s in structures.values():
		if Hex.distance(s["pos"], lg["pos"]) <= Defs.LANDING_TRACK:
			return true
	return false


func landing_known(lg: Dictionary) -> bool:
	return naval_visible(lg) or (lg["seen_turn"] >= turn - 1 and lg["seen_pos"] != Hex.INVALID)


func landing_eta(lg: Dictionary) -> int:
	return int(ceil(float(lg["path"].size()) / Defs.LANDING_SPEED))


func strike_targets(sid: int) -> Array:
	var s: Dictionary = structures.get(sid, {})
	var out: Array = []
	if s.is_empty() or not (s["kind"] == "airbase" or s["kind"] == "missile"):
		return out
	for t in naval_targets():
		if naval_visible(t) and Hex.distance(s["pos"], t["pos"]) <= strike_range(s):
			out.append(t["id"])
	return out


func strike_check(sid: int, cid: int = -1) -> String:
	var s: Dictionary = structures.get(sid, {})
	if s.is_empty():
		return "No launch site"
	if s["acted"]:
		return "Already acted this turn"
	if s["kind"] == "airbase" and not airbase_operational(s):
		return "Runway cratered: repair the airbase first"
	if s["kind"] == "airbase" and weather == "storm":
		return "Grounded by the storm"
	if story != null and turn <= story.strike_lock_until:
		return "Back-channel truce holds until turn %d" % story.strike_lock_until
	if supplies < strike_cost(s):
		return "Not enough supplies"
	var targets := strike_targets(sid)
	if targets.is_empty():
		return "No spotted carrier or landing group within %d hexes" % strike_range(s)
	if cid >= 0 and not targets.has(cid):
		return "Target out of range or not spotted"
	return ""


func strike(sid: int, cid: int) -> Array:
	var events: Array = []
	if phase != "player" or strike_check(sid, cid) != "":
		return events
	_sink = events
	var s: Dictionary = structures[sid]
	var c: Dictionary = naval_by_id(cid)
	s["acted"] = true
	supplies -= strike_cost(s)
	stats["strikes"] += 1
	ai.reveal(sid)
	story.on_strike(self, c)
	var mult := 1.5 if has_tech("precision_strikes") else 1.0
	var vi := _open_volley(events)
	if s["kind"] == "airbase":
		var dmg := int(rng.randi_range(30, 42) * mult)
		var blunted := _roll(0.3)
		if blunted:
			dmg = int(dmg * 0.5)
		events.append({"type": "strike", "weapon": "air", "from": s["pos"], "to": c["pos"], "cid": cid, "hit": true})
		_damage_naval(c, dmg, events)
		if blunted and not naval_by_id(cid).is_empty():
			log_msg("Escort flak blunted the air strike (%d damage)." % dmg, "warn")
	else:
		var hit := _roll(0.85)
		events.append({"type": "strike", "weapon": "missile", "from": s["pos"], "to": c["pos"], "cid": cid, "hit": hit})
		if hit:
			_damage_naval(c, int(rng.randi_range(26, 34) * mult), events)
		else:
			log_msg("Missile intercepted by escort defenses.", "warn")
	_close_volley(events, vi)
	_check_end(events)
	_sink = null
	return events


func _damage_naval(t: Dictionary, dmg: int, events: Array) -> void:
	if carriers.has(t["id"]):
		_damage_carrier(t, dmg, events)
		return
	if not landings.has(t["id"]):
		return
	t["hp"] -= dmg
	events.append({"type": "damage", "tgt": "landing", "id": t["id"], "dmg": dmg, "hp": maxi(t["hp"], 0), "pos": t["pos"]})
	if t["hp"] <= 0:
		landings.erase(t["id"])
		var pts := int(round(300 * diff()["score_mult"]))
		score += pts
		stats["landings_sunk"] = stats.get("landings_sunk", 0) + 1
		events.append({"type": "destroyed", "tgt": "landing", "id": t["id"], "pos": t["pos"], "kind": "landing", "pts": pts})
		log_msg("%s DESTROYED before it reached the beach. (+%d)" % [t["name"].to_upper(), pts], "good")
		story.on_landing_destroyed(self, t)


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
	if turn > 1:
		brownout_turns = maxi(0, brownout_turns - 1)
		comms_turns = maxi(0, comms_turns - 1)
		confidence_turns = maxi(0, confidence_turns - 1)
		energy = clampi(energy - energy_drain(), 0, maxi(energy, Defs.ENERGY_DAYS))
		interceptors = mini(Defs.INTERCEPTOR_CAP, interceptors + interceptor_regen())
	repairs_used = 0
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
		s["redeploying"] = false
	for e in enemies.values():
		e["reacted"] = false
	recon = recon.filter(func(r): return r["expires"] > turn)
	if turn > 1:
		weather = EnvGen.next_weather(env, weather, weather_rng)
		if forced_weather != "":
			weather = forced_weather
			forced_weather = ""
	compute_visibility()
	if story != null:
		story.on_turn_start(self)
	_update_forecast()
	if wave < waves_total and countdown() == 0:
		if intel_confidence() >= 1:
			log_msg("Wave %d launches at the end of this turn. Final preparations!" % (wave + 1), "warn")
		else:
			log_msg("Indicators suggest a raid is close. Our picture of it is poor.", "warn")


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
	_dry_logged = false
	for s in structures.values():
		s["shots_left"] = 0 if s.get("redeploying", false) else s_shots(s)
	for u in units.values():
		u["shots_left"] = u_shots(u)
	for e in enemies.values():
		e["reacted"] = false
		e["attacked"] = false
	ai.begin_phase(self)
	_move_carriers(events)
	var launching := wave < waves_total and turn >= next_wave_turn
	if launching and weather == "storm":
		launching = false
		next_wave_turn += 1
		log_msg("The storm has grounded the Commonwealth's squadrons: the raid is delayed a turn.", "intel")
	if launching and escalation() >= 3:
		_ballistic_salvo(events)
		if result != "":
			return
	_move_landings(events)
	if result != "":
		return
	ai.assign_targets(self)
	var paths: Dictionary = ai.plan_paths(self)
	var offsets := {}
	var max_len := 0
	for p in paths.values():
		max_len = maxi(max_len, p.size())
	_process_exits(events)
	var step := 0
	while step <= max_len:
		if step > 0:
			events.append({"type": "beat_start"})
			for id in paths:
				if not enemies.has(id):
					continue
				var p: Array = paths[id]
				var k: int = step - 1 - int(offsets.get(id, 0))
				if k < 0 or k >= p.size():
					continue
				var e: Dictionary = enemies[id]
				var from: Vector2i = e["pos"]
				e["pos"] = p[k]
				events.append({"type": "move", "ent": "enemy", "id": id, "from": from, "to": e["pos"], "vis": enemy_detected(e)})
			events.append({"type": "beat_end"})
			ai.update_known(self)
			_process_exits(events)
			_ew_jamming(events)
		var vi := _open_volley(events)
		_reaction_fire(events)
		_close_volley(events, vi)
		var vi2 := _open_volley(events)
		var launched: Array = []
		for id in paths.keys():
			if enemies.has(id):
				launched.append_array(_enemy_try_attack(enemies[id], events))
		_close_volley(events, vi2)
		for mid in launched:
			if not enemies.has(mid):
				continue
			var mp: Array = ai.plan_single(self, enemies[mid])
			paths[mid] = mp
			offsets[mid] = step
			max_len = maxi(max_len, step + mp.size())
		if result != "":
			return
		step += 1
	for e in enemies.values():
		e["fuel"] -= 1
		if e["fuel"] <= 0 and e["state"] != "rtb":
			e["state"] = "rtb"
			e["target"] = {}
	if launching:
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


## Rocket Force opening salvo (escalation 3+): short-range ballistic missiles at known bases,
## radars and launchers. Only SAMs with Hit-to-Kill interceptors can try to stop them.
func _ballistic_salvo(events: Array) -> void:
	var n: int = int(diff()["salvo"]) + (1 if wave >= waves_total / 2 else 0)
	var prio := {"airbase": 10.0, "sam": 9.0, "radar": 8.0, "missile": 7.5, "ewar": 6.5, "power": 6.0, "laser": 5.5, "harbor": 4.0, "lab": 3.0}
	var cands: Array = []
	for id in ai.known:
		var s: Dictionary = structures.get(id, {})
		if s.is_empty() or not prio.has(s["kind"]):
			continue
		cands.append([prio[s["kind"]] + rng.randf() * 3.0, s])
	if cands.is_empty():
		return
	cands.sort_custom(func(a, b): return a[0] > b[0])
	events.append({"type": "salvo_warning", "count": mini(n, cands.size())})
	if story != null:
		story.report["salvo"] = true
	log_msg("BALLISTIC MISSILE LAUNCH DETECTED: %d inbound from the mainland." % mini(n, cands.size()), "bad")
	for i in mini(n, cands.size()):
		var target: Dictionary = cands[i][1]
		if not structures.has(target["id"]):
			continue
		var vi := _open_volley(events)
		var intercepted := false
		var by := Hex.INVALID
		if has_tech("hit_to_kill"):
			for sam in structures.values():
				if sam["kind"] != "sam" or sam.get("redeploying", false) or interceptors < Defs.BMD_COST:
					continue
				if Hex.distance(sam["pos"], target["pos"]) > s_range(sam):
					continue
				interceptors -= Defs.BMD_COST
				by = sam["pos"]
				intercepted = _roll(0.55 + (0.1 if has_tech("phased_array") else 0.0))
				break
		events.append({"type": "ballistic", "to": target["pos"], "tid": target["id"], "intercepted": intercepted, "by": by})
		if intercepted:
			stats["bm_intercepted"] = stats.get("bm_intercepted", 0) + 1
			log_msg("Longbow intercepted a ballistic missile over the %s." % Defs.structure_name(target["kind"]), "good")
		else:
			_attacker_wave = wave + 1
			_phase_hits += 1
			_damage_structure(target, _vary(40.0 if target["kind"] == "airbase" else 32.0), events)
		_close_volley(events, vi)
		if result != "":
			return


## Cicada EW stations jam the links of drones, decoys and loitering munitions near them.
func _ew_jamming(events: Array) -> void:
	if brownout():
		return
	var stations: Array = []
	for s in structures.values():
		if s["kind"] == "ewar" and not s.get("redeploying", false):
			stations.append(s)
	if stations.is_empty():
		return
	var victims: Array = []
	for e in enemies.values():
		var role: String = Defs.ENEMIES[e["kind"]]["role"]
		if not (role in ["scout", "decoy", "seek"]):
			continue
		for st in stations:
			if Hex.distance(st["pos"], e["pos"]) <= int(Defs.STRUCTURES["ewar"]["aura"]):
				ai.reveal(st["id"])
				if _roll(0.3):
					victims.append([e, st])
				break
	if victims.is_empty():
		return
	var vi := _open_volley(events)
	for v in victims:
		var e: Dictionary = v[0]
		var st: Dictionary = v[1]
		if not enemies.has(e["id"]):
			continue
		events.append({"type": "shot", "weapon": "jam", "src": "structure", "src_id": st["id"], "from": st["pos"], "to": e["pos"],
			"dst": "enemy", "dst_id": e["id"], "hit": true, "dmg": e["hp"]})
		_damage_enemy(e, e["hp"], events, "ewar", st)
	_close_volley(events, vi)
	log_msg("Cicada jamming: %d drones lost their links." % victims.size(), "good")
	if story != null:
		story.report["jammed"] = int(story.report.get("jammed", 0)) + victims.size()


## Landing groups sail along their planned route; on arrival the target city falls.
func spawn_landings() -> void:
	if landings_spawned:
		return
	landings_spawned = true
	var cities: Array = []
	for s in structures.values():
		if s["kind"] == "city":
			cities.append(s)
	cities.sort_custom(func(a, b): return Hex.to_pixel(a["pos"]).x > Hex.to_pixel(b["pos"]).x)
	var n: int = diff()["landings"]
	var made := 0
	for city in cities:
		if made >= n:
			break
		var site := _landing_site(city["pos"])
		if site == Hex.INVALID:
			continue
		var spawn := Hex.INVALID
		var best := 999
		var site_x := Hex.axial_to_offset(site).x
		for h in cells:
			var o := Hex.axial_to_offset(h)
			if o.x < site_x + 4 or terrain(h) != "deep" or not carrier_at(h).is_empty():
				continue
			var d := absi(Hex.distance(h, site) - 12) * 3 + absi(o.y - Hex.axial_to_offset(site).y)
			if d < best:
				best = d
				spawn = h
		if spawn == Hex.INVALID:
			continue
		var water := func(h: Vector2i) -> bool:
			return tiles.has(h) and is_water(h)
		var path := Pathfinder.find(spawn, site, water, func(_h): return 1.0, 5000)
		if path.is_empty():
			continue
		var hp: int = diff()["landing_hp"]
		var lg := {"id": next_id, "pos": spawn, "hp": hp, "max_hp": hp, "target": city["id"], "target_name": city["name"],
			"site": site, "path": path, "name": Situations.LANDING_NAMES[made % Situations.LANDING_NAMES.size()],
			"seen_pos": Hex.INVALID, "seen_turn": -99, "gunships": 0}
		next_id += 1
		landings[lg["id"]] = lg
		made += 1
	compute_visibility()
	if made > 0:
		log_msg("ASSAULT: %d landing group%s sailing for Tessera's beaches." % [made, "" if made == 1 else "s"], "bad")


func _landing_site(city_pos: Vector2i) -> Vector2i:
	var best := Hex.INVALID
	var best_x := -INF
	for r in [1, 2]:
		for h in Hex.ring(city_pos, r):
			if not tiles.has(h) or not is_water(h):
				continue
			if r == 2:
				var touches := false
				for nb in Hex.neighbors(h):
					if Hex.distance(nb, city_pos) <= 1 and is_land(nb):
						touches = true
				if not touches:
					continue
			var x := Hex.to_pixel(h).x
			if x > best_x:
				best_x = x
				best = h
		if best != Hex.INVALID:
			return best
	return best


func _move_landings(events: Array) -> void:
	for lg in landings.values():
		var from: Vector2i = lg["pos"]
		for k in Defs.LANDING_SPEED:
			if lg["path"].is_empty():
				break
			lg["pos"] = lg["path"].pop_front()
		if lg["pos"] != from:
			events.append({"type": "move", "ent": "landing", "id": lg["id"], "from": from, "to": lg["pos"], "vis": naval_visible(lg)})
		if naval_visible(lg):
			lg["seen_pos"] = lg["pos"]
			lg["seen_turn"] = turn
		if lg["path"].is_empty():
			_landing_ashore(lg, events)
			if result != "":
				return
		elif Hex.distance(lg["pos"], lg["site"]) <= 6 and int(lg["gunships"]) < 2:
			lg["gunships"] = int(lg["gunships"]) + 1
			var g := _add_enemy("gunship", lg["pos"], "East")
			events.append({"type": "spawn", "id": g["id"], "kind": "gunship", "pos": lg["pos"], "vis": enemy_detected(g)})


func _landing_ashore(lg: Dictionary, events: Array) -> void:
	landings.erase(lg["id"])
	events.append({"type": "destroyed", "tgt": "landing", "id": lg["id"], "pos": lg["pos"], "kind": "landing", "pts": 0, "quiet": true})
	var city: Dictionary = structures.get(lg["target"], {})
	log_msg("%s HAS LANDED. Commonwealth marines are ashore near %s." % [lg["name"].to_upper(), lg["target_name"]], "bad")
	story.on_landing_ashore(self, lg)
	if not city.is_empty():
		_destroy_structure(city, events)


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
		if not carrier_list.is_empty() and kind in ["fighter", "drone", "jammer", "aew", "decoy", "kitefang"] and rng.randf() < 0.5:
			pos = carrier_list[rng.randi_range(0, carrier_list.size() - 1)]["pos"]
		else:
			pos = spawn_hexes[rng.randi_range(0, spawn_hexes.size() - 1)]
			if visible_hexes.has(pos):
				sector_seen = true
		var e := _add_enemy(kind, pos, plan["sector"])
		comp[kind] = comp.get(kind, 0) + 1
		events.append({"type": "spawn", "id": e["id"], "kind": kind, "pos": pos, "vis": enemy_detected(e)})
	next_wave_turn = turn + int(Defs.ESCALATION[escalation()]["interval"])
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
	if forecast.get("wave", -1) == wave:
		var sz: Array = forecast["size"]
		log_msg("Intel had forecast %d-%d aircraft (%s confidence)." % [sz[0], sz[1], confidence_label(int(forecast["confidence"])).to_lower()], "intel")
	forecast = {}
	log_msg("Intel: " + plan["doctrine"], "intel")


## Intelligence forecast for the next wave (within 2 turns), as good as our confidence allows.
func _update_forecast() -> void:
	forecast = {}
	if wave >= waves_total or countdown() > 2 or ai == null:
		return
	var plan: Dictionary = ai.plan_wave(self, wave + 1, true)
	var conf := intel_confidence()
	var n: int = plan["units"].size()
	var spread: float = [0.5, 0.3, 0.1][conf]
	var lo := maxi(1, int(floor(n * (1.0 - spread * intel_rng.randf_range(0.5, 1.0)))))
	var hi := maxi(lo, int(ceil(n * (1.0 + spread * intel_rng.randf_range(0.5, 1.0)))))
	var sector: String = plan["sector"]
	if intel_rng.randf() > [0.45, 0.75, 1.0][conf]:
		var others: Array = Defs.SECTORS.filter(func(x): return x != sector)
		sector = others[intel_rng.randi_range(0, others.size() - 1)]
	var counts := {}
	for k in plan["units"]:
		counts[k] = counts.get(k, 0) + 1
	var kinds: Array = counts.keys()
	kinds.sort_custom(func(a, b): return counts[a] > counts[b])
	var types: Array = []
	if conf >= 1:
		for k in kinds.slice(0, conf + 1):
			types.append(Defs.enemy_name(k))
	var eta := [next_wave_turn, next_wave_turn]
	if conf == 1:
		eta = [next_wave_turn, next_wave_turn + 1] if intel_rng.randf() < 0.5 else [next_wave_turn - 1, next_wave_turn]
	elif conf == 0:
		eta = [next_wave_turn - 1, next_wave_turn + 1]
	eta[0] = maxi(eta[0], turn)
	forecast = {"wave": wave + 1, "confidence": conf, "eta": eta, "size": [lo, hi], "sector": sector,
		"true_sector": plan["sector"], "types": types, "note": plan["doctrine"] if conf >= 1 else ""}


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
	elif wave >= waves_total and enemies.is_empty() and landings.is_empty():
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
		if s["shots_left"] <= 0 or not Defs.STRUCTURES[s["kind"]].has("weapon"):
			continue
		if s["kind"] == "laser" and brownout():
			continue
		if s["kind"] == "sam" and interceptors <= 0:
			if not _dry_logged:
				_dry_logged = true
				log_msg("Longbow batteries are out of interceptors and cannot fire.", "bad")
			continue
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
		if is_struct and sh["kind"] == "sam" and interceptors <= 0:
			continue
		var target := _pick_target(sh["pos"], r, wdef)
		if not target.is_empty():
			_fire(sh, wdef, target, events)
	for u in units.values():
		if u["kind"] != "interceptor" or not u["react"] or not units.has(u["id"]) or unit_grounded(u) != "":
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


## True when an enemy EW jet is within 2 hexes of `pos`: no radar bonus and -20% accuracy there.
func _jammed_at(pos: Vector2i) -> bool:
	for j in enemies.values():
		if Defs.ENEMIES[j["kind"]]["role"] == "jammer" and Hex.distance(j["pos"], pos) <= 2:
			return true
	return false


func weather_laser_penalty() -> float:
	return {"rain": 0.25, "storm": 0.4, "fog": 0.25, "haze": 0.15}.get(weather, 0.0)


func _fire(sh: Dictionary, wdef: Dictionary, e: Dictionary, events: Array) -> void:
	sh["shots_left"] -= 1
	var edef: Dictionary = Defs.ENEMIES[e["kind"]]
	var acc: float = wdef["acc"] + accuracy_bonus()
	var jammed := _jammed_at(e["pos"])
	if radar_cov.has(e["pos"]) and not jammed:
		acc += radar_bonus()
	if jammed:
		acc -= 0.2
	if edef.get("stealth", false):
		acc -= 0.2
	if wdef.get("weapon", "") == "laser":
		acc -= weather_laser_penalty()
	if wdef.get("weapon", "") == "sam":
		interceptors = maxi(0, interceptors - 1)
		stats["interceptors_used"] = stats.get("interceptors_used", 0) + 1
		if edef["role"] == "missile" and has_tech("hit_to_kill"):
			acc += 0.1
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
	var jammed := _jammed_at(e["pos"])
	if radar_cov.has(e["pos"]) and not jammed:
		acc += radar_bonus()
	if jammed:
		acc -= 0.1
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


## Returns the ids of any missiles launched (standoff bombers), so the phase can route them.
func _enemy_try_attack(e: Dictionary, events: Array) -> Array:
	if e["attacked"] or e["state"] == "rtb" or e["target"].is_empty():
		return []
	var edef: Dictionary = Defs.ENEMIES[e["kind"]]
	if edef["role"] in ["scout", "jammer", "aew"]:
		return []
	var t: Dictionary = e["target"]
	var rng_att: int = edef["attack_range"]
	if t.get("type", "") == "escort":
		if edef["role"] != "fighter":
			return []
		# Escorting fighters strafe whatever known structure they pass over.
		for s in structures.values():
			if Hex.distance(e["pos"], s["pos"]) <= rng_att and ai.known.has(s["id"]):
				_enemy_strike_structure(e, s, events)
				return []
		return []
	match t.get("type", ""):
		"structure":
			var s: Dictionary = structures.get(t["id"], {})
			if s.is_empty() or Hex.distance(e["pos"], s["pos"]) > rng_att:
				return []
			if edef["role"] == "standoff":
				return _launch_salvo(e, s, events)
			_enemy_strike_structure(e, s, events)
		"unit":
			var u: Dictionary = units.get(t["id"], {})
			if u.is_empty() or Hex.distance(e["pos"], u["pos"]) > rng_att:
				return []
			_enemy_strike_unit(e, u, events)
	return []


## A standoff bomber releases its cruise missiles from outside the defenses and turns for home.
func _launch_salvo(e: Dictionary, s: Dictionary, events: Array) -> Array:
	e["attacked"] = true
	var ids: Array = []
	var n: int = Defs.ENEMIES[e["kind"]].get("salvo", 2)
	var seen := enemy_detected(e)
	events.append({"type": "salvo", "id": e["id"], "from": e["pos"], "to": s["pos"], "vis": seen})
	for k in n:
		var m := _add_enemy("missile", e["pos"], e["sector"])
		m["wave"] = e["wave"]
		m["target"] = {"type": "structure", "id": s["id"], "pos": s["pos"]}
		events.append({"type": "spawn", "id": m["id"], "kind": "missile", "pos": e["pos"], "vis": enemy_detected(m)})
		ids.append(m["id"])
	e["state"] = "rtb"
	e["target"] = {}
	if seen:
		log_msg("%s released %d cruise missiles at the %s." % [Defs.enemy_name(e["kind"]), n, Defs.structure_name(s["kind"])], "warn")
	return ids


## +10% enemy accuracy while a Skylark AEW&C is airborne.
func _aew_bonus() -> float:
	for e in enemies.values():
		if Defs.ENEMIES[e["kind"]]["role"] == "aew":
			return 0.1
	return 0.0


func _ew_covered(pos: Vector2i) -> bool:
	if brownout():
		return false
	for s in structures.values():
		if s["kind"] == "ewar" and not s.get("redeploying", false) and Hex.distance(s["pos"], pos) <= int(Defs.STRUCTURES["ewar"]["aura"]):
			return true
	return false


func _enemy_weapon(kind: String) -> String:
	match kind:
		"bomber", "stealth":
			return "bombs"
		"gunship":
			return "rockets"
		"missile", "decoy", "kitefang":
			return "impact"
	return "guns"


func _enemy_strike_structure(e: Dictionary, s: Dictionary, events: Array) -> void:
	e["attacked"] = true
	_attacker_wave = e["wave"]
	var edef: Dictionary = Defs.ENEMIES[e["kind"]]
	var acc: float = edef["acc"] + _aew_bonus()
	if edef["role"] in ["missile", "decoy", "seek"] and _ew_covered(s["pos"]):
		acc -= 0.2
	var hit := _roll(acc)
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
		"missile", "decoy", "seek":
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
	if (s["kind"] == "city" or s["kind"] == "capital") and story != null:
		story.on_city_hit(s.get("name", ""))
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
			if s["kind"] == "power":
				brownout_turns = maxi(brownout_turns, 3)
				log_msg("The grid is on emergency generation: rolling blackouts for 3 turns, and the LNG reserve will drain faster from now on.", "bad")
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
		"story": story.to_dict(), "env": env, "weather": weather,
		"weather_seed": weather_rng.seed, "weather_state": weather_rng.state,
		"interceptors": interceptors, "landings": landings, "objectives": objectives, "forecast": forecast,
		"energy": energy, "brownout_turns": brownout_turns, "comms_turns": comms_turns,
		"confidence_turns": confidence_turns, "repairs_used": repairs_used, "procured_turn": procured_turn,
		"landings_spawned": landings_spawned, "intel_seed": intel_rng.seed, "intel_state": intel_rng.state,
		"forced_weather": forced_weather, "infra_names": infra_names,
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
	st.env = d.get("env", {})
	st.weather = d.get("weather", "clear")
	st.weather_rng.seed = d.get("weather_seed", 1)
	st.weather_rng.state = d.get("weather_state", 0)
	st.interceptors = d.get("interceptors", 0)
	st.landings = d.get("landings", {})
	st.objectives = d.get("objectives", [])
	st.forecast = d.get("forecast", {})
	st.energy = d.get("energy", Defs.ENERGY_DAYS)
	st.brownout_turns = d.get("brownout_turns", 0)
	st.comms_turns = d.get("comms_turns", 0)
	st.confidence_turns = d.get("confidence_turns", 0)
	st.repairs_used = d.get("repairs_used", 0)
	st.procured_turn = d.get("procured_turn", -1)
	st.landings_spawned = d.get("landings_spawned", false)
	st.forced_weather = d.get("forced_weather", "")
	st.infra_names = d.get("infra_names", {})
	st.intel_rng.seed = d.get("intel_seed", 1)
	st.intel_rng.state = d.get("intel_state", 0)
	st.ai = EnemyAI.new()
	st.ai.from_dict(d["ai"])
	st.story = Campaign.new()
	st.story.from_dict(d["story"])
	st.compute_visibility()
	return st
