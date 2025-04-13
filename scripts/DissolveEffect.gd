# DissolveEffect.gd (Poprawiony)
extends Sprite2D

# Zmieniamy nazwę eksportowanej zmiennej, aby uniknąć konfliktu z wbudowaną 'texture'
# I usuwamy niestandardowy setter/getter.
@export var initial_texture: Texture = null

const DISSOLVE_TIME: float = 3.0

func _ready() -> void:
	# 1. Przypisz otrzymaną teksturę (powinna to być AtlasTexture z player.gd)
	#    bezpośrednio do właściwości 'texture' tego Sprite2D.
	if initial_texture:
		texture = initial_texture
	else:
		printerr("DissolveEffect: Nie otrzymano initial_texture!")
		# Możesz tu dodać jakąś domyślną teksturę błędu lub po prostu usunąć węzeł
		queue_free()
		return # Zakończ _ready, jeśli nie ma tekstury

	# 2. Duplikacja materiału, aby uniknąć współdzielenia go przez różne instancje
	#    (To jest dobra praktyka, zostawiamy)
	if material:
		material = material.duplicate()
	else:
		printerr("DissolveEffect: Brak przypisanego materiału!")
		# Możesz tu dodać domyślny materiał lub usunąć węzeł
		queue_free()
		return # Zakończ _ready, jeśli nie ma materiału


	# 3. Ustawienie początkowe shadera i tween
	material.set_shader_parameter("progress", 0.0)
	var tween = create_tween()
	# Upewnij się, że twój materiał w DissolveMaterial.tres ma shader TileDissolve.gdshader
	# i że shader ma uniform 'progress'
	tween.tween_property(material, "shader_parameter/progress", 1.0, DISSOLVE_TIME)
	tween.finished.connect(queue_free)
