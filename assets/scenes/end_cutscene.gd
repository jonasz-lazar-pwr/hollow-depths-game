extends VideoStreamPlayer

const NEXT_SCENE_PATH = "res://assets/scenes/end_cutscene.tscn"
const TITLE_SCREEN_PATH = "res://assets/scenes/title_screen.tscn"

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
    finished.connect(_on_video_finished)


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
    pass
    
    
func _on_video_finished():
    # Gdy wideo się skończy, przechodzimy do następnej sceny.
    print("Final cutscene finished. Changing to title screen.")
    var error = get_tree().change_scene_to_file(TITLE_SCREEN_PATH)
    if error != OK:
        printerr("Failed to change scene to: ", TITLE_SCREEN_PATH)
    
