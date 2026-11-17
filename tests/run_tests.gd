extends SceneTree
## Headless test suite.  Run with:
##   godot --headless --path . -s tests/run_tests.gd
## Add "-- --balance" to also print a balance report across many simulated campaigns.

var failures := 0
var checks := 0


func _init() -> void:
	var t0 := Time.get_ticks_msec()
	test_hex_math()
	test_map_generation()
	test_construction_and_economy()
	test_units_and_combat()
	test_research()
	test_save_roundtrip()
	test_determinism()
	test_events_wellformed()
	test_adaptive_ai()
	test_full_campaigns()
	if OS.get_cmdline_user_args().has("--balance"):
		balance_report()
	print("")
	print("%d checks, %d failures (%d ms)" % [checks, failures, Time.get_ticks_msec() - t0])
	quit(1 if failures > 0 else 0)


func check(cond: bool, msg: String) -> void:
	checks += 1
	if not cond:
		failures += 1
		print("  FAIL: ", msg)


func section(name: String) -> void:
	print("- ", name)


# --------------------------------------------------------------------------------------------

func test_hex_math() -> void:
	section("hex math")
	var a := Vector2i(0, 0)
	check(Hex.distance(a, Vector2i(3, -1)) == 3, "distance")
	check(Hex.neighbors(a).size() == 6, "six neighbours")
	for nb in Hex.neighbors(a):
		check(Hex.distance(a, nb) == 1, "neighbour distance 1")
	check(Hex.in_range(a, 2).size() == 19, "range 2 has 19 hexes")
	check(Hex.ring(a, 3).size() == 18, "ring 3 has 18 hexes")
	for h in [Vector2i(3, 5), Vector2i(-2, 7), Vector2i(10, 0)]:
		check(Hex.from_pixel(Hex.to_pixel(h)) == h, "pixel round trip %s" % h)
		check(Hex.from_pixel(Hex.to_pixel(h) + Vector2(10, -8)) == h, "pixel inside hex %s" % h)
	for col in 6:
		for row in 6:
			check(Hex.axial_to_offset(Hex.offset_to_axial(col, row)) == Vector2i(col, row), "offset round trip")
	var ln := Hex.line(Vector2i(0, 0), Vector2i(4, -2))
	check(ln.size() == 5 and ln[0] == Vector2i(0, 0) and ln[4] == Vector2i(4, -2), "line endpoints")
	for i in 6:
		var e := Hex.edge(Vector2.ZERO, i)
		var mid := (e[0] + e[1]) * 0.5
		var toward := Hex.to_pixel(Hex.DIRS[i]).normalized()
		check(mid.normalized().dot(toward) > 0.99, "edge %d faces its neighbour" % i)
	var path := Pathfinder.find(Vector2i(0, 0), Vector2i(5, 0), func(_h): return true, func(_h): return 1.0)
	check(path.size() == 5 and path[4] == Vector2i(5, 0), "A* straight path")


func test_map_generation() -> void:
	section("map generation")
	for sd in range(1, 41):
		var m := MapGen.generate(sd * 101, Defs.MAP_W, Defs.MAP_H, 4, 3)
		check(m["tiles"].size() == Defs.MAP_W * Defs.MAP_H, "full grid seed %d" % sd)
		check(m["cities"].size() == 4, "4 cities seed %d" % sd)
		check(m["carriers"].size() >= 2, "carriers placed seed %d" % sd)
		var cap: Vector2i = m["capital"]
		check(not Defs.TERRAIN[m["tiles"][cap]]["water"] and m["tiles"][cap] != "mountain", "capital on buildable land")
		for c in m["cities"]:
			check(not Defs.TERRAIN[m["tiles"][c["pos"]]]["water"], "city on land")
			check(Hex.distance(c["pos"], cap) >= 4, "city spaced from capital")
		for c in m["carriers"]:
			check(m["tiles"][c] == "deep", "carrier in deep water")
	var m1 := MapGen.generate(777, Defs.MAP_W, Defs.MAP_H, 4, 2)
	var m2 := MapGen.generate(777, Defs.MAP_W, Defs.MAP_H, 4, 2)
	check(m1["tiles"] == m2["tiles"] and m1["capital"] == m2["capital"], "map generation deterministic")


func test_construction_and_economy() -> void:
	section("construction & economy")
	var st := GameState.create(42, "veteran")
	check(st.turn == 1 and st.phase == "player", "starts on player turn 1")
	check(st.structures.has(st.capital_id), "capital exists")
	check(st.income() > 0 and st.rp_income() > 0, "positive income")
	var cap: Dictionary = st.capital()
	check(st.build_check("flak", cap["pos"]) == "Hex is occupied", "cannot build on capital")
	check(st.build_check("sam", cap["pos"]).begins_with("Requires"), "SAM locked by tech")
	var water := Hex.INVALID
	var spot := Hex.INVALID
	for h in st.explored:
		if st.is_water(h) and water == Hex.INVALID:
			water = h
		if spot == Hex.INVALID and st.build_check("flak", h) == "":
			spot = h
	check(st.build_check("flak", water) == "Must be built on land", "no building on water")
	check(spot != Hex.INVALID, "found a buildable hex")
	var before := st.supplies
	var s := st.build("flak", spot)
	check(not s.is_empty() and st.supplies == before - 30, "build deducts cost")
	check(st.build("flak", spot).is_empty(), "cannot double-build")
	var refund := st.demolish_refund(s)
	check(st.demolish(s["id"]) and st.supplies == before - 30 + refund, "demolish refunds")
	check(st.demolish_check(st.capital_id) != "", "capital cannot be demolished")
	cap["hp"] -= 40
	var cost := st.repair_cost(cap)
	var sup := st.supplies
	check(st.repair(st.capital_id) and cap["hp"] == cap["max_hp"] and st.supplies == sup - cost, "repair works")
	check(st.repair_check(st.capital_id) != "", "cannot repair twice")
	var mountain := Hex.INVALID
	for h in st.explored:
		if st.terrain(h) == "mountain" and st.structure_at(h).is_empty():
			mountain = h
	if mountain != Hex.INVALID:
		check(st.build_check("flak", mountain) != "", "flak not on mountain")
		check(st.build_check("radar", mountain) == "", "radar allowed on mountain")


func test_units_and_combat() -> void:
	section("units & combat")
	var st := GameState.create(7, "veteran")
	st.supplies = 1000
	var spot := Hex.INVALID
	for h in st.explored:
		if st.build_check("airbase", h) == "":
			spot = h
			break
	var ab := st.build("airbase", spot)
	check(not ab.is_empty(), "airbase built")
	var u := st.produce(ab["id"], "interceptor")
	check(not u.is_empty() and u["pos"] == ab["pos"], "interceptor deployed on airbase")
	check(st.unit_reachable(u).is_empty(), "fresh unit cannot move")
	st.produce(ab["id"], "interceptor")
	check(st.produce_check(ab["id"], "interceptor") != "", "squadron limit enforced")
	st.end_turn()
	if not st.units.has(u["id"]):
		return
	var reach := st.unit_reachable(u)
	check(not reach.is_empty(), "unit can move next turn")
	for h in reach:
		check(Hex.distance(h, u["pos"]) <= st.u_move(u), "reach within move")
		check(Hex.distance(h, ab["pos"]) <= 6, "reach within fuel range")
	# Spawn an enemy bomber next to the interceptor and attack it.
	st.compute_visibility()
	var e := st._add_enemy("bomber", u["pos"] + Vector2i(1, 0), "East")
	st.compute_visibility()
	check(st.unit_targets(u).has(e["id"]), "adjacent bomber is targetable")
	var events := st.unit_attack(u["id"], e["id"])
	check(not events.is_empty(), "attack produced events")
	var has_shot := false
	for ev in events:
		if ev["type"] == "shot":
			has_shot = true
	check(has_shot, "attack produced a shot event")
	check(st.unit_targets(u).is_empty(), "unit cannot attack twice")
	# Stealth detection.
	var far := Hex.INVALID
	for h in st.radar_cov:
		var close := false
		for s in st.structures.values():
			if Hex.distance(s["pos"], h) <= 1:
				close = true
		for uu in st.units.values():
			if Hex.distance(uu["pos"], h) <= 1:
				close = true
		if not close:
			far = h
			break
	if far != Hex.INVALID:
		var sb := st._add_enemy("stealth", far, "East")
		check(not st.enemy_detected(sb), "stealth invisible without phased array")
		st.techs["phased_array"] = true
		check(st.enemy_detected(sb), "phased array reveals stealth in radar coverage")


func test_research() -> void:
	section("research")
	var st := GameState.create(9, "recruit")
	check(st.tech_status("phased_array") == "locked", "tier 2 locked")
	st.rp = 0
	check(st.research_check("improved_radar") == "Not enough research points", "needs RP")
	st.rp = 500
	var cap: Dictionary = st.capital()
	var old_max: int = cap["max_hp"]
	check(st.research("hardened_shelters"), "research hardened shelters")
	check(cap["max_hp"] > old_max, "capital max HP increased")
	check(st.build_locked_reason("bunker") == "", "bunker unlocked")
	check(st.research("improved_radar") and st.tech_status("phased_array") == "available", "prereq unlocks")
	var radar := {}
	for s in st.structures.values():
		if s["kind"] == "radar":
			radar = s
	if not radar.is_empty():
		check(st.s_vision(radar) >= 6, "improved radar extends vision")


func test_save_roundtrip() -> void:
	section("save / load")
	var st := GameState.create(1234, "veteran")
	var bot := TestBot.new(5)
	for i in 7:
		bot.play_turn(st)
		st.end_turn()
		if st.result != "":
			break
	var data := st.to_dict()
	var bytes := var_to_bytes(data)
	var restored := GameState.from_dict(bytes_to_var(bytes))
	check(restored != null, "restored state")
	check(var_to_bytes(restored.to_dict()) == bytes, "save round trip is lossless")
	# Both copies must evolve identically.
	if st.result == "":
		bot = TestBot.new(9)
		var bot2 := TestBot.new(9)
		for i in 4:
			bot.play_turn(st)
			bot2.play_turn(restored)
			st.end_turn()
			restored.end_turn()
		check(var_to_bytes(st.to_dict()) == var_to_bytes(restored.to_dict()), "restored game continues identically")


func test_determinism() -> void:
	section("determinism")
	var a := _run_campaign(555, "veteran", 1.0, 12)
	var b := _run_campaign(555, "veteran", 1.0, 12)
	check(var_to_bytes(a.to_dict()) == var_to_bytes(b.to_dict()), "same seed and actions give same game")


func test_events_wellformed() -> void:
	section("event stream")
	var st := GameState.create(31337, "commander")
	var bot := TestBot.new(3)
	var known_types := ["phase", "beat_start", "beat_end", "move", "spawn", "volley_start", "volley_end", "shot",
		"attack", "damage", "destroyed", "exit", "log", "wave", "wave_cleared", "turn", "game_over", "strike", "recon"]
	var depth_ok := true
	var types_ok := true
	for i in 30:
		bot.play_turn(st)
		var events := st.end_turn()
		var depth := 0
		for ev in events:
			if not known_types.has(ev["type"]):
				types_ok = false
				print("    unknown event type ", ev["type"])
			if ev["type"] == "volley_start" or ev["type"] == "beat_start":
				depth += 1
			elif ev["type"] == "volley_end" or ev["type"] == "beat_end":
				depth -= 1
			if depth < 0 or depth > 1:
				depth_ok = false
		if depth != 0:
			depth_ok = false
		if st.result != "":
			break
	check(types_ok, "all event types known")
	check(depth_ok, "volley/beat markers balanced and not nested")


func _build_known(st: GameState, kind: String, n: int) -> void:
	var placed := 0
	var cap: Dictionary = st.capital()
	for h in Hex.in_range(cap["pos"], 6):
		if placed >= n:
			break
		if st.build_check(kind, h) == "":
			var s := st.build(kind, h)
			st.ai.reveal(s["id"])
			placed += 1


func _avg_mix(st: GameState, samples: int) -> Dictionary:
	var mix := {}
	var total := 0
	for i in samples:
		var plan := st.ai.plan_wave(st, 6)
		for k in plan["units"]:
			mix[k] = mix.get(k, 0) + 1
			total += 1
	for k in mix:
		mix[k] = float(mix[k]) / total
	return mix


func test_adaptive_ai() -> void:
	section("adaptive enemy AI")
	var sam_heavy := GameState.create(808, "veteran")
	sam_heavy.supplies = 5000
	sam_heavy.techs["guided_missiles"] = true
	_build_known(sam_heavy, "sam", 5)
	var flak_heavy := GameState.create(808, "veteran")
	flak_heavy.supplies = 5000
	_build_known(flak_heavy, "flak", 6)
	var m_sam := _avg_mix(sam_heavy, 30)
	var m_flak := _avg_mix(flak_heavy, 30)
	var low_sam: float = m_sam.get("gunship", 0.0) + m_sam.get("missile", 0.0)
	var low_flak: float = m_flak.get("gunship", 0.0) + m_flak.get("missile", 0.0)
	check(low_sam > low_flak, "SAM-heavy defenses draw more low-altitude attackers (%.2f vs %.2f)" % [low_sam, low_flak])
	check(m_flak.get("bomber", 0.0) > m_sam.get("bomber", 0.0), "flak-heavy defenses draw more high bombers (%.2f vs %.2f)" % [m_flak.get("bomber", 0.0), m_sam.get("bomber", 0.0)])
	check(sam_heavy.ai.doctrine.contains("low"), "doctrine explains the shift: " + sam_heavy.ai.doctrine)

	# Forest camouflage: unseen from 2 hexes, spotted from 1.
	var st := GameState.create(4242, "veteran")
	st.supplies = 5000
	var forest := Hex.INVALID
	for h in st.explored:
		if st.terrain(h) == "forest" and st.build_check("lab", h) == "":
			forest = h
			break
	if forest != Hex.INVALID:
		var lab := st.build("lab", forest)
		var drone := st._add_enemy("drone", forest + Hex.DIRS[0] * 2, "East")
		st.ai.update_known(st)
		check(not st.ai.known.has(lab["id"]), "forest hides a lab from a drone 2 hexes away")
		drone["pos"] = forest + Hex.DIRS[0]
		st.ai.update_known(st)
		check(st.ai.known.has(lab["id"]), "drone spots the forest lab from an adjacent hex")

	# Decoys attract bombers like a real lab would; firing reveals a defense.
	var st2 := GameState.create(99, "veteran")
	st2.supplies = 5000
	st2.techs["deception"] = true
	var cap: Dictionary = st2.capital()
	var decoy := {}
	for h in Hex.in_range(cap["pos"], 4):
		if Hex.distance(h, cap["pos"]) >= 3 and st2.build_check("decoy", h) == "":
			decoy = st2.build("decoy", h)
			break
	if not decoy.is_empty():
		st2.ai.reveal(decoy["id"])
		var hits := 0
		for i in 20:
			var b := st2._add_enemy("bomber", decoy["pos"] + Hex.DIRS[1] * 3, "North")
			var t := st2.ai._pick_value_target(st2, b, {st2.capital_id: 2}, 1.0)
			if t.get("id", -1) == decoy["id"]:
				hits += 1
			st2.enemies.erase(b["id"])
		check(hits >= 5, "with the Capital already targeted, bombers divert to the decoy (%d/20)" % hits)


func test_full_campaigns() -> void:
	section("full campaigns")
	for diff in Defs.DIFFICULTY_ORDER:
		var st := _run_campaign(2024, diff, 1.0, 80)
		check(st.result != "", "%s campaign finished (turn %d)" % [diff, st.turn])
		print("    %-9s %-7s turn %2d  wave %2d/%d  score %5d  kills %3d  carriers sunk %d" % [diff, st.result, st.turn, st.wave, st.waves_total, st.score, st.stats["kills_total"], st.stats["carriers_sunk"]])
	var passive := _run_campaign(2024, "recruit", 0.0, 80)
	check(passive.result == "defeat", "a passive commander loses (got %s on turn %d)" % [passive.result, passive.turn])


func _run_campaign(sd: int, diff: String, skill: float, max_turns: int, strategy: String = "defend") -> GameState:
	var st := GameState.create(sd, diff)
	var bot := TestBot.new(sd, skill, strategy)
	while st.result == "" and st.turn < max_turns:
		bot.play_turn(st)
		st.end_turn()
	return st


func balance_report() -> void:
	print("")
	var n := 24
	print("Balance report (%d seeds per row; normal = full bot, novice = half-hearted bot)" % n)
	var only := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--only="):
			only = a.substr(7)
	for diff in Defs.DIFFICULTY_ORDER:
		if only != "" and diff != only:
			continue
		for skill in [1.0, 0.5]:
			var wins := 0
			var turns := 0
			var cities := 0
			var wave_dmg := {}
			var wave_runs := {}
			var lost_wave := 0
			for i in n:
				var st := _run_campaign(1000 + i * 37, diff, skill, 90)
				if st.result == "victory":
					wins += 1
				else:
					lost_wave += st.wave
				turns += st.turn
				cities += st.stats["cities_lost"]
				for w in range(1, st.wave + 1):
					wave_runs[w] = wave_runs.get(w, 0) + 1
					wave_dmg[w] = wave_dmg.get(w, 0) + st.stats["wave_damage"].get(w, 0)
			var curve: Array = []
			for w in range(1, Defs.DIFFICULTY[diff]["waves"] + 1):
				if wave_runs.has(w):
					curve.append(str(int(round(float(wave_dmg[w]) / wave_runs[w]))))
			var losses := n - wins
			print("  %-9s %-6s wins %5.1f%%  avg turn %4.1f  cities lost %.1f  avg wave reached on loss %s" % [diff, "normal" if skill >= 1.0 else "novice", 100.0 * wins / n, float(turns) / n, float(cities) / n, ("%.1f" % (float(lost_wave) / losses)) if losses > 0 else "-"])
			print("            damage per wave: " + " ".join(curve))
	for diff in Defs.DIFFICULTY_ORDER:
		if only != "" and diff != only:
			continue
		var passive_turns := 0
		for i in 6:
			passive_turns += _run_campaign(2000 + i, diff, 0.0, 90).turn
		print("  passive commander survives %.1f turns on %s" % [passive_turns / 6.0, diff])
