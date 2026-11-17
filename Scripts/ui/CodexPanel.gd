class_name CodexPanel
extends Modal
## The Intel Archive: dossiers, documents and contradictory accounts unlocked during the war.

const CATEGORIES := ["Factions", "People", "Terms", "Documents"]

var _detail: RichTextLabel
var _entries: Array = []


func _init(entries: Array, total: int) -> void:
	super(Vector2(1040, 0))
	_entries = entries
	var head := HBoxContainer.new()
	var t := UITheme.label("INTEL ARCHIVE", 26, Defs.INTEL, UITheme.font_bold)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(t)
	head.add_child(UITheme.label("%d / %d files" % [entries.size(), total], 14, UITheme.TEXT_DIM, UITheme.font_semibold))
	var close_b := UITheme.button("Close  [I]", 0, 34)
	close_b.pressed.connect(func(): Audio.play("click"); close())
	head.add_child(close_b)
	content.add_child(head)
	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 16)
	content.add_child(body)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(320, 560)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(scroll)
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 3)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)
	var first := {}
	for cat in CATEGORIES:
		var any := false
		for e in entries:
			if e["cat"] != cat:
				continue
			if not any:
				list.add_child(UITheme.label(cat.to_upper(), 13, Defs.GOLD, UITheme.font_bold))
				any = true
			var b := UITheme.button(e["title"], 300, 30)
			b.alignment = HORIZONTAL_ALIGNMENT_LEFT
			b.add_theme_font_size_override("font_size", 13)
			b.clip_text = true
			var entry: Dictionary = e
			b.pressed.connect(func(): Audio.play("click", -6.0); _show(entry))
			list.add_child(b)
			if first.is_empty():
				first = e
	var dp := PanelContainer.new()
	dp.add_theme_stylebox_override("panel", UITheme.box(Color(0.03, 0.06, 0.1, 0.95), Color(Defs.INTEL, 0.35), 1, 6, Vector4(20, 16, 20, 16)))
	dp.custom_minimum_size = Vector2(660, 560)
	body.add_child(dp)
	_detail = RichTextLabel.new()
	_detail.bbcode_enabled = true
	_detail.add_theme_font_size_override("normal_font_size", 16)
	_detail.add_theme_font_size_override("bold_font_size", 22)
	dp.add_child(_detail)
	if not first.is_empty():
		_show(first)


func _show(e: Dictionary) -> void:
	_detail.text = "[color=#ffd166]%s[/color]\n[b]%s[/b]\n\n%s" % [e["cat"].to_upper(), e["title"], e["text"]]


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and (event as InputEventKey).keycode == KEY_I:
		get_viewport().set_input_as_handled()
		close()
