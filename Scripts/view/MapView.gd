class_name MapView
extends Node2D
## Draws the terrain: water tints, coastal foam, raised land with cliffs and decorations, ruins.

var tiles := {}
var cells: Array = []
var ruins := {}
var show_grid := true


func setup(p_tiles: Dictionary, p_cells: Array) -> void:
	tiles = p_tiles
	cells = p_cells
	queue_redraw()


func set_ruins(p_ruins: Dictionary) -> void:
	ruins = p_ruins.duplicate()
	queue_redraw()


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


func _draw() -> void:
	if cells.is_empty():
		return
	# Pass 1: water tints and foam.
	for h in cells:
		var t: String = tiles[h]
		if not Defs.TERRAIN[t]["water"]:
			continue
		var c := Hex.to_pixel(h)
		var col: Color = Defs.TERRAIN[t]["color"]
		col.a = 0.42 if t == "deep" else 0.55
		draw_colored_polygon(Hex.corners(c, Hex.SIZE + 0.6), col)
		for i in 6:
			var nb: Vector2i = h + Hex.DIRS[i]
			if tiles.has(nb) and not Defs.TERRAIN[tiles[nb]]["water"]:
				var e := Hex.edge(c, i, Hex.SIZE)
				var inward := (c - (e[0] + e[1]) * 0.5).normalized()
				var a := e[0].lerp(e[1], 0.08) + inward * 6.0
				var b := e[0].lerp(e[1], 0.92) + inward * 6.0
				draw_line(a, b, Color(0.85, 0.95, 1.0, 0.16), 6.0, true)
				draw_line(a - inward * 3.0, b - inward * 3.0, Color(0.9, 0.97, 1.0, 0.35), 2.0, true)
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
		draw_colored_polygon(side, def["side"])
		var col: Color = def["color"]
		col = col.lightened((_hash(h, 1) - 0.5) * 0.08)
		draw_colored_polygon(top, col)
		# Light rim on the upper edges, shade on the lower ones.
		draw_polyline(PackedVector2Array([top[3], top[4], top[5], top[0]]), Color(1, 1, 1, 0.09), 1.5, true)
		draw_polyline(PackedVector2Array([top[0], top[1], top[2], top[3]]), Color(0, 0, 0, 0.12), 1.5, true)
		_decorate(h, t, c)
	# Pass 3: ruins.
	for h in ruins:
		Icons.ruin(self, top_center(tiles, h), 1.0, h.x * 31 + h.y * 17)
	# Pass 4: grid.
	if show_grid:
		for h in cells:
			var pts := Hex.corners(top_center(tiles, h), Hex.SIZE)
			pts.append(pts[0])
			draw_polyline(pts, Color(1, 1, 1, 0.055), 1.0, true)


func _decorate(h: Vector2i, t: String, c: Vector2) -> void:
	match t:
		"forest":
			var trees: Array = []
			for k in 5:
				var p := c + Vector2((_hash(h, k * 3) - 0.5) * 36.0, (_hash(h, k * 3 + 1) - 0.5) * 26.0)
				trees.append(p)
			trees.sort_custom(func(a, b): return a.y < b.y)
			for p in trees:
				var s := 0.8 + _hash(h, int(p.x)) * 0.5
				draw_line(p + Vector2(0, 2) * s, p + Vector2(0, 6) * s, Color(0.3, 0.2, 0.12), 2.0 * s)
				draw_colored_polygon(PackedVector2Array([p + Vector2(-6, 3) * s, p + Vector2(6, 3) * s, p + Vector2(0, -9) * s]), Color(0.13, 0.33, 0.16))
				draw_colored_polygon(PackedVector2Array([p + Vector2(0, -9) * s, p + Vector2(6, 3) * s, p + Vector2(1, 3) * s]), Color(0.1, 0.25, 0.12))
		"hills":
			for k in 2:
				var p := c + Vector2(-9 + k * 16, 2 - k * 7) + Vector2((_hash(h, k) - 0.5) * 6, 0)
				var pts := PackedVector2Array()
				for j in 11:
					var a := PI + PI * j / 10.0
					pts.append(p + Vector2(cos(a) * 11.0, sin(a) * 7.0))
				draw_colored_polygon(pts, Color(0.64, 0.68, 0.42))
				draw_polyline(pts, Color(0.42, 0.45, 0.27), 1.5, true)
		"mountain":
			var peaks := [[Vector2(-9, 6), 0.75], [Vector2(5, 7), 1.0]]
			for pk in peaks:
				var base: Vector2 = c + pk[0]
				var s: float = pk[1]
				var apex := base + Vector2(0, -24) * s
				var l := base + Vector2(-15, 0) * s
				var r := base + Vector2(15, 0) * s
				draw_colored_polygon(PackedVector2Array([l, apex, base + Vector2(1, 0)]), Color(0.6, 0.57, 0.54))
				draw_colored_polygon(PackedVector2Array([base + Vector2(-1, 0), apex, r]), Color(0.43, 0.4, 0.38))
				var sl := apex.lerp(l, 0.32)
				var sr := apex.lerp(r, 0.32)
				draw_colored_polygon(PackedVector2Array([sl, apex, sr, apex.lerp(base, 0.36) + Vector2(2, 0), apex.lerp(base, 0.28) - Vector2(3, 0)]), Color(0.95, 0.96, 0.98))
		"plains":
			for k in 4:
				var p := c + Vector2((_hash(h, k * 5) - 0.5) * 38.0, (_hash(h, k * 5 + 2) - 0.5) * 28.0)
				draw_line(p, p + Vector2(-2, -4), Color(0.36, 0.5, 0.25), 1.2)
				draw_line(p, p + Vector2(2, -5), Color(0.36, 0.5, 0.25), 1.2)
		"beach":
			for k in 5:
				var p := c + Vector2((_hash(h, k * 7) - 0.5) * 36.0, (_hash(h, k * 7 + 3) - 0.5) * 26.0)
				draw_circle(p, 1.2, Color(0.7, 0.62, 0.42))
