class_name TutorialCoach
extends Control
## Field training: the roughly one-minute interactive tutorial that opens a new campaign.
## Five short steps teach the controls and loop that actually exist: the situation and the
## capital, the camera, building a defence, the coverage overlay, and the objective and ending
## a turn. Each step completes only when the player does the thing. Skippable at any time.
## The game does not support controllers, so only keyboard and mouse controls are shown.

signal finished(skipped: bool)

const STEPS := [
	{"id": "situation", "secs": 12.0},
	{"id": "camera", "secs": 12.0},
	{"id": "build", "secs": 15.0},
	{"id": "coverage", "secs": 9.0},
	{"id": "objective", "secs": 12.0},
]
const KEY := "[color=#ffd166][b]%s[/b][/color]"

var game                       # the Game controller (untyped to avoid a cyclic class reference)
var step := -1
var elapsed := 0.0
var step_time := 0.0
var highlight_hexes: Array = []
var done_tasks := {}
var _ui_target: Control = null
var _panel: PanelContainer
var _title: Label
var _counter: Label
var _body: RichTextLabel
var _tasks: VBoxContainer
var _segments: Array = []
var _cam_start := Vector2.ZERO
var _zoom_start := 1.0
var _built_start := 0
var _capital_seen := false
var _t := 0.0
var _closing := false


func _init(p_game) -> void:
	game = p_game
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()


func _build() -> void:
	_panel = PanelContainer.new()
	_panel.add_theme_stylebox_override("panel", UITheme.box(Color(0.03, 0.07, 0.11, 0.96), UITheme.ACCENT, 2, 9, Vector4(18, 12, 18, 14)))
	_panel.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_panel.offset_left = -330
	_panel.offset_right = 330
	_panel.offset_bottom = -14
	_panel.offset_top = -14
	_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_panel)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 6)
	_panel.add_child(vb)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 10)
	vb.add_child(head)
	head.add_child(UITheme.label("FIELD TRAINING", 13, Color(1.0, 0.45, 0.75), UITheme.font_bold))
	_counter = UITheme.label("", 12, UITheme.TEXT_DIM)
	_counter.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(_counter)
	var skip := UITheme.button("Skip tutorial", 0, 28)
	skip.add_theme_font_size_override("font_size", 13)
	skip.tooltip_text = "End the training now. You can replay it from the main menu (Field Training) or Settings."
	skip.pressed.connect(func():
		Audio.play("click")
		_finish(true))
	head.add_child(skip)
	var seg_row := HBoxContainer.new()
	seg_row.add_theme_constant_override("separation", 4)
	vb.add_child(seg_row)
	for i in STEPS.size():
		var r := ColorRect.new()
		r.custom_minimum_size = Vector2(0, 4)
		r.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		r.mouse_filter = Control.MOUSE_FILTER_IGNORE
		seg_row.add_child(r)
		_segments.append(r)
	_title = UITheme.label("", 21, UITheme.TEXT, UITheme.font_bold)
	vb.add_child(_title)
	_body = RichTextLabel.new()
	_body.bbcode_enabled = true
	_body.fit_content = true
	_body.scroll_active = false
	_body.custom_minimum_size = Vector2(620, 0)
	_body.add_theme_font_size_override("normal_font_size", 15)
	_body.add_theme_font_size_override("bold_font_size", 15)
	_body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_child(_body)
	_tasks = VBoxContainer.new()
	_tasks.add_theme_constant_override("separation", 2)
	vb.add_child(_tasks)


func start() -> void:
	elapsed = 0.0
	_enter(0)


func is_active() -> bool:
	return step >= 0 and not _closing


## Called by the game for events that are not visible in the state (keys, end of turn).
func notify(what: String) -> void:
	if not is_active():
		return
	match what:
		"capital":
			_capital_seen = true
		"end_turn":
			# Ending the turn always closes the training: at the last step it is the final task;
			# earlier, the player evidently knows the basics already.
			_complete_task("end")
			_finish(STEPS[step]["id"] != "objective")


func _enter(i: int) -> void:
	step = i
	step_time = 0.0
	done_tasks = {}
	highlight_hexes = []
	_ui_target = null
	var st: GameState = game.state
	var cap: Dictionary = st.capital()
	for k in _segments.size():
		(_segments[k] as ColorRect).color = UITheme.ACCENT if k < i else (Color(1.0, 0.45, 0.75) if k == i else Color(1, 1, 1, 0.12))
	for c in _tasks.get_children():
		c.queue_free()
	var tasks: Array = []
	match STEPS[i]["id"]:
		"situation":
			_title.text = "Quarantine declared"
			_body.text = ("[color=#ff8fc7]%s[/color]\nThe Celestine Commonwealth has declared a quarantine of the Lantern Strait. You command Tessera's [b]Air Defense Command[/b]. Keep [color=#ffd166][b]%s[/b][/color], the gold-ringed capital, standing: if it falls, the war is lost. Raids come in from the east."
				% [EnvGen.theater_title(st.env), cap.get("name", "Lumen")])
			tasks = [["capital", "Find the capital: press %s, or click %s on the map" % [KEY % "H", KEY % cap.get("name", "Lumen")]]]
			if not cap.is_empty():
				highlight_hexes = [cap["pos"]]
		"camera":
			_title.text = "Look around"
			_body.text = "Scan the islands before the first raid. Radars and cities light up what you can see; the dark is unexplored."
			tasks = [["pan", "Pan: %s or the arrow keys, or drag with the %s" % [KEY % "W A S D", KEY % "right mouse button"]],
				["zoom", "Zoom: %s or %s / %s" % [KEY % "mouse wheel", KEY % "Q", KEY % "E"]]]
			_cam_start = game.cam.position
			_zoom_start = game.cam.target_zoom
		"build":
			_title.text = "Build a defense"
			_body.text = "Your defenses fire on their own whenever raiders come in range. A [b]Flak Battery[/b] shreds low flyers: drones, helicopters and sea-skimming missiles."
			tasks = [["build", "Press %s or click %s in CONSTRUCT, then click a highlighted hex" % [KEY % "1", KEY % "Flak Battery"]]]
			highlight_hexes = _suggest_sites(st)
			_built_start = int(st.stats.get("built", 0))
			_ui_target = game.hud.build_button("flak")
		"coverage":
			_title.text = "Check your coverage"
			_body.text = "Know where your guns reach before the raid arrives. Once enemies are spotted, red dashed lines show where they are heading. Hover or click anything for details."
			tasks = [["coverage", "Press %s or click %s at the top" % [KEY % "V", KEY % "Coverage"]]]
			_ui_target = game.hud.coverage_button()
		"objective":
			_title.text = "Your objective"
			_body.text = ("Hold out for [b]%d waves[/b], or find and sink every enemy carrier in the eastern sea. The [b]Wave[/b] counter at the top shows when the next raid launches. Raids grow, and they adapt to the defenses they have seen."
				% st.waves_total)
			tasks = [["end", "End your turn: press %s or click %s" % [KEY % "SPACE", KEY % "END TURN"]]]
			_ui_target = game.hud.end_turn_button()
	for tk in tasks:
		var l := RichTextLabel.new()
		l.bbcode_enabled = true
		l.fit_content = true
		l.scroll_active = false
		l.custom_minimum_size = Vector2(620, 0)
		l.add_theme_font_size_override("normal_font_size", 14)
		l.add_theme_font_size_override("bold_font_size", 14)
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		l.set_meta("task", tk[0])
		l.set_meta("text", tk[1])
		_tasks.add_child(l)
	_refresh_tasks()
	_update_counter()


func _refresh_tasks() -> void:
	for l in _tasks.get_children():
		if not l.has_meta("task"):
			continue
		var tid: String = l.get_meta("task")
		var mark := "[color=#7ee28a]✔[/color]" if done_tasks.has(tid) else "[color=#4fd1c5]▸[/color]"
		l.text = "%s %s" % [mark, l.get_meta("text")]


func _complete_task(tid: String) -> void:
	if done_tasks.has(tid):
		return
	done_tasks[tid] = true
	_refresh_tasks()


func _update_counter() -> void:
	var left := maxf(0.0, float(STEPS[step]["secs"]) - step_time)
	for k in range(step + 1, STEPS.size()):
		left += float(STEPS[k]["secs"])
	_counter.text = "Step %d of %d · about %d s left" % [step + 1, STEPS.size(), int(ceil(left / 5.0) * 5.0)]


func _suggest_sites(st: GameState) -> Array:
	var cap: Dictionary = st.capital()
	if cap.is_empty():
		return []
	var cands: Array = []
	for h in Hex.in_range(cap["pos"], 3):
		if h == cap["pos"] or not st.tiles.has(h) or not st.explored.has(h):
			continue
		if not st.structure_at(h).is_empty() or st.is_water(h) or st.terrain(h) == "mountain":
			continue
		var sc: float = Hex.to_pixel(h).x - Hex.to_pixel(cap["pos"]).x
		sc += 25.0 if st.terrain(h) == "hills" else 0.0
		sc -= Hex.distance(h, cap["pos"]) * 8.0
		cands.append([sc, h])
	cands.sort_custom(func(a, b): return a[0] > b[0])
	var out: Array = []
	for c in cands.slice(0, 3):
		out.append(c[1])
	return out


func _process(delta: float) -> void:
	if not is_active():
		return
	_t += delta
	elapsed += delta
	step_time += delta
	_check()
	if is_active():
		_update_counter()
	queue_redraw()


func _check() -> void:
	var st: GameState = game.state
	match STEPS[step]["id"]:
		"situation":
			var cap: Dictionary = st.capital()
			if _capital_seen or (not cap.is_empty() and game.selected == cap["pos"]):
				_complete_task("capital")
				_advance()
		"camera":
			if game.cam.position.distance_to(_cam_start) > 110.0:
				_complete_task("pan")
			if absf(game.cam.target_zoom - _zoom_start) > 0.08:
				_complete_task("zoom")
			if done_tasks.has("pan") and done_tasks.has("zoom"):
				_advance()
		"build":
			if int(st.stats.get("built", 0)) > _built_start:
				_complete_task("build")
				_advance()
		"coverage":
			if game.show_coverage:
				_complete_task("coverage")
				_advance()


func _advance() -> void:
	Audio.play("research", -6.0)
	if step + 1 >= STEPS.size():
		_finish(false)
		return
	_enter(step + 1)


func _finish(skipped: bool) -> void:
	if _closing:
		return
	_closing = true
	highlight_hexes = []
	_ui_target = null
	finished.emit(skipped)


func _draw() -> void:
	if _ui_target == null or not is_instance_valid(_ui_target) or not _ui_target.is_visible_in_tree():
		return
	var r := _ui_target.get_global_rect()
	var inv := get_global_transform_with_canvas().affine_inverse()
	var rect := Rect2(inv * r.position, r.size).grow(4.0 + 2.0 * sin(_t * 5.0))
	var col := Color(1.0, 0.45, 0.75, 0.55 + 0.35 * sin(_t * 5.0))
	draw_rect(rect, col, false, 3.0)
	draw_rect(rect.grow(4.0), Color(col, 0.18), false, 4.0)
