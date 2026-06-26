class_name VillageHUD
extends Control

@onready var resources_label: Label = $TopBar/HBoxContainer/ResourcesLabel
@onready var next_turn_button: Button = $BottomBar/NextTurnButton

func _ready() -> void:
	EventBus.season_changed.connect(_on_season_changed)
	EventBus.resource_changed.connect(_on_resource_changed)
	next_turn_button.pressed.connect(_on_next_turn_pressed)
	_update_resources()

func _update_resources() -> void:
	var pop = GlobalState.village_state.get("population", 0)
	var food = GlobalState.village_state.get("food_stored", 0.0)
	var gold = GlobalState.village_state.get("gold", 0.0)
	var season = TurnManager.get_current_season_name()
	var year = TurnManager.get_current_year_display()
	resources_label.text = "%s - %s | Pop: %d | Food: %.1f | Gold: %.1f" % [year, season, pop, food, gold]

func _on_resource_changed(res_name: String, old_val: float, new_val: float) -> void:
	_update_resources()

func _on_season_changed(season_name: String, year: int) -> void:
	_update_resources()

func _on_next_turn_pressed() -> void:
	var vm = get_tree().get_first_node_in_group("village_manager")
	if vm and vm.has_method("end_season"):
		vm.end_season()
	else:
		TurnManager.advance_season()
