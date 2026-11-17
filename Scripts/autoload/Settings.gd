extends Node
## Persistent user settings (audio, animation speed, display) and global theme setup.

signal changed

var PATH := "user://sandbox_settings.cfg" if OS.get_cmdline_user_args().has("--sandbox") else "user://settings.cfg"
const SPEEDS := [1.0, 1.5, 2.5, 4.0]

var master_volume := 0.85
var music_volume := 0.65
var sfx_volume := 0.85
var anim_speed := 1.5
var skip_animations := false
var fullscreen := false
var edge_pan := false
var show_grid := true
var show_intents := true
var tutorial_hints := true


func _ready() -> void:
	UITheme.init()
	get_tree().root.theme = UITheme.theme
	_ensure_buses()
	load_settings()
	apply()


func _ensure_buses() -> void:
	for bus_name in ["Music", "SFX"]:
		if AudioServer.get_bus_index(bus_name) == -1:
			AudioServer.add_bus()
			var idx := AudioServer.bus_count - 1
			AudioServer.set_bus_name(idx, bus_name)
			AudioServer.set_bus_send(idx, "Master")
	# A limiter on the master bus keeps stacked explosions and music from clipping.
	if AudioServer.get_bus_effect_count(0) == 0:
		var limiter := AudioEffectHardLimiter.new()
		limiter.ceiling_db = -0.8
		limiter.pre_gain_db = 0.0
		AudioServer.add_bus_effect(0, limiter)


func apply() -> void:
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(master_volume, 0.0001)))
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Music"), linear_to_db(maxf(music_volume, 0.0001)))
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("SFX"), linear_to_db(maxf(sfx_volume, 0.0001)))
	if DisplayServer.get_name() != "headless":
		var want := DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED
		if DisplayServer.window_get_mode() != want and not (want == DisplayServer.WINDOW_MODE_WINDOWED and DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_MAXIMIZED):
			DisplayServer.window_set_mode(want)
	changed.emit()


func save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("audio", "master", master_volume)
	cfg.set_value("audio", "music", music_volume)
	cfg.set_value("audio", "sfx", sfx_volume)
	cfg.set_value("game", "anim_speed", anim_speed)
	cfg.set_value("game", "skip_animations", skip_animations)
	cfg.set_value("game", "edge_pan", edge_pan)
	cfg.set_value("game", "show_grid", show_grid)
	cfg.set_value("game", "show_intents", show_intents)
	cfg.set_value("game", "tutorial_hints", tutorial_hints)
	cfg.set_value("display", "fullscreen", fullscreen)
	cfg.save(PATH)


func load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(PATH) != OK:
		return
	master_volume = cfg.get_value("audio", "master", master_volume)
	music_volume = cfg.get_value("audio", "music", music_volume)
	sfx_volume = cfg.get_value("audio", "sfx", sfx_volume)
	anim_speed = cfg.get_value("game", "anim_speed", anim_speed)
	skip_animations = cfg.get_value("game", "skip_animations", skip_animations)
	edge_pan = cfg.get_value("game", "edge_pan", edge_pan)
	show_grid = cfg.get_value("game", "show_grid", show_grid)
	show_intents = cfg.get_value("game", "show_intents", show_intents)
	tutorial_hints = cfg.get_value("game", "tutorial_hints", tutorial_hints)
	fullscreen = cfg.get_value("display", "fullscreen", fullscreen)


func set_and_save(key: String, value) -> void:
	set(key, value)
	save_settings()
	apply()
