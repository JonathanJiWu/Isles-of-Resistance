class_name Icons
extends RefCounted
## Procedural vector art for structures, aircraft, ships and UI icons.

const GLYPH := Color(0.88, 0.98, 0.96)
const PLATE := Color(0.03, 0.08, 0.11, 0.9)
const ENEMY_FILL := Color(0.8, 0.2, 0.24)
const ENEMY_LINE := Color(0.25, 0.03, 0.06)
const STEALTH_FILL := Color(0.17, 0.17, 0.23)

static var _shapes := {}


static func _mirror(half: Array) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for p in half:
		pts.append(p)
	for i in range(half.size() - 2, 0, -1):
		pts.append(Vector2(half[i].x, -half[i].y))
	return pts


static func shape(kind: String) -> PackedVector2Array:
	if _shapes.has(kind):
		return _shapes[kind]
	var pts: PackedVector2Array
	match kind:
		"fighter":
			pts = _mirror([Vector2(12, 0), Vector2(3, -2), Vector2(-1, -9), Vector2(-5, -9), Vector2(-4, -2.5), Vector2(-8, -5), Vector2(-10.5, -5), Vector2(-9, 0)])
		"bomber":
			pts = _mirror([Vector2(11, 0), Vector2(7, -2.2), Vector2(1, -3), Vector2(-3, -16), Vector2(-7, -16), Vector2(-6, -3), Vector2(-11, -3), Vector2(-13, -7.5), Vector2(-15.5, -7.5), Vector2(-14.5, 0)])
		"drone":
			pts = _mirror([Vector2(7, 0), Vector2(3, -1.2), Vector2(1.5, -8), Vector2(-0.5, -8), Vector2(-1.5, -1.2), Vector2(-6, -1.2), Vector2(-8, -4), Vector2(-9.2, -4), Vector2(-8.4, 0)])
		"missile":
			pts = _mirror([Vector2(10, 0), Vector2(7, -1.6), Vector2(-6, -1.6), Vector2(-8, -4.5), Vector2(-10, -4.5), Vector2(-9, 0)])
		"stealth":
			pts = _mirror([Vector2(10, 0), Vector2(-6, -15), Vector2(-8.5, -12.5), Vector2(-4.5, -6), Vector2(-7.5, -3.5), Vector2(-5, 0)])
		"interceptor":
			pts = _mirror([Vector2(13, 0), Vector2(2, -2.5), Vector2(-6, -10.5), Vector2(-9, -10.5), Vector2(-7, -2.5), Vector2(-10, -3), Vector2(-11.5, 0)])
		"gunship":
			pts = PackedVector2Array()
			for i in 14:
				var a := TAU * i / 14.0
				pts.append(Vector2(cos(a) * 8.0 + 2.0, sin(a) * 4.5))
		"frigate":
			pts = _mirror([Vector2(17, 0), Vector2(10, -5.5), Vector2(-12, -5.5), Vector2(-14.5, -3.5), Vector2(-14.5, 0)])
		"carrier":
			pts = _mirror([Vector2(24, 0), Vector2(17, -8), Vector2(-21, -8), Vector2(-24, -5.5), Vector2(-24, 0)])
	_shapes[kind] = pts
	return pts


static func xform(pts: PackedVector2Array, c: Vector2, rot: float, s: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	out.resize(pts.size())
	var cs := cos(rot)
	var sn := sin(rot)
	for i in pts.size():
		var p := pts[i] * s
		out[i] = c + Vector2(p.x * cs - p.y * sn, p.x * sn + p.y * cs)
	return out


static func _closed(pts: PackedVector2Array) -> PackedVector2Array:
	var out := pts.duplicate()
	out.append(pts[0])
	return out


static func poly(ci: CanvasItem, pts: PackedVector2Array, fill: Color, line: Color, width: float = 1.2) -> void:
	ci.draw_colored_polygon(pts, fill)
	if line.a > 0.0:
		ci.draw_polyline(_closed(pts), line, width, true)


# --------------------------------------------------------------------------------------------
# Aircraft and ships
# --------------------------------------------------------------------------------------------

static func aircraft(ci: CanvasItem, kind: String, c: Vector2, rot: float, s: float, t: float, enemy: bool = true, alpha: float = 1.0) -> void:
	var fill := ENEMY_FILL if enemy else Defs.PLAYER_COLOR
	var line := ENEMY_LINE if enemy else Color(0.02, 0.2, 0.22)
	if kind == "stealth":
		fill = STEALTH_FILL
		line = Defs.ENEMY_COLOR
	fill.a *= alpha
	line.a *= alpha
	var pts := xform(shape(kind), c, rot, s)
	match kind:
		"gunship":
			var tail_end := c + Vector2.RIGHT.rotated(rot) * -13.0 * s
			ci.draw_line(c, tail_end, Color(fill, fill.a), 2.5 * s, true)
			ci.draw_line(tail_end + Vector2.UP.rotated(rot) * 3.0 * s, tail_end - Vector2.UP.rotated(rot) * 3.0 * s, Color(line, line.a), 1.5 * s, true)
			poly(ci, pts, fill, line)
			ci.draw_circle(c + Vector2.RIGHT.rotated(rot) * 5.0 * s, 2.0 * s, Color(0.6, 0.85, 1.0, 0.8 * alpha))
			var spin := t * 28.0
			for k in 2:
				var a := spin + k * PI * 0.5
				var d := Vector2.RIGHT.rotated(a) * 13.0 * s
				ci.draw_line(c - d, c + d, Color(0.1, 0.1, 0.1, 0.55 * alpha), 1.6 * s, true)
			ci.draw_arc(c, 13.0 * s, 0, TAU, 24, Color(1, 1, 1, 0.08 * alpha), 6.0 * s, true)
		"missile":
			poly(ci, pts, Color(0.85, 0.85, 0.8, alpha), line)
			ci.draw_line(c + Vector2.RIGHT.rotated(rot) * 6.0 * s, c + Vector2.RIGHT.rotated(rot) * 9.0 * s, Color(fill, alpha), 3.0 * s)
			var flick := 0.7 + 0.3 * sin(t * 40.0)
			var back := c + Vector2.RIGHT.rotated(rot) * -9.5 * s
			var flame := PackedVector2Array([back + Vector2.UP.rotated(rot) * 1.5 * s, back - Vector2.UP.rotated(rot) * 1.5 * s, back - Vector2.RIGHT.rotated(rot) * 7.0 * s * flick])
			ci.draw_colored_polygon(flame, Color(1.0, 0.7, 0.2, 0.9 * alpha))
		_:
			poly(ci, pts, fill, line)
			if kind == "bomber":
				for side in [-1.0, 1.0]:
					for off in [6.0, 11.0]:
						var p := c + Vector2(-2.5, side * off).rotated(rot) * s
						ci.draw_circle(p, 1.6 * s, Color(line, line.a))
			elif kind == "interceptor":
				ci.draw_circle(c + Vector2(4, 0).rotated(rot) * s, 1.6 * s, Color(0.85, 1.0, 1.0, 0.9 * alpha))


static func shadow(ci: CanvasItem, kind: String, c: Vector2, rot: float, s: float, alpha: float = 1.0) -> void:
	if kind == "gunship":
		ci.draw_circle(c, 7.0 * s, Color(0, 0, 0, 0.25 * alpha))
		return
	ci.draw_colored_polygon(xform(shape(kind), c, rot, s), Color(0, 0, 0, 0.25 * alpha))


static func frigate(ci: CanvasItem, c: Vector2, rot: float, s: float, alpha: float = 1.0) -> void:
	var hull := xform(shape("frigate"), c, rot, s)
	poly(ci, hull, Color(0.62, 0.72, 0.76, alpha), Color(0.05, 0.12, 0.15, alpha))
	var deck := xform(PackedVector2Array([Vector2(-6, -3), Vector2(4, -3), Vector2(4, 3), Vector2(-6, 3)]), c, rot, s)
	poly(ci, deck, Color(Defs.PLAYER_COLOR, alpha), Color(0, 0, 0, 0))
	ci.draw_circle(c + Vector2(9, 0).rotated(rot) * s, 2.4 * s, Color(0.2, 0.3, 0.33, alpha))
	ci.draw_line(c + Vector2(9, 0).rotated(rot) * s, c + Vector2(14, 0).rotated(rot) * s, Color(0.2, 0.3, 0.33, alpha), 1.4 * s)


static func carrier(ci: CanvasItem, c: Vector2, rot: float, s: float, alpha: float = 1.0) -> void:
	var hull := xform(shape("carrier"), c, rot, s)
	poly(ci, hull, Color(0.33, 0.35, 0.38, alpha), Color(0.08, 0.08, 0.1, alpha), 1.5)
	var deck := xform(PackedVector2Array([Vector2(-19, -6), Vector2(16, -6), Vector2(21, 0), Vector2(16, 6), Vector2(-19, 6)]), c, rot, s)
	poly(ci, deck, Color(0.22, 0.23, 0.26, alpha), Color(0, 0, 0, 0))
	for k in 6:
		var x := -16.0 + k * 6.0
		ci.draw_line(c + Vector2(x, 0).rotated(rot) * s, c + Vector2(x + 3.0, 0).rotated(rot) * s, Color(0.9, 0.9, 0.85, 0.7 * alpha), 1.0 * s)
	var isl := xform(PackedVector2Array([Vector2(-2, 6), Vector2(7, 6), Vector2(7, 9.5), Vector2(-2, 9.5)]), c, rot, s)
	poly(ci, isl, Color(0.45, 0.47, 0.5, alpha), Color(0.08, 0.08, 0.1, alpha))
	ci.draw_circle(c + Vector2(-14, -3).rotated(rot) * s, 1.8 * s, Color(Defs.ENEMY_COLOR, alpha))
	ci.draw_circle(c + Vector2(10, -2).rotated(rot) * s, 1.8 * s, Color(Defs.ENEMY_COLOR, alpha))


# --------------------------------------------------------------------------------------------
# Structures
# --------------------------------------------------------------------------------------------

static func structure(ci: CanvasItem, kind: String, c: Vector2, s: float, t: float = 0.0, alpha: float = 1.0) -> void:
	match kind:
		"capital":
			_capital(ci, c, s, alpha)
			return
		"city":
			_city(ci, c, s, alpha)
			return
	var ring := Color(Defs.PLAYER_COLOR, alpha)
	ci.draw_circle(c, 15.0 * s, Color(PLATE, PLATE.a * alpha))
	if kind == "decoy":
		for k in 12:
			var a0 := TAU * k / 12.0
			ci.draw_arc(c, 15.0 * s, a0, a0 + TAU / 24.0, 4, ring, 2.0 * s, true)
	else:
		ci.draw_arc(c, 15.0 * s, 0, TAU, 32, ring, 2.0 * s, true)
	var g := Color(GLYPH, alpha)
	var acc := Color(Defs.PLAYER_COLOR, alpha)
	match kind:
		"flak":
			for off in [-2.2, 2.2]:
				var a0 := c + Vector2(off - 1.0, 1.0) * s
				var a1 := c + Vector2(off + 5.5, -10.0) * s
				ci.draw_line(a0, a1, g, 1.7 * s, true)
				ci.draw_circle(a1, 1.2 * s, Color(Defs.GOLD, alpha))
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-9, 9) * s, c + Vector2(9, 9) * s, c + Vector2(6, 4) * s, c + Vector2(-6, 4) * s]), g)
			ci.draw_circle(c + Vector2(0, 3) * s, 5.0 * s, g)
			ci.draw_circle(c + Vector2(0, 3) * s, 2.0 * s, Color(PLATE, alpha))
		"radar":
			ci.draw_line(c + Vector2(0, 2) * s, c + Vector2(0, 8) * s, g, 2.2 * s, true)
			ci.draw_line(c + Vector2(-6, 9) * s, c + Vector2(6, 9) * s, g, 2.2 * s, true)
			var rot := -0.55 + sin(t * 0.9) * 0.18
			var dc := c + Vector2(-1, -2) * s
			var dish := PackedVector2Array()
			for k in 13:
				var u := PI * k / 12.0
				dish.append(dc + Vector2(cos(u) * 10.0, sin(u) * 6.5).rotated(rot) * s)
			for k in range(12, -1, -1):
				var u := PI * k / 12.0
				dish.append(dc + Vector2(cos(u) * 7.5, sin(u) * 2.6).rotated(rot) * s)
			ci.draw_colored_polygon(dish, g)
			var nrm := Vector2(0, -1).rotated(rot)
			ci.draw_line(dc, dc + nrm * 7.0 * s, g, 1.3 * s, true)
			ci.draw_circle(dc + nrm * 7.0 * s, 1.8 * s, Color(Defs.GOLD, alpha))
			var a := t * 2.4
			ci.draw_arc(c, 15.0 * s, a - 0.9, a, 10, Color(1, 1, 1, 0.85 * alpha), 2.6 * s, true)
		"sam":
			ci.draw_rect(Rect2(c + Vector2(-9, 6) * s, Vector2(18, 3) * s), g)
			for off in [-4.0, 2.0]:
				var a := c + Vector2(off - 3.0, 5) * s
				var b := c + Vector2(off + 6.0, -9) * s
				ci.draw_line(a, b, g, 3.2 * s, true)
				ci.draw_circle(b, 1.8 * s, Color(Defs.ENEMY_COLOR.lerp(Color.ORANGE, 0.5), alpha))
		"harbor":
			ci.draw_line(c + Vector2(0, -7) * s, c + Vector2(0, 8) * s, g, 2.2 * s, true)
			ci.draw_arc(c + Vector2(0, -9) * s, 2.5 * s, 0, TAU, 12, g, 1.8 * s, true)
			ci.draw_line(c + Vector2(-5, -3) * s, c + Vector2(5, -3) * s, g, 2.0 * s, true)
			ci.draw_arc(c + Vector2(0, 0) * s, 8.0 * s, PI * 0.15, PI * 0.85, 14, g, 2.2 * s, true)
		"lab", "decoy":
			var flask := PackedVector2Array([Vector2(-3, -9), Vector2(3, -9), Vector2(3, -3), Vector2(8.5, 7), Vector2(-8.5, 7), Vector2(-3, -3)])
			var lf := PackedVector2Array()
			for p in flask:
				lf.append(c + p * s)
			ci.draw_colored_polygon(lf, Color(g, 0.25 * alpha))
			ci.draw_polyline(_closed(lf), g, 1.8 * s, true)
			var liquid := PackedVector2Array([c + Vector2(-6.3, 2.5) * s, c + Vector2(6.3, 2.5) * s, c + Vector2(8.5, 7) * s, c + Vector2(-8.5, 7) * s])
			ci.draw_colored_polygon(liquid, Color(acc, 0.9 * alpha))
			ci.draw_circle(c + Vector2(-1.5, -0.5) * s, 1.2 * s, g)
			ci.draw_circle(c + Vector2(1.5, -4) * s, 0.9 * s, g)
			if kind == "decoy":
				ci.draw_string(UITheme.font_bold, c + Vector2(6, -6) * s, "?", HORIZONTAL_ALIGNMENT_LEFT, -1, int(11 * s), Color(Defs.GOLD, alpha))
		"airbase":
			var rw := xform(PackedVector2Array([Vector2(-12, -3.5), Vector2(12, -3.5), Vector2(12, 3.5), Vector2(-12, 3.5)]), c, -0.55, s)
			ci.draw_colored_polygon(rw, Color(0.25, 0.3, 0.33, alpha))
			ci.draw_polyline(_closed(rw), g, 1.2 * s, true)
			for k in 4:
				var x := -9.0 + k * 5.5
				ci.draw_line(c + Vector2(x, 0).rotated(-0.55) * s, c + Vector2(x + 2.5, 0).rotated(-0.55) * s, g, 1.2 * s)
			aircraft(ci, "interceptor", c + Vector2(3, 5) * s, -0.55, 0.55 * s, t, false, alpha)
		"bunker":
			var dome := PackedVector2Array()
			for k in 13:
				var a := PI + PI * k / 12.0
				dome.append(c + Vector2(cos(a) * 9.5, sin(a) * 9.5 + 5.0) * s)
			ci.draw_colored_polygon(dome, Color(g, 0.85 * alpha))
			ci.draw_rect(Rect2(c + Vector2(-2.2, 0.5) * s, Vector2(4.4, 4.5) * s), Color(PLATE, alpha))
			ci.draw_line(c + Vector2(-11, 5) * s, c + Vector2(11, 5) * s, g, 2.0 * s, true)
		"missile":
			ci.draw_rect(Rect2(c + Vector2(-2.6, -6) * s, Vector2(5.2, 13) * s), g)
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-2.6, -6) * s, c + Vector2(2.6, -6) * s, c + Vector2(0, -12) * s]), Color(Defs.ENEMY_COLOR.lerp(Color.ORANGE, 0.4), alpha))
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-2.6, 3) * s, c + Vector2(-6, 8) * s, c + Vector2(-2.6, 7) * s]), g)
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(2.6, 3) * s, c + Vector2(6, 8) * s, c + Vector2(2.6, 7) * s]), g)
			ci.draw_line(c + Vector2(-2.6, -2) * s, c + Vector2(2.6, -2) * s, acc, 1.5 * s)
		"laser":
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-7, 9) * s, c + Vector2(7, 9) * s, c + Vector2(2.5, -4) * s, c + Vector2(-2.5, -4) * s]), g)
			var pulse := 0.5 + 0.5 * sin(t * 4.0)
			ci.draw_circle(c + Vector2(0, -7) * s, (5.0 + pulse * 2.0) * s, Color(0.4, 1.0, 1.0, 0.25 * alpha))
			ci.draw_circle(c + Vector2(0, -7) * s, 3.2 * s, Color(0.75, 1.0, 1.0, alpha))


static func _capital(ci: CanvasItem, c: Vector2, s: float, alpha: float) -> void:
	ci.draw_circle(c + Vector2(0, 3) * s, 19.0 * s, Color(0, 0, 0, 0.25 * alpha))
	ci.draw_circle(c, 18.0 * s, Color(0.05, 0.1, 0.13, 0.85 * alpha))
	ci.draw_arc(c, 18.0 * s, 0, TAU, 40, Color(Defs.GOLD, alpha), 2.5 * s, true)
	var wall := Color(0.82, 0.86, 0.88, alpha)
	var shade := Color(0.55, 0.6, 0.64, alpha)
	ci.draw_rect(Rect2(c + Vector2(-13, -2) * s, Vector2(6, 11) * s), shade)
	ci.draw_rect(Rect2(c + Vector2(7, -4) * s, Vector2(6, 13) * s), shade)
	ci.draw_rect(Rect2(c + Vector2(-8, -1) * s, Vector2(16, 10) * s), wall)
	var dome := PackedVector2Array()
	for k in 13:
		var a := PI + PI * k / 12.0
		dome.append(c + Vector2(cos(a) * 6.5, sin(a) * 6.5 - 1.0) * s)
	ci.draw_colored_polygon(dome, Color(Defs.GOLD, alpha))
	ci.draw_line(c + Vector2(0, -7.5) * s, c + Vector2(0, -14) * s, wall, 1.4 * s)
	ci.draw_colored_polygon(PackedVector2Array([c + Vector2(0, -14) * s, c + Vector2(6, -12.2) * s, c + Vector2(0, -10.5) * s]), Color(Defs.PLAYER_COLOR, alpha))
	for k in 3:
		ci.draw_rect(Rect2(c + Vector2(-5.5 + k * 4.0, 3) * s, Vector2(2, 3) * s), Color(0.15, 0.2, 0.25, alpha))


static func _city(ci: CanvasItem, c: Vector2, s: float, alpha: float) -> void:
	ci.draw_circle(c + Vector2(0, 3) * s, 15.0 * s, Color(0, 0, 0, 0.2 * alpha))
	ci.draw_arc(c, 15.0 * s, 0, TAU, 32, Color(Defs.PLAYER_COLOR, 0.65 * alpha), 1.5 * s, true)
	var blocks := [
		[Vector2(-11, -3), Vector2(6, 10), Color(0.78, 0.74, 0.68)],
		[Vector2(-5, -8), Vector2(6, 15), Color(0.86, 0.88, 0.9)],
		[Vector2(1, -5), Vector2(6, 12), Color(0.7, 0.75, 0.8)],
		[Vector2(7, -1), Vector2(5, 8), Color(0.82, 0.78, 0.7)],
	]
	for b in blocks:
		var col: Color = b[2]
		col.a = alpha
		ci.draw_rect(Rect2(c + b[0] * s, b[1] * s), col)
		ci.draw_rect(Rect2(c + b[0] * s, Vector2(b[1].x, 1.6) * s), Color(0.35, 0.3, 0.3, alpha))
		for wy in range(int(b[1].y / 3.5)):
			ci.draw_rect(Rect2(c + (b[0] + Vector2(1.5, 3.0 + wy * 3.5)) * s, Vector2(b[1].x - 3.0, 1.2) * s), Color(0.95, 0.85, 0.45, 0.55 * alpha))


static func ruin(ci: CanvasItem, c: Vector2, s: float, seed_value: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	ci.draw_circle(c, 13.0 * s, Color(0.08, 0.07, 0.06, 0.55))
	for k in 6:
		var p := c + Vector2(rng.randf_range(-9, 9), rng.randf_range(-7, 7)) * s
		ci.draw_rect(Rect2(p, Vector2(rng.randf_range(2, 5), rng.randf_range(1.5, 3.5)) * s), Color(0.3, 0.28, 0.26, 0.85))
	for k in 3:
		var p := c + Vector2(rng.randf_range(-6, 6), rng.randf_range(-5, 5)) * s
		ci.draw_circle(p, rng.randf_range(1.5, 3.0) * s, Color(0.02, 0.02, 0.02, 0.6))


# --------------------------------------------------------------------------------------------
# Small UI glyphs (resources)
# --------------------------------------------------------------------------------------------

static func ui_glyph(ci: CanvasItem, kind: String, c: Vector2, s: float, col: Color) -> void:
	match kind:
		"supplies":
			ci.draw_rect(Rect2(c + Vector2(-7, -3) * s, Vector2(14, 10) * s), col)
			ci.draw_rect(Rect2(c + Vector2(-8, -6) * s, Vector2(16, 3.5) * s), col.lightened(0.25))
			ci.draw_line(c + Vector2(0, -6) * s, c + Vector2(0, 7) * s, Color(0, 0, 0, 0.45), 1.5 * s)
		"research":
			ci.draw_arc(c, 7.0 * s, 0, TAU, 20, col, 1.6 * s, true)
			for k in 3:
				var a := k * PI / 3.0
				var pts := PackedVector2Array()
				for j in 21:
					var u := TAU * j / 20.0
					pts.append(c + Vector2(cos(u) * 8.0, sin(u) * 3.0).rotated(a) * s)
				ci.draw_polyline(pts, col, 1.2 * s, true)
			ci.draw_circle(c, 2.0 * s, col)
		"turn":
			ci.draw_arc(c, 7.0 * s, 0, TAU, 24, col, 1.8 * s, true)
			ci.draw_line(c, c + Vector2(0, -5) * s, col, 1.8 * s, true)
			ci.draw_line(c, c + Vector2(4, 1) * s, col, 1.8 * s, true)
		"wave":
			for k in 3:
				aircraft(ci, "bomber", c + Vector2(-5 + k * 5, -3 + k * 3) * s, -PI * 0.5, 0.42 * s, 0.0, true, 1.0)
		"score":
			var pts := PackedVector2Array()
			for k in 10:
				var r := 8.0 if k % 2 == 0 else 3.6
				var a := -PI / 2 + k * PI / 5
				pts.append(c + Vector2(cos(a), sin(a)) * r * s)
			ci.draw_colored_polygon(pts, col)
		"lock":
			ci.draw_rect(Rect2(c + Vector2(-5, -1) * s, Vector2(10, 8) * s), col)
			ci.draw_arc(c + Vector2(0, -1) * s, 3.5 * s, PI, TAU, 10, col, 1.6 * s, true)
		"recon":
			ci.draw_arc(c, 7.0 * s, 0, TAU, 24, col, 1.6 * s, true)
			ci.draw_arc(c, 3.5 * s, 0, TAU, 16, col, 1.2 * s, true)
			ci.draw_line(c + Vector2(-9, 0) * s, c + Vector2(9, 0) * s, col, 1.0 * s)
			ci.draw_line(c + Vector2(0, -9) * s, c + Vector2(0, 9) * s, col, 1.0 * s)
		"strike":
			aircraft(ci, "interceptor", c, -PI * 0.25, 0.8 * s, 0.0, false, 1.0)
		"repair":
			ci.draw_line(c + Vector2(-6, 6) * s, c + Vector2(4, -4) * s, col, 3.0 * s, true)
			ci.draw_arc(c + Vector2(5, -5) * s, 3.5 * s, PI * 0.75, PI * 2.25, 10, col, 2.0 * s, true)
		"resolve":
			emblem(ci, "lantern", c, s * 0.75, col)
		"ally":
			emblem(ci, "compass", c, s * 0.75, col)
		"intel":
			ci.draw_rect(Rect2(c + Vector2(-8, -5) * s, Vector2(16, 12) * s), col, false, 1.6 * s)
			ci.draw_rect(Rect2(c + Vector2(-8, -7) * s, Vector2(7, 3) * s), col)
			for k in 3:
				ci.draw_line(c + Vector2(-5, -1 + k * 3) * s, c + Vector2(5, -1 + k * 3) * s, col, 1.2 * s)
		"cyber":
			ci.draw_rect(Rect2(c + Vector2(-9, -7) * s, Vector2(18, 14) * s), col, false, 1.6 * s)
			ci.draw_polyline(PackedVector2Array([c + Vector2(-6, -3) * s, c + Vector2(-2, 0) * s, c + Vector2(-6, 3) * s]), col, 1.6 * s, true)
			ci.draw_line(c + Vector2(0, 3.5) * s, c + Vector2(5, 3.5) * s, col, 1.6 * s)


## Faction emblems used on comms cards, directives and the Intel Archive.
static func emblem(ci: CanvasItem, kind: String, c: Vector2, s: float, col: Color) -> void:
	match kind:
		"lantern":
			ci.draw_line(c + Vector2(0, -13) * s, c + Vector2(0, -9) * s, col, 1.6 * s)
			ci.draw_arc(c + Vector2(0, -13) * s, 2.0 * s, PI, TAU, 8, col, 1.4 * s, true)
			var body := PackedVector2Array([c + Vector2(-5, -9) * s, c + Vector2(5, -9) * s, c + Vector2(7, -2) * s,
				c + Vector2(5, 6) * s, c + Vector2(-5, 6) * s, c + Vector2(-7, -2) * s])
			ci.draw_colored_polygon(body, Color(col, 0.35))
			ci.draw_polyline(_closed(body), col, 1.6 * s, true)
			ci.draw_circle(c + Vector2(0, -1.5) * s, 2.6 * s, Color(1.0, 0.9, 0.55, col.a))
			for k in 3:
				ci.draw_rect(Rect2(c + Vector2(-9 + k * 6.5, 9) * s, Vector2(5, 4) * s), col)
		"star":
			var pts := PackedVector2Array()
			for k in 18:
				var r := 11.0 if k % 2 == 0 else 5.0
				var a := -PI / 2 + k * PI / 9.0
				pts.append(c + Vector2(cos(a), sin(a)) * r * s + Vector2(0, -2) * s)
			ci.draw_colored_polygon(pts, col)
			var wave := PackedVector2Array()
			for k in 13:
				var x := -12.0 + k * 2.0
				wave.append(c + Vector2(x, 11 + sin(k * 0.9) * 1.6) * s)
			ci.draw_polyline(wave, col, 1.8 * s, true)
		"compass":
			ci.draw_arc(c, 11.0 * s, 0, TAU, 28, col, 1.6 * s, true)
			for k in 4:
				var a := k * PI * 0.5
				var tip := c + Vector2.UP.rotated(a) * 13.0 * s
				var l := c + Vector2.UP.rotated(a + 0.35) * 4.0 * s
				var r := c + Vector2.UP.rotated(a - 0.35) * 4.0 * s
				ci.draw_colored_polygon(PackedVector2Array([tip, l, c, r]), col if k % 2 == 0 else Color(col, 0.55))
			ci.draw_circle(c, 2.0 * s, col)
		"rings":
			for k in 3:
				ci.draw_arc(c + Vector2(-6 + k * 6, 0) * s, 6.5 * s, 0, TAU, 20, col, 1.8 * s, true)
		"wafer":
			ci.draw_arc(c, 11.0 * s, 0, TAU, 28, col, 1.8 * s, true)
			for gx in range(-2, 3):
				for gy in range(-2, 3):
					if absi(gx) + absi(gy) <= 3:
						ci.draw_rect(Rect2(c + Vector2(gx * 4.2 - 1.7, gy * 4.2 - 1.7) * s, Vector2(3.4, 3.4) * s), Color(col, 0.85))
		"grid":
			for k in 4:
				ci.draw_line(c + Vector2(-10 + k * 6.6, -10) * s, c + Vector2(-10 + k * 6.6, 10) * s, col, 1.3 * s)
				ci.draw_line(c + Vector2(-10, -10 + k * 6.6) * s, c + Vector2(10, -10 + k * 6.6) * s, col, 1.3 * s)
			ci.draw_circle(c, 3.0 * s, col)
		"null":
			ci.draw_arc(c, 9.0 * s, 0, TAU, 24, col, 2.2 * s, true)
			ci.draw_line(c + Vector2(-11, 11) * s, c + Vector2(11, -11) * s, col, 2.2 * s, true)
