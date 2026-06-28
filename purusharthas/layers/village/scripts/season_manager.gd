class_name SeasonManager
extends Node

func _ready() -> void:
	EventBus.season_changed.connect(_on_season_changed)

func _on_season_changed(_season_name: String, _year: int) -> void:
	pass
