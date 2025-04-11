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

@export var ladder_scene: PackedScene
@export var ground_tilemap: TileMapLayer
@onready var collision_shape: CollisionShape2D = $CollisionShape2D

signal inventory_updated(current_inventory) # Sygnał emitowany przy zmianie ekwipunku
signal health_updated(new_hp, max_hp_value) # Sygnał do aktualizacji UI
signal player_died # Sygnał informujący o śmierci gracza


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
	
	# Wyemituj sygnał z początkowym stanem ekwipunku po gotowości gracza
	inventory_updated.emit(inventory)
	
	# Wyemituj sygnał z początkowym stanem HP
	health_updated.emit(current_hp, max_hp)


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("dig"):
		handle_digging()
	# Zmieniono na globalną pozycję myszy w handle_ladder_placement
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		handle_ladder_placement()


func _physics_process(delta: float) -> void:

	# --- Grawitacja i Śledzenie Spadania ---
	if not is_on_floor() and ladder_stack == 0:
		# Jeśli jesteśmy w powietrzu i nie na drabinie, stosuj grawitację
		velocity += get_gravity() * delta / 6

		# Sprawdź, czy właśnie zaczęliśmy spadać (nie byliśmy już w stanie spadania)
		if not is_currently_falling:
			is_currently_falling = true
			fall_start_position_y = global_position.y # Zapisz pozycję startową upadku
			# print("Start falling from Y:", fall_start_position_y)

	# --- Wykrywanie Lądowania na Podłodze i Obliczanie Obrażeń ---
	elif is_on_floor() and is_currently_falling:
		# Jeśli byliśmy w stanie spadania i właśnie wylądowaliśmy na podłodze
		is_currently_falling = false # Zakończ stan spadania
		var fall_end_position_y = global_position.y
		var fall_distance_pixels = fall_end_position_y - fall_start_position_y
		# print("Landed at Y:", fall_end_position_y, " Fall distance (pixels):", fall_distance_pixels)

		# Upewnij się, że faktycznie spadliśmy (dystans > 0)
		if fall_distance_pixels > 0:
			# Przelicz dystans w pikselach na liczbę kafelków (zaokrąglając w dół)
			var fall_distance_tiles = floor(fall_distance_pixels / TILE_HEIGHT)
			# print("Fall distance (tiles):", fall_distance_tiles)

			# Sprawdź, czy przekroczono próg obrażeń
			if fall_distance_tiles >= MIN_FALL_TILES_FOR_DAMAGE:
				# Oblicz, o ile kafelków przekroczono próg (minimum 1)
				var extra_tiles = fall_distance_tiles - (MIN_FALL_TILES_FOR_DAMAGE - 1)
				# Oblicz procent obrażeń
				var damage_percent = extra_tiles * DAMAGE_PER_EXTRA_TILE_PERCENT
				print("Fall damage calculated: ", damage_percent, "% for falling ", fall_distance_tiles, " tiles.")
				# Zastosuj obrażenia (zakładając, że masz funkcję apply_fall_damage)
				apply_fall_damage(damage_percent)

	# --- Anulowanie Spadania na Drabinie ---
	elif ladder_stack > 0:
		# Jeśli jesteśmy na drabinie, anulujemy stan spadania
		if is_currently_falling:
			is_currently_falling = false
			# print("Grabbed ladder, fall cancelled.")

	# --- Skok ---
	# Wykonywany tylko, gdy gracz jest na podłodze
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = JUMP_VELOCITY
		# Ważne: Skok natychmiastowo resetuje flagę spadania
		is_currently_falling = false

	# --- Logika Ruchu Poziomego i Wspinaczki (bez zmian w stosunku do poprzednich poprawek) ---
	if ladder_stack >= 1:
		# Na drabinie
		set_collision_mask_value(1, false) # Wyłącz kolizję z podłożem
		velocity.y = 0 # Resetuj prędkość Y na początku

		var direction_y = Input.get_axis("up", "down")
		var direction_x = Input.get_axis("left", "right")

		var can_move_vertically = true
		var can_move_horizontally = true

		# Sprawdzanie kolizji pionowej (bez zmian)
		if direction_y != 0:
			var check_pos_world_v: Vector2
			var collider_center_y = collision_shape.global_position.y
			var half_collider_height = collision_shape.shape.height / 2
			var check_margin_v = 1.0
			if direction_y > 0: check_pos_world_v = Vector2(global_position.x, collider_center_y + half_collider_height + check_margin_v)
			else: check_pos_world_v = Vector2(global_position.x, collider_center_y - half_collider_height - check_margin_v)
			var target_map_coords_v = ground_tilemap.local_to_map(check_pos_world_v)
			if ground_tilemap.get_cell_source_id(target_map_coords_v) != -1:
				var tile_data_v = ground_tilemap.get_cell_tile_data(target_map_coords_v)
				if tile_data_v and tile_data_v.get_collision_polygons_count(0) > 0:
					can_move_vertically = false

		# Sprawdzanie kolizji poziomej (bez zmian)
		if direction_x != 0:
			var check_pos_world_h: Vector2
			var collider_center_y = collision_shape.global_position.y
			var collider_center_x = collision_shape.global_position.x
			var collider_radius = collision_shape.shape.radius
			var check_margin_h = 1.0
			var check_offset_x = sign(direction_x) * (collider_radius + check_margin_h)
			check_pos_world_h = Vector2(collider_center_x + check_offset_x, collider_center_y)
			var target_map_coords_h = ground_tilemap.local_to_map(check_pos_world_h)
			if ground_tilemap.get_cell_source_id(target_map_coords_h) != -1:
				var tile_data_h = ground_tilemap.get_cell_tile_data(target_map_coords_h)
				if tile_data_h and tile_data_h.get_collision_polygons_count(0) > 0:
					can_move_horizontally = false

		# Ustaw prędkości ruchu na drabinie (bez zmian)
		if can_move_vertically and direction_y != 0:
			velocity.y = direction_y * CLIMB_SPEED
		if can_move_horizontally and direction_x != 0:
			velocity.x = direction_x * SPEED
		elif not can_move_horizontally: # Jeśli zablokowany w poziomie, zatrzymaj ruch X
			velocity.x = move_toward(velocity.x, 0, SPEED)
		else: # Jeśli brak inputu X i można się ruszać, wyhamuj
			velocity.x = move_toward(velocity.x, 0, SPEED)

		# Animacje wspinaczki (bez zmian)
		if direction_y != 0 or (can_move_horizontally and direction_x != 0):
			$AnimatedSprite2D.animation = "climb"
			if not $AnimatedSprite2D.is_playing(): $AnimatedSprite2D.play()
			$AnimatedSprite2D.speed_scale = 1
		else:
			$AnimatedSprite2D.animation = "climb"
			if $AnimatedSprite2D.is_playing(): $AnimatedSprite2D.stop()
			$AnimatedSprite2D.frame = 0
		if direction_x != 0: $AnimatedSprite2D.flip_h = direction_x < 0

	else:
		# Poza drabiną (na ziemi lub w powietrzu)
		set_collision_mask_value(1, true) # Włącz kolizję z podłożem

		# Ruch poziomy na ziemi/w powietrzu
		var direction_x = Input.get_axis("left", "right")
		if direction_x:
			velocity.x = direction_x * SPEED
		else:
			velocity.x = move_toward(velocity.x, 0, SPEED)

		# Animacje chodzenia/stania/spadania
		if is_on_floor():
			# Na ziemi
			if direction_x != 0:
				# Chodzenie
				$AnimatedSprite2D.animation = "walk"
				$AnimatedSprite2D.flip_h = direction_x < 0
				if not $AnimatedSprite2D.is_playing() or $AnimatedSprite2D.animation != "walk":
					$AnimatedSprite2D.play("walk")
			else:
				# Stanie w miejscu
				$AnimatedSprite2D.animation = "idle"
				if not $AnimatedSprite2D.is_playing() or $AnimatedSprite2D.animation != "idle":
					$AnimatedSprite2D.play("idle")
		else:
			# W powietrzu (spadanie lub skok)
			# TODO: Rozważ dodanie osobnej animacji "fall"
			$AnimatedSprite2D.animation = "idle" # Tymczasowo używamy idle
			if not $AnimatedSprite2D.is_playing() or $AnimatedSprite2D.animation != "idle":
				$AnimatedSprite2D.play("idle") # Odtwórz animację "fall", jeśli istnieje

	# --- Wykonaj Ruch ---
	# Funkcja move_and_slide() zastosuje obliczoną prędkość i obsłuży kolizje
	move_and_slide()

	# --- Sprawdzenie po ruchu (Edge Case) ---
	# Czasami move_and_slide() może spowodować, że gracz opuści podłogę
	# (np. ześlizgnięcie się z krawędzi). Musimy to wykryć, aby poprawnie
	# rozpocząć śledzenie upadku w takiej sytuacji.
	if not is_on_floor() and not is_currently_falling and ladder_stack == 0:
		# Jeśli po ruchu nie jesteśmy na ziemi, nie byliśmy oznaczani jako spadający
		# i nie jesteśmy na drabinie, to właśnie zaczęliśmy spadać.
		is_currently_falling = true
		fall_start_position_y = global_position.y
		# print("Start falling (post-move_and_slide) from Y:", fall_start_position_y)


func handle_digging():
	# Sprawdź, czy referencja do TileMap istnieje
	if not ground_tilemap: return

	# Pobierz pozycje na mapie
	var mouse_pos = get_global_mouse_position()
	var target_map_coords = ground_tilemap.local_to_map(mouse_pos)
	var player_map_coords = ground_tilemap.local_to_map(global_position)

	# Oblicz różnicę współrzędnych
	var dx = target_map_coords.x - player_map_coords.x
	var dy = target_map_coords.y - player_map_coords.y

	# --- NOWY WARUNEK ZASIĘGU: Pole gracza LUB 4 sąsiednie ---
	var is_valid_target = (
		(dx == 0 and dy == 0) or           # Pole, na którym stoi gracz
		(abs(dx) == 1 and dy == 0) or      # Bezpośrednio lewo/prawo
		(dx == 0 and abs(dy) == 1)         # Bezpośrednio góra/dół
	)
	# --- KONIEC NOWEGO WARUNKU ---

	# Sprawdź, czy cel jest w poprawnym zasięgu
	if is_valid_target:

		# --- Sprawdź, czy kliknięto na istniejącą drabinę do zebrania ---
		# To może się zdarzyć również na polu, na którym stoi gracz
		var collected_ladder = false
		for ladder in get_tree().get_nodes_in_group("ladders"):
			if ladder is Area2D and is_instance_valid(ladder):
				var ladder_map_coords = ground_tilemap.local_to_map(ladder.global_position)
				if ladder_map_coords == target_map_coords:
					print("Collecting ladder at map coordinates: ", target_map_coords)
					inventory["ladder"] += 1
					inventory_updated.emit(inventory)
					ladder.queue_free()
					collected_ladder = true
					# TODO: Odtwórz dźwięk zbierania drabiny
					break

		if collected_ladder:
			return # Zakończ, jeśli zebrano drabinę

		# --- Jeśli nie zebrano drabiny, spróbuj kopać ziemię ---
		# Kopanie NIE może odbywać się na polu gracza (dx=0, dy=0),
		# bo gracz na nim stoi, a nie na bloku ziemi.
		if not (dx == 0 and dy == 0): # Dodatkowe zabezpieczenie - nie próbuj kopać pod sobą
			var tile_data = ground_tilemap.get_cell_tile_data(target_map_coords)
			if tile_data:
				var is_diggable = tile_data.get_custom_data("diggable")
				if is_diggable:
					print("Digging tile at map coordinates: ", target_map_coords)
					$AnimatedSprite2D.flip_h = mouse_pos.x < global_position.x
					$AnimatedSprite2D.play("dig")
					# TODO: Odtwórz dźwięk kopania
					ground_tilemap.set_cell(target_map_coords, -1)
				else:
					print("Tile at ", target_map_coords, " is not diggable.")
			else:
				# W tej komórce (sąsiedniej) nie ma ani drabiny, ani kafelka
				print("Nothing to dig or collect at adjacent map coordinates: ", target_map_coords)

	else:
		# Cel jest poza dozwolonym zasięgiem (dalej niż 1 pole lub na skos)
		print("Target tile at ", target_map_coords, " is out of interaction range from player at ", player_map_coords)


func handle_ladder_placement() -> void:
	# Sprawdź ekwipunek
	if inventory.get("ladder", 0) <= 0:
		print("No ladders left in inventory.")
		return

	# Sprawdź referencje
	if not ground_tilemap or not ladder_scene:
		printerr("Ground TileMapLayer or Ladder Scene not assigned in Player script!")
		return

	# Pobierz pozycje
	var mouse_pos = get_global_mouse_position()
	var target_map_coords = ground_tilemap.local_to_map(mouse_pos)
	var player_map_coords = ground_tilemap.local_to_map(global_position)

	# Oblicz różnicę
	var dx = target_map_coords.x - player_map_coords.x
	var dy = target_map_coords.y - player_map_coords.y

	# --- NOWY WARUNEK ZASIĘGU: Pole gracza LUB 4 sąsiednie ---
	var is_valid_target_range = (
		(dx == 0 and dy == 0) or           # Pole, na którym stoi gracz
		(abs(dx) == 1 and dy == 0) or      # Bezpośrednio lewo/prawo
		(dx == 0 and abs(dy) == 1)         # Bezpośrednio góra/dół
	)
	# --- KONIEC NOWEGO WARUNKU ---

	# Jeśli cel jest w zasięgu
	if is_valid_target_range:

		# --- NOWE: Sprawdź, czy na docelowym polu już istnieje drabina ---
		var ladder_already_exists = false
		for existing_ladder in get_tree().get_nodes_in_group("ladders"):
			if is_instance_valid(existing_ladder):
				var existing_ladder_map_coords = ground_tilemap.local_to_map(existing_ladder.global_position)
				if existing_ladder_map_coords == target_map_coords:
					ladder_already_exists = true
					break # Znaleziono istniejącą drabinę, przerwij sprawdzanie
		# --- KONIEC SPRAWDZANIA ISTNIEJĄCYCH DRABIN ---

		# Sprawdź, czy komórka na mapie ziemi jest pusta ORAZ czy nie ma tam już drabiny
		if ground_tilemap.get_cell_source_id(target_map_coords) == -1 and not ladder_already_exists:
			# Można postawić drabinę
			var ladder_world_pos = ground_tilemap.map_to_local(target_map_coords)
			var ladder_instance = ladder_scene.instantiate()
			ladder_instance.position = ladder_world_pos

			# Podłącz sygnały
			if not ladder_instance.entered_ladder.is_connected(_on_ladder_entered):
				ladder_instance.entered_ladder.connect(_on_ladder_entered)
			if not ladder_instance.exited_ladder.is_connected(_on_ladder_exited):
				ladder_instance.exited_ladder.connect(_on_ladder_exited)

			# Dodaj do sceny
			var parent_node = get_parent()
			if is_instance_valid(parent_node):
				parent_node.add_child(ladder_instance)
				print("Added ladder instance:", ladder_instance.name, "to parent:", parent_node.name)
			else:
				printerr("Player has no valid parent to add ladder to!")
				return

			# Zaktualizuj ekwipunek
			inventory["ladder"] -= 1
			inventory_updated.emit(inventory)
			print("Placed ladder at map coords:", target_map_coords, " Remaining:", inventory["ladder"])
			# TODO: Odtwórz dźwięk stawiania drabiny

		else:
			# Komórka nie jest pusta lub już jest tam drabina
			if ladder_already_exists:
				print("Cannot place ladder here, another ladder already exists at map coords:", target_map_coords)
			else: # Wiadomo, że jest tam blok ziemi
				print("Cannot place ladder here, cell is not empty (ground tile) at map coords:", target_map_coords)
	else:
		# Cel jest poza dozwolonym zasięgiem
		print("Target position for ladder is out of interaction range.")


# Funkcja do odejmowania HP i obsługi konsekwencji
func apply_fall_damage(damage_percent: float):
	if current_hp <= 0: return # Już nie żyje

	var damage_amount = (damage_percent / 100.0) * max_hp
	current_hp -= damage_amount
	current_hp = max(current_hp, 0) # HP nie może spaść poniżej 0

	print("Took ", damage_amount, " fall damage. HP left: ", current_hp)
	health_updated.emit(current_hp, max_hp) # Wyślij sygnał do UI

	# TODO: Dodaj efekt wizualny/dźwiękowy otrzymania obrażeń (np. krótkie mignięcie, dźwięk)
	# $AnimatedSprite2D.modulate = Color(1, 0.5, 0.5) # Przykład mignięcia na czerwono
	# await get_tree().create_timer(0.1).timeout
	# $AnimatedSprite2D.modulate = Color(1, 1, 1)

	if current_hp <= 0:
		handle_death()


# Funkcja obsługująca śmierć gracza
func handle_death():
	print("Player has died!")
	player_died.emit() # Wyślij sygnał
	# TODO: Odtwórz animację śmierci
	$AnimatedSprite2D.play("death")
	# TODO: Zablokuj sterowanie graczem
	set_physics_process(false) # Prosty sposób na zatrzymanie przetwarzania fizyki
	set_process_input(false)   # Zablokuj input
	# TODO: Pokaż ekran "Game Over" lub zaoferuj respawn po chwili
	# await get_tree().create_timer(2.0).timeout
	# get_tree().reload_current_scene() # Przykładowy respawn przez przeładowanie sceny


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
