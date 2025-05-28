# res://scripts/ui/ShopUI.gd
class_name ShopUI
extends Control

enum ShopMode { SELL, BUY } # SELL = 0, BUY = 1
var current_shop_mode: ShopMode = ShopMode.SELL

@onready var offers_container: Container = $Background/MarginContainer/VBoxContainer/OffersScroll/OffersContainer
@onready var close_button: Button = $Background/MarginContainer/CloseButton 
@onready var offers_scroll: ScrollContainer = $Background/MarginContainer/VBoxContainer/OffersScroll
@onready var switch_mode_button: Button = $Background/MarginContainer/VBoxContainer/SwitchModeButton 
@onready var title_label: Label = $Background/MarginContainer/VBoxContainer/TitleLabel

# Zmienne, które będą ustawione przez game_manager
var player_inventory: Inventory = null
var game_manager: Node = null # Będzie to referencja do game.gd

# Zmienne pomocnicze do inicjalizacji
var _player_inventory_ref_for_setup: Inventory = null
var _game_manager_ref_for_setup: Node = null
var _is_ready_for_data_setup: bool = false # Flaga wskazująca, czy dane zostały przekazane

# Zasoby ofert i ikon
var ammolite_item_type_ref: InventoryItemType = preload("res://assets/inventory/ammolite.tres")
var pickaxe_upgrade_offer_template_ref: ShopOffer = preload("res://assets/shop_offers/unlock_digging1.tres") # unique_id to "unique_offer_id"
var pickaxe_icon_texture_ref: Texture2D = preload("res://assets/sprites/icons/pickaxe_icon.tres") # Upewnij się, że ta ścieżka jest poprawna
var offer_item_scene_ref: PackedScene = preload("res://assets/scenes/ShopOfferItemUI.tscn") # Upewnij się, że ta ścieżka jest poprawna

func _ready() -> void:
	print("ShopUI _ready CALLED. Checking initial @onready var values:")
	print("  _ready - CloseButton: ", close_button)
	print("  _ready - SwitchModeButton: ", switch_mode_button)
	print("  _ready - TitleLabel: ", title_label)
	print("  _ready - OffersContainer: ", offers_container)
	print("  _ready - OffersScroll: ", offers_scroll)

	if is_instance_valid(close_button):
		if not close_button.pressed.is_connected(close_ui):
			close_button.pressed.connect(close_ui)
	else:
		printerr("ShopUI _ready ERROR: CloseButton not found or invalid! Check path in @onready var.")

	if is_instance_valid(switch_mode_button):
		if not switch_mode_button.pressed.is_connected(_on_switch_mode_button_pressed):
			switch_mode_button.pressed.connect(_on_switch_mode_button_pressed)
	else:
		printerr("ShopUI _ready ERROR: SwitchModeButton not found or invalid! Check path in @onready var.")
	
	hide() # Ukryj na starcie

	# Jeśli dane zostały już ustawione PRZED _ready (mało prawdopodobne, ale dla pewności)
	if _is_ready_for_data_setup:
		print("ShopUI _ready: Data was set before _ready. Performing setup now.")
		_perform_actual_shop_setup()


# Ta funkcja jest teraz wywoływana z game.gd, aby przekazać dane
func set_initial_data_for_shop(p_inventory: Inventory, p_game_manager: Node) -> void:
	print("ShopUI set_initial_data_for_shop CALLED.")
	_player_inventory_ref_for_setup = p_inventory
	_game_manager_ref_for_setup = p_game_manager
	_is_ready_for_data_setup = true

	# Jeśli _ready już się wykonało (czyli węzeł jest w drzewie i @onready są gotowe),
	# możemy od razu uruchomić właściwy setup.
	if is_inside_tree() and get_tree() != null:
		# Dodatkowe sprawdzenie, czy kluczowe @onready vars są faktycznie dostępne
		if is_instance_valid(title_label) and is_instance_valid(switch_mode_button) and is_instance_valid(offers_container):
			print("ShopUI set_initial_data_for_shop: Node is in tree and @onready vars seem valid. Performing setup.")
			_perform_actual_shop_setup()
		else:
			printerr("ShopUI set_initial_data_for_shop ERROR: Node is in tree, BUT @onready vars are NOT valid yet. This is unexpected if _ready already ran.")
			# W tym miejscu można by dodać mechanizm ponownej próby lub logowania, ale jeśli _ready się wykonało, powinny być OK.
	else:
		print("ShopUI set_initial_data_for_shop: Node not in tree yet, or tree not available. Setup will be triggered by _ready.")


func _perform_actual_shop_setup():
	print("ShopUI _perform_actual_shop_setup CALLED. Verifying references before proceeding:")
	print("  _perform_actual_shop_setup - _player_inventory_ref_for_setup: ", _player_inventory_ref_for_setup)
	print("  _perform_actual_shop_setup - _game_manager_ref_for_setup: ", _game_manager_ref_for_setup)
	print("  _perform_actual_shop_setup - CloseButton: ", close_button)
	print("  _perform_actual_shop_setup - SwitchModeButton: ", switch_mode_button)
	print("  _perform_actual_shop_setup - TitleLabel: ", title_label)


	if not is_instance_valid(_player_inventory_ref_for_setup) or not is_instance_valid(_game_manager_ref_for_setup):
		printerr("ShopUI _perform_actual_shop_setup ERROR: Missing player inventory or game manager reference! Cannot proceed.")
		return

	# Przypisz referencje do właściwych zmiennych składowych
	player_inventory = _player_inventory_ref_for_setup
	game_manager = _game_manager_ref_for_setup
	
	_update_ui_for_mode() # Ustawia teksty przycisków/tytułów
	populate_offers()     # Wypełnia sklep przedmiotami


func _on_switch_mode_button_pressed():
	if current_shop_mode == ShopMode.SELL:
		current_shop_mode = ShopMode.BUY
	else:
		current_shop_mode = ShopMode.SELL
	_update_ui_for_mode() # Zaktualizuj teksty
	populate_offers()     # Przeładuj oferty


func _update_ui_for_mode():
	# Ta funkcja teraz tylko aktualizuje teksty na podstawie current_shop_mode
	# Zakłada, że title_label i switch_mode_button są już poprawnie zainicjowane przez @onready
	print("ShopUI _update_ui_for_mode CALLED. Checking @onready vars before use:")
	print("  _update_ui_for_mode - TitleLabel: ", title_label)
	print("  _update_ui_for_mode - SwitchModeButton: ", switch_mode_button)

	if not is_instance_valid(title_label) or not is_instance_valid(switch_mode_button):
		printerr("ShopUI _update_ui_for_mode ERROR: TitleLabel or SwitchModeButton is not valid. Cannot update UI texts.")
		return

	if current_shop_mode == ShopMode.SELL:
		title_label.text = "Miner's Exchange - Sell Items"
		switch_mode_button.text = "Switch to Buy Mode"
	else: # ShopMode.BUY
		title_label.text = "Miner's Shop - Buy Upgrades"
		switch_mode_button.text = "Switch to Sell Mode"


func populate_offers() -> void:
	print("ShopUI populate_offers CALLED. Current mode: ", current_shop_mode)
	print("  populate_offers - Checking offers_container: ", offers_container)

	if not is_instance_valid(offers_container):
		printerr("ShopUI populate_offers ERROR: OffersContainer not found or invalid!")
		return

	for child in offers_container.get_children():
		child.queue_free()

	if not player_inventory or not game_manager: # Te powinny być już ustawione przez _perform_actual_shop_setup
		printerr("ShopUI populate_offers ERROR: Inventory or GameManager not set up.")
		return

	# --- Logika dla trybu SELL ---
	if current_shop_mode == ShopMode.SELL:
		var ammolites_owned = player_inventory.get_amount_of_item_type(ammolite_item_type_ref)
		
		var dynamic_sell_offer = ShopOffer.new()
		dynamic_sell_offer.offer_name = "Sell All Ammolite"
		dynamic_sell_offer.description = "Sell %d Ammolite for %d Coins." % [ammolites_owned, ammolites_owned * 5]
		dynamic_sell_offer.cost_item = ammolite_item_type_ref
		dynamic_sell_offer.cost_amount = ammolites_owned
		dynamic_sell_offer.unique_id = "SELL_ALL_AMMOLITE_UNIQUE_ID"
		dynamic_sell_offer.reward_type = ShopOffer.RewardType.OTHER

		var offer_item_ui = offer_item_scene_ref.instantiate()
		if not is_instance_valid(offer_item_ui):
			printerr("ShopUI populate_offers ERROR: Failed to instantiate offer_item_scene_ref for SELL mode.")
			return
		
		offers_container.add_child(offer_item_ui)
		print("  populate_offers (SELL): Added sell offer UI to container.")
		
		if offer_item_ui.has_method("setup_offer"):
			var can_actually_sell = ammolites_owned > 0
			offer_item_ui.setup_offer(dynamic_sell_offer, player_inventory, false, can_actually_sell, int(current_shop_mode))
			
			if not offer_item_ui.purchase_requested.is_connected(_on_purchase_requested):
				offer_item_ui.purchase_requested.connect(_on_purchase_requested.bind(dynamic_sell_offer))
			_connect_tooltip_signals(offer_item_ui, dynamic_sell_offer)
		else:
			printerr("ShopUI populate_offers ERROR: Instantiated ShopOfferItemUI for selling does NOT have setup_offer method!")

	# --- Logika dla trybu BUY ---
	elif current_shop_mode == ShopMode.BUY:
		var display_offer_for_pickaxe = ShopOffer.new()
		# Użyj unique_id z załadowanego szablonu, aby identyfikować to ulepszenie
		display_offer_for_pickaxe.unique_id = pickaxe_upgrade_offer_template_ref.unique_id 
		display_offer_for_pickaxe.offer_name = "Upgrade Pickaxe (Dig Lvl 2)"
		
		var original_cost_ammolite = pickaxe_upgrade_offer_template_ref.cost_amount
		var buy_cost_in_coins = original_cost_ammolite * 10 # Np. 90 monet
		display_offer_for_pickaxe.description = "Allows digging harder rocks (Level 2).\nCost: %d Coins" % buy_cost_in_coins
		
		display_offer_for_pickaxe.cost_item = null # Ikona będzie specjalna (kilof), nie przedmiot kosztu
		var current_pickaxe_level_placeholder = 1 # Docelowo pobierz z game_manager
		display_offer_for_pickaxe.cost_amount = current_pickaxe_level_placeholder # Dla wyświetlenia "Lvl: X"
		display_offer_for_pickaxe.reward_type = pickaxe_upgrade_offer_template_ref.reward_type

		var is_already_purchased = false
		if game_manager.has_method("has_upgrade"):
			is_already_purchased = game_manager.has_upgrade(display_offer_for_pickaxe.unique_id)
		
		var can_player_afford = false
		if game_manager.has_method("get_player_coins"):
			if game_manager.get_player_coins() >= buy_cost_in_coins:
				can_player_afford = true

		var offer_item_ui_buy = offer_item_scene_ref.instantiate()
		if not is_instance_valid(offer_item_ui_buy):
			printerr("ShopUI populate_offers ERROR: Failed to instantiate offer_item_scene_ref for BUY mode.")
			return

		offers_container.add_child(offer_item_ui_buy)
		print("  populate_offers (BUY): Added buy offer UI to container.")

		if offer_item_ui_buy.has_method("setup_offer"):
			offer_item_ui_buy.setup_offer(display_offer_for_pickaxe, player_inventory, is_already_purchased, can_player_afford, int(current_shop_mode))
			if not offer_item_ui_buy.purchase_requested.is_connected(_on_purchase_requested):
				offer_item_ui_buy.purchase_requested.connect(_on_purchase_requested.bind(display_offer_for_pickaxe))
			_connect_tooltip_signals(offer_item_ui_buy, display_offer_for_pickaxe)
		else:
			printerr("ShopUI populate_offers ERROR: Instantiated ShopOfferItemUI for buying does NOT have setup_offer method!")
	
	if is_instance_valid(offers_scroll):
		offers_scroll.scroll_vertical = 0


func _connect_tooltip_signals(item_ui_instance: Control, offer_data: ShopOffer):
	if not is_instance_valid(item_ui_instance) or not is_instance_valid(offer_data): return

	if item_ui_instance.has_signal("show_tooltip_requested"):
		if not item_ui_instance.show_tooltip_requested.is_connected(_on_item_show_tooltip_requested):
			item_ui_instance.show_tooltip_requested.connect(_on_item_show_tooltip_requested)
	if item_ui_instance.has_signal("hide_tooltip_requested"):
		if not item_ui_instance.hide_tooltip_requested.is_connected(_on_item_hide_tooltip_requested):
			item_ui_instance.hide_tooltip_requested.connect(_on_item_hide_tooltip_requested)


func _on_purchase_requested(offer_to_purchase: ShopOffer) -> void:
	if not player_inventory or not game_manager: # Te powinny być już ustawione
		printerr("ShopUI _on_purchase_requested ERROR: Inventory or GameManager not set.")
		return
	if not is_instance_valid(offer_to_purchase):
		printerr("ShopUI _on_purchase_requested ERROR: offer_to_purchase is invalid.")
		return

	if current_shop_mode == ShopMode.SELL:
		if offer_to_purchase.unique_id == "SELL_ALL_AMMOLITE_UNIQUE_ID":
			var amount_to_sell = player_inventory.get_amount_of_item_type(ammolite_item_type_ref)
			if amount_to_sell > 0:
				if game_manager.has_method("remove_items_by_type") and \
				   game_manager.remove_items_by_type(ammolite_item_type_ref, amount_to_sell):
					if game_manager.has_method("add_player_coins"):
						game_manager.add_player_coins(amount_to_sell * 5)
					else: printerr("ShopUI _on_purchase_requested ERROR: game_manager missing add_player_coins method!")
					populate_offers()
				else: printerr("ShopUI _on_purchase_requested ERROR: Failed to remove ammolite or game_manager missing remove_items_by_type.")
			else: print("ShopUI _on_purchase_requested: No ammolite to sell.")
		else: printerr("ShopUI _on_purchase_requested (SELL): Unknown offer unique_id: ", offer_to_purchase.unique_id)

	elif current_shop_mode == ShopMode.BUY:
		if offer_to_purchase.unique_id == pickaxe_upgrade_offer_template_ref.unique_id:
			if not (game_manager.has_method("has_upgrade") and \
					game_manager.has_method("grant_upgrade") and \
					game_manager.has_method("get_player_coins") and \
					game_manager.has_method("remove_player_coins")):
				printerr("ShopUI _on_purchase_requested ERROR: game_manager is missing one or more required methods for pickaxe purchase!")
				return

			if game_manager.has_upgrade(offer_to_purchase.unique_id):
				print("ShopUI _on_purchase_requested: Pickaxe upgrade already purchased.")
				return

			var buy_cost_in_coins = pickaxe_upgrade_offer_template_ref.cost_amount * 10
			if game_manager.get_player_coins() >= buy_cost_in_coins:
				if game_manager.remove_player_coins(buy_cost_in_coins):
					game_manager.grant_upgrade(offer_to_purchase.unique_id)
					populate_offers()
				else:
					printerr("ShopUI _on_purchase_requested ERROR: Failed to remove coins for pickaxe upgrade.")
			else:
				print("ShopUI _on_purchase_requested: Not enough coins for pickaxe upgrade. Need %d." % buy_cost_in_coins)
		else:
			printerr("ShopUI _on_purchase_requested (BUY): Unknown offer unique_id: ", offer_to_purchase.unique_id)


func close_ui() -> void:
	if is_instance_valid(game_manager):
		if game_manager.has_method("close_shop_ui"):
			game_manager.close_shop_ui()
		else:
			printerr("ShopUI close_ui ERROR: game_manager does not have close_shop_ui method!")
			hide(); get_tree().paused = false
	else:
		printerr("ShopUI close_ui ERROR: game_manager is not valid.")
		hide(); get_tree().paused = false
		

func _on_item_show_tooltip_requested(text_title: String, text_description: String, item_global_rect: Rect2) -> void:
	if is_instance_valid(game_manager) and game_manager.has_method("display_global_tooltip"):
		game_manager.display_global_tooltip(text_title, text_description, item_global_rect)
	else:
		printerr("ShopUI _on_item_show_tooltip_requested ERROR: Cannot show tooltip, game_manager invalid or missing display_global_tooltip method.")


func _on_item_hide_tooltip_requested() -> void:
	if is_instance_valid(game_manager) and game_manager.has_method("hide_global_tooltip"):
		game_manager.hide_global_tooltip()
	else:
		printerr("ShopUI _on_item_hide_tooltip_requested ERROR: Cannot hide tooltip, game_manager invalid or missing hide_global_tooltip method.")


func _input(event: InputEvent) -> void:
	if not self.visible: return

	if event is InputEventKey and event.is_pressed() and not event.is_echo():
		var should_pass_to_game = false
		if event.is_action_pressed("ui_cancel"): 
			should_pass_to_game = true
			get_viewport().set_input_as_handled()
		elif event.is_action_pressed("interact"):
			should_pass_to_game = true
			get_viewport().set_input_as_handled()

		if should_pass_to_game:
			if is_instance_valid(game_manager) and game_manager.has_method("handle_shop_shortcut"):
				game_manager.handle_shop_shortcut(event)
			else:
				printerr("ShopUI _input ERROR: Cannot forward event, game_manager invalid or missing handle_shop_shortcut method.")
			return
