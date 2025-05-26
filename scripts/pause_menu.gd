# pause_menu.gd
extends Control

const TITLE_SCREEN_PATH = "res://assets/scenes/title_screen.tscn"

# Need a reference to the main game node to call save/load
# Assuming Game node is the grandparent: PauseMenuLayer -> Game
@onready var game_node = get_parent().get_parent() as Node2D

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

func _on_save_game_button_pressed():
    if game_node and game_node.has_method("save_game"):
        game_node.save_game()
        # Optionally keep menu open or close it
        # resume_game()
    else:
        printerr("PauseMenu cannot find game_node or save_game method!")

func _on_load_game_button_pressed():
    if game_node and game_node.has_method("load_game"):
        # Unpause BEFORE loading if loading from pause menu
        get_tree().paused = false
        hide() # Hide menu immediately
        # Call load_game on the main game node
        game_node.load_game()
        # Loading might change nodes, so don't assume 'self' is still valid in complex scenarios
    else:
        printerr("PauseMenu cannot find game_node or load_game method!")

func _unhandled_input(event):
    if Input.is_action_just_pressed("ui_cancel") and get_tree().paused and self.visible: # Only resume if pause menu is visible
        resume_game()
        get_viewport().set_input_as_handled()
