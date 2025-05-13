# res://scripts/ui/ShopUI.gd
extends Control

@onready var offers_container: Container = $Background/MarginContainer/VBoxContainer/OffersScroll/OffersContainer
@onready var close_button: Button = $Background/MarginContainer/CloseButton # Poprawiłem ścieżkę, jeśli VBox jest rodzicem
@onready var offers_scroll: ScrollContainer = $Background/MarginContainer/VBoxContainer/OffersScroll

var player_inventory: Inventory = null
var game_manager: Node = null

var available_offers: Array[ShopOffer] = [
	preload("res://assets/shop_offers/unlock_digging1.tres")
]

var offer_item_scene: PackedScene = preload("res://assets/scenes/ShopOfferItemUI.tscn") # Popraw ścieżkę, jeśli trzeba

func _ready() -> void:
	if is_instance_valid(close_button):
		print("DEBUG ShopUI: Attempting to connect CloseButton.pressed to self.close_ui.")
		print("DEBUG ShopUI: CloseButton path: ", close_button.get_path())
		print("DEBUG ShopUI: CloseButton instance: ", close_button)

		# Sprawdzanie, czy sygnał jest już połączony
		var is_already_connected = false
		for connection in close_button.pressed.get_connections():
			if connection.callable.object == self and connection.callable.method == &"close_ui":
				is_already_connected = true
				break
		
		if not is_already_connected:
			var err_connect_close = close_button.pressed.connect(close_ui)
			if err_connect_close == OK:
				print("DEBUG ShopUI: Connection for CloseButton.pressed to self.close_ui successful.")
			else:
				printerr("ERROR ShopUI: Failed to connect CloseButton.pressed to self.close_ui. Error: ", err_connect_close)
		else:
			print("DEBUG ShopUI: CloseButton.pressed was already connected to self.close_ui.")
	else:
		# Ta ścieżka jest z twojego oryginalnego kodu, upewnij się, że jest poprawna
		printerr("ShopUI: CloseButton not found at path $Background/MarginContainer/CloseButton. Check @onready var path!")
		# Jeśli używasz ścieżki z VBoxContainer:
		# printerr("ShopUI: CloseButton not found at path $Background/MarginContainer/VBoxContainer/CloseButton. Check @onready var path!")
	hide()

func setup_shop(p_inventory: Inventory, p_game_manager: Node) -> void:
	print("DEBUG ShopUI: setup_shop called.")
	player_inventory = p_inventory
	game_manager = p_game_manager
	print("DEBUG ShopUI: game_manager in setup_shop is: ", game_manager, " Is it valid? ", is_instance_valid(game_manager))
	populate_offers()

func populate_offers() -> void:
	print("DEBUG ShopUI: populate_offers called.")
	if not is_instance_valid(offers_container):
		printerr("ShopUI: OffersContainer not found or invalid! Path used: ", offers_container.get_path() if offers_container else "null")
		return

	for child in offers_container.get_children():
		print("DEBUG ShopUI: Removing old offer child: ", child.name)
		child.queue_free()

	if not player_inventory or not game_manager:
		printerr("ShopUI Error: Inventory or GameManager not set up for populate_offers.")
		return

	if available_offers.is_empty():
		print("ShopUI: No available offers to populate.")
		var no_offers_label = Label.new()
		no_offers_label.text = "Brak dostępnych ofert."
		no_offers_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		offers_container.add_child(no_offers_label)
		return

	print("DEBUG ShopUI: Number of available_offers: ", available_offers.size())
	for i in range(available_offers.size()):
		var offer_data = available_offers[i]
		print("DEBUG ShopUI: Processing offer [", i, "]: ", offer_data.offer_name if is_instance_valid(offer_data) else "INVALID OFFER DATA")

		if not is_instance_valid(offer_data):
			printerr("ShopUI: Offer data at index [", i, "] is null or invalid!")
			continue

		var already_purchased: bool = false
		if is_instance_valid(game_manager) and game_manager.has_method("has_upgrade"):
			already_purchased = game_manager.has_upgrade(offer_data.unique_id)
		else:
			printerr("ShopUI: game_manager invalid or missing has_upgrade method for offer: ", offer_data.offer_name)

		if not is_instance_valid(offer_item_scene):
			printerr("ShopUI: offer_item_scene is not loaded or invalid!")
			continue

		var offer_item_instance = offer_item_scene.instantiate()
		if not is_instance_valid(offer_item_instance):
			printerr("ShopUI: Failed to instantiate offer_item_scene for offer: ", offer_data.offer_name)
			continue
		
		print("DEBUG ShopUI: Instantiated ShopOfferItemUI: ", offer_item_instance.name, " for offer: ", offer_data.offer_name)
		offers_container.add_child(offer_item_instance)
		print("DEBUG ShopUI: Added instance to offers_container. Child count: ", offers_container.get_child_count())

		if offer_item_instance.has_method("setup_offer"):
			offer_item_instance.setup_offer(offer_data, player_inventory, already_purchased)
			
			if not offer_item_instance.purchase_requested.is_connected(_on_purchase_requested):
				offer_item_instance.purchase_requested.connect(_on_purchase_requested.bind(offer_data))
			
			# Podłączanie sygnałów tooltipa
			if offer_item_instance.has_signal("show_tooltip_requested"):
				if not offer_item_instance.show_tooltip_requested.is_connected(_on_item_show_tooltip_requested):
					var err_show = offer_item_instance.show_tooltip_requested.connect(_on_item_show_tooltip_requested)
					if err_show == OK:
						print("DEBUG ShopUI: Connected show_tooltip_requested for ", offer_data.offer_name)
					else:
						printerr("ERROR ShopUI: Failed to connect show_tooltip_requested for ", offer_data.offer_name, " Error: ", err_show)
			else:
				printerr("ERROR ShopUI: offer_item_instance for '", offer_data.offer_name, "' does NOT have signal 'show_tooltip_requested'")

			if offer_item_instance.has_signal("hide_tooltip_requested"):
				if not offer_item_instance.hide_tooltip_requested.is_connected(_on_item_hide_tooltip_requested):
					var err_hide = offer_item_instance.hide_tooltip_requested.connect(_on_item_hide_tooltip_requested)
					if err_hide == OK:
						print("DEBUG ShopUI: Connected hide_tooltip_requested for ", offer_data.offer_name)
					else:
						printerr("ERROR ShopUI: Failed to connect hide_tooltip_requested for ", offer_data.offer_name, " Error: ", err_hide)
			else:
				printerr("ERROR ShopUI: offer_item_instance for '", offer_data.offer_name, "' does NOT have signal 'hide_tooltip_requested'")
		else:
			printerr("ShopUI: Instantiated ShopOfferItemUI (",offer_item_instance.name,") does not have setup_offer method!")
	
	if is_instance_valid(offers_scroll):
		offers_scroll.scroll_vertical = 0
		print("DEBUG ShopUI: Offers populated. Scroll reset. offers_container visible: ", offers_container.visible, " offers_scroll visible: ", offers_scroll.visible)

func _on_purchase_requested(offer_to_purchase: ShopOffer) -> void:
	print("DEBUG ShopUI: _on_purchase_requested received for offer: ", offer_to_purchase.offer_name if offer_to_purchase else "NULL OFFER")
	if not player_inventory or not game_manager:
		printerr("ShopUI: Cannot purchase, Inventory or GameManager not set.")
		return
	if not is_instance_valid(offer_to_purchase):
		printerr("ShopUI: Cannot purchase, offer_to_purchase is invalid.")
		return

	if not game_manager.has_method("has_upgrade") or \
	   not game_manager.has_method("remove_items_by_type") or \
	   not game_manager.has_method("grant_upgrade"):
		printerr("ShopUI: game_manager is missing one or more required methods for purchase!")
		return

	if game_manager.has_upgrade(offer_to_purchase.unique_id):
		print("ShopUI: Already purchased: ", offer_to_purchase.offer_name)
		return

	if not is_instance_valid(offer_to_purchase.cost_item) and offer_to_purchase.cost_amount > 0 : # Sprawdź, czy przedmiot kosztu jest wymagany
		printerr("ShopUI: Cost item for offer '%s' is invalid but cost_amount > 0!" % offer_to_purchase.offer_name)
		return

	if is_instance_valid(offer_to_purchase.cost_item): # Tylko jeśli jest przedmiot kosztu
		var current_amount = player_inventory.get_amount_of_item_type(offer_to_purchase.cost_item)
		if current_amount < offer_to_purchase.cost_amount:
			print("ShopUI: Not enough %s. Need %d, have %d" % [offer_to_purchase.cost_item.name, offer_to_purchase.cost_amount, current_amount])
			return

	print("ShopUI: Attempting purchase: ", offer_to_purchase.offer_name)
	var items_removed_successfully = true # Załóż, jeśli koszt = 0 lub brak przedmiotu
	if is_instance_valid(offer_to_purchase.cost_item) and offer_to_purchase.cost_amount > 0:
		items_removed_successfully = game_manager.remove_items_by_type(offer_to_purchase.cost_item, offer_to_purchase.cost_amount)

	if items_removed_successfully:
		print("ShopUI: Items handled successfully for offer: ", offer_to_purchase.offer_name)
		game_manager.grant_upgrade(offer_to_purchase.unique_id)
		print("ShopUI: Upgrade granted: ", offer_to_purchase.unique_id)
		populate_offers()
	else:
		printerr("ShopUI: Failed to remove items from inventory during purchase for offer: ", offer_to_purchase.offer_name)

func close_ui() -> void:
	print("DEBUG ShopUI: close_ui() called by button press.")
	if is_instance_valid(game_manager):
		if game_manager.has_method("close_shop_ui"):
			game_manager.close_shop_ui()
		else:
			printerr("ShopUI: game_manager does not have close_shop_ui method!")
			hide()
			get_tree().paused = false
	else:
		printerr("ShopUI: game_manager is not valid when trying to close.")
		hide()
		get_tree().paused = false
		
func _on_item_show_tooltip_requested(text_title: String, text_description: String, item_global_rect: Rect2) -> void:
	print("DEBUG ShopUI: _on_item_show_tooltip_requested RECEIVED. Title: ", text_title)
	if is_instance_valid(game_manager) and game_manager.has_method("display_global_tooltip"):
		game_manager.display_global_tooltip(text_title, text_description, item_global_rect)
	else:
		printerr("ShopUI: Cannot show tooltip, game_manager invalid or missing display_global_tooltip method.")

func _on_item_hide_tooltip_requested() -> void:
	print("DEBUG ShopUI: _on_item_hide_tooltip_requested RECEIVED.")
	if is_instance_valid(game_manager) and game_manager.has_method("hide_global_tooltip"):
		game_manager.hide_global_tooltip()
	else:
		printerr("ShopUI: Cannot hide tooltip, game_manager invalid or missing hide_global_tooltip method.")

# res://scripts/ui/ShopUI.gd
# Zmodyfikuj dodaną wcześniej funkcję _input

func _input(event: InputEvent) -> void:
	# Loguj każde zdarzenie docierające do ShopUI (możesz to później usunąć)
	# print("--- ShopUI.gd _input: Event Class: ", event.get_class(), " | Event: ", event)

	if event is InputEventKey:
		if event.is_pressed() and not event.is_echo():
			# Loguj naciśnięty klawisz (możesz to później usunąć)
			# var key_string = OS.get_keycode_string(event.get_physical_keycode_with_modifiers())
			# print("--- ShopUI.gd _input: KEY PRESSED: ", key_string)

			var should_pass_to_game = false # Flaga, czy przekazać dalej

			# Sprawdź, czy naciśnięto klawisz akcji, które ma obsłużyć game.gd
			if event.is_action_pressed("ui_cancel"): # Sprawdź ESC
				print("--- ShopUI.gd _input: Detected 'ui_cancel' (ESC) press.")
				# Chcemy, aby game.gd obsłużyło ESC do zamknięcia
				should_pass_to_game = true
				# Oznaczamy jako obsłużone w ShopUI, aby inne kontrolki w ShopUI go nie dostały
				get_viewport().set_input_as_handled()

			elif event.is_action_pressed("interact"): # Sprawdź E
				print("--- ShopUI.gd _input: Detected 'interact' (E) press.")
				# Chcemy, aby game.gd obsłużyło E do zamknięcia (jeśli jest w shop area)
				should_pass_to_game = true
				# Oznaczamy jako obsłużone w ShopUI
				get_viewport().set_input_as_handled()

			# Możesz dodać inne klawisze, które ShopUI ma ignorować i przekazywać
			# elif event.is_action_pressed("jakaś_inna_akcja_dla_gry"):
			#	  should_pass_to_game = true
			#	  get_viewport().set_input_as_handled()

			# Jeśli zidentyfikowaliśmy klawisz do przekazania
			if should_pass_to_game:
				if is_instance_valid(game_manager) and game_manager.has_method("_unhandled_input"):
					print("--- ShopUI.gd _input: Forwarding event to game_manager._unhandled_input")
					# Ręcznie wywołaj _unhandled_input w game_manager, przekazując event
					# To nie jest standardowa metoda, ale symuluje dotarcie tam inputu
					# UWAGA: Bezpośrednie wywoływanie _unhandled_input może być ryzykowne,
					# lepszą opcją byłoby wywołanie dedykowanej funkcji w game_manager,
					# np. game_manager.handle_shop_close_shortcut(event)
					# Ale na razie spróbujmy tak dla testu:
					# game_manager._unhandled_input(event) # <--- Bezpośrednie wywołanie (mniej zalecane)

					# --- Lepsze podejście: Wywołaj dedykowaną funkcję w game_manager ---
					if game_manager.has_method("handle_shop_shortcut"):
						game_manager.handle_shop_shortcut(event)
					else:
						printerr("ShopUI ERROR: game_manager does not have handle_shop_shortcut method!")
					# --------------------------------------------------------------------
				else:
					printerr("ShopUI ERROR: Cannot forward event, game_manager invalid or missing _unhandled_input method.")
				return # Zakończ przetwarzanie eventu w ShopUI

	# Jeśli zdarzenie nie zostało obsłużone powyżej (np. to był inny klawisz, ruch myszy),
	# pozwól mu być przetwarzanym normalnie przez Godota (np. dla kliknięcia przycisku Close).
