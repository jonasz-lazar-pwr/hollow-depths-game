# res://scripts/ui/ShopOfferItemUI.gd
extends VBoxContainer # Lub HBoxContainer

signal purchase_requested(offer: ShopOffer)

@onready var name_label: Label = $TopContent/TextInfo/NameLabel
@onready var description_label: Label = $TopContent/TextInfo/DescriptionLabel
@onready var cost_label: Label = $TopContent/TextInfo/CostLabel
@onready var buy_button: Button = $BuyButton

var current_offer: ShopOffer = null
var player_inventory_ref: Inventory = null # Referencja, nie przechowujemy całego

func _ready() -> void:
	buy_button.pressed.connect(_on_buy_button_pressed)

func setup_offer(offer: ShopOffer, p_inventory: Inventory, already_purchased: bool) -> void:
	current_offer = offer
	player_inventory_ref = p_inventory

	name_label.text = offer.offer_name
	description_label.text = offer.description
	if offer.cost_item:
		cost_label.text = "Cost: %d %s" % [offer.cost_amount, offer.cost_item.name]
	else:
		cost_label.text = "Cost: Free" # Lub inny tekst

	if already_purchased:
		buy_button.text = "Purchased"
		buy_button.disabled = true
	else:
		# Sprawdź, czy gracza stać (tylko dla wizualnego feedbacku)
		var can_afford = false
		if p_inventory and offer.cost_item:
			can_afford = p_inventory.get_amount_of_item_type(offer.cost_item) >= offer.cost_amount

		if can_afford:
			buy_button.text = "Buy"
			buy_button.disabled = false
		else:
			buy_button.text = "Buy" # Lub np. "Need %d" % offer.cost_amount
			buy_button.disabled = true # Dezaktywuj jeśli nie stać
			 # Można dodać stylizację dla przycisku (np. czerwony tekst)

func _on_buy_button_pressed() -> void:
	if current_offer:
		purchase_requested.emit(current_offer)
