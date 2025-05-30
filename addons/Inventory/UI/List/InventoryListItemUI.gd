@tool
class_name InventoryListItemUI extends PanelContainer

@export var item:InventoryItem:
	set = set_item

@onready var nameLabel:PingPongScroller = $BoxContainer/Name
@onready var stackLabel:Label = $BoxContainer/Stack

@export var stack_count:int = 1:
	set = set_stack_count

func _ready():
	_update_ui()

func set_item(_item:InventoryItem):
	item = _item
	if is_inside_tree():
		_update_ui()

func set_stack_count(count:int):
	if stack_count != count:
		stack_count = count
		stackLabel.text = str(stack_count)
		stackLabel.visible = stack_count > 1

func _gui_input(event: InputEvent) -> void:
	pass

func _update_ui():
	nameLabel.text = item.name
