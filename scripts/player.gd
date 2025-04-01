extends CharacterBody2D

const SPEED = 50.0
const JUMP_VELOCITY = -75.0
const CLIMB_SPEED = 30.0
const DIG_REACH = 1
const LADDER_REACH = 2 # Zasięg stawiania drabin (w kafelkach)

var ladder_stack = 0
var inventory = {"ladder": 10} # Przykładowy startowy ekwipunek

@export var ladder_scene: PackedScene
@export var ground_tilemap: TileMapLayer

func _ready() -> void:
	if not ground_tilemap:
		printerr("Player: Ground TileMapLayer not assigned!")
	print("Player ready at: ", global_position, " Ladders:", inventory.get("ladder", 0))

	# Podłączanie sygnałów do drabin już istniejących na scenie przy starcie
	for ladder in get_tree().get_nodes_in_group("ladders"):
		if not ladder.entered_ladder.is_connected(_on_ladder_entered):
			ladder.entered_ladder.connect(_on_ladder_entered)
		if not ladder.exited_ladder.is_connected(_on_ladder_exited):
			ladder.exited_ladder.connect(_on_ladder_exited)

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("dig"):
		handle_digging()
	# Zmieniono na globalną pozycję myszy w handle_ladder_placement
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		handle_ladder_placement()

func _physics_process(delta: float) -> void:
	if not is_on_floor() and ladder_stack == 0:
		velocity += get_gravity() * delta / 6 # Uwaga: get_gravity() może nie być zdefiniowane, użyj ProjectSettings.get_setting("physics/2d/default_gravity") * ProjectSettings.get_setting("physics/2d/default_gravity_vector").y jeśli potrzeba

	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = JUMP_VELOCITY

	var direction_x = Input.get_axis("left", "right")
	if direction_x:
		velocity.x = direction_x * SPEED
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)

	if ladder_stack >= 1:
		set_collision_mask_value(1, false)
		velocity.y = 0
		var direction_y = Input.get_axis("up", "down")
		velocity.y = direction_y * CLIMB_SPEED

		if direction_y != 0 or direction_x != 0:
			$AnimatedSprite2D.animation = "climb"
			$AnimatedSprite2D.play()
			$AnimatedSprite2D.speed_scale = 1
		else:
			$AnimatedSprite2D.animation = "climb"
			$AnimatedSprite2D.pause()
			$AnimatedSprite2D.frame = 0

		if direction_x != 0:
			$AnimatedSprite2D.flip_h = direction_x < 0

	else:
		set_collision_mask_value(1, true)
		if is_on_floor():
			if direction_x != 0:
				$AnimatedSprite2D.animation = "walk"
				$AnimatedSprite2D.flip_h = direction_x < 0
				$AnimatedSprite2D.play()
			else:
				$AnimatedSprite2D.animation = "idle"
				$AnimatedSprite2D.play()
		else:
			# Proponuję idle lub fall animation tutaj zamiast walk/idle
			$AnimatedSprite2D.animation = "idle" # Możesz chcieć zmienić na "fall"
			$AnimatedSprite2D.play()

	move_and_slide()


func handle_digging():
	if not ground_tilemap: return
	var mouse_pos = get_global_mouse_position()
	var target_map_coords = ground_tilemap.local_to_map(mouse_pos)
	var player_map_coords = ground_tilemap.local_to_map(global_position)

	var dx = abs(target_map_coords.x - player_map_coords.x)
	var dy = abs(target_map_coords.y - player_map_coords.y)

	if dx <= DIG_REACH and dy <= DIG_REACH:
		var tile_data = ground_tilemap.get_cell_tile_data(target_map_coords)
		if tile_data:
			var is_diggable = tile_data.get_custom_data("diggable")
			if is_diggable:
				print("Digging tile at map coordinates: ", target_map_coords)
				var specific_dig_time = tile_data.get_custom_data("dig_time") # Ta zmienna nie jest używana?
				# Jeśli chcesz opóźnienie, musisz zaimplementować timer lub yield
				# $AnimatedSprite2D.flip_h = mouse_pos.x < player_map_coords.x # Powinno być global_position.x?
				$AnimatedSprite2D.flip_h = mouse_pos.x < global_position.x
				$AnimatedSprite2D.play("dig") # Użyj play() zamiast przypisania animation
				ground_tilemap.set_cell(target_map_coords, -1) # Warstwa 0 domyślnie
			else:
				print("Tile at ", target_map_coords, " is not diggable.")
		else:
			print("No tile data to dig at map coordinates: ", target_map_coords)
	else:
		print("Target tile at ", target_map_coords, " is too far from player at ", player_map_coords)


func handle_ladder_placement() -> void:
	if not ground_tilemap or not ladder_scene:
		printerr("Ground TileMapLayer or Ladder Scene not assigned!")
		return

	if inventory.get("ladder", 0) <= 0:
		print("No ladders in inventory.")
		return

	var mouse_pos = get_global_mouse_position()
	var target_map_coords = ground_tilemap.local_to_map(mouse_pos)
	var player_map_coords = ground_tilemap.local_to_map(global_position)

	var dx = target_map_coords.x - player_map_coords.x
	var dy = target_map_coords.y - player_map_coords.y

	var is_adjacent = (
		(dx == 0 and dy == 1) or # pod graczem
		(dx == 1 and dy == 0) or # prawo
		(dx == -1 and dy == 0)   # lewo
	)

	if is_adjacent:
		# Sprawdź, czy komórka na TileMapie jest pusta (Source ID -1 oznacza pusty)
		if ground_tilemap.get_cell_source_id(target_map_coords) == -1:
			var ladder_world_pos = ground_tilemap.map_to_local(target_map_coords)

			var ladder_instance = ladder_scene.instantiate()
			ladder_instance.position = ladder_world_pos
			# Ważne: Podłączanie sygnałów do NOWEJ instancji drabiny
			if not ladder_instance.entered_ladder.is_connected(_on_ladder_entered):
				ladder_instance.entered_ladder.connect(_on_ladder_entered)
			if not ladder_instance.exited_ladder.is_connected(_on_ladder_exited):
				ladder_instance.exited_ladder.connect(_on_ladder_exited)

			get_parent().add_child(ladder_instance) # Dodaj do rodzica gracza (zwykle główna scena)
			inventory["ladder"] -= 1
			print("Placed ladder at map coords:", target_map_coords, " Remaining:", inventory["ladder"])
			# Tutaj możesz dodać odtworzenie dźwięku, jeśli masz $PlaceSound
			# if $PlaceSound: $PlaceSound.play()
		else:
			print("Cannot place ladder here, cell is not empty at map coords:", target_map_coords)
	else:
		print("Target position for ladder is too far away.")


func _on_ladder_entered(body):
	# Sprawdźmy czy ciało które weszło to na pewno gracz
	if body == self:
		ladder_stack += 1
		# print("Entered ladder, stack:", ladder_stack)


func _on_ladder_exited(body):
	if body == self:
		ladder_stack -= 1
		if ladder_stack < 0: ladder_stack = 0
		# print("Exited ladder, stack:", ladder_stack)
		# Ważne: Po zejściu z drabiny, przywróć normalną grawitację i kolizje natychmiast
		set_collision_mask_value(1, true)
