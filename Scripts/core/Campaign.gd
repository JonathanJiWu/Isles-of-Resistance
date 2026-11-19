class_name Campaign
extends RefCounted
## The story layer of a campaign: acts, directives (political decisions), public Resolve and
## Hesperian Commitment, the Foundry and its Glass Shield, cyber operations, news broadcasts,
## intercepted enemy chatter, Intel Archive unlocks and epilogues.
## Uses its own RNG so narrative flavour never perturbs combat outcomes.

const FOUNDRY_INCOME := 6
const FOUNDRY_RP := 3
const DIRECTIVE_FRACTIONS := [0.1, 0.2, 0.4, 0.5, 0.6, 0.7, 0.8, 0.92]

var resolve := 60
var escalation := 1               # 0 gray zone, 1 quarantine, 2 blockade, 3 strikes, 4 assault
var ally := 50
var flags := {}
var choices := {}
var schedule: Array = []          # [[directive_id, trigger_wave], ...]
var next_directive := 0
var pending := ""
var budget_mods: Array = []       # [{"mult": float, "waves": int}]
var glass := "intact"
var foundry_id := -1
var foundry_mult := 1.0
var accuracy_bonus := 0.0
var strike_lock_until := 0
var no_new_types := 0
var convoy := 0
var reveal_next := 0
var act := -1
var codex := {}
var codex_unseen := 0
var news: Array = []
var beats: Array = []
var ops_ready := {}
var merge_used_wave := -1
var shipments := 0
var last_decision := ""
var used_intercepts := {}
var report := {}
var rng := RandomNumberGenerator.new()


# --------------------------------------------------------------------------------------------
# Setup and turn hooks
# --------------------------------------------------------------------------------------------

func setup(st: GameState) -> void:
	rng.seed = st.seed_value * 7 + 13
	_reset_report()
	# Silica Point: the city nearest the Capital becomes the Foundry.
	var cap: Dictionary = st.capital()
	var best := {}
	for s in st.structures.values():
		if s["kind"] == "city" and (best.is_empty() or Hex.distance(s["pos"], cap["pos"]) < Hex.distance(best["pos"], cap["pos"])):
			best = s
	if not best.is_empty():
		best["foundry"] = true
		best["name"] = Lore.FOUNDRY_CITY
		foundry_id = best["id"]
	var i := 0
	for c in st.carriers.values():
		c["name"] = Lore.CARRIER_NAMES[i % Lore.CARRIER_NAMES.size()]
		i += 1
	var total: int = st.waves_total
	var prev := 1
	for k in Lore.DIRECTIVE_ORDER.size():
		var w := clampi(int(round(DIRECTIVE_FRACTIONS[k] * total)), 1, total - 1)
		w = maxi(w, prev)
		schedule.append([Lore.DIRECTIVE_ORDER[k], w])
		prev = w
	unlock("start")
	_enter_act(st, 0)
	news = _make_news(st)


func _reset_report() -> void:
	report = {"kills": 0, "hits": 0, "cities_lost": [], "structures_lost": 0, "carriers_sunk": [], "wave": false}


func on_turn_start(st: GameState) -> void:
	var a := act_for_wave(st.wave, st.waves_total)
	if a > act:
		_enter_act(st, a)
	if pending == "" and next_directive < schedule.size() and st.wave >= int(schedule[next_directive][1]) and st.result == "":
		pending = schedule[next_directive][0]
	if st.turn > 1:
		news = _make_news(st)
	_reset_report()


func _enter_act(st: GameState, a: int) -> void:
	act = a
	var data: Dictionary = Lore.ACTS[a]
	beats.append({"title": data["title"], "speaker": data["speaker"], "text": data["text"], "act": true})
	unlock("act%d" % a)
	if a > 0:
		st.log_msg(data["title"], "intel")


static func act_for_wave(w: int, total: int) -> int:
	if w <= 0:
		return 0
	var a1 := maxi(1, int(round(total * 0.3)))
	var a2 := int(round(total * 0.6))
	if w <= a1:
		return 0
	if w <= a2:
		return 1
	if w <= total - 1:
		return 2
	return 3


# --------------------------------------------------------------------------------------------
# Economy hooks
# --------------------------------------------------------------------------------------------

func resolve_mult() -> float:
	if resolve >= 75:
		return 1.1
	if resolve >= 40:
		return 1.0
	if resolve >= 20:
		return 0.85
	return 0.7


func resolve_label() -> String:
	if resolve >= 75:
		return "Defiant"
	if resolve >= 40:
		return "Steady"
	if resolve >= 20:
		return "Shaken"
	return "Breaking"


func foundry_alive(st: GameState) -> bool:
	return st.structures.has(foundry_id)


func foundry_income(st: GameState) -> int:
	return int(round(FOUNDRY_INCOME * foundry_mult)) if foundry_alive(st) else 0


func foundry_rp(st: GameState) -> int:
	return int(round(FOUNDRY_RP * foundry_mult)) if foundry_alive(st) else 0


func budget_mult() -> float:
	var m := 1.0
	for b in budget_mods:
		m *= float(b["mult"])
	return m


func shipment_size() -> int:
	return maxi(0, int((ally - 45) * 0.7)) if ally >= 55 else 0


func adjust(key: String, delta: int) -> void:
	if key == "resolve":
		resolve = clampi(resolve + delta, 0, 100)
	elif key == "ally":
		ally = clampi(ally + delta, 0, 100)


# --------------------------------------------------------------------------------------------
# Battle hooks
# --------------------------------------------------------------------------------------------

func on_wave_launched(st: GameState, rep: Dictionary) -> void:
	report["wave"] = true
	for b in budget_mods:
		b["waves"] -= 1
	budget_mods = budget_mods.filter(func(b): return b["waves"] > 0)
	if no_new_types > 0:
		no_new_types -= 1
	var a := act_for_wave(st.wave, st.waves_total)
	rep["act"] = a
	var lines: Array = Lore.WAVE_LINES[a]
	rep["briefing"] = lines[rng.randi_range(0, lines.size() - 1)]
	if reveal_next > 0 and rep["composition"].is_empty():
		reveal_next -= 1
		rep["revealed"] = true


func on_enemy_lost(st: GameState, e: Dictionary) -> void:
	report["kills"] += 1
	unlock("kill:" + e["kind"])


func on_hit() -> void:
	report["hits"] += 1


func on_structure_destroyed(st: GameState, s: Dictionary) -> void:
	match s["kind"]:
		"city":
			report["cities_lost"].append(s["name"])
			adjust("resolve", -20 if s.get("foundry", false) else -12)
			if not flags.has("city_lost_once"):
				flags["city_lost_once"] = true
				beats.append({"speaker": "sol", "text": Lore.BEATS["first_city_lost"]["text"]})
			unlock("city_lost")
		"capital":
			pass
		_:
			report["structures_lost"] += 1
			if report["structures_lost"] <= 3:
				adjust("resolve", -2)


func on_carrier_sunk(st: GameState, c: Dictionary) -> void:
	report["carriers_sunk"].append(c.get("name", "a carrier"))
	adjust("resolve", 8)
	adjust("ally", 4)


func on_carrier_seen(st: GameState) -> void:
	if flags.has("carrier_seen"):
		return
	flags["carrier_seen"] = true
	beats.append({"speaker": "ardent", "text": Lore.BEATS["first_carrier"]["text"]})
	unlock("carrier_seen")


func on_wave_cleared(st: GameState, w: int) -> void:
	adjust("resolve", 3)
	var ship := shipment_size()
	if ship > 0:
		st.supplies += ship
		shipments += 1
		st.log_msg("Hesperian arms shipment received: +%d supplies." % ship, "good")
		if shipments == 1:
			beats.append({"speaker": "whitlow", "text": Lore.BEATS["ally_shipment"]["text"]})


func on_research(st: GameState, tech: String) -> void:
	unlock("tech:" + tech)


## Called at the end of the enemy phase. Emits one or two intercepted transmissions.
func on_enemy_phase_end(st: GameState, events: Array) -> void:
	if report["kills"] > report["hits"] + 1:
		adjust("resolve", 2)
	elif report["hits"] > report["kills"] + 2:
		adjust("resolve", -3)
	var triggers: Array = []
	for f in ["glass_cracked", "varo_purged", "kost_embarrassed"]:
		if flags.has(f) and not flags.has("said_" + f):
			flags["said_" + f] = true
			triggers.append(f)
	if flags.has("back_channel") and st.turn <= strike_lock_until:
		triggers.append("back_channel")
	if report["kills"] >= 5:
		triggers.append("heavy_loss")
	elif report["kills"] >= 2:
		triggers.append("loss")
	if report["hits"] >= 1:
		triggers.append("hit")
	if report["wave"]:
		triggers.append("launch")
	for e in st.enemies.values():
		if e["kind"] == "stealth":
			triggers.append("stealth")
			break
	triggers.append("generic")
	var said := 0
	for t in triggers:
		if said >= 2:
			break
		var line := _pick_intercept(t)
		if line.is_empty():
			continue
		events.append({"type": "intercept", "speaker": line[0], "text": line[1]})
		st.log_msg("[%s] %s" % [line[0], line[1]], "intercept")
		said += 1


func _pick_intercept(trigger: String) -> Array:
	var pool: Array = Lore.INTERCEPTS.get(trigger, [])
	if pool.is_empty():
		return []
	var fresh: Array = []
	for l in pool:
		if not used_intercepts.has(l[1]):
			fresh.append(l)
	if fresh.is_empty():
		if trigger != "generic" and trigger != "launch":
			return []
		fresh = pool
	var line: Array = fresh[rng.randi_range(0, fresh.size() - 1)]
	used_intercepts[line[1]] = true
	return line


# --------------------------------------------------------------------------------------------
# AI hooks
# --------------------------------------------------------------------------------------------

func foundry_value() -> float:
	return 9.5 if glass == "cracked" else 0.4


func allow_new_types() -> bool:
	return no_new_types <= 0


# --------------------------------------------------------------------------------------------
# Directives
# --------------------------------------------------------------------------------------------

func pending_data() -> Dictionary:
	return Lore.DIRECTIVES.get(pending, {})


func option_check(st: GameState, effects: Dictionary) -> String:
	if effects.get("supplies", 0) < 0 and st.supplies < -int(effects["supplies"]):
		return "Needs %d supplies" % -int(effects["supplies"])
	if effects.get("rp", 0) < 0 and st.rp < -int(effects["rp"]):
		return "Needs %d research" % -int(effects["rp"])
	return ""


static func effect_lines(effects: Dictionary) -> Array:
	var out: Array = []
	var names := {"ally": "Hesperian Commitment", "resolve": "Public Resolve", "supplies": "supplies", "rp": "research"}
	for k in ["supplies", "rp", "resolve", "ally"]:
		if effects.has(k):
			var v: int = effects[k]
			out.append("%s%d %s" % ["+" if v > 0 else "", v, names[k]])
	if effects.has("budget"):
		var b: Array = effects["budget"]
		var pct := int(round((float(b[0]) - 1.0) * 100.0))
		var span: String = "every remaining wave" if int(b[1]) > 20 else ("next wave" if int(b[1]) == 1 else "next %d waves" % int(b[1]))
		out.append("%s %s%d%%" % [span.capitalize(), "+" if pct > 0 else "", pct])
	if effects.has("free_tech"):
		out.append("Unlocks %s" % Defs.TECHS[effects["free_tech"]]["name"])
	if effects.has("glass"):
		out.append("Glass Shield cracks")
	if effects.has("foundry_mult"):
		out.append("Foundry output x%.1f" % float(effects["foundry_mult"]))
	if effects.has("accuracy"):
		out.append("+%d%% weapon accuracy" % int(round(float(effects["accuracy"]) * 100.0)))
	if effects.has("leak_known"):
		out.append("Enemy learns %d of your sites" % int(effects["leak_known"]))
	if effects.has("reveal_next"):
		out.append("Next wave revealed")
	if effects.has("strike_lock"):
		out.append("No carrier strikes for %d turns" % int(effects["strike_lock"]))
	if effects.has("no_new_types"):
		out.append("No Needles or Inkwash for %d waves" % int(effects["no_new_types"]))
	if effects.has("convoy"):
		out.append("+%d supplies per turn" % int(effects["convoy"]))
	if effects.has("gamble"):
		out.append("%d%% chance it works" % int(round(float(effects["gamble"]["chance"]) * 100.0)))
	return out


func choose(st: GameState, idx: int) -> bool:
	var d := pending_data()
	if d.is_empty():
		return false
	var opts: Array = d["options"]
	if idx < 0 or idx >= opts.size():
		return false
	var effects: Dictionary = opts[idx]["effects"]
	if option_check(st, effects) != "":
		return false
	var id := pending
	choices[id] = idx
	last_decision = "%s:%d" % [id, idx]
	pending = ""
	next_directive += 1
	st.log_msg("Directive · %s: %s." % [d["title"], opts[idx]["label"]], "intel")
	_apply(st, effects)
	if Lore.DECISION_NEWS.has(last_decision):
		news.push_front(Lore.DECISION_NEWS[last_decision])
	return true


func _apply(st: GameState, e: Dictionary) -> void:
	if e.has("gamble"):
		var g: Dictionary = e["gamble"]
		var ok := rng.randf() < float(g["chance"])
		st.log_msg("It worked." if ok else "It did not work.", "good" if ok else "bad")
		_apply(st, g["success"] if ok else g["fail"])
		return
	st.supplies += int(e.get("supplies", 0))
	st.rp = maxi(0, st.rp + int(e.get("rp", 0)))
	adjust("resolve", int(e.get("resolve", 0)))
	adjust("ally", int(e.get("ally", 0)))
	if e.has("budget"):
		budget_mods.append({"mult": float(e["budget"][0]), "waves": int(e["budget"][1])})
	if e.has("free_tech") and not st.has_tech(e["free_tech"]):
		st.techs[e["free_tech"]] = true
		st.log_msg("Technology acquired: %s." % Defs.TECHS[e["free_tech"]]["name"], "good")
	if e.has("foundry_mult"):
		foundry_mult *= float(e["foundry_mult"])
	if e.has("accuracy"):
		accuracy_bonus += float(e["accuracy"])
	if e.has("strike_lock"):
		strike_lock_until = st.turn + int(e["strike_lock"]) - 1
	if e.has("no_new_types"):
		no_new_types = maxi(no_new_types, int(e["no_new_types"]))
	if e.has("convoy"):
		convoy += int(e["convoy"])
	if e.has("convoy_set"):
		convoy = int(e["convoy_set"])
	if e.has("reveal_next"):
		reveal_next += int(e["reveal_next"])
	if e.has("leak_known"):
		_leak(st, int(e["leak_known"]))
	for f in e.get("flags", []):
		set_flag(st, f)
	if e.get("glass", "") == "cracked":
		crack_glass(st)


func set_flag(st: GameState, f: String) -> void:
	flags[f] = true
	unlock("flag:" + f)
	if f == "varo_purged":
		beats.append({"speaker": "kai", "text": Lore.BEATS["varo_purged"]["text"]})


func crack_glass(st: GameState) -> void:
	if glass == "cracked":
		return
	glass = "cracked"
	flags["glass_cracked"] = true
	unlock("flag:glass_cracked")
	beats.append({"speaker": "haldane", "text": Lore.BEATS["glass_cracked"]["text"]})
	st.log_msg("The Glass Shield has cracked: Silica Point is now on the enemy's target list.", "bad")


func _leak(st: GameState, n: int) -> void:
	var unknown: Array = []
	for s in st.structures.values():
		if not st.ai.known.has(s["id"]):
			unknown.append(s["id"])
	for i in mini(n, unknown.size()):
		var k := rng.randi_range(0, unknown.size() - 1)
		st.ai.reveal(unknown[k])
		unknown.remove_at(k)


# --------------------------------------------------------------------------------------------
# Cyber operations
# --------------------------------------------------------------------------------------------

func op_check(st: GameState, op: String) -> String:
	var d: Dictionary = Lore.OPS.get(op, {})
	if d.is_empty():
		return "Unknown operation"
	if st.phase != "player" or st.result != "":
		return "Unavailable"
	if act < int(d.get("min_act", 0)):
		return "Available from %s" % Lore.ACTS[int(d["min_act"])]["title"].split(" · ")[0].strip_edges()
	if st.turn < int(ops_ready.get(op, 0)):
		return "Recompiling: ready on turn %d" % int(ops_ready[op])
	if d.get("once_per_wave", false) and merge_used_wave == st.wave:
		return "Already run against this wave"
	if op == "rollback" and st.wave >= st.waves_total:
		return "No wave left to delay"
	if op == "merge_conflict" and st.wave >= st.waves_total:
		return "No wave left to confuse"
	if st.rp < int(d["cost"]):
		return "Needs %d research" % int(d["cost"])
	return ""


func run_op(st: GameState, op: String) -> bool:
	if op_check(st, op) != "":
		return false
	var d: Dictionary = Lore.OPS[op]
	st.rp -= int(d["cost"])
	ops_ready[op] = st.turn + int(d["cooldown"]) + (1 if int(d["cooldown"]) > 0 else 0)
	match op:
		"null_pointer":
			var forgot := 0
			for id in st.ai.known.keys():
				var s: Dictionary = st.structures.get(id, {})
				if s.is_empty() or s["kind"] == "capital" or s["kind"] == "city":
					continue
				st.ai.known.erase(id)
				forgot += 1
				if forgot >= 3:
					break
			st.log_msg("%s: the enemy lost track of %d of your sites." % [d["name"], forgot], "good")
		"rubber_duck":
			var confused := 0
			for e in st.enemies.values():
				if not st.enemy_detected(e):
					continue
				e["target"] = {}
				confused += 1
				if rng.randf() < 0.25:
					e["state"] = "rtb"
			st.ai.assign_targets(st)
			st.log_msg("%s: %d aircraft re-planning. Some are going home to ask questions." % [d["name"], confused], "good")
		"merge_conflict":
			merge_used_wave = st.wave
			reveal_next += 1
			budget_mods.append({"mult": 0.92, "waves": 1})
			st.log_msg("%s: their next wave will launch late-merged, 8%% weaker, and we'll see it coming." % d["name"], "good")
		"rollback":
			st.next_wave_turn += 1
			st.log_msg("%s: their logistics database thinks it is last Tuesday. Next wave delayed to turn %d." % [d["name"], st.next_wave_turn], "good")
	news.push_front("CCB: Commonwealth networks report “routine maintenance” after %s." % ["foreign cyber-vandalism", "an unexplained configuration change", "a rubber duck"][rng.randi_range(0, 2)])
	return true


# --------------------------------------------------------------------------------------------
# Broadcasts
# --------------------------------------------------------------------------------------------

func _make_news(st: GameState) -> Array:
	var sit := "quiet"
	if not report["carriers_sunk"].is_empty():
		sit = "carrier_sunk"
	elif not report["cities_lost"].is_empty():
		sit = "city_lost"
	elif report["kills"] >= 3:
		sit = "kills"
	elif report["wave"] or not st.enemies.is_empty():
		sit = "wave"
	var out: Array = []
	if last_decision != "" and Lore.DECISION_NEWS.has(last_decision):
		out.append(Lore.DECISION_NEWS[last_decision])
		last_decision = ""
	for outlet in ["lpb", "ccb", "sol", "hnn"]:
		var pools: Dictionary = Lore.NEWS[outlet]
		var pool: Array = pools.get(sit, pools["quiet"])
		out.append("%s · %s" % [pools["tag"], _fill(st, pool[rng.randi_range(0, pool.size() - 1)])])
	for i in 2:
		out.append(Lore.ADS[rng.randi_range(0, Lore.ADS.size() - 1)])
	return out


func _fill(st: GameState, text: String) -> String:
	var cities: Array = []
	for s in st.structures.values():
		if s["kind"] == "city":
			cities.append(s["name"])
	var city: String = cities[rng.randi_range(0, cities.size() - 1)] if not cities.is_empty() else "Lumen"
	var lost: String = report["cities_lost"][0] if not report["cities_lost"].is_empty() else city
	var carrier: String = report["carriers_sunk"][0] if not report["carriers_sunk"].is_empty() else "a carrier"
	var cap: Dictionary = st.capital()
	return text.format({"city": city, "lost": lost, "kills": report["kills"], "hits": report["hits"],
		"wave": st.wave, "total": st.waves_total, "capital": cap.get("name", "Lumen"), "carrier": carrier})


# --------------------------------------------------------------------------------------------
# Intel Archive
# --------------------------------------------------------------------------------------------

func unlock(tag: String) -> void:
	for entry in Lore.CODEX:
		if entry["unlock"] == tag and not codex.has(entry["id"]):
			codex[entry["id"]] = true
			if tag != "start":
				codex_unseen += 1


func unlocked_entries() -> Array:
	var out: Array = []
	for entry in Lore.CODEX:
		if codex.has(entry["id"]):
			out.append(entry)
	return out


# --------------------------------------------------------------------------------------------
# Epilogue
# --------------------------------------------------------------------------------------------

func ending(st: GameState) -> Dictionary:
	var key := "waves"
	if st.result == "defeat":
		key = "defeat"
	elif st.carriers.is_empty():
		key = "fleet"
	elif flags.has("posture_talks"):
		key = "talks"
	elif flags.has("posture_independence"):
		key = "independence"
	var base: Dictionary = Lore.ENDINGS[key]
	var lines: Array = []
	for f in Lore.ENDING_FLAGS:
		if flags.has(f):
			lines.append(Lore.ENDING_FLAGS[f])
	if ally >= 70:
		lines.append("In Concord, the Federation calls the outcome “a triumph of the Ambiguity Doctrine,” which nobody can disprove.")
	elif ally <= 30:
		lines.append("The Federation's commitment to Tessera remains “ironclad and under review.” Mostly under review.")
	if resolve >= 75:
		lines.append("Polls show Tesserans are exhausted, furious and certain of exactly one thing: they decide what comes next.")
	elif resolve < 30:
		lines.append("The Assembly of Tiles is fractured, and the streets are quieter than anyone likes.")
	var codas: Array = []
	for who in ["mara", "sorei", "sol"]:
		codas.append({"speaker": who, "text": Lore.CODAS[who][key]})
	return {"key": key, "title": base["title"], "text": base["text"], "lines": lines,
		"outlets": Lore.OUTLET_ENDINGS[key], "codas": codas}


# --------------------------------------------------------------------------------------------
# Persistence
# --------------------------------------------------------------------------------------------

const _FIELDS := ["resolve", "escalation", "ally", "flags", "choices", "schedule", "next_directive", "pending", "budget_mods",
	"glass", "foundry_id", "foundry_mult", "accuracy_bonus", "strike_lock_until", "no_new_types", "convoy",
	"reveal_next", "act", "codex", "codex_unseen", "news", "beats", "ops_ready", "merge_used_wave", "shipments",
	"last_decision", "used_intercepts", "report"]


func to_dict() -> Dictionary:
	var d := {"rng_seed": rng.seed, "rng_state": rng.state}
	for f in _FIELDS:
		d[f] = get(f)
	return d


func from_dict(d: Dictionary) -> void:
	for f in _FIELDS:
		if d.has(f):
			set(f, d[f])
	rng.seed = d.get("rng_seed", 1)
	rng.state = d.get("rng_state", 0)
