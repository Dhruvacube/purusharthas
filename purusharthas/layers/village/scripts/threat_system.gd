class_name ThreatSystem
extends Node

var threats_data: Array = []
var active_threats: Array = []
var threat_history: Array = []

signal threat_triggered(threat_data: Dictionary)
signal threat_resolved(threat_id: String, outcomes: Dictionary)
signal threat_expired(threat_id: String)

func _ready() -> void:
	_load_threats()

func _load_threats() -> void:
	var path = "res://data/events/village_threats.json"
	if FileAccess.file_exists(path):
		var text = FileAccess.get_file_as_string(path)
		var json = JSON.parse_string(text)
		if json != null and typeof(json) == TYPE_ARRAY:
			threats_data = json

func check_threats(season: String) -> Array:
	var triggered = []
	for t in threats_data:
		var ts = t.get("season", "any")
		if ts == "any" or ts.to_lower() == season.to_lower():
			if randf() < float(t.get("probability", 0.0)):
				var severity = _roll_severity(t)
				var act = {"threat_id": t.get("id"), "severity": severity, "duration": t.get("duration_seasons", 1)}
				active_threats.append(act)
				_apply_threat_effects(t, severity)
				_check_cross_layer_impact(t.get("id", ""), severity)
				var td = t.duplicate()
				td["rolled_severity"] = severity
				triggered.append(td)
				threat_triggered.emit(td)
	return triggered

func _roll_severity(threat: Dictionary) -> int:
	var sr = threat.get("severity_range", [1, 5])
	if sr.size() == 2:
		return randi_range(int(sr[0]), int(sr[1]))
	return 1

func _apply_threat_effects(threat: Dictionary, severity: int) -> void:
	var effs = threat.get("effects", {})
	for k in effs.keys():
		var val = float(effs[k]) * float(severity)
		var cur = GlobalState.village_state.get(k, 50.0)
		GlobalState.village_state[k] = cur + val

func _check_cross_layer_impact(threat_id: String, severity: int) -> void:
	if threat_id == "drought" and severity >= 4:
		EventBus.process_cross_layer_event("village", "famine", {})

func get_threat_details(threat_id: String) -> Dictionary:
	for t in threats_data:
		if t.get("id") == threat_id:
			return t
	return {}

func respond_to_threat(threat_id: String, choice_id: String) -> Dictionary:
	var t = get_threat_details(threat_id)
	if t.is_empty():
		return {}
	
	var choice = null
	for ch in t.get("choices", []):
		if ch.get("id") == choice_id:
			choice = ch
			break
			
	if choice == null:
		return {}
		
	var reqs = choice.get("requirements", {})
	for r in reqs.keys():
		if GlobalState.village_state.get(r, 0.0) < float(reqs[r]):
			return {}
			
	var outcomes = choice.get("outcomes", {})
	var prob = float(outcomes.get("probability", 1.0))
	var results = {}
	
	if randf() <= prob:
		for k in outcomes.keys():
			if k != "probability":
				var val = float(outcomes[k])
				GlobalState.village_state[k] = GlobalState.village_state.get(k, 0.0) + val
				results[k] = val
	else:
		results["failed"] = true
		
	threat_resolved.emit(threat_id, results)
	return results

func get_active_threats() -> Array:
	return active_threats

func tick_active_threats() -> void:
	var kept = []
	for at in active_threats:
		at["duration"] -= 1
		if at["duration"] > 0:
			var t = get_threat_details(at["threat_id"])
			_apply_threat_effects(t, at["severity"])
			kept.append(at)
		else:
			threat_expired.emit(at["threat_id"])
	active_threats = kept
