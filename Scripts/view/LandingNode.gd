class_name LandingNode
extends Node2D
## An enemy landing group: assault ship, two landing ships and an escort, steaming in formation.
## Shows a ghost at its last known position when out of sight.

var id := -1
var hp := 1
var max_hp := 1
var eta := 0
var label := ""
var ghost := false
var heading := PI
var _t := 0.0


func setup(lg: Dictionary) -> void:
	id = lg["id"]
	hp = lg["hp"]
	max_hp = lg["max_hp"]
	label = lg["name"]
	_t = randf() * 5.0


func move_to(target: Vector2, dur: float) -> void:
	if target.distance_to(position) > 0.5:
		heading = (target - position).angle()
	create_tween().tween_property(self, "position", target, dur).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func flash() -> void:
	modulate = Color(2.2, 1.6, 1.2)
	create_tween().tween_property(self, "modulate", Color.WHITE, 0.3)


func sink() -> void:
	var tw := create_tween().set_parallel(true)
	tw.tween_property(self, "modulate:a", 0.0, 1.6)
	tw.tween_property(self, "scale", Vector2(0.7, 0.7), 1.6)
	tw.chain().tween_callback(queue_free)


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _ship(c: Vector2, rot: float, length: float, width: float, hull: Color, deck: Color, flat: bool) -> void:
	var ax := Vector2.RIGHT.rotated(rot)
	var nv := ax.orthogonal()
	var pts := PackedVector2Array([c - ax * length * 0.5 - nv * width * 0.5, c + ax * length * 0.3 - nv * width * 0.5,
		c + ax * length * 0.5, c + ax * length * 0.3 + nv * width * 0.5, c - ax * length * 0.5 + nv * width * 0.5])
	var sh := PackedVector2Array()
	for p in pts:
		sh.append(p + Vector2(1.5, 1.5))
	draw_colored_polygon(sh, Color(0, 0, 0, 0.3))
	draw_colored_polygon(pts, hull)
	var d := PackedVector2Array([c - ax * length * 0.42 - nv * width * 0.34, c + ax * length * 0.3 - nv * width * 0.34,
		c + ax * length * 0.3 + nv * width * 0.34, c - ax * length * 0.42 + nv * width * 0.34])
	draw_colored_polygon(d, deck)
	if flat:
		for k in 3:
			var hp2 := c + ax * (-length * 0.25 + k * length * 0.22)
			draw_arc(hp2, width * 0.22, 0, TAU, 10, Color(0.9, 0.9, 0.85, 0.6), 0.8)
		draw_colored_polygon(Icons.xform(PackedVector2Array([Vector2(-2, -1.6), Vector2(3, -1.6), Vector2(3, 1.6), Vector2(-2, 1.6)]), c + nv * width * 0.38, rot, 1.0), Color(0.6, 0.62, 0.66))
	else:
		draw_line(c - ax * length * 0.1, c + ax * length * 0.15, Color(0.6, 0.62, 0.66), 2.0)
	draw_circle(c + ax * length * 0.45, 0.8, Color(1.0, 0.3, 0.3, 0.6 + 0.4 * sin(_t * 3.0)))


func _draw() -> void:
	var a := 0.4 if ghost else 1.0
	modulate.a = a if not ghost else 0.55
	var rot := heading
	var ax := Vector2.RIGHT.rotated(rot)
	var nv := ax.orthogonal()
	# Wakes.
	for off in [Vector2.ZERO, -nv * 13.0, nv * 13.0]:
		for k in 3:
			var b: Vector2 = off - ax * (14.0 + k * 7.0)
			draw_line(b + nv * (2.0 + k * 2.0), b - ax * 6.0 + nv * (3.0 + k * 3.0), Color(0.8, 0.95, 1.0, 0.16 - k * 0.04), 1.0, true)
			draw_line(b - nv * (2.0 + k * 2.0), b - ax * 6.0 - nv * (3.0 + k * 3.0), Color(0.8, 0.95, 1.0, 0.16 - k * 0.04), 1.0, true)
	var hull := Color(0.42, 0.44, 0.48)
	_ship(Vector2.ZERO, rot, 30.0, 8.0, hull, Color(0.3, 0.31, 0.34), true)
	_ship(-nv * 13.0 - ax * 6.0, rot, 18.0, 5.0, hull.darkened(0.1), Color(0.35, 0.33, 0.3), false)
	_ship(nv * 13.0 - ax * 6.0, rot, 18.0, 5.0, hull.darkened(0.1), Color(0.35, 0.33, 0.3), false)
	_ship(ax * 20.0 - nv * 4.0, rot, 15.0, 4.0, Color(0.5, 0.52, 0.56), Color(0.4, 0.42, 0.46), false)
	draw_arc(Vector2.ZERO, 26.0, 0, TAU, 32, Color(Defs.ENEMY_COLOR, 0.25 + 0.15 * sin(_t * 2.5)), 2.0, true)
	if not ghost:
		EntityNodes.hp_bar(self, Vector2(0, -22), 36.0, float(hp) / max_hp, Defs.ENEMY_COLOR.lerp(Color.WHITE, 0.2))
	var txt := "%s · ETA %d" % [label, eta] if not ghost else "%s (last seen)" % label
	EntityNodes.outlined_text(self, Vector2(0, 32), txt, 11, Color(1.0, 0.6, 0.6, 0.95))
