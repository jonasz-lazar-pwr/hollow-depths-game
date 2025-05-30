# res://scripts/ui/ShopOfferItemUI.gd
extends Control

signal purchase_requested(offer: ShopOffer)
signal show_tooltip_requested(text_title: String, text_description: String, item_global_rect: Rect2)
signal hide_tooltip_requested()

@onready var item_icon_rect: TextureRect = $BackgroundButton/CenterContainer/IconAndCountVBox/ItemIcon
@onready var count_label: Label = $BackgroundButton/CenterContainer/IconAndCountVBox/CountLabel
@onready var background_button: Button = $BackgroundButton

const COLOR_NORMAL_CAN_AFFORD_BUY: Color = Color("4a4a4a") # Dla KUPNA ulepszeń
const COLOR_NORMAL_CANT_AFFORD: Color = Color(0.8, 0.2, 0.2, 1.0)
const COLOR_NORMAL_OWNED: Color = Color(0.3, 0.3, 0.3, 1.0)

const COLOR_HOVER_CAN_AFFORD_BUY: Color = Color("6a6a6a") # Dla KUPNA ulepszeń
const COLOR_HOVER_CANT_AFFORD: Color = Color(0.9, 0.3, 0.3, 1.0)

const COLOR_SELL_AVAILABLE_NORMAL: Color = Color.WHITE
const COLOR_SELL_AVAILABLE_HOVER: Color = Color(0.95, 0.95, 0.95, 1.0)

# Stała dla przezroczystości, gdy nie można czegoś zrobić
const ALPHA_UNAVAILABLE: float = 0.5

var current_offer: ShopOffer = null
var player_inventory_ref: Inventory = null

var _is_owned: bool = false
var _can_afford: bool = false
var _is_mouse_over: bool = false
var _shop_mode_cached: int # 0 dla SELL, 1 dla BUY

func _ready() -> void:
	if is_instance_valid(background_button):
		# Upewnij się, że sygnał purchase_requested jest emitowany, a nie purchase_button_pressed
		# jeśli ShopUI nasłuchuje na purchase_requested.
		# Zostawiam to tak, jak masz w swoim kodzie, zakładając, że jest spójne.
		background_button.pressed.connect(_on_item_pressed)
		if not background_button.mouse_entered.is_connected(_on_mouse_entered_item_area):
			background_button.mouse_entered.connect(_on_mouse_entered_item_area)
		if not background_button.mouse_exited.is_connected(_on_mouse_exited_item_area):
			background_button.mouse_exited.connect(_on_mouse_exited_item_area)
		# background_button.modulate = COLOR_NORMAL_CANT_AFFORD # Początkowa modulacja w _update_visual_state
	else:
		printerr("ShopOfferItemUI: BackgroundButton is not valid in _ready!")

func _on_item_pressed() -> void:
	if current_offer and not background_button.disabled:
		print("DEBUG ShopOfferItemUI: _on_item_pressed, emitting purchase_requested for: ", current_offer.offer_name)
		# Jeśli ShopUI.gd nasłuchuje na 'purchase_requested(offer)' to jest OK.
		# Jeśli nasłuchiwało na `purchase_button_pressed.connect(Callable(self, "_on_any_offer_item_pressed").bind(offer_item_ui))`
		# to sygnał `purchase_requested` powinien być głównym sygnałem z tego komponentu.
		# Dla spójności z Twoim kodem w ShopUI, który używa .bind(), zostawiam `purchase_requested` z argumentem.
		purchase_requested.emit(current_offer)


# ZAKTUALIZOWANA SYGNATURA I LOGIKA
func setup_offer(offer: ShopOffer, p_inventory: Inventory, already_purchased: bool, can_afford_this_offer: bool, shop_mode_from_caller: int) -> void:
	print("DEBUG ShopOfferItemUI: setup_offer called with offer: '", (offer.offer_name if offer else "NULL OFFER"), 
		"' already_purchased: ", already_purchased, 
		" can_afford_this_offer: ", can_afford_this_offer, 
		" shop_mode: ", shop_mode_from_caller)
		
	current_offer = offer
	player_inventory_ref = p_inventory # Zachowujemy, może być przydatne do tooltipa
	_is_owned = already_purchased
	_can_afford = can_afford_this_offer # Bezpośrednie przypisanie przekazanej wartości
	_shop_mode_cached = shop_mode_from_caller

	if not is_instance_valid(current_offer):
		printerr("ShopOfferItemUI: current_offer is null in setup_offer! Aborting setup.")
		if is_instance_valid(background_button): background_button.disabled = true
		if is_instance_valid(count_label): count_label.text = "Error"
		if is_instance_valid(item_icon_rect): item_icon_rect.texture = null
		_update_visual_state() # Zaktualizuj, aby pokazać stan błędu
		return

	if is_instance_valid(item_icon_rect):
		var icon_tex = null
		if _shop_mode_cached == 0: # SELL mode
			if is_instance_valid(offer.cost_item) and is_instance_valid(offer.cost_item.texture):
				icon_tex = offer.cost_item.texture
		else: # BUY mode - ikona może pochodzić z innego miejsca, np. specjalnego pola w ShopOffer lub predefiniowanej tekstury
			# W twoim kodzie dla BUY (ulepszenie kilofa), cost_item jest null.
			# Musisz zdecydować, skąd wziąć ikonę dla ofert KUPNA.
			# Załóżmy, że masz pickaxe_icon_texture_ref w ShopUI i przekazujesz ją lub offer ma pole na ikonę.
			# Dla uproszczenia, jeśli cost_item jest null, użyjemy domyślnej ikony lub pozostawimy pustą.
			if is_instance_valid(offer.cost_item) and is_instance_valid(offer.cost_item.texture): # Jeśli jednak oferta kupna ma cost_item z teksturą
				icon_tex = offer.cost_item.texture
			elif offer.unique_id == "unique_offer_id": # Specjalny przypadek dla ulepszenia kilofa
				# Tutaj byś załadował ikonę kilofa, np. przekazaną do setup_offer lub zdefiniowaną w ShopOffer
				# Dla przykładu, załóżmy, że ShopOffer ma pole @export var display_icon: Texture2D
				# if is_instance_valid(offer.display_icon): icon_tex = offer.display_icon
				# Jeśli nie, to pozostanie null i będzie widoczny placeholder lub nic.
				# Twój `pickaxe_icon_texture_ref` jest w `ShopUI.gd`. Trzeba by go jakoś tu dostać.
				# Na razie, jeśli nie ma `cost_item.texture`, ikona będzie pusta dla kilofa.
				pass # Pozostaw icon_tex jako null, chyba że masz mechanizm na ikonę dla ofert kupna

		item_icon_rect.texture = icon_tex
	else:
		printerr("ShopOfferItemUI: item_icon_rect is null in setup_offer!")

	if is_instance_valid(count_label):
		if not _is_owned: # Tylko jeśli nie posiadane
			if _shop_mode_cached == 0: # SELL
				count_label.text = "x%d" % offer.cost_amount # cost_amount to ilość Ammolitu
			else: # BUY
				# Dla ofert kupna, opis kosztu jest w offer.description
				# `offer.cost_amount` dla kilofa to `current_pickaxe_level_placeholder`
				# Możemy zostawić puste lub pokazać coś innego, np. "Kup"
				# Jeśli `display_offer_for_pickaxe.description` zawiera koszt w monetach,
				# to etykieta `count_label` może nie być tu potrzebna lub wyświetlać co innego.
				# Na razie, zgodnie z Twoim kodem, jeśli `offer.cost_amount` > 0 to pokazujemy.
				if offer.cost_amount > 0 && offer.cost_item != null : # Jeśli jest koszt w przedmiotach
					count_label.text = "x%d" % offer.cost_amount
				else: # np. koszt w monetach, gdzie cost_item jest null
					count_label.text = "" # Lub np. "Kup" - do decyzji
		else:
			count_label.text = "Owned" # Już ustawione w _update_visual_state, ale dla pewności
	else:
		printerr("ShopOfferItemUI: count_label is null in setup_offer!")
		
	_update_visual_state()

# ZAKTUALIZOWANA LOGIKA WIZUALNA
func _update_visual_state() -> void:
	if not is_instance_valid(background_button) or \
	   not is_instance_valid(item_icon_rect) or \
	   not is_instance_valid(count_label):
		printerr("ShopOfferItemUI: Cannot update visual state, one or more required nodes are invalid.")
		return

	var current_normal_color: Color
	var current_hover_color: Color
	var label_text_color_override: Color = Color.WHITE # Domyślnie biały tekst
	var icon_modulate_color: Color = Color.WHITE     

	if _is_owned:
		current_normal_color = COLOR_NORMAL_OWNED
		current_hover_color = COLOR_NORMAL_OWNED 
		background_button.disabled = true
		if is_instance_valid(count_label): count_label.text = "Owned"
		label_text_color_override = Color(0.7, 0.7, 0.7, 1.0) 
		icon_modulate_color = Color(1.0, 1.0, 1.0, ALPHA_UNAVAILABLE)
	else:
		background_button.disabled = not _can_afford
		
		if _shop_mode_cached == 0: # Tryb SPRZEDAŻY
			if _can_afford: # Gracz ma przedmioty do sprzedania
				current_normal_color = COLOR_SELL_AVAILABLE_NORMAL # To jest Color.WHITE
				current_hover_color = COLOR_SELL_AVAILABLE_HOVER
				# === POPRAWKA TUTAJ: Wracamy do białego tekstu ===
				label_text_color_override = Color.WHITE 
				# ===============================================
				icon_modulate_color = Color.WHITE 
				if is_instance_valid(current_offer) and is_instance_valid(count_label):
					count_label.text = "x%d" % current_offer.cost_amount
			else: # Gracz nie ma przedmiotów do sprzedania (0 przedmiotów)
				current_normal_color = COLOR_NORMAL_CANT_AFFORD 
				current_hover_color = COLOR_HOVER_CANT_AFFORD   
				label_text_color_override = Color(1.0, 1.0, 1.0, ALPHA_UNAVAILABLE) 
				icon_modulate_color = Color(1.0, 1.0, 1.0, ALPHA_UNAVAILABLE) 
				if is_instance_valid(current_offer) and is_instance_valid(count_label):
					count_label.text = "x%d" % current_offer.cost_amount 
		else: # Tryb KUPNA
			if _can_afford: 
				current_normal_color = COLOR_NORMAL_CAN_AFFORD_BUY 
				current_hover_color = COLOR_HOVER_CAN_AFFORD_BUY   
				label_text_color_override = Color.WHITE 
				icon_modulate_color = Color.WHITE
				if is_instance_valid(current_offer) and is_instance_valid(count_label):
					if current_offer.cost_item != null && current_offer.cost_amount > 0:
						count_label.text = "x%d" % current_offer.cost_amount
					else: 
						count_label.text = "" 
			else: 
				current_normal_color = COLOR_NORMAL_CANT_AFFORD 
				current_hover_color = COLOR_HOVER_CANT_AFFORD   
				label_text_color_override = Color(1.0, 1.0, 1.0, ALPHA_UNAVAILABLE) 
				icon_modulate_color = Color(1.0, 1.0, 1.0, ALPHA_UNAVAILABLE) 
				if is_instance_valid(current_offer) and is_instance_valid(count_label):
					if current_offer.cost_item != null && current_offer.cost_amount > 0:
						count_label.text = "x%d" % current_offer.cost_amount
					else:
						count_label.text = ""

		if _is_mouse_over:
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
		print("DEBUG ShopOfferItemUI: Mouse ENTERED '", current_offer.offer_name, "'. Can afford: ", _can_afford, ", Is owned: ", _is_owned, ", ShopMode: ", _shop_mode_cached)
	else:
		print("DEBUG ShopOfferItemUI: Mouse ENTERED (NO OFFER).")
	_update_visual_state()


func _on_mouse_exited_item_area() -> void:
	_is_mouse_over = false
	hide_tooltip_requested.emit()
	if current_offer != null:
		print("DEBUG ShopOfferItemUI: Mouse EXITED '", current_offer.offer_name, "'. Can afford: ", _can_afford, ", Is owned: ", _is_owned, ", ShopMode: ", _shop_mode_cached)
	else:
		print("DEBUG ShopOfferItemUI: Mouse EXITED (NO OFFER).")
	_update_visual_state()

func set_display_icon(texture: Texture2D) -> void:
	if is_instance_valid(item_icon_rect):
		item_icon_rect.texture = texture
	else:
		printerr("ShopOfferItemUI: item_icon_rect is not valid in set_display_icon().")
