# res://scripts/ui/ShopOfferItemUI.gd
extends Control # Zmieniono, aby pasowało do nowego typu głównego węzła

signal purchase_requested(offer: ShopOffer)

@onready var item_icon_rect: TextureRect = $CenterContainer/IconAndCountVBox/ItemIcon
@onready var count_label: Label = $CenterContainer/IconAndCountVBox/CountLabel
@onready var background_button: Button = $BackgroundButton

@onready var tooltip_popup: PanelContainer = $TooltipPopup
@onready var tooltip_title: Label = $TooltipPopup/TooltipMargin/TooltipVBox/TooltipLabel # Zmieniono na TooltipLabel
@onready var tooltip_description: Label = $TooltipPopup/TooltipMargin/TooltipVBox/TooltipDescription

var current_offer: ShopOffer = null
var player_inventory_ref: Inventory = null

func _ready() -> void:
	if is_instance_valid(background_button):
		background_button.pressed.connect(_on_item_pressed)
	else:
		printerr("ShopOfferItemUI: BackgroundButton not found!")

	# Podłącz sygnały myszy do głównego węzła ShopOfferItem (czyli self)
	mouse_entered.connect(_on_mouse_entered_item_area)
	mouse_exited.connect(_on_mouse_exited_item_area)

	if is_instance_valid(tooltip_popup):
		tooltip_popup.visible = false
	else:
		printerr("ShopOfferItemUI: TooltipPopup not found!")

func setup_offer(offer: ShopOffer, p_inventory: Inventory, already_purchased: bool) -> void:
	current_offer = offer
	player_inventory_ref = p_inventory

	# Ustawianie ikony i licznika
	if is_instance_valid(offer.cost_item) and is_instance_valid(offer.cost_item.texture):
		item_icon_rect.texture = offer.cost_item.texture
	else:
		item_icon_rect.texture = null # Możesz tu wstawić domyślną ikonę "brak obrazka"
	
	count_label.text = "x%d" % offer.cost_amount

	# Ustawianie danych dla tooltipa
	tooltip_title.text = offer.offer_name
	tooltip_description.text = offer.description

	# Obsługa stanu "kupione" lub "stać/nie stać"
	if already_purchased:
		background_button.disabled = true
		modulate = Color(0.5, 0.5, 0.5, 0.8) # Przyciemnij cały item
		count_label.text = "Owned"
	else:
		var can_afford = false
		if p_inventory and is_instance_valid(offer.cost_item):
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
	if is_instance_valid(tooltip_popup) and current_offer != null:
		# Pozycjonowanie tooltipa:
		# Możesz chcieć, aby tooltip pojawiał się zawsze w tym samym miejscu względem itemu,
		# lub podążał za myszką z offsetem.
		# Proste pozycjonowanie pod itemem:
		var item_global_rect = get_global_rect()
		tooltip_popup.global_position = item_global_rect.position + Vector2(0, item_global_rect.size.y + 5) # 5px pod itemem
		
		# Upewnij się, że tooltip nie wychodzi poza ekran (bardziej zaawansowane)
		# var screen_size = get_viewport_rect().size
		# if tooltip_popup.global_position.x + tooltip_popup.size.x > screen_size.x:
		#    tooltip_popup.global_position.x = screen_size.x - tooltip_popup.size.x
		# if tooltip_popup.global_position.y + tooltip_popup.size.y > screen_size.y:
		#    tooltip_popup.global_position.y = item_global_rect.position.y - tooltip_popup.size.y - 5 # Nad itemem

		tooltip_popup.visible = true

func _on_mouse_exited_item_area() -> void:
	if is_instance_valid(tooltip_popup):
		tooltip_popup.visible = false
