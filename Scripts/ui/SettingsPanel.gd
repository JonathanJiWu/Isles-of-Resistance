class_name SettingsPanel
extends Modal
## Audio, animation and display settings.


func _init() -> void:
	super(Vector2(520, 0))
	title("SETTINGS")
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 24)
	grid.add_theme_constant_override("v_separation", 12)
	content.add_child(grid)
	_slider(grid, "Master volume", "master_volume")
	_slider(grid, "Music volume", "music_volume")
	_slider(grid, "Effects volume", "sfx_volume")
	grid.add_child(UITheme.label("Battle animation speed", 15))
	var speed := OptionButton.new()
	speed.focus_mode = Control.FOCUS_NONE
	var names := ["Normal", "Fast", "Faster", "Fastest"]
	for i in Settings.SPEEDS.size():
		speed.add_item("%s (%sx)" % [names[i], str(Settings.SPEEDS[i])], i)
		if is_equal_approx(Settings.SPEEDS[i], Settings.anim_speed):
			speed.select(i)
	speed.item_selected.connect(func(i): Settings.set_and_save("anim_speed", Settings.SPEEDS[i]))
	grid.add_child(speed)
	_toggle(grid, "Skip battle animations", "skip_animations")
	_toggle(grid, "Show enemy intent lines", "show_intents")
	_toggle(grid, "Show hex grid", "show_grid")
	_toggle(grid, "Edge-of-screen panning", "edge_pan")
	_toggle(grid, "Tutorial hints", "tutorial_hints")
	grid.add_child(UITheme.label("One-minute field training", 15))
	var replay := UITheme.button("Replay in next campaign" if Settings.tutorial_done else "Runs in next campaign", 0, 32)
	replay.add_theme_font_size_override("font_size", 13)
	replay.disabled = not Settings.tutorial_done
	replay.tooltip_text = "Run the one-minute interactive tutorial at the start of your next new campaign."
	replay.pressed.connect(func():
		Audio.play("click")
		Settings.set_and_save("tutorial_done", false)
		replay.text = "Runs in next campaign"
		replay.disabled = true)
	grid.add_child(replay)
	_toggle(grid, "Fullscreen", "fullscreen")
	var done := UITheme.button("Done", 160, 40)
	done.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	done.pressed.connect(func(): Audio.play("click"); close())
	content.add_child(done)


func _slider(grid: GridContainer, text: String, key: String) -> void:
	grid.add_child(UITheme.label(text, 15))
	var s := HSlider.new()
	s.min_value = 0.0
	s.max_value = 1.0
	s.step = 0.05
	s.value = Settings.get(key)
	s.custom_minimum_size = Vector2(220, 24)
	s.focus_mode = Control.FOCUS_NONE
	s.value_changed.connect(func(v):
		Settings.set(key, v)
		Settings.apply())
	s.drag_ended.connect(func(_c):
		Settings.save_settings()
		Audio.play("click"))
	grid.add_child(s)


func _toggle(grid: GridContainer, text: String, key: String) -> void:
	grid.add_child(UITheme.label(text, 15))
	var c := CheckButton.new()
	c.button_pressed = Settings.get(key)
	c.focus_mode = Control.FOCUS_NONE
	c.toggled.connect(func(v):
		Audio.play("click")
		Settings.set_and_save(key, v))
	grid.add_child(c)
