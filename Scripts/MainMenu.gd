extends Control

func _on_StartButton_pressed():
	print("Game Starting...")
	# Add logic here to transition to gameplay

func _on_ExitButton_pressed():
	get_tree().quit()


func _on_exit_button_pressed():
		get_tree().quit()
