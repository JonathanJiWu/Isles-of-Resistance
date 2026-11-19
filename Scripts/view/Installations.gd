class_name Installations
extends RefCounted
## World art for structures: recognisable installations drawn in the map's oblique 3/4 view
## (ground plane seen from above, heights rise straight up the screen, walls facing the viewer
## are visible). draw_base() renders the static part once per structure; draw_live() renders
## lights and moving parts every frame. UI icons keep using the flat glyphs in Icons.gd.
##
## `info` keys: kind, facing (hex direction 0-5 toward water, -1 if inland), axis (runway angle),
## seed (variation), style (city style), foundry (bool), stage (0 intact, 1 damaged, 2 critical).

const GRAVEL := Color(0.31, 0.31, 0.3)
const GRAVEL_EDGE := Color(0.42, 0.41, 0.38)
const CONCRETE := Color(0.42, 0.44, 0.47)
const CONCRETE_DARK := Color(0.27, 0.29, 0.32)
const ASPHALT := Color(0.11, 0.12, 0.14)
const STONE := Color(0.44, 0.45, 0.47)
const EARTH := Color(0.27, 0.25, 0.17)
const SANDBAG := Color(0.47, 0.42, 0.29)
const GRASS := Color(0.17, 0.27, 0.15)
const OLIVE := Color(0.42, 0.47, 0.32)
const OLIVE_DARK := Color(0.27, 0.31, 0.21)
const STEEL := Color(0.6, 0.65, 0.69)
const STEEL_DARK := Color(0.32, 0.36, 0.4)
const WALL := Color(0.62, 0.66, 0.71)
const ROOF := Color(0.5, 0.53, 0.57)
const WHITE := Color(0.84, 0.87, 0.9)
const TILE_ROOF := Color(0.46, 0.22, 0.17)
const WINDOW := Color(1.0, 0.84, 0.5)
const GLASS := Color(0.3, 0.7, 0.78)
const RED_LIGHT := Color(1.0, 0.22, 0.22)
const GREEN_LIGHT := Color(0.35, 1.0, 0.55)
const AMBER := Color(1.0, 0.7, 0.25)
const NEON_PINK := Color(1.0, 0.4, 0.75)

## How far above the structure's centre the art reaches (for HP bars and labels).
const HEIGHTS := {"radar": 40.0, "power": 38.0, "capital": 50.0, "city": 32.0, "cable": 30.0, "foundry": 30.0}


static func top_extent(kind: String, foundry: bool = false) -> float:
	if foundry:
		return HEIGHTS["foundry"]
	return HEIGHTS.get(kind, 18.0)


## Unit vector toward a hex neighbour (axial direction index 0-5, see Hex.DIRS).
static func dir_vec(f: int) -> Vector2:
	return Vector2.RIGHT.rotated(-PI / 3.0 * float(f))


static func _rng(seed_value: int) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = seed_value
	return r


# --------------------------------------------------------------------------------------------
# Primitives
# --------------------------------------------------------------------------------------------

## Organic ground footprint (gravel, concrete, earth) so sites sit in the landscape instead of
## on a token. Deterministic per radius so static redraws match.
static func pad(ci: CanvasItem, r: float, col: Color, edge: Color, offset: Vector2 = Vector2.ZERO) -> void:
	var outer := PackedVector2Array()
	var inner := PackedVector2Array()
	for k in 18:
		var a := TAU * k / 18.0
		var wob := 1.0 + 0.07 * sin(a * 3.0 + r) + 0.05 * sin(a * 5.0 + r * 0.7)
		outer.append(offset + Vector2(cos(a), sin(a) * 0.86) * r * wob * 1.06)
		inner.append(offset + Vector2(cos(a), sin(a) * 0.86) * r * wob)
	ci.draw_colored_polygon(outer, Color(col, col.a * 0.45))
	ci.draw_colored_polygon(inner, col)
	inner.append(inner[0])
	ci.draw_polyline(inner, Color(edge, edge.a * 0.6), 1.0, true)


## Perimeter lights: the ownership cue for military sites (teal) and infrastructure (amber).
static func perimeter(ci: CanvasItem, r: float, col: Color, n: int = 14) -> void:
	for k in n:
		var a := TAU * (k + 0.5) / n
		var p := Vector2(cos(a), sin(a) * 0.86) * r
		ci.draw_circle(p, 2.2, Color(col, 0.12))
		ci.draw_circle(p, 0.8, Color(col.lightened(0.3), 0.9))


static func _footprint(c: Vector2, w: float, d: float, rot: float) -> PackedVector2Array:
	var ax := Vector2.RIGHT.rotated(rot) * (w * 0.5)
	var ay := Vector2.DOWN.rotated(rot) * (d * 0.5)
	return PackedVector2Array([c - ax - ay, c + ax - ay, c + ax + ay, c - ax + ay])


static func shadow_poly(ci: CanvasItem, pts: PackedVector2Array, h: float, alpha: float = 0.32) -> void:
	var off := Vector2(2.0 + h * 0.42, 1.0 + h * 0.2)
	var all := PackedVector2Array()
	for p in pts:
		all.append(p)
		all.append(p + off)
	var hull := Geometry2D.convex_hull(all)
	# convex_hull() repeats the first point at the end; drop it so triangulation succeeds.
	if hull.size() > 1 and hull[0].is_equal_approx(hull[hull.size() - 1]):
		hull.remove_at(hull.size() - 1)
	if hull.size() >= 3:
		ci.draw_colored_polygon(hull, Color(0, 0, 0, alpha))


## A box standing on the ground: footprint w x d centred on c, rotated by rot, height h.
## Returns the visible wall quads (ground a, ground b, top b, top a) for window placement.
static func box(ci: CanvasItem, c: Vector2, w: float, d: float, h: float, rot: float, top: Color, wall: Color,
		shadow: bool = true) -> Array:
	var g := _footprint(c, w, d, rot)
	if shadow:
		shadow_poly(ci, g, h)
	var up := Vector2(0, -h)
	var walls: Array = []
	for i in 4:
		var a: Vector2 = g[i]
		var b: Vector2 = g[(i + 1) % 4]
		var n := ((a + b) * 0.5 - c).normalized()
		if n.y <= 0.02:
			continue
		var shade := clampf(1.0 - 0.22 * n.x, 0.7, 1.15)
		var wc := Color(wall.r * shade, wall.g * shade, wall.b * shade, wall.a)
		ci.draw_colored_polygon(PackedVector2Array([a, b, b + up, a + up]), wc)
		walls.append([a, b, b + up, a + up])
	var t := PackedVector2Array()
	for p in g:
		t.append(p + up)
	ci.draw_colored_polygon(t, top)
	t.append(t[0])
	ci.draw_polyline(t, Color(top.lightened(0.28), 0.55), 1.0, true)
	return walls


## Lit windows on the visible walls of a box.
static func windows(ci: CanvasItem, walls: Array, rows: int, cols: int, col: Color, seed_value: int, lit: float = 0.7) -> void:
	var r := _rng(seed_value)
	for wq in walls:
		var a: Vector2 = wq[0]
		var b: Vector2 = wq[1]
		var tb: Vector2 = wq[2]
		var ta: Vector2 = wq[3]
		var span := a.distance_to(b)
		var n_cols := maxi(1, int(round(cols * span / 20.0)))
		for row in rows:
			var v := (row + 0.65) / float(rows + 0.3)
			for k in n_cols:
				var u := (k + 0.5) / float(n_cols)
				var bottom := a.lerp(b, u)
				var top := ta.lerp(tb, u)
				var p := bottom.lerp(top, v)
				var on := r.randf() < lit
				var wc := col if on else Color(0.08, 0.1, 0.14, 0.9)
				ci.draw_rect(Rect2(p - Vector2(0.9, 0.7), Vector2(1.8, 1.3)), wc)


## Vertical cylinder (tank, silo, chimney) of radius r and height h standing on c.
static func cylinder(ci: CanvasItem, c: Vector2, r: float, h: float, side: Color, top: Color, shadow: bool = true) -> void:
	if shadow:
		var sh := PackedVector2Array()
		for k in 16:
			var a := TAU * k / 16.0
			sh.append(c + Vector2(cos(a), sin(a)) * r)
		shadow_poly(ci, sh, h, 0.28)
	var band := PackedVector2Array()
	for k in 13:
		var a := PI * k / 12.0
		band.append(c + Vector2(cos(a), sin(a)) * r)
	for k in range(12, -1, -1):
		var a := PI * k / 12.0
		band.append(c + Vector2(cos(a), sin(a)) * r + Vector2(0, -h))
	ci.draw_colored_polygon(band, side)
	var dark := PackedVector2Array()
	for k in 7:
		var a := PI * 0.5 * k / 6.0
		dark.append(c + Vector2(cos(a), sin(a)) * r)
	for k in range(6, -1, -1):
		var a := PI * 0.5 * k / 6.0
		dark.append(c + Vector2(cos(a), sin(a)) * r + Vector2(0, -h))
	ci.draw_colored_polygon(dark, Color(0, 0, 0, 0.18))
	ci.draw_circle(c + Vector2(0, -h), r, top)
	ci.draw_arc(c + Vector2(0, -h), r, PI * 0.9, PI * 1.6, 8, Color(1, 1, 1, 0.25), 1.0, true)


static func sphere(ci: CanvasItem, c: Vector2, r: float, col: Color) -> void:
	ci.draw_circle(c + Vector2(r * 0.45, r * 0.3), r, Color(0, 0, 0, 0.25))
	ci.draw_circle(c, r, col)
	ci.draw_circle(c + Vector2(r * 0.25, r * 0.25), r * 0.75, Color(0, 0, 0, 0.12))
	ci.draw_circle(c - Vector2(r * 0.35, r * 0.35), r * 0.3, Color(1, 1, 1, 0.35))


static func lattice(ci: CanvasItem, base: Vector2, h: float, wb: float, wt: float, col: Color, width: float = 1.1) -> void:
	var bl := base + Vector2(-wb, 0)
	var br := base + Vector2(wb, 0)
	var tl := base + Vector2(-wt, -h)
	var tr := base + Vector2(wt, -h)
	ci.draw_line(bl, tl, col, width + 0.3, true)
	ci.draw_line(br, tr, col, width + 0.3, true)
	var n := maxi(2, int(h / 6.0))
	var prev_l := bl
	var prev_r := br
	for k in range(1, n + 1):
		var f := float(k) / n
		var l := bl.lerp(tl, f)
		var r := br.lerp(tr, f)
		ci.draw_line(l, r, col, width * 0.8, true)
		ci.draw_line(prev_l, r, Color(col, col.a * 0.7), width * 0.6, true)
		ci.draw_line(prev_r, l, Color(col, col.a * 0.7), width * 0.6, true)
		prev_l = l
		prev_r = r


static func glow(ci: CanvasItem, p: Vector2, col: Color, r: float = 1.4, strength: float = 1.0) -> void:
	ci.draw_circle(p, r * 3.2, Color(col, 0.1 * strength))
	ci.draw_circle(p, r * 1.8, Color(col, 0.22 * strength))
	ci.draw_circle(p, r, Color(col.lightened(0.3), minf(1.0, strength)))


static func blink(t: float, period: float, duty: float = 0.5, phase: float = 0.0) -> bool:
	return fmod(t + phase, period) < period * duty


## A small truck: cab + bed, oriented along rot.
static func truck(ci: CanvasItem, c: Vector2, rot: float, length: float, col: Color) -> void:
	var ax := Vector2.RIGHT.rotated(rot)
	box(ci, c - ax * (length * 0.12), length * 0.76, 5.0, 2.6, rot, col.lightened(0.08), col.darkened(0.25))
	box(ci, c + ax * (length * 0.4), length * 0.22, 4.6, 3.6, rot, col.lightened(0.15), col.darkened(0.2), false)


static func camo_net(ci: CanvasItem, c: Vector2, r: float, seed_value: int) -> void:
	var rr := _rng(seed_value)
	var pts := PackedVector2Array()
	for k in 9:
		var a := TAU * k / 9.0
		pts.append(c + Vector2(cos(a), sin(a) * 0.75) * r * rr.randf_range(0.75, 1.15))
	ci.draw_colored_polygon(pts, Color(0.18, 0.24, 0.15, 0.85))
	for k in 7:
		var p := c + Vector2(rr.randf_range(-r, r), rr.randf_range(-r, r) * 0.6) * 0.7
		ci.draw_circle(p, rr.randf_range(1.0, 2.2), Color(0.28, 0.32, 0.2, 0.8))


static func tiny_text(ci: CanvasItem, p: Vector2, text: String, size: int, col: Color) -> void:
	var font: Font = UITheme.font_bold
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	ci.draw_string(font, p - Vector2(w * 0.5, 0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)


# --------------------------------------------------------------------------------------------
# Entry points
# --------------------------------------------------------------------------------------------

static func draw_base(ci: CanvasItem, info: Dictionary) -> void:
	var kind: String = info.get("kind", "")
	if info.get("foundry", false):
		_foundry(ci, info)
	else:
		match kind:
			"capital": _capital(ci, info)
			"city": _city(ci, info)
			"flak": _flak(ci, info)
			"radar": _radar(ci, info)
			"sam": _sam(ci, info)
			"airbase": _airbase(ci, info)
			"harbor": _harbor(ci, info)
			"lab": _lab(ci, info)
			"bunker": _bunker(ci, info)
			"decoy": _decoy(ci, info)
			"missile": _coastal_battery(ci, info)
			"laser": _laser(ci, info)
			"power": _power(ci, info)
			"cable": _cable(ci, info)
			_:
				pad(ci, 22.0, CONCRETE, GRAVEL_EDGE)
	var stage: int = info.get("stage", 0)
	if stage > 0:
		_damage_marks(ci, stage, int(info.get("seed", 0)), kind)


static func draw_live(ci: CanvasItem, info: Dictionary, t: float) -> void:
	var kind: String = info.get("kind", "")
	var seed_value: int = info.get("seed", 0)
	var ph := float(seed_value % 97) * 0.13
	if info.get("foundry", false):
		_foundry_live(ci, t, ph)
	else:
		match kind:
			"capital": _capital_live(ci, t, ph)
			"city": _city_live(ci, info, t, ph)
			"flak": _flak_live(ci, info, t, ph)
			"radar": _radar_live(ci, t, ph)
			"sam": _sam_live(ci, info, t, ph)
			"airbase": _airbase_live(ci, info, t, ph)
			"harbor": _harbor_live(ci, info, t, ph)
			"lab": _lab_live(ci, t, ph)
			"bunker": _bunker_live(ci, t, ph)
			"decoy": _decoy_live(ci, t, ph)
			"missile": _battery_live(ci, info, t, ph)
			"laser": _laser_live(ci, t, ph)
			"power": _power_live(ci, info, t, ph)
			"cable": _cable_live(ci, t, ph)
	var stage: int = info.get("stage", 0)
	if stage > 0:
		smoke(ci, Vector2(-3, -4), t, ph, 1.0 if stage == 1 else 1.6, stage >= 2)


static func needs_live(_kind: String) -> bool:
	return true


# --------------------------------------------------------------------------------------------
# Damage, smoke, fire, ruins
# --------------------------------------------------------------------------------------------

static func _damage_marks(ci: CanvasItem, stage: int, seed_value: int, kind: String) -> void:
	var r := _rng(seed_value * 13 + 7)
	for k in 2 + stage * 2:
		var p := Vector2(r.randf_range(-16, 16), r.randf_range(-10, 12))
		var blob := PackedVector2Array()
		var rad := r.randf_range(3.0, 6.5)
		for j in 8:
			var a := TAU * j / 8.0
			blob.append(p + Vector2(cos(a), sin(a) * 0.7) * rad * r.randf_range(0.6, 1.2))
		ci.draw_colored_polygon(blob, Color(0.03, 0.03, 0.03, 0.55))
	for k in 4 + stage * 4:
		var p := Vector2(r.randf_range(-18, 18), r.randf_range(-12, 14))
		ci.draw_rect(Rect2(p, Vector2(r.randf_range(1.5, 3.5), r.randf_range(1.0, 2.2))), Color(0.18, 0.17, 0.16, 0.9))
	if kind == "airbase":
		return
	if stage >= 2:
		for k in 2:
			var p := Vector2(r.randf_range(-10, 10), r.randf_range(-12, 2))
			ci.draw_colored_polygon(PackedVector2Array([p, p + Vector2(5, 1), p + Vector2(3, 4), p + Vector2(-1, 3)]), Color(0.02, 0.02, 0.03, 0.85))


## Rising smoke column (deterministic, animated with t). Fire adds flickering flames at the base.
static func smoke(ci: CanvasItem, base: Vector2, t: float, ph: float, size: float = 1.0, fire: bool = false) -> void:
	if fire:
		for k in 3:
			var fx := base + Vector2(-5 + k * 5, 2)
			var fl := 0.65 + 0.35 * sin(t * 13.0 + k * 2.1 + ph)
			var tip := fx + Vector2(sin(t * 7.0 + k) * 1.5, -9.0 * fl * size)
			ci.draw_colored_polygon(PackedVector2Array([fx + Vector2(-3, 0), fx + Vector2(3, 0), tip]), Color(1.0, 0.5, 0.12, 0.9))
			ci.draw_colored_polygon(PackedVector2Array([fx + Vector2(-1.5, 0), fx + Vector2(1.5, 0), fx.lerp(tip, 0.6)]), Color(1.0, 0.88, 0.45, 0.95))
		ci.draw_circle(base, 10.0 * size, Color(1.0, 0.45, 0.1, 0.08 + 0.04 * sin(t * 9.0)))
	for k in 7:
		var f := fmod(t * 0.28 + k / 7.0 + ph, 1.0)
		var p := base + Vector2(sin(f * 5.0 + k + ph) * 3.0 + f * 14.0, -f * 44.0 * size)
		var rad := (2.5 + f * 8.0) * size
		var g := 0.12 + 0.1 * (1.0 - f)
		ci.draw_circle(p, rad, Color(g, g, g * 1.05, (1.0 - f) * 0.42))


## A destroyed installation's remains (drawn once into the terrain layer).
static func ruin(ci: CanvasItem, kind: String, c: Vector2, seed_value: int) -> void:
	var r := _rng(seed_value)
	var scorch := PackedVector2Array()
	for j in 12:
		var a := TAU * j / 12.0
		scorch.append(c + Vector2(cos(a), sin(a) * 0.72) * 21.0 * r.randf_range(0.75, 1.15))
	ci.draw_colored_polygon(scorch, Color(0.04, 0.035, 0.03, 0.6))
	match kind:
		"radar", "cable":
			ci.draw_line(c + Vector2(-8, 4), c + Vector2(14, -3), Color(0.35, 0.38, 0.4), 1.6, true)
			ci.draw_line(c + Vector2(-6, 6), c + Vector2(15, 0), Color(0.3, 0.32, 0.34), 1.2, true)
			for k in 4:
				ci.draw_line(c + Vector2(-6 + k * 5, 5 - k * 1.8), c + Vector2(-3 + k * 5, 2 - k * 1.8), Color(0.3, 0.32, 0.34), 1.0)
		"airbase":
			ci.draw_line(c + Vector2(-24, 10), c + Vector2(24, -12), Color(0.12, 0.12, 0.13), 7.0)
			for k in 5:
				var p := c + Vector2(-20 + k * 10, 8 - k * 4.5)
				ci.draw_circle(p, 3.2, Color(0.02, 0.02, 0.02, 0.9))
				ci.draw_arc(p, 3.6, 0, TAU, 10, Color(0.4, 0.36, 0.3, 0.7), 1.0)
		"city", "capital":
			for k in 7:
				var p := c + Vector2(r.randf_range(-16, 14), r.randf_range(-8, 10))
				var w := r.randf_range(4, 9)
				var h := r.randf_range(2, 7)
				ci.draw_colored_polygon(PackedVector2Array([p, p + Vector2(w, 0), p + Vector2(w * 0.8, -h), p + Vector2(w * 0.15, -h * r.randf_range(0.3, 1.0))]), Color(0.3, 0.3, 0.31))
	for k in 9:
		var p := c + Vector2(r.randf_range(-15, 15), r.randf_range(-10, 10))
		ci.draw_rect(Rect2(p, Vector2(r.randf_range(2, 5), r.randf_range(1.5, 3.5))), Color(0.26, 0.25, 0.24, 0.95))
	for k in 3:
		var p := c + Vector2(r.randf_range(-8, 8), r.randf_range(-6, 6))
		ci.draw_circle(p, r.randf_range(1.5, 3.0), Color(0.01, 0.01, 0.01, 0.7))


# --------------------------------------------------------------------------------------------
# Air defence
# --------------------------------------------------------------------------------------------

const _FLAK_PITS := [Vector2(-9, -3), Vector2(9, 6)]


static func _flak(ci: CanvasItem, info: Dictionary) -> void:
	pad(ci, 24.0, GRAVEL, GRAVEL_EDGE)
	perimeter(ci, 24.0 + 2.5, Defs.PLAYER_COLOR)
	for p in _FLAK_PITS:
		ci.draw_circle(p + Vector2(1.5, 1.5), 10.0, Color(0, 0, 0, 0.3))
		ci.draw_circle(p, 9.5, SANDBAG.darkened(0.2))
		for k in 10:
			var a := TAU * k / 10.0
			ci.draw_circle(p + Vector2(cos(a), sin(a)) * 8.0, 2.2, SANDBAG if k % 2 == 0 else SANDBAG.darkened(0.12))
		ci.draw_circle(p, 6.2, EARTH.darkened(0.35))
		box(ci, p, 5.5, 5.5, 2.2, 0.0, OLIVE, OLIVE_DARK, false)
	# Fire-control radar trailer and ammunition bunker.
	box(ci, Vector2(13, -10), 9.0, 5.0, 3.0, 0.0, OLIVE.lightened(0.05), OLIVE_DARK)
	ci.draw_line(Vector2(13, -13), Vector2(13, -18), STEEL_DARK, 1.2)
	var walls := box(ci, Vector2(-13, 12), 9.0, 5.0, 4.0, 0.0, CONCRETE, CONCRETE_DARK)
	if not walls.is_empty():
		var w: Array = walls[0]
		var mid: Vector2 = (w[0] as Vector2).lerp(w[1], 0.5)
		ci.draw_rect(Rect2(mid + Vector2(-1.6, -3.2), Vector2(3.2, 3.2)), Color(0.05, 0.06, 0.07))


static func _gun_barrels(ci: CanvasItem, p: Vector2, aim: float, col: Color) -> void:
	var dir := Vector2(cos(aim), sin(aim) * 0.55) * 8.0 + Vector2(0, -7.5)
	var side := Vector2(cos(aim + PI * 0.5), sin(aim + PI * 0.5) * 0.55) * 1.4
	var base := p + Vector2(0, -2.6)
	for s in [-1.0, 1.0]:
		ci.draw_line(base + side * s, base + side * s + dir, col, 1.5, true)
		ci.draw_circle(base + side * s + dir, 0.9, Color(0.1, 0.1, 0.1))
	ci.draw_circle(base, 2.3, col.lightened(0.1))


static func _flak_live(ci: CanvasItem, info: Dictionary, t: float, ph: float) -> void:
	var facing: int = info.get("facing", 0)
	var base_aim := dir_vec(facing if facing >= 0 else 0).angle()
	for i in _FLAK_PITS.size():
		var aim := base_aim + sin(t * 0.35 + ph + i * 1.7) * 0.9
		_gun_barrels(ci, _FLAK_PITS[i], aim, Color(0.42, 0.47, 0.34))
	var bar := absf(cos(t * 2.2 + ph)) * 6.0
	ci.draw_line(Vector2(13 - bar, -18.5), Vector2(13 + bar, -18.5), STEEL, 1.6, true)
	if blink(t, 1.6, 0.12, ph):
		glow(ci, Vector2(13, -19.5), RED_LIGHT, 0.9, 0.8)


static func _radar(ci: CanvasItem, info: Dictionary) -> void:
	pad(ci, 24.0, GRAVEL, GRAVEL_EDGE)
	perimeter(ci, 24.0 + 2.5, Defs.PLAYER_COLOR)
	var fence := Hex.corners(Vector2.ZERO, 25.5)
	for k in 6:
		var a: Vector2 = fence[k]
		var b: Vector2 = fence[(k + 1) % 6]
		for j in 8:
			ci.draw_line(a.lerp(b, j / 8.0), a.lerp(b, (j + 0.55) / 8.0), Color(0.6, 0.65, 0.68, 0.45), 1.0)
	box(ci, Vector2(-14, 12), 7.0, 5.0, 3.5, 0.0, OLIVE, OLIVE_DARK)
	var walls := box(ci, Vector2(6, 13), 12.0, 6.0, 5.0, 0.0, ROOF, WALL)
	windows(ci, walls, 1, 3, Color(GREEN_LIGHT, 0.8), 11, 0.6)
	cylinder(ci, Vector2(12, 0), 6.0, 3.0, CONCRETE, CONCRETE.lightened(0.1))
	sphere(ci, Vector2(12, -8), 7.5, WHITE)
	ci.draw_line(Vector2(5.5, -8), Vector2(18.5, -8), Color(0.65, 0.7, 0.72, 0.5), 0.8)
	lattice(ci, Vector2(-6, 6), 30.0, 6.5, 2.0, STEEL_DARK.lightened(0.15))
	box(ci, Vector2(-6, -24), 6.0, 4.0, 2.0, 0.0, STEEL_DARK, STEEL_DARK.darkened(0.3), false)


static func _radar_live(ci: CanvasItem, t: float, ph: float) -> void:
	var top := Vector2(-6, -27)
	var th := t * 1.6 + ph
	var cw := cos(th)
	var w := 11.0 * absf(cw)
	var face := STEEL if cw > 0 else STEEL_DARK
	ci.draw_colored_polygon(PackedVector2Array([top + Vector2(-w, -4), top + Vector2(w, -4), top + Vector2(w, 1.5), top + Vector2(-w, 1.5)]), face)
	if cw > 0.2:
		for k in 4:
			var x := -w + (k + 0.5) * w * 0.5
			ci.draw_line(top + Vector2(x, -3.5), top + Vector2(x, 1.0), Color(0.2, 0.25, 0.3, 0.8), 0.8)
	ci.draw_line(top + Vector2(0, 1.5), top + Vector2(0, 3.5), STEEL_DARK, 1.5)
	if blink(t, 1.2, 0.35, ph):
		glow(ci, Vector2(-6, -33), RED_LIGHT, 1.1)
	var a := t * 1.6 + ph
	ci.draw_arc(Vector2(-6, 6), 27.0, a - 0.7, a, 10, Color(Defs.PLAYER_COLOR, 0.18), 3.0, true)


static func _sam_layout(info: Dictionary) -> Dictionary:
	var facing: int = info.get("facing", 0)
	var u := dir_vec(facing if facing >= 0 else 0)
	var v := u.orthogonal()
	return {"u": u, "v": v, "aim": u.angle(),
		"launchers": [-u * 4.0 + v * 13.0, u * 2.0 + v * 1.0, -u * 4.0 - v * 13.0],
		"radar": -u * 10.0 + v * 4.0, "van": -u * 13.0 - v * 9.0}


## Launcher vehicle: truck with a canister pack raised toward `aim` (the threat or the sea).
static func _launcher(ci: CanvasItem, p: Vector2, aim: float, col: Color, tubes: int, raised: float) -> void:
	var fwd := Vector2(cos(aim), sin(aim))
	truck(ci, p - fwd * 1.5, aim, 12.0, col)
	var dir := Vector2(cos(aim), sin(aim) * 0.6)
	var side := Vector2(-sin(aim), cos(aim) * 0.6).normalized()
	var base := p - dir * 4.0 + Vector2(0, -3.2)
	var tip := base + dir * 6.5 + Vector2(0, -raised)
	var half := 1.6 + float(tubes) * 0.85
	var quad := PackedVector2Array([base - side * half, base + side * half, tip + side * half, tip - side * half])
	ci.draw_colored_polygon(quad, Color(0.66, 0.67, 0.55))
	var edge := PackedVector2Array([tip - side * half, tip + side * half, tip + side * half + Vector2(0, 2.2), tip - side * half + Vector2(0, 2.2)])
	ci.draw_colored_polygon(edge, Color(0.5, 0.52, 0.42))
	ci.draw_polyline(PackedVector2Array([quad[0], quad[1], quad[2], quad[3], quad[0]]), Color(0.15, 0.17, 0.12), 0.9, true)
	ci.draw_line(base, tip, Color(0.3, 0.32, 0.25, 0.7), 0.8)
	for k in tubes:
		var o := -half + (k + 0.5) * half * 2.0 / tubes
		ci.draw_circle(tip + side * o + Vector2(0, 1.1), 0.95, Color(0.95, 0.55, 0.2))


static func _sam(ci: CanvasItem, info: Dictionary) -> void:
	pad(ci, 25.0, GRAVEL, GRAVEL_EDGE)
	perimeter(ci, 25.0 + 2.5, Defs.PLAYER_COLOR)
	var L := _sam_layout(info)
	for p in L["launchers"]:
		var u: Vector2 = L["u"]
		var berm := PackedVector2Array()
		for k in 9:
			var a: float = u.angle() + PI * 0.5 + PI * k / 8.0
			berm.append(p + Vector2(cos(a), sin(a)) * 8.5)
		ci.draw_polyline(berm, EARTH.lightened(0.1), 3.0, true)
	var radar: Vector2 = L["radar"]
	truck(ci, radar, L["aim"] + PI * 0.5, 11.0, OLIVE)
	var u2: Vector2 = L["u"]
	var v2: Vector2 = L["v"]
	var pc := radar + Vector2(0, -6)
	var panel := PackedVector2Array([pc - v2 * 5.5 + Vector2(0, 4), pc + v2 * 5.5 + Vector2(0, 4), pc + v2 * 4.5 + u2 * 1.5 + Vector2(0, -5), pc - v2 * 4.5 + u2 * 1.5 + Vector2(0, -5)])
	ci.draw_colored_polygon(panel, Color(0.7, 0.74, 0.72))
	for k in 4:
		ci.draw_line(panel[0].lerp(panel[3], k / 4.0), panel[1].lerp(panel[2], k / 4.0), Color(0.35, 0.4, 0.4, 0.8), 0.8)
	camo_net(ci, L["van"], 7.0, int(info.get("seed", 0)))
	box(ci, L["van"], 8.0, 5.0, 4.5, 0.0, OLIVE.darkened(0.05), OLIVE_DARK)
	ci.draw_line(L["van"] + Vector2(2, -4.5), L["van"] + Vector2(2, -13), STEEL_DARK, 0.9)


static func _sam_live(ci: CanvasItem, info: Dictionary, t: float, ph: float) -> void:
	var L := _sam_layout(info)
	var i := 0
	for p in L["launchers"]:
		_launcher(ci, p, L["aim"], OLIVE, 2, 5.5)
		i += 1
	var radar: Vector2 = L["radar"]
	if blink(t, 0.9, 0.5, ph):
		glow(ci, radar + Vector2(0, -10.5), GREEN_LIGHT, 0.7, 0.8)
	if blink(t, 2.4, 0.08, ph + 0.4):
		glow(ci, L["van"] + Vector2(2, -13.5), RED_LIGHT, 0.8)


static func _laser(ci: CanvasItem, info: Dictionary) -> void:
	pad(ci, 23.0, CONCRETE_DARK, GRAVEL_EDGE)
	perimeter(ci, 23.0 + 2.5, Defs.PLAYER_COLOR)
	for k in 8:
		var a := PI * 0.15 + PI * 0.7 * k / 8.0
		var p := Vector2(cos(a), sin(a)) * 13.0
		ci.draw_line(p, p + Vector2(cos(a), sin(a)) * 3.5, AMBER if k % 2 == 0 else Color(0.08, 0.08, 0.08), 2.4)
	var c1 := box(ci, Vector2(-13, -7), 10.0, 5.0, 5.0, 0.0, WHITE.darkened(0.1), WALL)
	for w in c1:
		ci.draw_line((w[0] as Vector2).lerp(w[3], 0.5), (w[1] as Vector2).lerp(w[2], 0.5), AMBER, 1.0)
	box(ci, Vector2(-13, 3), 10.0, 5.0, 5.0, 0.0, WHITE.darkened(0.1), WALL)
	var rad := box(ci, Vector2(13, -5), 6.0, 10.0, 6.0, 0.0, STEEL_DARK, STEEL_DARK.darkened(0.2))
	for w in rad:
		for k in 5:
			var f := (k + 0.5) / 5.0
			ci.draw_line((w[0] as Vector2).lerp(w[1], f), (w[3] as Vector2).lerp(w[2], f), Color(0.1, 0.12, 0.14), 0.8)
	ci.draw_polyline(PackedVector2Array([Vector2(-8, 3), Vector2(-4, 6), Vector2(0, 6)]), Color(0.08, 0.08, 0.1), 1.6, true)
	ci.draw_polyline(PackedVector2Array([Vector2(-8, -7), Vector2(-4, -3), Vector2(-1, 0)]), Color(0.08, 0.08, 0.1), 1.6, true)
	box(ci, Vector2(1, 4), 11.0, 11.0, 6.0, 0.0, STEEL_DARK.lightened(0.1), STEEL_DARK.darkened(0.15))
	var dome := PackedVector2Array()
	for k in 13:
		var a := PI + PI * k / 12.0
		dome.append(Vector2(1, -2) + Vector2(cos(a) * 6.5, sin(a) * 5.5))
	ci.draw_colored_polygon(dome, STEEL)
	ci.draw_arc(Vector2(1, -2), 6.5, PI * 1.1, PI * 1.5, 6, Color(1, 1, 1, 0.3), 1.0, true)


static func _laser_live(ci: CanvasItem, t: float, ph: float) -> void:
	var aim := -0.9 + sin(t * 0.3 + ph) * 0.35
	var base := Vector2(1, -6)
	var tip := base + Vector2(cos(aim), sin(aim)) * 9.0
	ci.draw_line(base, tip, STEEL_DARK.lightened(0.2), 5.0, true)
	ci.draw_line(base, tip, STEEL, 3.0, true)
	var pulse := 0.5 + 0.5 * sin(t * 3.0 + ph)
	ci.draw_circle(tip, 4.0 + pulse * 2.0, Color(0.4, 1.0, 1.0, 0.18))
	ci.draw_circle(tip, 2.4, Color(0.75, 1.0, 1.0, 0.95))
	for k in 3:
		var on := blink(t, 1.0, 0.5, ph + k * 0.33)
		ci.draw_circle(Vector2(-16 + k * 3, -9.5), 0.8, GREEN_LIGHT if on else Color(0.1, 0.3, 0.15))


# --------------------------------------------------------------------------------------------
# Airfields, ports, coastal sites
# --------------------------------------------------------------------------------------------

static func _airbase(ci: CanvasItem, info: Dictionary) -> void:
	pad(ci, 26.0, GRASS.darkened(0.15), Color(0.3, 0.38, 0.26, 0.5))
	var rot: float = info.get("axis", 0.52)
	var ax := Vector2.RIGHT.rotated(rot)
	var nv := ax.orthogonal()
	if nv.y > 0:
		nv = -nv
	var rc := -nv * 3.0
	var rw := _footprint(rc, 60.0, 8.0, rot)
	ci.draw_colored_polygon(rw, ASPHALT)
	ci.draw_polyline(PackedVector2Array([rw[0], rw[1], rw[2], rw[3], rw[0]]), Color(0.55, 0.58, 0.6, 0.6), 0.8, true)
	for k in 9:
		var f := -24.0 + k * 6.0
		ci.draw_line(rc + ax * f, rc + ax * (f + 3.0), Color(0.9, 0.9, 0.85, 0.75), 0.9)
	for e in [-1.0, 1.0]:
		var end: Vector2 = rc + ax * 27.5 * e
		for k in 4:
			var o := -2.6 + k * 1.75
			ci.draw_line(end + nv * o - ax * 1.5 * e, end + nv * o + ax * 0.8 * e, Color(0.9, 0.9, 0.85, 0.8), 0.9)
	var tw := rc + nv * 9.0
	ci.draw_line(tw - ax * 20.0, tw + ax * 20.0, Color(0.16, 0.17, 0.19), 3.0)
	ci.draw_line(tw - ax * 20.0, rc - ax * 20.0, Color(0.16, 0.17, 0.19), 3.0)
	ci.draw_line(tw + ax * 20.0, rc + ax * 20.0, Color(0.16, 0.17, 0.19), 3.0)
	# Hardened aircraft shelters face the taxiway; control tower and fuel farm behind them.
	for k in 2:
		var hp: Vector2 = tw + nv * 9.0 + ax * (-12.0 + k * 13.0)
		var g := _footprint(hp, 10.0, 8.0, rot)
		shadow_poly(ci, g, 5.0)
		var up := Vector2(0, -5)
		ci.draw_colored_polygon(PackedVector2Array([g[2], g[3], g[3] + up, g[2] + up]), CONCRETE_DARK)
		ci.draw_colored_polygon(PackedVector2Array([g[0] + up, g[1] + up, g[2] + up, g[3] + up]), CONCRETE)
		ci.draw_line(((g[0] + g[1]) * 0.5) + up, ((g[2] + g[3]) * 0.5) + up, Color(1, 1, 1, 0.22), 2.0)
		var door_a: Vector2 = g[3].lerp(g[2], 0.25)
		var door_b: Vector2 = g[3].lerp(g[2], 0.75)
		ci.draw_colored_polygon(PackedVector2Array([door_a, door_b, door_b + up * 0.8, door_a + up * 0.8]), Color(0.04, 0.05, 0.06))
	var tower_p := tw + nv * 10.0 + ax * 16.0
	var walls := box(ci, tower_p, 4.0, 4.0, 11.0, 0.0, CONCRETE, WALL)
	box(ci, tower_p + Vector2(0, -11), 6.5, 6.0, 3.0, 0.0, Color(0.2, 0.45, 0.5), GLASS, false)
	cylinder(ci, tw + nv * 4.0 + ax * 24.0, 3.0, 4.0, WHITE.darkened(0.15), WHITE)
	cylinder(ci, tw + nv * 9.5 + ax * 24.5, 3.0, 4.0, WHITE.darkened(0.15), WHITE)
	if info.get("stage", 0) >= 1:
		var r := _rng(int(info.get("seed", 0)) * 5 + 3)
		for k in 2 + int(info.get("stage", 0)) * 2:
			var p := rc + ax * r.randf_range(-24, 24) + nv * r.randf_range(-2, 2)
			ci.draw_circle(p, r.randf_range(2.0, 3.2), Color(0.02, 0.02, 0.02, 0.95))
			ci.draw_arc(p, 3.4, 0, TAU, 10, Color(0.45, 0.4, 0.33, 0.8), 1.0)


static func _airbase_live(ci: CanvasItem, info: Dictionary, t: float, ph: float) -> void:
	var rot: float = info.get("axis", 0.52)
	var ax := Vector2.RIGHT.rotated(rot)
	var nv := ax.orthogonal()
	if nv.y > 0:
		nv = -nv
	var rc := -nv * 3.0
	var damaged: bool = info.get("stage", 0) >= 1
	for k in 11:
		var f := -27.0 + k * 5.4
		for side in [-1.0, 1.0]:
			var p: Vector2 = rc + ax * f + nv * 4.6 * side
			if damaged and k % 3 == 1:
				continue
			ci.draw_circle(p, 0.75, Color(1.0, 0.92, 0.6, 0.8))
	if not damaged:
		var seq := int(fmod(t * 6.0 + ph, 6.0))
		var p0: Vector2 = rc - ax * (31.0 + seq * 2.2)
		glow(ci, p0, Color(1, 1, 1), 0.8, 0.9)
	var tw := rc + nv * 9.0
	var tower_p := tw + nv * 10.0 + ax * 16.0
	ci.draw_circle(tower_p + Vector2(0, -16), 2.0, Color(0.4, 0.95, 1.0, 0.4 + 0.2 * sin(t * 2.0)))
	if blink(t, 1.8, 0.1, ph):
		glow(ci, tower_p + Vector2(0, -17.5), RED_LIGHT, 0.8)
	var apron := tw + nv * 2.0 - ax * 4.0
	Icons.aircraft(ci, "interceptor", apron, rot + PI, 0.48, t, false, 1.0)


static func _harbor_basis(info: Dictionary) -> Array:
	var facing: int = info.get("facing", -1)
	var u := dir_vec(facing if facing >= 0 else 0)
	return [u, u.orthogonal()]


static func _harbor(ci: CanvasItem, info: Dictionary) -> void:
	var b := _harbor_basis(info)
	var u: Vector2 = b[0]
	var v: Vector2 = b[1]
	var rot := u.angle()
	pad(ci, 24.0, CONCRETE_DARK, GRAVEL_EDGE)
	# Quay along the water edge, finger piers and a docked patrol ship over the water.
	var quay := _footprint(u * 15.0, 9.0, 40.0, rot)
	ci.draw_colored_polygon(quay, CONCRETE)
	ci.draw_line(quay[1], quay[2], Color(0.85, 0.75, 0.3, 0.7), 1.2)
	for s in [-1.0, 1.0]:
		var pier := _footprint(u * 29.0 + v * 12.0 * s, 22.0, 4.0, rot)
		ci.draw_colored_polygon(pier, CONCRETE.lightened(0.05))
		ci.draw_polyline(PackedVector2Array([pier[0], pier[1], pier[2], pier[3], pier[0]]), Color(0, 0, 0, 0.35), 0.8, true)
		for k in 3:
			ci.draw_circle(u * (21.0 + k * 7.0) + v * 12.0 * s + v * 2.2 * s, 0.8, Color(0.85, 0.82, 0.6))
	var hull_c := u * 31.0
	var hull := PackedVector2Array([hull_c - u * 10.0 - v * 2.8, hull_c + u * 7.0 - v * 2.8, hull_c + u * 11.0, hull_c + u * 7.0 + v * 2.8, hull_c - u * 10.0 + v * 2.8])
	var sh := PackedVector2Array()
	for p in hull:
		sh.append(p + Vector2(1.5, 1.2))
	ci.draw_colored_polygon(sh, Color(0, 0, 0, 0.35))
	ci.draw_colored_polygon(hull, Color(0.55, 0.6, 0.64))
	ci.draw_polyline(PackedVector2Array([hull[0], hull[1], hull[2], hull[3], hull[4], hull[0]]), Color(0.1, 0.13, 0.15), 0.9, true)
	box(ci, hull_c - u * 2.0, 6.0, 3.6, 3.0, rot, WHITE, WALL, false)
	ci.draw_line(hull_c - u * 7.0, hull_c - u * 3.5, Defs.PLAYER_COLOR, 2.0)
	# Container stacks on the quay.
	var cols := [Color(0.55, 0.2, 0.18), Color(0.2, 0.35, 0.55), Color(0.65, 0.45, 0.15), Color(0.25, 0.45, 0.3)]
	var r := _rng(int(info.get("seed", 0)))
	for k in 4:
		var cp: Vector2 = u * 13.0 + v * (-15.0 + k * 5.5)
		box(ci, cp, 5.0, 3.0, 2.2 + 2.2 * r.randi_range(0, 1), rot, cols[k % 4].lightened(0.1), cols[k % 4], false)
	# Warehouses inland.
	for k in 2:
		var wp: Vector2 = -u * (2.0 + k * 10.0) + v * (3.0 if k == 0 else -4.0)
		var walls := box(ci, wp, 7.0, 22.0, 6.0, rot, ROOF, WALL)
		for w in walls:
			for j in 3:
				var f := (j + 0.5) / 3.0
				var bot: Vector2 = (w[0] as Vector2).lerp(w[1], f)
				ci.draw_colored_polygon(PackedVector2Array([bot - (w[1] - w[0]).normalized() * 1.6, bot + (w[1] - w[0]).normalized() * 1.6, bot + (w[1] - w[0]).normalized() * 1.6 + Vector2(0, -3.5), bot - (w[1] - w[0]).normalized() * 1.6 + Vector2(0, -3.5)]), Color(0.16, 0.18, 0.2))
	# Container gantry crane on the quay, boom over the water.
	var cb := u * 16.0 + v * 15.0
	for s in [-1.0, 1.0]:
		ci.draw_line(cb + v * 2.5 * s, cb + v * 2.5 * s + Vector2(0, -15), Color(0.85, 0.6, 0.2), 1.6, true)
	ci.draw_line(cb + v * 2.5 + Vector2(0, -15), cb - v * 2.5 + Vector2(0, -15), Color(0.85, 0.6, 0.2), 1.6, true)
	ci.draw_line(cb - u * 8.0 + Vector2(0, -15), cb + u * 18.0 + Vector2(0, -15), Color(0.9, 0.65, 0.25), 1.8, true)


static func _harbor_live(ci: CanvasItem, info: Dictionary, t: float, ph: float) -> void:
	var b := _harbor_basis(info)
	var u: Vector2 = b[0]
	var v: Vector2 = b[1]
	var cb := u * 16.0 + v * 15.0
	var trolley := cb + u * (2.0 + 12.0 * (0.5 + 0.5 * sin(t * 0.5 + ph))) + Vector2(0, -15)
	ci.draw_rect(Rect2(trolley - Vector2(1.5, 1.2), Vector2(3, 2.4)), Color(0.95, 0.85, 0.4))
	ci.draw_line(trolley, trolley + Vector2(0, 6 + 3 * sin(t * 0.8)), Color(0.8, 0.8, 0.8, 0.7), 0.7)
	if blink(t, 2.0, 0.5, ph):
		glow(ci, u * 40.0 + v * 12.0, GREEN_LIGHT, 0.9)
	if blink(t, 2.0, 0.5, ph + 1.0):
		glow(ci, u * 40.0 - v * 12.0, RED_LIGHT, 0.9)
	if blink(t, 1.5, 0.15, ph):
		glow(ci, cb + u * 18.0 + Vector2(0, -15.5), RED_LIGHT, 0.8)


static func _coastal_battery(ci: CanvasItem, info: Dictionary) -> void:
	pad(ci, 24.0, GRAVEL, GRAVEL_EDGE)
	perimeter(ci, 24.0 + 2.5, Defs.PLAYER_COLOR)
	var facing: int = info.get("facing", -1)
	var u := dir_vec(facing if facing >= 0 else 0)
	var v := u.orthogonal()
	for s in [-1.0, 1.0]:
		var p: Vector2 = u * 6.0 + v * 9.0 * s
		var berm := PackedVector2Array()
		for k in 9:
			var a: float = u.angle() - PI * 0.5 + PI * k / 8.0
			berm.append(p + Vector2(cos(a), sin(a)) * 9.0)
		ci.draw_polyline(berm, EARTH.lightened(0.1), 3.2, true)
	camo_net(ci, -u * 10.0 - v * 6.0, 8.0, int(info.get("seed", 0)) + 3)
	box(ci, -u * 10.0 - v * 6.0, 9.0, 5.0, 4.5, 0.0, OLIVE, OLIVE_DARK)
	truck(ci, -u * 11.0 + v * 9.0, u.angle() + PI * 0.5, 11.0, OLIVE)
	ci.draw_line(-u * 11.0 + v * 9.0 + Vector2(0, -3), -u * 11.0 + v * 9.0 + Vector2(0, -20), STEEL_DARK, 1.2)


static func _battery_live(ci: CanvasItem, info: Dictionary, t: float, ph: float) -> void:
	var facing: int = info.get("facing", -1)
	var u := dir_vec(facing if facing >= 0 else 0)
	var v := u.orthogonal()
	for s in [-1.0, 1.0]:
		_launcher(ci, u * 5.0 + v * 9.0 * s, u.angle(), OLIVE.lightened(0.04), 4, 7.0)
	var mast := -u * 11.0 + v * 9.0 + Vector2(0, -20)
	var w := 6.0 * absf(cos(t * 1.4 + ph))
	ci.draw_line(mast + Vector2(-w, 0), mast + Vector2(w, 0), STEEL, 2.4, true)
	if blink(t, 2.0, 0.1, ph):
		glow(ci, mast + Vector2(0, -2), RED_LIGHT, 0.8)


# --------------------------------------------------------------------------------------------
# Support sites
# --------------------------------------------------------------------------------------------

static func _lab(ci: CanvasItem, info: Dictionary) -> void:
	pad(ci, 24.0, Color(0.16, 0.2, 0.17), Color(0.3, 0.36, 0.3, 0.5))
	var lot := _footprint(Vector2(-2, 15), 22.0, 6.0, 0.0)
	ci.draw_colored_polygon(lot, ASPHALT)
	var r := _rng(int(info.get("seed", 0)) + 5)
	for k in 5:
		ci.draw_line(Vector2(-12 + k * 5, 12.5), Vector2(-12 + k * 5, 17.5), Color(0.8, 0.8, 0.8, 0.35), 0.6)
		if r.randf() < 0.7:
			ci.draw_rect(Rect2(Vector2(-11 + k * 5, 13.5), Vector2(3, 2.6)), [Color(0.6, 0.15, 0.15), Color(0.7, 0.7, 0.72), Color(0.15, 0.3, 0.55)][k % 3])
	for p in [Vector2(-19, 6), Vector2(17, 12), Vector2(-17, -12)]:
		ci.draw_circle(p + Vector2(1.5, 1.5), 4.0, Color(0, 0, 0, 0.3))
		ci.draw_circle(p, 4.0, Color(0.14, 0.3, 0.16))
		ci.draw_circle(p - Vector2(1, 1), 2.2, Color(0.2, 0.4, 0.22))
	var walls := box(ci, Vector2(-3, 0), 24.0, 12.0, 9.0, 0.0, ROOF.lightened(0.05), Color(0.2, 0.42, 0.48))
	windows(ci, walls, 3, 7, Color(0.75, 0.95, 1.0), 77, 0.75)
	for k in 3:
		box(ci, Vector2(-11 + k * 6, -9), 3.5, 3.0, 1.8, 0.0, STEEL_DARK, STEEL_DARK.darkened(0.3), false)
	var panels := _footprint(Vector2(4, -6.5), 8.0, 4.0, 0.0)
	var raised := PackedVector2Array()
	for p in panels:
		raised.append(p + Vector2(0, -9))
	ci.draw_colored_polygon(raised, Color(0.12, 0.2, 0.38))
	cylinder(ci, Vector2(14, 3), 5.0, 11.0, Color(0.22, 0.48, 0.55), Color(0.5, 0.8, 0.85))
	ci.draw_line(Vector2(14, -8), Vector2(14, -16), STEEL, 1.0)


static func _lab_live(ci: CanvasItem, t: float, ph: float) -> void:
	var dish_c := Vector2(-12, -13.5)
	var a := -0.6 + sin(t * 0.25 + ph) * 0.3
	var pts := PackedVector2Array()
	for k in 9:
		var u := PI * k / 8.0
		pts.append(dish_c + Vector2(cos(u) * 4.5, sin(u) * 2.0).rotated(a))
	ci.draw_colored_polygon(pts, WHITE)
	ci.draw_line(dish_c, dish_c + Vector2(0, 4), STEEL_DARK, 1.0)
	if blink(t, 1.4, 0.2, ph):
		glow(ci, Vector2(14, -16.5), RED_LIGHT, 0.8)


static func _bunker(ci: CanvasItem, info: Dictionary) -> void:
	var mound := PackedVector2Array()
	for k in 24:
		var a := TAU * k / 24.0
		mound.append(Vector2(cos(a) * 23.0, sin(a) * 13.0 - 2.0))
	shadow_poly(ci, mound, 6.0, 0.25)
	ci.draw_colored_polygon(mound, Color(0.19, 0.29, 0.17))
	var crest := PackedVector2Array()
	for k in 13:
		var a := PI + PI * k / 12.0
		crest.append(Vector2(cos(a) * 18.0, sin(a) * 8.0 - 5.0))
	ci.draw_colored_polygon(crest, Color(0.24, 0.36, 0.21))
	for k in 3:
		var x := -12.0 + k * 12.0
		var base := Vector2(x, 9.0 - absf(x) * 0.12)
		var frame := PackedVector2Array([base + Vector2(-5, 0), base + Vector2(5, 0), base + Vector2(5, -6), base + Vector2(-5, -6)])
		ci.draw_colored_polygon(frame, CONCRETE)
		var door := PackedVector2Array()
		for j in 9:
			var a := PI + PI * j / 8.0
			door.append(base + Vector2(cos(a) * 3.2, sin(a) * 4.2))
		ci.draw_colored_polygon(door, Color(0.03, 0.03, 0.04))
		ci.draw_line(base + Vector2(-5, -6), base + Vector2(5, -6), Color(0.55, 0.57, 0.6), 1.0)
	for p in [Vector2(-8, -10), Vector2(7, -11)]:
		cylinder(ci, p, 1.6, 4.0, CONCRETE, CONCRETE.lightened(0.15), false)
	box(ci, Vector2(19, 12), 5.0, 4.0, 3.0, 0.0, Color(0.55, 0.45, 0.25), Color(0.4, 0.32, 0.18))
	box(ci, Vector2(22, 7), 4.0, 3.0, 2.5, 0.0, Color(0.55, 0.45, 0.25), Color(0.4, 0.32, 0.18))
	ci.draw_line(Vector2(-21, 10), Vector2(-21, -6), STEEL_DARK, 1.2)
	for k in 3:
		var a := -PI * 0.5 + (k - 1) * 0.9
		ci.draw_line(Vector2(-21, -6), Vector2(-21, -6) + Vector2(cos(a), sin(a)) * 3.0, STEEL, 1.6)


static func _bunker_live(ci: CanvasItem, t: float, ph: float) -> void:
	for k in 3:
		var x := -12.0 + k * 12.0
		var p := Vector2(x, 9.0 - absf(x) * 0.12) + Vector2(0, -7.5)
		ci.draw_circle(p, 0.8, Color(0.4, 1.0, 0.55, 0.6 + 0.3 * sin(t * 2.0 + k + ph)))
	tiny_text(ci, Vector2(0, 19.5), "SHELTER", 6, Color(0.45, 1.0, 0.6, 0.85))


static func _decoy(ci: CanvasItem, info: Dictionary) -> void:
	pad(ci, 24.0, Color(0.24, 0.24, 0.22), Color(0.45, 0.42, 0.35, 0.6))
	var fake_layout := _sam_layout(info)
	for p in fake_layout["launchers"]:
		for k in 3:
			var a := TAU * k / 3.0 + 0.4
			ci.draw_line(p, p + Vector2(cos(a), sin(a)) * 9.0, Color(0.85, 0.85, 0.8, 0.35), 0.6)
			ci.draw_circle(p + Vector2(cos(a), sin(a)) * 9.0, 0.8, Color(0.6, 0.5, 0.3))
	var dash := Hex.corners(Vector2.ZERO, 25.0)
	for k in 6:
		var a: Vector2 = dash[k]
		var b: Vector2 = dash[(k + 1) % 6]
		for j in 5:
			ci.draw_line(a.lerp(b, j / 5.0), a.lerp(b, (j + 0.5) / 5.0), Color(Defs.GOLD, 0.55), 1.2)
	box(ci, Vector2(14, 12), 5.0, 4.0, 3.0, 0.0, Color(0.5, 0.5, 0.48), Color(0.35, 0.35, 0.33))


static func _decoy_live(ci: CanvasItem, t: float, ph: float) -> void:
	var breathe := 1.0 + 0.04 * sin(t * 1.7 + ph)
	var L := _sam_layout({"facing": 0})
	for p in L["launchers"]:
		var body := PackedVector2Array()
		for k in 12:
			var a := TAU * k / 12.0
			body.append(p + Vector2(cos(a) * 7.0, sin(a) * 3.2 - 3.0) * breathe)
		ci.draw_colored_polygon(body, Color(0.5, 0.56, 0.38, 0.9))
		var tube := PackedVector2Array()
		for k in 12:
			var a := TAU * k / 12.0
			tube.append(p + Vector2(3, -9) + Vector2(cos(a) * 5.5, sin(a) * 2.2).rotated(-0.5) * breathe)
		ci.draw_colored_polygon(tube, Color(0.58, 0.64, 0.45, 0.9))
	var fan := Vector2(14, 9)
	var a0 := t * 9.0
	for k in 3:
		ci.draw_line(fan, fan + Vector2.RIGHT.rotated(a0 + k * TAU / 3.0) * 2.4, Color(0.9, 0.9, 0.9, 0.8), 0.8)
	tiny_text(ci, Vector2(0, 22), "DECOY", 7, Color(Defs.GOLD, 0.85))


# --------------------------------------------------------------------------------------------
# Strategic infrastructure (placed by the map generator)
# --------------------------------------------------------------------------------------------

static func _power(ci: CanvasItem, info: Dictionary) -> void:
	var facing: int = info.get("facing", -1)
	var u := dir_vec(facing if facing >= 0 else 0)
	var v := u.orthogonal()
	pad(ci, 26.0, CONCRETE_DARK, GRAVEL_EDGE)
	perimeter(ci, 26.0 + 2.5, AMBER, 16)
	# LNG import jetty with a moored carrier, storage domes on the shore.
	var jetty := _footprint(u * 30.0, 22.0, 3.0, u.angle())
	ci.draw_colored_polygon(jetty, CONCRETE)
	var tank_c := u * 36.0 + v * 8.0
	var hull := PackedVector2Array([tank_c - v * 13.0 - u * 3.5, tank_c + v * 11.0 - u * 3.5, tank_c + v * 14.0, tank_c + v * 11.0 + u * 3.5, tank_c - v * 13.0 + u * 3.5])
	ci.draw_colored_polygon(hull, Color(0.45, 0.2, 0.2))
	for k in 4:
		sphere(ci, tank_c - v * (9.0 - k * 6.0) + Vector2(0, -2.5), 2.7, WHITE)
	for s in [-1.0, 1.0]:
		var p: Vector2 = u * 12.0 + v * 12.0 * s
		cylinder(ci, p, 6.5, 6.0, WHITE.darkened(0.12), WHITE)
		ci.draw_arc(p + Vector2(0, -6), 6.5, PI, TAU, 12, Color(1, 1, 1, 0.5), 1.0, true)
	# Switchyard and turbine hall.
	for gx in 3:
		for gy in 2:
			var p := -u * 15.0 + v * (-8.0 + gx * 6.0) + u * (gy * 5.0)
			box(ci, p, 3.0, 3.0, 3.0, 0.0, STEEL_DARK, STEEL_DARK.darkened(0.3), false)
	var hall := box(ci, -u * 3.0 - v * 2.0, 22.0, 11.0, 10.0, u.angle() + PI * 0.5, ROOF, WALL)
	windows(ci, hall, 2, 6, WINDOW, 31, 0.5)


static func _power_live(ci: CanvasItem, info: Dictionary, t: float, ph: float) -> void:
	var facing: int = info.get("facing", -1)
	var u := dir_vec(facing if facing >= 0 else 0)
	var v := u.orthogonal()
	var stage: int = info.get("stage", 0)
	for s in [-1.0, 1.0]:
		var base: Vector2 = -u * 9.0 + v * 7.0 * s + Vector2(0, -2)
		cylinder(ci, base, 2.4, 26.0, WHITE.darkened(0.1), STEEL_DARK, false)
		for k in 2:
			var y := -26.0 + k * 5.0
			ci.draw_rect(Rect2(base + Vector2(-2.4, y), Vector2(4.8, 2.4)), Color(0.75, 0.2, 0.2))
		if blink(t, 1.5, 0.3, ph + s):
			glow(ci, base + Vector2(0, -27.5), RED_LIGHT, 0.9)
		if stage == 0:
			for k in 5:
				var f := fmod(t * 0.22 + k / 5.0 + s * 0.3, 1.0)
				var p := base + Vector2(f * 16.0 + sin(f * 4.0 + k) * 2.0, -28.0 - f * 22.0)
				ci.draw_circle(p, 1.8 + f * 5.0, Color(0.75, 0.78, 0.82, (1.0 - f) * 0.3))


static func _cable(ci: CanvasItem, info: Dictionary) -> void:
	var facing: int = info.get("facing", -1)
	var u := dir_vec(facing if facing >= 0 else 0)
	var v := u.orthogonal()
	pad(ci, 22.0, Color(0.22, 0.22, 0.21), GRAVEL_EDGE)
	perimeter(ci, 22.0 + 2.5, AMBER, 16)
	for s in [-1.0, 1.0]:
		var a: Vector2 = v * 3.0 * s - u * 2.0
		var b: Vector2 = u * 24.0 + v * 5.0 * s
		ci.draw_line(a, b, Color(0.05, 0.05, 0.06), 2.0, true)
		for k in 4:
			var f := 1.0 + k * 0.35
			ci.draw_line(a.lerp(b, f), a.lerp(b, f + 0.15), Color(0.1, 0.25, 0.3, 0.8), 1.6)
		ci.draw_circle(u * 36.0 + v * 7.0 * s, 1.3, AMBER)
	var fence := _footprint(-u * 6.0, 18.0, 16.0, u.angle())
	var fl := PackedVector2Array(fence)
	fl.append(fence[0])
	for k in 4:
		var a2: Vector2 = fl[k]
		var b2: Vector2 = fl[k + 1]
		for j in 6:
			ci.draw_line(a2.lerp(b2, j / 6.0), a2.lerp(b2, (j + 0.5) / 6.0), Color(0.6, 0.65, 0.68, 0.5), 0.9)
	var walls := box(ci, -u * 7.0, 12.0, 8.0, 5.0, u.angle(), CONCRETE, WALL)
	windows(ci, walls, 1, 3, Color(0.5, 0.9, 1.0), 5, 0.5)
	lattice(ci, -u * 7.0 + v * 13.0 + Vector2(0, 4), 22.0, 3.5, 1.2, STEEL_DARK.lightened(0.2))
	for k in 2:
		var dp := -u * 7.0 + v * 13.0 + Vector2(2.5 - k * 5.0, -12.0 - k * 5.0)
		ci.draw_circle(dp, 2.4, WHITE.darkened(0.1))
		ci.draw_circle(dp, 1.2, STEEL_DARK)


static func _cable_live(ci: CanvasItem, t: float, ph: float) -> void:
	if blink(t, 1.3, 0.15, ph):
		glow(ci, Vector2(0, -24), RED_LIGHT, 0.8)


# --------------------------------------------------------------------------------------------
# Capital, cities, the Foundry
# --------------------------------------------------------------------------------------------

static func _street_pad(ci: CanvasItem, r: float, seed_value: int) -> void:
	pad(ci, r, Color(0.2, 0.21, 0.25), Color(0.36, 0.38, 0.42, 0.6))
	var rr := _rng(seed_value)
	for k in 3:
		var y := -12.0 + k * 11.0 + rr.randf_range(-2, 2)
		ci.draw_line(Vector2(-r * 0.78, y), Vector2(r * 0.78, y), Color(0.3, 0.31, 0.35), 3.0)
		for j in 5:
			ci.draw_circle(Vector2(-r * 0.7 + j * r * 0.35, y - 2.0), 0.7, Color(1.0, 0.85, 0.55, 0.7))
	for k in 3:
		var x := -13.0 + k * 13.0 + rr.randf_range(-2, 2)
		ci.draw_line(Vector2(x, -r * 0.75), Vector2(x, r * 0.75), Color(0.3, 0.31, 0.35), 3.0)


static func _tower_block(ci: CanvasItem, c: Vector2, w: float, d: float, h: float, seed_value: int, tint: Color) -> void:
	var t2 := tint.lightened(0.12)
	var walls := box(ci, c, w, d, h, 0.0, t2.lightened(0.18), t2)
	var glass := seed_value % 3 == 0
	windows(ci, walls, maxi(2, int(h / 2.6)), 4, Color(0.6, 0.95, 1.0) if glass else WINDOW, seed_value, 0.68)


static func _capital(ci: CanvasItem, info: Dictionary) -> void:
	_street_pad(ci, 29.0, 41)
	# Skyline behind the government quarter.
	_tower_block(ci, Vector2(-15, -15), 8.0, 7.0, 22.0, 3, Color(0.36, 0.42, 0.5))
	_tower_block(ci, Vector2(5, -18), 7.0, 6.0, 15.0, 4, Color(0.42, 0.44, 0.48))
	_tower_block(ci, Vector2(17, -12), 6.0, 6.0, 11.0, 5, Color(0.38, 0.4, 0.46))
	# The Assembly of Tiles: colonnade and the gold dome.
	var hall := box(ci, Vector2(-6, 1), 22.0, 11.0, 7.0, 0.0, STONE.lightened(0.15), Color(0.72, 0.72, 0.7))
	for w in hall:
		for k in 7:
			var f := (k + 0.5) / 7.0
			ci.draw_line((w[0] as Vector2).lerp(w[1], f), (w[3] as Vector2).lerp(w[2], f), Color(0.45, 0.45, 0.45), 1.0)
	var dome := PackedVector2Array()
	for k in 15:
		var a := PI + PI * k / 14.0
		dome.append(Vector2(-6, -6.5) + Vector2(cos(a) * 7.0, sin(a) * 7.5))
	ci.draw_colored_polygon(dome, Defs.GOLD.darkened(0.15))
	ci.draw_arc(Vector2(-6, -6.5), 6.0, PI * 1.15, PI * 1.55, 6, Color(1, 0.95, 0.75, 0.6), 1.2, true)
	ci.draw_line(Vector2(-6, -14), Vector2(-6, -20), WHITE, 1.0)
	ci.draw_colored_polygon(PackedVector2Array([Vector2(-6, -20), Vector2(-1.5, -18.8), Vector2(-6, -17.5)]), Defs.PLAYER_COLOR)
	# Air Defense Command: fortified, antenna farm on the roof, blast walls at the entrance.
	var hq := box(ci, Vector2(14, 9), 13.0, 9.0, 6.0, 0.0, CONCRETE, Color(0.42, 0.45, 0.48))
	windows(ci, hq, 1, 4, Color(0.5, 0.95, 1.0), 9, 0.6)
	for k in 5:
		box(ci, Vector2(8.5 + k * 2.8, 16.5), 2.0, 1.2, 2.4, 0.0, STONE, STONE.darkened(0.25), false)
	sphere(ci, Vector2(18, 1.5), 2.6, WHITE)
	for k in 3:
		ci.draw_line(Vector2(9 + k * 3.0, 4), Vector2(9 + k * 3.0, -6 - k * 2.0), STEEL, 0.8)
	# Lumen Tower: the comms needle that carries Air Defense Command's links, and the skyline.
	cylinder(ci, Vector2(-22, -2), 3.0, 2.5, CONCRETE, CONCRETE.lightened(0.1))
	ci.draw_line(Vector2(-22, -4), Vector2(-22, -40), Color(0.75, 0.78, 0.82), 2.4, true)
	ci.draw_line(Vector2(-21.2, -4), Vector2(-21.2, -40), Color(0.5, 0.53, 0.58), 0.8, true)
	var pod := PackedVector2Array()
	for k in 12:
		var a := TAU * k / 12.0
		pod.append(Vector2(-22, -33) + Vector2(cos(a) * 4.6, sin(a) * 2.6))
	ci.draw_colored_polygon(pod, Color(0.55, 0.6, 0.66))
	ci.draw_line(Vector2(-26.4, -33), Vector2(-17.6, -33), Color(0.6, 0.95, 1.0, 0.8), 1.0)
	ci.draw_line(Vector2(-22, -40), Vector2(-22, -50), STEEL, 1.0)
	# Helipad.
	ci.draw_circle(Vector2(-18, 13), 6.0, Color(0.2, 0.22, 0.25))
	ci.draw_arc(Vector2(-18, 13), 5.5, 0, TAU, 16, Color(0.9, 0.9, 0.85, 0.7), 0.8, true)
	tiny_text(ci, Vector2(-18, 15.5), "H", 7, Color(0.9, 0.9, 0.85, 0.85))


static func _capital_live(ci: CanvasItem, t: float, ph: float) -> void:
	if blink(t, 1.2, 0.5, ph):
		glow(ci, Vector2(-22, -50.5), RED_LIGHT, 1.0)
	ci.draw_line(Vector2(-26.4, -33), Vector2(-17.6, -33), Color(0.6, 1.0, 1.0, 0.35 + 0.25 * sin(t * 2.0)), 1.6)
	for p in [Vector2(-15, -38.5), Vector2(5, -34.5)]:
		if blink(t, 1.6, 0.4, ph + p.x * 0.1):
			glow(ci, p, RED_LIGHT, 0.9)
	ci.draw_circle(Vector2(14, 12.5), 1.0, Color(0.5, 1.0, 1.0, 0.6 + 0.3 * sin(t * 3.0)))
	for k in 3:
		if blink(t, 1.1, 0.3, ph + k * 0.4):
			ci.draw_circle(Vector2(9 + k * 3.0, -6 - k * 2.0), 0.9, RED_LIGHT)


static func city_style(name: String, facing: int) -> String:
	var h := absi(hash(name))
	var styles := ["towers", "oldtown", "port"] if facing >= 0 else ["towers", "oldtown"]
	return styles[h % styles.size()]


static func _city(ci: CanvasItem, info: Dictionary) -> void:
	var seed_value: int = info.get("seed", 0)
	_street_pad(ci, 27.0, seed_value)
	var style: String = info.get("style", "towers")
	var r := _rng(seed_value)
	match style:
		"oldtown":
			temple(ci, Vector2(-8, -9))
			for k in 6:
				var p := Vector2(-16 + (k % 3) * 14.0 + r.randf_range(-2, 2), 4 + (k / 3) * 9.0)
				_shophouse(ci, p, r.randf_range(8, 11), r.randf_range(4, 7), seed_value + k)
			_tower_block(ci, Vector2(15, -10), 7.0, 6.0, 13.0, seed_value + 9, Color(0.4, 0.42, 0.47))
		"port":
			var u := dir_vec(int(info.get("facing", 0)))
			var v := u.orthogonal()
			var quay := _footprint(u * 17.0, 7.0, 34.0, u.angle())
			ci.draw_colored_polygon(quay, CONCRETE)
			for k in 2:
				var cb: Vector2 = u * 18.0 + v * (-8.0 + k * 14.0)
				for s in [-1.0, 1.0]:
					ci.draw_line(cb + v * 2.0 * s, cb + v * 2.0 * s + Vector2(0, -13), Color(0.85, 0.6, 0.2), 1.4, true)
				ci.draw_line(cb - u * 6.0 + Vector2(0, -13), cb + u * 14.0 + Vector2(0, -13), Color(0.9, 0.65, 0.25), 1.6, true)
			var cols := [Color(0.55, 0.2, 0.18), Color(0.2, 0.35, 0.55), Color(0.65, 0.45, 0.15)]
			for k in 5:
				var cp: Vector2 = u * 8.0 + v * (-13.0 + k * 6.0)
				box(ci, cp, 5.0, 3.0, 2.0 + 2.0 * (k % 2), u.angle(), cols[k % 3].lightened(0.1), cols[k % 3], false)
			for k in 4:
				var p := -u * 6.0 + v * (-12.0 + k * 8.0) + Vector2(r.randf_range(-2, 2), r.randf_range(-2, 2))
				_tower_block(ci, p, 6.0, 6.0, r.randf_range(7, 15), seed_value + k, Color(0.4, 0.43, 0.48))
		_:
			var heights := [r.randf_range(14, 22), r.randf_range(18, 28), r.randf_range(10, 16), r.randf_range(8, 13), r.randf_range(12, 18)]
			var spots := [Vector2(-13, -10), Vector2(3, -13), Vector2(15, -4), Vector2(-14, 7), Vector2(4, 6)]
			for k in 5:
				var tint: Color = [Color(0.36, 0.42, 0.5), Color(0.42, 0.44, 0.48), Color(0.3, 0.38, 0.44)][k % 3]
				_tower_block(ci, spots[k], 7.0 + r.randf_range(-1, 1), 6.0, heights[k], seed_value + k, tint)
			ci.draw_line(Vector2(-26, 16), Vector2(26, 13), Color(0.35, 0.38, 0.42), 2.6)
			ci.draw_line(Vector2(-26, 15), Vector2(26, 12), Color(0.55, 0.6, 0.64, 0.6), 0.8)


static func _shophouse(ci: CanvasItem, p: Vector2, w: float, h: float, seed_value: int) -> void:
	var walls := box(ci, p, w, 6.0, h, 0.0, TILE_ROOF, Color(0.62, 0.58, 0.5))
	windows(ci, walls, 1, 2, WINDOW, seed_value, 0.75)
	var top := p + Vector2(0, -h)
	ci.draw_colored_polygon(PackedVector2Array([top + Vector2(-w * 0.55, 3.2), top + Vector2(w * 0.55, 3.2), top + Vector2(w * 0.4, -2.0), top + Vector2(-w * 0.4, -2.0)]), TILE_ROOF.lightened(0.08))
	ci.draw_line(top + Vector2(-w * 0.4, -2.0), top + Vector2(w * 0.4, -2.0), TILE_ROOF.lightened(0.3), 0.8)


static func temple(ci: CanvasItem, p: Vector2) -> void:
	box(ci, p + Vector2(0, 2), 16.0, 10.0, 2.0, 0.0, STONE, STONE.darkened(0.25))
	box(ci, p, 12.0, 7.0, 5.0, 0.0, Color(0.55, 0.15, 0.12), Color(0.6, 0.16, 0.13))
	for tier in 2:
		var y := -5.0 - tier * 4.5
		var hw := 10.0 - tier * 3.0
		var roof := PackedVector2Array([p + Vector2(-hw - 2.0, y - 1.8), p + Vector2(-hw, y + 0.5), p + Vector2(hw, y + 0.5), p + Vector2(hw + 2.0, y - 1.8),
			p + Vector2(hw - 2.0, y - 3.4), p + Vector2(-hw + 2.0, y - 3.4)])
		ci.draw_colored_polygon(roof, Color(0.2, 0.32, 0.28))
		ci.draw_line(p + Vector2(-hw + 2.0, y - 3.4), p + Vector2(hw - 2.0, y - 3.4), Color(0.85, 0.7, 0.3), 1.0)


static func _city_live(ci: CanvasItem, info: Dictionary, t: float, ph: float) -> void:
	var style: String = info.get("style", "towers")
	if style == "towers":
		if blink(t, 1.7, 0.4, ph):
			glow(ci, Vector2(3, -42), RED_LIGHT, 0.9)
		ci.draw_rect(Rect2(Vector2(-0.5, -37), Vector2(7, 1.6)), Color(NEON_PINK, 0.7 + 0.3 * sin(t * 2.3 + ph)))
	elif style == "oldtown":
		for k in 6:
			var p := Vector2(-18 + k * 7.0, 0.5 + sin(k * 1.3) * 1.0)
			ci.draw_circle(p, 1.1, Color(1.0, 0.35, 0.25, 0.75 + 0.2 * sin(t * 2.0 + k)))
		ci.draw_line(Vector2(-18, 0.5), Vector2(17, 0.5), Color(0.2, 0.1, 0.1, 0.6), 0.6)
	else:
		var u := dir_vec(int(info.get("facing", 0)))
		if blink(t, 1.6, 0.2, ph):
			glow(ci, u * 32.0 + Vector2(0, -13), RED_LIGHT, 0.8)


static func _foundry(ci: CanvasItem, info: Dictionary) -> void:
	_street_pad(ci, 28.0, 99)
	# Substation and bulk-gas yard.
	for gx in 3:
		box(ci, Vector2(-21 + gx * 4.0, 13), 2.6, 2.6, 2.6, 0.0, STEEL_DARK, STEEL_DARK.darkened(0.3), false)
	for k in 3:
		cylinder(ci, Vector2(16 + (k % 2) * 4.0, -2 + k * 3.0), 2.2, 12.0, WHITE.darkened(0.12), WHITE)
	# Two fab buildings with cleanroom roofs packed with air handlers.
	for k in 2:
		var p := Vector2(-6, -9 + k * 13.0)
		var walls := box(ci, p, 26.0, 9.0, 6.0, 0.0, Color(0.78, 0.8, 0.82), Color(0.55, 0.58, 0.62))
		windows(ci, walls, 1, 5, Color(0.55, 0.85, 1.0), 40 + k, 0.5)
		for j in 6:
			box(ci, p + Vector2(-10.5 + j * 4.2, -1.5), 2.4, 2.4, 1.4, 0.0, STEEL_DARK, STEEL_DARK.darkened(0.3), false)
	# TLW headquarters tower.
	_tower_block(ci, Vector2(14, -14), 7.0, 6.0, 20.0, 12, Color(0.32, 0.4, 0.5))
	cylinder(ci, Vector2(-20, -4), 5.0, 6.0, CONCRETE.lightened(0.1), Color(0.3, 0.33, 0.36))


static func _foundry_live(ci: CanvasItem, t: float, ph: float) -> void:
	for k in 4:
		var f := fmod(t * 0.2 + k / 4.0, 1.0)
		var p := Vector2(-20, -10) + Vector2(f * 10.0 + sin(f * 6.0) * 1.5, -f * 18.0)
		ci.draw_circle(p, 2.0 + f * 4.5, Color(0.85, 0.88, 0.92, (1.0 - f) * 0.35))
	ci.draw_rect(Rect2(Vector2(10.5, -35.5), Vector2(7, 1.6)), Color(NEON_PINK, 0.65 + 0.35 * sin(t * 2.0 + ph)))
	if blink(t, 1.4, 0.4, ph):
		glow(ci, Vector2(14, -37.5), RED_LIGHT, 0.9)
