extends CharacterBody2D

const SPEED = 50.0
const JUMP_VELOCITY = -75.0
const CLIMB_SPEED = 30.0

const TILE_HEIGHT: float = 16.0 # Wysokość jednego kafelka w pikselach
const MIN_FALL_TILES_FOR_DAMAGE: int = 3 # Minimalna liczba kafelków spadku, aby otrzymać obrażenia
const DAMAGE_PER_EXTRA_TILE_PERCENT: float = 10.0 # Procent HP odejmowany za każdy dodatkowy kafelek ponad próg

var ladder_stack = 0
var starting_inventory = {"ladder": 5} # Przykładowy ekwipunek

var max_hp: float = 100.0  # Maksymalne punkty życia
var current_hp: float = 100.0 # Aktualne punkty życia

var is_currently_falling: bool = false # Flaga śledząca stan spadania
var fall_start_position_y: float = 0.0 # Pozycja Y, z której rozpoczął się upadek

# Używamy systemu kopania z wersji kolegi
var digging_blocks = {} # Słownik śledzący stan kopanych bloków: {Vector2i(map_coords): current_durability}
var digging_timer = null # Timer do kontroli kopania
var digging_interval = 0.4 # Częstotliwość "uderzeń" (w sekundach)
var digging_target = null # Aktualne koordynaty kopiowanego bloku
var digging_damage = 25.0 # Ile "uderzenie" zmniejsza wytrzymałość
var digging_animation = "dig"
@export var ladder_item_type: InventoryItemType
@export var ladder_scene: PackedScene
@export var ground_tilemap: TileMapLayer
@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@export var inventory: Inventory
# Dźwięki – Twoje dodatki:
@onready var LadderClimbSound: AudioStreamPlayer2D = $LadderClimbSound
@onready var WalkSound: AudioStreamPlayer2D = $WalkSound
@onready var JumpSound: AudioStreamPlayer2D = $JumpSound
@onready var LadderPlaceSound: AudioStreamPlayer2D = $LadderPlaceSound
@onready var LadderRemoveSound: AudioStreamPlayer2D = $LadderRemoveSound
@onready var DigSound: AudioStreamPlayer2D = $DigSound

signal inventory_updated(current_inventory)  # Sygnał aktualizacji ekwipunku
signal health_updated(new_hp, max_hp_value)     # Sygnał aktualizacji HP
signal player_died                             # Sygnał śmierci gracza

func _ready() -> void:
	 # 1) Migruj starting_inventory do resource’u Inventory:
	if starting_inventory.has("ladder") and ladder_item_type:
		var count = starting_inventory["ladder"]
		for i in range(count):
			var new_item := InventoryItem.new()
			new_item.item_type = ladder_item_type
			inventory.put(new_item)
		# (opcjonalnie) skasuj tę pozycję, żeby nie zrobić migracji drugi raz:
		starting_inventory.erase("ladder")
		
	if not ground_tilemap:
		printerr("Player: Ground TileMapLayer not assigned!")
	print("Player ready at: ", global_position, " Ladders:", starting_inventory.get("ladder", 0))
	
	# Podłączanie sygnałów drabin już istniejących na scenie
	for ladder in get_tree().get_nodes_in_group("ladders"):
		if not ladder.entered_ladder.is_connected(_on_ladder_entered):
			ladder.entered_ladder.connect(_on_ladder_entered)
		if not ladder.exited_ladder.is_connected(_on_ladder_exited):
			ladder.exited_ladder.connect(_on_ladder_exited)
	
	inventory_updated.emit(inventory)
	health_updated.emit(current_hp, max_hp)
	
	# Inicjalizacja timera kopania
	digging_timer = Timer.new()
	digging_timer.wait_time = digging_interval
	digging_timer.one_shot = false
	digging_timer.connect("timeout", Callable(self, "_on_digging_timer_timeout"))
	add_child(digging_timer)

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("dig"):
		handle_digging()
	elif event.is_action_released("dig"):
		stop_digging()
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
			var fall_distance_tiles = floor(fall_distance_pixels / TILE_HEIGHT)
			if fall_distance_tiles >= MIN_FALL_TILES_FOR_DAMAGE:
				var extra_tiles = fall_distance_tiles - (MIN_FALL_TILES_FOR_DAMAGE - 1)
				var damage_percent = extra_tiles * DAMAGE_PER_EXTRA_TILE_PERCENT
				print("Fall damage calculated: ", damage_percent, "% for falling ", fall_distance_tiles, " tiles.")
				apply_fall_damage(damage_percent)
	elif ladder_stack > 0:
		if is_currently_falling:
			is_currently_falling = false

	# --- Skok ---
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = JUMP_VELOCITY
		JumpSound.play()
		is_currently_falling = false

	# --- Ruch na drabinie ---
	if ladder_stack >= 1:
		set_collision_mask_value(1, false)
		velocity.y = 0
		
		var direction_y = Input.get_axis("up", "down")
		var direction_x = Input.get_axis("left", "right")
		
		# Dodajemy dźwięk wspinania się po drabinie:
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

	# --- Ruch na ziemi/w powietrzu (poza drabiną) ---
	else:
		set_collision_mask_value(1, true)
		
		var direction_x = Input.get_axis("left", "right")
		if direction_x:
			velocity.x = direction_x * SPEED
			if is_on_floor() and not WalkSound.playing:
				WalkSound.play()
		else:
			velocity.x = move_toward(velocity.x, 0, SPEED)
			if WalkSound.playing:
				WalkSound.stop()
		
		# Jeśli trwa kopanie, ustaw animację kopania i zakończ tutaj dalsze zmiany animacji
		if Input.is_action_pressed("dig") and digging_target != null:
			$AnimatedSprite2D.animation = digging_animation
			if not $AnimatedSprite2D.is_playing():
				$AnimatedSprite2D.play()
			move_and_slide()
			return

		if is_on_floor():
			if direction_x != 0:
				$AnimatedSprite2D.animation = "walk"
				$AnimatedSprite2D.flip_h = direction_x < 0
				if not $AnimatedSprite2D.is_playing() or $AnimatedSprite2D.animation != "walk":
					$AnimatedSprite2D.play("walk")
			else:
				$AnimatedSprite2D.animation = "idle"
				if not $AnimatedSprite2D.is_playing() or $AnimatedSprite2D.animation != "idle":
					$AnimatedSprite2D.play("idle")
		else:
			$AnimatedSprite2D.animation = "idle"
			if not $AnimatedSprite2D.is_playing() or $AnimatedSprite2D.animation != "idle":
				$AnimatedSprite2D.play("idle")
	
	move_and_slide()
	
	if not is_on_floor() and not is_currently_falling and ladder_stack == 0:
		is_currently_falling = true
		fall_start_position_y = global_position.y

func _on_digging_timer_timeout() -> void:
	if digging_target == null:
		digging_timer.stop()
		return
	dig_block_progress(digging_target)

func handle_digging():
	if not ground_tilemap:
		return

	var mouse_pos = get_global_mouse_position()
	var target_map_coords = ground_tilemap.local_to_map(mouse_pos)
	var player_map_coords = ground_tilemap.local_to_map(global_position)

	var dx = target_map_coords.x - player_map_coords.x
	var dy = target_map_coords.y - player_map_coords.y

	var is_valid_target = (
		(dx == 0 and dy == 0) or
		(abs(dx) == 1 and dy == 0) or
		(dx == 0 and abs(dy) == 1)
	)

	# Sprawdź, czy kliknięto na istniejącą drabinę (do zebrania)
	var collected_ladder = false
	for ladder in get_tree().get_nodes_in_group("ladders"):
		if ladder is Area2D and is_instance_valid(ladder):
			var ladder_map_coords = ground_tilemap.local_to_map(ladder.global_position)
			if ladder_map_coords == target_map_coords:
				print("Collecting ladder at map coordinates: ", target_map_coords)
				var it = InventoryItem.new()
				it.item_type = ladder_item_type
				inventory.put(it) 
				ladder.queue_free()
				LadderRemoveSound.play()
				collected_ladder = true
				break

	if collected_ladder:
		stop_digging()
		return

	if is_valid_target:
		if not (dx == 0 and dy == 0):
			var tile_data = ground_tilemap.get_cell_tile_data(target_map_coords)
			if tile_data:
				var is_diggable = tile_data.get_custom_data("diggable")
				if is_diggable:
					$AnimatedSprite2D.flip_h = mouse_pos.x < global_position.x
					if mouse_pos.y > global_position.y:
						digging_animation = "dig_under"
					else:
						digging_animation = "dig"
					start_digging(target_map_coords)
				else:
					print("Tile at ", target_map_coords, " is not diggable.")
					stop_digging()
			else:
				print("Nothing to dig or collect at adjacent map coordinates: ", target_map_coords)
				stop_digging()
	else:
		print("Target tile at ", target_map_coords, " is out of interaction range from player at ", player_map_coords)
		stop_digging()

func start_digging(map_coords: Vector2i) -> void:
	if digging_target != null and digging_target != map_coords:
		stop_digging()
	
	digging_target = map_coords
	
	if not digging_blocks.has(map_coords):
		var tile_data = ground_tilemap.get_cell_tile_data(map_coords)
		var base_durability = 100.0
		if tile_data and tile_data.has_custom_data("durability"):
			base_durability = tile_data.get_custom_data("durability")
		digging_blocks[map_coords] = base_durability
	
	# Wykonaj pierwsze uderzenie natychmiast
	dig_block_progress(map_coords)
	digging_timer.start()

func stop_digging() -> void:
	digging_target = null
	digging_timer.stop()

func dig_block_progress(map_coords: Vector2i) -> void:
	if not digging_blocks.has(map_coords):
		stop_digging()
		return

	# Odtwórz dźwięk kopania – sprawdzamy, czy nie jest już odtwarzany, by nie nakładać wielu dźwięków
	if not DigSound.playing:
		DigSound.play()

	digging_blocks[map_coords] -= digging_damage
	print("Digging block at ", map_coords, " - Durability: ", digging_blocks[map_coords])
	
	if digging_blocks[map_coords] <= 0:
		ground_tilemap.set_cell(map_coords, -1)
		digging_blocks.erase(map_coords)
		# Możesz też dodać inny dźwięk dla zniszczenia bloku, jeśli chcesz
		stop_digging()


func handle_ladder_placement() -> void:
	# 1) Czy w ekwipunku są drabiny?
	if inventory.get_amount_of_item_type(ladder_item_type) <= 0:
		print("No ladders left in inventory.")
		return

	# 2) Sprawdź, czy w zasięgu…
	var mouse = get_global_mouse_position()
	var target = ground_tilemap.local_to_map(mouse)
	var me    = ground_tilemap.local_to_map(global_position)
	if abs(target.x - me.x) + abs(target.y - me.y) > 1:
		print("Too far away to place ladder.")
		return

	# 3) Usuń jedną drabinę z ekwipunku
	var list = inventory.get_of_type(ladder_item_type)
	if list.size() > 0:
		inventory.take(list[0])  # emituje item_removed

	# 4) Instancjonuj drabinę w świecie
	var inst = ladder_scene.instantiate()
	inst.position = ground_tilemap.map_to_local(target)
	get_parent().add_child(inst)
	LadderPlaceSound.play()


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

func _on_ladder_entered(body):
	if body == self:
		ladder_stack += 1

func _on_ladder_exited(body):
	if body == self:
		ladder_stack -= 1
		if ladder_stack < 0:
			ladder_stack = 0
		set_collision_mask_value(1, true)
		if LadderClimbSound.playing:
			LadderClimbSound.stop()
