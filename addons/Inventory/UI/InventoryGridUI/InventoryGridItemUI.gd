class_name InventoryGridItemUI extends Control

var item:InventoryItem:
    set = set_item

var count:int = 1:
    set = set_count

@onready var icon: TextureRect = $Icon
@onready var countLabel: Label = $Icon/Count
@onready var tooltip: CanvasLayer = $Tooltip
@onready var tooltipTitle: Label = $Tooltip/Container/VBoxContainer/Title
@onready var tooltipText: RichTextLabel = $Tooltip/Container/VBoxContainer/Text

signal request_select(item)


func set_item(i:InventoryItem):
    item = i
    if is_inside_tree():
        _update_item()

func set_count(c:int):
    count = c
    if is_inside_tree():
        countLabel.text = str(count)
        if count == 0:
            countLabel.hide()
        else:
            countLabel.show()

func _update_item():
    if not item:
        return
    
    icon.texture = item.item_type.texture
    tooltipTitle.text = item.name
    tooltipText.text = item.item_type.description
    countLabel.text = str(count)
    countLabel.visible = count > 0

func _ready():
    mouse_entered.connect(_on_mouse_entered)
    mouse_exited.connect(_on_mouse_exited)
    _update_item()


func _on_mouse_entered():
    tooltip.show()


func _on_mouse_exited():
    tooltip.hide()
