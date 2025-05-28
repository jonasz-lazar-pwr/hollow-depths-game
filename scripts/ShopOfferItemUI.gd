# res://scripts/ui/ShopOfferItemUI.gd
extends Control

signal purchase_requested(offer: ShopOffer)
signal show_tooltip_requested(text_title: String, text_description: String, item_global_rect: Rect2)
signal hide_tooltip_requested()

@onready var item_icon_rect: TextureRect = $BackgroundButton/CenterContainer/IconAndCountVBox/ItemIcon
@onready var count_label: Label = $BackgroundButton/CenterContainer/IconAndCountVBox/CountLabel
@onready var background_button: Button = $BackgroundButton

const COLOR_NORMAL_CAN_AFFORD: Color = Color("4a4a4a")
const COLOR_NORMAL_CANT_AFFORD: Color = Color(0.8, 0.2, 0.2, 1.0) # Czerwony, gdy nie stać/nie można sprzedać
const COLOR_NORMAL_OWNED: Color = Color(0.3, 0.3, 0.3, 1.0)

const COLOR_HOVER_CAN_AFFORD: Color = Color("6a6a6a")
const COLOR_HOVER_CANT_AFFORD: Color = Color(0.9, 0.3, 0.3, 1.0)

var current_offer_ref: ShopOffer = null
var player_inventory_ref: Inventory = null
var current_shop_mode_as_int_ref: int # Przechowamy tryb sklepu jako int (0=SELL, 1=BUY z ShopUI.ShopMode)

var _is_owned_ref: bool = false
var _can_afford_ref: bool = false # Czy gracz może sobie pozwolić (kupić) lub czy ma co sprzedać
var _is_mouse_over: bool = false

# Ikona kilofa - upewnij się, że ścieżka jest poprawna i plik .tres istnieje
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
	_update_visual_state() # Ustawienie domyślnego stanu


func _on_item_pressed() -> void:
	if current_offer_ref and not background_button.disabled:
		purchase_requested.emit(current_offer_ref)

func setup_offer(offer: ShopOffer, p_inventory: Inventory, already_purchased: bool, can_afford: bool, shop_mode_as_int: int) -> void:
	current_offer_ref = offer
	player_inventory_ref = p_inventory
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
		# Sprawdź ID oferty ulepszenia kilofa (powinno być "unique_offer_id" z pliku .tres dla pickaxe_upgrade_offer_template_ref)
		if current_offer_ref.unique_id == "unique_offer_id": 
			item_icon_rect.texture = pickaxe_icon_texture_ref
			if is_instance_valid(count_label): count_label.text = "Lvl: %d" % current_offer_ref.cost_amount 
		else: # Inne oferty kupna (jeśli będą)
			if is_instance_valid(current_offer_ref.cost_item) and is_instance_valid(current_offer_ref.cost_item.texture):
				item_icon_rect.texture = current_offer_ref.cost_item.texture
			else:
				item_icon_rect.texture = null
			if is_instance_valid(count_label): count_label.text = "x%d" % current_offer_ref.cost_amount
	else:
		printerr("ShopOfferItemUI: Unknown shop mode in setup: ", current_shop_mode_as_int_ref)

	_update_visual_state()


func _update_visual_state() -> void:
	if not is_instance_valid(background_button): # Dodatkowe zabezpieczenie
		return

	if _is_owned_ref and current_shop_mode_as_int_ref == 1: # "Owned" ma sens tylko w trybie BUY
		background_button.modulate = COLOR_NORMAL_OWNED
		background_button.disabled = true
		if is_instance_valid(count_label):
			if current_offer_ref and current_offer_ref.unique_id == "unique_offer_id": # ID dla kilofa
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
		
		# Przywróć tekst licznika, jeśli nie był "Owned" (np. po zmianie trybu lub stanu _can_afford_ref)
		# Ta część jest ważna, aby licznik/poziom się poprawnie aktualizował, gdy oferta nie jest "Owned"
		if current_offer_ref:
			if current_shop_mode_as_int_ref == 0 and current_offer_ref.unique_id == "SELL_ALL_AMMOLITE_UNIQUE_ID":
				if is_instance_valid(count_label): count_label.text = "x%d" % current_offer_ref.cost_amount
			elif current_shop_mode_as_int_ref == 1:
				if current_offer_ref.unique_id == "unique_offer_id": # ID dla kilofa
					if is_instance_valid(count_label): count_label.text = "Lvl: %d" % current_offer_ref.cost_amount
				elif is_instance_valid(count_label) and is_instance_valid(current_offer_ref.cost_item): # Dla innych ofert kupna z cost_item
					count_label.text = "x%d" % current_offer_ref.cost_amount
				elif is_instance_valid(count_label): # Jeśli oferta kupna nie ma cost_item, ale ma cost_amount (np. tylko koszt w monetach)
					count_label.text = "" # Lub coś innego, jeśli potrzebne


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
