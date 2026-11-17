extends Node2D
## Game scene controller: owns the GameState, builds the view, routes input and plays back
## the event streams produced by the simulation as (skippable) battle animations.

enum Mode { IDLE, BUILD, UNIT, RECON, STRIKE, BUSY, OVER }

var state: GameState
var mode := Mode.IDLE
var build_kind := ""
var selected := Hex.INVALID
var hover := Hex.INVALID
var selected_unit := -1
var strike_sid := -1
var show_coverage := false

var world: Node2D
var map_view: MapView
var overlay_low: DrawLayer
var entities: Node2D
var fog: FogView
var ghosts: Node2D
var air: Node2D
var overlay_top: DrawLayer
var effects: Effects
var cam: CameraRig
var ui: CanvasLayer
var hud: HUD
var _modal: Modal

var s_nodes := {}
var u_nodes := {}
var e_nodes := {}
var c_nodes := {}
var _reach := {}
var _targets: Array = []
var _animating := false
var _skip := false
var _token := 0
var _hints := {}
var _last_ruins := -1


func _ready() -> void:
	_build_scene()
	var p: Dictionary = Session.pending
	if p.get("mode", "new") == "load":
		state = Session.load_game()
	if state == null:
		var sd: int = p.get("seed", 0)
		if sd == 0:
			sd = randi() % 1000000 + 1
		state = GameState.create(sd, p.get("difficulty", "veteran"))
	map_view.setup(state.tiles, state.cells)
	map_view.show_grid = Settings.show_grid
	fog.setup(state.tiles, state.cells)
	var rect := MapView.map_rect(state.cells)
	cam.bounds = rect.grow(-120)
	var ocean := ColorRect.new()
	var margin := 900.0
	ocean.position = rect.position - Vector2(margin, margin)
	ocean.size = rect.size + Vector2(margin, margin) * 2.0
	var mat := ShaderMaterial.new()
	mat.shader = load("res://Shaders/ocean.gdshader")
	mat.set_shader_parameter("size", ocean.size)
	ocean.material = mat
	ocean.mouse_filter = Control.MOUSE_FILTER_IGNORE
	world.add_child(ocean)
	world.move_child(ocean, 0)
	hud.build(state)
	_connect_hud()
	Settings.changed.connect(_on_settings_changed)
	_on_settings_changed()
	sync_view()
	var cap := state.capital()
	cam.center_on(Hex.to_pixel(cap["pos"]) if not cap.is_empty() else rect.get_center(), true)
	hud.show_selection(Hex.INVALID)
	hud.banner("TURN %d" % state.turn, UITheme.ACCENT, 1.2)
	Session.save_game(state)
	_maybe_hint()


func _build_scene() -> void:
	world = Node2D.new()
	add_child(world)
	map_view = MapView.new()
	world.add_child(map_view)
	overlay_low = DrawLayer.new()
	overlay_low.draw_fn = _draw_low
	world.add_child(overlay_low)
	entities = Node2D.new()
	entities.y_sort_enabled = true
	world.add_child(entities)
	fog = FogView.new()
	world.add_child(fog)
	ghosts = Node2D.new()
	world.add_child(ghosts)
	air = Node2D.new()
	air.y_sort_enabled = true
	world.add_child(air)
	overlay_top = DrawLayer.new()
	overlay_top.draw_fn = _draw_top
	overlay_top.animate = true
	world.add_child(overlay_top)
	effects = Effects.new()
	world.add_child(effects)
	cam = CameraRig.new()
	add_child(cam)
	cam.make_current()
	ui = CanvasLayer.new()
	ui.layer = 10
	add_child(ui)
	hud = HUD.new()
	ui.add_child(hud)


func _connect_hud() -> void:
	hud.build_selected.connect(_on_build_selected)
	hud.recon_selected.connect(_on_recon_selected)
	hud.end_turn_pressed.connect(end_turn)
	hud.skip_pressed.connect(skip)
	hud.action_pressed.connect(_on_action)
	hud.research_pressed.connect(open_research)
	hud.coverage_toggled.connect(toggle_coverage)
	hud.menu_pressed.connect(open_pause)


func _on_settings_changed() -> void:
	cam.edge_pan = Settings.edge_pan
	effects.speed = Settings.anim_speed
	if map_view.show_grid != Settings.show_grid:
		map_view.show_grid = Settings.show_grid
		map_view.queue_redraw()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		_autosave()


func _autosave() -> void:
	if state != null and state.phase == "player" and not _animating and state.result == "":
		Session.save_game(state)


# --------------------------------------------------------------------------------------------
# Positions
# --------------------------------------------------------------------------------------------

func _top(h: Vector2i) -> Vector2:
	return MapView.top_center(state.tiles, h)


func _struct_pos(h: Vector2i) -> Vector2:
	return _top(h)


func _unit_pos(kind: String, h: Vector2i) -> Vector2:
	return _top(h) - Vector2(0, 12) if kind == "interceptor" else Hex.to_pixel(h)


func _air_pos(id: int, kind: String, h: Vector2i) -> Vector2:
	var lift := 20.0 if Defs.ENEMIES[kind]["alt"] == "high" else 12.0
	return _top(h) - Vector2(0, lift) + AircraftNode.jitter(id)


# --------------------------------------------------------------------------------------------
# View synchronisation
# --------------------------------------------------------------------------------------------

func sync_view() -> void:
	var targeted := {}
	for e in state.enemies.values():
		if state.enemy_detected(e) and e["target"].get("type", "") == "structure":
			targeted[e["target"]["id"]] = true
	for id in s_nodes.keys():
		if not state.structures.has(id):
			s_nodes[id].queue_free()
			s_nodes.erase(id)
	for s in state.structures.values():
		var n: StructureNode = s_nodes.get(s["id"])
		if n == null:
			n = StructureNode.new()
			n.setup(s)
			entities.add_child(n)
			s_nodes[s["id"]] = n
		n.position = _struct_pos(s["pos"])
		n.set_hp(s["hp"], s["max_hp"])
		n.targeted = targeted.has(s["id"]) and Settings.show_intents
		n.queue_redraw()
	for id in u_nodes.keys():
		if not state.units.has(id):
			u_nodes[id].queue_free()
			u_nodes.erase(id)
	for u in state.units.values():
		var n: UnitNode = u_nodes.get(u["id"])
		if n == null:
			n = UnitNode.new()
			n.setup(u)
			entities.add_child(n)
			u_nodes[u["id"]] = n
		n.position = _unit_pos(u["kind"], u["pos"])
		n.update_from(u)
	for id in e_nodes.keys():
		if not state.enemies.has(id):
			e_nodes[id].queue_free()
			e_nodes.erase(id)
	for e in state.enemies.values():
		var n: AircraftNode = e_nodes.get(e["id"])
		if n == null:
			n = AircraftNode.new()
			n.setup(e)
			air.add_child(n)
			e_nodes[e["id"]] = n
		n.position = _air_pos(e["id"], e["kind"], e["pos"])
		n.hp = e["hp"]
		n.force_shown(state.enemy_detected(e))
		var th := state.ai.target_hex(state, e)
		if th != Hex.INVALID and th != e["pos"]:
			n.heading = (Hex.to_pixel(th) - Hex.to_pixel(e["pos"])).angle()
	for id in c_nodes.keys():
		if not state.carriers.has(id):
			c_nodes[id].queue_free()
			c_nodes.erase(id)
	for c in state.carriers.values():
		var n: CarrierNode = c_nodes.get(c["id"])
		var vis := state.carrier_visible(c)
		var known := state.carrier_known(c)
		if n == null:
			n = CarrierNode.new()
			n.setup(c)
			ghosts.add_child(n)
			c_nodes[c["id"]] = n
		n.hp = c["hp"]
		n.max_hp = c["max_hp"]
		n.ghost = not vis
		n.seen_ago = state.turn - c["seen_turn"]
		n.visible = vis or known
		n.position = Hex.to_pixel(c["pos"] if vis else c["seen_pos"]) if n.visible else n.position
	if _last_ruins != state.ruins.size():
		_last_ruins = state.ruins.size()
		map_view.set_ruins(state.ruins)
	fog.update_fog(state.explored, state.visible_hexes)
	overlay_low.queue_redraw()
	hud.refresh()


# --------------------------------------------------------------------------------------------
# Input
# --------------------------------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if _modal != null and is_instance_valid(_modal):
		return
	if cam.handle_input(event):
		_update_hover()
		return
	if event is InputEventMouseMotion:
		_update_hover()
	elif event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			_update_hover()
			_on_left_click(hover)
		elif mb.button_index == MOUSE_BUTTON_RIGHT and not mb.pressed and cam.last_drag_distance < 6.0:
			cancel()
	elif event is InputEventKey and event.pressed and not event.echo:
		_on_key(event as InputEventKey)


func _on_key(k: InputEventKey) -> void:
	match k.keycode:
		KEY_SPACE, KEY_ENTER, KEY_KP_ENTER:
			if _animating:
				skip()
			elif mode == Mode.OVER:
				_show_game_over()
			else:
				end_turn()
		KEY_ESCAPE:
			if mode in [Mode.BUILD, Mode.UNIT, Mode.RECON, Mode.STRIKE] or selected != Hex.INVALID:
				cancel()
			else:
				open_pause()
		KEY_R:
			open_research()
		KEY_V:
			toggle_coverage()
		KEY_G:
			Settings.set_and_save("show_grid", not Settings.show_grid)
		KEY_H:
			var cap := state.capital()
			if not cap.is_empty():
				cam.center_on(Hex.to_pixel(cap["pos"]))
		KEY_TAB:
			_cycle_unit()
		KEY_F1:
			_open_modal(HowToPlayPanel.new())
		_:
			var n := -1
			if k.keycode >= KEY_1 and k.keycode <= KEY_9:
				n = k.keycode - KEY_1
			elif k.keycode == KEY_0:
				n = 9
			if n >= 0 and n < Defs.BUILD_ORDER.size():
				_on_build_selected(Defs.BUILD_ORDER[n])
	get_viewport().set_input_as_handled()


func _process(_delta: float) -> void:
	if hud.mouse_over_ui():
		if hover != Hex.INVALID:
			hover = Hex.INVALID
			_on_hover_changed()
		hud.set_tooltip("")
	else:
		_update_hover()


func _update_hover() -> void:
	if hud.mouse_over_ui() or (_modal != null and is_instance_valid(_modal)):
		return
	var h := _hex_under_mouse()
	if h != hover:
		hover = h
		_on_hover_changed()


func _hex_under_mouse() -> Vector2i:
	var m := get_global_mouse_position()
	var h := Hex.from_pixel(m)
	# Raised terrain: prefer the hex whose raised top face contains the cursor.
	var below := h + Hex.DIRS[5]
	var below2 := h + Hex.DIRS[4]
	for cand in [below, below2]:
		if state.tiles.has(cand) and MapView.elev(state.tiles[cand]) > 0.0:
			if Hex.from_pixel(m + Vector2(0, MapView.elev(state.tiles[cand]))) == cand:
				return cand
	if state.tiles.has(h) and MapView.elev(state.tiles[h]) > 0.0:
		var h2 := Hex.from_pixel(m + Vector2(0, MapView.elev(state.tiles[h])))
		if h2 == h or not state.tiles.has(h2):
			return h
	return h if state.tiles.has(h) else Hex.INVALID


func _on_hover_changed() -> void:
	for n in e_nodes.values():
		n.hovered = false
	if hover != Hex.INVALID:
		for e in state.visible_enemies_at(hover):
			if e_nodes.has(e["id"]):
				e_nodes[e["id"]].hovered = true
	overlay_low.queue_redraw()
	hud.set_tooltip(_hover_text(hover) if hover != Hex.INVALID and not _animating else "")


func _hover_text(h: Vector2i) -> String:
	if not state.explored.has(h):
		return "[b]Uncharted[/b]"
	var lines: Array = []
	var tdef: Dictionary = Defs.TERRAIN[state.terrain(h)]
	var head := "[b]%s[/b]" % tdef["name"]
	var s := state.structure_at(h)
	if not s.is_empty():
		var nm: String = s["name"] if s["name"] != "" else Defs.structure_name(s["kind"])
		head = "[b]%s[/b]  [color=#9fb0c2]%d/%d HP · %s[/color]" % [nm, s["hp"], s["max_hp"], tdef["name"]]
	lines.append(head)
	var u := state.unit_at(h)
	if not u.is_empty():
		lines.append("[color=#4fd1c5]%s[/color]  %d/%d HP" % [Defs.unit_name(u["kind"]), u["hp"], u["max_hp"]])
	for e in state.visible_enemies_at(h):
		var tgt := ""
		var th := state.ai.target_hex(state, e)
		if e["state"] == "rtb":
			tgt = " · withdrawing"
		elif th != Hex.INVALID:
			var ts := state.structure_at(th)
			if not ts.is_empty() and e["target"].get("type", "") == "structure":
				tgt = " → %s" % (ts["name"] if ts["name"] != "" else Defs.structure_name(ts["kind"]))
		lines.append("[color=#ff7a7a]%s[/color]  %d/%d HP%s" % [Defs.enemy_name(e["kind"]), e["hp"], e["max_hp"], tgt])
	var c := state.carrier_at(h)
	if not c.is_empty() and state.carrier_visible(c):
		lines.append("[color=#ff7a7a]Enemy Carrier[/color]  %d/%d HP" % [c["hp"], c["max_hp"]])
	match mode:
		Mode.BUILD:
			var err := state.build_check(build_kind, h)
			if err == "":
				lines.append("[color=#7de389]Build %s (%d)[/color]" % [Defs.structure_name(build_kind), state.build_cost(build_kind)])
			else:
				lines.append("[color=#ff6b6b]%s[/color]" % err)
		Mode.RECON:
			var err2 := state.recon_check(h)
			lines.append("[color=#7de389]Fly recon here (%d)[/color]" % Defs.RECON_COST if err2 == "" else "[color=#ff6b6b]%s[/color]" % err2)
		Mode.UNIT:
			for eid in _targets:
				if state.enemies.has(eid) and state.enemies[eid]["pos"] == h:
					lines.append("[color=#ffd166]Click to attack[/color]")
					break
			if _reach.has(h):
				lines.append("[color=#4fd1c5]Move here[/color]")
	return "\n".join(lines)


func _on_left_click(h: Vector2i) -> void:
	if _animating or mode == Mode.BUSY:
		return
	if mode == Mode.OVER:
		_select(h)
		return
	match mode:
		Mode.BUILD:
			if h == Hex.INVALID:
				return
			var err := state.build_check(build_kind, h)
			if err != "":
				Audio.play("error")
				hud.toast(err)
				return
			var s := state.build(build_kind, h)
			if not s.is_empty():
				Audio.play("build")
				effects.dust(_struct_pos(h))
				sync_view()
				s_nodes[s["id"]].appear()
				_maybe_hint()
				if not Input.is_key_pressed(KEY_SHIFT) or state.supplies < state.build_cost(build_kind):
					_set_mode(Mode.IDLE)
					_select(h)
				else:
					hud.show_selection(h)
		Mode.RECON:
			var err := state.recon_check(h)
			if err != "":
				Audio.play("error")
				hud.toast(err)
				return
			_set_mode(Mode.IDLE)
			var events := state.recon_flight(h)
			await _run_player_events(events)
		Mode.STRIKE:
			var c := state.carrier_at(h)
			if c.is_empty() or not state.strike_targets(strike_sid).has(c["id"]):
				Audio.play("error")
				hud.toast("Select a spotted carrier within range")
				return
			_do_strike(strike_sid, c["id"])
		Mode.UNIT:
			var u: Dictionary = state.units.get(selected_unit, {})
			if u.is_empty():
				_select(h)
				return
			for eid in _targets:
				if state.enemies.has(eid) and state.enemies[eid]["pos"] == h:
					await _do_attack(u["id"], eid)
					return
			if _reach.has(h):
				_do_move(u["id"], h)
				return
			_select(h)
		_:
			_select(h)


func cancel() -> void:
	if _animating:
		return
	if mode == Mode.OVER:
		return
	if mode != Mode.IDLE:
		_set_mode(Mode.IDLE)
	else:
		selected = Hex.INVALID
		hud.show_selection(Hex.INVALID)
	overlay_low.queue_redraw()


func _set_mode(m: Mode) -> void:
	mode = m
	if m != Mode.BUILD:
		build_kind = ""
		hud.set_active_build("")
	if m != Mode.UNIT:
		selected_unit = -1
		_reach = {}
		_targets = []
	if m != Mode.STRIKE:
		strike_sid = -1
	overlay_low.queue_redraw()
	hud.set_tooltip(_hover_text(hover) if hover != Hex.INVALID else "")


func _select(h: Vector2i) -> void:
	selected = h
	_set_mode(Mode.IDLE if mode != Mode.OVER else Mode.OVER)
	if h != Hex.INVALID and mode != Mode.OVER:
		var u := state.unit_at(h)
		if not u.is_empty():
			_select_unit(u)
	hud.show_selection(h)
	if h != Hex.INVALID:
		Audio.play("click", -6.0)


func _select_unit(u: Dictionary) -> void:
	mode = Mode.UNIT
	selected_unit = u["id"]
	selected = u["pos"]
	_reach = state.unit_reachable(u)
	_targets = state.unit_targets(u)
	overlay_low.queue_redraw()


func _cycle_unit() -> void:
	var list: Array = state.units.values()
	list.sort_custom(func(a, b): return a["id"] < b["id"])
	var ready: Array = []
	for u in list:
		if not state.unit_reachable(u).is_empty() or not state.unit_targets(u).is_empty():
			ready.append(u)
	if ready.is_empty():
		hud.toast("No units awaiting orders")
		return
	var idx := 0
	for i in ready.size():
		if ready[i]["id"] == selected_unit:
			idx = (i + 1) % ready.size()
	var u: Dictionary = ready[idx]
	_select(u["pos"])
	cam.center_on(Hex.to_pixel(u["pos"]))


func _on_build_selected(kind: String) -> void:
	if _animating or mode == Mode.OVER:
		return
	var locked := state.build_locked_reason(kind)
	if locked != "":
		Audio.play("error")
		hud.toast(locked)
		hud.set_active_build("")
		return
	if mode == Mode.BUILD and build_kind == kind:
		_set_mode(Mode.IDLE)
		return
	_set_mode(Mode.BUILD)
	build_kind = kind
	hud.set_active_build(kind)
	if state.supplies < state.build_cost(kind):
		hud.toast("Not enough supplies for %s" % Defs.structure_name(kind))
	overlay_low.queue_redraw()


func _on_recon_selected() -> void:
	if _animating or mode == Mode.OVER:
		return
	if state.recon_used_turn == state.turn:
		hud.toast("Recon flight already flown this turn")
		return
	_set_mode(Mode.RECON)
	hud.toast("Choose an area to reconnoitre (within %d hexes of your Capital or an Airbase)" % Defs.RECON_RANGE)


func _on_action(action: String, id: int) -> void:
	if _animating:
		return
	match action:
		"repair":
			if state.repair(id):
				Audio.play("build")
				effects.sparkle(_struct_pos(state.structures[id]["pos"]), Defs.GOOD)
		"demolish":
			var pos: Vector2i = state.structures[id]["pos"]
			if state.demolish(id):
				Audio.play("explosion", -8.0)
				effects.explosion(_struct_pos(pos), 0.6)
		"train", "frigate":
			var u := state.produce(id, "interceptor" if action == "train" else "frigate")
			if not u.is_empty():
				Audio.play("jet" if action == "train" else "build")
				sync_view()
				effects.dust(_unit_pos(u["kind"], u["pos"]))
				_maybe_hint()
		"strike":
			var targets := state.strike_targets(id)
			if targets.size() == 1:
				_do_strike(id, targets[0])
				return
			elif targets.size() > 1:
				_set_mode(Mode.STRIKE)
				strike_sid = id
				hud.toast("Select a carrier to strike")
	sync_view()
	hud.show_selection(selected)


func _do_move(uid: int, h: Vector2i) -> void:
	var u: Dictionary = state.units[uid]
	var n: UnitNode = u_nodes.get(uid)
	var old := n.position if n != null else Vector2.ZERO
	if not state.move_unit(uid, h):
		return
	Audio.play("jet" if u["kind"] == "interceptor" else "click", -6.0)
	selected = h
	_select_unit(u)
	sync_view()
	if n != null:
		n.position = old
		n.move_to(_unit_pos(u["kind"], h), 0.35)
	hud.show_selection(h)


func _do_attack(uid: int, eid: int) -> void:
	var events := state.unit_attack(uid, eid)
	await _run_player_events(events)
	if state.units.has(uid):
		_select_unit(state.units[uid])
		hud.show_selection(state.units[uid]["pos"])


func _do_strike(sid: int, cid: int) -> void:
	_set_mode(Mode.IDLE)
	var events := state.strike(sid, cid)
	await _run_player_events(events)


func _run_player_events(events: Array) -> void:
	if events.is_empty():
		return
	mode = Mode.BUSY
	await play_events(events)
	if state.result != "":
		_show_game_over()
		return
	mode = Mode.IDLE
	sync_view()
	hud.show_selection(selected)


func toggle_coverage() -> void:
	show_coverage = not show_coverage
	hud.set_coverage(show_coverage)
	overlay_low.queue_redraw()


# --------------------------------------------------------------------------------------------
# Turn flow
# --------------------------------------------------------------------------------------------

func end_turn() -> void:
	if _animating or state.phase != "player" or mode == Mode.OVER:
		return
	_set_mode(Mode.BUSY)
	hud.hide_hint()
	hud.set_tooltip("")
	hud.set_busy(true)
	var events := state.end_turn()
	await play_events(events)
	hud.set_busy(false)
	if state.result != "":
		_show_game_over()
		return
	mode = Mode.IDLE
	selected = Hex.INVALID
	hud.show_selection(Hex.INVALID)
	Audio.play("turn")
	hud.banner("TURN %d" % state.turn, UITheme.ACCENT, 1.0)
	Session.save_game(state)
	sync_view()
	_maybe_hint()


func skip() -> void:
	if _animating:
		_skip = true


func _wait(sec: float) -> void:
	var t := 0.0
	while t < sec and not _skip:
		await get_tree().process_frame
		t += get_process_delta_time()


func play_events(events: Array) -> void:
	_animating = true
	_skip = Settings.skip_animations
	_token += 1
	var token := _token
	var sp: float = Settings.anim_speed
	effects.speed = sp
	var pending_logs := 0
	for ev in events:
		if ev["type"] == "log":
			pending_logs += 1
	hud.log_hold(pending_logs)
	var wave_report := {}
	var i := 0
	while i < events.size() and not _skip:
		var ev: Dictionary = events[i]
		match ev["type"]:
			"phase":
				hud.banner(ev["text"], Defs.ENEMY_COLOR, 0.8)
				await _wait(0.5 / sp)
			"beat_start":
				var j := i + 1
				var dur := 0.34 / sp
				var any_vis := false
				while j < events.size() and events[j]["type"] != "beat_end":
					_anim_move(events[j], dur)
					if events[j].get("vis", false):
						any_vis = true
					j += 1
				i = j
				await _wait(dur if any_vis else 0.03)
			"volley_start":
				var j := i + 1
				var group: Array = []
				while j < events.size() and events[j]["type"] != "volley_end":
					group.append(events[j])
					j += 1
				i = j
				await _play_volley(group, sp, token)
			"move":
				_anim_move(ev, 0.6 / sp)
			"spawn":
				_anim_spawn(ev)
				await _wait(0.04 / sp)
			"exit":
				var n: AircraftNode = e_nodes.get(ev["id"])
				if n != null:
					e_nodes.erase(ev["id"])
					n.depart()
			"wave":
				wave_report = ev["report"]
				Audio.play("alarm")
				hud.wave_alert(wave_report)
				await _wait(1.8 / sp)
			"wave_cleared":
				Audio.play("cleared")
			"log":
				hud.log_advance()
			"recon":
				var a := Hex.to_pixel(ev["from"])
				var b := Hex.to_pixel(ev["to"])
				Audio.play("jet")
				effects.projectile("jet", a, b, 0.8 / sp, Color.WHITE)
				await _wait(0.8 / sp)
				effects.ring(b, 10.0, Hex.SIZE * 4.5, 0.8, Color(Defs.GOLD, 0.8))
				fog.update_fog(state.explored, state.visible_hexes)
				sync_view()
			"shot", "attack", "strike", "damage", "destroyed":
				var group2: Array = [ev]
				var j2 := i + 1
				while j2 < events.size() and events[j2]["type"] in ["damage", "destroyed", "log"]:
					group2.append(events[j2])
					j2 += 1
				i = j2 - 1
				await _play_volley(group2, sp, token)
		i += 1
	_token += 1
	var skipped := _skip
	_skip = false
	if skipped:
		effects.clear_all()
		for n in e_nodes.values():
			if is_instance_valid(n):
				n.queue_free()
		e_nodes.clear()
	_animating = false
	hud.log_release()
	sync_view()
	if skipped and not wave_report.is_empty():
		hud.wave_alert(wave_report, 3.0)


func _anim_move(ev: Dictionary, dur: float) -> void:
	match ev.get("ent", ""):
		"enemy":
			var e: Dictionary = state.enemies.get(ev["id"], {})
			var n: AircraftNode = e_nodes.get(ev["id"])
			if n == null:
				return
			var kind: String = n.kind
			n.fly_to(_air_pos(ev["id"], kind, ev["to"]), dur)
			n.set_shown(ev["vis"], dur * 0.6)
		"carrier":
			var c: CarrierNode = c_nodes.get(ev["id"])
			if c != null and ev["vis"]:
				c.visible = true
				c.ghost = false
				c.move_to(Hex.to_pixel(ev["to"]), dur)


func _anim_spawn(ev: Dictionary) -> void:
	if e_nodes.has(ev["id"]):
		return
	var n := AircraftNode.new()
	n.setup({"id": ev["id"], "kind": ev["kind"], "hp": Defs.ENEMIES[ev["kind"]]["hp"], "max_hp": Defs.ENEMIES[ev["kind"]]["hp"]})
	n.position = _air_pos(ev["id"], ev["kind"], ev["pos"])
	air.add_child(n)
	e_nodes[ev["id"]] = n
	n.force_shown(false)
	if ev["vis"]:
		n.set_shown(true, 0.4)


## Plays a group of shots/attacks (each followed by its consequences) with slight staggering.
func _play_volley(group: Array, sp: float, token: int) -> void:
	var stagger := 0.1 / sp
	var k := 0
	var idx := 0
	var end_time := 0.0
	while idx < group.size():
		var ev: Dictionary = group[idx]
		var follow: Array = []
		var j := idx + 1
		while j < group.size() and group[j]["type"] in ["damage", "destroyed", "log", "exit"]:
			follow.append(group[j])
			j += 1
		if ev["type"] in ["damage", "destroyed", "log", "exit"]:
			follow.push_front(ev)
			_apply_follow(follow, sp)
		else:
			var delay := k * stagger
			var travel := _launch(ev, follow, delay, sp, token)
			end_time = maxf(end_time, delay + travel)
			k += 1
		idx = j
	await _wait(end_time + 0.12 / sp)


func _src_pos(ev: Dictionary) -> Vector2:
	match ev.get("src", ""):
		"structure":
			return _struct_pos(ev["from"]) + Vector2(0, -6)
		"unit":
			var n: UnitNode = u_nodes.get(ev["src_id"])
			return n.position if n != null else _top(ev["from"])
		"enemy":
			var n2: AircraftNode = e_nodes.get(ev["src_id"])
			return n2.position if n2 != null else _top(ev["from"])
	return _top(ev.get("from", Vector2i.ZERO))


func _dst_pos(ev: Dictionary) -> Vector2:
	match ev.get("dst", ""):
		"enemy":
			var n: AircraftNode = e_nodes.get(ev["dst_id"])
			return n.position if n != null else _top(ev["to"]) - Vector2(0, 16)
		"unit":
			var n2: UnitNode = u_nodes.get(ev["dst_id"])
			return n2.position if n2 != null else _top(ev["to"])
	return _top(ev["to"])


func _launch(ev: Dictionary, follow: Array, delay: float, sp: float, token: int) -> float:
	var travel := 0.25 / sp
	var hit: bool = ev.get("hit", true)
	match ev["type"]:
		"shot":
			match ev["weapon"]:
				"sam":
					travel = 0.5 / sp
				"laser":
					travel = 0.1 / sp
				"cannon":
					travel = 0.3 / sp
				"gun":
					travel = 0.2 / sp
				_:
					travel = 0.22 / sp
		"attack":
			match ev["weapon"]:
				"bombs":
					travel = 0.55 / sp
				"rockets":
					travel = 0.35 / sp
				"impact":
					travel = 0.3 / sp
				_:
					travel = 0.25 / sp
		"strike":
			travel = (0.9 if ev["weapon"] == "air" else 0.85) / sp
	var go := func():
		if token != _token:
			return
		var a := Vector2.ZERO
		var b := Vector2.ZERO
		var on_hit := func():
			if token != _token:
				return
			_impact(ev, follow, sp)
		match ev["type"]:
			"shot":
				a = _src_pos(ev)
				b = _dst_pos(ev)
				if not hit:
					b += Vector2(randf_range(-14, 14), randf_range(-14, 8))
				match ev["weapon"]:
					"flak":
						Audio.play("flak", -4.0)
						for q in 3:
							effects.projectile("flak", a + Vector2(q * 2 - 2, 0), b + Vector2(randf_range(-5, 5), randf_range(-5, 5)), travel * (0.85 + q * 0.08), Color(1.0, 0.85, 0.4), on_hit if q == 0 else Callable())
					"sam":
						Audio.play("sam", -3.0)
						effects.projectile("missile", a, b, travel, Color.WHITE, on_hit, 40.0)
					"laser":
						Audio.play("laser", -3.0)
						effects.beam(a, b, Color(0.4, 1.0, 1.0), 0.3)
						effects.projectile("tracer", a, b, travel, Color(0, 0, 0, 0), on_hit)
					"cannon":
						Audio.play("cannon", -5.0)
						var un: UnitNode = u_nodes.get(ev["src_id"]) if ev["src"] == "unit" else null
						if un != null:
							un.lunge(b, travel * 1.6)
						for q in 4:
							effects.projectile("tracer", a, b + Vector2(randf_range(-4, 4), randf_range(-4, 4)), travel * (0.8 + q * 0.07), Color(0.6, 1.0, 1.0), on_hit if q == 0 else Callable())
					"gun":
						Audio.play("gun", -6.0)
						for q in 3:
							effects.projectile("tracer", a, b + Vector2(randf_range(-4, 4), randf_range(-4, 4)), travel * (0.85 + q * 0.07), Color(1.0, 0.5, 0.4), on_hit if q == 0 else Callable())
			"attack":
				var en: AircraftNode = e_nodes.get(ev["id"])
				a = en.position if en != null else _top(ev["from"])
				b = _top(ev["to"])
				if not hit:
					b += Vector2(randf_range(-20, 20), randf_range(-14, 14))
				match ev["weapon"]:
					"bombs":
						Audio.play("whistle", -4.0)
						effects.projectile("bomb", a, b, travel, Color.BLACK, on_hit)
					"rockets":
						Audio.play("rockets", -4.0)
						effects.projectile("rocket", a, b, travel, Color.WHITE, on_hit)
						effects.projectile("rocket", a + Vector2(3, 2), b + Vector2(5, -3), travel * 1.1, Color.WHITE)
					"impact":
						if en != null:
							e_nodes.erase(ev["id"])
							var tw := en.create_tween()
							tw.tween_property(en, "position", b, travel).set_ease(Tween.EASE_IN)
							tw.tween_callback(en.queue_free)
						effects.projectile("tracer", a, b, travel, Color(0, 0, 0, 0), on_hit)
					_:
						Audio.play("gun", -6.0)
						for q in 3:
							effects.projectile("tracer", a, b + Vector2(randf_range(-6, 6), randf_range(-6, 6)), travel * (0.85 + q * 0.07), Color(1.0, 0.5, 0.4), on_hit if q == 0 else Callable())
			"strike":
				a = _top(ev["from"])
				var cn: CarrierNode = c_nodes.get(ev["cid"])
				b = cn.position if cn != null else Hex.to_pixel(ev["to"])
				if not hit:
					b += Vector2(randf_range(-24, 24), randf_range(-16, 16))
				if ev["weapon"] == "air":
					Audio.play("jet")
					effects.projectile("jet", a, b, travel, Color.WHITE, on_hit)
				else:
					Audio.play("sam")
					effects.projectile("missile", a, b, travel, Color.WHITE, on_hit, 90.0)
	if delay <= 0.001:
		go.call()
	else:
		get_tree().create_timer(delay, false).timeout.connect(go)
	return travel


func _impact(ev: Dictionary, follow: Array, sp: float) -> void:
	var hit: bool = ev.get("hit", true)
	var p: Vector2
	match ev["type"]:
		"shot":
			p = _dst_pos(ev)
			if ev["weapon"] == "flak":
				for q in 3:
					effects.airburst(p + Vector2(randf_range(-10, 10), randf_range(-10, 10)))
			if not hit:
				effects.float_text(p, "MISS", Color(0.75, 0.8, 0.85), 13)
		"attack":
			p = _top(ev["to"])
			if not hit:
				var water := state.is_water(ev["to"])
				if water:
					effects.splash(p + Vector2(randf_range(-16, 16), randf_range(-10, 10)))
				else:
					effects.explosion(p + Vector2(randf_range(-20, 20), randf_range(-14, 14)), 0.6)
				Audio.play("explosion", -10.0)
				effects.float_text(p, "MISS", Color(0.75, 0.8, 0.85), 13)
			elif ev["weapon"] != "guns":
				effects.explosion(p, 0.9 if ev["weapon"] != "rockets" else 0.6)
				Audio.play("explosion", -4.0)
				cam.shake(5.0 if ev["weapon"] == "bombs" or ev["weapon"] == "impact" else 2.5)
		"strike":
			var cn: CarrierNode = c_nodes.get(ev["cid"])
			p = cn.position if cn != null else Hex.to_pixel(ev["to"])
			if hit:
				effects.explosion(p, 1.1)
				Audio.play("explosion")
			else:
				effects.splash(p + Vector2(18, 10))
				effects.float_text(p, "INTERCEPTED", Color(0.75, 0.8, 0.85), 13)
	_apply_follow(follow, sp)


func _apply_follow(follow: Array, _sp: float) -> void:
	for f in follow:
		match f["type"]:
			"damage":
				match f["tgt"]:
					"enemy":
						var n: AircraftNode = e_nodes.get(f["id"])
						if n != null:
							n.hp = f["hp"]
							n.flash()
							effects.float_text(n.position, "-%d" % f["dmg"], Defs.GOLD, 15)
					"structure":
						var s: StructureNode = s_nodes.get(f["id"])
						if s != null:
							s.set_hp(f["hp"], s.max_hp)
							s.flash()
							var txt := "-%d" % f["dmg"]
							if f.get("shielded", false):
								txt += " (sheltered)"
							effects.float_text(s.position, txt, Defs.BAD, 16)
					"unit":
						var u: UnitNode = u_nodes.get(f["id"])
						if u != null:
							u.hp = f["hp"]
							u.flash()
							effects.float_text(u.position, "-%d" % f["dmg"], Defs.BAD, 15)
					"carrier":
						var c: CarrierNode = c_nodes.get(f["id"])
						if c != null:
							c.hp = f["hp"]
							c.flash()
							effects.float_text(c.position, "-%d" % f["dmg"], Defs.GOLD, 18)
			"destroyed":
				match f["tgt"]:
					"enemy":
						var n: AircraftNode = e_nodes.get(f["id"])
						if n != null:
							e_nodes.erase(f["id"])
							if f.get("quiet", false):
								n.queue_free()
							else:
								effects.explosion(n.position, 0.7)
								Audio.play("explosion", -6.0)
								n.die()
								if f.get("pts", 0) > 0:
									effects.float_text(n.position + Vector2(0, -16), "+%d" % f["pts"], Defs.GOOD, 14)
					"structure":
						var s: StructureNode = s_nodes.get(f["id"])
						var p := _struct_pos(f["pos"])
						effects.explosion(p, 1.6)
						Audio.play("big_explosion")
						cam.shake(10.0)
						if s != null:
							s_nodes.erase(f["id"])
							var tw := s.create_tween()
							tw.tween_property(s, "modulate:a", 0.0, 0.5)
							tw.tween_callback(s.queue_free)
						map_view.set_ruins(state.ruins)
						_last_ruins = state.ruins.size()
					"unit":
						var u: UnitNode = u_nodes.get(f["id"])
						if u != null:
							u_nodes.erase(f["id"])
							effects.explosion(u.position, 0.8)
							Audio.play("explosion", -4.0)
							u.die()
					"carrier":
						var c: CarrierNode = c_nodes.get(f["id"])
						if c != null:
							c_nodes.erase(f["id"])
							effects.explosion(c.position, 2.0)
							effects.explosion(c.position + Vector2(14, 4), 1.4)
							Audio.play("big_explosion")
							cam.shake(12.0)
							c.sink()
						hud.banner("CARRIER SUNK", Defs.GOLD, 1.6)
			"exit":
				var n2: AircraftNode = e_nodes.get(f["id"])
				if n2 != null:
					e_nodes.erase(f["id"])
					n2.depart()
			"log":
				hud.log_advance()


# --------------------------------------------------------------------------------------------
# Overlays
# --------------------------------------------------------------------------------------------

func _weapon_range_set(pos: Vector2i, r: int) -> Dictionary:
	var out := {}
	for h in Hex.in_range(pos, r):
		if state.tiles.has(h):
			out[h] = true
	return out


func _draw_low(l: DrawLayer) -> void:
	if state == null:
		return
	var tiles := state.tiles
	if show_coverage or mode == Mode.BUILD:
		var cov := {}
		for s in state.structures.values():
			if Defs.STRUCTURES[s["kind"]].has("weapon"):
				for h in Hex.in_range(s["pos"], state.s_range(s)):
					if tiles.has(h):
						cov[h] = cov.get(h, 0) + 1
		for u in state.units.values():
			if u["kind"] == "frigate":
				for h in Hex.in_range(u["pos"], state.u_range(u)):
					if tiles.has(h):
						cov[h] = cov.get(h, 0) + 1
		for h in cov:
			l.hex_fill(h, _top(h), Color(UITheme.ACCENT, minf(0.06 + 0.05 * cov[h], 0.3)))
		l.region_outline(cov, tiles, Color(UITheme.ACCENT, 0.55), 1.5)
		if show_coverage:
			l.region_outline(state.radar_cov, tiles, Color(0.55, 0.75, 1.0, 0.45), 1.5)
	if mode == Mode.BUILD and hover != Hex.INVALID:
		var err := state.build_check(build_kind, hover)
		var col := UITheme.ACCENT if err == "" else Defs.ENEMY_COLOR
		l.hex_fill(hover, _top(hover), Color(col, 0.35))
		var def: Dictionary = Defs.STRUCTURES[build_kind]
		if def.has("range"):
			var r: int = def["range"] + (1 if state.terrain(hover) == "hills" else 0)
			l.region_outline(_weapon_range_set(hover, r), tiles, Color(Defs.GOLD, 0.9), 2.0)
		if build_kind == "radar":
			var v: int = def["vision"] + (2 if state.has_tech("improved_radar") else 0)
			var t := state.terrain(hover)
			v += 1 if t == "hills" else (2 if t == "mountain" else 0)
			v += 1 if state.has_tech("coastwatchers") else 0
			l.region_outline(_weapon_range_set(hover, v), tiles, Color(0.55, 0.75, 1.0, 0.9), 2.0)
	if mode == Mode.UNIT:
		for h in _reach:
			l.hex_fill(h, _top(h), Color(UITheme.ACCENT, 0.16))
		l.region_outline(_reach, tiles, Color(UITheme.ACCENT, 0.8), 2.0)
	if mode == Mode.RECON:
		for p in state.recon_sources():
			l.region_outline(_weapon_range_set(p, Defs.RECON_RANGE), tiles, Color(Defs.GOLD, 0.35), 1.5)
		if hover != Hex.INVALID:
			var area := _weapon_range_set(hover, Defs.RECON_RADIUS)
			var ok := state.recon_check(hover) == ""
			for h in area:
				l.hex_fill(h, _top(h), Color(Defs.GOLD if ok else Defs.ENEMY_COLOR, 0.14))
			l.region_outline(area, tiles, Color(Defs.GOLD if ok else Defs.ENEMY_COLOR, 0.9), 2.0)
	if mode == Mode.STRIKE and strike_sid >= 0 and state.structures.has(strike_sid):
		var s: Dictionary = state.structures[strike_sid]
		l.region_outline(_weapon_range_set(s["pos"], state.strike_range(s)), tiles, Color(Defs.ENEMY_COLOR, 0.5), 1.5)
	if selected != Hex.INVALID and state.tiles.has(selected):
		var s2 := state.structure_at(selected)
		if not s2.is_empty() and Defs.STRUCTURES[s2["kind"]].has("weapon") and mode != Mode.BUILD:
			l.region_outline(_weapon_range_set(s2["pos"], state.s_range(s2)), tiles, Color(Defs.GOLD, 0.8), 2.0)
		elif not s2.is_empty() and s2["kind"] == "radar":
			l.region_outline(_weapon_range_set(s2["pos"], state.s_vision(s2)), tiles, Color(0.55, 0.75, 1.0, 0.8), 2.0)
		l.hex_outline(_top(selected), Color(1, 1, 1, 0.95), 2.5)
	if hover != Hex.INVALID and mode != Mode.BUILD:
		l.hex_outline(_top(hover), Color(1, 1, 1, 0.45), 1.5)


func _draw_top(l: DrawLayer) -> void:
	if state == null:
		return
	var t := Time.get_ticks_msec() / 1000.0
	if Settings.show_intents and not _animating:
		for e in state.enemies.values():
			if e["state"] == "rtb" or not state.enemy_detected(e):
				continue
			var n: AircraftNode = e_nodes.get(e["id"])
			if n == null:
				continue
			var th := state.ai.target_hex(state, e)
			if th == Hex.INVALID or th == e["pos"]:
				continue
			var tp := _top(th)
			var strong := n.hovered
			var col := Color(Defs.ENEMY_COLOR, 0.8 if strong else 0.45)
			l.draw_dashed_line(n.position, tp, col, 2.0 if strong else 1.4, 7.0)
			var dir := (tp - n.position).normalized()
			var tip := tp - dir * 4.0
			l.draw_colored_polygon(PackedVector2Array([tip, tip - dir * 9.0 + dir.orthogonal() * 4.5, tip - dir * 9.0 - dir.orthogonal() * 4.5]), col)
	if mode == Mode.UNIT:
		for eid in _targets:
			var n2: AircraftNode = e_nodes.get(eid)
			if n2 == null:
				continue
			var r := 19.0 + sin(t * 6.0) * 2.0
			l.draw_arc(n2.position, r, 0, TAU, 28, Color(Defs.GOLD, 0.95), 2.5, true)
			for k in 4:
				var a := k * PI * 0.5
				l.draw_line(n2.position + Vector2.RIGHT.rotated(a) * (r + 2), n2.position + Vector2.RIGHT.rotated(a) * (r + 8), Color(Defs.GOLD, 0.95), 2.0)
	if mode == Mode.STRIKE and strike_sid >= 0:
		for cid in state.strike_targets(strike_sid):
			var cn: CarrierNode = c_nodes.get(cid)
			if cn != null:
				l.draw_arc(cn.position, 30.0 + sin(t * 6.0) * 3.0, 0, TAU, 32, Color(Defs.GOLD, 0.95), 2.5, true)


# --------------------------------------------------------------------------------------------
# Menus and modals
# --------------------------------------------------------------------------------------------

func _open_modal(m: Modal) -> void:
	if _modal != null and is_instance_valid(_modal):
		_modal.queue_free()
	_modal = m
	hud.set_tooltip("")
	ui.add_child(m)
	m.open_anim()
	m.closed.connect(func():
		if _modal == m:
			_modal = null
		sync_view())


func open_research() -> void:
	if mode == Mode.OVER:
		return
	if _modal is ResearchPanel:
		_modal.close()
		return
	var p := ResearchPanel.new(state)
	p.research.connect(func(id):
		if _animating:
			return
		if state.research(id):
			Audio.play("research")
			p.refresh()
			hud.refresh()
			hud.show_selection(selected)
		else:
			Audio.play("error"))
	_open_modal(p)


func open_pause() -> void:
	if _modal != null and is_instance_valid(_modal):
		return
	var p := PauseMenu.new(state.seed_value)
	p.save_requested.connect(func():
		if _animating or state.phase != "player":
			hud.toast("Cannot save during the enemy phase")
		elif Session.save_game(state):
			hud.toast("Game saved")
		p.close())
	p.quit_to_menu.connect(func():
		_autosave()
		Session.to_menu())
	p.open_settings.connect(func(): _open_modal(SettingsPanel.new()))
	p.open_help.connect(func(): _open_modal(HowToPlayPanel.new()))
	_open_modal(p)


func _show_game_over() -> void:
	if mode != Mode.OVER:
		mode = Mode.OVER
		Session.delete_save()
		var rank := Session.add_score(state)
		Audio.play("victory" if state.result == "victory" else "defeat")
		hud.banner("VICTORY" if state.result == "victory" else "DEFEAT", Defs.GOLD if state.result == "victory" else Defs.ENEMY_COLOR, 2.0)
		await get_tree().create_timer(1.2).timeout
		state.set_meta("rank", rank)
	var p := GameOverPanel.new(state, state.get_meta("rank", -1))
	p.new_game.connect(func(): Session.start_new(0, state.difficulty))
	p.main_menu.connect(func(): Session.to_menu())
	p.keep_viewing.connect(func(): hud.toast("Press SPACE to reopen the summary"))
	_open_modal(p)


# --------------------------------------------------------------------------------------------
# Tutorial hints
# --------------------------------------------------------------------------------------------

func _maybe_hint() -> void:
	if not Settings.tutorial_hints or mode == Mode.OVER:
		return
	var key := ""
	var text := ""
	var has_airbase := false
	var has_units := not state.units.is_empty()
	for s in state.structures.values():
		if s["kind"] == "airbase":
			has_airbase = true
	var spotted := false
	for e in state.enemies.values():
		if state.enemy_detected(e):
			spotted = true
	if state.turn == 1:
		key = "start"
		text = "[b]Welcome, Commander.[/b] Pick a structure in [color=#4fd1c5]CONSTRUCT[/color] (or press 1-0) and click a hex to build. [b]Flak[/b] guards against low flyers, [b]Research Labs[/b] speed up research. Hover anything for details, then press [b]SPACE[/b] to end your turn."
	elif state.turn == 2:
		key = "research"
		text = "You have research points. Press [b]R[/b] to open the tree. [b]Guided Missiles[/b] unlocks SAM Sites, the answer to high-altitude bombers that flak can barely touch."
	elif spotted and state.wave >= 1:
		key = "intent"
		text = "[color=#ff7a7a]Enemy aircraft spotted![/color] Dashed red lines show their [b]intended targets[/b]. Your defenses fire automatically during the enemy phase. Press [b]V[/b] to see your coverage."
	elif has_airbase and not has_units:
		key = "airbase"
		text = "Select your [b]Airbase[/b] to train Interceptors. Fly them next to enemy aircraft and attack, or leave them idle to [b]patrol[/b]."
	elif has_units and state.wave >= 1:
		key = "units"
		text = "Select a squadron (or press [b]Tab[/b]) to see where it can fly. Ringed enemies can be attacked right away."
	elif state.wave >= 2 and state.turn >= 6:
		key = "adapt"
		text = "The enemy [b]adapts[/b]: it remembers where it took losses and counters your favorite weapons. Read the [color=#8cb8ff]HQ Intelligence[/color] report (bottom right) and diversify your defenses."
	elif state.turn >= 9:
		key = "carriers"
		text = "Enemy [b]carriers[/b] hide in the eastern sea. Find one with a [b]Recon Flight[/b], then strike it from an Airbase or Missile Battery. Sinking them all wins the war."
	if key != "" and not _hints.has(key):
		_hints[key] = true
		hud.show_hint(text)
