class_name InventoryGridItemUI extends Control

var item:InventoryItem:
    set = set_item

var count:int = 1:
    set = set_count

@onready var icon: TextureRect = $Icon
@onready var countLabel: Label = $Icon/Count
@onready var tooltip: CanvasLayer = $Tooltip # CanvasLayer dla tooltipa? To trochę nietypowe, ale jeśli działa...
@onready var tooltipTitle: Label = $Tooltip/Container/MarginContainer/VBoxContainer/Title
@onready var tooltipText: RichTextLabel = $Tooltip/Container/MarginContainer/VBoxContainer/Text

signal request_select(item)


func set_item(i:InventoryItem):
    item = i
    if is_inside_tree():
        _update_item()

func set_count(c:int):
    count = c
    if is_inside_tree():
        countLabel.text = str(count)
        if count == 0: # Zmieniono z count <= 0 na count == 0 dla precyzji
            countLabel.hide()
        else:
            countLabel.show()

func _update_item():
    if not item or not item.item_type: # Dodatkowe sprawdzenie item.item_type
        icon.texture = null # Wyczyść ikonę, jeśli brak przedmiotu
        tooltipTitle.text = ""
        tooltipText.text = ""
        countLabel.text = "0" # Lub pusty string, zależy od preferencji
        countLabel.hide()
        return # Zakończ funkcję, jeśli nie ma przedmiotu
    
    icon.texture = item.item_type.texture
    tooltipTitle.text = item.name
    tooltipText.text = item.item_type.description
    countLabel.text = str(count)
    countLabel.visible = count > 0 # Pozostaje tak samo, ale count jest aktualizowany w set_count

func _ready():
    mouse_entered.connect(_on_mouse_entered)
    mouse_exited.connect(_on_mouse_exited)
    _update_item()
    
    # === NOWA LINIA - KLUCZOWA POPRAWKA ===
    if is_instance_valid(tooltip): # Dodatkowe sprawdzenie dla bezpieczeństwa
        tooltip.hide() 
    # === KONIEC NOWEJ LINII ===


func _on_mouse_entered():
    # Pokaż tooltip tylko jeśli jest przedmiot w slocie
    if item and item.item_type and is_instance_valid(tooltip): # Dodano sprawdzenie item i item.item_type
        tooltip.show()


func _on_mouse_exited():
    if is_instance_valid(tooltip): # Dodatkowe sprawdzenie dla bezpieczeństwa
        tooltip.hide()

#class_name InventoryGridItemUI extends Control
#
#var item:InventoryItem:
    #set = set_item
#
#var count:int = 1:
    #set = set_count
#
#@onready var icon: TextureRect = $Icon
#@onready var countLabel: Label = $Icon/Count
#@onready var tooltip: CanvasLayer = $Tooltip
#@onready var tooltipTitle: Label = $Tooltip/Container/MarginContainer/VBoxContainer/Title
#@onready var tooltipText: RichTextLabel = $Tooltip/Container/MarginContainer/VBoxContainer/Text
#
#signal request_select(item)
#
#
#func set_item(i:InventoryItem):
    #item = i
    #if is_inside_tree():
        #_update_item()
#
#func set_count(c:int):
    #count = c
    #if is_inside_tree():
        #countLabel.text = str(count)
        #if count == 0:
            #countLabel.hide()
        #else:
            #countLabel.show()
#
#func _update_item():
    #if not item:
        #return
    #
    #icon.texture = item.item_type.texture
    #tooltipTitle.text = item.name
    #tooltipText.text = item.item_type.description
    #countLabel.text = str(count)
    #countLabel.visible = count > 0
#
#func _ready():
    #mouse_entered.connect(_on_mouse_entered)
    #mouse_exited.connect(_on_mouse_exited)
    #_update_item()
#
#
#func _on_mouse_entered():
    #tooltip.show()
#
#
#func _on_mouse_exited():
    #tooltip.hide()
