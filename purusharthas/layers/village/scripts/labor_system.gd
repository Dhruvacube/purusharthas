class_name LaborSystem
extends Node

var allocation: Dictionary = {
	"FARMING": 0,
	"CRAFT_PRODUCTION": 0,
	"TRADE_CARAVANS": 0,
	"TEMPLE_UPKEEP": 0,
	"COMMUNITY_SERVICE": 0
}

var production_results: Dictionary = {}
var crops_data: Array = []
var crafts_data: Array = []

signal allocation_changed(category: String, new_amount: int)
signal production_completed(results: Dictionary)

func _ready() -> void:
	_load_crop_data()
	_load_craft_data()

func _load_crop_data() -> void:
	var path = "res://data/goods/crops.json"
	if FileAccess.file_exists(path):
		var text = FileAccess.get_file_as_string(path)
		var json = JSON.parse_string(text)
		if json != null and typeof(json) == TYPE_ARRAY:
			crops_data = json

func _load_craft_data() -> void:
	var path = "res://data/goods/crafts.json"
	if FileAccess.file_exists(path):
		var text = FileAccess.get_file_as_string(path)
		var json = JSON.parse_string(text)
		if json != null and typeof(json) == TYPE_ARRAY:
			crafts_data = json

func get_total_labor() -> int:
	return int(GlobalState.village_state.get("population", 0) * 0.6)

func get_allocation() -> Dictionary:
	return allocation

func set_allocation(category: String, units: int) -> bool:
	if not allocation.has(category):
		return false
	var total_req = 0
	for k in allocation.keys():
		if k == category:
			total_req += units
		else:
			total_req += allocation[k]
			
	if total_req > get_total_labor():
		return false
		
	allocation[category] = units
	allocation_changed.emit(category, units)
	return true

func get_unallocated() -> int:
	var used = 0
	for v in allocation.values():
		used += v
	return get_total_labor() - used

func auto_allocate() -> void:
	var total = get_total_labor()
	if total == 0:
		return
	var cats = allocation.keys()
	var per_cat = total / cats.size()
	var rem = total % cats.size()
	
	for i in range(cats.size()):
		var amt = per_cat
		if i < rem:
			amt += 1
		set_allocation(cats[i], amt)

func get_farming_output(labor_units: int, season: String) -> float:
	var output = 0.0
	for c in crops_data:
		if c.get("season", "").to_lower() == season.to_lower():
			output += labor_units * float(c.get("base_yield", 1.0)) * 0.5
	return output

func get_craft_output(labor_units: int) -> Dictionary:
	return {"goods": labor_units * 2.0}

func get_trade_income(labor_units: int) -> float:
	return float(labor_units * 3.0)

func calculate_production(season: String) -> Dictionary:
	var farm_out = get_farming_output(allocation["FARMING"], season)
	var craft_out = get_craft_output(allocation["CRAFT_PRODUCTION"])
	var trade_out = get_trade_income(allocation["TRADE_CARAVANS"])
	
	var cult_out = allocation["TEMPLE_UPKEEP"] * 1.5
	var morale_out = allocation["COMMUNITY_SERVICE"] * 1.0
	
	production_results = {
		"food_produced": farm_out,
		"crafts_produced": craft_out,
		"trade_income": trade_out,
		"culture_generated": cult_out,
		"morale_change": morale_out
	}
	return production_results

func apply_production(results: Dictionary) -> void:
	var s = GlobalState.village_state
	s["food_stored"] = s.get("food_stored", 0.0) + results.get("food_produced", 0.0)
	s["gold"] = s.get("gold", 0.0) + results.get("trade_income", 0.0)
	s["culture_points"] = s.get("culture_points", 0.0) + results.get("culture_generated", 0.0)
	s["morale"] = clampf(s.get("morale", 60.0) + results.get("morale_change", 0.0), 0.0, 100.0)
	production_completed.emit(results)
