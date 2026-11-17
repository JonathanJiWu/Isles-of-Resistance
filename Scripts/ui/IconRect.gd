class_name IconRect
extends Control
## Draws a procedural icon (structure, unit, aircraft or UI glyph) inside a UI control.

var kind := ""
var mode := "structure"   # structure | unit | aircraft | glyph | carrier
var color := UITheme.ACCENT
var icon_scale := 1.0
var dimmed := false
var _t := 0.0


func _init(p_kind: String = "", p_mode: String = "structure", p_size: float = 34.0, p_scale: float = 1.0) -> void:
	kind = p_kind
	mode = p_mode
	icon_scale = p_scale
	custom_minimum_size = Vector2(p_size, p_size)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(delta: float) -> void:
	if mode == "structure" and (kind == "radar" or kind == "laser"):
		_t += delta
		queue_redraw()


func _draw() -> void:
	var c := size * 0.5
	var a := 0.45 if dimmed else 1.0
	match mode:
		"structure":
			Icons.structure(self, kind, c, icon_scale, _t, a)
		"unit":
			if kind == "frigate":
				Icons.frigate(self, c, -PI * 0.15, icon_scale, a)
			else:
				Icons.aircraft(self, kind, c, -PI * 0.25, icon_scale, 0.0, false, a)
		"aircraft":
			Icons.aircraft(self, kind, c, -PI * 0.5, icon_scale, 0.0, true, a)
		"carrier":
			Icons.carrier(self, c, -PI * 0.15, icon_scale, a)
		"glyph":
			Icons.ui_glyph(self, kind, c, icon_scale, Color(color, a))
