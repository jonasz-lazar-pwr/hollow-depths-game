extends CharacterBody2D

const SPEED = 50.0
const JUMP_VELOCITY = -75.0
var ladder_stack = 0;

func _ready() -> void:
    for ladder in get_tree().get_nodes_in_group("ladders"):
        ladder.entered_ladder.connect(_on_ladder_entered)
        ladder.exited_ladder.connect(_on_ladder_exited)

func _physics_process(delta: float) -> void:
    if not is_on_floor():
        velocity += get_gravity() * delta / 6

    if Input.is_action_just_pressed("jump") and is_on_floor():
        velocity.y = JUMP_VELOCITY
        $AnimatedSprite2D.speed_scale = 0
    if velocity.y == 0:
        $AnimatedSprite2D.speed_scale = 1

    var direction := Input.get_axis("left", "right")
    if direction:
        $AnimatedSprite2D.animation = "walk"
        if Input.is_action_pressed("left"):
            $AnimatedSprite2D.flip_h = true
        else:
            $AnimatedSprite2D.flip_h = false
        velocity.x = direction * SPEED
    else:
        $AnimatedSprite2D.animation = "idle"
        velocity.x = move_toward(velocity.x, 0, SPEED * 2)
        
    if ladder_stack >= 1:
        velocity.y = 0 
        $AnimatedSprite2D.animation = "climb"
        if Input.is_action_pressed("up"):
            $AnimatedSprite2D.speed_scale = 1
            velocity.y = -50
        elif Input.is_action_pressed("down"):
            $AnimatedSprite2D.speed_scale = -1
            velocity.y = 50
        else:
            $AnimatedSprite2D.speed_scale = 0 
        
    move_and_slide()
    
func _on_ladder_entered():
    ladder_stack += 1

func _on_ladder_exited():
    ladder_stack -= 1
