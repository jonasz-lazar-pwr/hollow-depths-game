# res://scripts/ui/ShopUI.gd
extends Control

# Zaktualizowane ścieżki na podstawie zrzutu ekranu:
@onready var offers_container: Container = $Background/MarginContainer/VBoxContainer/OffersScroll/OffersContainer
# Jeśli OffersContainer to np. VBoxContainer, możesz być bardziej precyzyjny:
# @onready var offers_container: VBoxContainer = $Background/MarginContainer/VBoxContainer/OffersScroll/OffersContainer

@onready var close_button: Button = $Background/MarginContainer/CloseButton
# Sprawdź, czy OffersScroll nie powinien być również w @onready, jeśli chcesz nim manipulować (np. przewijać do góry)
@onready var offers_scroll: ScrollContainer = $Background/MarginContainer/VBoxContainer/OffersScroll


var player_inventory: Inventory = null
var game_manager: Node = null # Referencja do game.gd

var available_offers: Array[ShopOffer] = [
	preload("res://assets/shop_offers/unlock_digging1.tres")
	# Możesz dodać więcej ofert tutaj
]

# Upewnij się, że ścieżka do ShopOfferItemUI.tscn jest poprawna.
# Z poprzedniej wiadomości wynikało, że masz ją w res://scenes/ui/ShopOfferItemUI.tscn
# Jeśli jest w res://assets/scenes/, zmień poniżej:
var offer_item_scene: PackedScene = preload("res://assets/scenes/ShopOfferItemUI.tscn") # LUB "res://assets/scenes/ShopOfferItemUI.tscn"

func _ready() -> void:
	if is_instance_valid(close_button):
		print("DEBUG ShopUI: Connecting CloseButton.pressed to close_ui. Button: ", close_button.name) # Debug
		if not close_button.pressed.is_connected(close_ui):
			close_button.pressed.connect(close_ui)
			print("DEBUG ShopUI: Connection successful.") # Debug
		else:
			print("DEBUG ShopUI: CloseButton already connected.") # Debug
	else:
		printerr("ShopUI: CloseButton not found at path used in @onready var!")
	hide()

func setup_shop(p_inventory: Inventory, p_game_manager: Node) -> void:
	print("DEBUG ShopUI: setup_shop called.")
	player_inventory = p_inventory
	game_manager = p_game_manager
	populate_offers()

func populate_offers() -> void:
	print("DEBUG ShopUI: populate_offers called.")
	if not is_instance_valid(offers_container):
		printerr("ShopUI: OffersContainer not found or invalid! Path used: $Background/MarginContainer/VBoxContainer/OffersScroll/OffersContainer")
		return

	# Wyczyść stare oferty
	for child in offers_container.get_children():
		child.queue_free()

	if not player_inventory or not game_manager:
		printerr("ShopUI Error: Inventory or GameManager not set up for populate_offers.")
		return

	if available_offers.is_empty():
		print("ShopUI: No available offers to populate.")
		# Możesz tu dodać np. Labelkę "Brak ofert" do offers_container
		var no_offers_label = Label.new()
		no_offers_label.text = "Brak dostępnych ofert."
		no_offers_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		offers_container.add_child(no_offers_label)
		return

	for offer_data in available_offers:
		if not is_instance_valid(offer_data):
			printerr("ShopUI: An offer in available_offers is null or invalid!")
			continue

		var already_purchased: bool = false
		if game_manager.has_method("has_upgrade"):
			already_purchased = game_manager.has_upgrade(offer_data.unique_id)
		else:
			printerr("ShopUI: game_manager does not have has_upgrade method!")


		var offer_item_instance = offer_item_scene.instantiate()
		offers_container.add_child(offer_item_instance) # Dodajemy instancję do offers_container

		if offer_item_instance.has_method("setup_offer"):
			offer_item_instance.setup_offer(offer_data, player_inventory, already_purchased)
			if not offer_item_instance.purchase_requested.is_connected(_on_purchase_requested):
				# Używamy bind, aby przekazać offer_data, gdy sygnał zostanie wyemitowany
				offer_item_instance.purchase_requested.connect(_on_purchase_requested.bind(offer_data))
		else:
			printerr("ShopUI: Instantiated ShopOfferItemUI does not have setup_offer method!")
	
	# Po dodaniu wszystkich ofert, można zresetować scroll do góry (opcjonalnie)
	if is_instance_valid(offers_scroll):
		offers_scroll.scroll_vertical = 0


func _on_purchase_requested(offer_to_purchase: ShopOffer) -> void:
	print("DEBUG ShopUI: _on_purchase_requested called for offer: ", offer_to_purchase.offer_name)
	if not player_inventory or not game_manager:
		printerr("Cannot purchase: Inventory or GameManager not set.")
		return

	if not game_manager.has_method("has_upgrade") or \
	   not game_manager.has_method("remove_items_by_type") or \
	   not game_manager.has_method("grant_upgrade"):
		printerr("ShopUI: game_manager is missing one or more required methods for purchase!")
		return

	if game_manager.has_upgrade(offer_to_purchase.unique_id):
		print("Already purchased:", offer_to_purchase.offer_name)
		# Można dodać feedback dla gracza, np. dźwięk lub komunikat
		return

	if not is_instance_valid(offer_to_purchase.cost_item):
		printerr("ShopUI: Cost item for offer '%s' is invalid!" % offer_to_purchase.offer_name)
		# Jeśli koszt to "darmowe", to cost_item może być null, obsłuż to inaczej jeśli trzeba
		# if offer_to_purchase.cost_amount == 0: ... logika dla darmowych ...
		return

	var current_amount = player_inventory.get_amount_of_item_type(offer_to_purchase.cost_item)
	if current_amount < offer_to_purchase.cost_amount:
		print("Not enough %s. Need %d, have %d" % [offer_to_purchase.cost_item.name, offer_to_purchase.cost_amount, current_amount])
		# Można dodać feedback dla gracza
		return

	print("Attempting purchase:", offer_to_purchase.offer_name)
	var items_removed = game_manager.remove_items_by_type(offer_to_purchase.cost_item, offer_to_purchase.cost_amount)

	if items_removed:
		print("Items removed successfully for offer:", offer_to_purchase.offer_name)
		game_manager.grant_upgrade(offer_to_purchase.unique_id)
		print("Upgrade granted:", offer_to_purchase.unique_id)
		# $PurchaseSound.play() # Odtwórz dźwięk zakupu
		populate_offers() # Odśwież listę, aby zaktualizować stan przycisków
	else:
		printerr("Failed to remove items from inventory during purchase for offer:", offer_to_purchase.offer_name)


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
