extends CharacterBody2D

const SPEED = 50.0
const JUMP_VELOCITY = -75.0
const CLIMB_SPEED = 30.0
const DIG_REACH = 1
const LADDER_REACH = 2 # Zasięg stawiania drabin (w kafelkach)

var ladder_stack = 0
var inventory = {"ladder": 5} # Przykładowy startowy ekwipunek

@export var ladder_scene: PackedScene
@export var ground_tilemap: TileMapLayer
@onready var collision_shape: CollisionShape2D = $CollisionShape2D

signal inventory_updated(current_inventory) # Sygnał emitowany przy zmianie ekwipunku

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

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("dig"):
		handle_digging()
	# Zmieniono na globalną pozycję myszy w handle_ladder_placement
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		handle_ladder_placement()


# Upewnij się, że masz tę linię zdefiniowaną wyżej w skrypcie:
#@onready var collision_shape: CollisionShape2D = $CollisionShape2D

func _physics_process(delta: float) -> void:
	# --- Grawitacja (zgodnie z oryginalnym kodem) ---
	if not is_on_floor() and ladder_stack == 0:
		# velocity.y += ProjectSettings.get_setting("physics/2d/default_gravity") * delta / 6 # Alternatywa
		velocity += get_gravity() * delta / 6 # Oryginał

	# --- Skok (zgodnie z oryginalnym kodem) ---
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = JUMP_VELOCITY

	# --- Ruch Poziomy (Normalny - poza drabiną) ---
	# Ten blok zostanie obsłużony w sekcji 'else' dla ladder_stack
	# var direction_x = Input.get_axis("left", "right") # Przenieśliśmy odczyt niżej

	# --- Logika Drabiny i Kolizji ---
	if ladder_stack >= 1:
		# Jesteśmy na drabinie
		set_collision_mask_value(1, false) # Wyłącz kolizję z podłożem (warstwa 1) dla ruchu pionowego
		velocity.y = 0 # Resetuj prędkość Y na początku

		var direction_y = Input.get_axis("up", "down")
		var direction_x = Input.get_axis("left", "right") # Odczyt kierunku X tutaj

		var can_move_vertically = true
		var can_move_horizontally = true

		# --- SPRAWDZENIE KOLIZJI PIONOWEJ ---
		if direction_y != 0:
			var check_pos_world_v: Vector2
			var collider_center_y = collision_shape.global_position.y
			var half_collider_height = collision_shape.shape.height / 2
			var check_margin_v = 1.0
			if direction_y > 0:
				var bottom_edge_y = collider_center_y + half_collider_height
				check_pos_world_v = Vector2(global_position.x, bottom_edge_y + check_margin_v)
			else:
				var top_edge_y = collider_center_y - half_collider_height
				check_pos_world_v = Vector2(global_position.x, top_edge_y - check_margin_v)
			var target_map_coords_v = ground_tilemap.local_to_map(check_pos_world_v)
			if ground_tilemap.get_cell_source_id(target_map_coords_v) != -1:
				var tile_data_v = ground_tilemap.get_cell_tile_data(target_map_coords_v)
				if tile_data_v and tile_data_v.get_collision_polygons_count(0) > 0:
					can_move_vertically = false

		# --- NOWE: SPRAWDZENIE KOLIZJI POZIOMEJ ---
		if direction_x != 0:
			var check_pos_world_h: Vector2
			# Używamy środka collidera jako odniesienia pionowego
			var collider_center_y = collision_shape.global_position.y
			# Używamy globalnej pozycji X gracza (lub środka collidera X)
			var collider_center_x = collision_shape.global_position.x
			# Pobieramy promień kapsuły jako "połowę szerokości"
			var collider_radius = collision_shape.shape.radius
			var check_margin_h = 1.0

			# Oblicz offset X w kierunku ruchu
			var check_offset_x = sign(direction_x) * (collider_radius + check_margin_h)
			# Pozycja do sprawdzenia: na tej samej wysokości co środek collidera, przesunięta w poziomie
			check_pos_world_h = Vector2(collider_center_x + check_offset_x, collider_center_y)

			var target_map_coords_h = ground_tilemap.local_to_map(check_pos_world_h)

			# Sprawdź, czy w docelowej komórce jest solidny kafelek
			if ground_tilemap.get_cell_source_id(target_map_coords_h) != -1:
				var tile_data_h = ground_tilemap.get_cell_tile_data(target_map_coords_h)
				if tile_data_h and tile_data_h.get_collision_polygons_count(0) > 0:
					can_move_horizontally = false # Zablokuj ruch poziomy, jeśli jest kolizja
		# --- KONIEC SPRAWDZENIA POZIOMEGO ---

		# Ustaw prędkości tylko jeśli ruch jest dozwolony
		if can_move_vertically and direction_y != 0:
			velocity.y = direction_y * CLIMB_SPEED
		# Jeśli !can_move_vertically, velocity.y pozostaje 0

		# Zastosuj prędkość poziomą tylko jeśli można się ruszyć i jest input
		if can_move_horizontally and direction_x != 0:
			velocity.x = direction_x * SPEED
		else:
			# Jeśli nie można się ruszyć w poziomie LUB nie ma inputu X, wyhamuj
			velocity.x = move_toward(velocity.x, 0, SPEED)

		# --- Logika animacji wspinaczki ---
		if direction_y != 0 or (can_move_horizontally and direction_x != 0): # Animuj jeśli ruch pionowy LUB dozwolony poziomy
			$AnimatedSprite2D.animation = "climb"
			if not $AnimatedSprite2D.is_playing(): # Poprawka z poprzedniej wersji - graj tylko jeśli nie gra
				$AnimatedSprite2D.play()
			$AnimatedSprite2D.speed_scale = 1
		else: # Brak efektywnego ruchu na drabinie
			$AnimatedSprite2D.animation = "climb"
			if $AnimatedSprite2D.is_playing(): # Poprawka z poprzedniej wersji - zatrzymaj jeśli gra
				$AnimatedSprite2D.stop()
			$AnimatedSprite2D.frame = 0

		# --- Odwracanie sprite'a ---
		if direction_x != 0:
			$AnimatedSprite2D.flip_h = direction_x < 0

	else:
		# --- Poza drabiną (logika jak w oryginale) ---
		set_collision_mask_value(1, true) # Włącz kolizję z podłożem

		# Odczyt kierunku X dla ruchu po ziemi
		var direction_x = Input.get_axis("left", "right")

		# Logika prędkości poziomej na ziemi
		if direction_x:
			velocity.x = direction_x * SPEED
		else:
			velocity.x = move_toward(velocity.x, 0, SPEED)

		# Logika animacji chodzenia/stania/spadania
		if is_on_floor():
			if direction_x != 0:
				$AnimatedSprite2D.animation = "walk"
				$AnimatedSprite2D.flip_h = direction_x < 0
				if not $AnimatedSprite2D.is_playing() or $AnimatedSprite2D.animation != "walk": # Play only if needed
					$AnimatedSprite2D.play("walk")
			else:
				$AnimatedSprite2D.animation = "idle"
				if not $AnimatedSprite2D.is_playing() or $AnimatedSprite2D.animation != "idle": # Play only if needed
					$AnimatedSprite2D.play("idle")
		else:
			# W powietrzu
			$AnimatedSprite2D.animation = "idle" # Zmień na "fall"
			if not $AnimatedSprite2D.is_playing() or $AnimatedSprite2D.animation != "idle": # Play only if needed
					$AnimatedSprite2D.play("idle") # Zmień na "fall"

	# --- Wykonaj ruch (zawsze na końcu) ---
	move_and_slide()

#func handle_digging():
	#if not ground_tilemap: return
	#var mouse_pos = get_global_mouse_position()
	#var target_map_coords = ground_tilemap.local_to_map(mouse_pos)
	#var player_map_coords = ground_tilemap.local_to_map(global_position)
#
	#var dx = abs(target_map_coords.x - player_map_coords.x)
	#var dy = abs(target_map_coords.y - player_map_coords.y)
#
	#if dx <= DIG_REACH and dy <= DIG_REACH:
		#var tile_data = ground_tilemap.get_cell_tile_data(target_map_coords)
		#if tile_data:
			#var is_diggable = tile_data.get_custom_data("diggable")
			#if is_diggable:
				#print("Digging tile at map coordinates: ", target_map_coords)
				#var _specific_dig_time = tile_data.get_custom_data("dig_time") # Ta zmienna nie jest używana?
				## Jeśli chcesz opóźnienie, musisz zaimplementować timer lub yield
				## $AnimatedSprite2D.flip_h = mouse_pos.x < player_map_coords.x # Powinno być global_position.x?
				#$AnimatedSprite2D.flip_h = mouse_pos.x < global_position.x
				#$AnimatedSprite2D.play("dig") # Użyj play() zamiast przypisania animation
				#ground_tilemap.set_cell(target_map_coords, -1) # Warstwa 0 domyślnie
			#else:
				#print("Tile at ", target_map_coords, " is not diggable.")
		#else:
			#print("No tile data to dig at map coordinates: ", target_map_coords)
	#else:
		#print("Target tile at ", target_map_coords, " is too far from player at ", player_map_coords)

# ZASTĄP STARĄ FUNKCJĘ handle_digging() TĄ WERSJĄ:
func handle_digging():
	# Sprawdź, czy referencja do TileMap istnieje (potrzebna do konwersji i kopania)
	if not ground_tilemap: return

	# Pobierz pozycję myszy i gracza na mapie
	var mouse_pos = get_global_mouse_position()
	var target_map_coords = ground_tilemap.local_to_map(mouse_pos)
	var player_map_coords = ground_tilemap.local_to_map(global_position)

	# Oblicz odległość w kafelkach od gracza do celu kliknięcia
	var dx_reach = abs(target_map_coords.x - player_map_coords.x)
	var dy_reach = abs(target_map_coords.y - player_map_coords.y)

	# Sprawdź, czy cel jest w zasięgu (DIG_REACH działa też dla zbierania drabin)
	if dx_reach <= DIG_REACH and dy_reach <= DIG_REACH:

		# --- NOWA CZĘŚĆ: SPRAWDZENIE CZY KLIKNIĘTO NA DRABINĘ ---
		var collected_ladder = false # Flaga, czy zebrano drabinę
		# Przejrzyj wszystkie węzły w grupie "ladders"
		for ladder in get_tree().get_nodes_in_group("ladders"):
			# Sprawdź, czy to faktycznie instancja drabiny (na wszelki wypadek)
			if ladder is Area2D:
				# Pobierz pozycję drabiny na mapie kafelków
				var ladder_map_coords = ground_tilemap.local_to_map(ladder.global_position)
				# Sprawdź, czy kliknięta komórka mapy odpowiada pozycji drabiny
				if ladder_map_coords == target_map_coords:
					# Znaleziono drabinę w klikniętym miejscu i w zasięgu!
					print("Collecting ladder at map coordinates: ", target_map_coords)

					# Dodaj drabinę do ekwipunku
					inventory["ladder"] += 1
					# Wyemituj sygnał aktualizacji UI
					inventory_updated.emit(inventory)
					# Usuń drabinę ze sceny (ważne: użyj queue_free() dla bezpieczeństwa)
					ladder.queue_free()
					# TODO: Odtwórz dźwięk zbierania drabiny
					# TODO: Można dodać krótką animację zbierania

					# Ustaw flagę i przerwij pętlę, bo znaleźliśmy i zebraliśmy drabinę
					collected_ladder = true
					break # Wyjdź z pętli 'for ladder'

		# --- KONIEC SPRAWDZANIA DRABIN ---

		# Jeśli zebrano drabinę, nie próbuj kopać ziemi w tym samym miejscu
		if collected_ladder:
			return # Zakończ funkcję handle_digging

		# --- ISTNIEJĄCA CZĘŚĆ: KOPANIE ZIEMI (jeśli nie zebrano drabiny) ---
		# Pobierz dane kafelka w docelowej pozycji
		var tile_data = ground_tilemap.get_cell_tile_data(target_map_coords)
		# Sprawdź, czy kafelek istnieje
		if tile_data:
			# Sprawdź niestandardową właściwość "diggable"
			var is_diggable = tile_data.get_custom_data("diggable")
			if is_diggable:
				print("Digging tile at map coordinates: ", target_map_coords)
				var _specific_dig_time = tile_data.get_custom_data("dig_time") # Nadal nieużywane

				# Ustaw kierunek animacji kopania i odtwórz ją
				$AnimatedSprite2D.flip_h = mouse_pos.x < global_position.x
				$AnimatedSprite2D.play("dig")

				# Usuń kafelek z mapy
				ground_tilemap.set_cell(target_map_coords, -1)
			else:
				# Kafelek istnieje, ale nie jest kopialny
				print("Tile at ", target_map_coords, " is not diggable.")
		else:
			# W tej komórce nie ma żadnego kafelka (ani drabiny, bo sprawdziliśmy wcześniej)
			print("Nothing to dig or collect at map coordinates: ", target_map_coords)
	else:
		# Cel jest poza zasięgiem
		print("Target tile at ", target_map_coords, " is too far from player at ", player_map_coords)


# ZASTĄP STARĄ WERSJĘ TĄ PONIŻEJ
func handle_ladder_placement() -> void:
	# NAJPIERW sprawdź, czy gracz ma jeszcze drabiny
	if inventory.get("ladder", 0) <= 0:
		print("No ladders left in inventory.")
		return # Zakończ funkcję, jeśli nie ma drabin

	# Potem sprawdź, czy potrzebne referencje istnieją
	if not ground_tilemap or not ladder_scene:
		printerr("Ground TileMapLayer or Ladder Scene not assigned!")
		return

	# Reszta logiki znajdowania pozycji (bez zmian)
	var mouse_pos = get_global_mouse_position()
	var target_map_coords = ground_tilemap.local_to_map(mouse_pos)
	var player_map_coords = ground_tilemap.local_to_map(global_position)
	var dx = target_map_coords.x - player_map_coords.x
	var dy = target_map_coords.y - player_map_coords.y
	var is_adjacent = (
		(dx == 0 and abs(dy) == 1) or # Zmieniono na abs(dy) dla sprawdzania góra/dół
		(abs(dx) == 1 and dy == 0)   # Na lewo lub na prawo
	)

	if is_adjacent:
		# Sprawdź, czy komórka jest pusta
		if ground_tilemap.get_cell_source_id(target_map_coords) == -1: # Sprecyzowano warstwę 0
			var ladder_world_pos = ground_tilemap.map_to_local(target_map_coords)
			var ladder_instance = ladder_scene.instantiate()
			ladder_instance.position = ladder_world_pos

			# Podłączanie sygnałów nowej drabiny (bez zmian)
			if not ladder_instance.entered_ladder.is_connected(_on_ladder_entered):
				ladder_instance.entered_ladder.connect(_on_ladder_entered)
			if not ladder_instance.exited_ladder.is_connected(_on_ladder_exited):
				ladder_instance.exited_ladder.connect(_on_ladder_exited)

			# Dodaj instancję do sceny (bez zmian)
			get_parent().add_child(ladder_instance)

			# --- ZMIANA i SYGNAŁ ---
			# Zmniejsz liczbę drabin w ekwipunku
			inventory["ladder"] -= 1
			# Wyemituj sygnał, że ekwipunek się zmienił, przekazując aktualny słownik
			inventory_updated.emit(inventory)
			print("Placed ladder at map coords:", target_map_coords, " Remaining:", inventory["ladder"])
			# --- KONIEC ZMIANY i SYGNAŁU ---

		else:
			print("Cannot place ladder here, cell is not empty at map coords:", target_map_coords)
	else:
		print("Target position for ladder is not adjacent or valid.")


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


#func _physics_process(delta: float) -> void:
	## --- Grawitacja (zgodnie z oryginalnym kodem) ---
	#if not is_on_floor() and ladder_stack == 0:
		## velocity.y += ProjectSettings.get_setting("physics/2d/default_gravity") * delta / 6 # Alternatywa
		#velocity += get_gravity() * delta / 6 # Oryginał
#
	## --- Skok (zgodnie z oryginalnym kodem) ---
	#if Input.is_action_just_pressed("jump") and is_on_floor():
		#velocity.y = JUMP_VELOCITY
#
	## --- Ruch Poziomy (zgodnie z oryginalnym kodem) ---
	#var direction_x = Input.get_axis("left", "right")
	#if direction_x:
		#velocity.x = direction_x * SPEED
	#else:
		#velocity.x = move_toward(velocity.x, 0, SPEED)
#
	## --- Logika Drabiny i Kolizji ---
	#if ladder_stack >= 1:
		## Jesteśmy na drabinie
		#set_collision_mask_value(1, false) # Wyłącz kolizję z podłożem (warstwa 1)
		#velocity.y = 0 # Resetuj prędkość Y na początku
		#var direction_y = Input.get_axis("up", "down")
#
		#var can_move_vertically = true # Domyślnie zakładamy, że można się ruszyć
#
		## --- DOKŁADNIEJSZE SPRAWDZENIE KOLIZJI PRZY WSPINACZCE (v3) ---
		#if direction_y != 0:
			#var check_pos_world: Vector2
			## Pobierz światową pozycję środka kształtu kolizji
			#var collider_center_y = collision_shape.global_position.y
			## Pobierz połowę wysokości kształtu kolizji
			#var half_collider_height = collision_shape.shape.height / 2
			## Mały offset (np. 1 piksel)
			#var check_margin = 1.0
#
			#if direction_y > 0: # Schodzenie w dół
				## Sprawdź tuż PONIŻEJ dolnej krawędzi collidera
				#var bottom_edge_y = collider_center_y + half_collider_height
				#check_pos_world = Vector2(global_position.x, bottom_edge_y + check_margin)
			#else: # Wchodzenie w górę (direction_y < 0)
				## Sprawdź tuż POWYŻEJ górnej krawędzi collidera
				#var top_edge_y = collider_center_y - half_collider_height
				#check_pos_world = Vector2(global_position.x, top_edge_y - check_margin)
#
			#var target_map_coords = ground_tilemap.local_to_map(check_pos_world)
#
			## Sprawdź, czy w docelowej komórce jest solidny kafelek (Source ID != -1)
			#if ground_tilemap.get_cell_source_id(target_map_coords) != -1:
				## (Opcjonalne, ale bezpieczniejsze) Sprawdź, czy kafelek ma kolizję
				#var tile_data = ground_tilemap.get_cell_tile_data(target_map_coords)
				#if tile_data and tile_data.get_collision_polygons_count(0) > 0:
					#can_move_vertically = false # Zablokuj ruch, jeśli jest kafelek Z KOLIZJĄ
				## Jeśli nie potrzebujesz sprawdzać kolizji, wystarczy:
				## elif tile_data: # Jeśli jakikolwiek kafelek tam jest (bez sprawdzania kolizji)
				##    can_move_vertically = false
		## --- KONIEC DOKŁADNIEJSZEGO SPRAWDZENIA ---
#
#
		## Ustaw prędkość pionową tylko jeśli ruch jest dozwolony
		#if can_move_vertically and direction_y != 0:
			#velocity.y = direction_y * CLIMB_SPEED
		## Jeśli !can_move_vertically, velocity.y pozostaje 0
#
		## --- Logika animacji wspinaczki (zgodnie z oryginalnym kodem) ---
		#if direction_y != 0 or direction_x != 0: # Ruch w pionie LUB poziomie na drabinie
			#$AnimatedSprite2D.animation = "climb"
			#$AnimatedSprite2D.play()
			#$AnimatedSprite2D.speed_scale = 1
		#else: # Brak ruchu na drabinie
			#$AnimatedSprite2D.animation = "climb"
			#$AnimatedSprite2D.pause()
			#$AnimatedSprite2D.frame = 0
#
		## --- Odwracanie sprite'a (zgodnie z oryginalnym kodem) ---
		#if direction_x != 0:
			#$AnimatedSprite2D.flip_h = direction_x < 0
#
	#else:
		## --- Poza drabiną (zgodnie z oryginalnym kodem) ---
		#set_collision_mask_value(1, true) # Włącz kolizję z podłożem
#
		## Logika animacji chodzenia/stania/spadania
		#if is_on_floor():
			#if direction_x != 0:
				#$AnimatedSprite2D.animation = "walk"
				#$AnimatedSprite2D.flip_h = direction_x < 0
				#$AnimatedSprite2D.play()
			#else:
				#$AnimatedSprite2D.animation = "idle"
				#$AnimatedSprite2D.play()
		#else:
			## W powietrzu
			#$AnimatedSprite2D.animation = "idle" # Możesz chcieć zmienić na "fall"
			#$AnimatedSprite2D.play()
#
	## --- Wykonaj ruch (zawsze na końcu) ---
	#move_and_slide()
