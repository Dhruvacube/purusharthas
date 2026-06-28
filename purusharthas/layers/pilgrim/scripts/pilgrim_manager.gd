class_name PilgrimManager
extends Node2D

@onready var facility_system: FacilitySystem = $FacilitySystem
@onready var staff_system: StaffSystem = $StaffSystem
@onready var pilgrim_ai: PilgrimAI = $PilgrimAI
@onready var miracle_system: MiracleSystem = $MiracleSystem

func _ready() -> void:
	EventBus.season_changed.connect(_on_season_changed)
	if GlobalState.pilgrim_state.is_empty():
		_init_pilgrim_state()

func _init_pilgrim_state() -> void:
	GlobalState.pilgrim_state = {
		"facilities": [],
		"pilgrims_on_route": 0,
		"staff": []
	}
	_load_pilgrim_route()

func _load_pilgrim_route() -> void:
	var path = "res://data/map/pilgrim_route.json"
	if FileAccess.file_exists(path):
		var text = FileAccess.get_file_as_string(path)
		var json = JSON.parse_string(text)
		if typeof(json) == TYPE_ARRAY:
			GlobalState.pilgrim_state["facilities"] = json

func _on_season_changed(season: String, year: int) -> void:
	pilgrim_ai.process_turn()
	facility_system.process_turn()
	staff_system.process_turn()
	miracle_system.process_turn()
