extends Node

func _ready() -> void:
	# Add the Village HUD
	var hud_scene = load("res://ui/village_hud.tscn")
	var hud = hud_scene.instantiate()
	add_child(hud)
	
	GameManager.start_new_game()
