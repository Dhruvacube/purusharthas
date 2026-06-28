class_name VillageManager
extends Node2D

signal village_state_changed()
signal pending_cards_changed(cards: Array)
signal production_resolved(results: Dictionary)

@onready var building_system: BuildingSystem = $BuildingSystem
@onready var labor_system: LaborSystem = $LaborSystem
@onready var panchayat_system: PanchayatSystem = $PanchayatSystem
@onready var folk_event_system: FolkEventSystem = $FolkEventSystem
@onready var threat_system: ThreatSystem = $ThreatSystem
@onready var gram_swaraj: GramSwaraj = $GramSwaraj

var current_phase: String = "allocation" # 'allocation', 'production', 'event', 'resolution'
var pending_cards: Array[Dictionary] = []
var last_production_results: Dictionary = {}
var _next_card_id: int = 1
var _last_panchayat_year: int = -999999

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
		"wood": 120.0,
		"stone": 80.0,
		"culture_points": 10.0,
		"morale": 60.0,
		"trust": 50.0,
		"trade_connections": 0,
		"buildings": [],
		"farm_tiles": [],
		"map_width": 30,
		"map_height": 30
	}

func start_season() -> void:
	current_phase = "event" if not pending_cards.is_empty() else "allocation"
	village_state_changed.emit()

func end_season() -> void:
	current_phase = "resolution"
	
	var season_name = TurnManager.get_current_season_name()
	var production = labor_system.calculate_production(season_name)
	last_production_results = production.duplicate(true)
	labor_system.apply_production(production)
	production_resolved.emit(production)
	
	_consume_food()
	_process_population_growth()
	_check_famine()
	threat_system.tick_active_threats()
	_queue_threat_cards(threat_system.check_threats(season_name))
	_queue_folk_event_cards(folk_event_system.check_events(season_name))
	_queue_panchayat_cards()
	gram_swaraj.calculate_score()
	
	TurnManager.advance_season()
	current_phase = "event" if not pending_cards.is_empty() else "allocation"
	village_state_changed.emit()
	pending_cards_changed.emit(get_pending_cards())
	SaveSystem.save_game(true)

func get_gram_swaraj_score() -> Dictionary:
	return gram_swaraj.calculate_score()

func get_labor_allocation() -> Dictionary:
	return labor_system.get_allocation().duplicate()

func get_total_labor() -> int:
	return labor_system.get_total_labor()

func get_unallocated_labor() -> int:
	return labor_system.get_unallocated()

func set_labor_allocation(category: String, units: int) -> bool:
	var ok = labor_system.set_allocation(category, units)
	if ok:
		village_state_changed.emit()
	return ok

func auto_allocate_labor() -> void:
	labor_system.auto_allocate()
	village_state_changed.emit()

func get_pending_cards() -> Array:
	return pending_cards.duplicate(true)

func get_last_production_results() -> Dictionary:
	return last_production_results.duplicate(true)

func get_building_definitions() -> Dictionary:
	return building_system.get_building_definitions().duplicate(true)

func get_building_summary() -> Dictionary:
	var summary: Dictionary = {}
	for building: Dictionary in GlobalState.village_state.get("buildings", []):
		var building_id: String = building.get("building_id", "")
		summary[building_id] = int(summary.get(building_id, 0)) + 1
	return summary

func place_building_next_available(building_id: String) -> bool:
	var build_pos := _find_next_buildable_tile(building_id)
	if build_pos == Vector2i(-1, -1):
		return false
	var placed := building_system.place_building(building_id, build_pos)
	if placed:
		village_state_changed.emit()
	return placed

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

func _on_season_changed(_season_name: String, _year: int) -> void:
	start_season()

func resolve_pending_card(card_id: int, choice_id: String) -> Dictionary:
	var card_index := -1
	var card: Dictionary = {}
	for i in range(pending_cards.size()):
		if int(pending_cards[i].get("card_id", -1)) == card_id:
			card_index = i
			card = pending_cards[i]
			break
	if card_index == -1:
		return {}

	var result: Dictionary = {}
	match card.get("card_type", ""):
		"folk_event":
			if choice_id == "skip":
				folk_event_system.skip_event(card.get("source_id", ""))
				result = {"morale": -2.0}
			else:
				result = folk_event_system.invest_in_event(card.get("source_id", ""), choice_id)
		"threat":
			result = threat_system.respond_to_threat(card.get("source_id", ""), choice_id)
		"panchayat":
			var issue_id: String = card.get("source_id", "")
			if choice_id.begins_with("override:"):
				result = panchayat_system.override_decision(issue_id, choice_id.substr("override:".length()))
			else:
				result = panchayat_system.submit_decision(issue_id, choice_id)
		"notice":
			result = {"acknowledged": true}

	pending_cards.remove_at(card_index)
	current_phase = "event" if not pending_cards.is_empty() else "allocation"
	village_state_changed.emit()
	pending_cards_changed.emit(get_pending_cards())
	return result

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

func _find_next_buildable_tile(building_id: String) -> Vector2i:
	var state := GlobalState.village_state
	var width := int(state.get("map_width", 30))
	var height := int(state.get("map_height", 30))
	var center := Vector2i(int(float(width) / 2.0), int(float(height) / 2.0))
	var best_position := Vector2i(-1, -1)
	var best_distance := 999999

	for y in range(3, height - 3):
		for x in range(3, width - 3):
			var tile_pos := Vector2i(x, y)
			if not building_system.can_place_building(building_id, tile_pos):
				continue
			var distance: int = abs(tile_pos.x - center.x) + abs(tile_pos.y - center.y)
			if distance < best_distance:
				best_distance = distance
				best_position = tile_pos
	return best_position

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
		EventBus.process_cross_layer_event("village", "village_famine", {"severity": 1.0})
		_add_pending_card(
			"notice",
			"Famine Warning",
			"Food stores have fallen dangerously low. Other layers will feel the strain of this village famine.",
			"res://assets/art/ui/warning.svg",
			"famine",
			[{"id": "acknowledge", "text": "Acknowledge", "description": ""}]
		)

func _queue_folk_event_cards(events: Array) -> void:
	for event_data: Dictionary in events:
		var choices: Array[Dictionary] = []
		var levels: Dictionary = event_data.get("investment_levels", {})
		for level: String in levels.keys():
			var investment: Dictionary = levels[level]
			choices.append({
				"id": level,
				"text": "%s offering" % level.capitalize(),
				"description": _format_cost_reward(investment.get("cost", {}), investment.get("rewards", {})),
			})
		choices.append({"id": "skip", "text": "Skip festival", "description": "Morale -2"})
		_add_pending_card(
			"folk_event",
			event_data.get("name", "Village Event"),
			event_data.get("flavor_text", event_data.get("description", "")),
			"res://assets/art/ui/festival.svg",
			event_data.get("id", ""),
			choices
		)

func _queue_threat_cards(threats: Array) -> void:
	for threat_data: Dictionary in threats:
		var choices: Array[Dictionary] = []
		for choice: Dictionary in threat_data.get("choices", []):
			choices.append({
				"id": choice.get("id", ""),
				"text": choice.get("text", "Respond"),
				"description": choice.get("description", ""),
			})
		_add_pending_card(
			"threat",
			threat_data.get("name", "Threat"),
			threat_data.get("flavor_text", threat_data.get("description", "")),
			"res://assets/art/ui/threat.svg",
			threat_data.get("id", ""),
			choices
		)

func _queue_panchayat_cards() -> void:
	if not panchayat_system.check_panchayat_due():
		return
	if _last_panchayat_year == TurnManager.get_current_year():
		return
	_last_panchayat_year = TurnManager.get_current_year()
	panchayat_system.convene_panchayat()
	for issue: Dictionary in panchayat_system.current_issues:
		var choices: Array[Dictionary] = []
		for choice: Dictionary in issue.get("choices", []):
			choices.append({
				"id": choice.get("id", ""),
				"text": choice.get("text", "Advise"),
				"description": choice.get("description", ""),
			})
			choices.append({
				"id": "override:%s" % choice.get("id", ""),
				"text": "Override: %s" % choice.get("text", "Decision"),
				"description": "Force this decision. This may reduce Panchayat trust.",
			})
		_add_pending_card(
			"panchayat",
			issue.get("name", "Panchayat Issue"),
			issue.get("flavor_text", issue.get("description", "")),
			"res://assets/art/ui/panchayat.svg",
			issue.get("id", ""),
			choices
		)

func _add_pending_card(
	card_type: String,
	title: String,
	description: String,
	icon_path: String,
	source_id: String,
	choices: Array
) -> void:
	pending_cards.append({
		"card_id": _next_card_id,
		"card_type": card_type,
		"title": title,
		"description": description,
		"icon_path": icon_path,
		"source_id": source_id,
		"choices": choices,
	})
	_next_card_id += 1

func _format_cost_reward(cost: Dictionary, reward: Dictionary) -> String:
	var parts: Array[String] = []
	if not cost.is_empty():
		parts.append("Cost: %s" % _format_delta_map(cost))
	if not reward.is_empty():
		parts.append("Reward: %s" % _format_delta_map(reward))
	return " | ".join(parts)

func _format_delta_map(values: Dictionary) -> String:
	var parts: Array[String] = []
	for key: String in values.keys():
		parts.append("%s %s" % [key.capitalize(), values[key]])
	return ", ".join(parts)
