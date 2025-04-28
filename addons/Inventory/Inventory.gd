class_name Inventory extends Resource

var slots: Array[InventorySlot] = []
@export var capacity: int = 5  # Maximum weight capacity of the inventory

signal item_added(item:InventoryItem, slot_idx:int)
signal item_removed(item:InventoryItem, slot_idx:int)
signal capacity_changed(from:int, to:int)

# Returns true if all items in the array are of the same InventoryItemType
static func is_items_of_same_type(items: Array[InventoryItem]) -> bool:
	# If the array is empty, return true (no conflicting types)
	if items.size() == 0:
		return true
	
	# Store the type of the first item
	var item_type = items[0].item_type
	# Loop through the rest of the items and check their type
	for i in range(1, items.size()):
		if items[i].item_type != item_type:
			return false
	
	return true

# Initialize the slots with empty InventorySlots
func _init():
	for i in range(capacity):
		var slot = InventorySlot.new()
		slots.append(slot)
		slot.item_added.connect(_on_slot_item_added.bind(i))
		slot.item_removed.connect(_on_slot_item_removed.bind(i))
	emit_changed()  # Emit change when initializing the inventory

# Signal handler for when an item is added to a slot
func _on_slot_item_added(item:InventoryItem, slot_idx:int):
	item_added.emit(item, slot_idx)
	emit_changed()

# Signal handler for when an item is removed from a slot
func _on_slot_item_removed(item:InventoryItem, slot_idx:int):
	item_removed.emit(item, slot_idx)
	emit_changed()

# Sorts all items by type in ascending order.
# Items are temporarily removed from their slots and reinserted after sorting.
func sort():
	var items = take_all_items()
	items.sort_custom(_custom_sort_item_type)
	
	for item in items:
		put(item)
	emit_changed()

# Custom sorting method to compare item types by name
func _custom_sort_item_type(a:InventoryItem, b:InventoryItem) -> bool:
	var names = [a.item_type.name, b.item_type.name]
	names.sort()
	return names[0] == a.name

# Get all items from all slots in the inventory
func get_all_items() -> Array[InventoryItem]:
	var items : Array[InventoryItem] = []
	
	for slot in slots:
		items.append_array(slot.items)
	
	return items

# Take all items from the inventory and empty all slots
func take_all_items() -> Array[InventoryItem]:
	var items :Array[InventoryItem] = []
	
	for slot in slots:
		items.append_array(slot.take_all())
	
	emit_changed()
	return items

# Get the total count of items in the inventory
func get_count() -> int:
	var count = 0
	for slot in slots:
		count += slot.count
	
	return count

# Check if the inventory is empty
func is_empty() -> bool:
	return get_count() == 0

# Change the capacity of the inventory and resize the slots array
func resize(new_capacity: int):
	if new_capacity == capacity:
		return
	
	var old_capacity = capacity
	
	if new_capacity < capacity:
		slots.resize(new_capacity)  # Remove excess slots
	else:
		for i in range(capacity, new_capacity):
			slots.append(InventorySlot.new())  # Add new empty slots
	capacity = new_capacity

	capacity_changed.emit(old_capacity, new_capacity)
	emit_changed()

# Check if the inventory has space for a given item
func has_space_for_item(item: InventoryItem) -> bool:
	for slot in slots:
		if slot.type == null or (slot.type == item and slot.type.stackable and slot.available_stacks() > 0):
			return true
	return false

# Put an item into the inventory
func put(item: InventoryItem) -> bool:
	if not has_space_for_item(item):
		return false
	
	# Try to stack the item in an existing slot
	for slot in slots:
		if slot.type == item.item_type and item.item_type.stackable:
			if slot.available_stacks() > 0:
				slot.put(item)
				emit_changed()
				return true
	
	# If stacking isn't possible, find an empty slot
	for slot in slots:
		if slot.type == null:
			slot.put(item)
			emit_changed()
			return true
	
	return false

# Check if there is space for multiple items in the inventory
func has_space_for_items(items: Array[InventoryItem]) -> bool:
	for item in items:
		if not has_space_for_item(item):
			return false
	return true

# Put multiple items into the inventory at once
func put_many(items: Array[InventoryItem]) -> bool:
	if not has_space_for_items(items):
		return false
	
	for item in items:
		if not put(item):
			return false
	emit_changed()
	return true

# Remove a specific item from the inventory
func take(item: InventoryItem):
	for slot in slots:
		if item in slot.items:
			slot.take(item)
			emit_changed()
			return

# Take all items from a specific slot
func take_all_from_slot(slot_idx: int) -> Array[InventoryItem]:
	var slot = slots[slot_idx]
	var items: Array[InventoryItem] = []
	if slot.item != null:
		items.append(slot.item)
		slot.clear()
	emit_changed()
	return items

# Get all items of a specific type from the inventory
func get_of_type(type: InventoryItemType) -> Array[InventoryItem]:
	var items: Array[InventoryItem] = []
	for slot in slots:
		if slot.item != null and slot.item.item_type == type:
			items.append(slot.item)
	return items

# Check if a specific item exists in the inventory
func has_item(item: InventoryItem) -> bool:
	for slot in slots:
		if slot.item == item:
			return true
	return false

# Check if an item of a specific type exists in the inventory
func has_item_of_type(type: InventoryItemType) -> bool:
	for slot in slots:
		if not slot.is_empty() and slot.type == type:
			return true
	return false

# Get the total amount of a specific item type in the inventory
func get_amount_of_item_type(type: InventoryItemType) -> int:
	var amount = 0
	for slot in slots:
		if not slot.is_empty():
			if slot.type == type:
				amount += slot.count
	return amount

# Move an item from one slot to another
func move(item: InventoryItem, new_slot_idx: int):
	for i in range(slots.size()):
		if slots[i].items.has(item):  # Check if the current slot contains the item
			var current_slot = slots[i]
			var new_slot = slots[new_slot_idx]
			
			# If the new slot contains the same item type and the item is stackable, try to stack
			if new_slot.type == item.item_type and item.item_type.stackable:
				# Transfer as many items as possible
				var remaining_items = current_slot.take_many(new_slot.available_stacks())
				new_slot.put_all(remaining_items)
				
				# Clear current slot if empty
				if current_slot.is_empty():
					current_slot.clear()
			else:
				# Swap the items if they cannot be stacked
				var temp_items = new_slot.take_all()  # Take all items from the new slot
				new_slot.put_all(current_slot.take_all())  # Move all items from the current slot to the new slot
				current_slot.put_all(temp_items)  # Put the previously taken items into the original slot
			
			emit_changed()
			return

# Get the total weight of all items in the inventory
func get_total_weight() -> int:
	var total_weight: int = 0
	for slot in slots:
		total_weight += slot.weight
	return total_weight
