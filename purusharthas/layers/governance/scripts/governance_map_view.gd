class_name GovernanceMapView
extends Node2D

var _map_texture: Texture2D

func _ready() -> void:
	position = Vector2(420, 130)
	var path := "res://assets/art/governance/ui/kingdom_map.svg"
	if ResourceLoader.exists(path):
		_map_texture = load(path) as Texture2D
	queue_redraw()

func _draw() -> void:
	var rect := Rect2(Vector2.ZERO, Vector2(720, 480))
	if _map_texture != null:
		draw_texture_rect(_map_texture, rect, false)
	else:
		draw_rect(rect, Color(0.78, 0.63, 0.34, 1.0), true)
	draw_rect(rect, Color(0.05, 0.03, 0.02, 1.0), false, 4.0)
	draw_string(ThemeDB.fallback_font, Vector2(28, 448), "Kingdom Map - prototype regional view", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(0.18, 0.03, 0.33, 1.0))
