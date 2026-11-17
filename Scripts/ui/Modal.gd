class_name Modal
extends Control
## Base class for full-screen modal dialogs: dims the screen and centers a panel.

signal closed

var panel: PanelContainer
var content: VBoxContainer
var dismiss_on_backdrop := true
var _backdrop: ColorRect


func _init(min_size: Vector2 = Vector2(520, 0)) -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_backdrop = ColorRect.new()
	_backdrop.color = Color(0.01, 0.02, 0.04, 0.72)
	_backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	_backdrop.gui_input.connect(_on_backdrop_input)
	add_child(_backdrop)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	panel = PanelContainer.new()
	panel.custom_minimum_size = min_size
	panel.add_theme_stylebox_override("panel", UITheme.box(Color(0.05, 0.09, 0.14, 0.98), UITheme.ACCENT, 1, 8, Vector4(26, 20, 26, 22)))
	center.add_child(panel)
	content = VBoxContainer.new()
	content.add_theme_constant_override("separation", 10)
	panel.add_child(content)


func open_anim() -> void:
	modulate.a = 0.0
	panel.scale = Vector2(0.96, 0.96)
	panel.pivot_offset = panel.size * 0.5
	var tw := create_tween().set_parallel(true)
	tw.tween_property(self, "modulate:a", 1.0, 0.18)
	tw.tween_property(panel, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func close() -> void:
	closed.emit()
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.14)
	tw.tween_callback(queue_free)


func title(text: String, subtitle: String = "") -> void:
	var l := UITheme.label(text, 28, UITheme.ACCENT, UITheme.font_bold)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(l)
	if subtitle != "":
		var s := UITheme.label(subtitle, 14, UITheme.TEXT_DIM)
		s.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		s.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		content.add_child(s)


func _on_backdrop_input(event: InputEvent) -> void:
	if dismiss_on_backdrop and event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		close()


func _unhandled_key_input(event: InputEvent) -> void:
	if event.is_pressed() and not event.is_echo() and event is InputEventKey and (event as InputEventKey).keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		close()
