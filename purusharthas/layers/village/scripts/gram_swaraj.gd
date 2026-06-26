class_name GramSwaraj
extends Node

signal score_updated(new_score: Dictionary)
signal tier_changed(old_tier: String, new_tier: String)

var current_tier: String = "struggling"

func get_total_score() -> float:
	return calculate_score().get("total", 0.0)

func calculate_score() -> Dictionary:
	var food_sec = _calculate_food_security()
	var cult_vib = _calculate_cultural_vibrancy()
	var pan_trust = _calculate_panchayat_trust()
	var trade_con = _calculate_trade_connections()
	
	var total = (food_sec + cult_vib + pan_trust + trade_con) / 4.0
	
	var score = {
		"total": total,
		"food_security": food_sec,
		"cultural_vibrancy": cult_vib,
		"panchayat_trust": pan_trust,
		"trade_connections": trade_con
	}
	
	var new_t = get_score_tier_for_val(total)
	if new_t != current_tier:
		tier_changed.emit(current_tier, new_t)
		current_tier = new_t
		
	score_updated.emit(score)
	return score

func get_score_tier() -> String:
	return current_tier

func get_score_tier_for_val(val: float) -> String:
	if val <= 25.0:
		return "struggling"
	elif val <= 50.0:
		return "developing"
	elif val <= 75.0:
		return "thriving"
	else:
		return "swaraj"

func get_score_breakdown() -> Dictionary:
	return calculate_score()

func _calculate_food_security() -> float:
	var state = GlobalState.village_state
	var pop = state.get("population", 0)
	if pop <= 0:
		return 0.0
	var needed = pop * 1.5
	var stored = state.get("food_stored", 0.0)
	var ratio = stored / max(1.0, needed)
	return clampf(ratio * 50.0, 0.0, 100.0)

func _calculate_cultural_vibrancy() -> float:
	var cult = GlobalState.village_state.get("culture_points", 0.0)
	return clampf(cult * 2.0, 0.0, 100.0)

func _calculate_panchayat_trust() -> float:
	return GlobalState.village_state.get("trust", 50.0)

func _calculate_trade_connections() -> float:
	var conns = GlobalState.village_state.get("trade_connections", 0)
	return clampf(conns * 20.0, 0.0, 100.0)
