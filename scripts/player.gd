extends CharacterBody2D

const SPEED = 50.0
const JUMP_VELOCITY = -75.0
const CLIMB_SPEED = 30.0

const TILE_HEIGHT: float = 16.0 # Wysokość jednego kafelka w pikselach (dostosuj, jeśli inna)
const MIN_FALL_TILES_FOR_DAMAGE: int = 3 # Minimalna liczba kafelków spadku, aby otrzymać obrażenia
const DAMAGE_PER_EXTRA_TILE_PERCENT: float = 10.0 # Procent HP odejmowany za każdy dodatkowy kafelek ponad próg

var ladder_stack = 0
var inventory = {"ladder": 5} # Przykładowy startowy ekwipunek

var max_hp: float = 100.0  # Maksymalne punkty życia
var current_hp: float = 100.0 # Aktualne punkty życia

var is_currently_falling: bool = false # Flaga śledząca, czy gracz aktualnie spada
var fall_start_position_y: float = 0.0 # Pozycja Y, z której gracz zaczął spadać

var dig_timer: float = 0.0
const DIG_DURATION: float = 1.8 # Zdefiniuj stałą dla czasu kopania
var current_dig_tile: Vector2i = Vector2i(-1, -1)

@onready var dig_progress_sprite: Sprite2D = $DigProgressSprite # Upewnij się, że ścieżka jest poprawna!
@export var ladder_scene: PackedScene
@export var ground_tilemap: TileMapLayer
@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var LadderClimbSound: AudioStreamPlayer2D = $LadderClimbSound
@onready var WalkSound: AudioStreamPlayer2D = $WalkSound
@onready var JumpSound: AudioStreamPlayer2D = $JumpSound
# Dźwięki stawiania/usuwania drabin:
@onready var LadderPlaceSound: AudioStreamPlayer2D = $LadderPlaceSound
@onready var LadderRemoveSound: AudioStreamPlayer2D = $LadderRemoveSound

signal inventory_updated(current_inventory) # Sygnał emitowany przy zmianie ekwipunku
signal health_updated(new_hp, max_hp_value) # Sygnał do aktualizacji UI
signal player_died # Sygnał informujący o śmierci gracza

func reset_digging() -> void:
	current_dig_tile = Vector2i(-1, -1)
	dig_timer = 0.0
	update_tile_dig_animation(Vector2i(-1, -1), 0.0)
	if $AnimatedSprite2D.animation == "dig":
		$AnimatedSprite2D.animation = "idle"
		$AnimatedSprite2D.play("idle")

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
	
	inventory_updated.emit(inventory)
	health_updated.emit(current_hp, max_hp)

func _input(event: InputEvent) -> void:
	# UWAGA: Nie wywołujemy tutaj bezpośrednio kopi (handle_digging),
	#       bo chcemy, aby postęp kopania był ciągły.
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		handle_ladder_placement()

func _physics_process(delta: float) -> void:
	# --- Grawitacja i śledzenie spadania ---
	if not is_on_floor() and ladder_stack == 0:
		velocity += get_gravity() * delta / 6
		if not is_currently_falling:
			is_currently_falling = true
			fall_start_position_y = global_position.y
	elif is_on_floor() and is_currently_falling:
		is_currently_falling = false
		var fall_end_position_y = global_position.y
		var fall_distance_pixels = fall_end_position_y - fall_start_position_y
		if fall_distance_pixels > 0:
			var fall_distance_tiles = int(floor(fall_distance_pixels / TILE_HEIGHT))
			if fall_distance_tiles >= MIN_FALL_TILES_FOR_DAMAGE:
				var extra_tiles = fall_distance_tiles - (MIN_FALL_TILES_FOR_DAMAGE - 1)
				var damage_percent = extra_tiles * DAMAGE_PER_EXTRA_TILE_PERCENT
				print("Fall damage calculated: ", damage_percent, "% for falling ", fall_distance_tiles, " tiles.")
				apply_fall_damage(damage_percent)
				
	# --- Obsługa kopania bloków (ciągłe) ---
	if Input.is_action_pressed("dig"):
		process_digging(delta)
	else:
		if current_dig_tile != Vector2i(-1, -1):
			reset_digging()
	
	# --- Anulowanie spadania na drabinie ---
	if ladder_stack > 0:
		if is_currently_falling:
			is_currently_falling = false
		if WalkSound.playing:
			WalkSound.stop()
	
	# --- Skok ---
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = JUMP_VELOCITY
		JumpSound.play()
		is_currently_falling = false
	
	# --- Ruch (w tym poruszanie się po drabinie) ---
	if ladder_stack >= 1:
		set_collision_mask_value(1, false)
		velocity.y = 0
		var direction_y = Input.get_axis("up", "down")
		var direction_x = Input.get_axis("left", "right")
		
		if abs(direction_y) > 0.1:
			if not LadderClimbSound.playing:
				LadderClimbSound.play()
		else:
			if LadderClimbSound.playing:
				LadderClimbSound.stop()
		
		var can_move_vertically = true
		var can_move_horizontally = true
		
		if direction_y != 0:
			var check_pos_world_v: Vector2
			var collider_center_y = collision_shape.global_position.y
			var half_collider_height = collision_shape.shape.height / 2
			var check_margin_v = 1.0
			if direction_y > 0:
				check_pos_world_v = Vector2(global_position.x, collider_center_y + half_collider_height + check_margin_v)
			else:
				check_pos_world_v = Vector2(global_position.x, collider_center_y - half_collider_height - check_margin_v)
			var target_map_coords_v = ground_tilemap.local_to_map(check_pos_world_v)
			if ground_tilemap.get_cell_source_id(target_map_coords_v) != -1:
				var tile_data_v = ground_tilemap.get_cell_tile_data(target_map_coords_v)
				if tile_data_v and tile_data_v.get_collision_polygons_count(0) > 0:
					can_move_vertically = false
		if direction_x != 0:
			var collider_center_y = collision_shape.global_position.y
			var collider_center_x = collision_shape.global_position.x
			var collider_radius = collision_shape.shape.radius
			var check_margin_h = 1.0
			var check_offset_x = sign(direction_x) * (collider_radius + check_margin_h)
			var check_pos_world_h = Vector2(collider_center_x + check_offset_x, collider_center_y)
			var target_map_coords_h = ground_tilemap.local_to_map(check_pos_world_h)
			if ground_tilemap.get_cell_source_id(target_map_coords_h) != -1:
				var tile_data_h = ground_tilemap.get_cell_tile_data(target_map_coords_h)
				if tile_data_h and tile_data_h.get_collision_polygons_count(0) > 0:
					can_move_horizontally = false
		
		if can_move_vertically and direction_y != 0:
			velocity.y = direction_y * CLIMB_SPEED
		if can_move_horizontally and direction_x != 0:
			velocity.x = direction_x * SPEED
		elif not can_move_horizontally:
			velocity.x = move_toward(velocity.x, 0, SPEED)
		else:
			velocity.x = move_toward(velocity.x, 0, SPEED)
		
		if direction_y != 0 or (can_move_horizontally and direction_x != 0):
			$AnimatedSprite2D.animation = "climb"
			if not $AnimatedSprite2D.is_playing():
				$AnimatedSprite2D.play()
			$AnimatedSprite2D.speed_scale = 1
		else:
			$AnimatedSprite2D.animation = "climb"
			if $AnimatedSprite2D.is_playing():
				$AnimatedSprite2D.stop()
			$AnimatedSprite2D.frame = 0
		if direction_x != 0:
			$AnimatedSprite2D.flip_h = direction_x < 0
		
	else:
		# Ruch na ziemi/w powietrzu poza drabiną
		set_collision_mask_value(1, true)
		var direction_x2 = Input.get_axis("left", "right")
		if direction_x2:
			velocity.x = direction_x2 * SPEED
			if is_on_floor() and not WalkSound.playing:
				WalkSound.play()
		else:
			velocity.x = move_toward(velocity.x, 0, SPEED)
			if WalkSound.playing:
				WalkSound.stop()
		
		if is_on_floor():
			if current_dig_tile != Vector2i(-1, -1):
				# Jeśli trwa kopanie, nie zmieniaj animacji
				pass
			elif direction_x2 != 0:
				$AnimatedSprite2D.animation = "walk"
				$AnimatedSprite2D.flip_h = direction_x2 < 0
				if not $AnimatedSprite2D.is_playing() or $AnimatedSprite2D.animation != "walk":
					$AnimatedSprite2D.play("walk")
			else:
				$AnimatedSprite2D.animation = "idle"
				if not $AnimatedSprite2D.is_playing() or $AnimatedSprite2D.animation != "idle":
					$AnimatedSprite2D.play("idle")
		else:
			if current_dig_tile == Vector2i(-1, -1):  # Tylko jeśli nie kopiemy
				$AnimatedSprite2D.animation = "idle"
				if not $AnimatedSprite2D.is_playing() or $AnimatedSprite2D.animation != "idle":
					$AnimatedSprite2D.play("idle")
	
	move_and_slide()
	
	if not is_on_floor() and not is_currently_falling and ladder_stack == 0:
		is_currently_falling = true
		fall_start_position_y = global_position.y

func process_digging(delta: float) -> void:
	var mouse_pos = get_global_mouse_position()
	var target_map_coords = ground_tilemap.local_to_map(mouse_pos)
	var player_map_coords = ground_tilemap.local_to_map(global_position)
	
	var dx = target_map_coords.x - player_map_coords.x
	var dy = target_map_coords.y - player_map_coords.y
	var is_valid_target = ((dx == 0 and dy == 0) or (abs(dx) == 1 and dy == 0) or (dx == 0 and abs(dy) == 1))
	
	if not is_valid_target:
		reset_digging()
		return
	
	for ladder in get_tree().get_nodes_in_group("ladders"):
		if ladder is Area2D and is_instance_valid(ladder):
			var ladder_map_coords = ground_tilemap.local_to_map(ladder.global_position)
			if ladder_map_coords == target_map_coords:
				print("Collecting ladder at map coords: ", target_map_coords)
				inventory["ladder"] += 1
				inventory_updated.emit(inventory)
				ladder.queue_free()
				LadderRemoveSound.play()
				reset_digging()
				return
	
	# Sprawdź czy zmieniamy cel kopania
	if current_dig_tile == Vector2i(-1, -1) or current_dig_tile != target_map_coords:
		current_dig_tile = target_map_coords
		dig_timer = 0.0
		update_tile_dig_animation(current_dig_tile, 0.0)
	
	# Zawsze odtwarzaj animację kopania podczas procesu kopania
	if $AnimatedSprite2D.animation != "dig" or !$AnimatedSprite2D.is_playing():
		$AnimatedSprite2D.animation = "dig"
		$AnimatedSprite2D.play("dig")
	
	# Aktualizuj timer kopania
	dig_timer += delta
	update_tile_dig_animation(current_dig_tile, dig_timer / DIG_DURATION)
	
	if dig_timer >= DIG_DURATION:
		# Usuwamy blok bez wywoływania efektu shader/dissolve
		ground_tilemap.set_cell(current_dig_tile, -1)
		print("Tile destroyed at: ", current_dig_tile)
		reset_digging()

# Funkcja aktualizująca wizualny efekt niszczenia bloku (możesz rozbudować)
func update_tile_dig_animation(tile_coords: Vector2, progress: float) -> void:
	# Tutaj możesz np. zmieniać modulate, alpha lub uruchamiać tween dla overlay.
	# Na tę chwilę jest placeholder.
	# Przykład: print("Dig progress for tile ", tile_coords, ": ", progress);
	pass

func handle_ladder_placement() -> void:
	if inventory.get("ladder", 0) <= 0:
		print("No ladders left in inventory.")
		return
	if not ground_tilemap or not ladder_scene:
		printerr("Ground TileMapLayer or Ladder Scene not assigned in Player script!")
		return
	
	var mouse_pos = get_global_mouse_position()
	var target_map_coords = ground_tilemap.local_to_map(mouse_pos)
	var player_map_coords = ground_tilemap.local_to_map(global_position)
	
	var dx = target_map_coords.x - player_map_coords.x
	var dy = target_map_coords.y - player_map_coords.y
	var is_valid_target_range = ((dx == 0 and dy == 0) or (abs(dx) == 1 and dy == 0) or (dx == 0 and abs(dy) == 1))
	
	if is_valid_target_range:
		var ladder_already_exists = false
		for existing_ladder in get_tree().get_nodes_in_group("ladders"):
			if is_instance_valid(existing_ladder):
				var existing_ladder_map_coords = ground_tilemap.local_to_map(existing_ladder.global_position)
				if existing_ladder_map_coords == target_map_coords:
					ladder_already_exists = true
					break
		if ground_tilemap.get_cell_source_id(target_map_coords) == -1 and not ladder_already_exists:
			var ladder_world_pos = ground_tilemap.map_to_local(target_map_coords)
			var ladder_instance = ladder_scene.instantiate()
			ladder_instance.position = ladder_world_pos
			
			if not ladder_instance.entered_ladder.is_connected(_on_ladder_entered):
				ladder_instance.entered_ladder.connect(_on_ladder_entered)
			if not ladder_instance.exited_ladder.is_connected(_on_ladder_exited):
				ladder_instance.exited_ladder.connect(_on_ladder_exited)
			
			var parent_node = get_parent()
			if is_instance_valid(parent_node):
				parent_node.add_child(ladder_instance)
				print("Added ladder instance:", ladder_instance.name, "to parent:", parent_node.name)
			else:
				printerr("Player has no valid parent to add ladder to!")
				return
			
			inventory["ladder"] -= 1
			inventory_updated.emit(inventory)
			print("Placed ladder at map coords:", target_map_coords, " Remaining:", inventory["ladder"])
			LadderPlaceSound.play()
		else:
			if ladder_already_exists:
				print("Cannot place ladder here, another ladder already exists at map coords:", target_map_coords)
			else:
				print("Cannot place ladder here, cell is not empty (ground tile) at map coords:", target_map_coords)
	else:
		print("Target position for ladder is out of interaction range.")

func apply_fall_damage(damage_percent: float) -> void:
	if current_hp <= 0:
		return
	var damage_amount = (damage_percent / 100.0) * max_hp
	current_hp -= damage_amount
	current_hp = max(current_hp, 0)
	print("Took ", damage_amount, " fall damage. HP left: ", current_hp)
	health_updated.emit(current_hp, max_hp)
	if current_hp <= 0:
		handle_death()

func handle_death() -> void:
	print("Player has died!")
	player_died.emit()
	$AnimatedSprite2D.play("death")
	set_physics_process(false)
	set_process_input(false)
	# Możesz dodać ekran Game Over lub respawn

func _on_ladder_entered(body):
	if body == self:
		ladder_stack += 1
		if WalkSound.playing:
			WalkSound.stop()

func _on_ladder_exited(body):
	if body == self:
		ladder_stack -= 1
		if ladder_stack < 0:
			ladder_stack = 0
		set_collision_mask_value(1, true)
		if LadderClimbSound.playing:
			LadderClimbSound.stop()
