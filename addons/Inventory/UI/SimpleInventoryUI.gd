class_name SimpleInventoryUI extends BoxContainer

@export var ItemScene:PackedScene

@export var initial_items:Array[InventoryItem]

@export var inventory:Inventory:set = set_inventory
@export var container_target_node:NodePath
var container_target:Node

func set_inventory(it:Inventory):
	if inventory == it:
		return
	
	inventory = it
	
	if is_inside_tree():
		_clear_ui()
		_create_ui()
		if initial_items:
			inventory.put_many(initial_items)


func _clear_ui():
	for itemUI in container_target.get_children():
		itemUI.queue_free()


func _create_ui():
	if inventory:
		for slot_id in range(inventory.slots.size()):
			for item in inventory.slots[slot_id].items:
				_create_inventory_list_item_ui(item, slot_id)
		
		inventory.item_added.connect(_on_inventory_item_added)
		inventory.item_removed.connect(_on_inventory_item_removed)


func _on_inventory_item_added(item:InventoryItem, slot:int):
	if item.item_type.stackable:
		# can we stack?
		var current_item_ui = get_first_item_ui_by_type(item.item_type)
		if current_item_ui and slot == current_item_ui.get_meta("inventory_slot"):
			current_item_ui.count += 1
			return
	
	_create_inventory_list_item_ui(item, slot)


func _on_inventory_item_removed(item:InventoryItem, slot:int):
	var itemUI = get_item_ui(item)
	container_target.remove_child(itemUI)
	itemUI.queue_free()


func _create_inventory_list_item_ui(item:InventoryItem, slot:int):
	var itemUI:Control = ItemScene.instantiate()
	itemUI.set_meta("inventory_slot", slot)
	itemUI.item = item
	container_target.add_child(itemUI)


func get_item_ui(item:InventoryItem) -> Control:
	for child in container_target.get_children():
		if child.item == item:
			return child
	return null


func get_first_item_ui_by_type(type:InventoryItemType) -> InventoryGridItemUI:
	for child in container_target.get_children():
		if child.item.item_type == type:
			return child
	
	return null


func _ready():
	if container_target_node:
		container_target = get_node(container_target_node)
	
	if container_target:
		_clear_ui()
		_create_ui()
		if initial_items:
			inventory.put_many(initial_items)
