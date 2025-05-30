extends Node2D

@onready var player = $WorldContainer/Player
@onready var game_over_layer = $GameOverLayer
@onready var pause_menu = $PauseMenuLayer/PauseMenu
@onready var global_tooltip_panel: PanelContainer = $UI/GlobalTooltip
@onready var global_tooltip_title: Label = $UI/GlobalTooltip/TooltipMargin/TooltipVBox/TooltipTitle
@onready var global_tooltip_description: Label = $UI/GlobalTooltip/TooltipMargin/TooltipVBox/TooltipDescription
@onready var global_tooltip_vbox: VBoxContainer = $UI/GlobalTooltip/TooltipMargin/TooltipVBox
@onready var global_tooltip_margin_container: MarginContainer = $UI/GlobalTooltip/TooltipMargin
@export var highlight_source_id: int = 3
@export var highlight_atlas_coords: Vector2i = Vector2i(0, 7)
@export var highlight_modulate: Color = Color(1.0, 1.0, 1.0, 1.0)
@export var purchased_upgrades_data: Dictionary = {}
@export var save_format_version: float = 1.0 # Możesz zmienić na 1.1, jeśli chcesz oznaczyć zmianę formatu
@export var player_data: Dictionary = {}
@export var world_data: Dictionary = {}
var highlighted_dig_cell: Vector2i = Vector2i(-1, -1)
var current_purchased_upgrades_data: Dictionary = {} # Używamy tylko tego do przechowywania ulepszeń
@onready var ground_tilemap = $WorldContainer/TileMap/Ground

const SAVE_PATH = "res://savegame.res"
var current_tooltip_instance: PanelContainer = null 
const SaveGameDataResource = preload("res://scripts/save_game_data.gd")
# Usunięto: var current_purchased_upgrades: Array[String] = []

func save_game():
	if not is_instance_valid(player):
		printerr("Cannot save: Player node is invalid.")
		return

	var ground_tilemap_node = $WorldContainer/TileMap/Ground as TileMapLayer # Zmieniona nazwa dla jasności
	if not is_instance_valid(ground_tilemap_node):
		printerr("Cannot save: Ground TileMap node is invalid.")
		return

	var player_data = {
		"position_x": player.global_position.x,
		"position_y": player.global_position.y,
		"current_hp": player.current_hp,
		"inventory": player.inventory, 
		"coins": player.coins,
		# Możesz tu dodać zapis current_digging_damage gracza, aby było bardziej bezpośrednie przy odczycie,
		# zamiast polegać tylko na ponownym zastosowaniu ulepszeń.
		# "current_pickaxe_damage": player.current_digging_damage 
	}

	var tilemap_ground_state = {}
	var used_cells = ground_tilemap_node.get_used_cells()
	for cell_coords in used_cells:
		var source_id = ground_tilemap_node.get_cell_source_id(cell_coords)
		if source_id != -1:
			tilemap_ground_state[cell_coords] = {
				"source_id": source_id,
				"atlas_coords": ground_tilemap_node.get_cell_atlas_coords(cell_coords),
				"alternative": ground_tilemap_node.get_cell_alternative_tile(cell_coords)
			}

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

	var save_resource = SaveGameDataResource.new()
	save_resource.save_format_version = 1.1 
	save_resource.player_data = player_data
	save_resource.world_data = world_data
	save_resource.purchased_upgrades_data = current_purchased_upgrades_data.duplicate(true)
	
	# Jeśli SaveGameData.gd nadal ma @export var purchased_upgrades: Array[String],
	# i nie chcesz go usuwać dla starszych save'ów, które mogą go oczekiwać (choć to mało prawdopodobne):
	# if save_resource.has("purchased_upgrades"): # Sprawdź czy pole istnieje w definicji zasobu
	#    save_resource.purchased_upgrades = [] # Wypełnij pustą tablicą

	var error = ResourceSaver.save(save_resource, SAVE_PATH)
	if error == OK:
		print("Game saved successfully to: ", ProjectSettings.globalize_path(SAVE_PATH))
	else:
		printerr("Error saving game: ", error)




# game.gd

# ... (reszta kodu game.gd) ...

func load_game() -> bool:
	if not FileAccess.file_exists(SAVE_PATH):
		print("No save file found at: ", SAVE_PATH)
		return false

	var loaded_resource = ResourceLoader.load(SAVE_PATH, "", ResourceLoader.CACHE_MODE_IGNORE)
	
	if not loaded_resource is SaveGameData:
		printerr("Failed to load save data: incorrect resource type at path: %s. Loaded: %s" % [SAVE_PATH, loaded_resource])
		return false

	# === POPRAWKA: Bezpośredni dostęp do właściwości ===
	# Jeśli właściwość nie została zapisana w pliku .res, Godot użyje wartości domyślnej ze skryptu.
	var save_version = loaded_resource.save_format_version # Bezpośredni dostęp
	print("Save file resource loaded. Version: ", save_version)
	# ====================================================

	current_purchased_upgrades_data.clear()

	var loaded_upgrades_from_dict = loaded_resource.purchased_upgrades_data
	if loaded_upgrades_from_dict is Dictionary and not loaded_upgrades_from_dict.is_empty():
		print("Loading upgrades from 'purchased_upgrades_data' (Dictionary format)...")
		for upgrade_id in loaded_upgrades_from_dict:
			var upgrade_value = loaded_upgrades_from_dict[upgrade_id]
			grant_upgrade(upgrade_id, upgrade_value, false)
		print("Loaded upgrades with values: ", current_purchased_upgrades_data)
	else:
		# === POPRAWKA: Sprawdzenie starego pola purchased_upgrades ===
		# Zakładamy, że jeśli SaveGameData.gd ma pole 'purchased_upgrades', to ono istnieje na loaded_resource.
		# Jeśli go nie ma w definicji skryptu, to odwołanie się do niego da błąd.
		# Bezpieczniej jest sprawdzić, czy skrypt zasobu w ogóle definiuje to pole,
		# ale dla uproszczenia, jeśli jest to tylko kompatybilność wsteczna i wiesz, że stare save'y
		# mogły mieć to pole, a nowe definicje SaveGameData.gd mogą go nie mieć, to poniższa logika
		# z próbą dostępu i sprawdzeniem typu jest ryzykowna bez dodatkowego zabezpieczenia.
		# Lepsze podejście, jeśli pole 'purchased_upgrades' może nie istnieć w definicji SaveGameData:
		var old_upgrades_from_array = null
		if "purchased_upgrades" in loaded_resource: # Sprawdź, czy klucz istnieje (działa dla obiektów dziedziczących z Object)
			old_upgrades_from_array = loaded_resource.purchased_upgrades
		
		if old_upgrades_from_array is Array and not old_upgrades_from_array.is_empty():
			print("Loading old save format for upgrades (Array of Strings). Applying defaults.")
			for upgrade_id_str in old_upgrades_from_array:
				var default_value = true 
				var pickaxe_upgrade_id_from_offer = "upgrade_pickaxe_dam" # ZASTĄP PEŁNYM ID
				if upgrade_id_str == pickaxe_upgrade_id_from_offer:
					default_value = 1.5 
				grant_upgrade(upgrade_id_str, default_value, false)
		elif loaded_upgrades_from_dict is Dictionary and loaded_upgrades_from_dict.is_empty(): # Jeśli nowy format był pusty
			print("No upgrade data found in 'purchased_upgrades_data' (it was empty).")
		elif not (loaded_upgrades_from_dict is Dictionary): # Jeśli nowy format nie był słownikiem
			printerr("'purchased_upgrades_data' was not a Dictionary. Old format also not found or invalid.")
		else: # Ogólny przypadek, gdy nic nie znaleziono
			print("No upgrade data (new or old format) found in save file, or data is empty/invalid.")
	# =============================================================
		
	if not is_instance_valid(player):
		printerr("Player node is not valid during load_game(). Aborting player data load.")
	else:
		var pd = loaded_resource.player_data
		if pd is Dictionary:
			player.global_position = Vector2(pd.get("position_x", player.global_position.x), pd.get("position_y", player.global_position.y))
			player.current_hp = pd.get("current_hp", player.max_hp)
			player.coins = pd.get("coins", 0)
			
			if pd.has("current_pickaxe_damage"):
				if player.has_method("apply_pickaxe_damage_upgrade"):
					var saved_damage = pd.get("current_pickaxe_damage", player.base_digging_damage)
					player.apply_pickaxe_damage_upgrade(saved_damage, false)
					print("Loaded and applied current_pickaxe_damage directly to player: ", saved_damage)

			var loaded_inventory_res = pd.get("inventory", null)
			if loaded_inventory_res is Inventory:
				player.inventory = loaded_inventory_res
			else:
				player.inventory = Inventory.new()
				if loaded_inventory_res != null:
					printerr("Loaded inventory data was not of type Inventory. Creating new.")
		else:
			printerr("Loaded 'player_data' is not a Dictionary or is missing. Player state might be default.")

	var ground_tilemap_node = $WorldContainer/TileMap/Ground as TileMapLayer
	var ladders_container_node = $WorldContainer/Ladders

	if is_instance_valid(ground_tilemap_node): ground_tilemap_node.clear()
	else: printerr("Ground TileMap node is not valid during load_game(). Cannot load tilemap state.")

	if is_instance_valid(ladders_container_node):
		for existing_ladder in ladders_container_node.get_children(): existing_ladder.queue_free()
	else: printerr("Ladders container node is not valid during load_game(). Cannot load ladders.")

	var wd = loaded_resource.world_data
	if wd is Dictionary:
		if is_instance_valid(ground_tilemap_node):
			var loaded_tilemap_state = wd.get("tilemap_ground_state", {})
			if loaded_tilemap_state is Dictionary:
				for cell_coords_variant in loaded_tilemap_state:
					if cell_coords_variant is Vector2i:
						var cell_coords: Vector2i = cell_coords_variant
						var tile_info = loaded_tilemap_state[cell_coords]
						if tile_info is Dictionary:
							ground_tilemap_node.set_cell(
								cell_coords,
								tile_info.get("source_id", -1),
								tile_info.get("atlas_coords", Vector2i(-1, -1)),
								tile_info.get("alternative", 0)
							)
			else:
				printerr("Loaded 'tilemap_ground_state' is not a Dictionary or is missing from world_data.")

		if is_instance_valid(ladders_container_node) and is_instance_valid(player) and player.ladder_scene:
			var loaded_ladders_array = wd.get("ladders", [])
			if loaded_ladders_array is Array:
				for ladder_pos_data in loaded_ladders_array:
					if ladder_pos_data is Dictionary:
						var ladder_instance = player.ladder_scene.instantiate()
						ladder_instance.global_position = Vector2(
							ladder_pos_data.get("x", 0.0),
							ladder_pos_data.get("y", 0.0)
						)
						ladders_container_node.add_child(ladder_instance)
						if not ladder_instance.entered_ladder.is_connected(player._on_ladder_entered):
							ladder_instance.entered_ladder.connect(player._on_ladder_entered)
						if not ladder_instance.exited_ladder.is_connected(player._on_ladder_exited):
							ladder_instance.exited_ladder.connect(player._on_ladder_exited)
			else:
				printerr("Loaded 'ladders' data is not an Array or is missing from world_data.")
		elif not is_instance_valid(player) or not player.ladder_scene:
			printerr("Cannot load ladders: Player or player.ladder_scene is invalid.")
	else:
		printerr("Loaded 'world_data' is not a Dictionary or is missing. World state might be default.")

	if is_instance_valid(player):
		for upg_id in current_purchased_upgrades_data:
			var upg_val = current_purchased_upgrades_data[upg_id]
			var pickaxe_upgrade_id_from_offer = "upgrade_pickaxe_dam" # ZASTĄP
			if upg_id == pickaxe_upgrade_id_from_offer:
				if player.has_method("apply_pickaxe_damage_upgrade") and (upg_val is float or upg_val is int):
					player.apply_pickaxe_damage_upgrade(float(upg_val), true)
		
		player.health_updated.emit(player.current_hp, player.max_hp)
		player.coins_updated.emit(player.coins)
		if player.inventory: player.inventory_updated.emit(player.inventory)
		player.stop_digging() 
	
	_reconnect_inventory_signals() 

	print("Game loaded successfully (full process completed).")
	get_tree().paused = false
	return true

# --- Nowa funkcja do dodawania monet (wywoływana przez ShopUI) ---
func add_player_coins(amount: int):
	if is_instance_valid(player):
		player.add_coins(amount)
	else:
		printerr("Game: Cannot add coins, player instance is invalid.")
		
# --- Nowa funkcja do usuwania monet (wywoływana przez ShopUI) ---
func remove_player_coins(amount: int) -> bool:
	if is_instance_valid(player):
		return player.remove_coins(amount)
	else:
		printerr("Game: Cannot remove coins, player instance is invalid.")
		return false
		
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


	if shop_ui_instance.has_method("set_initial_data_for_shop"):
		print("DEBUG: Calling set_initial_data_for_shop on shop_ui_instance.")
		shop_ui_instance.set_initial_data_for_shop(player.inventory, self)
	else:
		printerr("ShopUI instance (shop_ui_instance) does not have a 'set_initial_data_for_shop' method!")

	shop_ui_instance.show()
	print("DEBUG: shop_ui_instance.show() called. Is it visible on screen?")
	get_tree().paused = true
	print("Game paused. Shop UI should be open.")
func _initialize_new_game_state():
	print("Initializing new game state...")
	current_purchased_upgrades_data.clear()
	
	if is_instance_valid(player):
		player.global_position = Vector2.ZERO # Lub inna pozycja startowa
		player.current_hp = player.max_hp
		player.coins = 0 
		if player.inventory: 
			player.inventory.take_all_items()
			# Dodaj startowe drabiny (jeśli player._ready() nie jest wywoływane przy nowej grze z menu)
			if player.ladder_item_type and player.initial_ladders > 0:
				for i in range(player.initial_ladders):
					var it = InventoryItem.new()
					it.item_type = player.ladder_item_type
					player.inventory.put(it)
		
		# Zastosuj bazowe obrażenia kilofa
		if player.has_method("apply_pickaxe_damage_upgrade"):
			player.apply_pickaxe_damage_upgrade(1.0, true) # Bazowy mnożnik to 1.0
		
		player.stop_digging() # Zresetuj stan kopania

		# Podłączanie sygnałów (jeśli nie są już podłączone)
		var ui_node = $UI
		if ui_node:
			if player.has_signal("health_updated") and ui_node.has_method("_on_player_health_updated"):
				if not player.health_updated.is_connected(ui_node._on_player_health_updated): 
					player.health_updated.connect(ui_node._on_player_health_updated)
			if player.has_signal("coins_updated") and ui_node.has_method("_on_player_coins_updated"):
				if not player.coins_updated.is_connected(ui_node._on_player_coins_updated): 
					player.coins_updated.connect(ui_node._on_player_coins_updated)
		
		if player.has_signal("player_died"):
			if not player.player_died.is_connected(_on_player_died): 
				player.player_died.connect(_on_player_died)
		
		_reconnect_inventory_signals()

		# Wyemituj początkowe wartości dla UI
		player.health_updated.emit(player.current_hp, player.max_hp)
		player.coins_updated.emit(player.coins)
		if player.inventory: player.inventory_updated.emit(player.inventory)
	else:
		printerr("Game script: Cannot initialize new game state, Player node is invalid!")


func close_shop_ui() -> void:
	print("DEBUG game.gd: close_shop_ui() CALLED.")
	if is_instance_valid(shop_ui_instance):
		print("DEBUG game.gd: shop_ui_instance is valid. Calling hide(). Currently visible: ", shop_ui_instance.visible)
		shop_ui_instance.hide()
		print("DEBUG game.gd: shop_ui_instance.hide() called. Now visible: ", shop_ui_instance.visible)
	else:
		print("DEBUG game.gd: shop_ui_instance is NOT valid in close_shop_ui().")

	if get_tree() != null:
		print("DEBUG game.gd: Unpausing game. Current get_tree().paused state: ", get_tree().paused)
		get_tree().paused = false
		print("DEBUG game.gd: Game unpaused. New get_tree().paused state: ", get_tree().paused)
	else:
		print("DEBUG game.gd: get_tree() is null in close_shop_ui(). Cannot unpause.")
	print("Game unpaused state should be false. Shop UI should be closed.")
	
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
	if is_instance_valid(global_tooltip_panel): global_tooltip_panel.visible = false
	else: printerr("Game: GlobalTooltipPanel not found!")
	if is_instance_valid(global_tooltip_description): global_tooltip_description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	else: printerr("Game: global_tooltip_description Label not found!")

	if FileAccess.file_exists(SAVE_PATH):
		print("Save file found, attempting to load...")
		if not load_game(): 
			print("Load failed or save file corrupted, starting new game.")
			_initialize_new_game_state()
	else:
		print("No save file found, starting new game.")
		_initialize_new_game_state()

	if is_instance_valid(game_over_layer): game_over_layer.visible = false
	if is_instance_valid(pause_menu): pause_menu.hide()
	else: printerr("Game script cannot find PauseMenu node!")
	
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

# game.gd
# ... (reszta kodu game.gd bez zmian) ...
# scripts/game.gd

func show_and_update_global_tooltip_content(text_title: String, text_description: String, item_global_rect: Rect2) -> void:
	if not is_instance_valid(global_tooltip_panel):
		printerr("Game: show_and_update_global_tooltip_content - GlobalTooltipPanel is not valid.")
		return

	# 1. Ukryj panel i zresetuj minimalne rozmiary kontenerów i etykiet
	global_tooltip_panel.visible = false
	global_tooltip_panel.custom_minimum_size = Vector2.ZERO
	if is_instance_valid(global_tooltip_margin_container):
		global_tooltip_margin_container.custom_minimum_size = Vector2.ZERO
	if is_instance_valid(global_tooltip_vbox):
		global_tooltip_vbox.custom_minimum_size = Vector2.ZERO

	# 2. Ustaw nową zawartość tekstową i autowrap dla opisu
	if is_instance_valid(global_tooltip_title):
		global_tooltip_title.custom_minimum_size = Vector2.ZERO
		global_tooltip_title.text = text_title # Ustaw tekst tytułu
	
	if is_instance_valid(global_tooltip_description):
		global_tooltip_description.custom_minimum_size = Vector2.ZERO
		
		var is_short_text = text_description.length() < 60 and not "\n" in text_description
		if is_short_text:
			global_tooltip_description.autowrap_mode = TextServer.AUTOWRAP_OFF
		else:
			global_tooltip_description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		
		global_tooltip_description.text = text_description # Ustaw tekst opisu

	# Usunięto stąd wywołania update_minimum_size() i fit_child_in_rect()

	# 3. Uczyń panel widocznym (ale jego rozmiar jeszcze nie jest finalny)
	global_tooltip_panel.visible = true

	# 4. Użyj call_deferred do finalnego obliczenia rozmiaru i pozycjonowania
	#	Przekazujemy teraz także oryginalne teksty, aby mieć pewność, że używamy właściwych w logach
	call_deferred("_finalize_tooltip_layout_and_position", text_title, text_description, item_global_rect)
	
	print("Tooltip content set. Title: '", text_title, "'. Deferred finalization scheduled.")


# Zmieniona nazwa i logika funkcji wywoływanej przez call_deferred
func _finalize_tooltip_layout_and_position(final_text_title: String, final_text_description: String, item_global_rect: Rect2) -> void:
	if not is_instance_valid(global_tooltip_panel):
		printerr("Game _finalize_tooltip_layout_and_position: global_tooltip_panel is not valid.")
		return

	print("--- Finalizing Tooltip Layout ---")
	print("  Input Title: '", final_text_title, "'")
	print("  Input Description: '", final_text_description.substr(0,50), "...'")

	# 1. Upewnij się, że dzieci mają aktualne minimalne rozmiary
	if is_instance_valid(global_tooltip_title):
		if global_tooltip_title.text != final_text_title:
			global_tooltip_title.text = final_text_title 
		global_tooltip_title.update_minimum_size()
		print("    Title Label min_size:", global_tooltip_title.get_combined_minimum_size(), " current_size:", global_tooltip_title.size)

	if is_instance_valid(global_tooltip_description):
		var expected_autowrap = TextServer.AUTOWRAP_WORD_SMART
		if final_text_description.length() < 60 and not "\n" in final_text_description:
			expected_autowrap = TextServer.AUTOWRAP_OFF
		
		if global_tooltip_description.text != final_text_description or global_tooltip_description.autowrap_mode != expected_autowrap:
			global_tooltip_description.autowrap_mode = expected_autowrap
			global_tooltip_description.text = final_text_description
			
		global_tooltip_description.update_minimum_size()
		print("    Description Label min_size:", global_tooltip_description.get_combined_minimum_size(), " current_size:", global_tooltip_description.size, " (Autowrap: ", global_tooltip_description.autowrap_mode, ")")

	if is_instance_valid(global_tooltip_vbox):
		global_tooltip_vbox.update_minimum_size() 
		print("  VBox min_size:", global_tooltip_vbox.get_combined_minimum_size(), " current_size:", global_tooltip_vbox.size)

	if is_instance_valid(global_tooltip_margin_container):
		global_tooltip_margin_container.update_minimum_size()
		print("  MarginContainer min_size:", global_tooltip_margin_container.get_combined_minimum_size(), " current_size:", global_tooltip_margin_container.size)

	var panel_calculated_min_size = Vector2.ZERO
	if is_instance_valid(global_tooltip_panel):
		global_tooltip_panel.update_minimum_size() 
		panel_calculated_min_size = global_tooltip_panel.get_combined_minimum_size()
		print("  PanelContainer calculated_min_size (from children):", panel_calculated_min_size)
		
		# Ustaw custom_minimum_size, aby dać wskazówkę systemowi layoutu
		global_tooltip_panel.custom_minimum_size = panel_calculated_min_size
		print("  Set PanelContainer custom_minimum_size to:", panel_calculated_min_size)

	# Poczekaj na zakończenie cyklu layoutu
	await get_tree().process_frame 

	var tooltip_size: Vector2
	if is_instance_valid(global_tooltip_panel):
		var current_panel_size = global_tooltip_panel.size
		# Używamy panel_calculated_min_size, bo to jest minimalny rozmiar zawartości
		var target_content_size = panel_calculated_min_size 

		var style_min_size = Vector2.ZERO
		var panel_stylebox = global_tooltip_panel.get_theme_stylebox("panel")
		if panel_stylebox:
			style_min_size = panel_stylebox.get_minimum_size()
		
		var expected_actual_size = target_content_size + style_min_size
		print("    StyleBox min_size:", style_min_size, " Expected Actual Size (content_min + style_min):", expected_actual_size)

		if (current_panel_size - expected_actual_size).abs().length_squared() > 0.1 :
			print("    WARN: Panel size [", current_panel_size, "] not matching expected_actual_size [", expected_actual_size, "].")
			print("    Attempting to set size directly (LAST RESORT). Ensure Size Flags are SHRINK.")
			global_tooltip_panel.size = expected_actual_size # <--- RĘCZNE USTAWIENIE ROZMIARU
			# Po ręcznym ustawieniu rozmiaru, może być potrzebna kolejna klatka na ustabilizowanie
			await get_tree().process_frame 
			tooltip_size = global_tooltip_panel.size # Pobierz rozmiar ponownie
		else:
			tooltip_size = current_panel_size
	else:
		tooltip_size = Vector2.ZERO

	print("  PanelContainer final_size for positioning:", tooltip_size)
	# Pozycjonowanie
	var tooltip_pos: Vector2 = item_global_rect.position + Vector2(item_global_rect.size.x + 10, 0)
	var viewport_size: Vector2 = get_viewport_rect().size
	
	if tooltip_pos.x + tooltip_size.x > viewport_size.x:
		tooltip_pos.x = item_global_rect.position.x - tooltip_size.x - 10
	if tooltip_pos.x < 0:
		tooltip_pos.x = 5
		
	if tooltip_pos.y + tooltip_size.y > viewport_size.y:
		tooltip_pos.y = viewport_size.y - tooltip_size.y - 5
	if tooltip_pos.y < 0:
		tooltip_pos.y = 5

	global_tooltip_panel.global_position = tooltip_pos
	print("--- Tooltip Positioned. Final Panel Actual Size:", global_tooltip_panel.size, "---")
func _position_and_finalize_tooltip(item_global_rect: Rect2) -> void:
	if not is_instance_valid(global_tooltip_panel):
		printerr("Game _position_and_finalize_tooltip: global_tooltip_panel is not valid.")
		return

	print("--- Tooltip Finalization ---")
	if is_instance_valid(global_tooltip_title):
		print("  Title: '", global_tooltip_title.text, "'")
		print("    Title Label min_size:", global_tooltip_title.get_combined_minimum_size(), " size:", global_tooltip_title.size)
	if is_instance_valid(global_tooltip_description):
		print("  Description: '", global_tooltip_description.text.substr(0, 50), "...'") # Pokaż tylko początek długiego opisu
		print("    Description Label min_size:", global_tooltip_description.get_combined_minimum_size(), " size:", global_tooltip_description.size)
	if is_instance_valid(global_tooltip_vbox):
		print("  VBox min_size:", global_tooltip_vbox.get_combined_minimum_size(), " size:", global_tooltip_vbox.size)
	if is_instance_valid(global_tooltip_margin_container):
		print("  MarginContainer min_size:", global_tooltip_margin_container.get_combined_minimum_size(), " size:", global_tooltip_margin_container.size)
	
	var tooltip_size: Vector2 = global_tooltip_panel.size 
	print("  PanelContainer final_size:", tooltip_size)
	
	if tooltip_size.y > 300 and global_tooltip_description.text.length() < 70: # Bardziej rygorystyczny warunek
		print("  Tooltip WARN: Panel.size (", tooltip_size, ") still seems too large for short content.")

	var tooltip_pos: Vector2 = item_global_rect.position + Vector2(item_global_rect.size.x + 10, 0)
	var viewport_size: Vector2 = get_viewport_rect().size
	
	if tooltip_pos.x + tooltip_size.x > viewport_size.x:
		tooltip_pos.x = item_global_rect.position.x - tooltip_size.x - 10
	if tooltip_pos.x < 0:
		tooltip_pos.x = 5
		
	if tooltip_pos.y + tooltip_size.y > viewport_size.y:
		tooltip_pos.y = viewport_size.y - tooltip_size.y - 5
	if tooltip_pos.y < 0:
		tooltip_pos.y = 5

	global_tooltip_panel.global_position = tooltip_pos
	print("--- Tooltip Positioned ---")
	
func hide_global_tooltip() -> void:
	if is_instance_valid(global_tooltip_panel):
		global_tooltip_panel.visible = false
		global_tooltip_panel.custom_minimum_size = Vector2.ZERO
		if is_instance_valid(global_tooltip_margin_container):
			global_tooltip_margin_container.custom_minimum_size = Vector2.ZERO
		if is_instance_valid(global_tooltip_vbox):
			global_tooltip_vbox.custom_minimum_size = Vector2.ZERO
		if is_instance_valid(global_tooltip_title): # Dodaj to
			global_tooltip_title.custom_minimum_size = Vector2.ZERO
		if is_instance_valid(global_tooltip_description): # Dodaj to
			global_tooltip_description.custom_minimum_size = Vector2.ZERO
		print("Tooltip hidden and ALL container/label sizes reset.")

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
# game.gd
func _unhandled_input(event: InputEvent): # Dodanie typu dla 'event' dla jasności
	# Pauza / ESC
	# Dla akcji globalnych jak ESC, lepiej używać Input, bo event może być np. ruchem myszy
	if Input.is_action_just_pressed("ui_cancel"): # POPRAWKA TUTAJ
		get_viewport().set_input_as_handled() # Ważne, aby zrobić to na początku, jeśli obsługujemy
		if get_tree().paused:
			if is_instance_valid(shop_ui_instance) and shop_ui_instance.visible:
				print("DEBUG game.gd: ESC pressed, shop UI is open. Closing shop.")
				close_shop_ui()
			elif pause_menu and pause_menu.visible:
				pause_menu.resume_game()
		else:
			print("DEBUG game.gd: ESC pressed, game not paused. Opening pause menu.")
			get_tree().paused = true
			if pause_menu:
				pause_menu.show()
		return

	# Przełącz ekwipunek klawiszem I
	if Input.is_action_just_pressed("ui_inventory"): # POPRAWKA TUTAJ
		get_viewport().set_input_as_handled() # Ważne
		if is_instance_valid(shop_ui_instance) and shop_ui_instance.visible:
			print("DEBUG game.gd: 'I' pressed, but shop is open. Doing nothing with inventory.")
			return

		print("DEBUG game.gd: 'I' (ui_inventory) action JUST pressed.")
		var inv_ui = $UI/InventoryGridUI  
		if is_instance_valid(inv_ui):
			inv_ui.visible = not inv_ui.visible
			print("DEBUG game.gd: InventoryGridUI visibility toggled to: ", inv_ui.visible)
		else:
			printerr("DEBUG game.gd: InventoryGridUI node not found at $UI/InventoryGridUI")
		return

	# Interakcja (np. otwieranie/zamykanie sklepu klawiszem E)
	# Tutaj również używamy Input, ponieważ event może nie być Key press,
	# a my chcemy zareagować na akcję zdefiniowaną w InputMap.
	if Input.is_action_just_pressed("interact"): # POPRAWKA TUTAJ
		get_viewport().set_input_as_handled() # Ważne
		print("DEBUG game.gd: Global Input 'interact' (E) action JUST pressed.")
		if player_in_shop_area:
			print("DEBUG game.gd: Player IS in shop area.")
			if is_instance_valid(shop_ui_instance) and shop_ui_instance.visible:
				print("DEBUG game.gd: Shop UI is valid and VISIBLE. Attempting to CLOSE via 'E'...")
				close_shop_ui()
			elif (not is_instance_valid(shop_ui_instance)) or (is_instance_valid(shop_ui_instance) and not shop_ui_instance.visible):
				print("DEBUG game.gd: Shop UI is not valid OR not visible. Attempting to OPEN via 'E'...")
				open_shop_ui()
			else:
				print("DEBUG game.gd: 'interact' (E) pressed in shop area, but shop state is unexpected.")
		else:
			print("DEBUG game.gd: 'interact' (E) pressed, but player NOT in shop area.")
		return


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
	return current_purchased_upgrades_data.has(upgrade_id)
# W game.gd
func get_player_coins() -> int:
	if is_instance_valid(player):
		return player.coins
	return 0 # Zwróć 0, jeśli gracz nie jest dostępny
# Przyznaje graczowi ulepszenie
func grant_upgrade(upgrade_id: String, value = true, is_new_purchase: bool = true) -> void:
	if not current_purchased_upgrades_data.has(upgrade_id) or is_new_purchase:
		if is_new_purchase:
			print("Game: Granted new upgrade: '%s' with value: %s" % [upgrade_id, str(value)])
		else:
			print("Game: Applying loaded upgrade: '%s' with value: %s" % [upgrade_id, str(value)])

		current_purchased_upgrades_data[upgrade_id] = value
		
		var pickaxe_upgrade_id_from_offer = "upgrade_pickaxe_dam" # ZASTĄP PEŁNYM ID Z TWOJEJ OFERTY .tres
		# Musisz upewnić się, że to ID jest spójne z tym, co masz w `Reward String Data` pliku .tres oferty
		
		if upgrade_id == pickaxe_upgrade_id_from_offer: 
			if is_instance_valid(player) and player.has_method("apply_pickaxe_damage_upgrade"):
				if value is float or value is int:
					player.apply_pickaxe_damage_upgrade(float(value), true) # Zakładamy, że wartość z oferty to mnożnik
				else:
					printerr("Game: Value for pickaxe damage upgrade ('%s') is not a number: %s" % [upgrade_id, str(value)])
			else:
				printerr("Game: Player instance or apply_pickaxe_damage_upgrade method not found for upgrade: '%s'" % upgrade_id)
		# Dodaj 'elif' dla innych ulepszeń, np.:
		# elif upgrade_id == "can_dig_level_2":
		#     if is_instance_valid(player) and player.has_method("unlock_dig_level"):
		#         player.unlock_dig_level(2) # Lub przekazując 'value' jeśli to poziom
		#     else:
		#         printerr("Game: Player or unlock_dig_level method not found for '%s'" % upgrade_id)

	elif not is_new_purchase and current_purchased_upgrades_data.has(upgrade_id): # Ulepszenie jest już w słowniku, ale to wczytywanie
		print("Game: Re-applying (verifying) already loaded upgrade: '%s' with value: %s" % [upgrade_id, str(value)])
		# Ponownie zastosuj logikę, aby upewnić się, że stan gracza jest poprawny
		var pickaxe_upgrade_id_from_offer = "upgrade_pickaxe_dam" # ZASTĄP
		if upgrade_id == pickaxe_upgrade_id_from_offer:
			if is_instance_valid(player) and player.has_method("apply_pickaxe_damage_upgrade"):
				if value is float or value is int:
					player.apply_pickaxe_damage_upgrade(float(value), true)

# Reszta funkcji (add_player_coins, remove_player_coins, open_shop_ui, close_shop_ui, 
# _reconnect_inventory_signals, show_and_update_global_tooltip_content, _finalize_tooltip_layout_and_position,
# _position_and_finalize_tooltip, hide_global_tooltip, _on_player_died, _unhandled_input,
# _on_InventoryButton_pressed, remove_items_by_type, _process, _draw, _on_shop_area_body_entered,
# _on_shop_area_body_exited, handle_shop_shortcut)
# pozostaje taka sama jak w Twojej ostatniej wersji, chyba że chcesz je również przejrzeć pod kątem zmian.
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
			
# game.gd
# Dodaj tę nową funkcję gdzieś w skrypcie game.gd

func handle_shop_shortcut(event: InputEvent):
	# Ta funkcja jest wywoływana RĘCZNIE przez ShopUI._input
	print(">>> game.gd handle_shop_shortcut: Received forwarded event: ", event)

	# Sprawdź, jaka akcja odpowiada temu zdarzeniu
	# Musimy użyć Input.is_action... bo sam event tego nie powie bezpośrednio
	if Input.is_action_just_pressed("ui_cancel"):
		print(">>> game.gd handle_shop_shortcut: Handling forwarded 'ui_cancel' (ESC).")
		if is_instance_valid(shop_ui_instance) and shop_ui_instance.visible:
			print("DEBUG game.gd (via shortcut): ESC detected, shop open. Closing.")
			close_shop_ui()
		else:
			print("DEBUG game.gd (via shortcut): ESC detected, but shop not open/visible?")
		# Nie musimy tutaj robić set_input_as_handled, bo ShopUI już to zrobiło
		return

	if Input.is_action_just_pressed("interact"):
		print(">>> game.gd handle_shop_shortcut: Handling forwarded 'interact' (E).")
		# Zakładamy, że skoro ShopUI jest otwarte, to gracz jest w strefie
		if is_instance_valid(shop_ui_instance) and shop_ui_instance.visible:
			print("DEBUG game.gd (via shortcut): 'interact' (E) detected, shop open. Closing.")
			close_shop_ui()
		else:
			print("DEBUG game.gd (via shortcut): 'interact' (E) detected, but shop not open/visible?")
		# Nie musimy tutaj robić set_input_as_handled
		return

	# Możesz dodać obsługę innych akcji przekazanych przez ShopUI, jeśli zajdzie potrzeba
