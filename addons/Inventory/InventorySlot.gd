class_name InventorySlot extends RefCounted

var items:Array[InventoryItem] = []
# Zwraca pierwszy item w slocie (lub null, jeśli pusty)
var item: InventoryItem:
	get:
		if items.size() > 0:
			return items[0]
		return null

var type:InventoryItemType:
	get:
		if items.size() > 0:
			return items[0].item_type
		return null

var count:int:
	get:
		return items.size()


var weight:float:
	get:
		var weight = 0.0
		for item in items:
			weight += item.item_type.weight
		
		return weight

signal item_added(item:InventoryItem)
signal item_removed(item:InventoryItem)

func is_empty() -> bool:
	return count == 0


func available_stacks() -> int:
	if type == null:
		return INF
	
	return type.max_stack_size - count


func take(item:InventoryItem):
	if item in items:
		items.erase(item)


func take_one() -> InventoryItem:
	var item = items.pop_back()
	item_removed.emit(item)
	return item


func take_many(count:int = 1) -> Array[InventoryItem]:
	var to_take:Array[InventoryItem] = []
	
	for i in count:
		var item = items.pop_back()
		to_take.append(item)
		item_removed.emit(item)
	
	return to_take


func take_all() -> Array[InventoryItem]:
	return take_many(items.size())
	

func put(item:InventoryItem) -> bool:
	if type == null:
		items.append(item)
		item_added.emit(item)
		return true
	elif type == item.item_type and type.stackable and count < type.max_stack_size:
		items.append(item)
		item_added.emit(item)
		return true
	
	return false


func put_all(items:Array[InventoryItem]) -> bool:
	if items.size() == 1:
		return put(items[0])
	
	# incompatible type?
	if type != items[0].item_type:
		return false
	
	# verify all items are same type
	if not Inventory.is_items_of_same_type(items):
		return false
	
	# no items in this slot?
	if type == null:
		# stackable?
		if not items[0].item_type.stackable:
			return false
		
		# too many?
		if items.size() > items[0].item_type.max_stack_size:
			return false
		
		# add them
		for item in items:
			put(item)
		
		return true
	
	return false
