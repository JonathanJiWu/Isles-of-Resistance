extends SceneTree
## Plays the real game using only injected mouse and keyboard events, asserting that every
## interaction has the expected effect. Needs a rendered window, e.g. under Xvfb:
##   xvfb-run godot --path . --resolution 1600x900 -s tests/input_playtest.gd -- --sandbox
## With --sandbox it uses separate save/score/settings files instead of the player's.

var failures := 0
var checks := 0
var Settings
var Session
var game
var st: GameState


func _init() -> void:
	await process_frame
	Settings = root.get_node("/root/Settings")
	Session = root.get_node("/root/Session")
	Settings.tutorial_hints = false
	Settings.skip_animations = false
	Settings.anim_speed = 4.0
	Session.delete_save()
	print("window %s, viewport %s" % [DisplayServer.window_get_size(), root.get_visible_rect().size])
	await _menu_flow()
	await _build_flow()
	await _camera_and_overlays()
	await _research_flow()
	await _turn_flow()
	await _air_flow()
	await _recon_flow()
	await _pause_flow()
	await _continue_flow()
	await _game_over_flow()
	Session.delete_save()
	print("")
	print("%d input checks, %d failures" % [checks, failures])
	quit(1 if failures > 0 else 0)


# --------------------------------------------------------------------------------------------
# Input helpers
# --------------------------------------------------------------------------------------------

func check(cond: bool, msg: String) -> void:
	checks += 1
	print(("  ok    " if cond else "  FAIL  ") + msg)
	if not cond:
		failures += 1


func frames(n: int = 2) -> void:
	for i in n:
		await process_frame


func wait(sec: float) -> void:
	await create_timer(sec).timeout


func until(cond: Callable, timeout: float = 10.0) -> bool:
	var t := 0.0
	while not cond.call() and t < timeout:
		await create_timer(0.05).timeout
		t += 0.05
	return cond.call()


## Converts a position in the (stretched) game viewport into real window pixels.
func to_window(pos: Vector2) -> Vector2:
	return root.get_final_transform() * pos


func move(pos: Vector2) -> void:
	pos = to_window(pos)
	Input.warp_mouse(pos)
	var ev := InputEventMouseMotion.new()
	ev.position = pos
	ev.global_position = pos
	Input.parse_input_event(ev)
	await frames(2)


func click(pos: Vector2, button: MouseButton = MOUSE_BUTTON_LEFT) -> void:
	await move(pos)
	pos = to_window(pos)
	for pressed in [true, false]:
		var ev := InputEventMouseButton.new()
		ev.position = pos
		ev.global_position = pos
		ev.button_index = button
		ev.pressed = pressed
		ev.button_mask = MOUSE_BUTTON_MASK_LEFT if button == MOUSE_BUTTON_LEFT and pressed else 0
		Input.parse_input_event(ev)
		await frames(2)


func wheel(pos: Vector2, up: bool) -> void:
	await move(pos)
	pos = to_window(pos)
	var ev := InputEventMouseButton.new()
	ev.position = pos
	ev.global_position = pos
	ev.button_index = MOUSE_BUTTON_WHEEL_UP if up else MOUSE_BUTTON_WHEEL_DOWN
	ev.pressed = true
	Input.parse_input_event(ev)
	await frames(2)


func key(code: Key, hold: float = 0.0, ctrl: bool = false, unicode: int = 0) -> void:
	var ev := InputEventKey.new()
	ev.keycode = code
	ev.physical_keycode = code
	ev.ctrl_pressed = ctrl
	ev.unicode = unicode
	ev.pressed = true
	Input.parse_input_event(ev)
	if hold > 0.0:
		await wait(hold)
	else:
		await frames(2)
	var up := ev.duplicate()
	up.pressed = false
	Input.parse_input_event(up)
	await frames(2)


func type_text(text: String) -> void:
	for ch in text:
		var code := OS.find_keycode_from_string(ch.to_upper())
		await key(code, 0.0, false, ch.unicode_at(0))


func center_of(c: Control) -> Vector2:
	return c.get_global_rect().get_center()


func find_button(node: Node, prefix: String) -> Button:
	if node is Button and (node as Button).text.begins_with(prefix) and (node as Button).is_visible_in_tree():
		return node
	for ch in node.get_children():
		var b := find_button(ch, prefix)
		if b != null:
			return b
	return null


func hex_screen(h: Vector2i) -> Vector2:
	return game.get_viewport().get_canvas_transform() * MapView.top_center(st.tiles, h)


func on_map(p: Vector2) -> bool:
	return p.x > 300 and p.x < 1250 and p.y > 90 and p.y < 680


## A hex near the Capital that is visible in the map area and accepts `kind`.
func build_spot(kind: String) -> Vector2i:
	var cap: Dictionary = st.capital()
	for r in range(1, 6):
		for h in Hex.ring(cap["pos"], r):
			if st.build_check(kind, h) == "" and on_map(hex_screen(h)):
				return h
	return Hex.INVALID


func is_a(node, cls: String) -> bool:
	return node != null and is_instance_valid(node) and node.get_script() != null and node.get_script().get_global_name() == cls


func modal_is(cls: String) -> bool:
	return is_a(game._modal, cls)


func open_pause_menu() -> void:
	for i in 3:
		if modal_is("PauseMenu"):
			break
		await key(KEY_ESCAPE)
	await wait(0.4)


func find_enabled_button(node: Node, prefix: String) -> Button:
	if node is Button and (node as Button).text.begins_with(prefix) and (node as Button).is_visible_in_tree() and not (node as Button).disabled:
		return node
	for ch in node.get_children():
		var b := find_enabled_button(ch, prefix)
		if b != null:
			return b
	return null


var directives_clicked := 0


## Clears story UI the way a player would: Continue on comms cards, Choose on directives.
func story() -> void:
	for guard in 10:
		await frames(3)
		if game.hud.comms_visible():
			await click(center_of(find_button(game.hud._comms, "Continue")))
			continue
		if modal_is("DirectivePanel"):
			await wait(0.4)
			var pending: String = st.story.pending
			await click(center_of(find_enabled_button(game._modal, "Choose")))
			await wait(0.3)
			if pending != "" and st.story.choices.has(pending):
				directives_clicked += 1
			continue
		if st.story.pending != "" and not game._animating:
			await click(center_of(game.hud._end_btn))
			continue
		break


func attach_game() -> void:
	game = current_scene
	st = game.state


# --------------------------------------------------------------------------------------------
# Flows
# --------------------------------------------------------------------------------------------

func _menu_flow() -> void:
	print("- main menu")
	change_scene_to_file("res://Scenes/Main.tscn")
	await wait(1.0)
	var menu := current_scene
	var nb := find_button(menu, "New Campaign")
	check(nb != null, "New Campaign button exists")
	await click(center_of(nb))
	check(menu._new_panel.visible, "clicking New Campaign opens the setup panel")
	await click(center_of(menu._diff_buttons["recruit"]))
	check(menu._diff == "recruit", "clicking Recruit selects that difficulty")
	await click(center_of(menu._seed_edit))
	await key(KEY_A, 0.0, true)
	await type_text("24680")
	check(menu._seed_edit.text == "24680", "typing a seed into the field (got '%s')" % menu._seed_edit.text)
	await click(center_of(find_button(menu, "Deploy")))
	await until(func(): return current_scene != null and current_scene.has_method("end_turn"), 8.0)
	await wait(1.2)
	check(current_scene.has_method("end_turn"), "Deploy starts a campaign")
	attach_game()
	check(st.seed_value == 24680 and st.difficulty == "recruit", "campaign uses the chosen seed and difficulty")
	check(game.hud.comms_visible() and game.hud._comms_name.text.contains("QUARANTINE"), "the campaign opens with the Act I briefing")
	await click(center_of(find_button(game.hud._comms, "Continue")))
	check(not game.hud.comms_visible(), "Continue dismisses the briefing")


func _build_flow() -> void:
	print("- construction")
	await key(KEY_H)
	await wait(0.6)
	await key(KEY_1)
	check(game.mode == game.Mode.BUILD and game.build_kind == "flak", "key 1 selects Flak Battery")
	var spot := build_spot("flak")
	var n0: int = st.structures.size()
	var sup0: int = st.supplies
	await move(hex_screen(spot))
	check(game.hover == spot, "hovering a hex highlights it")
	check(game.hud._tooltip.visible and game.hud._tooltip_label.text.contains("Build Flak"), "build tooltip offers the placement")
	await click(hex_screen(spot))
	check(st.structures.size() == n0 + 1 and st.supplies == sup0 - 30, "clicking the hex builds the flak battery")
	check(game.mode == game.Mode.IDLE, "build mode ends after placing")
	await key(KEY_2)
	await click(hex_screen(build_spot("radar")), MOUSE_BUTTON_RIGHT)
	check(game.mode == game.Mode.IDLE, "right click cancels build mode")
	await key(KEY_3)
	await key(KEY_ESCAPE)
	check(game.mode == game.Mode.IDLE and game._modal == null, "Escape cancels build mode without opening the menu")
	var lab_btn: Button = game.hud._build_buttons["lab"]
	await click(center_of(lab_btn))
	check(game.mode == game.Mode.BUILD and game.build_kind == "lab", "clicking the Research Lab button enters build mode")
	var lab_spot := build_spot("lab")
	await click(hex_screen(lab_spot))
	check(not st.structure_at(lab_spot).is_empty() and st.structure_at(lab_spot)["kind"] == "lab", "the lab is placed where clicked")
	var water := Hex.INVALID
	for h in Hex.in_range(st.capital()["pos"], 4):
		if st.is_water(h) and on_map(hex_screen(h)):
			water = h
			break
	await key(KEY_1)
	var n1: int = st.structures.size()
	await click(hex_screen(water))
	check(st.structures.size() == n1 and game.hud._toast.modulate.a > 0.5, "an invalid placement shows an error and builds nothing")
	await key(KEY_ESCAPE)
	await click(hex_screen(st.capital()["pos"]))
	check(game.selected == st.capital()["pos"], "clicking the Capital selects it")
	check(find_button(game.hud._info_box, "Demolish") == null, "the Capital cannot be demolished")
	await key(KEY_ESCAPE)
	check(game.selected == Hex.INVALID, "Escape clears the selection")


func _camera_and_overlays() -> void:
	print("- camera & overlays")
	var p0: Vector2 = game.cam.position
	await key(KEY_D, 0.4)
	check(game.cam.position.x > p0.x + 40, "holding D pans the camera right")
	var p1: Vector2 = game.cam.position
	await key(KEY_W, 0.4)
	check(game.cam.position.y < p1.y - 40, "holding W pans the camera up")
	var z0: float = game.cam.target_zoom
	await wheel(Vector2(760, 400), true)
	check(game.cam.target_zoom > z0, "mouse wheel zooms in")
	await wheel(Vector2(760, 400), false)
	await key(KEY_H)
	await wait(0.6)
	check(game.cam.position.distance_to(Hex.to_pixel(st.capital()["pos"])) < 80, "H recenters on the Capital")
	await key(KEY_V)
	check(game.show_coverage, "V toggles the coverage overlay on")
	await key(KEY_V)
	check(not game.show_coverage, "V toggles it off")
	var grid: bool = Settings.show_grid
	await key(KEY_G)
	check(Settings.show_grid != grid, "G toggles the hex grid")
	await key(KEY_G)


func _research_flow() -> void:
	print("- research")
	st.rp = 40
	await key(KEY_R)
	await wait(0.4)
	check(modal_is("ResearchPanel"), "R opens the research tree")
	var btn: Button = game._modal._cards["guided_missiles"]["button"]
	await click(center_of(btn))
	check(st.has_tech("guided_missiles"), "clicking Research unlocks Guided Missiles")
	check(not game.hud._build_buttons["sam"].disabled, "SAM Site becomes buildable")
	await key(KEY_R)
	await wait(0.3)
	check(game._modal == null, "R closes the research tree")


func _turn_flow() -> void:
	print("- turns")
	await story()
	var t0: int = st.turn
	await key(KEY_SPACE)
	await until(func(): return not game._animating and st.turn > t0, 30.0)
	check(st.turn == t0 + 1, "Space ends the turn")
	# Play into the first wave with the End Turn button, skipping animations with Space.
	var guard := 0
	while st.wave < 1 and guard < 4:
		guard += 1
		await story()
		var t1: int = st.turn
		await click(center_of(game.hud._end_btn))
		await wait(0.3)
		if game._animating:
			await key(KEY_SPACE)
		await until(func(): return not game._animating and st.turn > t1, 30.0)
	await story()
	check(st.wave >= 1, "the END TURN button advances turns until the first wave launches")
	check(not game._animating and game.mode == game.Mode.IDLE, "input returns to the player after the enemy phase")
	game.hud.hide_wave_alert()
	await _story_flow()


func _story_flow() -> void:
	print("- story")
	var guard := 0
	while directives_clicked == 0 and guard < 4 and st.result == "":
		guard += 1
		await story()
		if directives_clicked > 0:
			break
		var t1: int = st.turn
		Settings.skip_animations = true
		await key(KEY_SPACE)
		await until(func(): return not game._animating and st.turn > t1, 30.0)
		Settings.skip_animations = false
		game.hud.hide_wave_alert()
	await story()
	check(directives_clicked >= 1, "a directive is presented and answered by clicking Choose (%d)" % directives_clicked)
	check(st.story.pending == "", "no directive left pending")
	check(game.hud._ticker_text.length() > 40, "the broadcast ticker is running")
	await key(KEY_I)
	await wait(0.4)
	check(modal_is("CodexPanel"), "I opens the Intel Archive")
	var detail: String = game._modal._detail.text
	var entry_btn := find_button(game._modal, "The Celestine Commonwealth")
	if entry_btn != null:
		await click(center_of(entry_btn))
	check(game._modal._detail.text != detail and game._modal._detail.text.contains("Celestine"), "clicking a file shows it")
	await key(KEY_I)
	await wait(0.3)
	check(game._modal == null, "I closes the Intel Archive")
	st.rp += 40
	game.sync_view()
	await key(KEY_O)
	await wait(0.4)
	check(modal_is("CyberOpsPanel"), "O opens Cyber Ops")
	var rp0: int = st.rp
	await click(center_of(game._modal._rows["null_pointer"]["button"]))
	check(st.rp == rp0 - 15, "clicking Run executes Operation Null Pointer")
	check(game._modal._rows["null_pointer"]["button"].disabled, "the operation goes on cooldown")
	await key(KEY_O)
	await wait(0.3)
	check(game._modal == null, "O closes Cyber Ops")


func _air_flow() -> void:
	print("- interceptors")
	st.supplies += 300
	game.sync_view()
	await key(KEY_5)
	var spot := build_spot("airbase")
	await click(hex_screen(spot))
	var ab := st.structure_at(spot)
	check(not ab.is_empty() and ab["kind"] == "airbase", "key 5 + click builds an Airbase")
	await click(hex_screen(spot))
	var train := find_button(game.hud._info_box, "Train Interceptor")
	check(train != null and not train.disabled, "the Airbase panel offers Train Interceptor")
	if train != null:
		await click(center_of(train))
	check(st.units.size() == 1, "clicking Train Interceptor deploys a squadron")
	await story()
	var t0: int = st.turn
	Settings.skip_animations = true
	await key(KEY_SPACE)
	await until(func(): return not game._animating and st.turn > t0, 30.0)
	Settings.skip_animations = false
	game.hud.hide_wave_alert()
	await story()
	if st.units.is_empty():
		check(false, "squadron survived the enemy phase")
		return
	var u: Dictionary = st.units.values()[0]
	await key(KEY_TAB)
	check(game.mode == game.Mode.UNIT and game.selected_unit == u["id"], "Tab selects the ready squadron")
	var dest := Hex.INVALID
	for h in game._reach:
		if on_map(hex_screen(h)) and Hex.distance(h, u["pos"]) >= 2:
			dest = h
			break
	await click(hex_screen(dest))
	check(u["pos"] == dest and u["moved"], "clicking a highlighted hex moves the squadron")
	# Put an enemy bomber next to it and attack by clicking.
	var enemy_hex := Hex.INVALID
	for nb in Hex.neighbors(u["pos"]):
		if st.tiles.has(nb) and on_map(hex_screen(nb)) and st.unit_at(nb).is_empty():
			enemy_hex = nb
			break
	var e := st._add_enemy("bomber", enemy_hex, "East")
	st.compute_visibility()
	game.sync_view()
	await click(hex_screen(u["pos"]))
	check(game._targets.has(e["id"]), "an adjacent bomber is shown as attackable")
	# Click where the bomber is drawn (above its hex), as a player would.
	var plane_screen: Vector2 = game.get_viewport().get_canvas_transform() * game.e_nodes[e["id"]].position
	await move(plane_screen)
	check(game.hover == enemy_hex, "pointing at the bomber sprite targets its hex")
	await click(plane_screen)
	await until(func(): return not game._animating, 10.0)
	check(not st.units.has(u["id"]) or st.units[u["id"]]["attacked"], "clicking the bomber attacks it")
	check(not st.enemies.has(e["id"]) or st.enemies[e["id"]]["hp"] < Defs.ENEMIES["bomber"]["hp"] or st.stats["shots"] > 0, "the attack resolved")


func _recon_flow() -> void:
	print("- recon")
	await story()
	st.supplies += 50
	game.sync_view()
	await click(center_of(game.hud._recon_btn))
	check(game.mode == game.Mode.RECON, "clicking Recon Flight enters targeting mode")
	var target := Hex.INVALID
	for h in Hex.in_range(st.capital()["pos"], 8):
		if st.recon_check(h) == "" and on_map(hex_screen(h)) and Hex.distance(h, st.capital()["pos"]) >= 5:
			target = h
			break
	await click(hex_screen(target))
	await until(func(): return not game._animating, 10.0)
	check(st.recon_used_turn == st.turn, "clicking a hex flies the recon mission")
	check(st.visible_hexes.has(target), "the recon area is revealed")


func _pause_flow() -> void:
	print("- pause menu")
	await open_pause_menu()
	check(modal_is("PauseMenu") and paused, "Escape opens the pause menu and pauses the game")
	await click(center_of(find_button(game._modal, "Settings")))
	await wait(0.3)
	var settings_open := false
	for c in game.ui.get_children():
		if is_a(c, "SettingsPanel"):
			settings_open = true
	check(settings_open and modal_is("PauseMenu"), "Settings opens on top of the pause menu")
	await key(KEY_ESCAPE)
	await wait(0.3)
	var still := false
	for c in game.ui.get_children():
		if is_a(c, "SettingsPanel") and not c.is_queued_for_deletion():
			still = true
	check(not still and modal_is("PauseMenu"), "Escape closes Settings and returns to the pause menu")
	await click(center_of(find_button(game._modal, "Resume")))
	await wait(0.3)
	check(game._modal == null and not paused, "Resume closes the menu and unpauses")


func _continue_flow() -> void:
	print("- save & continue")
	var turn: int = st.turn
	var n_struct: int = st.structures.size()
	await open_pause_menu()
	await click(center_of(find_button(game._modal, "Main Menu")))
	await until(func(): return current_scene != null and current_scene.has_method("_toggle_new_panel"), 8.0)
	await wait(1.2)
	check(not paused, "returning to the main menu unpauses")
	var cont := find_button(current_scene, "Continue Campaign")
	check(cont != null, "the main menu offers Continue Campaign")
	if cont == null:
		return
	await click(center_of(cont))
	await until(func(): return current_scene != null and current_scene.has_method("end_turn"), 8.0)
	await wait(1.2)
	attach_game()
	check(st.turn == turn and st.structures.size() == n_struct, "Continue restores the saved campaign")
	await story()


func _game_over_flow() -> void:
	print("- game over")
	await story()
	var cap: Dictionary = st.capital()
	cap["hp"] = 1
	for k in 4:
		var b := st._add_enemy("bomber", cap["pos"], "East")
		b["target"] = {"type": "structure", "id": cap["id"], "pos": cap["pos"]}
	game.sync_view()
	await key(KEY_SPACE)
	await until(func(): return modal_is("GameOverPanel"), 30.0)
	check(st.result == "defeat" and modal_is("GameOverPanel"), "losing the Capital ends the campaign with a summary")
	await wait(0.5)
	await click(center_of(find_button(game._modal, "View Map")))
	await wait(0.4)
	check(game._modal == null, "View Map closes the summary")
	await key(KEY_1)
	check(game.mode == game.Mode.OVER, "build hotkeys are ignored after the campaign ends")
	await key(KEY_SPACE)
	await until(func(): return modal_is("GameOverPanel"), 5.0)
	check(modal_is("GameOverPanel"), "Space reopens the summary")
	check(not Session.has_save(), "a finished campaign leaves no save to continue")
