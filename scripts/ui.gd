# scripts/ui.gd
extends CanvasLayer

@onready var ladder_label: Label = $LadderCountLabel
@onready var health_label: Label = $HealthLabel
@onready var coins_label: Label = $CoinsLabel # Upewnij się, że ten Label istnieje w scenie UI
@onready var player := get_tree().get_first_node_in_group("player") as CharacterBody2D # ODzkomentuj to
func _ready():
    if not is_instance_valid(player):
        printerr("UI: nie znaleziono Playera lub nie jest typu 'Player'!")
        if is_instance_valid(ladder_label): ladder_label.text = "Drabiny: -"
        if is_instance_valid(health_label): health_label.text = "❤️ -/-"
        if is_instance_valid(coins_label): coins_label.text = "🪙 -"
        return

    # Ekwipunek
    if player.inventory is Inventory: # Bezpośredni dostęp do właściwości
        if not player.inventory.item_added.is_connected(_on_inventory_changed):
            player.inventory.item_added.connect(_on_inventory_changed)
        if not player.inventory.item_removed.is_connected(_on_inventory_changed):
            player.inventory.item_removed.connect(_on_inventory_changed)
        _on_inventory_changed(null, 0)
    else:
        printerr("UI: Player.inventory nie jest typu Inventory.")
        if is_instance_valid(ladder_label): ladder_label.text = "Drabiny: BŁĄD"

    # Zdrowie
    if player.has_signal("health_updated"):
        if not player.health_updated.is_connected(_on_player_health_updated):
            player.health_updated.connect(_on_player_health_updated)
        _on_player_health_updated(player.current_hp, player.max_hp) # Bezpośredni dostęp
    else:
        printerr("UI: Player nie ma sygnału 'health_updated'.")
        if is_instance_valid(health_label): health_label.text = "❤️ BŁĄD"

    # Monety
    if player.has_signal("coins_updated"):
        if not player.coins_updated.is_connected(_on_player_coins_updated):
            player.coins_updated.connect(_on_player_coins_updated)
        _on_player_coins_updated(player.coins) # Bezpośredni dostęp
    else:
        printerr("UI: Player nie ma sygnału 'coins_updated'.")
        if is_instance_valid(coins_label): coins_label.text = "Monety: BŁĄD"


func _on_inventory_changed(item: InventoryItem, slot_idx: int) -> void:
    if not is_instance_valid(player) or not (player.inventory is Inventory):
        if is_instance_valid(ladder_label): ladder_label.text = "Drabiny: ?"
        return
    if not is_instance_valid(player.ladder_item_type): # Bezpośredni dostęp
        if is_instance_valid(ladder_label): ladder_label.text = "Drabiny: (Brak typu)"
        return

    var inv := player.inventory as Inventory
    var ladder_type = player.ladder_item_type as InventoryItemType

    if not is_instance_valid(ladder_type):
        if is_instance_valid(ladder_label): ladder_label.text = "Drabiny: (Błąd typu)"
        return

    var count := inv.get_amount_of_item_type(ladder_type)
    if is_instance_valid(ladder_label):
        ladder_label.text = "Drabiny: %d" % count


func _on_player_health_updated(new_hp: float, max_hp_value: float):
    if not is_instance_valid(health_label):
        printerr("UI: HealthLabel nie jest ważny")
        return
    health_label.text = "❤️ %d/%d" % [int(new_hp), int(max_hp_value)]


func _on_player_coins_updated(new_coin_amount: int):
    if not is_instance_valid(coins_label):
        printerr("UI: CoinsLabel nie jest ważny!") # Dodaj wykrzyknik dla podkreślenia
        return
    coins_label.text = "🪙 %d" % new_coin_amount
