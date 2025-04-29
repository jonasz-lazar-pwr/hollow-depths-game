# game.gd

extends Node2D

@onready var player = $WorldContainer/Player # Ścieżka do gracza
@onready var game_over_layer = $GameOverLayer
@onready var pause_menu = $PauseMenuLayer/PauseMenu # Upewnij się, że ścieżka jest poprawna!
# lub: @onready var pause_menu_layer = $PauseMenuLayer
#@onready var world_container = $WorldContainer


# Called when the node enters the scene tree for the first time.
func _ready():
	if player:
		if player.has_signal("player_died"):
			player.player_died.connect(_on_player_died)
		else:
			printerr("Player node does not have 'player_died' signal!")
	else:
		printerr("Game script cannot find Player node at path $WorldContainer/Player!")

	if is_instance_valid(game_over_layer):
		game_over_layer.visible = false # Ukryj na starcie
	
	if pause_menu:
		pause_menu.hide()
	else:
		printerr("Game script cannot find PauseMenu node!")


func _on_player_died():
	print("Game Over sequence started.")

	# 1. Zatrzymaj główną logikę gry
	get_tree().paused = true

	# 2. Pokaż warstwę Game Over (która teraz zawiera efekt grayscale i napis)
	if is_instance_valid(game_over_layer):
		game_over_layer.visible = true
		print("GameOverLayer visibility set to true.") # Dodaj log dla pewności
	else:
		printerr("game_over_layer is not valid, cannot show Game Over screen!")

	# 3. TODO: Odtwórz dźwięk "Game Over"
	# 4. TODO: Przyciski Restart/Quit

# Ta funkcja przechwytuje input, który nie został obsłużony gdzie indziej
func _unhandled_input(event):
	# pauza / ESC
	if Input.is_action_just_pressed("ui_cancel"):
		if get_tree().paused:
			if pause_menu and pause_menu.visible:
				pause_menu.resume_game()
		else:
			get_tree().paused = true
			if pause_menu:
				pause_menu.show()
		get_viewport().set_input_as_handled()

	# przełącz ekwipunek klawiszem I
	if Input.is_action_just_pressed("ui_inventory"):
		print("DEBUG: wykryto I!")  # zobaczymy w konsoli
		var inv_ui = $UI/InventoryGridUI  
		inv_ui.visible = not inv_ui.visible
		get_viewport().set_input_as_handled()


#
#func _on_player_died():
	#print("Game Over sequence started.")
	## Upewnij się, że menu pauzy jest ukryte, gdy pojawi się Game Over
	#if pause_menu and pause_menu.visible:
		#pause_menu.hide()
	## ... (reszta logiki game over) ...
	#get_tree().paused = true
	## ... (reszta logiki game over) ...


func _on_InventoryButton_pressed():
 # Znajdź node z UI ekwipunku:
	var inv_ui = $UI/InventoryGridUI   # lub jeśli używasz SimpleInventoryUI: $UI/SimpleInventoryUI
	# Przełącz widoczność:
	inv_ui.visible = not inv_ui.visible
	
