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
		if _get_village_resource(k) < float(cost[k]):
			return {}
			
	for k in cost.keys():
		_modify_village_resource(k, -float(cost[k]))
		
	var rewards = inv.get("rewards", {})
	for k in rewards.keys():
		var val = float(rewards[k])
		_modify_village_resource(k, val)
			
	event_completed.emit(event_id, rewards)
	return rewards

func skip_event(event_id: String) -> void:
	GlobalState.village_state["morale"] = maxf(0.0, GlobalState.village_state.get("morale", 60.0) - 2.0)
	event_completed.emit(event_id, {"morale": -2.0})

func _resource_key(resource: String) -> String:
	match resource:
		"food":
			return "food_stored"
		"culture":
			return "culture_points"
		_:
			return resource

func _get_village_resource(resource: String) -> float:
	return float(GlobalState.village_state.get(_resource_key(resource), 0.0))

func _modify_village_resource(resource: String, delta: float) -> void:
	var key := _resource_key(resource)
	var old_value := float(GlobalState.village_state.get(key, 0.0))
	var new_value := old_value + delta
	if key == "morale" or key == "trust":
		new_value = clampf(new_value, 0.0, 100.0)
	elif key == "population":
		new_value = maxf(new_value, 0.0)
	GlobalState.village_state[key] = int(new_value) if key == "population" else new_value
