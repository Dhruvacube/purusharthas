class_name FolkEventSystem
extends Node

var events_data: Array = []

signal event_triggered(event_data: Dictionary)
signal event_completed(event_id: String, outcomes: Dictionary)

func _ready() -> void:
	_load_events()

func _load_events() -> void:
	var path = "res://data/events/village_events.json"
	if FileAccess.file_exists(path):
		var text = FileAccess.get_file_as_string(path)
		var json = JSON.parse_string(text)
		if json != null and typeof(json) == TYPE_ARRAY:
			events_data = json

func check_events(season: String) -> Array:
	var triggered = []
	for ev in events_data:
		var ev_season = ev.get("season", "any")
		if ev_season == "any" or ev_season.to_lower() == season.to_lower():
			if _check_population_requirement(ev):
				if randf() < float(ev.get("probability", 0.0)):
					triggered.append(ev)
					event_triggered.emit(ev)
	return triggered

func get_event_details(event_id: String) -> Dictionary:
	for ev in events_data:
		if ev.get("id") == event_id:
			return ev
	return {}

func _check_population_requirement(event: Dictionary) -> bool:
	return GlobalState.village_state.get("population", 0) >= event.get("min_population", 0)

func invest_in_event(event_id: String, level: String) -> Dictionary:
	var ev = get_event_details(event_id)
	if ev.is_empty():
		return {}
		
	var levels = ev.get("investment_levels", {})
	if not levels.has(level):
		return {}
		
	var inv = levels[level]
	var cost = inv.get("cost", {})
	
	for k in cost.keys():
		if GlobalState.village_state.get(k, 0.0) < cost[k]:
			return {}
			
	for k in cost.keys():
		GlobalState.village_state[k] -= cost[k]
		
	var rewards = inv.get("rewards", {})
	for k in rewards.keys():
		var val = float(rewards[k])
		if k == "morale" or k == "trust":
			GlobalState.village_state[k] = clampf(GlobalState.village_state.get(k, 0.0) + val, 0.0, 100.0)
		else:
			GlobalState.village_state[k] = GlobalState.village_state.get(k, 0.0) + val
			
	event_completed.emit(event_id, rewards)
	return rewards

func skip_event(event_id: String) -> void:
	GlobalState.village_state["morale"] = maxf(0.0, GlobalState.village_state.get("morale", 60.0) - 2.0)
	event_completed.emit(event_id, {"morale": -2.0})
