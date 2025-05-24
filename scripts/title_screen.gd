# title_screen.gd
extends Control

# Paths defined as constants for clarity
const GAME_SCENE_PATH = "res://assets/scenes/game.tscn"
const SAVE_PATH = "res://savegame.res" # Make sure this matches game.gd

# Get references to the buttons (use % syntax if they are direct children,
# otherwise adjust paths or use @onready)
@onready var continue_button: Button = $LoadGameButton # Adjust path if needed
@onready var new_game_button: Button = $NewGameButton   # Adjust path if needed
@onready var quit_button: Button = $QuitButton       # Adjust path if needed

func _ready():
	# Disable the "Continue" button if no save file exists
	continue_button.disabled = not FileAccess.file_exists(SAVE_PATH)


func _on_new_game_button_pressed():
	print("New Game button pressed!")
	# Delete existing save file if it exists
	if FileAccess.file_exists(SAVE_PATH):
		var err = DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
		if err == OK:
			print("Existing save file deleted.")
		else:
			printerr("Failed to delete existing save file! Error code: ", err)
			# Optionally show an error to the user, but proceed anyway for a new game

	# Change scene to start the game fresh
	var error = get_tree().change_scene_to_file(GAME_SCENE_PATH)
	if error != OK:
		printerr("Failed to change scene to game! Error code: ", error)


func _on_continue_button_pressed(): # Renamed from _on_start_button_pressed
	print("Continue button pressed! Loading game scene...")
	# Just change scene. game.gd's _ready() will handle loading the save.
	var error = get_tree().change_scene_to_file(GAME_SCENE_PATH)
	if error != OK:
		printerr("Failed to change scene to game! Error code: ", error)


func _on_quit_button_pressed():
	print("Quit button pressed! Exiting application...")
	get_tree().quit()
