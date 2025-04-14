extends Area2D

signal entered_ladder
signal exited_ladder

func _on_body_entered(body):
	if body.is_in_group("player"): # albo: if body == get_node("/root/Player") lub == self
		entered_ladder.emit(body)

func _on_body_exited(body):
	if body.is_in_group("player"):
		exited_ladder.emit(body)
