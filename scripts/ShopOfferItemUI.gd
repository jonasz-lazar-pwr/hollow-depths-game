# res://scripts/ui/ShopOfferItemUI.gd
extends Control

signal purchase_requested(offer: ShopOffer)
signal show_tooltip_requested(text_title: String, text_description: String, item_global_rect: Rect2)
signal hide_tooltip_requested()

@onready var item_icon_rect: TextureRect = $CenterContainer/IconAndCountVBox/ItemIcon
@onready var count_label: Label = $CenterContainer/IconAndCountVBox/CountLabel
@onready var background_button: Button = $BackgroundButton
# Usunęliśmy @onready var dla lokalnego tooltipa

var current_offer: ShopOffer = null
var player_inventory_ref: Inventory = null

func _ready() -> void:
	if is_instance_valid(background_button):
		if not background_button.pressed.is_connected(_on_item_pressed):
			background_button.pressed.connect(_on_item_pressed)
	else:
		printerr("ShopOfferItemUI: BackgroundButton not found!")

	# Podłącz sygnały myszy do głównego węzła ShopOfferItemUI (czyli self)
	# Upewnij się, że główny węzeł ShopOfferItemUI ma Mouse Filter ustawiony na Stop lub Pass
	if not mouse_entered.is_connected(_on_mouse_entered_item_area):
		mouse_entered.connect(_on_mouse_entered_item_area)
	if not mouse_exited.is_connected(_on_mouse_exited_item_area):
		mouse_exited.connect(_on_mouse_exited_item_area)

func setup_offer(offer: ShopOffer, p_inventory: Inventory, already_purchased: bool) -> void:
	print("DEBUG ShopOfferItemUI: setup_offer called with offer: ", offer.offer_name if offer else "NULL OFFER")
	current_offer = offer
	player_inventory_ref = p_inventory

	if is_instance_valid(offer.cost_item) and is_instance_valid(offer.cost_item.texture):
		item_icon_rect.texture = offer.cost_item.texture
	else:
		item_icon_rect.texture = null # Możesz tu wstawić domyślną ikonę "brak obrazka"
	
	count_label.text = "x%d" % offer.cost_amount

	# Obsługa stanu "kupione" lub "stać/nie stać"
	if already_purchased:
		background_button.disabled = true
		modulate = Color(0.5, 0.5, 0.5, 0.8) # Przyciemnij cały item
		count_label.text = "Owned"
	else:
		var can_afford = false
		if p_inventory and is_instance_valid(offer.cost_item): # Sprawdź czy cost_item jest valid
			can_afford = p_inventory.get_amount_of_item_type(offer.cost_item) >= offer.cost_amount
		
		background_button.disabled = not can_afford
		if can_afford:
			modulate = Color.WHITE
		else:
			modulate = Color(0.8, 0.7, 0.7, 1.0) # Lekko przyciemniony, jeśli nie stać

func _on_item_pressed() -> void:
	if current_offer and not background_button.disabled:
		purchase_requested.emit(current_offer)

func _on_mouse_entered_item_area() -> void:
	if current_offer != null:
		print("DEBUG ShopOfferItemUI: Mouse entered. Emitting show_tooltip_requested for: ", current_offer.offer_name)
		show_tooltip_requested.emit(current_offer.offer_name, current_offer.description, get_global_rect())
	else:
		print("DEBUG ShopOfferItemUI: Mouse entered, but current_offer is null.")

	# Podświetlenie
	if is_instance_valid(background_button) and not background_button.disabled:
		# Zamiast modulować background_button, modulujmy self (główny Control), jeśli ma on jakiś wygląd
		# lub jeśli background_button to tylko przezroczysty detector.
		# Zakładając, że 'self' ma jakiś panel jako tło lub chcesz podświetlić cały obszar:
		self.modulate = Color(0.85, 0.95, 1.0, 1.0) # Lekko jaśniejsze podświetlenie
		# Jeśli chcesz podświetlać tylko `background_button` (np. jeśli ma on swój styl):
		# background_button.modulate = Color(0.85, 0.95, 1.0, 1.0)


func _on_mouse_exited_item_area() -> void:
	print("DEBUG ShopOfferItemUI: Mouse exited. Emitting hide_tooltip_requested.")
	hide_tooltip_requested.emit()
	
	# Reset modulacji (na podstawie aktualnego stanu)
	if current_offer and is_instance_valid(background_button):
		var already_purchased_flag = background_button.disabled and count_label.text == "Owned"
		if already_purchased_flag:
			self.modulate = Color(0.5, 0.5, 0.5, 0.8)
		elif background_button.disabled: # Nie stać
			self.modulate = Color(0.8, 0.7, 0.7, 1.0)
		else: # Dostępne do kupna
			self.modulate = Color.WHITE
