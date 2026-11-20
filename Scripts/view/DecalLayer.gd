class_name DecalLayer
extends Node2D
## Persistent ground marks left by the fighting: scorch where installations burned, craters
## where bombs and missiles missed. Drawn once per change; oldest marks fade out past a cap.

const MAX_DECALS := 70

var _decals: Array = []


func clear() -> void:
	_decals.clear()
	queue_redraw()


func add_scorch(p: Vector2, radius: float = 14.0) -> void:
	_add({"kind": "scorch", "p": p, "r": radius, "seed": randi()})


func add_crater(p: Vector2, radius: float = 4.0) -> void:
	_add({"kind": "crater", "p": p, "r": radius, "seed": randi()})


func _add(d: Dictionary) -> void:
	_decals.append(d)
	while _decals.size() > MAX_DECALS:
		_decals.pop_front()
	queue_redraw()


## Recorded into one batched mesh (see CanvasBatcher); rebuilt only when it changes.
var _c: CanvasBatcher
var _mesh: ArrayMesh


func _draw() -> void:
	_c = CanvasBatcher.new()
	_paint()
	_mesh = _c.submit(self)
	_c = null


func _paint() -> void:
	var n := _decals.size()
	for i in n:
		var d: Dictionary = _decals[i]
		var age_fade := 0.55 + 0.45 * float(i + 1) / float(n)
		var rng := RandomNumberGenerator.new()
		rng.seed = d["seed"]
		var p: Vector2 = d["p"]
		var r: float = d["r"]
		match d["kind"]:
			"scorch":
				var pts := PackedVector2Array()
				for k in 12:
					var a := TAU * k / 12.0
					pts.append(p + Vector2(cos(a), sin(a) * 0.7) * r * rng.randf_range(0.65, 1.2))
				_c.draw_colored_polygon(pts, Color(0.03, 0.025, 0.02, 0.5 * age_fade))
				for k in 5:
					var q := p + Vector2(rng.randf_range(-r, r), rng.randf_range(-r, r) * 0.6) * 0.6
					_c.draw_circle(q, rng.randf_range(1.5, 3.0), Color(0.02, 0.02, 0.02, 0.55 * age_fade))
			"crater":
				_c.draw_circle(p + Vector2(0.8, 0.8), r + 1.6, Color(0.35, 0.3, 0.22, 0.45 * age_fade))
				_c.draw_circle(p, r, Color(0.04, 0.035, 0.03, 0.85 * age_fade))
				for k in 4:
					var a := rng.randf() * TAU
					_c.draw_line(p + Vector2(cos(a), sin(a)) * r, p + Vector2(cos(a), sin(a)) * (r + rng.randf_range(2.0, 5.0)), Color(0.05, 0.04, 0.03, 0.5 * age_fade), 1.0)
