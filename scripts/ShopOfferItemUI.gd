# res://scripts/ui/ShopOfferItemUI.gd
extends Control

# ZMIANA: Sygnał nie będzie już przekazywał 'offer', ShopUI samo zidentyfikuje ofertę
signal purchase_button_pressed 
signal show_tooltip_requested(text_title: String, text_description: String, item_global_rect: Rect2)
signal hide_tooltip_requested()

@onready var item_icon_rect: TextureRect = $BackgroundButton/CenterContainer/IconAndCountVBox/ItemIcon
@onready var count_label: Label = $BackgroundButton/CenterContainer/IconAndCountVBox/CountLabel
@onready var background_button: Button = $BackgroundButton

const COLOR_NORMAL_CAN_AFFORD: Color = Color("4a4a4a")
const COLOR_NORMAL_CANT_AFFORD: Color = Color(0.8, 0.2, 0.2, 1.0)
const COLOR_NORMAL_OWNED: Color = Color(0.3, 0.3, 0.3, 1.0)

const COLOR_HOVER_CAN_AFFORD: Color = Color("6a6a6a")
const COLOR_HOVER_CANT_AFFORD: Color = Color(0.9, 0.3, 0.3, 1.0)

# current_offer_ref jest nadal potrzebne do wyświetlania danych w UI (ikona, tekst, tooltip)
var current_offer_ref: ShopOffer = null 
var player_inventory_ref: Inventory = null # Nie używane bezpośrednio tutaj, ale przekazywane
var current_shop_mode_as_int_ref: int 

var _is_owned_ref: bool = false
var _can_afford_ref: bool = false
var _is_mouse_over: bool = false

var pickaxe_icon_texture_ref: Texture2D = preload("res://assets/sprites/icons/pickaxe_icon.tres")


func _ready() -> void:
	if is_instance_valid(background_button):
		if not background_button.pressed.is_connected(_on_item_pressed):
			background_button.pressed.connect(_on_item_pressed)
		if not background_button.mouse_entered.is_connected(_on_mouse_entered_item_area):
			background_button.mouse_entered.connect(_on_mouse_entered_item_area)
		if not background_button.mouse_exited.is_connected(_on_mouse_exited_item_area):
			background_button.mouse_exited.connect(_on_mouse_exited_item_area)
	else:
		printerr("ShopOfferItemUI: BackgroundButton is not valid in _ready!")
	_update_visual_state()


func _on_item_pressed() -> void:
	print("ShopOfferItemUI: _on_item_pressed CALLED for offer: ", current_offer_ref.offer_name if current_offer_ref else "NULL OFFER")
	if current_offer_ref and not background_button.disabled:
		# ZMIANA: Emitujemy prosty sygnał bez argumentu 'offer'
		print("ShopOfferItemUI: Emitting 'purchase_button_pressed'.")
		purchase_button_pressed.emit() 
	elif not current_offer_ref:
		print("ShopOfferItemUI: _on_item_pressed - current_offer_ref is NULL!")
	elif background_button.disabled:
		print("ShopOfferItemUI: _on_item_pressed - background_button is DISABLED.")


func setup_offer(offer: ShopOffer, p_inventory: Inventory, already_purchased: bool, can_afford: bool, shop_mode_as_int: int) -> void:
	current_offer_ref = offer
	player_inventory_ref = p_inventory # Nadal przekazujemy, może być potrzebne w przyszłości
	_is_owned_ref = already_purchased
	_can_afford_ref = can_afford
	current_shop_mode_as_int_ref = shop_mode_as_int

	if not is_instance_valid(current_offer_ref):
		printerr("ShopOfferItemUI: current_offer_ref is null in setup_offer!")
		if is_instance_valid(item_icon_rect): item_icon_rect.texture = null
		if is_instance_valid(count_label): count_label.text = "ERR"
		if is_instance_valid(background_button): background_button.disabled = true
		_update_visual_state()
		return

	# 0 odpowiada ShopUI.ShopMode.SELL, 1 odpowiada ShopUI.ShopMode.BUY
	if current_shop_mode_as_int_ref == 0: # Tryb SELL
		if current_offer_ref.unique_id == "SELL_ALL_AMMOLITE_UNIQUE_ID":
			if is_instance_valid(current_offer_ref.cost_item) and is_instance_valid(current_offer_ref.cost_item.texture):
				item_icon_rect.texture = current_offer_ref.cost_item.texture
			else:
				item_icon_rect.texture = null
			if is_instance_valid(count_label): count_label.text = "x%d" % current_offer_ref.cost_amount
		else:
			printerr("ShopOfferItemUI (SELL mode): Unknown offer type in setup: ", current_offer_ref.unique_id)
			
	elif current_shop_mode_as_int_ref == 1: # Tryb BUY
		if current_offer_ref.unique_id == "unique_offer_id": # Upewnij się, że to jest poprawne ID dla ulepszenia kilofa
			item_icon_rect.texture = pickaxe_icon_texture_ref
			if is_instance_valid(count_label): count_label.text = "Lvl: %d" % current_offer_ref.cost_amount 
		else: 
			if is_instance_valid(current_offer_ref.cost_item) and is_instance_valid(current_offer_ref.cost_item.texture):
				item_icon_rect.texture = current_offer_ref.cost_item.texture
			else:
				item_icon_rect.texture = null
			if is_instance_valid(count_label): count_label.text = "x%d" % current_offer_ref.cost_amount
	else:
		printerr("ShopOfferItemUI: Unknown shop mode in setup: ", current_shop_mode_as_int_ref)

	_update_visual_state()


func _update_visual_state() -> void:
	if not is_instance_valid(background_button):
		return

	if _is_owned_ref and current_shop_mode_as_int_ref == 1: 
		background_button.modulate = COLOR_NORMAL_OWNED
		background_button.disabled = true
		if is_instance_valid(count_label):
			if current_offer_ref and current_offer_ref.unique_id == "unique_offer_id":
				count_label.text = "Owned (Lvl %d)" % current_offer_ref.cost_amount
			else:
				count_label.text = "Owned"
	else:
		background_button.disabled = not _can_afford_ref
		
		var normal_color = COLOR_NORMAL_CANT_AFFORD
		var hover_color = COLOR_HOVER_CANT_AFFORD

		if _can_afford_ref:
			normal_color = COLOR_NORMAL_CAN_AFFORD
			hover_color = COLOR_HOVER_CAN_AFFORD
		
		if _is_mouse_over:
			background_button.modulate = hover_color
		else:
			background_button.modulate = normal_color
		
		if current_offer_ref: # Tylko jeśli oferta istnieje, aktualizuj tekst licznika
			if not (_is_owned_ref and current_shop_mode_as_int_ref == 1): # Nie nadpisuj "Owned"
				if current_shop_mode_as_int_ref == 0 and current_offer_ref.unique_id == "SELL_ALL_AMMOLITE_UNIQUE_ID":
					if is_instance_valid(count_label): count_label.text = "x%d" % current_offer_ref.cost_amount
				elif current_shop_mode_as_int_ref == 1:
					if current_offer_ref.unique_id == "unique_offer_id": 
						if is_instance_valid(count_label): count_label.text = "Lvl: %d" % current_offer_ref.cost_amount
					elif is_instance_valid(count_label) and is_instance_valid(current_offer_ref.cost_item): 
						count_label.text = "x%d" % current_offer_ref.cost_amount
					elif is_instance_valid(count_label): 
						count_label.text = "" 


func _on_mouse_entered_item_area() -> void:
	_is_mouse_over = true
	if current_offer_ref != null:
		var tooltip_title = current_offer_ref.offer_name
		var tooltip_desc = current_offer_ref.description
		show_tooltip_requested.emit(tooltip_title, tooltip_desc, get_global_rect())
	_update_visual_state()


func _on_mouse_exited_item_area() -> void:
	_is_mouse_over = false
	hide_tooltip_requested.emit()
	_update_visual_state()
