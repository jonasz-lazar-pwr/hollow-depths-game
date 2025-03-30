extends CharacterBody2D

const SPEED = 50.0
const JUMP_VELOCITY = -75.0
const CLIMB_SPEED = 30.0
const DIG_REACH = 1 

var ladder_stack = 0

@export var ground_tilemap: TileMapLayer
const TILE_SIZE = 16 # Upewnij się, że to poprawny rozmiar kafelka

func _ready() -> void:
    if not ground_tilemap:
        printerr("Player: Ground TileMapLayer not assigned!")
        
    for ladder in get_tree().get_nodes_in_group("ladders"):
        ladder.entered_ladder.connect(_on_ladder_entered)
        ladder.exited_ladder.connect(_on_ladder_exited)

func _input(event: InputEvent) -> void:
    if event.is_action_pressed("dig"): 
        handle_digging()

func _physics_process(delta: float) -> void:
    if not is_on_floor() and ladder_stack == 0:
        velocity += get_gravity() * delta / 6

    if Input.is_action_just_pressed("jump") and is_on_floor():
        velocity.y = JUMP_VELOCITY

    var direction_x = Input.get_axis("left", "right")
    if direction_x:
        velocity.x = direction_x * SPEED
    else:
        velocity.x = move_toward(velocity.x, 0, SPEED)

    if ladder_stack >= 1:
        set_collision_mask_value(1, false) # Wyłącz kolizję ze światem na drabinie
        velocity.y = 0
        var direction_y = Input.get_axis("up", "down")
        velocity.y = direction_y * CLIMB_SPEED
        
        if direction_y != 0 or direction_x != 0: 
            $AnimatedSprite2D.animation = "climb"
            $AnimatedSprite2D.play()
            $AnimatedSprite2D.speed_scale = 1 
        else:
            $AnimatedSprite2D.animation = "climb" 
            $AnimatedSprite2D.pause()
            $AnimatedSprite2D.frame = 0 # Ustaw na pierwszą klatkę animacji wspinania
            
        if direction_x != 0:
             $AnimatedSprite2D.flip_h = direction_x < 0
             
    else:
        set_collision_mask_value(1, true) # Włącz kolizję ze światem
        if is_on_floor():
            if direction_x != 0:
                $AnimatedSprite2D.animation = "walk"
                $AnimatedSprite2D.flip_h = direction_x < 0
                $AnimatedSprite2D.play()
            else:
                $AnimatedSprite2D.animation = "idle"
                $AnimatedSprite2D.play()
        else:
            $AnimatedSprite2D.animation = "idle"
            $AnimatedSprite2D.play()

    move_and_slide()

func handle_digging():
    if not ground_tilemap: return
    var mouse_pos = get_global_mouse_position()
    var target_map_coords = ground_tilemap.local_to_map(mouse_pos)
    var player_map_coords = ground_tilemap.local_to_map(global_position) # Użyj global_position

    # 4. Sprawdź odległość/sąsiedztwo
    # Oblicz różnicę w koordynatach X i Y
    var dx = abs(target_map_coords.x - player_map_coords.x)
    var dy = abs(target_map_coords.y - player_map_coords.y)

    # Sprawdź, czy kafelek jest w zasięgu (np. w kwadracie 5x5 wokół gracza dla DIG_REACH=2)
    if dx <= DIG_REACH and dy <= DIG_REACH:
        var tile_data = ground_tilemap.get_cell_tile_data(target_map_coords)
        if tile_data:
            var is_diggable = tile_data.get_custom_data("diggable")
            if is_diggable: 
                print("Digging tile at map coordinates: ", target_map_coords)
                var specific_dig_time = tile_data.get_custom_data("dig_time")
                if specific_dig_time > 0:
                    $AnimatedSprite2D.flip_h = mouse_pos.x < player_map_coords.x
                    $AnimatedSprite2D.animation = "dig"
                    # Usuń kafelek
                    ground_tilemap.set_cell(target_map_coords, -1) 
            else:
                print("Tile at ", target_map_coords, " is not diggable.")
        else:
            print("No tile to dig at map coordinates: ", target_map_coords)
    else:
        print("Target tile at ", target_map_coords, " is too far from player at ", player_map_coords)

func _on_ladder_entered():
    ladder_stack += 1

func _on_ladder_exited():
    ladder_stack -= 1
    if ladder_stack < 0: ladder_stack = 0
