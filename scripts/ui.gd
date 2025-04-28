# ui.gd
extends CanvasLayer

@onready var ladder_label: Label = $LadderCountLabel
@onready var health_label: Label = $HealthLabel
@onready var player := get_tree().get_first_node_in_group("player") as Node2D

func _ready():
	if not player:
		printerr("UI: nie znaleziono Playera w grupie 'player'!")
		return

	# --- Obsługa Ekwipunku ---
	# Połącz sygnały nowego Inventory zamiast starego Dictionary
	var inv := player.inventory as Inventory
	if not inv:
		printerr("UI: player.inventory nie jest Inventory!")
	else:
		# gdy cokolwiek się zmieni, odśwież etykietę
		inv.item_added.connect(_on_inventory_changed)
		inv.item_removed.connect(_on_inventory_changed)
		# od razu zrób pierwsze odświeżenie
		_on_inventory_changed()

	# --- Obsługa HP (bez zmian) ---
	if not player.health_updated.is_connected(_on_player_health_updated):
		player.health_updated.connect(_on_player_health_updated)
	_on_player_health_updated(player.current_hp, player.max_hp)

func _on_inventory_changed():
	# Wyciągnij licznik drabin z Inventory
	var inv := player.inventory as Inventory
	if not inv:
		return
	# Zakładam, że w Playerze masz export var ladder_item_type: InventoryItemType
	var type := player.ladder_item_type as InventoryItemType
	# Ile drabin w ekwipunku?
	var count := inv.get_amount_of_item_type(type)
	ladder_label.text = "Drabiny: %d" % count

func _on_player_health_updated(new_hp: float, max_hp_value: float):
	if not is_instance_valid(health_label):
		printerr("UI: HealthLabel nie jest ważny")
		return
	health_label.text = "HP: %d/%d" % [int(new_hp), int(max_hp_value)]
