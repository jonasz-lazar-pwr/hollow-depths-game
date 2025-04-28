# title_screen.gd
extends Control

# Ścieżka do głównej sceny gry - upewnij się, że jest poprawna!
const GAME_SCENE_PATH = "res://assets/scenes/game.tscn"

# Nie potrzebujemy _ready ani _process w tym prostym menu

func _on_start_button_pressed():
	print("Start button pressed! Loading game scene...")
	# Zmień scenę na główną scenę gry
	var error = get_tree().change_scene_to_file(GAME_SCENE_PATH)
	if error != OK:
		printerr("Failed to change scene to game! Error code: ", error)


func _on_quit_button_pressed():
	print("Quit button pressed! Exiting application...")
	# Zamknij grę
	get_tree().quit()
