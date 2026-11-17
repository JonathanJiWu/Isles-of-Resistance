class_name TestBot
extends RefCounted
## A simple heuristic commander used by the headless test suite to play complete campaigns.

const TECH_PRIORITY := [
	"guided_missiles", "logistics", "rapid_flak", "improved_radar", "hardened_shelters", "phased_array",
	"proximity_fuzes", "jet_interceptors", "naval_aa", "cruise_missiles", "coastwatchers", "satellite_uplink",
	"directed_energy", "precision_strikes", "deception",
]

const HUNTER_PRIORITY := [
	"guided_missiles", "logistics", "cruise_missiles", "improved_radar", "jet_interceptors", "precision_strikes",
	"rapid_flak", "hardened_shelters", "phased_array", "satellite_uplink", "proximity_fuzes", "naval_aa",
	"coastwatchers", "directed_energy", "deception",
]

var rng := RandomNumberGenerator.new()
var skill := 1.0   # 0 = passive, 0.5 = novice (builds every other turn, no air power), 1 = normal
var strategy := "defend"   # defend | hunter


func _init(seed_value: int = 1, p_skill: float = 1.0, p_strategy: String = "defend") -> void:
	rng.seed = seed_value
	skill = p_skill
	strategy = p_strategy


func play_turn(st: GameState) -> void:
	if skill <= 0.0:
		return
	_research(st)
	if skill >= 1.0:
		_repairs(st)
		_strikes(st)
		_units(st)
		_produce(st)
	if skill >= 1.0 or st.turn % 2 == 0:
		_build(st)


func _research(st: GameState) -> void:
	# Research strictly in priority order, saving up for the next tech on the list.
	for id in (HUNTER_PRIORITY if strategy == "hunter" else TECH_PRIORITY):
		if st.has_tech(id) or st.tech_status(id) == "locked":
			continue
		if st.research_check(id) == "":
			st.research(id)
			continue
		return


func _repairs(st: GameState) -> void:
	var list: Array = st.structures.values()
	list.sort_custom(func(a, b): return EnemyAI.VALUE.get(a["kind"], 1.0) > EnemyAI.VALUE.get(b["kind"], 1.0))
	for s in list:
		if float(s["hp"]) / s["max_hp"] < 0.75 and st.repair_check(s["id"]) == "":
			st.repair(s["id"])


func _strikes(st: GameState) -> void:
	for s in st.structures.values():
		if s["kind"] != "airbase" and s["kind"] != "missile":
			continue
		var targets := st.strike_targets(s["id"])
		if not targets.is_empty() and st.strike_check(s["id"], targets[0]) == "" and st.supplies > (40 if strategy == "hunter" else 60):
			st.strike(s["id"], targets[0])
	var recon_now := st.turn > 8 and st.turn % 4 == 0 and st.supplies > 80
	if strategy == "hunter":
		recon_now = st.supplies > 30
	if st.recon_used_turn != st.turn and recon_now and not st.carriers.is_empty():
		var c: Dictionary = st.carriers.values()[st.turn % st.carriers.size()]
		var guess: Vector2i = c["seen_pos"] if c["seen_pos"] != Hex.INVALID else Hex.offset_to_axial(st.width - 3 - (st.turn % 3), 3 + (st.turn * 5) % (st.height - 6))
		if st.recon_check(guess) == "":
			st.recon_flight(guess)
			_strikes_only(st)


func _strikes_only(st: GameState) -> void:
	for s in st.structures.values():
		if s["kind"] != "airbase" and s["kind"] != "missile":
			continue
		var targets := st.strike_targets(s["id"])
		if not targets.is_empty() and st.strike_check(s["id"], targets[0]) == "":
			st.strike(s["id"], targets[0])


func _units(st: GameState) -> void:
	for u in st.units.values():
		if not st.units.has(u["id"]):
			continue
		var targets := st.unit_targets(u)
		if not targets.is_empty():
			st.unit_attack(u["id"], targets[0])
			continue
		if u["kind"] != "interceptor" or u["moved"]:
			continue
		var reach := st.unit_reachable(u)
		var best := Hex.INVALID
		var best_d := 999
		for e in st.enemies.values():
			if not st.enemy_detected(e):
				continue
			for h in reach:
				var d := Hex.distance(h, e["pos"])
				if d < best_d:
					best_d = d
					best = h
		if best != Hex.INVALID and best_d <= 1:
			st.move_unit(u["id"], best)
			var t2 := st.unit_targets(st.units[u["id"]])
			if not t2.is_empty():
				st.unit_attack(u["id"], t2[0])


func _count(st: GameState, kind: String) -> int:
	var n := 0
	for s in st.structures.values():
		if s["kind"] == kind:
			n += 1
	return n


func _choose_kind(st: GameState) -> String:
	var labs := _count(st, "lab")
	var flak := _count(st, "flak")
	var sams := _count(st, "sam")
	if strategy == "hunter":
		if st.turn >= 3 and _count(st, "airbase") < 1:
			return "airbase"
		if st.has_tech("cruise_missiles") and _count(st, "missile") < 3:
			return "missile"
	if st.turn >= 2 and labs < 1:
		return "lab"
	if _count(st, "harbor") < 1:
		return "harbor"
	if st.turn >= 5 and labs < 2:
		return "lab"
	if st.turn >= 8 and _count(st, "airbase") < 1:
		return "airbase"
	if st.turn >= 6 and _count(st, "radar") < 2:
		return "radar"
	if st.has_tech("directed_energy") and _count(st, "laser") < 3:
		return "laser"
	if st.has_tech("cruise_missiles") and _count(st, "missile") < 1:
		return "missile"
	if st.has_tech("hardened_shelters") and _count(st, "bunker") < 2:
		return "bunker"
	if st.has_tech("guided_missiles") and sams * 2 < flak:
		return "sam"
	return "flak"


func _build(st: GameState) -> void:
	var guard := 0
	while guard < 8:
		guard += 1
		var kind := _choose_kind(st)
		if st.supplies < st.build_cost(kind) + 10:
			return
		var spot := _best_spot(st, kind)
		if spot == Hex.INVALID:
			return
		if st.build(kind, spot).is_empty():
			return


func _best_spot(st: GameState, kind: String) -> Vector2i:
	var best := Hex.INVALID
	var best_sc := -INF
	var weapon: bool = Defs.STRUCTURES[kind].has("weapon")
	for h in st.explored:
		if st.build_check(kind, h) != "":
			continue
		var sc := rng.randf()
		for s in st.structures.values():
			var d := Hex.distance(s["pos"], h)
			if s["kind"] == "capital":
				sc += 6.0 / (1 + d)
			elif s["kind"] == "city":
				sc += 3.0 / (1 + d)
			elif weapon and Defs.STRUCTURES[s["kind"]].has("weapon") and d <= 1:
				sc -= 1.0
		if weapon and st.terrain(h) == "hills":
			sc += 1.0
		if not weapon and st.terrain(h) == "forest":
			sc += 0.8
		if kind == "missile" or kind == "radar" or (strategy == "hunter" and kind == "airbase"):
			sc += Hex.to_pixel(h).x / (60.0 if strategy == "hunter" else 200.0)
		if sc > best_sc:
			best_sc = sc
			best = h
	return best


func _produce(st: GameState) -> void:
	for s in st.structures.values():
		if s["kind"] == "airbase" and st.produce_check(s["id"], "interceptor") == "" and st.supplies > 50:
			st.produce(s["id"], "interceptor")
		elif s["kind"] == "harbor" and st.produce_check(s["id"], "frigate") == "" and st.supplies > 120:
			st.produce(s["id"], "frigate")
