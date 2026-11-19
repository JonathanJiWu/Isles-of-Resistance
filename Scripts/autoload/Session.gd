extends Node
## Cross-scene session data: how the next game should start, save games and high scores.

## Tests pass "-- --sandbox" so they never touch the player's real save or Hall of Fame.
var SAVE_PATH := "user://sandbox_savegame.dat" if OS.get_cmdline_user_args().has("--sandbox") else "user://savegame.dat"
var SCORES_PATH := "user://sandbox_highscores.cfg" if OS.get_cmdline_user_args().has("--sandbox") else "user://highscores.cfg"
const MAX_SCORES := 8

var pending := {"mode": "new", "seed": 0, "difficulty": "veteran"}


func start_new(seed_value: int, difficulty: String, tutorial: bool = false) -> void:
	pending = {"mode": "new", "seed": seed_value, "difficulty": difficulty, "tutorial": tutorial}
	Transition.go("res://Scenes/Game.tscn")


func continue_game() -> void:
	pending = {"mode": "load"}
	Transition.go("res://Scenes/Game.tscn")


func to_menu() -> void:
	Transition.go("res://Scenes/Main.tscn")


func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


func save_game(st: GameState) -> bool:
	if st == null or st.result != "":
		return false
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		return false
	f.store_var(st.to_dict())
	f.close()
	return true


func load_game() -> GameState:
	if not has_save():
		return null
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return null
	var d = f.get_var(false)
	f.close()
	if typeof(d) != TYPE_DICTIONARY:
		return null
	return GameState.from_dict(d)


func save_summary() -> Dictionary:
	var st := load_game()
	if st == null:
		return {}
	return {"turn": st.turn, "wave": st.wave, "waves_total": st.waves_total,
		"difficulty": Defs.DIFFICULTY[st.difficulty]["name"], "score": st.score}


func delete_save() -> void:
	if has_save():
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))


func highscores() -> Array:
	var cfg := ConfigFile.new()
	if cfg.load(SCORES_PATH) != OK:
		return []
	return cfg.get_value("scores", "list", [])


## Records a finished campaign. Returns its rank (0-based) or -1 if it did not place.
func add_score(st: GameState) -> int:
	if st.score <= 0:
		return -1
	var list := highscores()
	var entry := {
		"score": st.score, "result": st.result, "difficulty": st.difficulty, "turn": st.turn,
		"waves": "%d/%d" % [st.wave, st.waves_total], "date": Time.get_date_string_from_system(), "seed": st.seed_value,
	}
	list.append(entry)
	list.sort_custom(func(a, b): return a["score"] > b["score"])
	var rank := list.find(entry)
	if list.size() > MAX_SCORES:
		list.resize(MAX_SCORES)
	if rank >= MAX_SCORES:
		rank = -1
	var cfg := ConfigFile.new()
	cfg.set_value("scores", "list", list)
	cfg.save(SCORES_PATH)
	return rank
