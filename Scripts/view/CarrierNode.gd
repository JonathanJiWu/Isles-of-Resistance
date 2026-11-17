class_name CarrierNode
extends Node2D
## An enemy carrier, either in plain sight or as a "last seen" ghost.

var id := -1
var hp := 1
var max_hp := 1
var ghost := false
var seen_ago := 0
var _t := 0.0


func setup(c: Dictionary) -> void:
	id = c["id"]
	hp = c["hp"]
	max_hp = c["max_hp"]
	_t = randf() * 10.0


func move_to(target: Vector2, dur: float) -> void:
	var tw := create_tween()
	tw.tween_property(self, "position", target, dur).set_trans(Tween.TRANS_SINE)


func flash() -> void:
	modulate = Color(2.2, 1.0, 0.8, modulate.a)
	create_tween().tween_property(self, "modulate", Color(1, 1, 1, modulate.a), 0.4)


func sink() -> void:
	var tw := create_tween().set_parallel(true)
	tw.tween_property(self, "rotation", 0.5, 2.0)
	tw.tween_property(self, "scale", Vector2(0.7, 0.7), 2.0)
	tw.tween_property(self, "modulate:a", 0.0, 2.0)
	tw.chain().tween_callback(queue_free)


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	var rot := PI + sin(_t * 0.4) * 0.05
	var alpha := 0.35 if ghost else 1.0
	if not ghost:
		for k in 3:
			var off := Vector2(32 + k * 8, 0).rotated(rot + PI)
			draw_arc(-off, 6.0 + k * 3.0, rot + PI * 0.6, rot + PI * 1.4, 8, Color(1, 1, 1, 0.22 - k * 0.06), 1.5, true)
	Icons.carrier(self, Vector2.ZERO, rot, 1.25, alpha)
	if ghost:
		EntityNodes.outlined_text(self, Vector2(0, 5), "?", 18, Color(Defs.ENEMY_COLOR, 0.9), UITheme.font_bold)
		EntityNodes.outlined_text(self, Vector2(0, 26), "last seen %d turn%s ago" % [seen_ago, "" if seen_ago == 1 else "s"], 11, Color(1, 0.8, 0.8, 0.8))
	else:
		EntityNodes.hp_bar(self, Vector2(0, -22), 44.0, float(hp) / max_hp, Defs.ENEMY_COLOR)
