# game.gd

extends Node2D

@onready var player = $WorldContainer/Player # Ścieżka do gracza
@onready var game_over_layer = $GameOverLayer
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
