extends CharacterBody2D

const SPEED = 50.0;
const JUMP_VELOCITY = -75.0;
const CLIMB_SPEED = 30.0;
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

    if Input.is_action_pressed("left"):
        velocity.x = -SPEED
        if ladder_stack == 0:
            $AnimatedSprite2D.animation = "walk"
            $AnimatedSprite2D.flip_h = true
    if Input.is_action_pressed("right"):
        velocity.x = SPEED
        if ladder_stack == 0:
            $AnimatedSprite2D.animation = "walk"
            $AnimatedSprite2D.flip_h = false
    if !Input.is_action_pressed("left") and !Input.is_action_pressed("right"):
        velocity.x = move_toward(velocity.x, 0, SPEED * 2)
        
    if ladder_stack >= 1:
        velocity.y = 0 
        if Input.is_action_pressed("up"):
            $AnimatedSprite2D.animation = "climb"
            velocity.y = -CLIMB_SPEED
            $AnimatedSprite2D.speed_scale = -1
        if Input.is_action_pressed("down"):
            $AnimatedSprite2D.animation = "climb"
            velocity.y = CLIMB_SPEED
            $AnimatedSprite2D.speed_scale = 1
        if !Input.is_action_pressed("up") and !Input.is_action_pressed("down") and !Input.is_action_pressed("left") and !Input.is_action_pressed("right"):
            $AnimatedSprite2D.speed_scale = 0
        
    if velocity.x == 0 and velocity.y == 0 and ladder_stack == 0:
        $AnimatedSprite2D.animation = "idle"
        
    move_and_slide()
    
func _on_ladder_entered():
    ladder_stack += 1

func _on_ladder_exited():
    ladder_stack -= 1
