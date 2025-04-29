# pause_menu.gd
extends Control

# Ścieżka do sceny menu głównego - upewnij się, że jest poprawna!
const TITLE_SCREEN_PATH = "res://assets/scenes/title_screen.tscn" # <-- Popraw, jeśli zapisałeś gdzie indziej!

# Funkcja do ukrywania menu i odpauzowywania gry
func resume_game():
	get_tree().paused = false
	hide() # Ukrywa węzeł PauseMenu (i jego dzieci)

# Funkcja do wyjścia do menu głównego
func quit_to_menu():
	# WAŻNE: Najpierw odpauzuj, zanim zmienisz scenę
	get_tree().paused = false
	var error = get_tree().change_scene_to_file(TITLE_SCREEN_PATH)
	if error != OK:
		printerr("Failed to change scene to title screen! Error code: ", error)

# Podłącz sygnały przycisków do tych funkcji w edytorze!
func _on_resume_button_pressed():
	print("Resume button pressed")
	resume_game()


func _on_quit_to_menu_button_pressed():
	print("Quit to Menu button pressed")
	quit_to_menu()

# Można też dodać obsługę ESC do zamknięcia menu pauzy
func _unhandled_input(event):
	if Input.is_action_just_pressed("ui_cancel") and get_tree().paused:
		resume_game()
		get_viewport().set_input_as_handled() # Zapobiega przetworzeniu tego samego inputu gdzie indziej
