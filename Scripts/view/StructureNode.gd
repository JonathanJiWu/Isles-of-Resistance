class_name StructureNode
extends Node2D
## A player structure (including the Capital and Cities) on the map.

var id := -1
var kind := ""
var label := ""
var hp := 1
var max_hp := 1
var targeted := false
var foundry := false
var _t := 0.0
var _animated := false
var _signs: Array = []


func setup(s: Dictionary) -> void:
	id = s["id"]
	kind = s["kind"]
	label = s.get("name", "")
	hp = s["hp"]
	max_hp = s["max_hp"]
	foundry = s.get("foundry", false)
	_animated = kind in ["radar", "laser", "city", "capital"]
	_t = randf() * 10.0
	_signs.clear()
	if kind == "capital":
		_signs = [["LUMEN", Vector2(-32, -30), Lore.SIGN_COLORS[1]], ["ASSEMBLY", Vector2(36, -12), Lore.SIGN_COLORS[2]]]
	elif foundry:
		_signs = [["TLW · FAB 18", Vector2(-4, -32), Lore.SIGN_COLORS[2]], ["CLEANROOM", Vector2(32, -8), Lore.SIGN_COLORS[1]]]
	elif kind == "city":
		var h: int = absi(hash(label))
		for k in 2:
			var txt: String = Lore.SIGNS[(h + k * 7) % Lore.SIGNS.size()]
			var pos := Vector2(-26, -28) if k == 0 else Vector2(28, -9)
			_signs.append([txt, pos, Lore.SIGN_COLORS[(h / 3 + k) % Lore.SIGN_COLORS.size()]])
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
	if kind == "capital" or kind == "city":
		_draw_city_lights()
	Icons.structure(self, kind, Vector2.ZERO, s, _t)
	for sg in _signs:
		_draw_sign(sg[0], sg[1], sg[2])
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


func _draw_city_lights() -> void:
	var warm := Color(1.0, 0.45, 0.75) if foundry else Color(1.0, 0.6, 0.3)
	for r in [46.0, 34.0, 23.0]:
		draw_circle(Vector2(0, 4), r, Color(warm, 0.04))
	if kind == "capital" or foundry:
		for k in 2:
			var a := _t * (0.35 if kind == "capital" else -0.28) + k * PI + (0.6 if foundry else 0.0)
			var dir := Vector2.RIGHT.rotated(a)
			var side := dir.orthogonal() * 9.0
			var tip := dir * 150.0
			draw_colored_polygon(PackedVector2Array([Vector2.ZERO, tip + side, tip - side]), Color(0.7, 0.95, 1.0, 0.05))
			draw_colored_polygon(PackedVector2Array([Vector2.ZERO, tip * 0.6 + side * 0.4, tip * 0.6 - side * 0.4]), Color(0.8, 1.0, 1.0, 0.05))


func _draw_sign(text: String, pos: Vector2, col: Color) -> void:
	var font: Font = UITheme.font_bold
	var fs := 8
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var flick := 0.88 + 0.12 * sin(_t * 3.1 + pos.x)
	if sin(_t * 7.3 + pos.y * 3.0 + float(id)) > 0.985:
		flick = 0.25
	var c := Color(col, flick)
	var rect := Rect2(pos - Vector2(w * 0.5 + 4.0, 8.0), Vector2(w + 8.0, 11.0))
	draw_rect(rect.grow(2.0), Color(col, 0.12 * flick), false, 3.0)
	draw_rect(rect, Color(0.02, 0.02, 0.05, 0.78))
	draw_rect(rect, c, false, 1.1)
	draw_string(font, pos - Vector2(w * 0.5, -1.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, c)
