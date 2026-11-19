class_name MapView
extends Node2D
## Draws the terrain once: water, raised land with cliffs, scenery, and the generated environment
## (roads, bridges, villages, paddies, coastal works, landmarks), then ruins and the grid.
## Redrawn only when the set of occupied hexes or ruins changes.

var tiles := {}
var cells: Array = []
var ruins := {}
var env := {}
var occupied := {}
var show_grid := true
static var tint := Color(1, 1, 1)


func setup(p_tiles: Dictionary, p_cells: Array, p_env: Dictionary = {}) -> void:
	tiles = p_tiles
	cells = p_cells
	env = p_env
	tint = EnvGen.season_data(env)["tint"] if not env.is_empty() else Color(1, 1, 1)
	queue_redraw()


func set_ruins(p_ruins: Dictionary) -> void:
	ruins = p_ruins.duplicate()
	queue_redraw()


## Hexes covered by structures: village houses, paddies and landmarks step aside for them.
func set_occupied(p: Dictionary) -> void:
	if p.size() == occupied.size():
		var same := true
		for k in p:
			if not occupied.has(k):
				same = false
				break
		if same:
			return
	occupied = p.duplicate()
	queue_redraw()


## Night grade (with the season's tint): Tessera after dark.
static func night(c: Color) -> Color:
	var d := Color(clampf(c.r * tint.r, 0, 1), clampf(c.g * tint.g, 0, 1), clampf(c.b * tint.b, 0, 1), c.a).darkened(0.4)
	return d.lerp(Color(0.04, 0.06, 0.16, d.a), 0.24)


static func elev(t: String) -> float:
	return float(Defs.TERRAIN.get(t, {}).get("elev", 0))


static func top_center(p_tiles: Dictionary, h: Vector2i) -> Vector2:
	return Hex.to_pixel(h) - Vector2(0, elev(p_tiles.get(h, "deep")))


static func map_rect(p_cells: Array) -> Rect2:
	var r := Rect2(Hex.to_pixel(p_cells[0]), Vector2.ZERO)
	for h in p_cells:
		r = r.expand(Hex.to_pixel(h))
	return r.grow(Hex.SIZE * 1.2)


func _hash(h: Vector2i, k: int) -> float:
	var v := sin(float(h.x * 374761 + h.y * 668265 + k * 1442695)) * 43758.5453
	return v - floor(v)


func _is_water(h: Vector2i) -> bool:
	return Defs.TERRAIN[tiles.get(h, "deep")]["water"]


func _draw() -> void:
	if cells.is_empty():
		return
	var windfarm: Array = env.get("windfarm", [])
	var fishfarms: Array = env.get("fishfarms", [])
	var farms: Array = env.get("farms", [])
	# Pass 1: water tints, shoals, foam, and works standing in the water.
	for h in cells:
		var t: String = tiles[h]
		if not Defs.TERRAIN[t]["water"]:
			continue
		var c := Hex.to_pixel(h)
		var col: Color = night(Defs.TERRAIN[t]["color"])
		col.a = 0.42 if t == "deep" else 0.55
		draw_colored_polygon(Hex.corners(c, Hex.SIZE + 0.6), col)
		if t == "shallow":
			for k in 3:
				var p := c + Vector2((_hash(h, k * 9) - 0.5) * 34.0, (_hash(h, k * 9 + 4) - 0.5) * 28.0)
				draw_circle(p, 2.0 + _hash(h, k) * 2.5, Color(0.25, 0.55, 0.6, 0.12))
		for i in 6:
			var nb: Vector2i = h + Hex.DIRS[i]
			if tiles.has(nb) and not _is_water(nb):
				var e := Hex.edge(c, i, Hex.SIZE)
				var inward := (c - (e[0] + e[1]) * 0.5).normalized()
				var a := e[0].lerp(e[1], 0.08) + inward * 6.0
				var b := e[0].lerp(e[1], 0.92) + inward * 6.0
				draw_line(a, b, Color(0.3, 0.95, 1.0, 0.12), 7.0, true)
				draw_line(a - inward * 3.0, b - inward * 3.0, Color(0.55, 1.0, 1.0, 0.42), 1.6, true)
		if fishfarms.has(h):
			_fish_farm(h, c)
		if windfarm.has(h):
			for p in turbine_spots(h):
				draw_circle(p, 1.6, Color(0.7, 0.75, 0.78, 0.55))
				draw_line(p, p + Vector2(0, -11), Color(0.72, 0.76, 0.8, 0.6), 0.9, true)
	# Pass 2: land, row by row so nearer hexes overlap farther ones.
	for h in cells:
		var t: String = tiles[h]
		var def: Dictionary = Defs.TERRAIN[t]
		if def["water"]:
			continue
		var e := elev(t)
		var c := Hex.to_pixel(h) - Vector2(0, e)
		var top := Hex.corners(c, Hex.SIZE + 0.5)
		var depth := 6.0 + e
		var side := PackedVector2Array([top[1], top[2], top[3],
			top[3] + Vector2(0, depth), top[2] + Vector2(0, depth), top[1] + Vector2(0, depth)])
		draw_colored_polygon(side, night(def["side"]))
		var col: Color = night(def["color"])
		col = col.lightened((_hash(h, 1) - 0.5) * 0.06)
		draw_colored_polygon(top, col)
		draw_polyline(PackedVector2Array([top[3], top[4], top[5], top[0]]), Color(0.5, 0.95, 1.0, 0.1), 1.5, true)
		draw_polyline(PackedVector2Array([top[0], top[1], top[2], top[3]]), Color(0, 0, 0, 0.12), 1.5, true)
		if farms.has(h) and not occupied.has(h):
			_paddies(h, c)
		else:
			_decorate(h, t, c)
	# Pass 3: roads and bridges.
	for r in env.get("roads", []):
		_road(r)
	# Pass 4: settlements, coastal defences and landmarks.
	for h in env.get("obstacles", []):
		if not occupied.has(h):
			_obstacles(h, top_center(tiles, h))
	for h in env.get("villages", []):
		if not occupied.has(h):
			_village(h, top_center(tiles, h))
	var temple: Vector2i = env.get("temple", Hex.INVALID)
	if temple != Hex.INVALID and not occupied.has(temple):
		var tc := top_center(tiles, temple)
		draw_colored_polygon(PackedVector2Array([tc + Vector2(-3, 14), tc + Vector2(3, 14), tc + Vector2(2, 6), tc + Vector2(-2, 6)]), night(Color(0.7, 0.68, 0.62)))
		Installations.temple(self, tc + Vector2(0, 4))
	var lh: Vector2i = env.get("lighthouse", Hex.INVALID)
	if lh != Hex.INVALID and not occupied.has(lh):
		var lc := lighthouse_point(tiles, lh)
		Installations.box(self, lc + Vector2(-5, 3), 7.0, 5.0, 3.0, 0.0, Color(0.7, 0.72, 0.74), Color(0.55, 0.57, 0.6))
		Installations.cylinder(self, lc, 2.6, 17.0, Color(0.9, 0.9, 0.9), Color(0.25, 0.28, 0.3))
		draw_rect(Rect2(lc + Vector2(-2.6, -12), Vector2(5.2, 2.6)), Color(0.75, 0.18, 0.18))
	for h in env.get("masts", []):
		if not occupied.has(h):
			Installations.lattice(self, top_center(tiles, h) + Vector2(10, 2), 18.0, 3.0, 1.0, Color(0.55, 0.6, 0.64))
	# Pass 5: ruins.
	for h in ruins:
		Installations.ruin(self, String(ruins[h]), top_center(tiles, h), h.x * 31 + h.y * 17)
	# Pass 6: grid.
	if show_grid:
		for h in cells:
			var pts := Hex.corners(top_center(tiles, h), Hex.SIZE)
			pts.append(pts[0])
			draw_polyline(pts, Color(0.45, 0.9, 1.0, 0.06), 1.0, true)


static func turbine_spots(h: Vector2i) -> Array:
	var c := Hex.to_pixel(h)
	return [c + Vector2(-13, -6), c + Vector2(9, -11), c + Vector2(2, 12)]


static func lighthouse_point(p_tiles: Dictionary, h: Vector2i) -> Vector2:
	var c := top_center(p_tiles, h)
	for i in 6:
		var nb: Vector2i = h + Hex.DIRS[i]
		if p_tiles.has(nb) and Defs.TERRAIN[p_tiles[nb]]["water"]:
			return c + Installations.dir_vec(i) * 14.0
	return c


# --------------------------------------------------------------------------------------------
# Scenery
# --------------------------------------------------------------------------------------------

func _decorate(h: Vector2i, t: String, c: Vector2) -> void:
	match t:
		"forest":
			var trees: Array = []
			for k in 8:
				var p := c + Vector2((_hash(h, k * 3) - 0.5) * 40.0, (_hash(h, k * 3 + 1) - 0.5) * 30.0)
				trees.append(p)
			trees.sort_custom(func(a, b): return a.y < b.y)
			var k2 := 0
			for p in trees:
				var s := 0.7 + _hash(h, int(p.x)) * 0.5
				if (k2 + h.x) % 3 == 0:
					draw_circle(p + Vector2(1.5, 2.5) * s, 5.5 * s, Color(0, 0, 0, 0.2))
					draw_circle(p, 5.5 * s, night(Color(0.17, 0.4, 0.2)))
					draw_circle(p - Vector2(1.5, 1.8) * s, 3.2 * s, night(Color(0.24, 0.5, 0.26)))
				else:
					draw_line(p + Vector2(0, 2) * s, p + Vector2(0, 6) * s, night(Color(0.3, 0.2, 0.12)), 2.0 * s)
					draw_colored_polygon(PackedVector2Array([p + Vector2(-6, 3) * s, p + Vector2(6, 3) * s, p + Vector2(0, -9) * s]), night(Color(0.13, 0.33, 0.16)))
					draw_colored_polygon(PackedVector2Array([p + Vector2(0, -9) * s, p + Vector2(6, 3) * s, p + Vector2(1, 3) * s]), night(Color(0.1, 0.25, 0.12)))
				k2 += 1
		"hills":
			for k in 3:
				var p := c + Vector2(-10 + k * 9, 6 - k * 6) + Vector2((_hash(h, k) - 0.5) * 6, 0)
				var pts := PackedVector2Array()
				for j in 11:
					var a := PI + PI * j / 10.0
					pts.append(p + Vector2(cos(a) * 12.0, sin(a) * 6.0))
				draw_colored_polygon(pts, night(Color(0.62, 0.66, 0.4)))
				draw_polyline(pts, night(Color(0.42, 0.45, 0.27)), 1.2, true)
				for j in 2:
					var arc := PackedVector2Array()
					for q in 7:
						var a := PI + PI * (0.15 + 0.7 * q / 6.0)
						arc.append(p + Vector2(cos(a) * (9.0 - j * 3.5), sin(a) * (4.0 - j * 1.6) + 1.0))
					draw_polyline(arc, night(Color(0.5, 0.56, 0.32)), 1.0, true)
		"mountain":
			var peaks := [[Vector2(-10, 6), 0.72], [Vector2(9, 9), 0.55], [Vector2(3, 7), 1.0]]
			for pk in peaks:
				var base: Vector2 = c + pk[0]
				var s: float = pk[1]
				var apex := base + Vector2(0, -24) * s
				var l := base + Vector2(-15, 0) * s
				var r := base + Vector2(15, 0) * s
				draw_colored_polygon(PackedVector2Array([l, apex, base + Vector2(1, 0)]), night(Color(0.6, 0.57, 0.54)))
				draw_colored_polygon(PackedVector2Array([base + Vector2(-1, 0), apex, r]), night(Color(0.43, 0.4, 0.38)))
				draw_line(apex, apex.lerp(base, 0.7) + Vector2(3, 0), night(Color(0.35, 0.33, 0.31)), 1.0, true)
				var sl := apex.lerp(l, 0.32)
				var sr := apex.lerp(r, 0.32)
				draw_colored_polygon(PackedVector2Array([sl, apex, sr, apex.lerp(base, 0.36) + Vector2(2, 0) * s, apex.lerp(base, 0.28) - Vector2(3, 0) * s]), night(Color(0.85, 0.86, 0.88)))
		"plains":
			for k in 5:
				var p := c + Vector2((_hash(h, k * 5) - 0.5) * 40.0, (_hash(h, k * 5 + 2) - 0.5) * 30.0)
				draw_line(p, p + Vector2(-2, -4), night(Color(0.36, 0.5, 0.25)), 1.2)
				draw_line(p, p + Vector2(2, -5), night(Color(0.36, 0.5, 0.25)), 1.2)
			if _hash(h, 77) < 0.35:
				var a := c + Vector2(-20, (_hash(h, 78) - 0.5) * 16.0)
				for k in 6:
					draw_circle(a + Vector2(k * 7.0, sin(k + h.x) * 1.5), 2.2, night(Color(0.2, 0.36, 0.18)))
		"beach":
			for k in 5:
				var p := c + Vector2((_hash(h, k * 7) - 0.5) * 36.0, (_hash(h, k * 7 + 3) - 0.5) * 26.0)
				draw_circle(p, 1.2, night(Color(0.7, 0.62, 0.42)))
			for k in 2:
				var y := c.y - 6.0 + k * 10.0
				draw_line(Vector2(c.x - 14, y), Vector2(c.x + 12, y + 2), night(Color(0.75, 0.68, 0.5)), 0.8, true)


func _paddies(h: Vector2i, c: Vector2) -> void:
	var rot := (_hash(h, 3) - 0.5) * 0.3
	for gy in 3:
		for gx in 4:
			var p := c + Vector2(-19.5 + gx * 13.0, -12.0 + gy * 12.0).rotated(rot)
			if p.distance_to(c) > 25.0:
				continue
			var wet := _hash(h, gx * 7 + gy) < 0.45
			var col := Color(0.2, 0.38, 0.42) if wet else Color(0.38, 0.55, 0.26)
			var q := PackedVector2Array([p + Vector2(-5.6, -5.0).rotated(rot), p + Vector2(5.6, -5.0).rotated(rot), p + Vector2(5.6, 5.0).rotated(rot), p + Vector2(-5.6, 5.0).rotated(rot)])
			draw_colored_polygon(q, night(col))
			if wet:
				draw_line(q[0].lerp(q[1], 0.2), q[3].lerp(q[2], 0.5), Color(0.5, 0.8, 0.9, 0.18), 1.0)
			q.append(q[0])
			draw_polyline(q, night(Color(0.5, 0.45, 0.3)), 1.0)


func _road(path: Array) -> void:
	if path.size() < 2:
		return
	var pts := PackedVector2Array()
	for h in path:
		pts.append(top_center(tiles, h))
	for i in range(pts.size() - 1):
		var a: Vector2 = pts[i]
		var b: Vector2 = pts[i + 1]
		var bridge := _is_water(path[i]) or _is_water(path[i + 1])
		if bridge:
			var n := (b - a).normalized().orthogonal()
			for k in 4:
				var p := a.lerp(b, (k + 0.5) / 4.0)
				draw_line(p, p + Vector2(0, 6), Color(0.12, 0.13, 0.15), 2.0)
			draw_line(a, b, Color(0.05, 0.06, 0.08), 7.0, true)
			draw_line(a, b, night(Color(0.62, 0.64, 0.66)), 5.0, true)
			draw_line(a + n * 2.6, b + n * 2.6, Color(0.85, 0.88, 0.9, 0.5), 0.8, true)
			draw_line(a - n * 2.6, b - n * 2.6, Color(0.85, 0.88, 0.9, 0.5), 0.8, true)
		else:
			draw_line(a, b, Color(0.05, 0.06, 0.08, 0.7), 6.0, true)
			draw_line(a, b, night(Color(0.42, 0.43, 0.46)), 3.6, true)
		var seg := a.distance_to(b)
		var dir := (b - a) / maxf(seg, 0.001)
		var n2 := dir.orthogonal()
		var steps := int(seg / 12.0)
		for k in steps:
			var p := a + dir * (6.0 + k * 12.0) + n2 * (3.6 if k % 2 == 0 else -3.6)
			draw_circle(p, 2.2, Color(1.0, 0.8, 0.45, 0.08))
			draw_circle(p, 0.7, Color(1.0, 0.85, 0.55, 0.85))


func _village(h: Vector2i, c: Vector2) -> void:
	var spots := [Vector2(-12, -6), Vector2(2, -10), Vector2(13, -3), Vector2(-6, 6), Vector2(9, 9), Vector2(-16, 9)]
	var n := 4 + int(_hash(h, 11) * 3.0)
	var houses: Array = []
	for k in n:
		houses.append(c + spots[k] + Vector2((_hash(h, k + 20) - 0.5) * 4.0, (_hash(h, k + 30) - 0.5) * 3.0))
	houses.sort_custom(func(a, b): return a.y < b.y)
	for k in 3:
		var tp := c + Vector2((_hash(h, k + 40) - 0.5) * 36.0, (_hash(h, k + 50) - 0.5) * 26.0)
		draw_circle(tp + Vector2(1.5, 1.5), 3.6, Color(0, 0, 0, 0.2))
		draw_circle(tp, 3.6, night(Color(0.2, 0.42, 0.22)))
	var i := 0
	for p in houses:
		var roof := Installations.TILE_ROOF if (i + h.y) % 3 != 0 else Color(0.36, 0.4, 0.44)
		var walls := Installations.box(self, p, 6.5, 4.5, 3.5, 0.0, roof.lightened(0.08), Color(0.66, 0.62, 0.54))
		Installations.windows(self, walls, 1, 1, Installations.WINDOW, h.x * 13 + h.y * 7 + i, 0.65)
		i += 1


func _obstacles(h: Vector2i, c: Vector2) -> void:
	for i in [0, 1, 5]:
		var nb: Vector2i = h + Hex.DIRS[i]
		if not tiles.has(nb) or not _is_water(nb):
			continue
		var e := Hex.edge(c, i, Hex.SIZE - 7.0)
		for k in 5:
			var p: Vector2 = e[0].lerp(e[1], (k + 0.5) / 5.0)
			var col := Color(0.42, 0.44, 0.46)
			draw_line(p + Vector2(-2.4, -1.4), p + Vector2(2.4, 1.4), col, 1.2, true)
			draw_line(p + Vector2(-2.4, 1.4), p + Vector2(2.4, -1.4), col, 1.2, true)
			draw_line(p + Vector2(0, -2.6), p + Vector2(0, 1.6), col, 1.2, true)
	if _hash(h, 61) < 0.5:
		Installations.box(self, c + Vector2(-6, 4), 6.0, 5.0, 3.0, 0.0, Color(0.48, 0.5, 0.52), Color(0.36, 0.38, 0.4))
		draw_rect(Rect2(c + Vector2(-7.5, 3.2), Vector2(3, 0.9)), Color(0.02, 0.02, 0.02))


func _fish_farm(h: Vector2i, c: Vector2) -> void:
	var spots := [Vector2(-9, -7), Vector2(7, -8), Vector2(-7, 8), Vector2(9, 7)]
	draw_line(c + Vector2(-9, -7), c + Vector2(9, 7), Color(0.6, 0.55, 0.4, 0.6), 1.2)
	draw_line(c + Vector2(7, -8), c + Vector2(-7, 8), Color(0.6, 0.55, 0.4, 0.6), 1.2)
	for s in spots:
		draw_arc(c + s, 5.0, 0, TAU, 16, Color(0.7, 0.68, 0.55, 0.8), 1.4, true)
		draw_circle(c + s, 4.4, Color(0.1, 0.25, 0.3, 0.5))
		draw_circle(c + s + Vector2(5, 0), 0.9, Color(1.0, 0.6, 0.2, 0.8))
