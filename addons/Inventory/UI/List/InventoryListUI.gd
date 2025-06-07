class_name InventoryListUI extends ScrollContainer

@export var InventoryListItemUI: PackedScene
@export var initial_items: Array[InventoryItem]
@export var inventory: Inventory : set = set_inventory

@onready var vbox: VBoxContainer = $VBoxContainer


# Set the inventory and initialize UI
func set_inventory(it: Inventory):
    if inventory == it:
        return
    
    inventory = it
    
    if is_inside_tree():
        _clear_ui()
        _create_ui()
        if initial_items:
            inventory.put_many(initial_items)

# Clear all the UI elements
func _clear_ui():
    for itemUI in vbox.get_children():
        itemUI.queue_free()

# Create the initial UI for the inventory
func _create_ui():
    for item in inventory.get_all_items():
        _create_inventory_list_item_ui(item)
    
    inventory.item_added.connect(_on_inventory_item_added)
    inventory.item_removed.connect(_on_inventory_item_removed)

# Handle when an item is added to the inventory
func _on_inventory_item_added(item: InventoryItem, slot: int):
    # Check if the item is stackable
    if item.item_type.stackable:
        # Find if the UI already exists for this item
        var itemUI = get_item_ui(item)
        if itemUI != null:
            # Update the stack count of the existing UI
            itemUI.stack_count = inventory.get_amount_of_item_type(item.item_type)
        else:
            # If no UI exists, create a new one
            _create_inventory_list_item_ui(item)
    else:
        # If the item is not stackable, create a new UI
        _create_inventory_list_item_ui(item)

# Handle when an item is removed from the inventory
func _on_inventory_item_removed(item: InventoryItem, slot: int):
    var itemUI = get_item_ui(item)
    if itemUI != null:
        vbox.remove_child(itemUI)
        itemUI.queue_free()

# Create a new UI element for an item
func _create_inventory_list_item_ui(item: InventoryItem):
    var itemUI: InventoryListItemUI = InventoryListItemUI.instantiate()
    itemUI.item = item
    itemUI.stack_count = inventory.get_amount_of_item_type(item.item_type) if item.item_type.stackable else 1
    vbox.add_child(itemUI)

# Retrieve the UI element associated with a specific item
func get_item_ui(item: InventoryItem) -> InventoryListItemUI:
    for child in vbox.get_children():
        if child is InventoryListItemUI and child.item == item:
            return child
    return null

# Ready function to initialize UI
func _ready():
    _clear_ui()
    _create_ui()
    if initial_items:
        inventory.put_many(initial_items)
