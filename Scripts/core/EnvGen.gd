class_name EnvGen
extends RefCounted
## Environment generator: everything on the map that is not a playable structure but makes the
## archipelago a place. Roads and bridges join the towns, ferries and shipping lanes cross the
## water, villages and paddies fill the countryside, and the coast carries a lighthouse, fish
## farms, an offshore wind farm and anti-landing obstacles on the beaches that face the strait.
## Each campaign also gets a theater: a named region and a season that sets its weather.
## Deterministic for a given seed; purely visual except for the season's weather table.

const REGIONS := ["Northern Approaches", "Saltmere Banks", "Kestrel Reach", "Seabright Narrows",
	"Harrow Shoals", "Driftwood Sound", "Old Customs Coast", "Lantern Roads"]

## Seasons: weather odds per turn and how they tint the land.
const SEASONS := {
	"plum_rain": {"name": "Plum Rain season", "desc": "Warm, wet and close. Rain and fog roll in off the strait.",
		"weather": {"clear": 0.4, "rain": 0.35, "fog": 0.2, "storm": 0.05}, "tint": Color(0.92, 1.06, 0.95)},
	"typhoon": {"name": "Typhoon season", "desc": "Long hot spells broken by violent storms.",
		"weather": {"clear": 0.55, "rain": 0.22, "storm": 0.15, "fog": 0.08}, "tint": Color(0.96, 1.04, 0.96)},
	"winter_monsoon": {"name": "Northeast monsoon", "desc": "Grey skies, cold wind and short, steep seas.",
		"weather": {"overcast": 0.4, "rain": 0.22, "clear": 0.28, "fog": 0.1}, "tint": Color(1.02, 0.97, 0.92)},
	"dry_spring": {"name": "Dry spring", "desc": "Clear days and dusty haze; the best flying weather of the year.",
		"weather": {"clear": 0.62, "haze": 0.28, "fog": 0.1}, "tint": Color(1.06, 1.02, 0.86)},
}
const SEASON_ORDER := ["plum_rain", "typhoon", "winter_monsoon", "dry_spring"]


static func generate(seed_value: int, tiles: Dictionary, cells: Array, w: int, h: int, hubs: Array, occupied: Array) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value * 31 + 5
	var is_land := func(hx: Vector2i) -> bool:
		return tiles.has(hx) and not Defs.TERRAIN[tiles[hx]]["water"]
	var occ := {}
	for o in occupied:
		occ[o] = true
	var env := {}
	var season: String = SEASON_ORDER[rng.randi_range(0, SEASON_ORDER.size() - 1)]
	env["theater"] = {"region": REGIONS[rng.randi_range(0, REGIONS.size() - 1)], "season": season}

	# --- Roads: a tree joining the Capital to every hub, over land, with short causeway bridges.
	var roads: Array = []
	var bridges := {}
	var ferries: Array = []
	var connected: Array = [hubs[0]]
	var rest: Array = hubs.slice(1)
	rest.sort_custom(func(a, b): return Hex.distance(a, hubs[0]) < Hex.distance(b, hubs[0]))
	for hub in rest:
		var best_path: Array = []
		var best_len := 9999
		for target in connected:
			var path := _road_path(tiles, hub, target)
			if path.is_empty():
				continue
			var water := 0
			for hx in path:
				if not is_land.call(hx):
					water += 1
			if water > 2:
				continue
			if path.size() < best_len:
				best_len = path.size()
				best_path = path
		if not best_path.is_empty():
			var full: Array = [hub]
			full.append_array(best_path)
			roads.append(full)
			for hx in full:
				if not is_land.call(hx):
					bridges[hx] = true
		else:
			var near: Vector2i = connected[0]
			for c in connected:
				if Hex.distance(c, hub) < Hex.distance(near, hub):
					near = c
			ferries.append([hub, near])
		connected.append(hub)
	env["roads"] = roads
	env["bridges"] = bridges.keys()
	env["ferries"] = ferries
	var road_hexes := {}
	for r in roads:
		for hx in r:
			road_hexes[hx] = true

	# --- Villages along the roads and near towns, with paddies around them.
	var villages: Array = []
	var land_count := 0
	for hx in cells:
		if is_land.call(hx):
			land_count += 1
	var want := clampi(land_count / 11, 4, 11)
	var cand: Array = []
	for hx in cells:
		if not is_land.call(hx) or occ.has(hx) or tiles[hx] == "mountain" or tiles[hx] == "beach":
			continue
		var near_road := false
		for nb in Hex.neighbors(hx):
			if road_hexes.has(nb):
				near_road = true
				break
		var d_hub := 99
		for hb in hubs:
			d_hub = mini(d_hub, Hex.distance(hx, hb))
		if d_hub < 2:
			continue
		var sc := (3.0 if near_road else 0.0) + (2.0 if d_hub <= 3 else 0.0) + rng.randf() * 2.0
		cand.append([sc, hx])
	cand.sort_custom(func(a, b): return a[0] > b[0])
	for c in cand:
		if villages.size() >= want:
			break
		var ok := true
		for v in villages:
			if Hex.distance(v, c[1]) < 2:
				ok = false
				break
		if ok:
			villages.append(c[1])
	env["villages"] = villages
	var farms: Array = []
	for v in villages:
		for nb in Hex.neighbors(v):
			if tiles.get(nb, "") == "plains" and not occ.has(nb) and not villages.has(nb) and not farms.has(nb) and rng.randf() < 0.5:
				farms.append(nb)
	for hb in hubs.slice(1):
		for nb in Hex.neighbors(hb):
			if tiles.get(nb, "") == "plains" and not occ.has(nb) and not villages.has(nb) and not farms.has(nb) and rng.randf() < 0.35:
				farms.append(nb)
	env["farms"] = farms

	# --- Coast: anti-landing obstacles on beaches facing the strait, a lighthouse, fish farms,
	# an offshore wind farm.
	var obstacles: Array = []
	for hx in cells:
		if tiles[hx] != "beach" or occ.has(hx):
			continue
		for i in [0, 1, 5]:
			var nb: Vector2i = hx + Hex.DIRS[i]
			if tiles.has(nb) and Defs.TERRAIN[tiles[nb]]["water"]:
				obstacles.append(hx)
				break
	env["obstacles"] = obstacles
	var lighthouse := Hex.INVALID
	var best_l := -INF
	for hx in cells:
		if not is_land.call(hx) or occ.has(hx) or villages.has(hx) or tiles[hx] == "mountain":
			continue
		var wet := 0
		for nb in Hex.neighbors(hx):
			if tiles.has(nb) and not is_land.call(nb):
				wet += 1
		if wet < 3:
			continue
		var sc := wet + Hex.axial_to_offset(hx).x * 0.05 + rng.randf()
		if sc > best_l:
			best_l = sc
			lighthouse = hx
	env["lighthouse"] = lighthouse
	var fishfarms: Array = []
	for hb in hubs.slice(1):
		for nb in Hex.neighbors(hb):
			if tiles.get(nb, "") == "shallow" and fishfarms.size() < 3 and rng.randf() < 0.5:
				fishfarms.append(nb)
				break
	env["fishfarms"] = fishfarms
	var windfarm: Array = []
	var best_w := -INF
	var seed_hex := Hex.INVALID
	for hx in cells:
		if tiles[hx] != "shallow" or fishfarms.has(hx):
			continue
		var n := 0
		for nb in Hex.neighbors(hx):
			if tiles.get(nb, "") == "shallow":
				n += 1
		var col := Hex.axial_to_offset(hx).x
		var sc := n + (2.0 if col < w * 0.3 else 0.0) + rng.randf()
		if sc > best_w:
			best_w = sc
			seed_hex = hx
	if seed_hex != Hex.INVALID:
		windfarm.append(seed_hex)
		for nb in Hex.neighbors(seed_hex):
			if tiles.get(nb, "") == "shallow" and windfarm.size() < 3 and not fishfarms.has(nb):
				windfarm.append(nb)
	env["windfarm"] = windfarm

	# --- Landmarks inland: a hill temple and comms masts on the peaks.
	var temple := Hex.INVALID
	var best_t := -INF
	for hx in cells:
		if not (tiles[hx] in ["hills", "forest"]) or occ.has(hx) or villages.has(hx) or farms.has(hx):
			continue
		var d_hub := 99
		for hb in hubs.slice(1):
			d_hub = mini(d_hub, Hex.distance(hx, hb))
		if d_hub < 2 or d_hub > 4:
			continue
		var sc := (1.5 if tiles[hx] == "hills" else 0.0) + rng.randf() * 2.0
		if sc > best_t:
			best_t = sc
			temple = hx
	env["temple"] = temple
	var masts: Array = []
	for hx in cells:
		if tiles[hx] == "mountain" and not occ.has(hx) and masts.size() < 2 and rng.randf() < 0.45:
			masts.append(hx)
	env["masts"] = masts

	# --- Shipping lanes through open water from the north edge to the south edge.
	env["lanes"] = _lanes(tiles, cells, w, h, rng)
	return env


static func _road_path(tiles: Dictionary, a: Vector2i, b: Vector2i) -> Array:
	var passable := func(hx: Vector2i) -> bool:
		if not tiles.has(hx):
			return false
		var t: String = tiles[hx]
		return t != "mountain" and t != "deep"
	var cost := func(hx: Vector2i) -> float:
		match tiles.get(hx, "deep"):
			"plains": return 1.0
			"beach": return 1.25
			"forest": return 1.6
			"hills": return 2.3
			"shallow": return 7.0
		return 50.0
	return Pathfinder.find(a, b, passable, cost, 4000)


static func _lanes(tiles: Dictionary, cells: Array, w: int, h: int, rng: RandomNumberGenerator) -> Array:
	var out: Array = []
	var passable := func(hx: Vector2i) -> bool:
		return tiles.has(hx) and Defs.TERRAIN[tiles[hx]]["water"]
	var cost := func(hx: Vector2i) -> float:
		return 1.0 if tiles.get(hx, "") == "deep" else 2.5
	for col_frac in [0.82, 0.62, 0.12]:
		var col := int(w * col_frac)
		var start := Hex.INVALID
		var goal := Hex.INVALID
		for dx in [0, 1, -1, 2, -2, 3, -3]:
			var a := Hex.offset_to_axial(clampi(col + dx, 0, w - 1), 0)
			if start == Hex.INVALID and tiles.has(a) and Defs.TERRAIN[tiles[a]]["water"]:
				start = a
			var b := Hex.offset_to_axial(clampi(col + dx + rng.randi_range(-1, 1), 0, w - 1), h - 1)
			if goal == Hex.INVALID and tiles.has(b) and Defs.TERRAIN[tiles[b]]["water"]:
				goal = b
		if start == Hex.INVALID or goal == Hex.INVALID:
			continue
		var path := Pathfinder.find(start, goal, passable, cost, 5000)
		if path.size() >= h - 2:
			var full: Array = [start]
			full.append_array(path)
			out.append(full)
	return out


static func season_data(env: Dictionary) -> Dictionary:
	var th: Dictionary = env.get("theater", {})
	return SEASONS.get(th.get("season", "typhoon"), SEASONS["typhoon"])


static func theater_title(env: Dictionary) -> String:
	var th: Dictionary = env.get("theater", {})
	return "%s · %s" % [th.get("region", "Lantern Strait"), season_data(env)["name"]]


## Picks the next turn's weather: weather tends to persist, otherwise draw from the season.
static func next_weather(env: Dictionary, current: String, rng: RandomNumberGenerator) -> String:
	if current != "" and rng.randf() < 0.45:
		return current
	var table: Dictionary = season_data(env)["weather"]
	var r := rng.randf()
	for k in table:
		r -= float(table[k])
		if r <= 0.0:
			return k
	return "clear"
