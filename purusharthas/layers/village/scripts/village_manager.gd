class_name VillageManager
extends Node2D

@onready var building_system: BuildingSystem = $BuildingSystem
@onready var labor_system: LaborSystem = $LaborSystem
@onready var panchayat_system: PanchayatSystem = $PanchayatSystem
@onready var folk_event_system: FolkEventSystem = $FolkEventSystem
@onready var threat_system: ThreatSystem = $ThreatSystem
@onready var gram_swaraj: GramSwaraj = $GramSwaraj

var current_phase: String = "allocation" # 'allocation', 'production', 'event', 'resolution'

func _ready() -> void:
	if GlobalState.village_state.is_empty():
		_init_village_state()
	
	EventBus.season_changed.connect(_on_season_changed)
	
	start_season()

func _init_village_state() -> void:
	GlobalState.village_state = {
		"population": 25,
		"families": 5,
		"food_stored": 100.0,
		"gold": 50.0,
		"culture_points": 10.0,
		"morale": 60.0,
		"trust": 50.0,
		"trade_connections": 0,
		"buildings": [],
		"farm_tiles": []
	}

func start_season() -> void:
	current_phase = "allocation"

func end_season() -> void:
	current_phase = "resolution"
	
	var season_name = TurnManager.get_current_season_name()
	var production = labor_system.calculate_production(season_name)
	labor_system.apply_production(production)
	
	_consume_food()
	_process_population_growth()
	_check_famine()
	
	TurnManager.advance_season()

func get_gram_swaraj_score() -> Dictionary:
	return gram_swaraj.calculate_score()

func get_population() -> int:
	return GlobalState.village_state.get("population", 0)

func get_food_status() -> String:
	var pop = get_population()
	var food = GlobalState.village_state.get("food_stored", 0.0)
	var needed = pop * 1.5
	if food < needed * 0.5:
		return "famine"
	elif food < needed:
		return "deficit"
	elif food < needed * 2.0:
		return "sufficient"
	else:
		return "surplus"

func _on_season_changed(season_name: String, year: int) -> void:
	start_season()

func _process_population_growth() -> void:
	var status = get_food_status()
	var state = GlobalState.village_state
	var pop = state.get("population", 0)
	var morale = state.get("morale", 50.0)
	var capacity = building_system.get_total_housing_capacity()
	
	if status == "surplus" and morale > 70.0 and pop < capacity:
		state["population"] = pop + randi_range(1, 3)
	elif status == "famine" or morale < 30.0:
		state["population"] = int(max(0, pop - randi_range(1, 4)))

func _consume_food() -> void:
	var pop = get_population()
	var needed = pop * 1.5
	var state = GlobalState.village_state
	var food = state.get("food_stored", 0.0)
	
	if food >= needed:
		state["food_stored"] = food - needed
	else:
		state["food_stored"] = 0.0
		state["morale"] -= 10.0

func _check_famine() -> void:
	if get_food_status() == "famine":
		EventBus.process_cross_layer_event("village", "famine", {})
