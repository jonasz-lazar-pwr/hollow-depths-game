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
var game_manager: Node = null

var _player_inventory_ref_for_setup: Inventory = null
var _game_manager_ref_for_setup: Node = null
var _is_ready_for_data_setup: bool = false

# Zasoby dla ofert sprzedaży
var ammolite_item_type_ref: InventoryItemType = preload("res://assets/inventory/ammolite.tres")
var jasper_item_type_ref: InventoryItemType = preload("res://assets/inventory/jasper.tres")
var malachite_item_type_ref: InventoryItemType = preload("res://assets/inventory/malachite.tres")
var crystal_item_type_ref: InventoryItemType = preload("res://assets/inventory/crystal.tres")

# Zasoby dla ofert zakupu
@export var pickaxe_upgrade_offers_list: Array[ShopOffer] = [
	preload("res://assets/shop_offers/upgrade_pickaxe_damage_1.tres"),
	preload("res://assets/shop_offers/upgrade_pickaxe_damage_2.tres"),
	preload("res://assets/shop_offers/upgrade_pickaxe_damage_3.tres"),
]
var buy_ladder_offer_ref: ShopOffer = preload("res://assets/shop_offers/buy_ladder.tres")
var ladder_item_type_for_purchase: InventoryItemType = preload("res://assets/inventory/ladder.tres")
var buy_health_potion_offer_ref: ShopOffer = preload("res://assets/shop_offers/buy_health_potion.tres") # <<< NOWA REFERENCJA

var offer_item_scene_ref: PackedScene = preload("res://assets/scenes/ShopOfferItemUI.tscn")

var _ui_to_offer_map: Dictionary = {}

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
		title_label.text = "Miner's Shop - Buy Upgrades & Items" # Zmiana tytułu
		switch_mode_button.text = "Switch to Sell Mode"

func populate_offers() -> void:
	print("ShopUI populate_offers. Mode: ", current_shop_mode)
	if not is_instance_valid(offers_container): return
	for child in offers_container.get_children(): child.queue_free()
	_ui_to_offer_map.clear()
	if not player_inventory or not game_manager: return

	var sellable_items_config = [
		[ammolite_item_type_ref, "Sell All Ammolite", "SELL_ALL_AMMOLITE_DYNAMIC", 30],
		[jasper_item_type_ref, "Sell All Jasper", "SELL_ALL_JASPER_DYNAMIC", 50],
		[malachite_item_type_ref, "Sell All Malachite", "SELL_ALL_MALACHITE_DYNAMIC", 100],
		[crystal_item_type_ref, "Sell All Crystal", "SELL_ALL_CRYSTAL_DYNAMIC", 200]
	]

	if current_shop_mode == ShopMode.SELL:
		for item_config in sellable_items_config:
			var item_type: InventoryItemType = item_config[0]
			var offer_name: String = item_config[1]
			var offer_id: String = item_config[2]
			var price_per_unit: int = item_config[3]

			if not is_instance_valid(item_type):
				printerr("ShopUI: Invalid ItemType in sellable_items_config for ID '", offer_id, "'. Expected: ", item_type)
				continue
			var items_owned = player_inventory.get_amount_of_item_type(item_type)
			var dynamic_sell_offer = ShopOffer.new()
			dynamic_sell_offer.offer_name = offer_name
			dynamic_sell_offer.description = "Sell all your %s for %d coins each." % [item_type.name, price_per_unit]
			dynamic_sell_offer.cost_item = item_type
			dynamic_sell_offer.cost_amount = items_owned
			dynamic_sell_offer.unique_id = offer_id
			dynamic_sell_offer.display_icon = item_type.texture
			var offer_item_ui_sell = offer_item_scene_ref.instantiate()
			offers_container.add_child(offer_item_ui_sell)
			_ui_to_offer_map[offer_item_ui_sell] = dynamic_sell_offer
			if offer_item_ui_sell.has_method("setup_offer"):
				var can_actually_sell = items_owned > 0
				offer_item_ui_sell.setup_offer(dynamic_sell_offer, player_inventory, false, can_actually_sell, int(current_shop_mode))
				if offer_item_ui_sell.has_signal("purchase_requested") and not offer_item_ui_sell.purchase_requested.is_connected(_on_any_offer_item_pressed):
					offer_item_ui_sell.purchase_requested.connect(_on_any_offer_item_pressed)
				_connect_tooltip_signals(offer_item_ui_sell, dynamic_sell_offer)

	elif current_shop_mode == ShopMode.BUY:
		var player_current_coins = 0
		if game_manager.has_method("get_player_coins"):
			player_current_coins = game_manager.get_player_coins()

		# 1. Oferta zakupu drabinki
		if is_instance_valid(buy_ladder_offer_ref):
			var offer_item_ui_ladder = offer_item_scene_ref.instantiate()
			offers_container.add_child(offer_item_ui_ladder)
			_ui_to_offer_map[offer_item_ui_ladder] = buy_ladder_offer_ref
			var can_afford_ladder = player_current_coins >= buy_ladder_offer_ref.cost_amount
			offer_item_ui_ladder.setup_offer(buy_ladder_offer_ref, player_inventory, false, can_afford_ladder, int(current_shop_mode))
			if offer_item_ui_ladder.has_signal("purchase_requested") and not offer_item_ui_ladder.purchase_requested.is_connected(_on_any_offer_item_pressed):
				offer_item_ui_ladder.purchase_requested.connect(_on_any_offer_item_pressed)
			_connect_tooltip_signals(offer_item_ui_ladder, buy_ladder_offer_ref)

		# 2. Oferta zakupu mikstury zdrowia
		if is_instance_valid(buy_health_potion_offer_ref):
			var offer_item_ui_potion = offer_item_scene_ref.instantiate()
			offers_container.add_child(offer_item_ui_potion)
			_ui_to_offer_map[offer_item_ui_potion] = buy_health_potion_offer_ref
			var can_afford_potion = player_current_coins >= buy_health_potion_offer_ref.cost_amount
			# Dla mikstury, `already_purchased_this_offer` jest zawsze false, bo można kupować wielokrotnie
			offer_item_ui_potion.setup_offer(buy_health_potion_offer_ref, player_inventory, false, can_afford_potion, int(current_shop_mode))
			if offer_item_ui_potion.has_signal("purchase_requested") and not offer_item_ui_potion.purchase_requested.is_connected(_on_any_offer_item_pressed):
				offer_item_ui_potion.purchase_requested.connect(_on_any_offer_item_pressed)
			_connect_tooltip_signals(offer_item_ui_potion, buy_health_potion_offer_ref)

		# 3. Oferty ulepszeń kilofa
		var current_pickaxe_lvl = 0
		if game_manager.has_method("get_upgrade_level"):
			current_pickaxe_lvl = game_manager.get_upgrade_level("PICKAXE_LEVEL_PROGRESS")
		var next_pickaxe_offer_to_display: ShopOffer = null
		if current_pickaxe_lvl < pickaxe_upgrade_offers_list.size():
			next_pickaxe_offer_to_display = pickaxe_upgrade_offers_list[current_pickaxe_lvl]
		
		if is_instance_valid(next_pickaxe_offer_to_display):
			var offer_item_ui_pickaxe = offer_item_scene_ref.instantiate()
			offers_container.add_child(offer_item_ui_pickaxe)
			_ui_to_offer_map[offer_item_ui_pickaxe] = next_pickaxe_offer_to_display
			var can_afford_pickaxe_upgrade = player_current_coins >= next_pickaxe_offer_to_display.cost_amount
			offer_item_ui_pickaxe.setup_offer(next_pickaxe_offer_to_display, player_inventory, false, can_afford_pickaxe_upgrade, int(current_shop_mode))
			if offer_item_ui_pickaxe.has_signal("purchase_requested") and not offer_item_ui_pickaxe.purchase_requested.is_connected(_on_any_offer_item_pressed):
				offer_item_ui_pickaxe.purchase_requested.connect(_on_any_offer_item_pressed)
			_connect_tooltip_signals(offer_item_ui_pickaxe, next_pickaxe_offer_to_display)
		
		# Komunikat, jeśli nie ma ŻADNYCH ofert w trybie BUY
		if offers_container.get_child_count() == 0 :
			var no_offers_label = Label.new()
			no_offers_label.text = "No items or upgrades available for purchase."
			no_offers_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			no_offers_label.custom_minimum_size.y = 50
			offers_container.add_child(no_offers_label)

	if is_instance_valid(offers_scroll): offers_scroll.scroll_vertical = 0

func _on_any_offer_item_pressed(offer_to_purchase: ShopOffer) -> void:
	if not is_instance_valid(offer_to_purchase) or not player_inventory or not game_manager: return
	print("ShopUI: Purchase attempt for: '%s'" % offer_to_purchase.offer_name)

	var sell_price_per_item = 0
	var item_type_to_sell: InventoryItemType = null

	if offer_to_purchase.unique_id == "SELL_ALL_AMMOLITE_DYNAMIC":
		item_type_to_sell = ammolite_item_type_ref
		sell_price_per_item = 30
	elif offer_to_purchase.unique_id == "SELL_ALL_JASPER_DYNAMIC":
		item_type_to_sell = jasper_item_type_ref
		sell_price_per_item = 50
	elif offer_to_purchase.unique_id == "SELL_ALL_MALACHITE_DYNAMIC":
		item_type_to_sell = malachite_item_type_ref
		sell_price_per_item = 100
	elif offer_to_purchase.unique_id == "SELL_ALL_CRYSTAL_DYNAMIC":
		item_type_to_sell = crystal_item_type_ref
		sell_price_per_item = 200

	if current_shop_mode == ShopMode.SELL:
		if is_instance_valid(item_type_to_sell) and sell_price_per_item > 0:
			var amount_to_sell = player_inventory.get_amount_of_item_type(item_type_to_sell)
			if amount_to_sell > 0:
				if game_manager.has_method("remove_items_by_type") and \
				   game_manager.remove_items_by_type(item_type_to_sell, amount_to_sell):
					if game_manager.has_method("add_player_coins"):
						var coins_earned = amount_to_sell * sell_price_per_item
						game_manager.add_player_coins(coins_earned)
						print("ShopUI: Sold %d %s for %d coins." % [amount_to_sell, item_type_to_sell.name, coins_earned])
						populate_offers()
					else: printerr("ShopUI (SELL) ERROR: game_manager missing add_player_coins method.")
				else: printerr("ShopUI (SELL) ERROR: Failed to remove items from player inventory or game_manager missing remove_items_by_type.")
			else: print("ShopUI (SELL): No %s to sell." % item_type_to_sell.name)

	elif current_shop_mode == ShopMode.BUY:
		var player_current_coins = 0
		if game_manager.has_method("get_player_coins"):
			player_current_coins = game_manager.get_player_coins()
		
		if player_current_coins < offer_to_purchase.cost_amount:
			print("ShopUI: Not enough coins for '%s'." % offer_to_purchase.offer_name)
			return

		var purchase_successful = false
		if game_manager.has_method("remove_player_coins"):
			if game_manager.remove_player_coins(offer_to_purchase.cost_amount):
				purchase_successful = true
			else:
				printerr("ShopUI (BUY) ERROR: Failed to remove coins for offer '%s'." % offer_to_purchase.offer_name)
		else:
			printerr("ShopUI (BUY) ERROR: game_manager missing remove_player_coins method.")
			return # Nie można kontynuować bez odejmowania monet

		if purchase_successful:
			if offer_to_purchase.reward_string_data == "PICKAXE_LEVEL_PROGRESS":
				if game_manager.has_method("grant_leveled_upgrade"):
					game_manager.grant_leveled_upgrade(
						offer_to_purchase.reward_string_data,
						offer_to_purchase.level_number,
						offer_to_purchase.reward_float_data
					)
				else: printerr("ShopUI (BUY PICKAXE): game_manager missing grant_leveled_upgrade method.")
			
			elif offer_to_purchase.reward_string_data == "LADDER_ITEM_PURCHASE":
				if is_instance_valid(ladder_item_type_for_purchase):
					var new_ladder_item = InventoryItem.new()
					new_ladder_item.item_type = ladder_item_type_for_purchase
					if not player_inventory.put(new_ladder_item):
						printerr("ShopUI (BUY LADDER) ERROR: Could not add ladder to inventory. Refunding coins.")
						game_manager.add_player_coins(offer_to_purchase.cost_amount)
				else: printerr("ShopUI (BUY LADDER): ladder_item_type_for_purchase is invalid.")

			elif offer_to_purchase.reward_string_data == "HEALTH_POTION_PURCHASE":
				# Potrzebujemy dostępu do obiektu gracza, aby wywołać add_health
				# Zakładamy, że game_manager to np. scena 'Game', która ma referencję do gracza
				var player_node = null
				if game_manager.has_node("WorldContainer/Player"): # Dostosuj ścieżkę, jeśli jest inna
					player_node = game_manager.get_node("WorldContainer/Player")
				
				if is_instance_valid(player_node) and player_node.has_method("add_health"):
					player_node.add_health(50.0) # Przywróć 50 HP
					print("ShopUI: Used Health Potion, restored 50 HP.")
				else:
					printerr("ShopUI (BUY POTION) ERROR: Player node not found or missing add_health method. Refunding coins.")
					game_manager.add_player_coins(offer_to_purchase.cost_amount)
			
			else:
				printerr("ShopUI (BUY): Unknown offer reward_string_data: '%s'" % offer_to_purchase.reward_string_data)
				# Jeśli był to nieznany typ oferty, a monety zostały odjęte, powinniśmy je zwrócić
				game_manager.add_player_coins(offer_to_purchase.cost_amount)
				print("ShopUI (BUY): Refunded coins due to unknown offer type after payment.")

			populate_offers() # Odśwież UI sklepu po każdej udanej lub częściowo udanej transakcji

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
		hide(); get_tree().paused = false

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
		elif event.is_action_pressed("interact"):
			should_pass_to_game = true
			get_viewport().set_input_as_handled()
		if should_pass_to_game:
			if is_instance_valid(game_manager) and game_manager.has_method("handle_shop_shortcut"):
				game_manager.handle_shop_shortcut(event)
			else:
				printerr("ShopUI _input ERROR: Cannot forward event, game_manager invalid or missing handle_shop_shortcut method.")
			return
