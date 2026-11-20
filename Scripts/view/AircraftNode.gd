class_name AircraftNode
extends Node2D
## An enemy aircraft with shadow, contrail and smooth movement.

var id := -1
var kind := ""
var heading := PI
var hp := 1
var max_hp := 1
var high := true
var hovered := false
var _t := 0.0
var _trail: Array = []
var _dying := false
var _shown := true
var _fade_tween: Tween


func setup(e: Dictionary) -> void:
	id = e["id"]
	kind = e["kind"]
	hp = e["hp"]
	max_hp = e["max_hp"]
	high = Defs.ENEMIES[kind]["alt"] == "high"
	heading = PI
	_t = randf() * 10.0


static func jitter(p_id: int) -> Vector2:
	var a := p_id * 2.39996
	return Vector2(cos(a), sin(a)) * (6.0 + float(p_id % 3) * 3.0)


func set_shown(v: bool, fade: float = 0.25) -> void:
	if v == _shown:
		return
	_shown = v
	if _fade_tween:
		_fade_tween.kill()
	_fade_tween = create_tween()
	_fade_tween.tween_property(self, "modulate:a", 1.0 if v else 0.0, fade)
	if v:
		visible = true
	else:
		_fade_tween.tween_callback(func(): visible = false)


func is_shown() -> bool:
	return _shown


func force_shown(v: bool) -> void:
	if _fade_tween:
		_fade_tween.kill()
	_shown = v
	visible = v
	modulate.a = 1.0 if v else 0.0


func fly_to(target: Vector2, dur: float) -> void:
	if target.distance_to(position) > 0.5:
		var want := (target - position).angle()
		var tw0 := create_tween()
		tw0.tween_method(func(a): heading = a, heading, heading + wrapf(want - heading, -PI, PI), minf(dur * 0.4, 0.2))
	var tw := create_tween()
	tw.tween_property(self, "position", target, dur).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func flash() -> void:
	modulate = Color(2.5, 2.0, 1.5, modulate.a)
	create_tween().tween_property(self, "modulate", Color(1, 1, 1, modulate.a), 0.25)


func die() -> void:
	_dying = true
	var tw := create_tween().set_parallel(true)
	tw.tween_property(self, "rotation", rotation + (5.0 if id % 2 == 0 else -5.0), 1.0)
	tw.tween_property(self, "scale", Vector2(0.25, 0.25), 1.0).set_ease(Tween.EASE_IN)
	tw.tween_property(self, "position", position + Vector2(10, 40), 1.0).set_ease(Tween.EASE_IN)
	tw.tween_property(self, "modulate:a", 0.0, 1.0).set_ease(Tween.EASE_IN)
	tw.chain().tween_callback(queue_free)


func depart() -> void:
	_dying = true
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.4)
	tw.tween_callback(queue_free)


func _process(delta: float) -> void:
	_t += delta
	if high and visible:
		_trail.append(position)
		if _trail.size() > 18:
			_trail.pop_front()
	queue_redraw()


func _draw() -> void:
	var s := 1.0
	var bob := Vector2(0, sin(_t * 2.6 + id) * 1.6)
	if high and _trail.size() > 2:
		for i in range(1, _trail.size()):
			var a: Vector2 = _trail[i - 1] - position
			var b: Vector2 = _trail[i] - position
			var k := float(i) / _trail.size()
			draw_line(a, b, Color(1, 1, 1, 0.12 * k), 3.0 * k, true)
	var shadow_off := Vector2(10, 16) if high else Vector2(5, 8)
	if not _dying:
		Icons.shadow(self, kind, shadow_off, heading, s)
	if kind == "stealth":
		draw_circle(bob, 15.0, Color(Defs.ENEMY_COLOR, 0.08 + 0.05 * sin(_t * 3.0)))
	Icons.aircraft(self, kind, bob, heading, s, _t, true)
	_draw_nav_lights(bob)
	if hovered:
		draw_arc(Vector2.ZERO, 17.0, 0, TAU, 24, Color(Defs.ENEMY_COLOR, 0.9), 1.5, true)
	if hp < max_hp and not _dying:
		EntityNodes.hp_bar(self, Vector2(0, -18), 24.0, float(hp) / max_hp, Defs.ENEMY_COLOR.lerp(Color.WHITE, 0.2))


const _WINGSPAN := {"bomber": 15.0, "fighter": 9.0, "drone": 8.0, "stealth": 14.0, "gunship": 0.0, "missile": 0.0,
	"decoy": 8.0, "kitefang": 0.0, "jammer": 9.5, "aew": 13.0}


func _draw_nav_lights(bob: Vector2) -> void:
	var span: float = _WINGSPAN.get(kind, 0.0)
	if span <= 0.0 or _dying:
		return
	var blink := 0.6 + 0.4 * sin(_t * 4.0 + id)
	var left := bob + Vector2(-4.0, -span).rotated(heading)
	var right := bob + Vector2(-4.0, span).rotated(heading)
	if kind != "stealth":
		draw_circle(left, 3.2, Color(1.0, 0.15, 0.2, 0.18 * blink))
		draw_circle(left, 1.4, Color(1.0, 0.3, 0.3, blink))
		draw_circle(right, 3.2, Color(0.2, 1.0, 0.4, 0.18 * blink))
		draw_circle(right, 1.4, Color(0.4, 1.0, 0.5, blink))
	if fmod(_t + id * 0.37, 1.3) < 0.07:
		draw_circle(bob, 5.0, Color(1, 1, 1, 0.35))
		draw_circle(bob, 2.0, Color(1, 1, 1, 0.9))
