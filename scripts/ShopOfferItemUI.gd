# res://scripts/ui/ShopOfferItemUI.gd
extends Control

signal purchase_requested(offer: ShopOffer)
signal show_tooltip_requested(text_title: String, text_description: String, item_global_rect: Rect2)
signal hide_tooltip_requested()

@onready var item_icon_rect: TextureRect = $BackgroundButton/CenterContainer/IconAndCountVBox/ItemIcon # Upewnij się, że ścieżka jest poprawna
@onready var count_label: Label = $BackgroundButton/CenterContainer/IconAndCountVBox/CountLabel       # Upewnij się, że ścieżka jest poprawna
@onready var background_button: Button = $BackgroundButton

var current_offer: ShopOffer = null
var player_inventory_ref: Inventory = null

func _ready() -> void:
	if is_instance_valid(background_button):
		background_button.pressed.connect(_on_item_pressed)
	# Jeśli BackgroundButton jest na wierzchu i ma Filter=Stop:
	if not background_button.mouse_entered.is_connected(_on_mouse_entered_item_area):
		background_button.mouse_entered.connect(_on_mouse_entered_item_area)
	if not background_button.mouse_exited.is_connected(_on_mouse_exited_item_area):
		background_button.mouse_exited.connect(_on_mouse_exited_item_area)

# --- DODAJ TĘ FUNKCJĘ ---
func _on_item_pressed() -> void:
	if current_offer and not background_button.disabled: # Sprawdź, czy można kupić
		print("DEBUG ShopOfferItemUI: _on_item_pressed, emitting purchase_requested for: ", current_offer.offer_name)
		purchase_requested.emit(current_offer)
# --- KONIEC DODANEJ FUNKCJI ---

func setup_offer(offer: ShopOffer, p_inventory: Inventory, already_purchased: bool) -> void:
	print("DEBUG ShopOfferItemUI: setup_offer called with offer: ", offer.offer_name if offer else "NULL OFFER")
	current_offer = offer
	player_inventory_ref = p_inventory

	# Upewnij się, że item_icon_rect i count_label nie są null przed użyciem
	if is_instance_valid(item_icon_rect):
		if is_instance_valid(offer.cost_item) and is_instance_valid(offer.cost_item.texture):
			item_icon_rect.texture = offer.cost_item.texture
		else:
			item_icon_rect.texture = null
	else:
		printerr("ShopOfferItemUI: item_icon_rect is null in setup_offer!")

	if is_instance_valid(count_label):
		count_label.text = "x%d" % offer.cost_amount
	else:
		printerr("ShopOfferItemUI: count_label is null in setup_offer!")
		
	# Obsługa stanu "kupione" lub "stać/nie stać"
	if already_purchased:
		if is_instance_valid(background_button): background_button.disabled = true
		self.modulate = Color(0.5, 0.5, 0.5, 0.8)
		if is_instance_valid(count_label): count_label.text = "Owned"
	else:
		var can_afford = false
		if p_inventory and is_instance_valid(offer.cost_item):
			can_afford = p_inventory.get_amount_of_item_type(offer.cost_item) >= offer.cost_amount
		
		if is_instance_valid(background_button): background_button.disabled = not can_afford
		
		if can_afford:
			self.modulate = Color.WHITE
		else:
			self.modulate = Color(0.8, 0.7, 0.7, 1.0)

func _on_mouse_entered_item_area() -> void:
	print("DEBUG ShopOfferItemUI: _on_mouse_entered_item_area TRIGGERED for: ", current_offer.offer_name if current_offer else "NO OFFER")
	if current_offer != null:
		show_tooltip_requested.emit(current_offer.offer_name, current_offer.description, get_global_rect())
	
	if is_instance_valid(background_button) and not background_button.disabled:
		self.modulate = Color(0.85, 0.95, 1.0, 1.0)
		print("DEBUG ShopOfferItemUI: Modulated to HOVER for: ", current_offer.offer_name if current_offer else "NO OFFER")

func _on_mouse_exited_item_area() -> void:
	print("DEBUG ShopOfferItemUI: _on_mouse_exited_item_area TRIGGERED for: ", current_offer.offer_name if current_offer else "NO OFFER")
	hide_tooltip_requested.emit()
	
	if current_offer and is_instance_valid(background_button):
		var already_purchased_flag = background_button.disabled and is_instance_valid(count_label) and count_label.text == "Owned"
		if already_purchased_flag:
			self.modulate = Color(0.5, 0.5, 0.5, 0.8)
		elif background_button.disabled:
			self.modulate = Color(0.8, 0.7, 0.7, 1.0)
		else:
			self.modulate = Color.WHITE
		print("DEBUG ShopOfferItemUI: Modulated to NORMAL/STATE for: ", current_offer.offer_name if current_offer else "NO OFFER")
