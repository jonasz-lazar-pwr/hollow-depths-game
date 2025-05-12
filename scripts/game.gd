# game.gd
extends Node2D

@onready var player = $WorldContainer/Player # Ścieżka do gracza
@onready var game_over_layer = $GameOverLayer
@onready var pause_menu = $PauseMenuLayer/PauseMenu # Upewnij się, że ścieżka jest poprawna!
# lub: @onready var pause_menu_layer = $PauseMenuLayer
#@onready var world_container = $WorldContainer

# --- Zmienne do podświetlania ---
@export var highlight_source_id: int = 3 # <<< ZMIEŃ na ID źródła twojego kafelka podświetlenia
@export var highlight_atlas_coords: Vector2i = Vector2i(0, 7) # <<< ZMIEŃ na koordynaty twojego kafelka podświetlenia
@export var highlight_modulate: Color = Color(1.0, 1.0, 1.0, 1.0) # Kolor/przezroczystość podświetlenia

var highlighted_dig_cell: Vector2i = Vector2i(-1, -1) # Przechowuje koordynaty podświetlanej komórki

@onready var ground_tilemap = $WorldContainer/TileMap/Ground # Upewnij się, że ścieżka jest poprawna

const SAVE_PATH = "res://savegame.res"

const SaveGameDataResource = preload("res://scripts/save_game_data.gd")
var current_purchased_upgrades: Array[String] = []
func save_game():
	if not is_instance_valid(player):
		printerr("Cannot save: Player node is invalid.")
		return

	var ground_tilemap = $WorldContainer/TileMap/Ground as TileMapLayer
	if not is_instance_valid(ground_tilemap):
		printerr("Cannot save: Ground TileMap node is invalid.")
		return

	# --- Prepare Player Data (Dictionary - stays the same) ---
	var player_data = {
		"position_x": player.global_position.x,
		"position_y": player.global_position.y,
		"current_hp": player.current_hp,
		"inventory": player.inventory # Store the actual Inventory resource
	}

	# --- Prepare World Data (Dictionary - stays the same) ---
	# TileMap State
	var tilemap_ground_state = {}
	var used_cells = ground_tilemap.get_used_cells()
	for cell_coords in used_cells:
		var source_id = ground_tilemap.get_cell_source_id(cell_coords)
		if source_id != -1:
			# Important: ResourceSaver CAN serialize Vector2i keys in dictionaries *within* a Resource
			tilemap_ground_state[cell_coords] = {
				"source_id": source_id,
				"atlas_coords": ground_tilemap.get_cell_atlas_coords(cell_coords),
				"alternative": ground_tilemap.get_cell_alternative_tile(cell_coords)
			}

	# Ladder Positions
	var ladder_positions = []
	for ladder_node in get_tree().get_nodes_in_group("ladders"):
		if is_instance_valid(ladder_node):
			ladder_positions.append({
				"x": ladder_node.global_position.x,
				"y": ladder_node.global_position.y
				})

	var world_data = {
		"tilemap_ground_state": tilemap_ground_state,
		"ladders": ladder_positions
	}

	# --- Assemble Save Data Resource ---
	# Create an INSTANCE of our custom resource
	var save_resource = SaveGameDataResource.new() # Use the preloaded script or just SaveGameData.new()

	# Populate its exported variables
	save_resource.save_format_version = 1.0
	save_resource.player_data = player_data
	save_resource.world_data = world_data
	save_resource.purchased_upgrades = current_purchased_upgrades.duplicate()
	# Assign other data if added to SaveGameData

	# --- Save to File ---
	# Pass the SaveGameData Resource object to ResourceSaver
	var error = ResourceSaver.save(save_resource, SAVE_PATH) # NO LONGER PASSING A DICTIONARY
	if error == OK:
		print("Game saved successfully to: ", ProjectSettings.globalize_path(SAVE_PATH))
		# show_save_message()
	else:
		printerr("Error saving game: ", error)
		# show_save_error_message()


# --- LOAD FUNCTION (Modified) ---
func load_game():
	if not FileAccess.file_exists(SAVE_PATH):
		print("No save file found at: ", SAVE_PATH)
		return false

	# --- Load from File ---
	# ResourceLoader now returns our SaveGameData instance or null
	var loaded_resource = ResourceLoader.load(SAVE_PATH)

	# Check if loading succeeded AND if it's the correct type
	if loaded_resource.has("purchased_upgrades"): # Dodaj sprawdzenie na wypadek starych save'ów
		current_purchased_upgrades = loaded_resource.purchased_upgrades.duplicate() # <-- DODAJ TO
	else:
		current_purchased_upgrades = [] # Zainicjuj jako pustą, jeśli brak w save

	print("Game loaded successfully.")
	print("Loaded upgrades: ", current_purchased_upgrades) # Debug
	get_tree().paused = false
	# _reconnect_inventory_signals() # Upewnij się, że to jest wywoływane
	return true

	# --- Version Check ---
	var save_version = loaded_resource.save_format_version # Access variable directly
	if save_version != 1.0:
		printerr("Save file version mismatch! Expected 1.0, got ", save_version)
		return false

	# --- Reset Current State BEFORE Loading ---
	if not is_instance_valid(player):
		printerr("Cannot load: Player node is invalid.")
		return false
	var ground_tilemap = $WorldContainer/TileMap/Ground as TileMapLayer
	if not is_instance_valid(ground_tilemap):
		printerr("Cannot load: Ground TileMap node is invalid.")
		return false

	ground_tilemap.clear()
	for ladder_node in get_tree().get_nodes_in_group("ladders"):
		if is_instance_valid(ladder_node):
			ladder_node.queue_free()
	player.stop_digging()

	_initialize_new_game_state()
	# --- Apply Loaded Data ---
	# Player Data - Access from the loaded resource's variables
	var loaded_player_data = loaded_resource.player_data
	player.global_position = Vector2(
		loaded_player_data.get("position_x", player.global_position.x),
		loaded_player_data.get("position_y", player.global_position.y)
	)
	player.current_hp = loaded_player_data.get("current_hp", player.max_hp)
	var loaded_inventory = loaded_player_data.get("inventory")
	if loaded_inventory is Inventory:
		player.inventory = loaded_inventory # Assign the loaded Inventory Resource
		# Re-emit signals
		player.emit_signal("inventory_updated", player.inventory)
		player.emit_signal("health_updated", player.current_hp, player.max_hp)
		# Reconnect signals if needed (though direct resource assignment might keep them)
		_reconnect_inventory_signals() # Optional helper function below
	else:
		printerr("Loaded inventory data is invalid or missing!")
		player.inventory = Inventory.new() # Fallback: create a new empty one


	# World Data - Access from the loaded resource's variables
	var loaded_world_data = loaded_resource.world_data

	# TileMap State: Recreate the ground layer
	var loaded_tilemap_state = loaded_world_data.get("tilemap_ground_state", {})
	# Vector2i keys ARE usually saved correctly when inside a Resource's dictionary
	for cell_coords in loaded_tilemap_state:
		var tile_info = loaded_tilemap_state[cell_coords]
		ground_tilemap.set_cell(
			cell_coords, # Should be Vector2i directly
			tile_info.get("source_id", -1),
			tile_info.get("atlas_coords", Vector2i(-1, -1)),
			tile_info.get("alternative", 0)
		)

	# Ladders: Recreate ladders
	var loaded_ladders = loaded_world_data.get("ladders", [])
	var ladders_container = $WorldContainer/Ladders
	if not is_instance_valid(ladders_container):
		printerr("Ladders container node is invalid!")
	else:
		for ladder_pos_data in loaded_ladders:
			if not player.ladder_scene:
				printerr("Player's ladder_scene is not set!")
				continue
			var ladder_instance = player.ladder_scene.instantiate()
			ladder_instance.global_position = Vector2(
				ladder_pos_data.get("x", 0.0),
				ladder_pos_data.get("y", 0.0)
				)
			ladders_container.add_child(ladder_instance)
			# Reconnect signals
			if not ladder_instance.entered_ladder.is_connected(player._on_ladder_entered):
				ladder_instance.entered_ladder.connect(player._on_ladder_entered)
			if not ladder_instance.exited_ladder.is_connected(player._on_ladder_exited):
				ladder_instance.exited_ladder.connect(player._on_ladder_exited)

	print("Game loaded successfully.")
	get_tree().paused = false
	return true

func open_shop_ui() -> void:
	print("DEBUG: open_shop_ui() called.") # Czy funkcja jest w ogóle wywoływana?

	if not is_instance_valid(player):
		printerr("Cannot open shop: Player is invalid")
		return
	print("DEBUG: Player is valid.")

	if not player.inventory: # Zakładając, że player.inventory to zasób Inventory
		printerr("Cannot open shop: Player inventory is invalid or null")
		return
	print("DEBUG: Player inventory is valid.")

	if not is_instance_valid(shop_ui_instance):
		print("DEBUG: shop_ui_instance is not valid, attempting to instantiate.")
		if not shop_ui_scene:
			printerr("Shop UI scene (shop_ui_scene variable) not preloaded or assigned!")
			return
		print("DEBUG: shop_ui_scene is loaded.")

		shop_ui_instance = shop_ui_scene.instantiate()
		if not is_instance_valid(shop_ui_instance):
			printerr("Failed to instantiate shop_ui_scene!")
			return
		print("DEBUG: shop_ui_instance instantiated successfully: ", shop_ui_instance)

		# WAŻNE: Upewnij się, że $UI to poprawna ścieżka do węzła,
		# który ma być rodzicem dla UI sklepu.
		# Może to być np. CanvasLayer lub główny Control node dla UI.
		var ui_parent_node = $UI # Zastąp $UI właściwą ścieżką, jeśli jest inna
		if is_instance_valid(ui_parent_node):
			ui_parent_node.add_child(shop_ui_instance)
			print("DEBUG: shop_ui_instance added as child to: ", ui_parent_node.name)
		else:
			printerr("Parent node for Shop UI ($UI or your path) not found!")
			shop_ui_instance.queue_free() # Ważne, aby zwolnić pamięć
			return
	else:
		print("DEBUG: shop_ui_instance is already valid.")


	# Przekaż potrzebne dane do UI sklepu
	if shop_ui_instance.has_method("setup_shop"):
		print("DEBUG: Calling setup_shop on shop_ui_instance.")
		shop_ui_instance.setup_shop(player.inventory, self)
	else:
		printerr("ShopUI instance (shop_ui_instance) does not have a 'setup_shop' method!")
		# Możesz chcieć nie pokazywać UI w takim przypadku, albo pokazać błąd w UI
		# shop_ui_instance.hide()
		# return

	shop_ui_instance.show()
	print("DEBUG: shop_ui_instance.show() called. Is it visible on screen?")
	get_tree().paused = true
	print("Game paused. Shop UI should be open.")

func close_shop_ui() -> void:
	print("DEBUG game.gd: close_shop_ui() called.") # Debug
	if is_instance_valid(shop_ui_instance):
		shop_ui_instance.hide()
	get_tree().paused = false
	print("Game unpaused. Shop UI should be closed.")
	
# Optional helper function to reconnect inventory signals after loading
func _reconnect_inventory_signals():
	if player and player.inventory:
		var ui_node = $UI # Assuming UI script is attached here
		if ui_node and ui_node.has_method("_on_inventory_changed"):
			if not player.inventory.item_added.is_connected(ui_node._on_inventory_changed):
				player.inventory.item_added.connect(ui_node._on_inventory_changed)
			if not player.inventory.item_removed.is_connected(ui_node._on_inventory_changed):
				player.inventory.item_removed.connect(ui_node._on_inventory_changed)
		# Remove the passthrough connection if it exists, as UI connects directly now
		# (Or adjust based on your actual signal flow)
		#if player.inventory.item_added.is_connected(_on_inventory_changed_passthrough):
		#	player.inventory.item_added.disconnect(_on_inventory_changed_passthrough)
		#if player.inventory.item_removed.is_connected(_on_inventory_changed_passthrough):
		#	player.inventory.item_removed.disconnect(_on_inventory_changed_passthrough)


# Remove the _on_inventory_changed_passthrough function if not needed

func _ready():
	# Load game attempt
	if FileAccess.file_exists(SAVE_PATH):
		print("Save file found, attempting to load...")
		if load_game():
			# If load succeeded, player signals are already handled within load_game
			pass
		else:
			# If load failed, proceed as new game
			print("Load failed, starting new game.")
			_initialize_new_game_state()
	else:
		print("No save file found, starting new game.")
		_initialize_new_game_state()

	if is_instance_valid(game_over_layer):
		game_over_layer.visible = false
	if pause_menu:
		pause_menu.hide()
	else:
		printerr("Game script cannot find PauseMenu node!")
	var ground_tilemap = $WorldContainer/TileMap/Ground as TileMapLayer
	if is_instance_valid(ground_tilemap) and is_instance_valid(ground_tilemap.tile_set): # Dodatkowe sprawdzenie tile_set
		# Pozycja środka komórki (4, -2)
		var cell_4_n2_center = ground_tilemap.map_to_local(Vector2i(4, -2))
		
		# Rozmiar kafelka jako Vector2
		var tile_size_float: Vector2 = Vector2(ground_tilemap.tile_set.tile_size) # <--- KONWERSJA

		# Lewy górny róg kafla (4,-2):
		var top_left_of_cell_4_n2 = cell_4_n2_center - tile_size_float / 2.0
		
		# Środek obszaru 2x2 będzie przesunięty o (tile_size.x, tile_size.y) od lewego górnego rogu kafla (4,-2)
		var shop_area_center_pos = top_left_of_cell_4_n2 + tile_size_float # <--- UŻYJ tile_size_float
		print("Obliczona pozycja ShopArea: ", shop_area_center_pos)
	else:
		if not is_instance_valid(ground_tilemap):
			printerr("Ground TileMap not found for ShopArea position calculation!")
		elif not is_instance_valid(ground_tilemap.tile_set):
			printerr("TileSet on Ground TileMap not found for ShopArea position calculation!")


# Helper to setup connections for a new game or failed load
func _initialize_new_game_state():
	current_purchased_upgrades = []
	if player:
		if player.has_signal("player_died"):
			if not player.player_died.is_connected(_on_player_died):
				player.player_died.connect(_on_player_died)
		else:
			printerr("Player node does not have 'player_died' signal!")
		
		var ui_node = $UI # Pobierz węzeł UI
		if ui_node and ui_node.has_method("_on_player_health_updated"): # Sprawdź czy UI i funkcja istnieją
			if not player.health_updated.is_connected(ui_node._on_player_health_updated):
				# Połącz sygnał 'health_updated' z gracza z funkcją '_on_player_health_updated' w UI
				var err = player.health_updated.connect(ui_node._on_player_health_updated)
				if err != OK:
					printerr("GAME ERROR: Failed to connect player.health_updated to ui._on_player_health_updated. Error: ", err)
				else:
					print("GAME INFO: Connected player.health_updated to ui._on_player_health_updated.") # Potwierdzenie w konsoli
		else:
			# Komunikaty błędów, jeśli coś poszło nie tak
			if not ui_node: printerr("GAME ERROR: UI node ($UI) not found for health connection!")
			elif not ui_node.has_method("_on_player_health_updated"): printerr("GAME ERROR: UI node script does not have _on_player_health_updated method!")
		
		_reconnect_inventory_signals() # Use the helper
	else:
		printerr("Game script cannot find Player node at path $WorldContainer/Player!")

func _on_player_died():
	print("Game Over sequence started.")

	# 1. Zatrzymaj główną logikę gry
	get_tree().paused = true

	# 2. Pokaż warstwę Game Over (która teraz zawiera efekt grayscale i napis)
	if is_instance_valid(game_over_layer):
		game_over_layer.visible = true
		print("GameOverLayer visibility set to true.") # Dodaj log dla pewności
	else:
		printerr("game_over_layer is not valid, cannot show Game Over screen!")

	# 3. TODO: Odtwórz dźwięk "Game Over"
	# 4. TODO: Przyciski Restart/Quit

# Ta funkcja przechwytuje input, który nie został obsłużony gdzie indziej
func _unhandled_input(event):
	# pauza / ESC
	if Input.is_action_just_pressed("ui_cancel"):
		if get_tree().paused:
			if pause_menu and pause_menu.visible:
				pause_menu.resume_game()
		else:
			get_tree().paused = true
			if pause_menu:
				pause_menu.show()
		get_viewport().set_input_as_handled()

	# przełącz ekwipunek klawiszem I
	if Input.is_action_just_pressed("ui_inventory"):
		print("DEBUG: wykryto I!")  # zobaczymy w konsoli
		var inv_ui = $UI/InventoryGridUI  
		inv_ui.visible = not inv_ui.visible
		get_viewport().set_input_as_handled()
		if player_in_shop_area and event.is_action_pressed("interact"): # Załóżmy, że masz akcję "interact" zmapowaną na 'E'
			if not is_instance_valid(shop_ui_instance) or not shop_ui_instance.visible:
				open_shop_ui()
				get_viewport().set_input_as_handled() # Zatrzymaj dalsze przetwarzanie tego eventu
		# Można dodać else: close_shop_ui() jeśli chcemy zamykać sklep tym samym klawiszem
	if player_in_shop_area and event.is_action_pressed("interact"):
		print("DEBUG: 'interact' action pressed!")
		if is_instance_valid(shop_ui_instance) and shop_ui_instance.visible: # Jeśli UI jest stworzone I WIDOCZNE
			print("DEBUG: Shop UI is visible, attempting to close...")
			close_shop_ui() # Wywołaj zamknięcie
			get_viewport().set_input_as_handled()
		elif not is_instance_valid(shop_ui_instance) or not shop_ui_instance.visible: # Jeśli nie jest stworzone LUB jest niewidoczne
			print("DEBUG: Conditions met to open shop UI...")
			open_shop_ui()
			get_viewport().set_input_as_handled()


#
#func _on_player_died():
	#print("Game Over sequence started.")
	## Upewnij się, że menu pauzy jest ukryte, gdy pojawi się Game Over
	#if pause_menu and pause_menu.visible:
		#pause_menu.hide()
	## ... (reszta logiki game over) ...
	#get_tree().paused = true
	## ... (reszta logiki game over) ...


func _on_InventoryButton_pressed():
 # Znajdź node z UI ekwipunku:
	var inv_ui = $UI/InventoryGridUI
	print("Znaleziono Inventory UI node: ", inv_ui) # Sprawdź, czy nie jest null
	if inv_ui:
		inv_ui.visible = not inv_ui.visible
		print("Ustawiono visible na: ", inv_ui.visible)
	else:
		printerr("Nie znaleziono node'a InventoryGridUI pod ścieżką $UI/InventoryGridUI!")
	
# game.gd
# ... (reszta kodu na górze) ...
# Sprawdza, czy gracz posiada dane ulepszenie
func has_upgrade(upgrade_id: String) -> bool:
	return upgrade_id in current_purchased_upgrades

# Przyznaje graczowi ulepszenie
func grant_upgrade(upgrade_id: String) -> void:
	if not has_upgrade(upgrade_id):
		current_purchased_upgrades.append(upgrade_id)
		print("Granted upgrade:", upgrade_id)
		# Tutaj możesz wywołać specyficzne funkcje dla danego ulepszenia,
		# jeśli sama obecność ID w tablicy nie wystarcza.
		# Np. if upgrade_id == "enable_double_jump": player.can_double_jump = true
	else:
		print("Attempted to grant already owned upgrade:", upgrade_id)

# Funkcja pomocnicza do usuwania przedmiotów (potrzebna w ShopUI)
# Zwraca true jeśli usunięto pomyślnie, false w przeciwnym razie
func remove_items_by_type(item_type: InventoryItemType, amount: int) -> bool:
	if not is_instance_valid(player) or not player.inventory:
		printerr("Cannot remove items: Player or inventory invalid.")
		return false

	if player.inventory.get_amount_of_item_type(item_type) < amount:
		printerr("Cannot remove items: Not enough items in inventory (should have been checked earlier).")
		return false # Chociaż to powinno być sprawdzone w UI

	var items_to_remove: Array[InventoryItem] = []
	# Znajdź konkretne instancje przedmiotów do usunięcia
	for slot in player.inventory.slots:
		if slot.type == item_type:
			for item in slot.items:
				if items_to_remove.size() < amount:
					items_to_remove.append(item)
				else:
					break # Mamy już wystarczającą ilość
		if items_to_remove.size() >= amount:
			break # Mamy już wystarczającą ilość

	if items_to_remove.size() != amount:
		printerr("Inventory logic error: Could not find exact amount of items to remove.")
		 # To może się zdarzyć przy błędach w logice Inventory
		return false

	# Usuń znalezione przedmioty
	for item_instance in items_to_remove:
		player.inventory.take(item_instance) # take powinien emitować sygnał

	print("Removed %d items of type %s" % [amount, item_type.name])
	# Sygnał inventory_updated powinien zostać wyemitowany przez inventory.take
	# player.emit_signal("inventory_updated", player.inventory) # Niepotrzebne jeśli take emituje
	return true
	
func _process(delta: float) -> void:
	# --- Logika podświetlania kopania ---
	var new_highlight_cell = Vector2i(-1, -1) # Domyślnie brak podświetlenia

	# Sprawdź, czy gracz i tilemap są nadal poprawne
	if not is_instance_valid(player) or not is_instance_valid(ground_tilemap):
		if highlighted_dig_cell != Vector2i(-1, -1): # Jeśli coś było podświetlone, zaktualizuj
			highlighted_dig_cell = Vector2i(-1, -1)
			queue_redraw() # Odśwież, aby usunąć stare podświetlenie
		return # Zakończ, jeśli brakuje gracza lub tilemapy

	var mouse_pos = get_global_mouse_position()
	var mouse_cell = ground_tilemap.local_to_map(ground_tilemap.to_local(mouse_pos))
	var player_cell = ground_tilemap.local_to_map(ground_tilemap.to_local(player.global_position))
	var distance = abs(mouse_cell.x - player_cell.x) + abs(mouse_cell.y - player_cell.y)

	# DEBUG PRINT: Zobaczmy koordynaty i dystans
	# print("Mouse Cell: ", mouse_cell, " Player Cell: ", player_cell, " Distance: ", distance)

	if distance <= 1:
		# Sprawdź, czy w komórce jest kafelek
		var source_id = ground_tilemap.get_cell_source_id(mouse_cell)
		if source_id != -1:
			# Sprawdź, czy kafelek jest 'diggable'
			var tile_data = ground_tilemap.get_cell_tile_data(mouse_cell)
			var is_diggable = tile_data and tile_data.get_custom_data("diggable")

			# DEBUG PRINT: Sprawdźmy dane kafelka
			# print("  Tile Source ID: ", source_id, " Is Diggable: ", is_diggable)

			if is_diggable:
				# Sprawdź, czy to nie jest komórka z drabiną
				var is_ladder = false
				for ladder in get_tree().get_nodes_in_group("ladders"):
					if not is_instance_valid(ladder): continue # Dodatkowe zabezpieczenie
					var ladder_cell = ground_tilemap.local_to_map(ground_tilemap.to_local(ladder.global_position))
					if ladder_cell == mouse_cell:
						is_ladder = true
						# DEBUG PRINT:
						# print("  Detected Ladder at cell.")
						break
				if not is_ladder:
					new_highlight_cell = mouse_cell # Ustaw tę komórkę do podświetlenia
					# DEBUG PRINT:
					# print("  Setting highlight cell to: ", new_highlight_cell)

	# Zaktualizuj podświetlenie tylko jeśli się zmieniło
	if new_highlight_cell != highlighted_dig_cell:
		# DEBUG PRINT:
		# print("Highlight changed! Old: ", highlighted_dig_cell, " New: ", new_highlight_cell, " Requesting redraw.")
		highlighted_dig_cell = new_highlight_cell
		queue_redraw() # Poproś o przerysowanie

# --- Funkcja rysowania ---
func _draw() -> void:
	# DEBUG PRINT:
	# print("_draw() called. Highlighted cell: ", highlighted_dig_cell)

	if highlighted_dig_cell != Vector2i(-1, -1) and is_instance_valid(ground_tilemap) and ground_tilemap.tile_set:
		var tile_set = ground_tilemap.tile_set
		var tile_size = tile_set.tile_size

		# Oblicz pozycję i rozmiar docelowy na ekranie
		# Ważne: map_to_local daje ŚRODEK komórki dla map kwadratowych/prostokątnych
		var draw_pos_center = ground_tilemap.map_to_local(highlighted_dig_cell)
		# Potrzebujemy lewego górnego rogu do rysowania
		var dest_rect = Rect2(draw_pos_center - tile_size / 2.0, tile_size)

		# --- DEBUG: Rysuj prosty prostokąt zamiast tekstury ---
		#print("  Drawing SIMPLE RED RECT at: ", dest_rect)
		#draw_rect(dest_rect, Color.RED, false, 2.0) # Rysuj czerwony kontur
		# -------------------------------------------------------

		# --- Oryginalne rysowanie tekstury ---
		if not tile_set.has_source(highlight_source_id):
			print("Highlight Error: TileSet does not have source ID: ", highlight_source_id) # Zmieniono z printerr na print dla testów
			return
		var source = tile_set.get_source(highlight_source_id)
		if not source is TileSetAtlasSource:
			print("Highlight Error: Source ID ", highlight_source_id, " is not a TileSetAtlasSource.") # Zmieniono z printerr na print dla testów
			return
		var atlas_texture = source.texture
		if not atlas_texture:
			print("Highlight Error: AtlasSource with ID ", highlight_source_id, " has no texture.") # Zmieniono z printerr na print dla testów
			return
		var src_rect = source.get_tile_texture_region(highlight_atlas_coords, 0)
		if src_rect == Rect2i(0,0,0,0) and not source.has_tile(highlight_atlas_coords):
			print("Highlight Error: Atlas Coords ", highlight_atlas_coords, " not found in source ID ", highlight_source_id) # Zmieniono z printerr na print dla testów
			return
		#print("  Drawing highlight texture: ", atlas_texture.resource_path if atlas_texture else "null", " SrcRect: ", src_rect, " DestRect: ", dest_rect, " Modulate: ", highlight_modulate)
		draw_texture_rect_region(atlas_texture, dest_rect, src_rect, highlight_modulate)
		# --- Koniec oryginalnego rysowania ---

	#else: # DEBUG PRINT:
		#if highlighted_dig_cell == Vector2i(-1,-1):
			#print("  Not drawing highlight: cell is invalid.")
		#elif not is_instance_valid(ground_tilemap):
			#print("  Not drawing highlight: ground_tilemap invalid.")
		#elif not ground_tilemap.tile_set:
			#print("  Not drawing highlight: no tileset on ground_tilemap.")
var player_in_shop_area: bool = false
var shop_ui_scene: PackedScene = preload("res://assets/scenes/ShopUI.tscn")
var shop_ui_instance: Control = null # Instancja UI sklepu
func _on_shop_area_body_entered(body: Node2D) -> void:
	if body == player: # Sprawdź, czy to gracz wszedł
		player_in_shop_area = true
		print("Player entered shop area")
		# Możesz dodać jakiś wizualny wskaźnik, np. tekst "Press E to shop"
		# get_node("UI/ShopPromptLabel").visible = true

func _on_shop_area_body_exited(body: Node2D) -> void:
	if body == player:
		player_in_shop_area = false
		print("Player exited shop area")
		# Ukryj wskaźnik
		# get_node("UI/ShopPromptLabel").visible = false
		# Jeśli UI sklepu jest otwarte, zamknij je
		if is_instance_valid(shop_ui_instance) and shop_ui_instance.visible:
			close_shop_ui()
