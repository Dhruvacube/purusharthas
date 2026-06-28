class_name PilgrimHUD
extends Control

@onready var info_label: Label = $InfoPanel/Label

func _ready() -> void:
	EventBus.season_changed.connect(_on_season_changed)
	_update_display()

func _on_season_changed(season: String, year: int) -> void:
	_update_display()

func _update_display() -> void:
	var state = GlobalState.pilgrim_state
	var pilgrims = state.get("pilgrims_on_route", 0)
	var facilities = state.get("facilities", []).size()
	info_label.text = "Pilgrim Route (Moksha)\nPilgrims: %d\nFacilities: %d" % [pilgrims, facilities]
