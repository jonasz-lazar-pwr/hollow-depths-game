# ui.gd
extends CanvasLayer

@onready var ladder_label: Label = $LadderCountLabel
@onready var health_label: Label = $HealthLabel
@onready var player := get_tree().get_first_node_in_group("player") as Node2D

func _ready():
    if not player:
        printerr("UI: nie znaleziono Playera w grupie 'player'!")
        return

    var inv := player.inventory as Inventory
    if inv:
        inv.item_added.connect(_on_inventory_changed)
        inv.item_removed.connect(_on_inventory_changed)
        # od razu pierwsze odświeżenie:
        _on_inventory_changed(null, 0)

func _on_inventory_changed(item: InventoryItem, slot_idx: int) -> void:
    var inv := player.inventory as Inventory
    if not inv:
        return
    var count := inv.get_amount_of_item_type(player.ladder_item_type)
    ladder_label.text = "Drabiny: %d" % count


func _on_player_health_updated(new_hp: float, max_hp_value: float):
    if not is_instance_valid(health_label):
        printerr("UI: HealthLabel nie jest ważny")
        return
    health_label.text = "❤️ %d/%d" % [int(new_hp), int(max_hp_value)]
