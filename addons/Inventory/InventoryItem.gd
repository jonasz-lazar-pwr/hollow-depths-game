class_name InventoryItem extends Resource

@export var item_type: InventoryItemType
@export var custom_name:String

var name:String:
	get:
		if custom_name:
			return custom_name
		return item_type.name
