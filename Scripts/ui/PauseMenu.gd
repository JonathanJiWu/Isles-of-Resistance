class_name PauseMenu
extends Modal
## In-game menu.

signal save_requested
signal quit_to_menu
signal open_settings
signal open_help


func _init(seed_value: int) -> void:
	super(Vector2(380, 0))
	title("PAUSED", "Map seed %d" % seed_value)
	for item in [["Resume", "resume"], ["Save Game", "save"], ["How to Play", "help"], ["Settings", "settings"], ["Main Menu", "menu"], ["Quit to Desktop", "quit"]]:
		var b := UITheme.button(item[0], 300, 44)
		b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		b.pressed.connect(_on_item.bind(item[1]))
		content.add_child(b)
	var note := UITheme.label("Your campaign autosaves at the start of every turn.", 12, UITheme.TEXT_DIM)
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(note)


func _on_item(action: String) -> void:
	Audio.play("click")
	match action:
		"resume":
			close()
		"save":
			save_requested.emit()
		"help":
			open_help.emit()
		"settings":
			open_settings.emit()
		"menu":
			quit_to_menu.emit()
		"quit":
			get_tree().quit()
