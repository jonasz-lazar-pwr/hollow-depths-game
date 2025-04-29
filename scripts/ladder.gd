extends Area2D

signal entered_ladder
signal exited_ladder

func _ready() -> void:
	add_to_group("ladders")

func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		entered_ladder.emit(body)

func _on_body_exited(body: Node) -> void:
	if body.is_in_group("player"):
		exited_ladder.emit(body)
