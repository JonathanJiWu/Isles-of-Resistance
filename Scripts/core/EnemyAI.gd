class_name EnemyAI
extends RefCounted
## The invasion's planning staff. It only knows what its aircraft have seen (or what has fired
## at them), keeps a memory of where it has taken losses, routes aircraft around known air
## defenses, and re-balances each wave to counter the player's preferred tactics.

const VALUE := {
	"capital": 10.0, "city": 7.0, "lab": 6.0, "decoy": 8.0, "airbase": 6.0, "missile": 6.5,
	"harbor": 5.0, "radar": 5.0, "sam": 4.0, "laser": 4.5, "flak": 3.0, "bunker": 2.0,
	"power": 3.0, "cable": 2.5,
}
const CAUTION := {"strike": 1.0, "missile": 0.15, "sead": 0.35, "fighter": 0.5, "scout": 0.8}

var known := {}            # structure id -> true
var seen_units := {}       # unit id -> {"pos": Vector2i, "turn": int}
var loss_heat := {}        # hex -> float
var kills_by := {}         # player weapon source -> enemy aircraft lost to it
var struct_kills := {}     # structure id -> kills credited (as observed by the enemy)
var sector_losses := {}    # sector -> float
var last_sector := ""
var sector_streak := 0
var doctrine := ""
var baseline_known := 0

var threat_low := {}
var threat_high := {}
var _exits := {}
var _sector_cache := {}


func setup(st: GameState) -> void:
	for s in st.structures.values():
		if s["kind"] in ["capital", "city", "power", "cable"]:
			known[s["id"]] = true
	baseline_known = known.size()


# --------------------------------------------------------------------------------------------
# Knowledge
# --------------------------------------------------------------------------------------------

func begin_phase(st: GameState) -> void:
	for h in loss_heat.keys():
		loss_heat[h] *= 0.8
		if loss_heat[h] < 0.3:
			loss_heat.erase(h)
	update_known(st)
	compute_threat(st)


func update_known(st: GameState) -> void:
	for e in st.enemies.values():
		var v: int = Defs.ENEMIES[e["kind"]]["vision"]
		if v > 0:
			_scan(st, e["pos"], v)
	for c in st.carriers.values():
		_scan(st, c["pos"], Defs.CARRIER["vision"])


func _scan(st: GameState, pos: Vector2i, v: int) -> void:
	for s in st.structures.values():
		if known.has(s["id"]):
			continue
		var need := v
		if st.terrain(s["pos"]) == "forest":
			need = mini(v, 1)
		if Hex.distance(pos, s["pos"]) <= need:
			known[s["id"]] = true
	for u in st.units.values():
		if Hex.distance(pos, u["pos"]) <= v:
			seen_units[u["id"]] = {"pos": u["pos"], "turn": st.turn}


func reveal(sid: int) -> void:
	known[sid] = true


func saw_unit(u: Dictionary, turn: int) -> void:
	seen_units[u["id"]] = {"pos": u["pos"], "turn": turn}


func on_structure_destroyed(s: Dictionary) -> void:
	known.erase(s["id"])
	struct_kills.erase(s["id"])


func on_enemy_lost(st: GameState, e: Dictionary, source: String, shooter) -> void:
	var key := source
	if key == "capital":
		key = "flak"
	kills_by[key] = kills_by.get(key, 0) + 1
	loss_heat[e["pos"]] = loss_heat.get(e["pos"], 0.0) + 6.0
	for nb in Hex.neighbors(e["pos"]):
		if st.tiles.has(nb):
			loss_heat[nb] = loss_heat.get(nb, 0.0) + 2.5
	sector_losses[e["sector"]] = sector_losses.get(e["sector"], 0.0) + float(Defs.ENEMIES[e["kind"]]["cost"])
	if shooter is Dictionary and shooter.get("cls", "") == "structure":
		struct_kills[shooter["id"]] = struct_kills.get(shooter["id"], 0) + 1
		known[shooter["id"]] = true


func compute_threat(st: GameState) -> void:
	threat_low = {}
	threat_high = {}
	for id in known:
		var s: Dictionary = st.structures.get(id, {})
		if s.is_empty():
			continue
		var def: Dictionary = Defs.STRUCTURES[s["kind"]]
		if def.has("weapon"):
			var shots := st.s_shots(s)
			var tl: float = st.weapon_damage(def, "low") * def["acc"] * shots
			var th: float = st.weapon_damage(def, "high") * def["acc"] * shots
			for h in Hex.in_range(s["pos"], st.s_range(s)):
				threat_low[h] = threat_low.get(h, 0.0) + tl
				threat_high[h] = threat_high.get(h, 0.0) + th
		elif s["kind"] == "airbase":
			for h in Hex.in_range(s["pos"], 6):
				threat_low[h] = threat_low.get(h, 0.0) + 4.0
				threat_high[h] = threat_high.get(h, 0.0) + 4.0
	for uid in seen_units:
		var info: Dictionary = seen_units[uid]
		if not st.units.has(uid) or st.turn - info["turn"] > 2:
			continue
		var u: Dictionary = st.units[uid]
		if u["kind"] == "frigate":
			var fd: Dictionary = Defs.UNITS["frigate"]
			for h in Hex.in_range(info["pos"], fd["range"]):
				threat_low[h] = threat_low.get(h, 0.0) + st.weapon_damage(fd, "low") * fd["acc"] * fd["shots"]
				threat_high[h] = threat_high.get(h, 0.0) + st.weapon_damage(fd, "high") * fd["acc"] * fd["shots"]
		else:
			for h in Hex.in_range(info["pos"], 2):
				threat_low[h] = threat_low.get(h, 0.0) + 8.0
				threat_high[h] = threat_high.get(h, 0.0) + 8.0
	for h in loss_heat:
		threat_low[h] = threat_low.get(h, 0.0) + loss_heat[h]
		threat_high[h] = threat_high.get(h, 0.0) + loss_heat[h]


func threat_at(h: Vector2i, alt: String) -> float:
	return (threat_low if alt == "low" else threat_high).get(h, 0.0)


func _line_threat(a: Vector2i, b: Vector2i, alt: String) -> float:
	var tm := threat_low if alt == "low" else threat_high
	var total := 0.0
	for h in Hex.line(a, b):
		total += tm.get(h, 0.0)
	return total


# --------------------------------------------------------------------------------------------
# Exits and sectors
# --------------------------------------------------------------------------------------------

func _ensure_exits(st: GameState) -> void:
	if not _exits.is_empty():
		return
	for h in st.cells:
		var o := Hex.axial_to_offset(h)
		if o.x >= int(st.width * 0.3) and (o.x == st.width - 1 or o.y == 0 or o.y == st.height - 1):
			_exits[h] = true


func is_exit(st: GameState, h: Vector2i) -> bool:
	_ensure_exits(st)
	return _exits.has(h) or not st.carrier_at(h).is_empty()


func nearest_exit(st: GameState, from: Vector2i) -> Vector2i:
	_ensure_exits(st)
	var best := from
	var best_d := 9999
	for h in _exits:
		var d := Hex.distance(from, h)
		if d < best_d:
			best_d = d
			best = h
	for c in st.carriers.values():
		var d := Hex.distance(from, c["pos"])
		if d < best_d:
			best_d = d
			best = c["pos"]
	return best


func sector_hexes(st: GameState, sector: String) -> Array:
	if _sector_cache.has(sector):
		return _sector_cache[sector]
	var out: Array = []
	var w := st.width
	var h := st.height
	for hx in st.cells:
		var o := Hex.axial_to_offset(hx)
		var ok := false
		match sector:
			"North":
				ok = o.y == 0 and o.x >= int(w * 0.32) and o.x < int(w * 0.66)
			"North-East":
				ok = (o.y == 0 and o.x >= int(w * 0.66)) or (o.x == w - 1 and o.y < int(h * 0.3))
			"East":
				ok = o.x == w - 1 and o.y >= int(h * 0.3) and o.y < int(h * 0.7)
			"South-East":
				ok = (o.y == h - 1 and o.x >= int(w * 0.66)) or (o.x == w - 1 and o.y >= int(h * 0.7))
			"South":
				ok = o.y == h - 1 and o.x >= int(w * 0.32) and o.x < int(w * 0.66)
		if ok:
			out.append(hx)
	_sector_cache[sector] = out
	return out


# --------------------------------------------------------------------------------------------
# Targeting
# --------------------------------------------------------------------------------------------

func _target_valid(st: GameState, t: Dictionary) -> bool:
	if t.is_empty():
		return false
	match t.get("type", ""):
		"structure":
			return st.structures.has(t["id"]) and known.has(t["id"])
		"unit":
			return st.units.has(t["id"])
		"escort":
			return st.enemies.has(t["id"])
	return true


func _ordered_enemies(st: GameState) -> Array:
	var list: Array = st.enemies.values()
	list.sort_custom(func(a, b):
		var fa: int = 1 if a["kind"] == "fighter" else 0
		var fb: int = 1 if b["kind"] == "fighter" else 0
		if fa != fb:
			return fa < fb
		return a["id"] < b["id"])
	return list


func assign_targets(st: GameState) -> void:
	compute_threat(st)
	var targeted := {}
	for e in _ordered_enemies(st):
		if e["state"] == "rtb":
			e["target"] = {"type": "exit", "pos": nearest_exit(st, e["pos"])}
			continue
		var role: String = Defs.ENEMIES[e["kind"]]["role"]
		match role:
			"scout":
				_target_scout(st, e)
			"strike", "missile":
				if not _target_valid(st, e["target"]):
					e["target"] = _pick_value_target(st, e, targeted, CAUTION[role] if e["kind"] != "stealth" else 0.35)
			"sead":
				if not _target_valid(st, e["target"]):
					e["target"] = _pick_aa_target(st, e, targeted)
			"fighter":
				e["target"] = _pick_fighter_target(st, e, targeted)
		var t: Dictionary = e["target"]
		if t.get("type", "") == "structure":
			targeted[t["id"]] = targeted.get(t["id"], 0) + 1


func _target_scout(st: GameState, e: Dictionary) -> void:
	var t: Dictionary = e["target"]
	if t.get("type", "") == "scout" and Hex.distance(e["pos"], t["pos"]) > 1:
		return
	var best := Hex.INVALID
	var best_sc := -INF
	for h in st.cells:
		if not st.is_land(h):
			continue
		var o := Hex.axial_to_offset(h)
		if o.x > int(st.width * 0.7):
			continue
		var d := Hex.distance(e["pos"], h)
		if d < 3:
			continue
		var unknown_bonus := 3.0
		for id in known:
			var s: Dictionary = st.structures.get(id, {})
			if not s.is_empty() and Hex.distance(s["pos"], h) <= 2:
				unknown_bonus = 0.0
				break
		var sc := unknown_bonus + st.rng.randf() * 4.0 - absf(d - 7.0) * 0.35
		if sc > best_sc:
			best_sc = sc
			best = h
	if best != Hex.INVALID:
		e["target"] = {"type": "scout", "pos": best}


## How far the aircraft can still fly before it must turn for home.
func _reach(e: Dictionary) -> int:
	return int(Defs.ENEMIES[e["kind"]]["speed"]) * maxi(int(e["fuel"]), 1) + 1


func _pick_value_target(st: GameState, e: Dictionary, targeted: Dictionary, caution: float) -> Dictionary:
	var edef: Dictionary = Defs.ENEMIES[e["kind"]]
	var best := {}
	var best_sc := -INF
	var hp: float = maxf(e["hp"], 8.0)
	for id in known:
		var s: Dictionary = st.structures.get(id, {})
		if s.is_empty():
			continue
		var v: float = VALUE.get(s["kind"], 2.0)
		if s.get("foundry", false) and st.story != null:
			v = st.story.foundry_value()
		v *= 1.0 + 0.4 * (1.0 - float(s["hp"]) / s["max_hp"])
		v /= 1.0 + 0.35 * targeted.get(id, 0)
		var danger := _line_threat(e["pos"], s["pos"], edef["alt"])
		var dist := Hex.distance(e["pos"], s["pos"])
		var sc := v * 10.0 / (1.0 + caution * danger / hp * 1.5) - dist * 0.25 + st.rng.randf() * 2.0
		if dist > _reach(e):
			sc -= 50.0
		if sc > best_sc:
			best_sc = sc
			best = s
	if best.is_empty():
		return {}
	return {"type": "structure", "id": best["id"], "pos": best["pos"]}


func _pick_aa_target(st: GameState, e: Dictionary, targeted: Dictionary) -> Dictionary:
	var best := {}
	var best_sc := -INF
	var hp: float = maxf(e["hp"], 8.0)
	for id in known:
		var s: Dictionary = st.structures.get(id, {})
		if s.is_empty() or s["kind"] == "capital" or not Defs.STRUCTURES[s["kind"]].has("weapon"):
			continue
		var base: float = 5.0 + struct_kills.get(id, 0) * 3.0
		if s["kind"] == "sam" or s["kind"] == "laser":
			base += 3.0
		base /= 1.0 + 0.5 * targeted.get(id, 0)
		var danger := _line_threat(e["pos"], s["pos"], "low")
		var sc: float = base * 10.0 / (1.0 + 0.3 * danger / hp) - Hex.distance(e["pos"], s["pos"]) * 0.4 + st.rng.randf() * 2.0
		if Hex.distance(e["pos"], s["pos"]) > _reach(e):
			sc -= 50.0
		if sc > best_sc:
			best_sc = sc
			best = {"type": "structure", "id": s["id"], "pos": s["pos"]}
	for uid in seen_units:
		var info: Dictionary = seen_units[uid]
		if not st.units.has(uid) or st.units[uid]["kind"] != "frigate" or st.turn - info["turn"] > 1:
			continue
		var sc := 70.0 - Hex.distance(e["pos"], info["pos"]) * 0.4 + st.rng.randf() * 2.0
		if sc > best_sc:
			best_sc = sc
			best = {"type": "unit", "id": uid, "pos": info["pos"]}
	if best.is_empty():
		return _pick_value_target(st, e, targeted, 0.6)
	return best


func _pick_fighter_target(st: GameState, e: Dictionary, targeted: Dictionary) -> Dictionary:
	var best := {}
	var best_d := 9
	for uid in seen_units:
		var info: Dictionary = seen_units[uid]
		if not st.units.has(uid) or st.turn - info["turn"] > 1:
			continue
		var d := Hex.distance(e["pos"], info["pos"])
		if st.units[uid]["kind"] == "frigate":
			d += 2
		if d < best_d:
			best_d = d
			best = {"type": "unit", "id": uid, "pos": info["pos"]}
	if not best.is_empty():
		return best
	var ally := {}
	var ally_d := 7
	for a in st.enemies.values():
		if a["id"] == e["id"] or a["state"] == "rtb":
			continue
		var role: String = Defs.ENEMIES[a["kind"]]["role"]
		if role != "strike" and role != "sead":
			continue
		var d := Hex.distance(e["pos"], a["pos"])
		if d < ally_d:
			ally_d = d
			ally = a
	if not ally.is_empty():
		return {"type": "escort", "id": ally["id"], "pos": ally["pos"]}
	var strafe := {}
	var strafe_sc := -INF
	for id in known:
		var s: Dictionary = st.structures.get(id, {})
		if s.is_empty() or s["kind"] == "capital" or s["kind"] == "city":
			continue
		var danger := _line_threat(e["pos"], s["pos"], "high")
		var sc: float = VALUE.get(s["kind"], 2.0) * 10.0 / (1.0 + danger / 20.0) - Hex.distance(e["pos"], s["pos"]) * 0.5 + st.rng.randf() * 2.0
		sc /= 1.0 + 0.5 * targeted.get(id, 0)
		if sc > strafe_sc:
			strafe_sc = sc
			strafe = {"type": "structure", "id": s["id"], "pos": s["pos"]}
	if strafe.is_empty():
		return _pick_value_target(st, e, targeted, 0.5)
	return strafe


## Hex the aircraft is heading for, as currently understood (used by the UI's intent lines too).
func target_hex(st: GameState, e: Dictionary) -> Vector2i:
	var t: Dictionary = e["target"]
	match t.get("type", ""):
		"structure":
			var s: Dictionary = st.structures.get(t["id"], {})
			return s["pos"] if not s.is_empty() else Hex.INVALID
		"unit":
			var u: Dictionary = st.units.get(t["id"], {})
			return u["pos"] if not u.is_empty() else t.get("pos", Hex.INVALID)
		"escort":
			var a: Dictionary = st.enemies.get(t["id"], {})
			return a["pos"] if not a.is_empty() else Hex.INVALID
		"scout", "exit":
			return t["pos"]
	return Hex.INVALID


# --------------------------------------------------------------------------------------------
# Path planning
# --------------------------------------------------------------------------------------------

func plan_paths(st: GameState) -> Dictionary:
	var paths := {}
	for e in _ordered_enemies(st):
		var edef: Dictionary = Defs.ENEMIES[e["kind"]]
		var t: Dictionary = e["target"]
		if t.is_empty():
			paths[e["id"]] = []
			continue
		var goal: Vector2i = e["pos"]
		var stop := 0
		match t["type"]:
			"structure":
				var s: Dictionary = st.structures.get(t["id"], {})
				goal = s["pos"] if not s.is_empty() else e["pos"]
				stop = edef["attack_range"]
			"unit":
				var u: Dictionary = st.units.get(t["id"], {})
				if u.is_empty():
					goal = e["pos"]
				else:
					var spotted := false
					for other in st.enemies.values():
						if Hex.distance(other["pos"], u["pos"]) <= maxi(Defs.ENEMIES[other["kind"]]["vision"], 1) + 1:
							spotted = true
							break
					goal = u["pos"] if spotted else t["pos"]
				stop = edef["attack_range"]
			"escort":
				var ally_path: Array = paths.get(t["id"], [])
				if not ally_path.is_empty():
					goal = ally_path[ally_path.size() - 1]
				elif st.enemies.has(t["id"]):
					goal = st.enemies[t["id"]]["pos"]
				stop = 1
			_:
				goal = t["pos"]
		if Hex.distance(e["pos"], goal) <= stop:
			paths[e["id"]] = []
			continue
		var full := _astar(st, e, goal)
		if full.is_empty():
			paths[e["id"]] = []
			continue
		if stop > 0:
			for i in full.size():
				if Hex.distance(full[i], goal) <= stop:
					full = full.slice(0, i + 1)
					break
		paths[e["id"]] = full.slice(0, edef["speed"])
	return paths


func _astar(st: GameState, e: Dictionary, goal: Vector2i) -> Array:
	var edef: Dictionary = Defs.ENEMIES[e["kind"]]
	var low: bool = edef["alt"] == "low"
	var caution: float = 1.2 if e["state"] == "rtb" else CAUTION[edef["role"]]
	if e["kind"] == "stealth":
		caution = 0.35
	var tm := threat_low if low else threat_high
	var hp: float = maxf(e["hp"], 8.0)
	var tiles := st.tiles
	var passable := func(h: Vector2i) -> bool:
		return tiles.has(h) and (not low or tiles[h] != "mountain")
	var cost := func(h: Vector2i) -> float:
		return 1.0 + caution * tm.get(h, 0.0) / hp * 3.0
	return Pathfinder.find(e["pos"], goal, passable, cost)


# --------------------------------------------------------------------------------------------
# Wave planning (the adaptive part)
# --------------------------------------------------------------------------------------------

func plan_wave(st: GameState, w: int) -> Dictionary:
	compute_threat(st)
	var d: Dictionary = st.diff()
	var alive := float(st.carriers.size())
	var budget: float = (d["base"] + d["growth"] * (w - 1)) * (0.45 + 0.55 * alive / float(d["carriers"]))
	if st.story != null:
		budget *= st.story.budget_mult()
	var flak := 0.0
	var sam := 0.0
	var laser := 0.0
	var air := 0.0
	for id in known:
		var s: Dictionary = st.structures.get(id, {})
		if s.is_empty():
			continue
		match s["kind"]:
			"flak":
				flak += 1.0
			"capital":
				flak += 0.5
			"sam":
				sam += 1.0
			"laser":
				laser += 1.0
			"airbase":
				air += 1.5
	for uid in seen_units:
		if not st.units.has(uid) or st.turn - seen_units[uid]["turn"] > 3:
			continue
		if st.units[uid]["kind"] == "interceptor":
			air += 1.0
		else:
			flak += 1.0
	var low_t: float = flak + laser * 1.5 + kills_by.get("flak", 0) * 0.35 + kills_by.get("frigate", 0) * 0.35 + kills_by.get("laser", 0) * 0.4
	var high_t: float = sam * 1.6 + laser * 1.5 + kills_by.get("sam", 0) * 0.45
	var air_t: float = air + kills_by.get("interceptor", 0) * 0.4

	var weights := {"drone": 1.2, "fighter": 1.4, "gunship": 2.0, "bomber": 3.0}
	# New aircraft types are phased in over three waves instead of appearing all at once.
	var missile_wave: int = Defs.ENEMIES["missile"]["min_wave"]
	var stealth_wave: int = Defs.ENEMIES["stealth"]["min_wave"]
	if w >= missile_wave:
		weights["missile"] = 1.4 * minf(1.0, (w - missile_wave + 1) / 3.0)
	if w >= stealth_wave:
		weights["stealth"] = 1.6 * minf(1.0, (w - stealth_wave + 1) / 3.0)
	if st.story != null and not st.story.allow_new_types():
		weights.erase("missile")
		weights.erase("stealth")
	var notes: Array = []
	if high_t > low_t * 1.3 and high_t >= 2.0:
		weights["gunship"] *= 2.2
		weights["bomber"] *= 0.55
		weights["drone"] *= 1.3
		if weights.has("missile"):
			weights["missile"] *= 1.8
		if weights.has("stealth"):
			weights["stealth"] *= 0.7
		notes.append("Your SAM coverage is forcing the enemy low: expect gunships and sea-skimming missiles.")
	elif low_t > high_t * 1.3 and low_t >= 2.0:
		weights["bomber"] *= 1.7
		weights["gunship"] *= 0.6
		weights["drone"] *= 0.6
		if weights.has("stealth"):
			weights["stealth"] *= 1.5
		notes.append("Your flak belts have the enemy flying high: expect heavy bombers above the guns.")
	if air_t >= 2.0:
		weights["fighter"] *= 1.0 + minf(air_t * 0.35, 2.0)
		notes.append("Interceptor activity noted: bombers will fly with fighter escorts.")
	if weights.has("stealth"):
		var stealth_kills: int = st.stats["kills"].get("stealth", 0)
		if stealth_kills >= 2:
			weights["stealth"] *= 0.5
			notes.append("Stealth losses are mounting: the enemy is holding back its stealth wing.")
		elif not st.has_tech("phased_array"):
			weights["stealth"] *= 1.4
			if w == Defs.ENEMIES["stealth"]["min_wave"]:
				notes.append("Stealth bombers sighted at enemy airfields. Phased Array radar can detect them.")
	if st.story != null and st.story.glass == "cracked" and not st.story.flags.has("glass_noted"):
		st.story.flags["glass_noted"] = true
		notes.append("The Glass Shield is gone: Silica Point is now on their target list.")
	if st.story != null and st.story.budget_mult() > 1.05:
		notes.append("Political pressure in the Steering Council is putting more aircraft in the air.")
	elif st.story != null and st.story.budget_mult() < 0.95:
		notes.append("Their squadrons are thinner than usual tonight.")
	if known.size() <= baseline_known + 1 and w >= 2:
		weights["drone"] *= 2.0
		notes.append("Enemy planners know little of your defenses: reconnaissance drones will probe the islands.")

	var units: Array = []
	while budget >= 2.0 and units.size() < 26:
		var pick := _weighted_pick(weights, budget, st.rng)
		if pick == "":
			break
		units.append(pick)
		budget -= Defs.ENEMIES[pick]["cost"]
	if not units.has("bomber") and not units.has("stealth") and units.size() >= 2:
		units[0] = "bomber"

	var sector := _choose_sector(st)
	if last_sector != "" and sector != last_sector and sector_losses.get(last_sector, 0.0) >= 8.0:
		notes.append("Heavy losses on the %s approach have pushed the enemy to a new vector." % last_sector)
	if sector == last_sector:
		sector_streak += 1
	else:
		sector_streak = 0
	last_sector = sector
	for k in sector_losses.keys():
		sector_losses[k] *= 0.7
	doctrine = " ".join(notes) if not notes.is_empty() else "A standard combined-arms raid is forming."
	return {"units": units, "sector": sector, "doctrine": doctrine}


func _weighted_pick(weights: Dictionary, budget: float, rng: RandomNumberGenerator) -> String:
	var total := 0.0
	for k in weights:
		if Defs.ENEMIES[k]["cost"] <= budget:
			total += weights[k]
	if total <= 0.0:
		return ""
	var r := rng.randf() * total
	for k in weights:
		if Defs.ENEMIES[k]["cost"] > budget:
			continue
		r -= weights[k]
		if r <= 0.0:
			return k
	return ""


func _choose_sector(st: GameState) -> String:
	var cap: Dictionary = st.capital()
	var target: Vector2i = cap["pos"] if not cap.is_empty() else Hex.offset_to_axial(st.width / 4, st.height / 2)
	var best := "East"
	var best_sc := INF
	for sec in Defs.SECTORS:
		var hexes := sector_hexes(st, sec)
		if hexes.is_empty():
			continue
		var mid: Vector2i = hexes[hexes.size() / 2]
		var danger := (_line_threat(mid, target, "low") + _line_threat(mid, target, "high")) * 0.5
		var sc: float = danger * 0.6 + sector_losses.get(sec, 0.0) * 1.2 + st.rng.randf() * 8.0 + Hex.distance(mid, target) * 0.4
		if sec == last_sector:
			sc += 3.0 * (sector_streak + 1)
		if sc < best_sc:
			best_sc = sc
			best = sec
	return best


# --------------------------------------------------------------------------------------------
# Persistence
# --------------------------------------------------------------------------------------------

func to_dict() -> Dictionary:
	return {
		"known": known, "seen_units": seen_units, "loss_heat": loss_heat, "kills_by": kills_by,
		"struct_kills": struct_kills, "sector_losses": sector_losses, "last_sector": last_sector,
		"sector_streak": sector_streak, "doctrine": doctrine, "baseline_known": baseline_known,
	}


func from_dict(d: Dictionary) -> void:
	known = d.get("known", {})
	seen_units = d.get("seen_units", {})
	loss_heat = d.get("loss_heat", {})
	kills_by = d.get("kills_by", {})
	struct_kills = d.get("struct_kills", {})
	sector_losses = d.get("sector_losses", {})
	last_sector = d.get("last_sector", "")
	sector_streak = d.get("sector_streak", 0)
	doctrine = d.get("doctrine", "")
	baseline_known = d.get("baseline_known", 0)
