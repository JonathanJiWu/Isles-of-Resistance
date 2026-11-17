extends SceneTree
## Drives the real game (rendered, e.g. under Xvfb) and captures screenshots of key screens.
##   godot --path . --resolution 1600x900 -s tests/screenshots.gd -- <out_dir>

var out_dir := "user://shots"


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	if not args.is_empty():
		out_dir = args[0]
	DirAccess.make_dir_recursive_absolute(out_dir)
	await process_frame
	var Settings = root.get_node("/root/Settings")
	var Session = root.get_node("/root/Session")
	Settings.tutorial_hints = true
	Settings.anim_speed = 1.5
	Settings.skip_animations = false
	Session.delete_save()

	change_scene_to_file("res://Scenes/Main.tscn")
	await _wait(2.5)
	await _shot("01_menu")
	var menu := current_scene
	menu.call("_toggle_new_panel")
	await _wait(0.6)
	await _shot("02_new_campaign")

	Session.pending = {"mode": "new", "seed": 4242, "difficulty": "veteran"}
	change_scene_to_file("res://Scenes/Game.tscn")
	await _wait(2.0)
	var game := current_scene
	var st: GameState = game.state
	await _shot("03_turn1")

	# Build a few things like a player would, then preview a placement.
	var bot := TestBot.new(7)
	bot.play_turn(st)
	game.sync_view()
	game.hud.hide_hint()
	game.call("_on_build_selected", "flak")
	var cap: Dictionary = st.capital()
	var spot := Hex.INVALID
	for h in Hex.in_range(cap["pos"], 3):
		if st.build_check("flak", h) == "":
			spot = h
			break
	if spot != Hex.INVALID:
		game.cam.center_on(Hex.to_pixel(spot), true)
		await _wait(0.3)
		var screen: Vector2 = game.get_viewport().get_canvas_transform() * MapView.top_center(st.tiles, spot)
		Input.warp_mouse(screen * (Vector2(DisplayServer.window_get_size()) / game.get_viewport().get_visible_rect().size))
	await _wait(0.4)
	await _shot("04_build_mode")
	game.call("_set_mode", 0)

	# Play forward with the bot until a wave is airborne and visible.
	Settings.skip_animations = true
	var guard := 0
	while guard < 12:
		guard += 1
		bot.play_turn(st)
		game.sync_view()
		await game.end_turn()
		await _wait(0.2)
		var spotted := 0
		for e in st.enemies.values():
			if st.enemy_detected(e):
				spotted += 1
		if spotted >= 4 and st.turn >= 6:
			break
	game.hud.hide_wave_alert()
	game.hud.hide_hint()
	# Centre on the action.
	var focus := Vector2.ZERO
	var n := 0
	for e in st.enemies.values():
		if st.enemy_detected(e):
			focus += Hex.to_pixel(e["pos"])
			n += 1
	if n > 0:
		game.cam.center_on((focus / n + Hex.to_pixel(cap["pos"])) * 0.5, true)
	game.show_coverage = true
	game.overlay_low.queue_redraw()
	await _wait(0.6)
	await _shot("05_enemies_inbound")
	game.show_coverage = false

	# Watch a live enemy phase with animations, zoomed in on the defended Capital.
	Settings.skip_animations = false
	Settings.anim_speed = 1.0
	bot.play_turn(st)
	game.sync_view()
	game.cam.target_zoom = 1.25
	game.cam.center_on(Hex.to_pixel(cap["pos"]) + Vector2(60, -20), true)
	await _wait(0.4)
	game.end_turn()
	await _wait(1.6)
	await _shot("06_battle_a")
	await _wait(1.3)
	await _shot("07_battle_b")
	while game._animating:
		await _wait(0.2)
	await _wait(0.5)
	await _shot("08_after_battle")
	game.cam.target_zoom = 1.0

	# Select a structure for the info panel.
	var pick: Dictionary = st.capital()
	for s in st.structures.values():
		if s["kind"] == "airbase" or s["kind"] == "sam":
			pick = s
			break
	game.call("_select", pick["pos"])
	await _wait(0.3)
	await _shot("09_selection")

	game.open_research()
	await _wait(0.5)
	await _shot("10_research")
	game._modal.close()
	await _wait(0.3)
	game.open_pause()
	await _wait(0.4)
	await _shot("11_pause")
	game._modal.close()
	await _wait(0.3)

	# Finish the campaign quickly and show the summary.
	Settings.skip_animations = true
	guard = 0
	while st.result == "" and guard < 80:
		guard += 1
		bot.play_turn(st)
		game.sync_view()
		await game.end_turn()
		await process_frame
	await _wait(2.0)
	await _shot("12_game_over")
	print("final: ", st.result, " turn ", st.turn, " score ", st.score)

	# ---- Part 2: air power, carriers and defeat ------------------------------------------
	Session.pending = {"mode": "new", "seed": 9090, "difficulty": "veteran"}
	change_scene_to_file("res://Scenes/Game.tscn")
	await _wait(1.5)
	game = current_scene
	st = game.state
	game.hud.hide_hint()
	st.supplies = 3000
	st.rp = 600
	for t in ["guided_missiles", "logistics", "cruise_missiles", "naval_aa", "jet_interceptors", "improved_radar"]:
		st.research(t)
	for h in st.cells:
		st.explored[h] = true
	var east := Hex.INVALID
	for h in st.cells:
		if st.build_check("airbase", h) == "" and (east == Hex.INVALID or Hex.to_pixel(h).x > Hex.to_pixel(east).x):
			east = h
	var ab: Dictionary = st.build("airbase", east)
	for nb in Hex.neighbors(east):
		if st.build_check("missile", nb) == "":
			st.build("missile", nb)
			break
	for nb in Hex.neighbors(east):
		if st.build_check("radar", nb) == "":
			st.build("radar", nb)
			break
	var harbor := {}
	for h in Hex.in_range(east, 3):
		if st.build_check("harbor", h) == "":
			harbor = st.build("harbor", h)
			break
	st.produce(ab["id"], "interceptor")
	st.produce(ab["id"], "interceptor")
	if not harbor.is_empty():
		st.produce(harbor["id"], "frigate")
	st.compute_visibility()
	game.sync_view()
	Settings.skip_animations = true
	while st.turn < 4:
		await game.end_turn()
		await _wait(0.2)
	game.hud.hide_wave_alert()
	game.hud.hide_hint()
	var unit := {}
	for u in st.units.values():
		if u["kind"] == "interceptor":
			unit = u
	if not unit.is_empty():
		game.cam.center_on(Hex.to_pixel(unit["pos"]), true)
		game.call("_select", unit["pos"])
		await _wait(0.5)
		await _shot("13_interceptor_orders")
	game.call("_set_mode", 0)
	# Recon toward the nearest carrier and strike it.
	Settings.skip_animations = false
	var carrier: Dictionary = st.carriers.values()[0]
	for c in st.carriers.values():
		if Hex.distance(c["pos"], east) < Hex.distance(carrier["pos"], east):
			carrier = c
	game.cam.center_on((Hex.to_pixel(carrier["pos"]) + Hex.to_pixel(east)) * 0.5, true)
	if st.recon_check(carrier["pos"]) == "":
		await game._run_player_events(st.recon_flight(carrier["pos"]))
	await _wait(0.3)
	await _shot("14_recon_carrier")
	if st.strike_check(ab["id"], carrier["id"]) == "":
		game.call("_do_strike", ab["id"], carrier["id"])
		await _wait(0.55)
		await _shot("15_air_strike")
		while game._animating:
			await _wait(0.1)
	for s in st.structures.values():
		if s["kind"] == "missile" and st.strike_check(s["id"], carrier["id"]) == "":
			game.call("_do_strike", s["id"], carrier["id"])
			await _wait(0.5)
			await _shot("16_missile_strike")
			while game._animating:
				await _wait(0.1)
	await _wait(0.6)
	game.call("_select", carrier["pos"])
	await _wait(0.3)
	await _shot("17_carrier_damaged")
	if not st.last_wave_report.is_empty():
		game.hud.wave_alert(st.last_wave_report, 5.0)
		await _wait(0.6)
		await _shot("18_wave_alert")
		game.hud.hide_wave_alert()
	# Defeat.
	var cap2: Dictionary = st.capital()
	var evs: Array = []
	st._destroy_structure(cap2, evs)
	game.sync_view()
	game.call("_show_game_over")
	await _wait(2.2)
	await _shot("19_defeat")
	Session.delete_save()
	quit()


func _wait(sec: float) -> void:
	await create_timer(sec).timeout


func _shot(name: String) -> void:
	await process_frame
	await process_frame
	var img := root.get_texture().get_image()
	var path := out_dir.path_join(name + ".png")
	img.save_png(path)
	print("saved ", path, " ", img.get_size())
