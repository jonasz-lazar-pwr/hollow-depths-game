extends Sprite2D

@export var block_texture: Texture

const DISSOLVE_TIME: float = 3.0
var elapsed_time: float = 0.0

func _ready():
	if block_texture:
		self.texture = block_texture # <-- TUTAJ ustawiasz właściwość tekstury sprite'a poprawnie
	material.set_shader_parameter("progress", 0.0)
	var tween = create_tween()
	tween.tween_property(material, "shader_parameter/progress", 1.0, DISSOLVE_TIME)
	tween.finished.connect(queue_free)
