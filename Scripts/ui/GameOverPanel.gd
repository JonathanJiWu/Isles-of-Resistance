class_name GameOverPanel
extends Modal
## Victory / defeat summary with the campaign's epilogue.

signal new_game
signal main_menu
signal keep_viewing


func _init(st: GameState, rank: int) -> void:
	super(Vector2(820, 0))
	dismiss_on_backdrop = false
	var win := st.result == "victory"
	var ending: Dictionary = st.story.ending(st)
	panel.add_theme_stylebox_override("panel", UITheme.box(Color(0.04, 0.08, 0.12, 0.98), UITheme.ACCENT if win else Defs.ENEMY_COLOR, 2, 8, Vector4(30, 20, 30, 22)))
	var t := UITheme.label("VICTORY" if win else "DEFEAT", 40, Defs.GOLD if win else Defs.ENEMY_COLOR, UITheme.font_bold)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(t)
	var et := UITheme.label(ending["title"].to_upper(), 20, UITheme.TEXT, UITheme.font_bold)
	et.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(et)
	var reason := UITheme.label(st.result_reason, 14, UITheme.TEXT_DIM)
	reason.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	reason.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(reason)

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(760, 300)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	content.add_child(scroll)
	var story := RichTextLabel.new()
	story.bbcode_enabled = true
	story.fit_content = true
	story.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	story.add_theme_font_size_override("normal_font_size", 15)
	story.add_theme_font_size_override("bold_font_size", 15)
	story.add_theme_font_size_override("italics_font_size", 15)
	var parts: Array = [ending["text"]]
	if not ending["lines"].is_empty():
		parts.append("[color=#c8d3de]" + " ".join(ending["lines"]) + "[/color]")
	var outlets: Array = []
	for o in ending["outlets"]:
		outlets.append("[color=#ff8fc7]◆[/color] [i]%s[/i]" % o)
	parts.append("[color=#ffd166][b]THE NEXT MORNING'S HEADLINES[/b][/color]\n" + "\n".join(outlets))
	var codas: Array = []
	for c in ending["codas"]:
		codas.append("[color=#4fd1c5][b]%s.[/b][/color] %s" % [Lore.person(c["speaker"])["name"], c["text"]])
	parts.append("[color=#ffd166][b]AFTERWARDS[/b][/color]\n" + "\n\n".join(codas))
	story.text = "\n\n".join(parts)
	scroll.add_child(story)
	content.add_child(HSeparator.new())

	var grid := GridContainer.new()
	grid.columns = 6
	grid.add_theme_constant_override("h_separation", 20)
	grid.add_theme_constant_override("v_separation", 4)
	var s: Dictionary = st.stats
	var cities_alive := 0
	for x in st.structures.values():
		if x["kind"] == "city":
			cities_alive += 1
	var acc := 0
	if s["shots"] > 0:
		acc = int(round(100.0 * s["hits"] / s["shots"]))
	var rows := [
		["Difficulty", Defs.DIFFICULTY[st.difficulty]["name"]], ["Turns", st.turn],
		["Waves", "%d / %d" % [st.wave, st.waves_total]], ["Aircraft downed", s["kills_total"]],
		["Carriers sunk", s["carriers_sunk"]], ["Cities standing", cities_alive],
		["Resolve", st.story.resolve], ["Commitment", st.story.ally],
		["Accuracy", "%d%%" % acc], ["Technologies", s["techs"]],
		["Structures lost", s["structures_lost"]], ["Squadrons lost", s["units_lost"]],
	]
	for r in rows:
		grid.add_child(UITheme.label(r[0], 13, UITheme.TEXT_DIM))
		grid.add_child(UITheme.label(str(r[1]), 13, UITheme.TEXT, UITheme.font_semibold))
	var cc := CenterContainer.new()
	cc.add_child(grid)
	content.add_child(cc)
	var sc := UITheme.label("SCORE  %d" % st.score, 28, Defs.GOLD, UITheme.font_bold)
	sc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(sc)
	if s.get("final_bonus", 0) > 0:
		var fb := UITheme.label("includes victory bonus +%d" % s["final_bonus"], 12, UITheme.TEXT_DIM)
		fb.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		content.add_child(fb)
	if rank >= 0:
		var hs := UITheme.label("NEW HIGH SCORE  ·  #%d" % (rank + 1) if rank == 0 else "Hall of fame  ·  #%d" % (rank + 1), 16, UITheme.ACCENT, UITheme.font_bold)
		hs.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		content.add_child(hs)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 12)
	var view := UITheme.button("View Map", 150, 42)
	view.pressed.connect(func(): Audio.play("click"); keep_viewing.emit(); close())
	var again := UITheme.button("New Campaign", 180, 42)
	again.pressed.connect(func(): Audio.play("click"); new_game.emit())
	var menu := UITheme.button("Main Menu", 150, 42)
	menu.pressed.connect(func(): Audio.play("click"); main_menu.emit())
	row.add_child(view)
	row.add_child(again)
	row.add_child(menu)
	content.add_child(row)


func _unhandled_key_input(_event: InputEvent) -> void:
	pass
