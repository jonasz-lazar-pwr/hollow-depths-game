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

var player_inventory: Inventory = null
var game_manager: Node = null # Powinien być typu Node2D lub Node, który ma metody get_player_coins, remove_player_coins, has_upgrade, grant_upgrade

var _player_inventory_ref_for_setup: Inventory = null
var _game_manager_ref_for_setup: Node = null
var _is_ready_for_data_setup: bool = false

# Zasoby dla ofert
var ammolite_item_type_ref: InventoryItemType = preload("res://assets/inventory/ammolite.tres")
# Upewnij się, że ścieżka wskazuje na Twój zmodyfikowany plik .tres z obrazka
@export var pickaxe_upgrade_offers_list: Array[ShopOffer] = [
	preload("res://assets/shop_offers/upgrade_pickaxe_damage_1.tres"), # ZMIEŃ NA TWOJĄ ŚCIEŻKĘ JEŚLI INNA
preload("res://assets/shop_offers/upgrade_pickaxe_damage_2.tres"), # Nowy
	 preload("res://assets/shop_offers/upgrade_pickaxe_damage_3.tres"), # itd.
]

# Upewnij się, że ścieżka wskazuje na Twój zasób AtlasTexture ikony kilofa
var pickaxe_display_icon_ref: Texture2D = preload("res://assets/sprites/icons/pickaxe1.tres") # ZMIEŃ NA TWOJĄ ŚCIEŻKĘ

var offer_item_scene_ref: PackedScene = preload("res://assets/scenes/ShopOfferItemUI.tscn")

var _ui_to_offer_map: Dictionary = {} # Mapuje instancję UI oferty na obiekt ShopOffer

func _ready() -> void:
	print("ShopUI _ready CALLED.")
	if is_instance_valid(close_button):
		if not close_button.pressed.is_connected(close_ui):
			close_button.pressed.connect(close_ui)
	else: printerr("ShopUI _ready ERROR: CloseButton not found!")

	if is_instance_valid(switch_mode_button):
		if not switch_mode_button.pressed.is_connected(_on_switch_mode_button_pressed):
			switch_mode_button.pressed.connect(_on_switch_mode_button_pressed)
	else: printerr("ShopUI _ready ERROR: SwitchModeButton not found!")
	
	hide() 
	if _is_ready_for_data_setup: _perform_actual_shop_setup()


func set_initial_data_for_shop(p_inventory: Inventory, p_game_manager: Node) -> void:
	print("ShopUI set_initial_data_for_shop CALLED.")
	_player_inventory_ref_for_setup = p_inventory
	_game_manager_ref_for_setup = p_game_manager
	_is_ready_for_data_setup = true

	if is_inside_tree() and get_tree() != null:
		if is_instance_valid(title_label) and is_instance_valid(switch_mode_button) and is_instance_valid(offers_container):
			_perform_actual_shop_setup()
		else: printerr("ShopUI set_initial_data_for_shop ERROR: @onready vars NOT valid yet.")
	else: print("ShopUI set_initial_data_for_shop: Node not in tree yet. Setup via _ready.")

func _perform_actual_shop_setup():
	print("ShopUI _perform_actual_shop_setup CALLED.")
	if not is_instance_valid(_player_inventory_ref_for_setup) or not is_instance_valid(_game_manager_ref_for_setup):
		printerr("ShopUI _perform_actual_shop_setup ERROR: Missing refs!")
		return
	player_inventory = _player_inventory_ref_for_setup
	game_manager = _game_manager_ref_for_setup
	_update_ui_for_mode() 
	populate_offers()     


func _on_switch_mode_button_pressed():
	if current_shop_mode == ShopMode.SELL:
		current_shop_mode = ShopMode.BUY
	else:
		current_shop_mode = ShopMode.SELL
	_update_ui_for_mode() 
	populate_offers()     

func _update_ui_for_mode():
	if not is_instance_valid(title_label) or not is_instance_valid(switch_mode_button): return
	if current_shop_mode == ShopMode.SELL:
		title_label.text = "Miner's Exchange - Sell Items"
		switch_mode_button.text = "Switch to Buy Mode"
	else: 
		title_label.text = "Miner's Shop - Buy Upgrades"
		switch_mode_button.text = "Switch to Sell Mode"

func populate_offers() -> void:
	print("ShopUI populate_offers. Mode: ", current_shop_mode)
	if not is_instance_valid(offers_container): return
	for child in offers_container.get_children(): child.queue_free()
	_ui_to_offer_map.clear()
	if not player_inventory or not game_manager: return

	if current_shop_mode == ShopMode.SELL:
		var ammolites_owned = player_inventory.get_amount_of_item_type(ammolite_item_type_ref)
		var dynamic_sell_offer = ShopOffer.new() 
		dynamic_sell_offer.offer_name = "Sell All Ammolite"
		dynamic_sell_offer.cost_item = ammolite_item_type_ref
		dynamic_sell_offer.cost_amount = ammolites_owned
		dynamic_sell_offer.unique_id = "SELL_ALL_AMMOLITE_DYNAMIC"
		
		var offer_item_ui_sell = offer_item_scene_ref.instantiate()
		offers_container.add_child(offer_item_ui_sell)
		_ui_to_offer_map[offer_item_ui_sell] = dynamic_sell_offer
		
		if offer_item_ui_sell.has_method("setup_offer"):
			var can_actually_sell = ammolites_owned > 0 
			offer_item_ui_sell.setup_offer(dynamic_sell_offer, player_inventory, false, can_actually_sell, int(current_shop_mode))
			if offer_item_ui_sell.has_signal("purchase_requested") and not offer_item_ui_sell.purchase_requested.is_connected(_on_any_offer_item_pressed):
				offer_item_ui_sell.purchase_requested.connect(_on_any_offer_item_pressed)
			_connect_tooltip_signals(offer_item_ui_sell, dynamic_sell_offer)

	elif current_shop_mode == ShopMode.BUY:
		var current_pickaxe_lvl = 0
		if game_manager.has_method("get_upgrade_level"):
			current_pickaxe_lvl = game_manager.get_upgrade_level("PICKAXE_LEVEL_PROGRESS")
			print("ShopUI BUY: Current Pickaxe Level from game_manager: ", current_pickaxe_lvl)
		var next_offer_to_display: ShopOffer = null
		# Indeks w liście to current_pickaxe_lvl, bo jeśli masz Lvl 0, chcesz ofertę dla Lvl 1 (indeks 0).
		# Jeśli masz Lvl 1, chcesz ofertę dla Lvl 2 (indeks 1).
		if current_pickaxe_lvl < pickaxe_upgrade_offers_list.size():
			next_offer_to_display = pickaxe_upgrade_offers_list[current_pickaxe_lvl]
			print("ShopUI BUY: Next offer to display: ", next_offer_to_display.offer_name if next_offer_to_display else "None")
		else:
			print("ShopUI BUY: Max pickaxe level reached or no more offers defined.")
		
		if is_instance_valid(next_offer_to_display):
			var offer_item_ui_buy = offer_item_scene_ref.instantiate()
			offers_container.add_child(offer_item_ui_buy)
			_ui_to_offer_map[offer_item_ui_buy] = next_offer_to_display

			var player_coins = 0
			if game_manager.has_method("get_player_coins"): player_coins = game_manager.get_player_coins()
			var can_player_afford_buy = player_coins >= next_offer_to_display.cost_amount

			# `already_purchased_this_offer` dla ofert kupna będzie tu zawsze false,
			# bo pokazujemy ofertę *następnego* poziomu.
			offer_item_ui_buy.setup_offer(next_offer_to_display, player_inventory, false, can_player_afford_buy, int(current_shop_mode))
			
			if offer_item_ui_buy.has_signal("purchase_requested") and not offer_item_ui_buy.purchase_requested.is_connected(_on_any_offer_item_pressed):
				offer_item_ui_buy.purchase_requested.connect(_on_any_offer_item_pressed)
			_connect_tooltip_signals(offer_item_ui_buy, next_offer_to_display)
		else:
			var max_label = Label.new()
			max_label.text = "Pickaxe Max Level Reached"
			max_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			max_label.custom_minimum_size.y = 50
			offers_container.add_child(max_label)
	
	if is_instance_valid(offers_scroll): offers_scroll.scroll_vertical = 0

func _on_any_offer_item_pressed(offer_to_purchase: ShopOffer) -> void: 
	if not is_instance_valid(offer_to_purchase) or not player_inventory or not game_manager: return
	print("ShopUI: Purchase attempt for: '%s'" % offer_to_purchase.offer_name)

	if current_shop_mode == ShopMode.SELL:
		if offer_to_purchase.unique_id == "SELL_ALL_AMMOLITE_DYNAMIC":
			var amount_to_sell = player_inventory.get_amount_of_item_type(ammolite_item_type_ref)
			if amount_to_sell > 0 and game_manager.has_method("remove_items_by_type") and \
			   game_manager.remove_items_by_type(ammolite_item_type_ref, amount_to_sell):
				if game_manager.has_method("add_player_coins"):
					game_manager.add_player_coins(amount_to_sell * 30) 
					populate_offers()
	
	elif current_shop_mode == ShopMode.BUY:
		if (offer_to_purchase.reward_string_data == "PICKAXE_LEVEL_PROGRESS") and \
			game_manager.has_method("grant_leveled_upgrade") and \
			game_manager.has_method("get_player_coins") and \
			game_manager.has_method("remove_player_coins"):

			var cost_in_coins = offer_to_purchase.cost_amount 
			if game_manager.get_player_coins() >= cost_in_coins:
				if game_manager.remove_player_coins(cost_in_coins):
					game_manager.grant_leveled_upgrade(
						offer_to_purchase.reward_string_data,
						offer_to_purchase.level_number,
						offer_to_purchase.reward_float_data
					)
					populate_offers()
				else: printerr("ShopUI (BUY) ERROR: Failed to remove coins.")
			else: print("ShopUI: Not enough coins for '%s'." % offer_to_purchase.offer_name)
		else: printerr("ShopUI (BUY): Offer '%s' not pickaxe upgrade or game_manager missing methods." % offer_to_purchase.offer_name)
		
func _connect_tooltip_signals(item_ui_instance: Control, offer_data: ShopOffer):
	if not is_instance_valid(item_ui_instance) or not is_instance_valid(offer_data): return

	if item_ui_instance.has_signal("show_tooltip_requested"):
		if not item_ui_instance.show_tooltip_requested.is_connected(_on_item_show_tooltip_requested):
			item_ui_instance.show_tooltip_requested.connect(_on_item_show_tooltip_requested)
	if item_ui_instance.has_signal("hide_tooltip_requested"):
		if not item_ui_instance.hide_tooltip_requested.is_connected(_on_item_hide_tooltip_requested):
			item_ui_instance.hide_tooltip_requested.connect(_on_item_hide_tooltip_requested)

func close_ui() -> void:
	if is_instance_valid(game_manager):
		if game_manager.has_method("close_shop_ui"):
			game_manager.close_shop_ui()
		else:
			printerr("ShopUI close_ui ERROR: game_manager does not have close_shop_ui method!")
			hide(); get_tree().paused = false
	else:
		printerr("ShopUI close_ui ERROR: game_manager is not valid.")
		hide(); get_tree().paused = false # Awaryjne zamknięcie
		
func _on_item_show_tooltip_requested(text_title: String, text_description: String, item_global_rect: Rect2) -> void:
	if is_instance_valid(game_manager) and game_manager.has_method("show_and_update_global_tooltip_content"):
		game_manager.show_and_update_global_tooltip_content(text_title, text_description, item_global_rect)
	else:
		if not is_instance_valid(game_manager): printerr("ShopUI Tooltip ERROR: game_manager is null.")
		elif not game_manager.has_method("show_and_update_global_tooltip_content"): printerr("ShopUI Tooltip ERROR: game_manager missing 'show_and_update_global_tooltip_content'.")

func _on_item_hide_tooltip_requested() -> void:
	if is_instance_valid(game_manager) and game_manager.has_method("hide_global_tooltip"):
		game_manager.hide_global_tooltip()
	else:
		printerr("ShopUI Tooltip ERROR: Cannot hide tooltip, game_manager invalid or missing hide_global_tooltip method.")

func _input(event: InputEvent) -> void:
	if not self.visible: return

	if event is InputEventKey and event.is_pressed() and not event.is_echo():
		var should_pass_to_game = false
		if event.is_action_pressed("ui_cancel"): 
			should_pass_to_game = true
			get_viewport().set_input_as_handled()
		elif event.is_action_pressed("interact"): # Klawisz E do interakcji/zamknięcia sklepu
			should_pass_to_game = true
			get_viewport().set_input_as_handled()

		if should_pass_to_game:
			if is_instance_valid(game_manager) and game_manager.has_method("handle_shop_shortcut"):
				game_manager.handle_shop_shortcut(event)
			else:
				printerr("ShopUI _input ERROR: Cannot forward event, game_manager invalid or missing handle_shop_shortcut method.")
			return
