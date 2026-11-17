class_name UITheme
extends RefCounted
## Builds the shared UI theme (fonts, panels, buttons, sliders...) in code.

const BG := Color(0.03, 0.06, 0.1)
const PANEL := Color(0.05, 0.09, 0.14, 0.93)
const PANEL_LIGHT := Color(0.08, 0.14, 0.21, 0.97)
const BORDER := Color(0.27, 0.6, 0.64, 0.5)
const ACCENT := Color(0.31, 0.82, 0.77)
const TEXT := Color(0.9, 0.94, 0.97)
const TEXT_DIM := Color(0.6, 0.68, 0.77)

static var font_regular: Font
static var font_semibold: Font
static var font_bold: Font
static var theme: Theme


static func init() -> void:
	if theme != null:
		return
	font_regular = load("res://Assets/fonts/ChakraPetch-Regular.ttf")
	font_semibold = load("res://Assets/fonts/ChakraPetch-SemiBold.ttf")
	font_bold = load("res://Assets/fonts/ChakraPetch-Bold.ttf")
	theme = Theme.new()
	theme.default_font = font_regular
	theme.default_font_size = 16

	var btn_normal := box(Color(0.08, 0.14, 0.21, 0.96), BORDER, 1, 5, Vector4(12, 6, 12, 6))
	var btn_hover := box(Color(0.11, 0.21, 0.29, 0.98), ACCENT, 1, 5, Vector4(12, 6, 12, 6))
	var btn_pressed := box(Color(0.12, 0.33, 0.36, 1.0), ACCENT, 2, 5, Vector4(12, 6, 12, 6))
	var btn_disabled := box(Color(0.06, 0.09, 0.13, 0.85), Color(0.2, 0.26, 0.32, 0.5), 1, 5, Vector4(12, 6, 12, 6))
	var focus := box(Color(0, 0, 0, 0), Color(ACCENT, 0.6), 1, 5)
	for cls in ["Button", "OptionButton", "MenuButton"]:
		theme.set_stylebox("normal", cls, btn_normal)
		theme.set_stylebox("hover", cls, btn_hover)
		theme.set_stylebox("pressed", cls, btn_pressed)
		theme.set_stylebox("hover_pressed", cls, btn_pressed)
		theme.set_stylebox("disabled", cls, btn_disabled)
		theme.set_stylebox("focus", cls, focus)
		theme.set_font("font", cls, font_semibold)
		theme.set_color("font_color", cls, TEXT)
		theme.set_color("font_hover_color", cls, Color.WHITE)
		theme.set_color("font_pressed_color", cls, Color.WHITE)
		theme.set_color("font_hover_pressed_color", cls, Color.WHITE)
		theme.set_color("font_focus_color", cls, TEXT)
		theme.set_color("font_disabled_color", cls, Color(0.45, 0.5, 0.56))

	theme.set_color("font_color", "Label", TEXT)
	theme.set_color("font_shadow_color", "Label", Color(0, 0, 0, 0))
	theme.set_color("default_color", "RichTextLabel", TEXT)
	theme.set_font("bold_font", "RichTextLabel", font_bold)
	theme.set_font("normal_font", "RichTextLabel", font_regular)
	for key in ["normal_font_size", "bold_font_size", "italics_font_size", "bold_italics_font_size", "mono_font_size"]:
		theme.set_font_size(key, "RichTextLabel", 15)

	theme.set_stylebox("panel", "PanelContainer", box(PANEL, BORDER, 1, 7, Vector4(12, 10, 12, 10)))
	theme.set_stylebox("panel", "Panel", box(PANEL, BORDER, 1, 7))
	theme.set_stylebox("panel", "TooltipPanel", box(Color(0.04, 0.08, 0.12, 0.97), ACCENT, 1, 4, Vector4(10, 6, 10, 6)))
	theme.set_color("font_color", "TooltipLabel", TEXT)
	theme.set_font("font", "TooltipLabel", font_regular)
	theme.set_font_size("font_size", "TooltipLabel", 14)

	theme.set_stylebox("background", "ProgressBar", box(Color(0.03, 0.05, 0.08, 0.9), Color(0, 0, 0, 0), 0, 3))
	theme.set_stylebox("fill", "ProgressBar", box(ACCENT, Color(0, 0, 0, 0), 0, 3))
	theme.set_font_size("font_size", "ProgressBar", 12)

	var slider := box(Color(0.1, 0.16, 0.23), Color(0, 0, 0, 0), 0, 3, Vector4(0, 3, 0, 3))
	theme.set_stylebox("slider", "HSlider", slider)
	theme.set_stylebox("grabber_area", "HSlider", box(Color(ACCENT, 0.7), Color(0, 0, 0, 0), 0, 3, Vector4(0, 3, 0, 3)))
	theme.set_stylebox("grabber_area_highlight", "HSlider", box(ACCENT, Color(0, 0, 0, 0), 0, 3, Vector4(0, 3, 0, 3)))
	theme.set_icon("grabber", "HSlider", _circle_icon(9, Color.WHITE))
	theme.set_icon("grabber_highlight", "HSlider", _circle_icon(9, ACCENT.lightened(0.4)))

	for cls in ["CheckButton", "CheckBox"]:
		theme.set_color("font_color", cls, TEXT)
		theme.set_color("font_hover_color", cls, Color.WHITE)
		theme.set_color("font_pressed_color", cls, TEXT)
		theme.set_color("font_hover_pressed_color", cls, Color.WHITE)
		theme.set_stylebox("normal", cls, StyleBoxEmpty.new())
		theme.set_stylebox("hover", cls, StyleBoxEmpty.new())
		theme.set_stylebox("pressed", cls, StyleBoxEmpty.new())
		theme.set_stylebox("hover_pressed", cls, StyleBoxEmpty.new())
		theme.set_stylebox("focus", cls, StyleBoxEmpty.new())

	theme.set_stylebox("panel", "PopupMenu", box(PANEL_LIGHT, ACCENT, 1, 4, Vector4(6, 6, 6, 6)))
	theme.set_stylebox("hover", "PopupMenu", box(Color(0.14, 0.3, 0.34), Color(0, 0, 0, 0), 0, 3))
	theme.set_color("font_color", "PopupMenu", TEXT)
	theme.set_color("font_hover_color", "PopupMenu", Color.WHITE)

	theme.set_stylebox("normal", "LineEdit", box(Color(0.03, 0.06, 0.1, 0.95), BORDER, 1, 4, Vector4(10, 6, 10, 6)))
	theme.set_stylebox("focus", "LineEdit", box(Color(0, 0, 0, 0), ACCENT, 1, 4))
	theme.set_color("font_color", "LineEdit", TEXT)
	theme.set_color("caret_color", "LineEdit", ACCENT)

	var sb_bg := box(Color(0.03, 0.05, 0.08, 0.6), Color(0, 0, 0, 0), 0, 4)
	var grab := box(Color(0.25, 0.45, 0.5, 0.8), Color(0, 0, 0, 0), 0, 4)
	var grab_hi := box(ACCENT, Color(0, 0, 0, 0), 0, 4)
	for cls in ["VScrollBar", "HScrollBar"]:
		theme.set_stylebox("scroll", cls, sb_bg)
		theme.set_stylebox("grabber", cls, grab)
		theme.set_stylebox("grabber_highlight", cls, grab_hi)
		theme.set_stylebox("grabber_pressed", cls, grab_hi)

	var sep := StyleBoxLine.new()
	sep.color = Color(BORDER, 0.35)
	sep.thickness = 1
	theme.set_stylebox("separator", "HSeparator", sep)
	theme.set_constant("separation", "HSeparator", 10)


static func box(bg: Color, border: Color, border_w: int = 1, radius: int = 6, margins: Vector4 = Vector4(8, 6, 8, 6)) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(border_w)
	sb.set_corner_radius_all(radius)
	sb.content_margin_left = margins.x
	sb.content_margin_top = margins.y
	sb.content_margin_right = margins.z
	sb.content_margin_bottom = margins.w
	sb.anti_aliasing = true
	return sb


static func _circle_icon(r: int, col: Color) -> ImageTexture:
	var img := Image.create(r * 2 + 2, r * 2 + 2, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var c := Vector2(r + 1, r + 1)
	for y in img.get_height():
		for x in img.get_width():
			var d := Vector2(x + 0.5, y + 0.5).distance_to(c)
			if d <= r:
				img.set_pixel(x, y, Color(col, clampf(r - d + 0.5, 0.0, 1.0)))
	return ImageTexture.create_from_image(img)


## Convenience label factory.
static func label(text: String, size: int = 16, color: Color = TEXT, font: Font = null) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	if font != null:
		l.add_theme_font_override("font", font)
	return l


static func button(text: String, min_w: float = 0.0, min_h: float = 38.0) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(min_w, min_h)
	b.focus_mode = Control.FOCUS_NONE
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	return b


static func kind_color(kind: String) -> Color:
	match kind:
		"good":
			return Defs.GOOD
		"bad":
			return Defs.BAD
		"warn":
			return Defs.WARN
		"intel":
			return Defs.INTEL
		"intercept":
			return Color(1.0, 0.55, 0.78)
	return TEXT_DIM


## Emblem IconRect for a person (by Lore id).
static func person_emblem(person_id: String, size: float = 44.0) -> IconRect:
	var p: Dictionary = Lore.person(person_id)
	var f: Dictionary = Lore.FACTIONS.get(p["faction"], Lore.FACTIONS["tessera"])
	var icon := IconRect.new(f["emblem"], "emblem", size, size / 30.0)
	icon.color = f["color"]
	return icon
