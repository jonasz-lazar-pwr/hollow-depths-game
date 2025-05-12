# res://scripts/ui/ShopOfferItemUI.gd
extends Control

signal purchase_requested(offer: ShopOffer)
signal show_tooltip_requested(text_title: String, text_description: String, item_global_rect: Rect2)
signal hide_tooltip_requested()

@onready var item_icon_rect: TextureRect = $BackgroundButton/CenterContainer/IconAndCountVBox/ItemIcon
@onready var count_label: Label = $BackgroundButton/CenterContainer/IconAndCountVBox/CountLabel
@onready var background_button: Button = $BackgroundButton

# --- ZDEFINIOWANE KOLORY ---
const COLOR_NORMAL_CAN_AFFORD: Color = Color("4a4a4a")       # Ciemnoszary, gdy stać
const COLOR_NORMAL_CANT_AFFORD: Color = Color(0.8, 0.2, 0.2, 1.0) # Czerwony, gdy nie stać
const COLOR_NORMAL_OWNED: Color = Color(0.3, 0.3, 0.3, 1.0)         # Bardzo ciemnoszary, gdy kupione

const COLOR_HOVER_CAN_AFFORD: Color = Color("6a6a6a")      # Jaśniejszy szary (hover), gdy stać
const COLOR_HOVER_CANT_AFFORD: Color = Color(0.9, 0.3, 0.3, 1.0) # Jaśniejszy czerwony (hover), gdy nie stać

var current_offer: ShopOffer = null
var player_inventory_ref: Inventory = null

var _is_owned: bool = false
var _can_afford: bool = false
var _is_mouse_over: bool = false

func _ready() -> void:
	if is_instance_valid(background_button):
		background_button.pressed.connect(_on_item_pressed)
		if not background_button.mouse_entered.is_connected(_on_mouse_entered_item_area):
			background_button.mouse_entered.connect(_on_mouse_entered_item_area)
		if not background_button.mouse_exited.is_connected(_on_mouse_exited_item_area):
			background_button.mouse_exited.connect(_on_mouse_exited_item_area)
		background_button.modulate = COLOR_NORMAL_CANT_AFFORD
	else:
		printerr("ShopOfferItemUI: BackgroundButton is not valid in _ready!")

func _on_item_pressed() -> void:
	if current_offer and not background_button.disabled:
		print("DEBUG ShopOfferItemUI: _on_item_pressed, emitting purchase_requested for: ", current_offer.offer_name)
		purchase_requested.emit(current_offer)

func setup_offer(offer: ShopOffer, p_inventory: Inventory, already_purchased: bool) -> void:
	print("DEBUG ShopOfferItemUI: setup_offer called with offer: '", (offer.offer_name if offer else "NULL OFFER"), "' already_purchased: ", already_purchased)
	current_offer = offer
	player_inventory_ref = p_inventory
	_is_owned = already_purchased

	if not is_instance_valid(current_offer):
		printerr("ShopOfferItemUI: current_offer is null in setup_offer! Aborting setup.")
		if is_instance_valid(background_button): background_button.disabled = true
		if is_instance_valid(count_label): count_label.text = "Error"
		if is_instance_valid(item_icon_rect): item_icon_rect.texture = null
		_update_visual_state()
		return

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
		
	_can_afford = false
	if not _is_owned:
		if p_inventory and is_instance_valid(offer.cost_item):
			_can_afford = p_inventory.get_amount_of_item_type(offer.cost_item) >= offer.cost_amount
		elif not is_instance_valid(offer.cost_item) and offer.cost_amount == 0:
			_can_afford = true
			
	_update_visual_state()

func _update_visual_state() -> void:
	if not is_instance_valid(background_button):
		printerr("ShopOfferItemUI: Cannot update visual state, background_button is invalid.")
		return

	if _is_owned:
		background_button.modulate = COLOR_NORMAL_OWNED
		background_button.disabled = true
		if is_instance_valid(count_label): count_label.text = "Owned"
	else:
		background_button.disabled = not _can_afford
		
		if _is_mouse_over:
			if _can_afford:
				background_button.modulate = COLOR_HOVER_CAN_AFFORD
			else:
				background_button.modulate = COLOR_HOVER_CANT_AFFORD
		else: 
			if _can_afford:
				background_button.modulate = COLOR_NORMAL_CAN_AFFORD
			else:
				background_button.modulate = COLOR_NORMAL_CANT_AFFORD
		
		if is_instance_valid(count_label) and count_label.text == "Owned" and is_instance_valid(current_offer): # Sprawdzamy czy current_offer jest valid
			count_label.text = "x%d" % current_offer.cost_amount


func _on_mouse_entered_item_area() -> void:
	_is_mouse_over = true
	if current_offer != null:
		show_tooltip_requested.emit(current_offer.offer_name, current_offer.description, get_global_rect())
		# Poprawiony print
		print("DEBUG ShopOfferItemUI: Mouse ENTERED '", current_offer.offer_name, "'. Can afford: ", _can_afford, ", Is owned: ", _is_owned)
	else:
		print("DEBUG ShopOfferItemUI: Mouse ENTERED (NO OFFER).")
	_update_visual_state()


func _on_mouse_exited_item_area() -> void:
	_is_mouse_over = false
	hide_tooltip_requested.emit()
	if current_offer != null:
		# Poprawiony print
		print("DEBUG ShopOfferItemUI: Mouse EXITED '", current_offer.offer_name, "'. Can afford: ", _can_afford, ", Is owned: ", _is_owned)
	else:
		print("DEBUG ShopOfferItemUI: Mouse EXITED (NO OFFER).")
	_update_visual_state()
