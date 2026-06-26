class_name SeasonManager
extends Node

func _ready() -> void:
	EventBus.season_changed.connect(_on_season_changed)

func _on_season_changed(season_name: String, year: int) -> void:
	pass
