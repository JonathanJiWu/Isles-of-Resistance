class_name StructureNode
extends Node2D
## A player structure (installation, city or strategic infrastructure) on the map.
## The installation art is drawn once into a child layer (redrawn only when the damage stage
## changes); lights, moving parts, smoke, signs and the HP bar are drawn every frame on top.

var id := -1
var kind := ""
var label := ""
var hp := 1
var max_hp := 1
var targeted := false
var order_ready := false         # an order is available here (train, commission, strike)
var foundry := false
var info := {}
var _t := 0.0
var _signs: Array = []
var _base: DrawLayer
var _stage := 0

const ART_SCALE := 1.22


func setup(s: Dictionary) -> void:
	id = s["id"]
	kind = s["kind"]
	label = s.get("name", "")
	hp = s["hp"]
	max_hp = s["max_hp"]
	foundry = s.get("foundry", false)
	var facing: int = s.get("facing", -1)
	var seed_value: int = absi(hash(label if label != "" else str(s.get("pos", Vector2i(id, 0))))) % 100003
	info = {"kind": kind, "facing": facing, "axis": s.get("axis", 0.5236), "seed": seed_value,
		"foundry": foundry, "stage": 0}
	if kind == "city" and not foundry:
		info["style"] = Installations.city_style(label, facing)
	_t = randf() * 10.0
	_signs.clear()
	if kind == "capital":
		_signs = [["LUMEN", Vector2(-27, -40), Lore.SIGN_COLORS[1]], ["ASSEMBLY", Vector2(20, -24), Lore.SIGN_COLORS[2]]]
	elif foundry:
		_signs = [["TLW · FAB 18", Vector2(-14, -27), Lore.SIGN_COLORS[2]], ["CLEANROOM", Vector2(26, -6), Lore.SIGN_COLORS[1]]]
	elif kind == "city":
		var h: int = absi(hash(label))
		for k in 2:
			var txt: String = Lore.SIGNS[(h + k * 7) % Lore.SIGNS.size()]
			var pos := Vector2(-25, -30) if k == 0 else Vector2(27, -7)
			_signs.append([txt, pos, Lore.SIGN_COLORS[(h / 3 + k) % Lore.SIGN_COLORS.size()]])
	if _base == null:
		_base = DrawLayer.new()
		_base.show_behind_parent = true
		_base.draw_fn = _draw_base
		_base.scale = Vector2(ART_SCALE, ART_SCALE)
		add_child(_base)
	_stage = _stage_for(hp, max_hp)
	info["stage"] = _stage
	_base.queue_redraw()
	set_process(true)


func appear() -> void:
	scale = Vector2(0.2, 0.2)
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


static func _stage_for(p_hp: int, p_max: int) -> int:
	var r := float(p_hp) / maxf(1.0, float(p_max))
	if r >= 0.6:
		return 0
	if r >= 0.3:
		return 1
	return 2


func set_hp(p_hp: int, p_max: int) -> void:
	if p_hp == hp and p_max == max_hp:
		return
	hp = p_hp
	max_hp = p_max
	var st := _stage_for(hp, max_hp)
	if st != _stage:
		_stage = st
		info["stage"] = st
		if _base != null:
			_base.queue_redraw()
	queue_redraw()


func flash() -> void:
	modulate = Color(2.2, 0.8, 0.7)
	create_tween().tween_property(self, "modulate", Color.WHITE, 0.35)


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw_base(l: DrawLayer) -> void:
	if kind == "capital" or kind == "city":
		var warm := Color(1.0, 0.45, 0.75) if foundry else Color(1.0, 0.6, 0.3)
		for r in [48.0, 36.0, 25.0]:
			l.draw_circle(Vector2(0, 4), r, Color(warm, 0.04))
	Installations.draw_base(l, info)


func _draw() -> void:
	if kind == "capital" or foundry:
		_draw_searchlights()
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(ART_SCALE, ART_SCALE))
	Installations.draw_live(self, info, _t)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	for sg in _signs:
		_draw_sign(sg[0], sg[1], sg[2])
	var bar_y := 26.0
	if hp < max_hp or kind == "capital":
		EntityNodes.hp_bar(self, Vector2(0, bar_y), 30.0 if kind != "capital" else 38.0, float(hp) / max_hp)
	if kind == "capital" or kind == "city":
		var col := Defs.GOLD if kind == "capital" else Color(0.92, 0.95, 0.98)
		EntityNodes.outlined_text(self, Vector2(0, 39), label, 13 if kind == "capital" else 12, col)
	elif kind == "power" or kind == "cable":
		EntityNodes.outlined_text(self, Vector2(0, 39), label, 11, Color(0.75, 0.85, 0.95, 0.9))
	if order_ready:
		var top := -Installations.top_extent(kind, foundry) * ART_SCALE - 6.0
		var bob := sin(_t * 3.0) * 2.0
		var p := Vector2(0, top + bob)
		draw_circle(p, 9.0, Color(Defs.PLAYER_COLOR, 0.12 + 0.08 * sin(_t * 3.0)))
		draw_colored_polygon(PackedVector2Array([p + Vector2(-5, -3), p + Vector2(0, 2), p + Vector2(5, -3), p + Vector2(0, -8)]), Color(Defs.PLAYER_COLOR, 0.95))
		draw_polyline(PackedVector2Array([p + Vector2(-5, -3), p + Vector2(0, 2), p + Vector2(5, -3), p + Vector2(0, -8), p + Vector2(-5, -3)]), Color(0.9, 1.0, 1.0, 0.9), 1.0, true)
	if targeted:
		var pulse := 0.5 + 0.5 * sin(_t * 5.0)
		var r := 31.0 + pulse * 2.0
		var col := Color(Defs.ENEMY_COLOR, 0.55 + 0.35 * pulse)
		for k in 4:
			var a := k * PI * 0.5 + PI * 0.25
			draw_arc(Vector2.ZERO, r, a - 0.35, a + 0.35, 6, col, 2.0, true)


func _draw_searchlights() -> void:
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
