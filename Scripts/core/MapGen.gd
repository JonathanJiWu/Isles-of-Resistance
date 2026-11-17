class_name MapGen
extends RefCounted
## Procedural archipelago generator. The player's islands lie in the west; the east is open
## ocean where the enemy carrier fleet patrols.

const CAPITAL_NAMES := Lore.CAPITAL_NAMES
const CITY_NAMES := Lore.CITY_NAMES
const LAND_THRESHOLD := 0.11


static func generate(seed_value: int, w: int, h: int, n_cities: int, n_carriers: int) -> Dictionary:
	for attempt in 60:
		var res := _attempt(seed_value + attempt * 7919, w, h, n_cities, n_carriers, false)
		if not res.is_empty():
			res["seed_used"] = seed_value + attempt * 7919
			return res
	var forced := _attempt(seed_value, w, h, n_cities, n_carriers, true)
	forced["seed_used"] = seed_value
	return forced


static func _attempt(s: int, w: int, h: int, n_cities: int, n_carriers: int, force: bool) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = s
	var noise := FastNoiseLite.new()
	noise.seed = s
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = 0.075
	noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	noise.fractal_octaves = 3
	var moist := FastNoiseLite.new()
	moist.seed = s + 101
	moist.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	moist.frequency = 0.12

	var cells: Array = []
	var elev := {}
	var offset := {}
	for row in h:
		for col in w:
			var hx := Hex.offset_to_axial(col, row)
			cells.append(hx)
			offset[hx] = Vector2i(col, row)
			var p := Hex.to_pixel(hx) / Hex.SIZE
			var e := noise.get_noise_2d(p.x * 1.6, p.y * 1.6)
			var fx := float(col) / float(w - 1)
			var bias := 0.1
			if fx > 0.58:
				bias = 0.1 - (fx - 0.58) * 2.6
			var edge := mini(col, mini(row, h - 1 - row))
			if edge == 0:
				bias -= 1.0
			elif edge == 1:
				bias -= 0.12
			elev[hx] = e + bias

	var tiles := {}
	var land: Array = []
	for hx in cells:
		if elev[hx] > LAND_THRESHOLD:
			land.append(hx)
	# Elevation percentiles among land for hills/mountains.
	var land_elev: Array = []
	for hx in land:
		land_elev.append(elev[hx])
	land_elev.sort()
	var mountain_cut := 99.0
	var hill_cut := 99.0
	if land_elev.size() > 10:
		mountain_cut = land_elev[int(land_elev.size() * 0.93)]
		hill_cut = land_elev[int(land_elev.size() * 0.76)]
	var land_set := {}
	for hx in land:
		land_set[hx] = true
	for hx in cells:
		if not land_set.has(hx):
			continue
		var e: float = elev[hx]
		var coastal := false
		for nb in Hex.neighbors(hx):
			if offset.has(nb) and not land_set.has(nb):
				coastal = true
				break
		var t := "plains"
		if e >= mountain_cut:
			t = "mountain"
		elif e >= hill_cut:
			t = "hills"
		elif coastal and e < LAND_THRESHOLD + 0.07:
			t = "beach"
		else:
			var p := Hex.to_pixel(hx) / Hex.SIZE
			t = "forest" if moist.get_noise_2d(p.x, p.y) > 0.08 else "plains"
		tiles[hx] = t
	for hx in cells:
		if land_set.has(hx):
			continue
		var near_land := false
		for nb in Hex.neighbors(hx):
			if land_set.has(nb):
				near_land = true
				break
		tiles[hx] = "shallow" if near_land else "deep"

	# Islands (connected land components).
	var island_of := {}
	var islands: Array = []
	for hx in land:
		if island_of.has(hx):
			continue
		var comp: Array = []
		var stack: Array = [hx]
		island_of[hx] = islands.size()
		while not stack.is_empty():
			var c: Vector2i = stack.pop_back()
			comp.append(c)
			for nb in Hex.neighbors(c):
				if land_set.has(nb) and not island_of.has(nb):
					island_of[nb] = islands.size()
					stack.append(nb)
		islands.append(comp)

	var total_land := land.size()
	if not force and (total_land < 58 or total_land > 140):
		return {}

	# Capital: the most interior non-mountain hex of a large western island.
	var order: Array = range(islands.size())
	order.sort_custom(func(a, b): return islands[a].size() > islands[b].size())
	var capital := Hex.INVALID
	var capital_island := -1
	for idx in order:
		var isl: Array = islands[idx]
		if isl.size() < 12 and not force:
			break
		var best_score := -INF
		for hx in isl:
			if tiles[hx] == "mountain":
				continue
			var col: int = offset[hx].x
			var row: int = offset[hx].y
			if col > int(w * 0.42) and not force:
				continue
			var interior := _water_distance(hx, land_set, 3)
			var sc := interior * 3.0 - absf(col - w * 0.22) * 0.6 - absf(row - h * 0.5) * 0.35 + rng.randf() * 0.5
			if sc > best_score:
				best_score = sc
				capital = hx
		if capital != Hex.INVALID:
			capital_island = idx
			break
	if capital == Hex.INVALID:
		if not force:
			return {}
		capital = land[0] if not land.is_empty() else Hex.offset_to_axial(4, h / 2)
		tiles[capital] = "plains"
		capital_island = island_of.get(capital, 0)

	# Cities: spread across islands, favouring coasts and new islands.
	var cities: Array = []
	var used_islands := {capital_island: 1}
	var taken: Array = [capital]
	for _i in n_cities:
		var best := Hex.INVALID
		var best_score := -INF
		for hx in land:
			if tiles[hx] == "mountain":
				continue
			var col: int = offset[hx].x
			if col > int(w * 0.68):
				continue
			var min_d := 99
			for t in taken:
				min_d = mini(min_d, Hex.distance(hx, t))
			if min_d < 4:
				continue
			var isl: int = island_of[hx]
			var sc := 0.0
			sc += 6.0 if not used_islands.has(isl) else -2.0 * used_islands[isl]
			sc += minf(min_d, 7) * 0.8
			if _water_distance(hx, land_set, 1) == 0:
				sc += 1.5
			if islands[isl].size() < 3:
				sc -= 4.0
			sc += rng.randf() * 2.0
			if sc > best_score:
				best_score = sc
				best = hx
		if best == Hex.INVALID:
			break
		taken.append(best)
		var isl2: int = island_of[best]
		used_islands[isl2] = used_islands.get(isl2, 0) + 1
		cities.append(best)
	if cities.size() < n_cities and not force:
		return {}

	# Deep water for the carrier fleet.
	var carrier_zone: Array = []
	for hx in cells:
		var o: Vector2i = offset[hx]
		if o.x >= w - Defs.CARRIER_ZONE + 1 and o.x < w - 1 and o.y >= 2 and o.y <= h - 3 and tiles[hx] == "deep":
			carrier_zone.append(hx)
	if carrier_zone.size() < 18 and not force:
		return {}
	var carriers: Array = []
	var tries := 0
	while carriers.size() < n_carriers and tries < 400 and not carrier_zone.is_empty():
		tries += 1
		var cand: Vector2i = carrier_zone[rng.randi_range(0, carrier_zone.size() - 1)]
		var ok := true
		for c in carriers:
			if Hex.distance(c, cand) < 4:
				ok = false
		if ok:
			carriers.append(cand)

	# Starting defenses next to the capital.
	var start_flak := Hex.INVALID
	var best_f := -INF
	for nb in Hex.neighbors(capital):
		if not tiles.has(nb) or Defs.TERRAIN[tiles[nb]]["water"] or tiles[nb] == "mountain":
			continue
		var sc := rng.randf() + (2.0 if tiles[nb] == "hills" else 0.0) + (0.5 if Hex.to_pixel(nb).x > Hex.to_pixel(capital).x else 0.0)
		if sc > best_f:
			best_f = sc
			start_flak = nb
	var start_radar := Hex.INVALID
	var best_r := -INF
	for hx in Hex.in_range(capital, 3):
		if hx == capital or hx == start_flak or not tiles.has(hx) or Defs.TERRAIN[tiles[hx]]["water"]:
			continue
		if cities.has(hx):
			continue
		var d := Hex.distance(hx, capital)
		if d < 2:
			continue
		var terrain_bonus: float = {"mountain": 3.0, "hills": 2.0}.get(tiles[hx], 0.0)
		var sc: float = rng.randf() + terrain_bonus + (1.0 if Hex.to_pixel(hx).x > Hex.to_pixel(capital).x else 0.0)
		if sc > best_r:
			best_r = sc
			start_radar = hx

	var names := CITY_NAMES.duplicate()
	_shuffle(names, rng)
	var city_list: Array = []
	for i in cities.size():
		city_list.append({"pos": cities[i], "name": names[i]})

	return {
		"tiles": tiles,
		"cells": cells,
		"capital": capital,
		"capital_name": CAPITAL_NAMES[rng.randi_range(0, CAPITAL_NAMES.size() - 1)],
		"cities": city_list,
		"start_flak": start_flak,
		"start_radar": start_radar,
		"carriers": carriers,
		"land_count": total_land,
		"island_count": islands.size(),
	}


static func _water_distance(hx: Vector2i, land_set: Dictionary, cap: int) -> int:
	for r in range(1, cap + 1):
		for c in Hex.ring(hx, r):
			if not land_set.has(c):
				return r - 1
	return cap


static func _shuffle(arr: Array, rng: RandomNumberGenerator) -> void:
	for i in range(arr.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp = arr[i]
		arr[i] = arr[j]
		arr[j] = tmp
