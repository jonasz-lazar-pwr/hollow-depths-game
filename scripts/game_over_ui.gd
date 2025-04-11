# game_over_ui.gd

extends CanvasLayer


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
