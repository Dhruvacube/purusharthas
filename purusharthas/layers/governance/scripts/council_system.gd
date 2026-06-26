class_name CouncilSystem
extends Node

const ADVISORS_PATH := "res://data/characters/advisors.json"

signal advisor_loyalty_changed(advisor_id: String, old_value: float, new_value: float)

func _ready() -> void:
	if not GlobalState.governance_state.has("advisors"):
		GlobalState.governance_state["advisors"] = _load_advisors()

func get_advisors() -> Array:
	return (GlobalState.governance_state.get("advisors", []) as Array).duplicate(true)

func get_advisor(advisor_id: String) -> Dictionary:
	for advisor: Dictionary in GlobalState.governance_state.get("advisors", []):
		if advisor.get("id", "") == advisor_id:
			return advisor
	return {}

func modify_loyalty(advisor_id: String, delta: float) -> void:
	var advisors: Array = GlobalState.governance_state.get("advisors", [])
	for advisor: Dictionary in advisors:
		if advisor.get("id", "") != advisor_id:
			continue
		var old_value := float(advisor.get("loyalty", 50.0))
		var new_value := clampf(old_value + delta, 0.0, 100.0)
		advisor["loyalty"] = new_value
		if not is_equal_approx(old_value, new_value):
			advisor_loyalty_changed.emit(advisor_id, old_value, new_value)
		return

func apply_loyalty_changes(changes: Dictionary) -> void:
	for advisor_id: String in changes.keys():
		modify_loyalty(advisor_id, float(changes[advisor_id]))

func _load_advisors() -> Array:
	if not FileAccess.file_exists(ADVISORS_PATH):
		return []
	var text := FileAccess.get_file_as_string(ADVISORS_PATH)
	var parsed: Variant = JSON.parse_string(text)
	if parsed is Array:
		return (parsed as Array).duplicate(true)
	return []
