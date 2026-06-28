class_name CivilisationManager
extends Node2D

@onready var dynasty_system: DynastySystem = $DynastySystem
@onready var diplomacy_system: DiplomacySystem = $DiplomacySystem
@onready var military_system: MilitarySystem = $MilitarySystem
@onready var culture_system: CultureSystem = $CultureSystem
@onready var civ_ai: CivAI = $CivAI

func _ready() -> void:
	EventBus.decade_changed.connect(_on_decade_changed)
	if GlobalState.civilisation_state.is_empty():
		_init_civ_state()

func _init_civ_state() -> void:
	GlobalState.civilisation_state = {
		"current_era": "Classical",
		"player_dynasty": "maurya",
		"hexes": [],
		"turn_number": 0
	}
	_load_hex_map()

func _load_hex_map() -> void:
	var path = "res://data/map/subcontinent_hexes.json"
	if FileAccess.file_exists(path):
		var text = FileAccess.get_file_as_string(path)
		var json = JSON.parse_string(text)
		if typeof(json) == TYPE_ARRAY:
			GlobalState.civilisation_state["hexes"] = json

func _on_decade_changed(decade: int, era: String) -> void:
	var state = GlobalState.civilisation_state
	state["turn_number"] += 1
	
	culture_system.process_turn()
	military_system.process_turn()
	diplomacy_system.process_turn()
	civ_ai.process_turn()
	
	if state["turn_number"] % 2 == 0:
		EventBus.notification.emit("Civilisation Expanded", "Your culture continues to spread across the subcontinent.", "info")
