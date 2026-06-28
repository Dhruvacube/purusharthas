class_name DecadeManager
extends Node

func _ready() -> void:
	EventBus.decade_changed.connect(_on_decade_changed)

func _on_decade_changed(decade: int, era: String) -> void:
	pass
