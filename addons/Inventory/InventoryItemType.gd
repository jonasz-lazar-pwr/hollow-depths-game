class_name InventoryItemType extends Resource

@export var name: String = "Unknown Item" : set = _set_name
@export var description: String : set = _set_description
@export var texture: Texture : set = _set_texture
@export var weight: int = 1 : set = _set_weight  # Weight of a single item
@export var stackable: bool = true : set = _set_stackable  # Whether this item can be stacked
@export var max_stack_size: int = 99 : set = _set_max_stack_size  # Maximum stack size, if stackable

# Setter for 'name'
func _set_name(n: String):
	if name != n:
		name = n
		emit_changed()

# Setter for 'description'
func _set_description(d: String):
	if description != d:
		description = d
		emit_changed()

# Setter for 'texture'
func _set_texture(t: Texture):
	if texture != t:
		texture = t
		emit_changed()

# Setter for 'weight'
func _set_weight(w: int):
	if weight != w:
		weight = w
		emit_changed()

# Setter for 'stackable'
func _set_stackable(s: bool):
	if stackable != s:
		stackable = s
		emit_changed()

# Setter for 'max_stack_size'
func _set_max_stack_size(s: int):
	if max_stack_size != s:
		max_stack_size = s
		emit_changed()
