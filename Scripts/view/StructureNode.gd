class_name StructureNode
extends Node2D
## A player structure (including the Capital and Cities) on the map.

var id := -1
var kind := ""
var label := ""
var hp := 1
var max_hp := 1
var targeted := false
var _t := 0.0
var _animated := false


func setup(s: Dictionary) -> void:
	id = s["id"]
	kind = s["kind"]
	label = s.get("name", "")
	hp = s["hp"]
	max_hp = s["max_hp"]
	_animated = kind == "radar" or kind == "laser"
	_t = randf() * 10.0
	set_process(true)


func appear() -> void:
	scale = Vector2(0.2, 0.2)
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func set_hp(p_hp: int, p_max: int) -> void:
	if p_hp == hp and p_max == max_hp:
		return
	hp = p_hp
	max_hp = p_max
	queue_redraw()


func flash() -> void:
	modulate = Color(2.2, 0.8, 0.7)
	create_tween().tween_property(self, "modulate", Color.WHITE, 0.35)


func _process(delta: float) -> void:
	_t += delta
	if _animated or targeted:
		queue_redraw()


func _draw() -> void:
	var s := 1.0
	Icons.structure(self, kind, Vector2.ZERO, s, _t)
	var bar_y := -22.0 if kind == "capital" else -19.0
	if hp < max_hp or kind == "capital":
		EntityNodes.hp_bar(self, Vector2(0, bar_y), 30.0 if kind != "capital" else 38.0, float(hp) / max_hp)
	if kind == "capital" or kind == "city":
		var col := Defs.GOLD if kind == "capital" else Color(0.92, 0.95, 0.98)
		EntityNodes.outlined_text(self, Vector2(0, 32), label, 13 if kind == "capital" else 12, col)
	if targeted:
		var pulse := 0.5 + 0.5 * sin(_t * 5.0)
		var r := 21.0 + pulse * 2.0
		var col := Color(Defs.ENEMY_COLOR, 0.55 + 0.35 * pulse)
		for k in 4:
			var a := k * PI * 0.5 + PI * 0.25
			draw_arc(Vector2.ZERO, r, a - 0.35, a + 0.35, 6, col, 2.0, true)
