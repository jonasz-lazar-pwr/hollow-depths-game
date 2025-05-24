# game_over_ui.gd
extends CanvasLayer

const TITLE_SCREEN_PATH = "res://assets/scenes/title_screen.tscn"

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass


# Ta funkcja zostanie wywołana po kliknięciu przycisku "RESTART"
func _on_restart_button_pressed():
	print("Restart button pressed!")
	# WAŻNE: Najpierw od-pauzuj grę, inaczej przeładowana scena też będzie spauzowana!
	get_tree().paused = false
	# Przeładuj bieżącą scenę (czyli całą scenę 'game.tscn')
	var error = get_tree().reload_current_scene()
	if error != OK:
		printerr("Failed to reload scene! Error code: ", error)


func _on_quit_button_pressed() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file(TITLE_SCREEN_PATH)
