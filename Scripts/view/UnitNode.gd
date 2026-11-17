class_name UnitNode
extends Node2D
## A player interceptor squadron or AA frigate.

var id := -1
var kind := ""
var heading := PI
var hp := 1
var max_hp := 1
var spent := false
var _t := 0.0


func setup(u: Dictionary) -> void:
	id = u["id"]
	kind = u["kind"]
	heading = u.get("heading", PI)
	hp = u["hp"]
	max_hp = u["max_hp"]
	_t = randf() * 10.0


func update_from(u: Dictionary) -> void:
	heading = u.get("heading", heading)
	hp = u["hp"]
	max_hp = u["max_hp"]
	spent = u["moved"] and (u["attacked"] or kind == "frigate")


func move_to(target: Vector2, dur: float) -> void:
	if target.distance_to(position) > 1.0:
		heading = (target - position).angle()
	var tw := create_tween()
	tw.tween_property(self, "position", target, dur).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func lunge(target: Vector2, dur: float) -> void:
	var home := position
	heading = (target - position).angle() if target.distance_to(position) > 1.0 else heading
	var mid := position.lerp(target, 0.55)
	var tw := create_tween()
	tw.tween_property(self, "position", mid, dur * 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "position", home, dur * 0.55).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)


func flash() -> void:
	modulate = Color(2.2, 0.8, 0.7)
	create_tween().tween_property(self, "modulate", Color.WHITE, 0.3)


func die() -> void:
	var tw := create_tween().set_parallel(true)
	tw.tween_property(self, "rotation", rotation + 4.0, 0.9)
	tw.tween_property(self, "scale", Vector2(0.3, 0.3), 0.9)
	tw.tween_property(self, "modulate:a", 0.0, 0.9)
	tw.chain().tween_callback(queue_free)


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	var alpha := 0.55 if spent else 1.0
	if kind == "interceptor":
		var bob := Vector2(0, sin(_t * 2.2) * 1.5)
		Icons.shadow(self, kind, Vector2(7, 11), heading, 1.15, alpha)
		Icons.aircraft(self, kind, bob, heading, 1.15, _t, false, alpha)
	else:
		var sway := sin(_t * 1.3) * 0.04
		draw_arc(Vector2(-14, 0).rotated(heading), 6.0, heading + PI * 0.6, heading + PI * 1.4, 8, Color(1, 1, 1, 0.25), 1.5, true)
		Icons.frigate(self, Vector2.ZERO, heading + sway, 1.0, alpha)
	if hp < max_hp:
		EntityNodes.hp_bar(self, Vector2(0, -18), 26.0, float(hp) / max_hp, Defs.PLAYER_COLOR)
