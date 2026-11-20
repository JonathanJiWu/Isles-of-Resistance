class_name DirectivePanel
extends Modal
## A political decision with concrete consequences: a scheduled directive from the Cabinet, or a
## situation that has blown up on the ground (Situations.gd).

signal chosen(idx: int)


func _init(st: GameState) -> void:
	super(Vector2(780, 0))
	var d: Dictionary = st.story.pending_data()
	var situation := st.story.pending_is_situation()
	var p: Dictionary = Lore.person(d["speaker"])
	var f: Dictionary = Lore.FACTIONS.get(p["faction"], Lore.FACTIONS["tessera"])
	panel.add_theme_stylebox_override("panel", UITheme.box(Color(0.04, 0.07, 0.11, 0.98), f["color"], 2, 8, Vector4(26, 20, 26, 20)))
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 14)
	head.add_child(UITheme.person_emblem(d["speaker"], 56))
	var hv := VBoxContainer.new()
	hv.add_theme_constant_override("separation", -2)
	if situation:
		var ed: Dictionary = Defs.ESCALATION[st.escalation()]
		hv.add_child(UITheme.label("SITUATION · %s · intel confidence %s" % [String(ed["name"]).to_upper(), GameState.confidence_label(st.intel_confidence()).to_lower()], 12, ed["color"], UITheme.font_semibold))
	else:
		hv.add_child(UITheme.label("DIRECTIVE · %s" % Lore.ACTS[maxi(st.story.act, 0)]["title"], 12, Defs.GOLD, UITheme.font_semibold))
	hv.add_child(UITheme.label(d["title"], 26, UITheme.TEXT, UITheme.font_bold))
	hv.add_child(UITheme.label("%s · %s" % [p["name"], p["title"]], 13, f["color"]))
	head.add_child(hv)
	content.add_child(head)
	var body := RichTextLabel.new()
	body.bbcode_enabled = true
	body.fit_content = true
	body.custom_minimum_size = Vector2(720, 0)
	body.add_theme_font_size_override("normal_font_size", 15)
	body.text = st.story.fill_text(d["text"]) if situation else d["text"]
	content.add_child(body)
	content.add_child(HSeparator.new())
	var opts: Array = d["options"]
	for i in opts.size():
		content.add_child(_option(st, i, opts[i]))
	var foot := UITheme.label("Esc to decide later. You must decide before ending the turn.%s" % ("  Escalation changes move the pressure toward the next rung of the ladder." if situation else ""), 12, UITheme.TEXT_DIM)
	foot.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(foot)


func _option(st: GameState, idx: int, opt: Dictionary) -> Control:
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", UITheme.box(Color(0.06, 0.1, 0.15, 0.95), UITheme.BORDER, 1, 6, Vector4(14, 10, 12, 10)))
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 12)
	card.add_child(hb)
	var vb := VBoxContainer.new()
	vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vb.add_theme_constant_override("separation", 2)
	vb.add_child(UITheme.label(opt["label"], 17, UITheme.TEXT, UITheme.font_bold))
	var fx := RichTextLabel.new()
	fx.bbcode_enabled = true
	fx.fit_content = true
	fx.add_theme_font_size_override("normal_font_size", 13)
	var parts: Array = []
	for line in Campaign.effect_lines(opt["effects"]):
		parts.append("[color=#%s]%s[/color]" % [_tone(line).to_html(false), line])
	fx.text = "  ·  ".join(parts)
	vb.add_child(fx)
	var note := UITheme.label(st.story.fill_text(opt.get("note", "")), 12, UITheme.TEXT_DIM)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.custom_minimum_size = Vector2(560, 0)
	vb.add_child(note)
	hb.add_child(vb)
	var reason := st.story.option_check(st, opt["effects"], opt)
	var b := UITheme.button("Choose", 104, 40)
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	b.disabled = reason != ""
	b.tooltip_text = reason
	b.pressed.connect(func():
		Audio.play("research")
		chosen.emit(idx)
		close())
	hb.add_child(b)
	return card


static func _tone(line: String) -> Color:
	var bad_markers := ["Glass Shield cracks", "Enemy learns", "No carrier strikes", "Foundry output", "Escalation +",
		"Rolling blackouts", "sites damaged", "No repairs"]
	for m in bad_markers:
		if line.contains(m):
			return Defs.BAD
	for m in ["Comms back in", "New objective"]:
		if line.contains(m):
			return Defs.WARN
	if line.to_lower().contains("wave"):
		return Defs.BAD if line.contains("+") else Defs.GOOD
	if line.contains("chance"):
		return Defs.WARN
	if line.begins_with("-"):
		return Defs.BAD
	return Defs.GOOD
