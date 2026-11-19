class_name AmbientLayer
extends Node2D
## The living world around the battle: merchant shipping on the sea lanes, ferries between the
## islands, fishing fleets and coast guard cutters (their mix follows the escalation: shipping
## thins out under a blockade while cutters and "fishing" fleets multiply), offshore wind
## turbines, the lighthouse beam, beacon lights and drifting cloud shadows.
## Purely visual; drawn under the fog of war so unexplored waters stay hidden.

var env := {}
var tiles := {}
var t := 0.0
var escalation := 1
var weather := "clear"
var _lanes: Array = []        # [PackedVector2Array points, PackedFloat32Array cumulative lengths]
var _ferries: Array = []      # [Vector2 a, Vector2 b]
var _ships: Array = []
var _bounds := Rect2()
var _rng := RandomNumberGenerator.new()


func setup(p_env: Dictionary, p_tiles: Dictionary) -> void:
	env = p_env
	tiles = p_tiles
	_rng.seed = hash(str(env.get("theater", {}))) + 11
	_lanes.clear()
	for lane in env.get("lanes", []):
		var pts := PackedVector2Array()
		for h in lane:
			pts.append(Hex.to_pixel(h))
		var cum := PackedFloat32Array([0.0])
		for i in range(1, pts.size()):
			cum.append(cum[i - 1] + pts[i - 1].distance_to(pts[i]))
		_lanes.append([pts, cum])
	_ferries.clear()
	for f in env.get("ferries", []):
		var a := _water_near(f[0])
		var b := _water_near(f[1])
		if a != Vector2.INF and b != Vector2.INF:
			_ferries.append([a, b])
	if not tiles.is_empty():
		_bounds = MapView.map_rect(tiles.keys())
	_spawn_ships()


func set_state(p_escalation: int, p_weather: String) -> void:
	weather = p_weather
	if p_escalation != escalation:
		escalation = p_escalation
		_spawn_ships()


func _water_near(h: Vector2i) -> Vector2:
	for nb in Hex.neighbors(h):
		if tiles.has(nb) and Defs.TERRAIN[tiles[nb]]["water"]:
			return Hex.to_pixel(h).lerp(Hex.to_pixel(nb), 0.75)
	return Vector2.INF


func _spawn_ships() -> void:
	_ships.clear()
	var merchants: int = [5, 3, 1, 0, 0][clampi(escalation, 0, 4)]
	var fishing: int = [3, 5, 6, 3, 2][clampi(escalation, 0, 4)]
	var cutters: int = [1, 3, 4, 3, 2][clampi(escalation, 0, 4)]
	if _lanes.is_empty():
		return
	for i in merchants:
		var li := i % _lanes.size()
		var cum: PackedFloat32Array = _lanes[li][1]
		_ships.append({"type": "tanker" if i % 3 == 1 else "container", "lane": li, "s": _rng.randf() * cum[cum.size() - 1],
			"speed": _rng.randf_range(7.0, 11.0), "dir": 1.0 if i % 2 == 0 else -1.0})
	for i in cutters:
		var li := 0
		var cum: PackedFloat32Array = _lanes[li][1]
		_ships.append({"type": "cutter", "lane": li, "s": _rng.randf() * cum[cum.size() - 1],
			"speed": _rng.randf_range(5.0, 8.0), "dir": 1.0 if i % 2 == 0 else -1.0, "offset": _rng.randf_range(-30, 30)})
	var east: PackedVector2Array = _lanes[0][0]
	for i in fishing:
		var anchor: Vector2 = east[_rng.randi_range(0, east.size() - 1)] + Vector2(_rng.randf_range(-40, 40), _rng.randf_range(-30, 30))
		_ships.append({"type": "fishing", "center": anchor, "phase": _rng.randf() * TAU, "r": _rng.randf_range(6, 16)})
	for i in _ferries.size():
		_ships.append({"type": "ferry", "ferry": i, "phase": _rng.randf()})


func _lane_pos(li: int, s: float, offset: float = 0.0) -> Array:
	var pts: PackedVector2Array = _lanes[li][0]
	var cum: PackedFloat32Array = _lanes[li][1]
	var total: float = cum[cum.size() - 1]
	s = fposmod(s, maxf(total, 1.0))
	var i := 1
	while i < cum.size() - 1 and cum[i] < s:
		i += 1
	var seg := maxf(cum[i] - cum[i - 1], 0.001)
	var f := (s - cum[i - 1]) / seg
	var a: Vector2 = pts[i - 1]
	var b: Vector2 = pts[i]
	var dir := (b - a).normalized()
	return [a.lerp(b, f) + dir.orthogonal() * offset, dir]


func _process(delta: float) -> void:
	t += delta
	for sh in _ships:
		if sh.has("lane"):
			sh["s"] += sh["speed"] * sh["dir"] * delta
	queue_redraw()


func _draw() -> void:
	_draw_cloud_shadows()
	for sh in _ships:
		match sh["type"]:
			"fishing":
				var p: Vector2 = sh["center"] + Vector2(cos(t * 0.05 + sh["phase"]), sin(t * 0.04 + sh["phase"])) * sh["r"]
				_boat(p, sh["phase"] + t * 0.05, "fishing")
			"ferry":
				var fr: Array = _ferries[sh["ferry"]]
				var k := 0.5 - 0.5 * cos(t * 0.06 + sh["phase"] * TAU)
				var dirv: Vector2 = (fr[1] - fr[0]).normalized()
				var going := sin(t * 0.06 + sh["phase"] * TAU) >= 0.0
				_boat((fr[0] as Vector2).lerp(fr[1], k), (dirv if going else -dirv).angle(), "ferry")
			_:
				var lp := _lane_pos(sh["lane"], sh["s"], sh.get("offset", 0.0))
				var dir: Vector2 = lp[1] * sh["dir"]
				_boat(lp[0], dir.angle(), sh["type"])
	_draw_windfarm()
	_draw_lighthouse()
	for h in env.get("masts", []):
		var top: Vector2 = MapView.top_center(tiles, h) + Vector2(10, 2) - Vector2(0, 18)
		if Installations.blink(t, 1.6, 0.35, float(h.x)):
			Installations.glow(self, top, Installations.RED_LIGHT, 0.9)


func _boat(p: Vector2, rot: float, kind: String) -> void:
	var len := 8.0
	var wid := 2.6
	var hull := Color(0.3, 0.32, 0.36)
	match kind:
		"container":
			len = 26.0
			wid = 5.5
			hull = Color(0.35, 0.16, 0.16)
		"tanker":
			len = 28.0
			wid = 6.0
			hull = Color(0.2, 0.24, 0.3)
		"cutter":
			len = 15.0
			wid = 3.6
			hull = Color(0.85, 0.87, 0.9)
		"ferry":
			len = 14.0
			wid = 4.2
			hull = Color(0.86, 0.88, 0.9)
	var ax := Vector2.RIGHT.rotated(rot)
	var nv := ax.orthogonal()
	# Wake.
	for k in 3:
		var b := p - ax * (len * 0.5 + k * 6.0)
		draw_line(b + nv * (wid * 0.4 + k * 2.0), b - ax * 5.0 + nv * (wid * 0.6 + k * 3.0), Color(0.8, 0.95, 1.0, 0.18 - k * 0.05), 1.0, true)
		draw_line(b - nv * (wid * 0.4 + k * 2.0), b - ax * 5.0 - nv * (wid * 0.6 + k * 3.0), Color(0.8, 0.95, 1.0, 0.18 - k * 0.05), 1.0, true)
	var pts := PackedVector2Array([p - ax * len * 0.5 - nv * wid * 0.5, p + ax * len * 0.32 - nv * wid * 0.5, p + ax * len * 0.5,
		p + ax * len * 0.32 + nv * wid * 0.5, p - ax * len * 0.5 + nv * wid * 0.5])
	var sh := PackedVector2Array()
	for q in pts:
		sh.append(q + Vector2(1.5, 1.5))
	draw_colored_polygon(sh, Color(0, 0, 0, 0.3))
	draw_colored_polygon(pts, hull)
	match kind:
		"container":
			var cols := [Color(0.55, 0.25, 0.2), Color(0.2, 0.35, 0.55), Color(0.6, 0.5, 0.2), Color(0.25, 0.45, 0.35)]
			for k in 5:
				var c := p + ax * (-6.0 + k * 3.6)
				draw_colored_polygon(Icons.xform(PackedVector2Array([Vector2(-1.5, -2), Vector2(1.5, -2), Vector2(1.5, 2), Vector2(-1.5, 2)]), c, rot, 1.0), cols[k % 4])
			draw_colored_polygon(Icons.xform(PackedVector2Array([Vector2(-2, -2.2), Vector2(2, -2.2), Vector2(2, 2.2), Vector2(-2, 2.2)]), p - ax * 10.0, rot, 1.0), Color(0.88, 0.9, 0.92))
		"tanker":
			draw_line(p - ax * 8.0, p + ax * 10.0, Color(0.6, 0.55, 0.45), 1.0)
			draw_colored_polygon(Icons.xform(PackedVector2Array([Vector2(-2, -2.4), Vector2(2, -2.4), Vector2(2, 2.4), Vector2(-2, 2.4)]), p - ax * 11.0, rot, 1.0), Color(0.88, 0.9, 0.92))
		"cutter":
			draw_line(p - ax * 1.0 - nv * 1.9, p + ax * 3.0 + nv * 1.9, Defs.ENEMY_COLOR, 1.4)
			draw_colored_polygon(Icons.xform(PackedVector2Array([Vector2(-2, -1.4), Vector2(2, -1.4), Vector2(2, 1.4), Vector2(-2, 1.4)]), p - ax * 2.0, rot, 1.0), Color(0.7, 0.72, 0.76))
			if Installations.blink(t, 0.8, 0.5, p.x * 0.01):
				draw_circle(p - ax * 2.0, 1.2, Color(1.0, 0.3, 0.3, 0.9))
		"fishing":
			var on := 0.75 + 0.25 * sin(t * 1.3 + p.x)
			draw_circle(p, 5.0, Color(0.9, 1.0, 0.85, 0.08 * on))
			draw_circle(p + nv * 1.5, 0.9, Color(0.95, 1.0, 0.9, on))
			draw_circle(p - nv * 1.5, 0.9, Color(0.95, 1.0, 0.9, on))
		"ferry":
			for k in 4:
				draw_circle(p + ax * (-4.5 + k * 3.0), 0.6, Color(1.0, 0.85, 0.5, 0.9))
	# Running lights.
	draw_circle(p + ax * len * 0.45, 0.7, Color(1, 1, 1, 0.85))
	draw_circle(p - nv * wid * 0.45, 0.6, Color(1.0, 0.3, 0.3, 0.8))
	draw_circle(p + nv * wid * 0.45, 0.6, Color(0.3, 1.0, 0.4, 0.8))


func _draw_windfarm() -> void:
	var k := 0
	for h in env.get("windfarm", []):
		for p in MapView.turbine_spots(h):
			var hub: Vector2 = p + Vector2(0, -11)
			var a0 := t * 1.6 + k * 1.3
			for b in 3:
				var dir := Vector2.RIGHT.rotated(a0 + b * TAU / 3.0)
				draw_line(hub, hub + dir * 5.0, Color(0.78, 0.82, 0.86, 0.5), 0.8, true)
			draw_circle(hub, 0.8, Color(0.9, 0.92, 0.95, 0.7))
			if Installations.blink(t, 2.0, 0.25, k * 0.37):
				Installations.glow(self, hub + Vector2(0, -1), Installations.RED_LIGHT, 0.7, 0.8)
			k += 1


func _draw_lighthouse() -> void:
	var lh: Vector2i = env.get("lighthouse", Hex.INVALID)
	if lh == Hex.INVALID:
		return
	var lamp := MapView.lighthouse_point(tiles, lh) + Vector2(0, -19)
	for k in 2:
		var a := t * 0.8 + k * PI
		var dir := Vector2.RIGHT.rotated(a)
		var side := dir.orthogonal() * 10.0
		var tip := dir * 170.0
		draw_colored_polygon(PackedVector2Array([lamp, lamp + tip + side, lamp + tip - side]), Color(1.0, 0.95, 0.7, 0.05))
		draw_colored_polygon(PackedVector2Array([lamp, lamp + tip * 0.5 + side * 0.35, lamp + tip * 0.5 - side * 0.35]), Color(1.0, 0.95, 0.75, 0.06))
	Installations.glow(self, lamp, Color(1.0, 0.95, 0.7), 1.6, 1.0)


func _draw_cloud_shadows() -> void:
	if _bounds.size == Vector2.ZERO:
		return
	var n := 2
	var alpha := 0.06
	match weather:
		"overcast", "rain":
			n = 6
			alpha = 0.12
		"storm":
			n = 7
			alpha = 0.18
		"fog":
			n = 4
			alpha = 0.08
	for k in n:
		var span := _bounds.size + Vector2(600, 0)
		var x := _bounds.position.x - 300 + fposmod(k * 397.0 + t * (9.0 + k), span.x)
		var y := _bounds.position.y + fposmod(k * 233.0, _bounds.size.y)
		var c := Vector2(x, y)
		for j in 3:
			draw_circle(c + Vector2(j * 38.0 - 38.0, sin(k + j) * 14.0), 70.0 - j * 8.0, Color(0.0, 0.01, 0.03, alpha * 0.6))
