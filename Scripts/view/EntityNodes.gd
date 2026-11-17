class_name EntityNodes
extends RefCounted
## Factory helpers shared by entity nodes.


static func hp_bar(ci: CanvasItem, center: Vector2, width: float, ratio: float, col_full: Color = Defs.GOOD) -> void:
	ratio = clampf(ratio, 0.0, 1.0)
	var r := Rect2(center - Vector2(width * 0.5, 2.5), Vector2(width, 5))
	ci.draw_rect(r.grow(1.0), Color(0, 0, 0, 0.7))
	var col := col_full
	if ratio < 0.35:
		col = Defs.BAD
	elif ratio < 0.65:
		col = Defs.WARN
	ci.draw_rect(Rect2(r.position, Vector2(width * ratio, 5)), col)


static func outlined_text(ci: CanvasItem, pos: Vector2, text: String, size: int, col: Color, font: Font = null) -> void:
	if font == null:
		font = UITheme.font_semibold
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var p := pos - Vector2(w * 0.5, 0)
	ci.draw_string_outline(font, p, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 4, Color(0, 0, 0, 0.75 * col.a))
	ci.draw_string(font, p, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)
