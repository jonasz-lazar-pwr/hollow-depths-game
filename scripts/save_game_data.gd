# res://scripts/save_game_data.gd
class_name SaveGameData extends Resource

# Use @export so Godot knows how to save/load these variables
@export var save_format_version: float = 1.0
@export var player_data: Dictionary = {}  # Will store player pos, hp, inventory resource
@export var world_data: Dictionary = {}   # Will store tilemap state, ladder positions
