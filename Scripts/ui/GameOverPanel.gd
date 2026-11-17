class_name GameOverPanel
extends Modal
## Victory / defeat summary.

signal new_game
signal main_menu
signal keep_viewing


func _init(st: GameState, rank: int) -> void:
	super(Vector2(600, 0))
	dismiss_on_backdrop = false
	var win := st.result == "victory"
	panel.add_theme_stylebox_override("panel", UITheme.box(Color(0.04, 0.08, 0.12, 0.98), UITheme.ACCENT if win else Defs.ENEMY_COLOR, 2, 8, Vector4(30, 22, 30, 24)))
	var t := UITheme.label("VICTORY" if win else "DEFEAT", 48, Defs.GOLD if win else Defs.ENEMY_COLOR, UITheme.font_bold)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(t)
	var reason := UITheme.label(st.result_reason, 16, UITheme.TEXT)
	reason.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	reason.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(reason)
	content.add_child(HSeparator.new())
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 26)
	grid.add_theme_constant_override("v_separation", 6)
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
		["Structures lost", s["structures_lost"]], ["Squadrons lost", s["units_lost"]],
		["Defense accuracy", "%d%%" % acc], ["Technologies", s["techs"]],
	]
	for r in rows:
		grid.add_child(UITheme.label(r[0], 14, UITheme.TEXT_DIM))
		grid.add_child(UITheme.label(str(r[1]), 14, UITheme.TEXT, UITheme.font_semibold))
	var cc := CenterContainer.new()
	cc.add_child(grid)
	content.add_child(cc)
	content.add_child(HSeparator.new())
	var sc := UITheme.label("SCORE  %d" % st.score, 32, Defs.GOLD, UITheme.font_bold)
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
	var view := UITheme.button("View Map", 150, 44)
	view.pressed.connect(func(): Audio.play("click"); keep_viewing.emit(); close())
	var again := UITheme.button("New Campaign", 180, 44)
	again.pressed.connect(func(): Audio.play("click"); new_game.emit())
	var menu := UITheme.button("Main Menu", 150, 44)
	menu.pressed.connect(func(): Audio.play("click"); main_menu.emit())
	row.add_child(view)
	row.add_child(again)
	row.add_child(menu)
	content.add_child(row)


func _unhandled_key_input(_event: InputEvent) -> void:
	pass
