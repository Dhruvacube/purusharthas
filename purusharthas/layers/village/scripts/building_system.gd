class_name BuildingSystem
extends Node

var building_definitions: Dictionary = {}

signal building_placed(building_id: String, position: Vector2i)
signal building_upgraded(building_index: int, new_tier: int)
signal building_removed(building_index: int)

func _ready() -> void:
	_load_building_data()

func _load_building_data() -> void:
	var path = "res://data/buildings/village_buildings.json"
	if FileAccess.file_exists(path):
		var file = FileAccess.open(path, FileAccess.READ)
		var text = file.get_as_text()
		var json = JSON.parse_string(text)
		if json != null and typeof(json) == TYPE_DICTIONARY:
			building_definitions = json

func can_place_building(building_id: String, position: Vector2i) -> bool:
	if not building_definitions.has(building_id):
		return false
	
	var bdef = building_definitions[building_id]
	if not _is_footprint_clear(position, _tile_size_for(bdef)):
		return false

	var state = GlobalState.village_state
	
	if state.get("population", 0) < bdef.get("required_population", 0):
		return false
		
	var costs = bdef.get("cost", {})
	for res in costs.keys():
		if _get_village_resource(res) < float(costs[res]):
			return false
			
	return true

func place_building(building_id: String, position: Vector2i) -> bool:
	if not can_place_building(building_id, position):
		return false
		
	var bdef = building_definitions[building_id]
	var state = GlobalState.village_state
	
	var costs = bdef.get("cost", {})
	for res in costs.keys():
		_modify_village_resource(res, -float(costs[res]))
		
	var new_building = {
		"building_id": building_id,
		"position": {"x": position.x, "y": position.y},
		"tier": 1,
		"built_season": TurnManager.get_current_year() * 3 + TurnManager.get_current_season()
	}
	
	if not state.has("buildings"):
		state["buildings"] = []
	state["buildings"].append(new_building)
	building_placed.emit(building_id, position)
	return true

func upgrade_building(building_index: int) -> bool:
	var state = GlobalState.village_state
	if not state.has("buildings") or building_index < 0 or building_index >= state["buildings"].size():
		return false
		
	var b_data = state["buildings"][building_index]
	var bdef = building_definitions.get(b_data["building_id"], {})
	
	if b_data["tier"] >= bdef.get("max_tier", 1):
		return false
		
	var multiplier = bdef.get("upgrade_cost_multiplier", 2.0)
	var base_costs = bdef.get("cost", {})
	var upgrade_costs = {}
	for k in base_costs.keys():
		upgrade_costs[k] = base_costs[k] * multiplier
		
	for res in upgrade_costs.keys():
		if _get_village_resource(res) < float(upgrade_costs[res]):
			return false
			
	for res in upgrade_costs.keys():
		_modify_village_resource(res, -float(upgrade_costs[res]))
		
	b_data["tier"] += 1
	building_upgraded.emit(building_index, b_data["tier"])
	return true

func remove_building(building_index: int) -> void:
	var state = GlobalState.village_state
	if state.has("buildings") and building_index >= 0 and building_index < state["buildings"].size():
		state["buildings"].remove_at(building_index)
		building_removed.emit(building_index)

func get_building_at(position: Vector2i) -> Dictionary:
	var state = GlobalState.village_state
	for b in state.get("buildings", []):
		var bdef: Dictionary = building_definitions.get(b["building_id"], {})
		var tile_size := _tile_size_for(bdef)
		var origin := Vector2i(int(b["position"]["x"]), int(b["position"]["y"]))
		var rect := Rect2i(origin, tile_size)
		if rect.has_point(position):
			return b
	return {}

func get_buildings_by_type(building_id: String) -> Array:
	var res = []
	var state = GlobalState.village_state
	for b in state.get("buildings", []):
		if b["building_id"] == building_id:
			res.append(b)
	return res

func get_total_housing_capacity() -> int:
	var total = 0
	var state = GlobalState.village_state
	for b in state.get("buildings", []):
		var bdef = building_definitions.get(b["building_id"], {})
		if bdef.get("category", "") == "housing":
			total += int(bdef.get("capacity", 0) * (1.0 + (b["tier"]-1)*0.5))
	return total

func get_total_effects() -> Dictionary:
	var total_eff = {}
	var state = GlobalState.village_state
	for b in state.get("buildings", []):
		var bdef = building_definitions.get(b["building_id"], {})
		var effs = bdef.get("effects", {})
		for k in effs.keys():
			total_eff[k] = total_eff.get(k, 0.0) + float(effs[k]) * b["tier"]
	return total_eff

func get_building_definitions() -> Dictionary:
	return building_definitions

func _is_footprint_clear(position: Vector2i, tile_size: Vector2i) -> bool:
	var state := GlobalState.village_state
	var width := int(state.get("map_width", 30))
	var height := int(state.get("map_height", 30))
	if position.x < 0 or position.y < 0:
		return false
	if position.x + tile_size.x > width or position.y + tile_size.y > height:
		return false
	for y in range(position.y, position.y + tile_size.y):
		for x in range(position.x, position.x + tile_size.x):
			if not get_building_at(Vector2i(x, y)).is_empty():
				return false
	return true

func _tile_size_for(definition: Dictionary) -> Vector2i:
	var raw: Array = definition.get("tile_size", [1, 1])
	if raw.size() >= 2:
		return Vector2i(int(raw[0]), int(raw[1]))
	return Vector2i.ONE

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
