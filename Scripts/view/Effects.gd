class_name Effects
extends Node2D
## Lightweight immediate-mode particle/projectile system for battle animations.

var speed := 1.0
var _parts: Array = []
var _shots: Array = []
var _beams: Array = []
var _texts: Array = []
var _rings: Array = []
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()


func clear_all() -> void:
	_parts.clear()
	_shots.clear()
	_beams.clear()
	_texts.clear()
	_rings.clear()
	queue_redraw()


func busy() -> bool:
	return not (_shots.is_empty() and _beams.is_empty())


# --------------------------------------------------------------------------------------------
# Spawners
# --------------------------------------------------------------------------------------------

func _part(p: Vector2, v: Vector2, life: float, size: float, col: Color, grow: float = 0.0, drag: float = 2.0, kind: int = 0) -> void:
	_parts.append({"p": p, "v": v, "life": life, "max": life, "size": size, "col": col, "grow": grow, "drag": drag, "kind": kind})


func explosion(p: Vector2, size: float = 1.0) -> void:
	_rings.append({"p": p, "r0": 4.0 * size, "r1": 34.0 * size, "life": 0.45, "max": 0.45, "col": Color(1.0, 0.85, 0.5, 0.8)})
	# Light flash that briefly lights up the surroundings.
	_part(p, Vector2.ZERO, 0.24, 52.0 * size, Color(1.0, 0.78, 0.45, 0.32), 60.0, 0.0, 4)
	_part(p, Vector2.ZERO, 0.18, 22.0 * size, Color(1.0, 0.95, 0.75, 0.95), 30.0, 0.0)
	for i in int(3 * size):
		var a := _rng.randf() * TAU
		_part(p + Vector2.RIGHT.rotated(a) * 6.0 * size, Vector2.RIGHT.rotated(a) * 30.0, _rng.randf_range(0.35, 0.55), _rng.randf_range(7, 11) * size, Color(1.0, _rng.randf_range(0.35, 0.55), 0.1, 0.85), 10.0, 2.0)
	for i in int(6 * size):
		var a := _rng.randf_range(-PI, 0)
		_part(p, Vector2.RIGHT.rotated(a) * _rng.randf_range(60.0, 170.0) * size, _rng.randf_range(0.55, 0.95), _rng.randf_range(1.6, 3.0), Color(0.12, 0.1, 0.09), 0.0, 0.3, 3)
	for i in int(14 * size):
		var a := _rng.randf() * TAU
		var sp := _rng.randf_range(60.0, 190.0) * size
		_part(p, Vector2.RIGHT.rotated(a) * sp, _rng.randf_range(0.25, 0.6), _rng.randf_range(1.5, 3.2), Color(1.0, _rng.randf_range(0.45, 0.85), 0.2), -2.0, 3.5, 1)
	for i in int(7 * size):
		var a := _rng.randf() * TAU
		var g := _rng.randf_range(0.18, 0.32)
		_part(p + Vector2.RIGHT.rotated(a) * _rng.randf_range(0, 10) * size, Vector2.RIGHT.rotated(a) * 25.0 + Vector2(0, -18), _rng.randf_range(0.9, 1.6), _rng.randf_range(6, 11) * size, Color(g, g, g, 0.55), 14.0, 1.2)
	for i in int(5 * size):
		var a := _rng.randf_range(-PI, 0)
		_part(p, Vector2.RIGHT.rotated(a) * _rng.randf_range(50, 120), _rng.randf_range(0.6, 0.9), 2.2, Color(0.15, 0.12, 0.1), 0.0, 0.5, 2)


## Destruction of an installation: double shockwave, big flash and a smoke column that lingers.
func demolition(p: Vector2, size: float = 1.0) -> void:
	explosion(p, 1.6 * size)
	_rings.append({"p": p, "r0": 10.0, "r1": 90.0 * size, "life": 0.7, "max": 0.7, "col": Color(1.0, 0.9, 0.7, 0.7)})
	_rings.append({"p": p, "r0": 6.0, "r1": 60.0 * size, "life": 0.5, "max": 0.5, "col": Color(1.0, 0.6, 0.3, 0.8)})
	for i in 14:
		var g := _rng.randf_range(0.12, 0.22)
		_part(p + Vector2(_rng.randf_range(-12, 12), _rng.randf_range(-6, 6)), Vector2(_rng.randf_range(-6, 10), _rng.randf_range(-26, -14)),
			_rng.randf_range(3.0, 5.5), _rng.randf_range(6, 10), Color(g, g, g * 1.05, 0.5), 7.0, 0.25)


func airburst(p: Vector2) -> void:
	var off := Vector2(_rng.randf_range(-10, 10), _rng.randf_range(-10, 10))
	_part(p + off, Vector2.ZERO, 0.12, 9.0, Color(1.0, 0.8, 0.4, 0.9), 20.0, 0.0)
	_part(p + off, Vector2(0, -6), _rng.randf_range(0.8, 1.3), 7.0, Color(0.12, 0.12, 0.13, 0.7), 9.0, 1.0)


func splash(p: Vector2) -> void:
	for i in 8:
		var a := _rng.randf_range(-PI * 0.9, -PI * 0.1)
		_part(p, Vector2.RIGHT.rotated(a) * _rng.randf_range(30, 80), 0.6, 2.0, Color(0.85, 0.95, 1.0, 0.85), 0.0, 0.5, 2)
	_rings.append({"p": p, "r0": 3.0, "r1": 16.0, "life": 0.5, "max": 0.5, "col": Color(0.85, 0.95, 1.0, 0.6)})


func dust(p: Vector2) -> void:
	_rings.append({"p": p, "r0": 8.0, "r1": 30.0, "life": 0.5, "max": 0.5, "col": Color(Defs.PLAYER_COLOR, 0.8)})
	for i in 10:
		var a := TAU * i / 10.0
		_part(p + Vector2.RIGHT.rotated(a) * 8.0, Vector2.RIGHT.rotated(a) * 40.0, 0.7, 5.0, Color(0.75, 0.7, 0.6, 0.5), 8.0, 2.5)


func sparkle(p: Vector2, col: Color) -> void:
	for i in 12:
		var a := TAU * i / 12.0
		_part(p, Vector2.RIGHT.rotated(a) * 70.0, 0.6, 2.2, col, -2.0, 2.0, 1)
	_rings.append({"p": p, "r0": 6.0, "r1": 26.0, "life": 0.5, "max": 0.5, "col": col})


func ring(p: Vector2, r0: float, r1: float, dur: float, col: Color) -> void:
	_rings.append({"p": p, "r0": r0, "r1": r1, "life": dur, "max": dur, "col": col})


func float_text(p: Vector2, text: String, col: Color, size: int = 16) -> void:
	_texts.append({"p": p + Vector2(_rng.randf_range(-6, 6), -14), "text": text, "col": col, "life": 1.2, "max": 1.2, "size": size})


## Generic projectile. kind: tracer | missile | bomb | rocket | flak
func projectile(kind: String, a: Vector2, b: Vector2, dur: float, col: Color, on_hit: Callable = Callable(), arc: float = 0.0) -> void:
	_shots.append({"kind": kind, "a": a, "b": b, "t": 0.0, "dur": maxf(dur, 0.01), "col": col, "on_hit": on_hit, "arc": arc, "trail": 0.0})


func beam(a: Vector2, b: Vector2, col: Color, dur: float = 0.25) -> void:
	_beams.append({"a": a, "b": b, "col": col, "life": dur, "max": dur})


# --------------------------------------------------------------------------------------------

func _process(delta: float) -> void:
	var d := delta * speed
	if _parts.is_empty() and _shots.is_empty() and _beams.is_empty() and _texts.is_empty() and _rings.is_empty():
		return
	for i in range(_parts.size() - 1, -1, -1):
		var q: Dictionary = _parts[i]
		q["life"] -= d
		if q["life"] <= 0.0:
			_parts.remove_at(i)
			continue
		q["p"] += q["v"] * d
		q["v"] *= maxf(0.0, 1.0 - q["drag"] * d)
		if q["kind"] == 2 or q["kind"] == 3:
			q["v"] += Vector2(0, 160) * d
		q["size"] = maxf(0.3, q["size"] + q["grow"] * d)
	var hits: Array = []
	for i in range(_shots.size() - 1, -1, -1):
		var s: Dictionary = _shots[i]
		s["t"] += d
		var k: float = s["t"] / s["dur"]
		var pos := _shot_pos(s, minf(k, 1.0))
		if s["kind"] == "missile" or s["kind"] == "rocket":
			s["trail"] += d
			if s["trail"] > 0.025:
				s["trail"] = 0.0
				_part(pos, Vector2(_rng.randf_range(-6, 6), _rng.randf_range(-6, 6)), 0.6, 2.5, Color(0.85, 0.85, 0.85, 0.45), 6.0, 1.0)
		if k >= 1.0:
			_shots.remove_at(i)
			hits.append(s["on_hit"])
	for i in range(_beams.size() - 1, -1, -1):
		_beams[i]["life"] -= d
		if _beams[i]["life"] <= 0.0:
			_beams.remove_at(i)
	for i in range(_texts.size() - 1, -1, -1):
		var tx: Dictionary = _texts[i]
		tx["life"] -= d
		tx["p"] += Vector2(0, -28) * d
		if tx["life"] <= 0.0:
			_texts.remove_at(i)
	for i in range(_rings.size() - 1, -1, -1):
		_rings[i]["life"] -= d
		if _rings[i]["life"] <= 0.0:
			_rings.remove_at(i)
	for cb in hits:
		if cb is Callable and cb.is_valid():
			cb.call()
	queue_redraw()


func _shot_pos(s: Dictionary, k: float) -> Vector2:
	var a: Vector2 = s["a"]
	var b: Vector2 = s["b"]
	var p := a.lerp(b, k)
	if s["arc"] != 0.0:
		p.y -= sin(k * PI) * s["arc"]
	return p


func _draw() -> void:
	for r in _rings:
		var k: float = 1.0 - r["life"] / r["max"]
		var col: Color = r["col"]
		draw_arc(r["p"], lerpf(r["r0"], r["r1"], k), 0, TAU, 32, Color(col, col.a * (1.0 - k)), 2.5 * (1.0 - k) + 0.5, true)
	for q in _parts:
		var k: float = q["life"] / q["max"]
		var col: Color = q["col"]
		col.a *= clampf(k * 1.5, 0.0, 1.0)
		match q["kind"]:
			1:
				draw_line(q["p"], q["p"] - q["v"] * 0.03, col, q["size"], true)
			3:
				var ang: float = q["life"] * 14.0
				var hs: float = q["size"]
				var c0: Vector2 = q["p"]
				draw_colored_polygon(PackedVector2Array([c0 + Vector2(-hs, -hs * 0.6).rotated(ang), c0 + Vector2(hs, -hs * 0.6).rotated(ang),
					c0 + Vector2(hs, hs * 0.6).rotated(ang), c0 + Vector2(-hs, hs * 0.6).rotated(ang)]), col)
			4:
				draw_circle(q["p"], q["size"], Color(col, col.a * 0.5))
				draw_circle(q["p"], q["size"] * 0.55, col)
			_:
				draw_circle(q["p"], q["size"], col)
	for s in _shots:
		var k: float = minf(s["t"] / s["dur"], 1.0)
		var pos := _shot_pos(s, k)
		var col: Color = s["col"]
		match s["kind"]:
			"tracer", "flak":
				var tail := _shot_pos(s, maxf(k - 0.22, 0.0))
				draw_line(tail, pos, col, 2.0, true)
				draw_circle(pos, 1.6, Color(1, 1, 0.85))
			"missile", "rocket":
				var tail := _shot_pos(s, maxf(k - 0.06, 0.0))
				draw_line(tail, pos, Color(0.95, 0.95, 0.95), 2.4, true)
				draw_circle(pos, 2.6, Color(1.0, 0.75, 0.3))
				draw_circle(pos, 5.0, Color(1.0, 0.6, 0.2, 0.25))
			"ballistic":
				var tail := _shot_pos(s, maxf(k - 0.18, 0.0))
				draw_line(tail, pos, Color(1.0, 0.75, 0.4, 0.35), 5.0, true)
				draw_line(tail.lerp(pos, 0.5), pos, Color(1.0, 0.95, 0.8, 0.9), 2.0, true)
				draw_circle(pos, 6.0, Color(1.0, 0.6, 0.25, 0.3))
				draw_circle(pos, 2.6, Color(1.0, 1.0, 0.9))
			"boat":
				var dir2 := (s["b"] - s["a"]).normalized() as Vector2
				draw_line(pos - dir2 * 14.0, pos, Color(0.85, 0.95, 1.0, 0.7), 2.0, true)
				draw_circle(pos, 2.2, Color(0.3, 0.35, 0.4))
			"bomb":
				for j in 3:
					var kk := clampf(k - j * 0.1, 0.0, 1.0)
					var bp := _shot_pos(s, kk) + Vector2((j - 1) * 5.0, 0)
					draw_circle(bp, 2.4 * (1.0 - kk * 0.4), Color(0.1, 0.1, 0.1))
			"jet":
				var dir := (s["b"] - s["a"]).normalized() as Vector2
				var ang := dir.angle()
				for j in 3:
					var off := Vector2(-8.0 * j, (j - 1) * 9.0).rotated(ang)
					Icons.aircraft(self, "interceptor", pos + off, ang, 0.8, 0.0, false)
	for b in _beams:
		var k: float = b["life"] / b["max"]
		var col: Color = b["col"]
		draw_line(b["a"], b["b"], Color(col, 0.35 * k), 9.0 * k, true)
		draw_line(b["a"], b["b"], Color(1, 1, 1, 0.9 * k), 2.0, true)
	for tx in _texts:
		var k: float = tx["life"] / tx["max"]
		var col: Color = tx["col"]
		col.a = clampf(k * 2.0, 0.0, 1.0)
		EntityNodes.outlined_text(self, tx["p"], tx["text"], tx["size"], col, UITheme.font_bold)
