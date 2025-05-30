# res://scripts/ui/ShopOfferItemUI.gd
extends Control

signal purchase_requested(offer: ShopOffer)
signal show_tooltip_requested(text_title: String, text_description: String, item_global_rect: Rect2)
signal hide_tooltip_requested()

@onready var item_icon_rect: TextureRect = $BackgroundButton/CenterContainer/IconAndCountVBox/ItemIcon
@onready var count_label: Label = $BackgroundButton/CenterContainer/IconAndCountVBox/CountLabel
@onready var background_button: Button = $BackgroundButton

const COLOR_NORMAL_CAN_AFFORD_BUY: Color = Color(0.85, 0.85, 0.85, 1.0)
const COLOR_NORMAL_CANT_AFFORD: Color = Color(0.8, 0.2, 0.2, 1.0)
const COLOR_NORMAL_OWNED: Color = Color(0.3, 0.3, 0.3, 1.0) # Rzadko używane dla BUY w nowym systemie

const COLOR_HOVER_CAN_AFFORD_BUY: Color = Color("6a6a6a")
const COLOR_HOVER_CANT_AFFORD: Color = Color(0.9, 0.3, 0.3, 1.0) # Rzadko używane dla BUY

const COLOR_SELL_AVAILABLE_NORMAL: Color = Color.WHITE
const COLOR_SELL_AVAILABLE_HOVER: Color = Color(0.95, 0.95, 0.95, 1.0)
const ALPHA_UNAVAILABLE: float = 0.5

var current_offer: ShopOffer = null
var player_inventory_ref: Inventory = null

var _is_owned: bool = false # <<< POPRAWIONA DEKLARACJA (było _is_owned_this_specific_offer w użyciu, ale nie w deklaracji)
var _can_afford: bool = false
var _is_mouse_over: bool = false
var _shop_mode_cached: int # 0 dla SELL, 1 dla BUY (ShopUI.ShopMode enum)

func _ready() -> void:
	if is_instance_valid(background_button):
		background_button.pressed.connect(_on_item_pressed)
		if not background_button.mouse_entered.is_connected(_on_mouse_entered_item_area):
			background_button.mouse_entered.connect(_on_mouse_entered_item_area)
		if not background_button.mouse_exited.is_connected(_on_mouse_exited_item_area):
			background_button.mouse_exited.connect(_on_mouse_exited_item_area)
	else: printerr("ShopOfferItemUI: BackgroundButton not valid!")


func _on_item_pressed() -> void:
	if current_offer and not background_button.disabled:
		purchase_requested.emit(current_offer)


func setup_offer(offer: ShopOffer, p_inventory: Inventory, already_purchased_this_offer: bool, can_afford_this_offer: bool, shop_mode_from_caller: int) -> void:
	current_offer = offer
	player_inventory_ref = p_inventory
	_is_owned = already_purchased_this_offer # <<< UŻYCIE POPRAWIONEJ ZMIENNEJ
	_can_afford = can_afford_this_offer
	_shop_mode_cached = shop_mode_from_caller

	if not is_instance_valid(current_offer):
		if is_instance_valid(background_button): background_button.disabled = true
		if is_instance_valid(count_label): count_label.text = "Error"
		if is_instance_valid(item_icon_rect): item_icon_rect.texture = null
		_update_visual_state(); return

	if is_instance_valid(item_icon_rect):
		var icon_tex = null
		if _shop_mode_cached == ShopUI.ShopMode.SELL: # Użyj enum z ShopUI dla czytelności
			if is_instance_valid(offer.cost_item) and is_instance_valid(offer.cost_item.texture):
				icon_tex = offer.cost_item.texture
		else: # BUY mode
			if is_instance_valid(offer.display_icon):
				icon_tex = offer.display_icon
			elif is_instance_valid(offer.cost_item) and is_instance_valid(offer.cost_item.texture):
				icon_tex = offer.cost_item.texture
		item_icon_rect.texture = icon_tex

	if is_instance_valid(count_label):
		if _shop_mode_cached == ShopUI.ShopMode.BUY:
			if offer.level_number > 0:
				count_label.text = "Lvl. %d" % offer.level_number
			else:
				count_label.text = ""
		elif _shop_mode_cached == ShopUI.ShopMode.SELL:
			count_label.text = "x%d" % offer.cost_amount
	
	_update_visual_state()

func _update_visual_state() -> void:
	if not is_instance_valid(background_button) or \
	   not is_instance_valid(item_icon_rect) or \
	   not is_instance_valid(count_label): return

	var current_normal_color: Color
	var current_hover_color: Color
	var label_text_color_override: Color = Color.WHITE
	var icon_modulate_color: Color = Color.WHITE     

	if _is_owned: # <<< UŻYCIE POPRAWIONEJ ZMIENNEJ
		current_normal_color = COLOR_NORMAL_OWNED
		current_hover_color = COLOR_NORMAL_OWNED 
		background_button.disabled = true
		# Tekst "Owned" jest teraz bardziej ogólny, bo setup_offer ustawi "Lvl. X" dla kupna
		# if is_instance_valid(count_label): count_label.text = "Owned" 
		label_text_color_override = Color(0.7, 0.7, 0.7, 1.0) 
		icon_modulate_color = Color(1.0, 1.0, 1.0, ALPHA_UNAVAILABLE)
	else:
		background_button.disabled = not _can_afford
		
		if _shop_mode_cached == ShopUI.ShopMode.SELL:
			if _can_afford:
				current_normal_color = COLOR_SELL_AVAILABLE_NORMAL
				current_hover_color = COLOR_SELL_AVAILABLE_HOVER
			else:
				current_normal_color = COLOR_NORMAL_CANT_AFFORD
				current_hover_color = COLOR_HOVER_CANT_AFFORD
				label_text_color_override = Color(1.0, 1.0, 1.0, ALPHA_UNAVAILABLE)
				icon_modulate_color = Color(1.0, 1.0, 1.0, ALPHA_UNAVAILABLE)
		else: # BUY mode
			if _can_afford: 
				current_normal_color = COLOR_NORMAL_CAN_AFFORD_BUY
				current_hover_color = COLOR_HOVER_CAN_AFFORD_BUY
			else: 
				current_normal_color = COLOR_NORMAL_CANT_AFFORD
				current_hover_color = COLOR_HOVER_CANT_AFFORD
				label_text_color_override = Color(1.0, 1.0, 1.0, ALPHA_UNAVAILABLE)
				icon_modulate_color = Color(1.0, 1.0, 1.0, ALPHA_UNAVAILABLE)
		
		if _is_mouse_over and _can_afford:
			background_button.modulate = current_hover_color
		else:
			background_button.modulate = current_normal_color
	
	if is_instance_valid(count_label):
		count_label.add_theme_color_override("font_color", label_text_color_override)
	if is_instance_valid(item_icon_rect):
		item_icon_rect.modulate = icon_modulate_color

func _on_mouse_entered_item_area() -> void:
	_is_mouse_over = true
	if current_offer != null:
		show_tooltip_requested.emit(current_offer.offer_name, current_offer.description, get_global_rect())
		# Usunięto _is_owned_this_specific_offer z logu, używamy _is_owned
		print("DEBUG ShopOfferItemUI: Mouse ENTERED '", current_offer.offer_name, "'. Can afford: ", _can_afford, ", Is owned (this specific offer): ", _is_owned, ", ShopMode: ", _shop_mode_cached)

	_update_visual_state()

func _on_mouse_exited_item_area() -> void:
	_is_mouse_over = false
	hide_tooltip_requested.emit()
	if current_offer != null:
		# Usunięto _is_owned_this_specific_offer z logu, używamy _is_owned
		print("DEBUG ShopOfferItemUI: Mouse EXITED '", current_offer.offer_name, "'. Can afford: ", _can_afford, ", Is owned (this specific offer): ", _is_owned, ", ShopMode: ", _shop_mode_cached)

	_update_visual_state()

# Ta funkcja nie jest już potrzebna, jeśli setup_offer poprawnie ustawia ikonę z offer.display_icon
# func set_display_icon(texture: Texture2D) -> void:
# 	if is_instance_valid(item_icon_rect):
# 		item_icon_rect.texture = texture
# 	else:
# 		printerr("ShopOfferItemUI: item_icon_rect is not valid in set_display_icon().")
