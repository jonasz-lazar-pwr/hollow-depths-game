extends Area2D

signal entered_ladder
signal exited_ladder

func _on_body_entered(body: Node2D) -> void:
    entered_ladder.emit()

func _on_body_exited(body: Node2D) -> void:
    exited_ladder.emit()
