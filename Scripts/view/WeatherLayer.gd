class_name WeatherLayer
extends Node2D
## Weather over the battlefield: rain streaks, storm darkness and lightning, drifting fog banks,
## dusty haze or grey overcast. Drawn above the action at low opacity so it never hides it.
## Only redraws while there is weather to show.

var weather := "clear":
	set(v):
		weather = v
		queue_redraw()
var t := 0.0
var _flash := 0.0
var _next_flash := 4.0


func _process(delta: float) -> void:
	if weather == "clear":
		return
	t += delta
	if weather == "storm":
		_next_flash -= delta
		if _next_flash <= 0.0:
			_flash = 1.0
			_next_flash = randf_range(3.5, 9.0)
	_flash = maxf(0.0, _flash - delta * 3.0)
	queue_redraw()


func _visible_rect() -> Rect2:
	var inv := get_canvas_transform().affine_inverse()
	var size := get_viewport_rect().size
	var a := inv * Vector2.ZERO
	var b := inv * size
	return Rect2(a, b - a)


func _draw() -> void:
	if weather == "clear":
		return
	var vr := _visible_rect()
	var zoom := maxf(0.3, get_canvas_transform().get_scale().x)
	match weather:
		"rain", "storm":
			draw_rect(vr, Color(0.02, 0.04, 0.08, 0.16 if weather == "storm" else 0.08))
			var n := 220 if weather == "storm" else 140
			var slant := Vector2(-4.0, 13.0) / zoom
			for i in n:
				var hx := fposmod(sin(i * 12.9898) * 43758.5453, 1.0)
				var hy := fposmod(sin(i * 78.233) * 12345.678, 1.0)
				var x := vr.position.x + fposmod(hx * vr.size.x - t * 60.0 / zoom, vr.size.x)
				var y := vr.position.y + fposmod(hy * vr.size.y + t * 420.0 / zoom, vr.size.y)
				var p := Vector2(x, y)
				draw_line(p, p + slant, Color(0.7, 0.85, 1.0, 0.22), 1.0 / zoom)
		"fog":
			draw_rect(vr, Color(0.55, 0.62, 0.7, 0.07))
			for i in 9:
				var hx := fposmod(sin(i * 3.17) * 9137.0, 1.0)
				var hy := fposmod(sin(i * 7.41) * 3517.0, 1.0)
				var c := vr.position + Vector2(fposmod(hx * vr.size.x + t * 6.0, vr.size.x), hy * vr.size.y)
				for j in 3:
					draw_circle(c + Vector2(j * 60.0, sin(i + j) * 20.0) / zoom, (120.0 - j * 25.0) / zoom, Color(0.7, 0.76, 0.82, 0.045))
		"haze":
			draw_rect(vr, Color(0.75, 0.62, 0.4, 0.06))
		"overcast":
			draw_rect(vr, Color(0.25, 0.28, 0.32, 0.08))
	if _flash > 0.0:
		draw_rect(vr, Color(0.8, 0.88, 1.0, _flash * 0.3))
