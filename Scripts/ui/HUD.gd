class_name HUD
extends Control
## In-game heads-up display: resources, construction panel, selection info, log, end turn,
## banners, wave alerts, tooltips and tutorial hints.

signal build_selected(kind: String)
signal recon_selected
signal end_turn_pressed
signal skip_pressed
signal action_pressed(action: String, id: int)
signal research_pressed
signal coverage_toggled
signal menu_pressed
signal ops_pressed
signal intel_pressed
signal directive_pressed
signal comms_dismissed

const LEFT_W := 252.0
const RIGHT_W := 316.0

var st: GameState
var _chips := {}
var _build_buttons := {}
var _recon_btn: Button
var _info_scroll: ScrollContainer
var _info_box: VBoxContainer
var _log: RichTextLabel
var _end_btn: Button
var _end_sub: Label
var _banner: PanelContainer
var _banner_label: Label
var _wave_panel: PanelContainer
var _wave_box: VBoxContainer
var _tooltip: PanelContainer
var _tooltip_label: RichTextLabel
var _toast: PanelContainer
var _toast_label: Label
var _hint: PanelContainer
var _hint_label: RichTextLabel
var _cov_btn: Button
var _intel_label: RichTextLabel
var _busy := false
var _log_hold := 0
var _active_build := ""
var _wave_tween: Tween
var _banner_tween: Tween
var _toast_tween: Tween
var _ticker_clip: Control
var _ticker_label: Label
var _ticker_text := ""
var _ops_btn: Button
var _intel_btn: Button
var _comms: PanelContainer
var _comms_icon_slot: Control
var _comms_name: Label
var _comms_title: Label
var _comms_text: RichTextLabel
var _intercept: PanelContainer
var _intercept_label: RichTextLabel
var _intercept_tween: Tween


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func build(p_state: GameState) -> void:
	st = p_state
	_build_top_bar()
	_build_ticker()
	_build_left_panel()
	_build_right_panel()
	_build_log()
	_build_end_turn()
	_build_overlays()
	refresh()


# --------------------------------------------------------------------------------------------
# Construction
# --------------------------------------------------------------------------------------------

func _panel(bg: Color = UITheme.PANEL) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UITheme.box(bg, UITheme.BORDER, 1, 7, Vector4(12, 10, 12, 10)))
	p.mouse_filter = Control.MOUSE_FILTER_STOP
	return p


func _build_top_bar() -> void:
	var bar := PanelContainer.new()
	bar.add_theme_stylebox_override("panel", UITheme.box(Color(0.03, 0.06, 0.1, 0.94), Color(UITheme.BORDER, 0.35), 0, 0, Vector4(16, 4, 12, 4)))
	bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	bar.custom_minimum_size.y = 52
	bar.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(bar)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	bar.add_child(row)
	var tb := VBoxContainer.new()
	tb.add_theme_constant_override("separation", -5)
	tb.alignment = BoxContainer.ALIGNMENT_CENTER
	tb.add_child(UITheme.label("ISLES OF RESISTANCE", 18, UITheme.ACCENT, UITheme.font_bold))
	tb.add_child(UITheme.label("TESSERA AIR DEFENSE COMMAND · %s" % Defs.DIFFICULTY[st.difficulty]["name"].to_upper(), 10, UITheme.TEXT_DIM, UITheme.font_semibold))
	row.add_child(tb)
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(sp)
	for k in [["supplies", Defs.GOLD, "Supplies: spent on construction, units, repairs and strikes. Income arrives each turn from your Capital, Cities and Harbors."],
			["research", Color(0.6, 0.75, 1.0), "Research points: spend them in the Research tree [R]. Produced by your Capital and Research Labs."],
			["turn", UITheme.TEXT, "Current turn."],
			["wave", Defs.ENEMY_COLOR, "Enemy waves launched so far, and when the next one launches."],
			["resolve", Defs.GOLD, "Public Resolve: Tessera's will to keep going. Defiant (75+) adds 10% income; Shaken (below 40) and Breaking (below 20) cut it. Losing cities hurts it; repelling waves, sinking carriers and some directives raise it."],
			["ally", Color(0.55, 0.68, 1.0), "Hesperian Commitment: how much the Federation is willing to help. At 55+ every repelled wave brings an arms shipment, bigger the higher it goes."],
			["score", Defs.GOLD, "Score: aircraft downed, waves repelled, carriers sunk, and a victory bonus."]]:
		var chip := HBoxContainer.new()
		chip.add_theme_constant_override("separation", 6)
		chip.tooltip_text = k[2]
		chip.mouse_filter = Control.MOUSE_FILTER_STOP
		var icon := IconRect.new(k[0], "glyph", 26, 1.0)
		icon.color = k[1]
		chip.add_child(icon)
		var vb := VBoxContainer.new()
		vb.add_theme_constant_override("separation", -4)
		var v := UITheme.label("0", 18, UITheme.TEXT, UITheme.font_bold)
		var s := UITheme.label("", 11, UITheme.TEXT_DIM)
		vb.add_child(v)
		vb.add_child(s)
		chip.add_child(vb)
		row.add_child(chip)
		_chips[k[0]] = [v, s]
	var sp2 := Control.new()
	sp2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(sp2)
	var rb := UITheme.button("Research [R]", 0, 36)
	rb.pressed.connect(func(): Audio.play("click"); research_pressed.emit())
	row.add_child(rb)
	_cov_btn = UITheme.button("Coverage [V]", 0, 36)
	_cov_btn.toggle_mode = true
	_cov_btn.tooltip_text = "Show the combined reach of your air defenses."
	_cov_btn.pressed.connect(func(): Audio.play("click"); coverage_toggled.emit())
	row.add_child(_cov_btn)
	var mb := UITheme.button("Menu [Esc]", 0, 36)
	mb.pressed.connect(func(): Audio.play("click"); menu_pressed.emit())
	row.add_child(mb)
	for b in [rb, _cov_btn, mb]:
		b.size_flags_vertical = Control.SIZE_SHRINK_CENTER


func _build_ticker() -> void:
	var strip := PanelContainer.new()
	strip.add_theme_stylebox_override("panel", UITheme.box(Color(0.02, 0.03, 0.06, 0.92), Color(1.0, 0.45, 0.75, 0.35), 0, 0, Vector4(0, 2, 0, 2)))
	strip.set_anchors_preset(Control.PRESET_TOP_WIDE)
	strip.offset_top = 52
	strip.offset_bottom = 76
	strip.mouse_filter = Control.MOUSE_FILTER_STOP
	strip.tooltip_text = "Broadcasts: CCB (Commonwealth state media), HNN (Hesperian), LPB (Lumen Public Broadcasting), Strait Talk (pirate radio) and advertisers. Each tells the same war differently."
	add_child(strip)
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 0)
	strip.add_child(hb)
	var tag := PanelContainer.new()
	tag.add_theme_stylebox_override("panel", UITheme.box(Color(1.0, 0.3, 0.6, 0.9), Color(0, 0, 0, 0), 0, 0, Vector4(10, 0, 10, 0)))
	var tl := UITheme.label("LIVE", 12, Color.WHITE, UITheme.font_bold)
	tl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	tag.add_child(tl)
	hb.add_child(tag)
	_ticker_clip = Control.new()
	_ticker_clip.clip_contents = true
	_ticker_clip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_ticker_clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hb.add_child(_ticker_clip)
	_ticker_label = UITheme.label("", 13, Color(0.95, 0.85, 0.95), UITheme.font_semibold)
	_ticker_label.position = Vector2(1600, 1)
	_ticker_clip.add_child(_ticker_label)


func _build_left_panel() -> void:
	var p := _panel()
	p.position = Vector2(10, 84)
	p.custom_minimum_size = Vector2(LEFT_W, 0)
	add_child(p)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 4)
	p.add_child(vb)
	vb.add_child(UITheme.label("CONSTRUCT", 15, UITheme.ACCENT, UITheme.font_bold))
	var i := 1
	for kind in Defs.BUILD_ORDER:
		var b := _make_build_button(kind, i % 10)
		vb.add_child(b)
		_build_buttons[kind] = b
		i += 1
	vb.add_child(HSeparator.new())
	vb.add_child(UITheme.label("OPERATIONS", 15, UITheme.ACCENT, UITheme.font_bold))
	_recon_btn = _make_row_button("recon", "glyph", "Recon Flight", str(Defs.RECON_COST))
	_recon_btn.tooltip_text = "Fly a reconnaissance sortie: reveal a radius-%d area within %d hexes of your Capital or an Airbase until your next turn. Use it to find enemy carriers. Once per turn." % [Defs.RECON_RADIUS, Defs.RECON_RANGE]
	_recon_btn.pressed.connect(func(): Audio.play("click"); recon_selected.emit())
	vb.add_child(_recon_btn)
	_ops_btn = _make_row_button("cyber", "glyph", "Cyber Ops  [O]", "")
	_ops_btn.tooltip_text = "Spend research points on hacking operations against the Commonwealth's networks."
	_ops_btn.pressed.connect(func(): Audio.play("click"); ops_pressed.emit())
	vb.add_child(_ops_btn)
	_intel_btn = _make_row_button("intel", "glyph", "Intel Archive  [I]", "")
	_intel_btn.tooltip_text = "Dossiers, documents, intercepts and contradictory accounts collected during the war."
	_intel_btn.pressed.connect(func(): Audio.play("click"); intel_pressed.emit())
	vb.add_child(_intel_btn)


func _make_row_button(kind: String, mode: String, text: String, cost: String) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(LEFT_W - 24, 38)
	b.focus_mode = Control.FOCUS_NONE
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var hb := HBoxContainer.new()
	hb.set_anchors_preset(Control.PRESET_FULL_RECT)
	hb.offset_left = 6
	hb.offset_right = -10
	hb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hb.add_theme_constant_override("separation", 8)
	b.add_child(hb)
	var icon := IconRect.new(kind, mode, 34, 0.9)
	if mode == "glyph":
		icon.icon_scale = 1.3
	hb.add_child(icon)
	var name_l := UITheme.label(text, 14, UITheme.TEXT, UITheme.font_semibold)
	name_l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_l.clip_text = true
	hb.add_child(name_l)
	var cost_l := UITheme.label(cost, 14, Defs.GOLD, UITheme.font_bold)
	cost_l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hb.add_child(cost_l)
	b.set_meta("icon", icon)
	b.set_meta("name", name_l)
	b.set_meta("cost", cost_l)
	return b


func _make_build_button(kind: String, hotkey: int) -> Button:
	var def: Dictionary = Defs.STRUCTURES[kind]
	var b := _make_row_button(kind, "structure", def["name"], str(def["cost"]))
	b.toggle_mode = true
	b.set_meta("hotkey", hotkey)
	b.pressed.connect(func():
		Audio.play("click")
		build_selected.emit(kind))
	b.mouse_entered.connect(func(): Audio.play("hover", -8.0))
	return b


func _build_right_panel() -> void:
	var p := _panel()
	p.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	p.offset_left = -RIGHT_W - 10
	p.offset_right = -10
	p.offset_top = 84
	p.offset_bottom = 640
	add_child(p)
	_info_scroll = ScrollContainer.new()
	_info_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	p.add_child(_info_scroll)
	_info_box = VBoxContainer.new()
	_info_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_info_box.add_theme_constant_override("separation", 6)
	_info_scroll.add_child(_info_box)


func _build_log() -> void:
	var p := _panel(Color(0.03, 0.06, 0.1, 0.82))
	p.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	p.offset_left = 10
	p.offset_right = 10 + 470
	p.offset_top = -176
	p.offset_bottom = -10
	add_child(p)
	_log = RichTextLabel.new()
	_log.bbcode_enabled = true
	_log.scroll_following = true
	_log.add_theme_font_size_override("normal_font_size", 13)
	_log.add_theme_font_size_override("bold_font_size", 13)
	_log.add_theme_font_size_override("italics_font_size", 13)
	_log.mouse_filter = Control.MOUSE_FILTER_PASS
	p.add_child(_log)


func _build_end_turn() -> void:
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	box.offset_left = -RIGHT_W - 10
	box.offset_right = -10
	box.offset_top = -250
	box.offset_bottom = -10
	box.alignment = BoxContainer.ALIGNMENT_END
	box.add_theme_constant_override("separation", 6)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(box)
	var intel := _panel(Color(0.08, 0.05, 0.07, 0.85))
	intel.add_theme_stylebox_override("panel", UITheme.box(Color(0.09, 0.05, 0.07, 0.88), Color(Defs.ENEMY_COLOR, 0.45), 1, 7, Vector4(12, 8, 12, 8)))
	_intel_label = RichTextLabel.new()
	_intel_label.bbcode_enabled = true
	_intel_label.fit_content = true
	_intel_label.add_theme_font_size_override("normal_font_size", 13)
	_intel_label.add_theme_font_size_override("bold_font_size", 13)
	_intel_label.add_theme_font_size_override("italics_font_size", 13)
	_intel_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	intel.add_child(_intel_label)
	box.add_child(intel)
	_end_btn = Button.new()
	_end_btn.custom_minimum_size = Vector2(RIGHT_W, 66)
	_end_btn.focus_mode = Control.FOCUS_NONE
	_end_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_end_btn.add_theme_font_override("font", UITheme.font_bold)
	_end_btn.add_theme_font_size_override("font_size", 24)
	_end_btn.add_theme_stylebox_override("normal", UITheme.box(Color(0.1, 0.36, 0.38, 0.97), UITheme.ACCENT, 2, 7))
	_end_btn.add_theme_stylebox_override("hover", UITheme.box(Color(0.14, 0.46, 0.47, 1.0), Color.WHITE, 2, 7))
	_end_btn.add_theme_stylebox_override("pressed", UITheme.box(Color(0.08, 0.28, 0.3, 1.0), UITheme.ACCENT, 2, 7))
	_end_btn.add_theme_stylebox_override("disabled", UITheme.box(Color(0.12, 0.08, 0.1, 0.95), Color(Defs.ENEMY_COLOR, 0.6), 2, 7))
	_end_btn.pressed.connect(func():
		Audio.play("click")
		if _busy:
			skip_pressed.emit()
		elif st.story.pending != "" and st.result == "":
			directive_pressed.emit()
		else:
			end_turn_pressed.emit())
	box.add_child(_end_btn)
	_end_sub = UITheme.label("", 12, UITheme.TEXT_DIM)
	_end_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_end_sub)


func _build_overlays() -> void:
	_banner = PanelContainer.new()
	_banner.add_theme_stylebox_override("panel", UITheme.box(Color(0.03, 0.06, 0.1, 0.9), UITheme.ACCENT, 1, 6, Vector4(28, 8, 28, 8)))
	_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_banner.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_banner.offset_top = 92
	_banner.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_banner.modulate.a = 0.0
	_banner_label = UITheme.label("", 26, UITheme.ACCENT, UITheme.font_bold)
	_banner_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner.add_child(_banner_label)
	add_child(_banner)

	_hint = PanelContainer.new()
	_hint.add_theme_stylebox_override("panel", UITheme.box(Color(0.05, 0.12, 0.16, 0.95), UITheme.ACCENT, 1, 7, Vector4(14, 10, 14, 10)))
	_hint.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_hint.offset_top = 150
	_hint.custom_minimum_size = Vector2(560, 0)
	_hint.offset_left = -280
	_hint.offset_right = 280
	_hint.visible = false
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 10)
	_hint.add_child(hb)
	_hint_label = RichTextLabel.new()
	_hint_label.bbcode_enabled = true
	_hint_label.fit_content = true
	_hint_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_hint_label.add_theme_font_size_override("normal_font_size", 14)
	_hint_label.add_theme_font_size_override("bold_font_size", 14)
	_hint_label.add_theme_font_size_override("italics_font_size", 14)
	hb.add_child(_hint_label)
	var close := UITheme.button("Got it", 0, 30)
	close.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	close.pressed.connect(func(): Audio.play("click"); hide_hint())
	hb.add_child(close)
	add_child(_hint)

	_comms = PanelContainer.new()
	_comms.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_comms.offset_top = 150
	_comms.custom_minimum_size = Vector2(640, 0)
	_comms.offset_left = -320
	_comms.offset_right = 320
	_comms.visible = false
	var cv := VBoxContainer.new()
	cv.add_theme_constant_override("separation", 6)
	_comms.add_child(cv)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 10)
	_comms_icon_slot = Control.new()
	_comms_icon_slot.custom_minimum_size = Vector2(40, 40)
	head.add_child(_comms_icon_slot)
	var names := VBoxContainer.new()
	names.add_theme_constant_override("separation", -3)
	names.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_comms_name = UITheme.label("", 16, UITheme.TEXT, UITheme.font_bold)
	_comms_title = UITheme.label("", 12, UITheme.TEXT_DIM)
	names.add_child(_comms_name)
	names.add_child(_comms_title)
	head.add_child(names)
	var cont := UITheme.button("Continue  ▸", 0, 32)
	cont.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	cont.pressed.connect(func():
		Audio.play("click")
		_comms.visible = false
		comms_dismissed.emit())
	head.add_child(cont)
	cv.add_child(head)
	_comms_text = RichTextLabel.new()
	_comms_text.bbcode_enabled = true
	_comms_text.fit_content = true
	_comms_text.add_theme_font_size_override("normal_font_size", 15)
	_comms_text.add_theme_font_size_override("bold_font_size", 15)
	_comms_text.add_theme_font_size_override("italics_font_size", 15)
	cv.add_child(_comms_text)
	add_child(_comms)

	_intercept = PanelContainer.new()
	_intercept.add_theme_stylebox_override("panel", UITheme.box(Color(0.09, 0.02, 0.07, 0.92), Color(1.0, 0.45, 0.75, 0.8), 1, 5, Vector4(14, 7, 14, 7)))
	_intercept.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_intercept.custom_minimum_size = Vector2(600, 0)
	_intercept.offset_left = -300
	_intercept.offset_right = 300
	_intercept.offset_top = -96
	_intercept.offset_bottom = -24
	_intercept.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_intercept.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_intercept.modulate.a = 0.0
	_intercept_label = RichTextLabel.new()
	_intercept_label.bbcode_enabled = true
	_intercept_label.fit_content = true
	_intercept_label.add_theme_font_size_override("normal_font_size", 14)
	_intercept_label.add_theme_font_size_override("bold_font_size", 13)
	_intercept_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_intercept.add_child(_intercept_label)
	add_child(_intercept)

	_wave_panel = PanelContainer.new()
	_wave_panel.add_theme_stylebox_override("panel", UITheme.box(Color(0.1, 0.03, 0.05, 0.95), Defs.ENEMY_COLOR, 2, 8, Vector4(26, 16, 26, 18)))
	_wave_panel.set_anchors_preset(Control.PRESET_CENTER)
	_wave_panel.custom_minimum_size = Vector2(560, 0)
	_wave_panel.offset_left = -280
	_wave_panel.offset_right = 280
	_wave_panel.offset_top = -170
	_wave_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	_wave_panel.visible = false
	_wave_panel.gui_input.connect(func(ev): if ev is InputEventMouseButton and ev.pressed: hide_wave_alert())
	_wave_box = VBoxContainer.new()
	_wave_box.add_theme_constant_override("separation", 8)
	_wave_panel.add_child(_wave_box)
	add_child(_wave_panel)

	_toast = PanelContainer.new()
	_toast.add_theme_stylebox_override("panel", UITheme.box(Color(0.12, 0.05, 0.06, 0.95), Defs.ENEMY_COLOR, 1, 6, Vector4(16, 8, 16, 8)))
	_toast.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_toast.offset_top = -120
	_toast.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toast.modulate.a = 0.0
	_toast_label = UITheme.label("", 16, UITheme.TEXT, UITheme.font_semibold)
	_toast.add_child(_toast_label)
	add_child(_toast)

	_tooltip = PanelContainer.new()
	_tooltip.add_theme_stylebox_override("panel", UITheme.box(Color(0.03, 0.07, 0.11, 0.95), Color(UITheme.ACCENT, 0.6), 1, 5, Vector4(10, 7, 10, 7)))
	_tooltip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tooltip.visible = false
	_tooltip_label = RichTextLabel.new()
	_tooltip_label.bbcode_enabled = true
	_tooltip_label.fit_content = true
	_tooltip_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	_tooltip_label.add_theme_font_size_override("normal_font_size", 13)
	_tooltip_label.add_theme_font_size_override("bold_font_size", 14)
	_tooltip_label.add_theme_font_size_override("italics_font_size", 13)
	_tooltip_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tooltip.add_child(_tooltip_label)
	add_child(_tooltip)


# --------------------------------------------------------------------------------------------
# Refresh
# --------------------------------------------------------------------------------------------

func refresh() -> void:
	if st == null:
		return
	_chips["supplies"][0].text = str(st.supplies)
	_chips["supplies"][1].text = "+%d / turn" % st.income()
	_chips["research"][0].text = str(st.rp)
	_chips["research"][1].text = "+%d / turn" % st.rp_income()
	_chips["turn"][0].text = "Turn %d" % st.turn
	_chips["turn"][1].text = "%s phase" % ("Enemy" if _busy else "Your")
	_chips["wave"][0].text = "Wave %d/%d" % [st.wave, st.waves_total]
	var cd := st.countdown()
	if st.wave >= st.waves_total:
		_chips["wave"][1].text = "final wave inbound" if not st.enemies.is_empty() else "all waves launched"
	elif cd <= 0:
		_chips["wave"][1].text = "next launches end of this turn"
		_chips["wave"][1].add_theme_color_override("font_color", Defs.ENEMY_COLOR)
	else:
		_chips["wave"][1].text = "next launches end of turn %d" % st.next_wave_turn
		_chips["wave"][1].add_theme_color_override("font_color", Defs.WARN if cd == 1 else UITheme.TEXT_DIM)
	_chips["resolve"][0].text = str(st.story.resolve)
	_chips["resolve"][1].text = "%s · income x%.2f" % [st.story.resolve_label(), st.story.resolve_mult()]
	_chips["resolve"][1].add_theme_color_override("font_color", Defs.BAD if st.story.resolve < 40 else UITheme.TEXT_DIM)
	_chips["ally"][0].text = str(st.story.ally)
	var ship := st.story.shipment_size()
	_chips["ally"][1].text = ("shipments +%d / wave" % ship) if ship > 0 else "no shipments"
	_chips["score"][0].text = str(st.score)
	_chips["score"][1].text = "%d carrier%s afloat" % [st.carriers.size(), "" if st.carriers.size() == 1 else "s"]
	for kind in _build_buttons:
		var b: Button = _build_buttons[kind]
		var locked := st.build_locked_reason(kind)
		var cost := st.build_cost(kind)
		var icon: IconRect = b.get_meta("icon")
		var cost_l: Label = b.get_meta("cost")
		b.disabled = locked != "" or _busy or st.result != ""
		icon.dimmed = locked != ""
		icon.queue_redraw()
		if locked != "":
			cost_l.text = "locked"
			cost_l.add_theme_color_override("font_color", UITheme.TEXT_DIM)
			cost_l.add_theme_font_size_override("font_size", 11)
		else:
			cost_l.text = str(cost)
			cost_l.add_theme_font_size_override("font_size", 14)
			cost_l.add_theme_color_override("font_color", Defs.GOLD if st.supplies >= cost else Defs.BAD)
		b.set_pressed_no_signal(_active_build == kind)
		b.tooltip_text = _structure_tooltip(kind, locked)
	_recon_btn.disabled = _busy or st.result != "" or st.recon_used_turn == st.turn or st.supplies < Defs.RECON_COST
	_ops_btn.disabled = _busy or st.result != ""
	var ready_ops := 0
	for op in Lore.OPS:
		if st.story.op_check(st, op) == "":
			ready_ops += 1
	var ops_cost: Label = _ops_btn.get_meta("cost")
	ops_cost.text = "%d ready" % ready_ops if ready_ops > 0 else ""
	ops_cost.add_theme_font_size_override("font_size", 11)
	var intel_cost: Label = _intel_btn.get_meta("cost")
	intel_cost.text = "%d new" % st.story.codex_unseen if st.story.codex_unseen > 0 else ""
	intel_cost.add_theme_font_size_override("font_size", 11)
	intel_cost.add_theme_color_override("font_color", Color(1.0, 0.55, 0.78))
	_set_ticker(st.story.news)
	_refresh_end_button()
	_refresh_intel()
	if _log_hold == 0:
		_render_log(st.messages.size())


func _structure_tooltip(kind: String, locked: String) -> String:
	var def: Dictionary = Defs.STRUCTURES[kind]
	var lines: Array = ["%s  (%d supplies)" % [def["name"], def["cost"]], def["desc"]]
	if def.has("weapon"):
		lines.append("Range %d  |  %d shot%s/phase  |  dmg %d low / %d high  |  %d%% accuracy" % [def["range"], def["shots"], "" if def["shots"] == 1 else "s", st.weapon_damage(def, "low"), st.weapon_damage(def, "high"), int(def["acc"] * 100)])
	lines.append("HP %d  |  Vision %d" % [def["hp"], def["vision"]])
	if locked != "":
		lines.append("LOCKED: " + locked)
	return "\n".join(lines)


func _refresh_end_button() -> void:
	if _busy:
		_end_btn.text = "SKIP  ▸▸"
		_end_btn.add_theme_stylebox_override("normal", UITheme.box(Color(0.3, 0.08, 0.1, 0.97), Defs.ENEMY_COLOR, 2, 7))
		_end_btn.add_theme_stylebox_override("hover", UITheme.box(Color(0.4, 0.1, 0.13, 1.0), Color.WHITE, 2, 7))
		_end_sub.text = "Enemy phase in progress  ·  SPACE to skip animations"
	elif st.story.pending != "" and st.result == "":
		_end_btn.text = "DIRECTIVE  ▸"
		_end_btn.add_theme_stylebox_override("normal", UITheme.box(Color(0.3, 0.22, 0.06, 0.97), Defs.GOLD, 2, 7))
		_end_btn.add_theme_stylebox_override("hover", UITheme.box(Color(0.4, 0.3, 0.08, 1.0), Color.WHITE, 2, 7))
		_end_sub.text = "A decision awaits before you can end the turn"
	elif st.result != "":
		_end_btn.text = "VICTORY  ·  SUMMARY" if st.result == "victory" else "DEFEAT  ·  SUMMARY"
		_end_btn.add_theme_stylebox_override("normal", UITheme.box(Color(0.1, 0.36, 0.38, 0.97), UITheme.ACCENT, 2, 7))
		_end_btn.add_theme_stylebox_override("hover", UITheme.box(Color(0.14, 0.46, 0.47, 1.0), Color.WHITE, 2, 7))
		_end_sub.text = "The campaign is over  ·  SPACE to view the summary"
	else:
		_end_btn.text = "END TURN  ▸"
		_end_btn.add_theme_stylebox_override("normal", UITheme.box(Color(0.1, 0.36, 0.38, 0.97), UITheme.ACCENT, 2, 7))
		_end_btn.add_theme_stylebox_override("hover", UITheme.box(Color(0.14, 0.46, 0.47, 1.0), Color.WHITE, 2, 7))
		var cd := st.countdown()
		if st.wave < st.waves_total and cd <= 0:
			_end_sub.text = "Wave %d launches when you end this turn  ·  SPACE" % (st.wave + 1)
		else:
			_end_sub.text = "Turn %d  ·  press SPACE to end turn" % st.turn


func _refresh_intel() -> void:
	var lines: Array = []
	var r: Dictionary = st.last_wave_report
	var spotted := 0
	for e in st.enemies.values():
		if st.enemy_detected(e):
			spotted += 1
	lines.append("[b][color=#ff8a8a]ENEMY INTEL[/color][/b]   [color=#9fb0c2]%d aircraft airborne, %d spotted[/color]" % [st.enemies.size(), spotted])
	if not r.is_empty():
		var sector: String = r["sector"] if r["sector"] != "" else "unknown vector"
		lines.append("[color=#c8d3de]Wave %d: %d aircraft, %s.[/color]" % [r["wave"], r["count"], sector])
		if not r["composition"].is_empty():
			var parts: Array = []
			for k in r["composition"]:
				parts.append("%d %s" % [r["composition"][k], Defs.enemy_name(k)])
			lines.append("[color=#9fb0c2]%s[/color]" % ", ".join(parts))
		lines.append("[color=#8cb8ff][i]%s[/i][/color]" % r["doctrine"])
	else:
		lines.append("[color=#9fb0c2]No enemy aircraft launched yet. The first wave launches at the end of turn %d.[/color]" % st.next_wave_turn)
	_intel_label.text = "\n".join(lines)


func set_busy(v: bool) -> void:
	_busy = v
	refresh()


func set_active_build(kind: String) -> void:
	_active_build = kind
	for k in _build_buttons:
		_build_buttons[k].set_pressed_no_signal(k == kind)


func set_coverage(on: bool) -> void:
	_cov_btn.set_pressed_no_signal(on)


# --------------------------------------------------------------------------------------------
# Log
# --------------------------------------------------------------------------------------------

func log_hold(pending: int) -> void:
	_log_hold = pending
	_render_log(st.messages.size() - pending)


func log_advance() -> void:
	if _log_hold > 0:
		_log_hold -= 1
	_render_log(st.messages.size() - _log_hold)


func log_release() -> void:
	_log_hold = 0
	_render_log(st.messages.size())


func _render_log(upto: int) -> void:
	var lines: Array = []
	var start := maxi(0, upto - 40)
	for i in range(start, clampi(upto, 0, st.messages.size())):
		var m: Dictionary = st.messages[i]
		var col := UITheme.kind_color(m["kind"]).to_html(false)
		lines.append("[color=#5d7085]T%d[/color]  [color=#%s]%s[/color]" % [m["turn"], col, m["text"]])
	_log.text = "\n".join(lines)


# --------------------------------------------------------------------------------------------
# Selection info panel
# --------------------------------------------------------------------------------------------

func _info_clear() -> void:
	for c in _info_box.get_children():
		c.queue_free()


func _info_title(text: String, sub: String = "", icon: IconRect = null) -> void:
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 10)
	if icon != null:
		hb.add_child(icon)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", -2)
	vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var t := UITheme.label(text, 19, UITheme.TEXT, UITheme.font_bold)
	t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vb.add_child(t)
	if sub != "":
		var sl := UITheme.label(sub, 12, UITheme.TEXT_DIM)
		sl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		sl.custom_minimum_size = Vector2(200, 0)
		vb.add_child(sl)
	hb.add_child(vb)
	_info_box.add_child(hb)


func _info_hp(hp: int, max_hp: int, col: Color) -> void:
	var bar := ProgressBar.new()
	bar.max_value = max_hp
	bar.value = hp
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(0, 16)
	bar.add_theme_stylebox_override("fill", UITheme.box(col, Color(0, 0, 0, 0), 0, 3))
	var l := UITheme.label("HP %d / %d" % [hp, max_hp], 11, Color.WHITE, UITheme.font_semibold)
	l.set_anchors_preset(Control.PRESET_FULL_RECT)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	bar.add_child(l)
	_info_box.add_child(bar)


func _info_stats(rows: Array) -> void:
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 1)
	for r in rows:
		grid.add_child(UITheme.label(r[0], 13, UITheme.TEXT_DIM))
		var v := UITheme.label(str(r[1]), 13, UITheme.TEXT, UITheme.font_semibold)
		grid.add_child(v)
	_info_box.add_child(grid)


func _info_text(bb: String, size: int = 13) -> void:
	var r := RichTextLabel.new()
	r.bbcode_enabled = true
	r.fit_content = true
	r.scroll_active = false
	r.add_theme_font_size_override("normal_font_size", size)
	r.add_theme_font_size_override("bold_font_size", size)
	r.add_theme_font_size_override("italics_font_size", size)
	r.text = bb
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_info_box.add_child(r)


func _info_action(text: String, reason: String, action: String, id: int, tip: String = "") -> void:
	var b := UITheme.button(text, 0, 36)
	b.disabled = reason != "" or _busy or st.result != ""
	b.tooltip_text = reason if reason != "" else tip
	b.pressed.connect(func():
		Audio.play("click")
		action_pressed.emit(action, id))
	_info_box.add_child(b)


func _sep() -> void:
	_info_box.add_child(HSeparator.new())


func show_selection(h: Vector2i) -> void:
	_info_clear()
	if st == null:
		return
	if h == Hex.INVALID or not st.tiles.has(h):
		_info_title("No selection", "Click a hex for details")
		_info_text("[color=#9fb0c2]Choose a structure in the [b]CONSTRUCT[/b] panel and click a hex to build it. Select your units and facilities to give orders.\n\n[b]Controls[/b]\nLeft click: select / build / order\nShift+click: keep building\nRight click or Esc: cancel\nWASD / arrows / right-drag: pan\nMouse wheel or Q/E: zoom\n1-0: quick build, R: research\nV: coverage, Tab: next unit\nI: Intel Archive, O: Cyber Ops\nSpace: end turn / skip[/color]")
		return
	if not st.explored.has(h):
		_info_title("Uncharted waters", "Unexplored")
		_info_text("[color=#9fb0c2]Extend your vision with Radar Stations, frigates or a Recon Flight.[/color]")
		return
	var u := st.unit_at(h)
	if not u.is_empty():
		_show_unit(u)
		_sep()
	var s := st.structure_at(h)
	if not s.is_empty():
		_show_structure(s)
		_sep()
	var es := st.visible_enemies_at(h)
	for e in es:
		_show_enemy(e)
		_sep()
	var c := st.carrier_at(h)
	if not c.is_empty() and st.carrier_visible(c):
		_show_carrier(c)
		_sep()
	var t: String = st.terrain(h)
	var tdef: Dictionary = Defs.TERRAIN[t]
	var o := Hex.axial_to_offset(h)
	var vis := "In sight" if st.visible_hexes.has(h) else "Out of sight"
	if st.radar_cov.has(h):
		vis += " · radar coverage"
	if s.is_empty() and u.is_empty() and es.is_empty():
		_info_title(tdef["name"], "Hex %d,%d · %s" % [o.x, o.y, vis])
	else:
		_info_box.add_child(UITheme.label("%s  ·  %s" % [tdef["name"], vis], 13, UITheme.ACCENT, UITheme.font_semibold))
	_info_text("[color=#9fb0c2]%s[/color]" % tdef["desc"])
	if st.ruins.has(h) and s.is_empty():
		_info_text("[color=#c99]Ruins of a destroyed %s.[/color]" % Defs.structure_name(st.ruins[h]).to_lower())


func _show_structure(s: Dictionary) -> void:
	var def: Dictionary = Defs.STRUCTURES[s["kind"]]
	var title: String = def["name"]
	var sub := ""
	if s["kind"] == "capital" or s["kind"] == "city":
		title = s["name"]
		sub = def["name"]
		if s.get("foundry", false):
			sub = "Foundry City · TLW Fab 18"
	elif s["kind"] == "decoy":
		sub = "Enemy believes this is a Research Lab"
	var known: bool = st.ai.known.has(s["id"])
	sub += ("  ·  " if sub != "" else "") + ("[spotted by enemy]" if known else "[unknown to enemy]")
	_info_title(title, sub, IconRect.new(s["kind"], "structure", 44, 1.15))
	_info_hp(s["hp"], s["max_hp"], Defs.GOOD)
	var rows: Array = []
	if def.has("weapon"):
		rows.append(["Range", "%d hex%s%s" % [st.s_range(s), "" if st.s_range(s) == 1 else "es", " (hills +1)" if st.terrain(s["pos"]) == "hills" else ""]])
		rows.append(["Shots / enemy phase", st.s_shots(s)])
		rows.append(["Damage (low / high alt)", "%d / %d" % [st.weapon_damage(def, "low"), st.weapon_damage(def, "high")]])
		rows.append(["Accuracy", "%d%%" % int(def["acc"] * 100)])
	rows.append(["Vision", st.s_vision(s)])
	if def.has("income"):
		var extra := st.story.foundry_income(st) if s.get("foundry", false) else 0
		rows.append(["Supplies", "+%d / turn" % (int(def["income"]) + extra)])
	if def.has("rp") or s.get("foundry", false):
		var extra_rp := st.story.foundry_rp(st) if s.get("foundry", false) else 0
		rows.append(["Research", "+%d / turn" % (int(def.get("rp", 0)) + extra_rp)])
	if s.get("foundry", false):
		rows.append(["Glass Shield", "INTACT" if st.story.glass == "intact" else "CRACKED"])
	if s["kills"] > 0:
		rows.append(["Aircraft downed", s["kills"]])
	_info_stats(rows)
	_info_text("[color=#9fb0c2]%s[/color]" % def["desc"], 12)
	if s.get("foundry", false):
		if st.story.glass == "intact":
			_info_text("[color=#ffd166]The Glass Shield holds: Commonwealth planners keep Silica Point off their target lists, because they need Fab 18 too.[/color]", 12)
		else:
			_info_text("[color=#ff6b6b]The Glass Shield has cracked. Silica Point is now a prime target. Defend it.[/color]", 12)
	var targeted_by: Array = []
	for e in st.enemies.values():
		if st.enemy_detected(e) and e["target"].get("type", "") == "structure" and e["target"].get("id", -1) == s["id"]:
			targeted_by.append(Defs.enemy_name(e["kind"]))
	if not targeted_by.is_empty():
		_info_text("[color=#ff8a8a][b]Targeted by:[/b] %s[/color]" % ", ".join(targeted_by))
	if s["hp"] < s["max_hp"]:
		_info_action("Repair  (+%d HP for %d)" % [st.repair_amount(s), st.repair_cost(s)], st.repair_check(s["id"]), "repair", s["id"])
	match s["kind"]:
		"airbase":
			var n := st.units_from(s["id"])
			_info_action("Train Interceptor  (%d)  [%d/2]" % [Defs.UNITS["interceptor"]["cost"], n], st.produce_check(s["id"], "interceptor"), "train", s["id"], Defs.UNITS["interceptor"]["desc"])
			_info_action("Air Strike on Carrier  (%d)" % Defs.AIR_STRIKE_COST, st.strike_check(s["id"]), "strike", s["id"], "Launch a strike package at a spotted carrier within %d hexes." % Defs.AIR_STRIKE_RANGE)
		"harbor":
			var n2 := st.units_from(s["id"])
			_info_action("Commission Corvette  (%d)  [%d/2]" % [Defs.UNITS["frigate"]["cost"], n2], st.produce_check(s["id"], "frigate"), "frigate", s["id"], Defs.UNITS["frigate"]["desc"])
		"missile":
			_info_action("Launch Cruise Missile  (%d)" % Defs.MISSILE_COST, st.strike_check(s["id"]), "strike", s["id"], "Fire at a spotted carrier within %d hexes." % Defs.MISSILE_RANGE)
	if def.get("build", false):
		_info_action("Demolish  (+%d)" % st.demolish_refund(s), "", "demolish", s["id"], "Remove this structure and recover part of its cost.")


func _show_unit(u: Dictionary) -> void:
	var def: Dictionary = Defs.UNITS[u["kind"]]
	var status := "Ready"
	if u["kind"] == "interceptor":
		if u["attacked"]:
			status = "Engaged this turn"
		elif u["moved"]:
			status = "Moved · on patrol"
		else:
			status = "Ready · on patrol"
	elif u["moved"]:
		status = "Moved"
	_info_title(def["name"], status, IconRect.new(u["kind"], "unit", 44, 1.4))
	_info_hp(u["hp"], u["max_hp"], Defs.PLAYER_COLOR)
	var rows: Array = [["Move", "%d hexes" % st.u_move(u)], ["Vision", st.u_vision(u)]]
	if u["kind"] == "interceptor":
		rows.append(["Cannon damage", st.u_dmg(u)])
		rows.append(["Patrol radius", "2 hexes"])
	else:
		rows.append(["AA range", st.u_range(u)])
		rows.append(["Shots / enemy phase", st.u_shots(u)])
	_info_stats(rows)
	if u["kind"] == "interceptor":
		_info_text("[color=#9fb0c2]Click a [color=#4fd1c5]highlighted hex[/color] to move, or a [color=#ff6b6b]ringed enemy[/color] to attack. Squadrons that hold fire engage the first enemy within 2 hexes during the enemy phase. Heals at an Airbase.[/color]", 12)
	else:
		_info_text("[color=#9fb0c2]Click a [color=#4fd1c5]highlighted hex[/color] to sail. Fires automatically during the enemy phase. Repairs next to a Harbor.[/color]", 12)


func _show_enemy(e: Dictionary) -> void:
	var def: Dictionary = Defs.ENEMIES[e["kind"]]
	var sub := "%s altitude" % ("High" if def["alt"] == "high" else "Low")
	if e["state"] == "rtb":
		sub += " · returning to base"
	_info_title(def["name"], sub, IconRect.new(e["kind"], "aircraft", 44, 1.3))
	_info_hp(e["hp"], e["max_hp"], Defs.ENEMY_COLOR)
	var tgt := "—"
	var t: Dictionary = e["target"]
	match t.get("type", ""):
		"structure":
			var s: Dictionary = st.structures.get(t["id"], {})
			if not s.is_empty():
				tgt = s["name"] if s["name"] != "" else Defs.structure_name(s["kind"])
		"unit":
			tgt = "your %s" % Defs.unit_name(st.units[t["id"]]["kind"]).to_lower() if st.units.has(t["id"]) else "your units"
		"escort":
			tgt = "escorting bombers"
		"scout":
			tgt = "scouting your islands"
		"exit":
			tgt = "leaving the area"
	_info_stats([["Speed", "%d hexes / turn" % def["speed"]], ["Payload", def["dmg"] if def["dmg"] > 0 else "none"], ["Intent", tgt]])
	_info_text("[color=#9fb0c2]%s[/color]" % def["desc"], 12)


func _show_carrier(c: Dictionary) -> void:
	_info_title(c.get("name", Defs.CARRIER["name"]), Defs.CARRIER["name"], IconRect.new("carrier", "carrier", 52, 1.0))
	_info_hp(c["hp"], c["max_hp"], Defs.ENEMY_COLOR)
	_info_text("[color=#9fb0c2]%s Repairs 3 HP per turn.[/color]" % Defs.CARRIER["desc"], 12)


# --------------------------------------------------------------------------------------------
# Transient UI
# --------------------------------------------------------------------------------------------

func banner(text: String, col: Color = UITheme.ACCENT, hold: float = 1.1) -> void:
	_banner_label.text = text
	_banner_label.add_theme_color_override("font_color", col)
	_banner.add_theme_stylebox_override("panel", UITheme.box(Color(0.03, 0.06, 0.1, 0.9), col, 1, 6, Vector4(28, 8, 28, 8)))
	_banner.reset_size()
	_banner.offset_left = -_banner.size.x * 0.5
	_banner.offset_right = _banner.size.x * 0.5
	if _banner_tween:
		_banner_tween.kill()
	_banner_tween = create_tween()
	_banner_tween.tween_property(_banner, "modulate:a", 1.0, 0.18)
	_banner_tween.tween_interval(hold)
	_banner_tween.tween_property(_banner, "modulate:a", 0.0, 0.4)


func toast(text: String) -> void:
	_toast_label.text = text
	_toast.reset_size()
	_toast.offset_left = -_toast.size.x * 0.5
	_toast.offset_right = _toast.size.x * 0.5
	if _toast_tween:
		_toast_tween.kill()
	_toast_tween = create_tween()
	_toast.modulate.a = 1.0
	_toast_tween.tween_interval(1.6)
	_toast_tween.tween_property(_toast, "modulate:a", 0.0, 0.4)


func wave_alert(r: Dictionary, auto_hide: float = 4.0) -> void:
	for c in _wave_box.get_children():
		c.queue_free()
	if r.has("act"):
		var at := UITheme.label(Lore.ACTS[int(r["act"])]["title"], 12, Defs.GOLD, UITheme.font_semibold)
		at.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_wave_box.add_child(at)
	var t := UITheme.label("WAVE %d / %d INBOUND" % [r["wave"], r["total"]], 30, Defs.ENEMY_COLOR, UITheme.font_bold)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_wave_box.add_child(t)
	var sector: String = ("Approach vector: %s" % r["sector"]) if r["sector"] != "" else "Approach vector unknown. Extend radar coverage or research Coastwatchers."
	var s := UITheme.label("%d aircraft  ·  %s" % [r["count"], sector], 15, UITheme.TEXT, UITheme.font_semibold)
	s.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	s.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_wave_box.add_child(s)
	if not r["composition"].is_empty():
		var hb := HBoxContainer.new()
		hb.alignment = BoxContainer.ALIGNMENT_CENTER
		hb.add_theme_constant_override("separation", 14)
		for k in r["composition"]:
			var item := HBoxContainer.new()
			item.add_child(IconRect.new(k, "aircraft", 30, 0.9))
			item.add_child(UITheme.label("x%d" % r["composition"][k], 15, UITheme.TEXT, UITheme.font_bold))
			item.tooltip_text = Defs.enemy_name(k)
			hb.add_child(item)
		_wave_box.add_child(hb)
	var d := RichTextLabel.new()
	d.bbcode_enabled = true
	d.fit_content = true
	d.add_theme_font_size_override("normal_font_size", 14)
	d.add_theme_font_size_override("italics_font_size", 14)
	var brief: String = ("[color=#e6edf3]Capt. Ardent: “%s”[/color]\n" % r["briefing"]) if r.has("briefing") else ""
	d.text = "[center]%s[color=#8cb8ff][i]HQ Intelligence: %s[/i][/color][/center]" % [brief, r["doctrine"]]
	d.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_wave_box.add_child(d)
	var hint := UITheme.label("click to dismiss", 11, UITheme.TEXT_DIM)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_wave_box.add_child(hint)
	_wave_panel.visible = true
	_wave_panel.modulate.a = 0.0
	_wave_panel.scale = Vector2(0.9, 0.9)
	_wave_panel.pivot_offset = Vector2(280, 80)
	if _wave_tween:
		_wave_tween.kill()
	_wave_tween = create_tween()
	_wave_tween.set_parallel(true)
	_wave_tween.tween_property(_wave_panel, "modulate:a", 1.0, 0.2)
	_wave_tween.tween_property(_wave_panel, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_wave_tween.chain().tween_interval(auto_hide)
	_wave_tween.chain().tween_property(_wave_panel, "modulate:a", 0.0, 0.5)
	_wave_tween.chain().tween_callback(func(): _wave_panel.visible = false)


func hide_wave_alert() -> void:
	if _wave_tween:
		_wave_tween.kill()
	_wave_panel.visible = false


func show_hint(bb: String) -> void:
	_hint_label.text = bb
	_hint.visible = true
	_hint.modulate.a = 0.0
	create_tween().tween_property(_hint, "modulate:a", 1.0, 0.3)


func hide_hint() -> void:
	_hint.visible = false


func hint_visible() -> bool:
	return _hint.visible


func set_tooltip(bb: String) -> void:
	if bb == "":
		_tooltip.visible = false
		return
	_tooltip_label.text = bb
	_tooltip.visible = true
	_tooltip.reset_size()
	_place_tooltip()


func _place_tooltip() -> void:
	var m := get_local_mouse_position()
	var p := m + Vector2(18, 18)
	var sz := _tooltip.size
	if p.x + sz.x > size.x - 8:
		p.x = m.x - sz.x - 12
	if p.y + sz.y > size.y - 8:
		p.y = m.y - sz.y - 12
	_tooltip.position = p


func _process(delta: float) -> void:
	if _tooltip.visible:
		_place_tooltip()
	if _ticker_label != null and _ticker_text != "":
		_ticker_label.position.x -= 70.0 * delta
		if _ticker_label.position.x < -_ticker_label.size.x:
			_ticker_label.position.x = _ticker_clip.size.x


## True if the mouse is over an interactive HUD element.
func mouse_over_ui() -> bool:
	var hovered := get_viewport().gui_get_hovered_control()
	return hovered != null and hovered != self


# --------------------------------------------------------------------------------------------
# Story widgets
# --------------------------------------------------------------------------------------------

func _set_ticker(items: Array) -> void:
	var text := "     ◆     ".join(items)
	if text == _ticker_text:
		return
	_ticker_text = text
	_ticker_label.text = text
	_ticker_label.reset_size()
	_ticker_label.position.x = _ticker_clip.size.x if _ticker_clip.size.x > 0 else 1400.0


func show_comms(beat: Dictionary) -> void:
	var p: Dictionary = Lore.person(beat["speaker"])
	var f: Dictionary = Lore.FACTIONS.get(p["faction"], Lore.FACTIONS["tessera"])
	for c in _comms_icon_slot.get_children():
		c.queue_free()
	_comms_icon_slot.add_child(UITheme.person_emblem(beat["speaker"], 40))
	_comms_name.text = beat.get("title", p["name"]) if beat.get("act", false) else p["name"]
	_comms_name.add_theme_color_override("font_color", Defs.GOLD if beat.get("act", false) else UITheme.TEXT)
	_comms_title.text = ("%s · %s" % [p["name"], p["title"]]) if beat.get("act", false) else p["title"]
	_comms_text.text = beat["text"]
	_comms.add_theme_stylebox_override("panel", UITheme.box(Color(0.03, 0.07, 0.11, 0.96), Color(f["color"], 0.85), 1, 7, Vector4(16, 12, 16, 14)))
	_comms.visible = true
	_comms.modulate.a = 0.0
	create_tween().tween_property(_comms, "modulate:a", 1.0, 0.25)
	hide_hint()


func comms_visible() -> bool:
	return _comms.visible


func show_intercept(speaker: String, text: String, hold: float = 3.2) -> void:
	_intercept_label.text = "[color=#ff8fc7][b]INTERCEPT · %s[/b][/color]\n[color=#f3dce9]“%s”[/color]" % [speaker, text]
	if _intercept_tween:
		_intercept_tween.kill()
	_intercept_tween = create_tween()
	_intercept_tween.tween_property(_intercept, "modulate:a", 1.0, 0.2)
	_intercept_tween.tween_interval(hold)
	_intercept_tween.tween_property(_intercept, "modulate:a", 0.0, 0.5)
