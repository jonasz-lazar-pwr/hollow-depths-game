class_name InventoryPopupTooltip extends PanelContainer

@export var offset := Vector2(8, 8)

func _process(delta):
	var vp_size := get_viewport_rect().size
	var mouse := get_global_mouse_position()
	
	var pos = mouse
	
	# horizontally
	if mouse.x <= vp_size.x / 2:
		pos.x = mouse.x + offset.x
	else:
		pos.x = mouse.x - size.x - offset.x
	
	# vertically
	if mouse.y > vp_size.y / 2:
		pos.y = mouse.y - size.y - offset.y
	else:
		pos.y = mouse.y + offset.y
	
	global_position = pos
