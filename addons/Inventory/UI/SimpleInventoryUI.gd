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


func _on_inventory_item_removed(item: InventoryItem, slot: int):
	# Dodajmy sprawdzenie null dla bezpieczeństwa
	if item == null or item.item_type == null:
		printerr("SimpleInventoryUI: Received null item or item without type in _on_inventory_item_removed.")
		return

	if item.item_type.stackable:
		# Przedmiot jest stackowalny: Znajdź UI dla tego typu
		var stack_ui = get_first_item_ui_by_type(item.item_type)
		if stack_ui:
			# Zmniejsz licznik na znalezionym UI
			stack_ui.count -= 1
			print("SimpleInventoryUI: Decremented count for ", item.item_type.name, " UI. New count: ", stack_ui.count)

			# Jeśli licznik spadł do zera, usuń całe UI dla tego stosu
			if stack_ui.count <= 0:
				print("SimpleInventoryUI: Stack count is 0, removing UI element for ", item.item_type.name)
				# Bezpieczne usunięcie z kontenera przed queue_free
				if is_instance_valid(container_target):
					container_target.remove_child(stack_ui)
				stack_ui.queue_free()
		else:
			# To nie powinno się zdarzyć, jeśli dodawanie działa poprawnie
			printerr("SimpleInventoryUI: Could not find stack UI to decrement count for stackable item: ", item.item_type.name)
	else:
		# Przedmiot nie jest stackowalny: Znajdź konkretne UI dla tego obiektu
		var itemUI = get_item_ui(item)
		if itemUI:
			print("SimpleInventoryUI: Removing UI element for non-stackable item: ", item.name)
			# Bezpieczne usunięcie z kontenera przed queue_free
			if is_instance_valid(container_target):
				container_target.remove_child(itemUI)
			itemUI.queue_free()
		else:
			# To też nie powinno się zdarzyć dla non-stackable
			printerr("SimpleInventoryUI: Could not find specific UI element for non-stackable item: ", item.name)


func _create_inventory_list_item_ui(item:InventoryItem, slot:int):
	if not ItemScene:
		printerr("SimpleInventoryUI: ItemScene is not assigned!")
		return
	if not is_instance_valid(container_target):
		printerr("SimpleInventoryUI: Cannot add item UI, container_target is invalid!")
		return

	print("SimpleInventoryUI: Creating UI for item: ", item.name if item else "NULL ITEM", " in slot: ", slot) # Dodaj sprawdzenie `if item`
	var itemUI:Control = ItemScene.instantiate()
	itemUI.set_meta("inventory_slot", slot)
	itemUI.item = item
	container_target.add_child(itemUI)
	print("SimpleInventoryUI: Item UI added as child.")


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
	print("SimpleInventoryUI: _ready start")
	if container_target_node:
		container_target = get_node(container_target_node)
		print("SimpleInventoryUI: Container target node found: ", container_target)
	else:
		printerr("SimpleInventoryUI: container_target_node not set!")
		return # Ważne, żeby nie kontynuować bez celu

	if container_target:
		_clear_ui()
		_create_ui()
		if initial_items:
			if inventory: # Dodaj sprawdzenie, czy inventory istnieje
				inventory.put_many(initial_items)
			else:
				printerr("SimpleInventoryUI: Cannot put initial_items, inventory is null!")
	else:
		printerr("SimpleInventoryUI: container_target is null!")
	print("SimpleInventoryUI: _ready end")
