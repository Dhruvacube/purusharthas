class_name CivilisationHUD
extends Control

@onready var info_label: Label = $InfoPanel/Label

func _ready() -> void:
	EventBus.decade_changed.connect(_on_decade_changed)
	_update_display()

func _on_decade_changed(decade: int, era: String) -> void:
	_update_display()

func _update_display() -> void:
	var state = GlobalState.civilisation_state
	var turn = state.get("turn_number", 0)
	var civs = state.get("hexes", []).size()
	info_label.text = "Civilisation Layer (Kama)\nTurn: %d\nHexes Controlled: %d" % [turn, civs]
