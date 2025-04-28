class_name PingPongScroller
extends Container

enum MODE {
	ALWAYS,
	ON_HOVER
}

@export var speed: float = 32.0
@export var mode:MODE = MODE.ON_HOVER
@export var scroll_margin:int = 16
@export var text: String = "Some very long text here":
	set = set_text

@onready var label: Label = $Label

var is_scrolling := true
var direction := 1  # 1 for right, -1 for left

func set_text(t: String):
	text = t
	_update()

func _update():
	label.text = text
	is_scrolling = mode == MODE.ALWAYS
	direction = 1  # Reset to initial scrolling direction

func _ready():
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)

func _on_mouse_entered():
	if mode == MODE.ON_HOVER:
		is_scrolling = true

func _on_mouse_exited():
	if mode == MODE.ON_HOVER:
		is_scrolling = false


func _process(delta: float) -> void:
	var child: Control = get_child(0)
	if child == null or child is Control == false:
		return
	
	if is_scrolling:
		var velocity = direction * speed * delta
		var text_size = child.get_combined_minimum_size()  # Get the full text size
		
		# If the text fits inside the container, no scrolling is needed
		if text_size.x <= size.x:
			is_scrolling = false
			child.position.x = 0
			return
		
		# Calculate scrollable width
		var scroll_width = text_size.x - size.x

		# Update the position of the child based on the velocity
		child.position.x -= velocity
		
		# Handle direction change at the boundaries
		if child.position.x < -scroll_width:
			child.position.x = -scroll_width  # Snap to the right limit
			direction *= -1  # Reverse direction (scroll to the right)
		elif child.position.x > 0:
			child.position.x = 0  # Snap to the left limit
			direction *= -1  # Reverse direction (scroll to the left)
	else:
		if child.position.x != 0:
			child.position = child.position.move_toward(Vector2.ZERO, speed * 2 * delta)
