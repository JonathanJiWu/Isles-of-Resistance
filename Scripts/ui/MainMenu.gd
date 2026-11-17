extends Control
## Title screen: animated archipelago backdrop, campaign setup, settings, help and high scores.

var _bg_world: Node2D
var _bg_cam: Camera2D
var _bg_map: MapView
var _air: Node2D
var _flyers: Array = []
var _cam_t := 0.0
var _modal: Modal
var _seed_edit: LineEdit
var _diff := "recruit"
var _diff_buttons := {}
var _diff_desc: Label
var _new_panel: PanelContainer
var _menu_box: VBoxContainer
var _ticker: Label
var _ticker_clip: Control


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build_background()
	_build_ui()
	Audio.music("theme")


func _build_background() -> void:
	var vp_container := SubViewportContainer.new()
	vp_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	vp_container.stretch = true
	vp_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(vp_container)
	var vp := SubViewport.new()
	vp.size = Vector2i(1600, 900)
	vp_container.add_child(vp)
	_bg_world = Node2D.new()
	vp.add_child(_bg_world)
	var gen := MapGen.generate(randi() % 100000 + 1, Defs.MAP_W, Defs.MAP_H, 4, 2)
	var rect := MapView.map_rect(gen["cells"])
	var ocean := ColorRect.new()
	ocean.position = rect.position - Vector2(1200, 900)
	ocean.size = rect.size + Vector2(2400, 1800)
	var mat := ShaderMaterial.new()
	mat.shader = load("res://Shaders/ocean.gdshader")
	mat.set_shader_parameter("size", ocean.size)
	ocean.material = mat
	_bg_world.add_child(ocean)
	_bg_map = MapView.new()
	_bg_map.show_grid = false
	_bg_map.setup(gen["tiles"], gen["cells"])
	_bg_world.add_child(_bg_map)
	var deco := Node2D.new()
	deco.y_sort_enabled = true
	_bg_world.add_child(deco)
	var cap := StructureNode.new()
	cap.setup({"id": 0, "kind": "capital", "name": gen["capital_name"], "hp": 150, "max_hp": 150})
	cap.position = MapView.top_center(gen["tiles"], gen["capital"])
	deco.add_child(cap)
	for c in gen["cities"]:
		var cn := StructureNode.new()
		cn.setup({"id": 0, "kind": "city", "name": c["name"], "hp": 80, "max_hp": 80})
		cn.position = MapView.top_center(gen["tiles"], c["pos"])
		deco.add_child(cn)
	if gen["start_radar"] != Hex.INVALID:
		var rn := StructureNode.new()
		rn.setup({"id": 0, "kind": "radar", "hp": 30, "max_hp": 30})
		rn.position = MapView.top_center(gen["tiles"], gen["start_radar"])
		deco.add_child(rn)
	_air = Node2D.new()
	_bg_world.add_child(_air)
	_bg_cam = Camera2D.new()
	_bg_cam.zoom = Vector2(1.1, 1.1)
	_bg_cam.position = Hex.to_pixel(gen["capital"]) + Vector2(260, 0)
	_bg_world.add_child(_bg_cam)
	_bg_cam.make_current()
	for i in 7:
		_spawn_flyer(true)
	# Vignette and tint over the backdrop.
	var shade := ColorRect.new()
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sh := Shader.new()
	sh.code = """shader_type canvas_item;
void fragment() {
	vec2 uv = UV - vec2(0.5);
	float v = smoothstep(0.25, 0.85, length(uv * vec2(1.0, 1.3)));
	float left = smoothstep(0.6, 0.05, UV.x) * 0.8;
	COLOR = vec4(0.01, 0.03, 0.06, clamp(v * 0.75 + left, 0.0, 0.9));
}"""
	var sm := ShaderMaterial.new()
	sm.shader = sh
	shade.material = sm
	add_child(shade)


func _spawn_flyer(initial: bool) -> void:
	var kinds := ["bomber", "fighter", "fighter", "drone", "gunship", "bomber"]
	var n := AircraftNode.new()
	var id := randi() % 1000
	n.setup({"id": id, "kind": kinds[randi() % kinds.size()], "hp": 1, "max_hp": 1})
	var y := _bg_cam.position.y + randf_range(-420, 420)
	var x := _bg_cam.position.x + (randf_range(-700, 900) if initial else 950.0)
	n.position = Vector2(x, y)
	n.heading = PI + randf_range(-0.15, 0.15)
	n.set_meta("speed", randf_range(40, 85) * (1.4 if n.kind == "fighter" else 1.0))
	_air.add_child(n)
	_flyers.append(n)


func _build_ticker() -> void:
	var strip := PanelContainer.new()
	strip.add_theme_stylebox_override("panel", UITheme.box(Color(0.02, 0.03, 0.06, 0.85), Color(1.0, 0.45, 0.75, 0.35), 0, 0, Vector4(0, 2, 0, 2)))
	strip.set_anchors_preset(Control.PRESET_TOP_WIDE)
	strip.offset_bottom = 24
	strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(strip)
	_ticker_clip = Control.new()
	_ticker_clip.clip_contents = true
	_ticker_clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	strip.add_child(_ticker_clip)
	var items: Array = []
	for outlet in ["hnn", "ccb", "lpb", "sol"]:
		var pool: Array = Lore.NEWS[outlet]["quiet"]
		items.append("%s · %s" % [Lore.NEWS[outlet]["tag"], pool[randi() % pool.size()].format({"city": "Saltmere"})])
	items.append(Lore.ADS[randi() % Lore.ADS.size()])
	items.append(Lore.ADS[randi() % Lore.ADS.size()])
	_ticker = UITheme.label("     ◆     ".join(items), 13, Color(0.95, 0.85, 0.95), UITheme.font_semibold)
	_ticker.position = Vector2(1600, 1)
	_ticker_clip.add_child(_ticker)


func _process(delta: float) -> void:
	if _ticker != null:
		_ticker.position.x -= 60.0 * delta
		if _ticker.position.x < -_ticker.size.x:
			_ticker.position.x = _ticker_clip.size.x
	_cam_t += delta
	if _bg_cam != null:
		_bg_cam.position += Vector2(cos(_cam_t * 0.05), sin(_cam_t * 0.07)) * delta * 9.0
	for n in _flyers.duplicate():
		if not is_instance_valid(n):
			_flyers.erase(n)
			continue
		n.position += Vector2.RIGHT.rotated(n.heading) * n.get_meta("speed") * delta
		if n.position.x < _bg_cam.position.x - 1000:
			_flyers.erase(n)
			n.queue_free()
			_spawn_flyer(false)


func _build_ui() -> void:
	var root := MarginContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("margin_left", 110)
	root.add_theme_constant_override("margin_top", 90)
	root.add_theme_constant_override("margin_bottom", 60)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(col)
	var kicker := UITheme.label("THE LANTERN STRAIT · A TURN-BASED AIR DEFENSE CAMPAIGN", 15, Color(1.0, 0.45, 0.75, 0.9), UITheme.font_semibold)
	col.add_child(kicker)
	var title_box := VBoxContainer.new()
	title_box.add_theme_constant_override("separation", -26)
	title_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(title_box)
	var t1 := UITheme.label("ISLES OF", 64, UITheme.TEXT, UITheme.font_bold)
	var t2 := UITheme.label("RESISTANCE", 80, UITheme.ACCENT, UITheme.font_bold)
	t1.add_theme_constant_override("outline_size", 10)
	t1.add_theme_color_override("font_outline_color", Color(0.01, 0.03, 0.06, 0.8))
	t2.add_theme_constant_override("outline_size", 14)
	t2.add_theme_color_override("font_outline_color", Color(0.31, 0.82, 0.77, 0.22))
	title_box.add_child(t1)
	title_box.add_child(t2)
	var sub := UITheme.label("The old order is buffering. A rising power wants its turn. Tessera wants a vote.", 18, UITheme.TEXT)
	col.add_child(sub)
	var pro := UITheme.label("Tessera makes nearly every advanced chip on Earth. The Celestine Commonwealth calls it a lost province.\nThe Hesperian Federation calls it “strategically ambiguous.” Tonight, the Commonwealth declared a quarantine.", 14, UITheme.TEXT_DIM)
	col.add_child(pro)
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 30)
	col.add_child(gap)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 30)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(row)
	_menu_box = VBoxContainer.new()
	_menu_box.add_theme_constant_override("separation", 10)
	row.add_child(_menu_box)
	if Session.has_save():
		var info := Session.save_summary()
		if not info.is_empty():
			var cb := _menu_button("Continue Campaign", func(): Session.continue_game())
			var l := UITheme.label("%s · Turn %d · Wave %d/%d" % [info["difficulty"], info["turn"], info["wave"], info["waves_total"]], 12, UITheme.TEXT_DIM)
			l.position = Vector2(0, 0)
			_menu_box.add_child(cb)
			_menu_box.add_child(l)
	_menu_box.add_child(_menu_button("New Campaign", _toggle_new_panel))
	_menu_box.add_child(_menu_button("How to Play", func(): _open(HowToPlayPanel.new())))
	_menu_box.add_child(_menu_button("Settings", func(): _open(SettingsPanel.new())))
	_menu_box.add_child(_menu_button("Quit", func(): get_tree().quit()))
	_build_new_panel(row)
	_build_scores()
	_build_ticker()
	var ver := UITheme.label("v%s  ·  Godot %s" % [Defs.VERSION, Engine.get_version_info()["string"]], 12, Color(UITheme.TEXT_DIM, 0.7))
	ver.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	ver.offset_left = 16
	ver.offset_top = -28
	add_child(ver)


func _menu_button(text: String, cb: Callable) -> Button:
	var b := UITheme.button(text, 300, 50)
	b.add_theme_font_size_override("font_size", 20)
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.pressed.connect(func():
		Audio.play("click")
		cb.call())
	b.mouse_entered.connect(func(): Audio.play("hover", -6.0))
	return b


func _build_new_panel(row: HBoxContainer) -> void:
	_new_panel = PanelContainer.new()
	_new_panel.add_theme_stylebox_override("panel", UITheme.box(Color(0.04, 0.08, 0.12, 0.94), UITheme.ACCENT, 1, 8, Vector4(22, 18, 22, 18)))
	_new_panel.custom_minimum_size = Vector2(500, 0)
	_new_panel.visible = false
	_new_panel.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	row.add_child(_new_panel)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 12)
	_new_panel.add_child(vb)
	vb.add_child(UITheme.label("NEW CAMPAIGN", 22, UITheme.ACCENT, UITheme.font_bold))
	vb.add_child(UITheme.label("Difficulty", 14, UITheme.TEXT_DIM))
	var dr := HBoxContainer.new()
	dr.add_theme_constant_override("separation", 8)
	vb.add_child(dr)
	for d in Defs.DIFFICULTY_ORDER:
		var b := UITheme.button(Defs.DIFFICULTY[d]["name"], 112, 42)
		b.toggle_mode = true
		b.pressed.connect(func():
			Audio.play("click")
			_set_diff(d))
		dr.add_child(b)
		_diff_buttons[d] = b
	_diff_desc = UITheme.label("", 14, UITheme.TEXT)
	_diff_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_diff_desc.custom_minimum_size = Vector2(472, 44)
	vb.add_child(_diff_desc)
	vb.add_child(UITheme.label("Map seed", 14, UITheme.TEXT_DIM))
	var sr := HBoxContainer.new()
	sr.add_theme_constant_override("separation", 8)
	_seed_edit = LineEdit.new()
	_seed_edit.text = str(randi() % 1000000 + 1)
	_seed_edit.custom_minimum_size = Vector2(220, 40)
	_seed_edit.max_length = 9
	sr.add_child(_seed_edit)
	var dice := UITheme.button("Randomize", 0, 40)
	dice.pressed.connect(func():
		Audio.play("click")
		_seed_edit.text = str(randi() % 1000000 + 1))
	sr.add_child(dice)
	vb.add_child(sr)
	var go := UITheme.button("Deploy  ▸", 0, 52)
	go.add_theme_font_size_override("font_size", 22)
	go.add_theme_stylebox_override("normal", UITheme.box(Color(0.1, 0.36, 0.38, 0.97), UITheme.ACCENT, 2, 7))
	go.add_theme_stylebox_override("hover", UITheme.box(Color(0.14, 0.46, 0.47, 1.0), Color.WHITE, 2, 7))
	go.pressed.connect(_start)
	vb.add_child(go)
	# First campaign: start on Recruit. Returning commanders default to Regular.
	_set_diff("recruit" if Session.highscores().is_empty() else "regular")


func _set_diff(d: String) -> void:
	_diff = d
	for k in _diff_buttons:
		_diff_buttons[k].set_pressed_no_signal(k == d)
	_diff_desc.text = Defs.DIFFICULTY[d]["desc"]


func _toggle_new_panel() -> void:
	_new_panel.visible = not _new_panel.visible
	if _new_panel.visible:
		_new_panel.modulate.a = 0.0
		create_tween().tween_property(_new_panel, "modulate:a", 1.0, 0.2)


func _start() -> void:
	Audio.play("build")
	var sd := int(_seed_edit.text) if _seed_edit.text.is_valid_int() else 0
	if sd <= 0:
		sd = hash(_seed_edit.text) % 1000000 + 1
	Session.start_new(absi(sd), _diff)


func _build_scores() -> void:
	var scores := Session.highscores()
	if scores.is_empty():
		return
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UITheme.box(Color(0.04, 0.08, 0.12, 0.85), UITheme.BORDER, 1, 8, Vector4(18, 14, 18, 14)))
	p.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	p.offset_left = -390
	p.offset_right = -24
	p.offset_bottom = -24
	p.grow_vertical = Control.GROW_DIRECTION_BEGIN
	add_child(p)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 4)
	p.add_child(vb)
	vb.add_child(UITheme.label("HALL OF FAME", 16, Defs.GOLD, UITheme.font_bold))
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 16)
	vb.add_child(grid)
	var i := 1
	for s in scores.slice(0, 6):
		grid.add_child(UITheme.label("%d." % i, 13, UITheme.TEXT_DIM))
		grid.add_child(UITheme.label(str(s["score"]), 13, UITheme.TEXT, UITheme.font_bold))
		grid.add_child(UITheme.label(Defs.DIFFICULTY.get(s["difficulty"], {"name": "?"})["name"], 13, UITheme.TEXT_DIM))
		var res := UITheme.label("Victory" if s["result"] == "victory" else "Defeat · wave %s" % s["waves"], 13, Defs.GOOD if s["result"] == "victory" else Defs.BAD)
		grid.add_child(res)
		i += 1


func _open(m: Modal) -> void:
	if _modal != null and is_instance_valid(_modal):
		_modal.queue_free()
	_modal = m
	add_child(m)
	m.open_anim()
