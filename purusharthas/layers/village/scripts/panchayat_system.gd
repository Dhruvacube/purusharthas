class_name PanchayatSystem
extends Node

var panchayat_active: bool = false
var current_issues: Array = []
var history: Array = []
var issues_data: Array = []

signal panchayat_convened(issues: Array)
signal decision_made(issue_id: String, choice_id: String, outcomes: Dictionary)
signal trust_changed(old_value: float, new_value: float)

func _ready() -> void:
	_load_issues()

func _load_issues() -> void:
	var path = "res://data/events/panchayat_issues.json"
	if FileAccess.file_exists(path):
		var text = FileAccess.get_file_as_string(path)
		var json = JSON.parse_string(text)
		if json != null and typeof(json) == TYPE_ARRAY:
			issues_data = json

func check_panchayat_due() -> bool:
	return TurnManager.is_panchayat_year()

func convene_panchayat() -> void:
	panchayat_active = true
	current_issues = _select_random_issues(2)
	panchayat_convened.emit(current_issues)

func _select_random_issues(count: int) -> Array:
	if issues_data.is_empty():
		return []
	var selected = []
	var pool = issues_data.duplicate()
	pool.shuffle()
	for i in range(min(count, pool.size())):
		selected.append(pool[i])
	return selected

func present_issue(issue_index: int) -> Dictionary:
	if issue_index >= 0 and issue_index < current_issues.size():
		return current_issues[issue_index]
	return {}

func get_trust() -> float:
	return GlobalState.village_state.get("trust", 50.0)

func modify_trust(delta: float) -> void:
	var old_val = get_trust()
	var new_val = clampf(old_val + delta, 0.0, 100.0)
	GlobalState.village_state["trust"] = new_val
	if not is_equal_approx(old_val, new_val):
		trust_changed.emit(old_val, new_val)

func submit_decision(issue_id: String, choice_id: String) -> Dictionary:
	return _process_decision(issue_id, choice_id, false)

func override_decision(issue_id: String, choice_id: String) -> Dictionary:
	return _process_decision(issue_id, choice_id, true)

func _process_decision(issue_id: String, choice_id: String, was_override: bool) -> Dictionary:
	var issue = null
	for iss in current_issues:
		if iss.get("id") == issue_id:
			issue = iss
			break
			
	if issue == null:
		return {}
		
	var choice = null
	for ch in issue.get("choices", []):
		if ch.get("id") == choice_id:
			choice = ch
			break
			
	if choice == null:
		return {}
		
	var outcomes = choice.get("outcomes", {})
	
	var res_deltas = outcomes.get("resource_deltas", {})
	for res in res_deltas.keys():
		_modify_village_resource(res, float(res_deltas[res]))
		
	var trust_delta = _calculate_trust_change(choice, was_override)
	modify_trust(trust_delta)
	outcomes["final_trust_delta"] = trust_delta
	
	var axes = outcomes.get("axis_shifts", {})
	for ax in axes.keys():
		GlobalState.modify_axis(ax, float(axes[ax]))
		
	history.append({"issue_id": issue_id, "choice_id": choice_id, "was_override": was_override, "turn": TurnManager.get_current_year()})
	
	decision_made.emit(issue_id, choice_id, outcomes)
	return outcomes

func _calculate_trust_change(choice: Dictionary, was_override: bool) -> float:
	var base = float(choice.get("outcomes", {}).get("trust_delta", 0.0))
	var pop_sup = float(choice.get("popular_support", 0.5))
	if was_override:
		return base - (1.0 - pop_sup) * 10.0
	else:
		return base + pop_sup * 5.0

func _resource_key(resource: String) -> String:
	match resource:
		"food":
			return "food_stored"
		"culture":
			return "culture_points"
		_:
			return resource

func _modify_village_resource(resource: String, delta: float) -> void:
	var key := _resource_key(resource)
	var old_value := float(GlobalState.village_state.get(key, 0.0))
	var new_value := old_value + delta
	if key == "morale" or key == "trust":
		new_value = clampf(new_value, 0.0, 100.0)
	elif key == "population":
		new_value = maxf(new_value, 0.0)
	GlobalState.village_state[key] = int(new_value) if key == "population" else new_value
