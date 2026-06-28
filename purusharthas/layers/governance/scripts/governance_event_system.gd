class_name GovernanceEventSystem
extends Node

var events_data: Array = []
signal event_triggered(event_data: Dictionary)
signal event_resolved(event_id: String, choice_id: String, outcomes: Dictionary)

func _ready() -> void:
	var path = "res://data/events/governance_events.json"
	if FileAccess.file_exists(path):
		var text = FileAccess.get_file_as_string(path)
		var json = JSON.parse_string(text)
		if json != null and typeof(json) == TYPE_ARRAY:
			events_data = json
	
	EventBus.decade_changed.connect(_on_decade_changed)

func _on_decade_changed(decade: int, era: String) -> void:
	if not events_data.is_empty():
		var ev = events_data.pick_random()
		event_triggered.emit(ev)

func resolve_event(event_id: String, choice_id: String) -> Dictionary:
	var ev = null
	for e in events_data:
		if e["id"] == event_id:
			ev = e
			break
			
	if ev == null: return {}
	var choice = null
	for ch in ev.get("choices", []):
		if ch.get("id") == choice_id:
			choice = ch
			break
			
	if choice == null: return {}
	
	var outcomes = choice.get("outcomes", {})
	
	if outcomes.has("axis_shifts"):
		var shifts = outcomes["axis_shifts"]
		for ax in shifts.keys():
			GlobalState.modify_axis(ax, float(shifts[ax]))
			
	if outcomes.has("resource_deltas"):
		var deltas = outcomes["resource_deltas"]
		for res in deltas.keys():
			GlobalState.modify_resource(res, float(deltas[res]))
			
	event_resolved.emit(event_id, choice_id, outcomes)
	
	var council = get_tree().get_first_node_in_group("council_system")
	if council:
		var supporters = choice.get("advisor_support", [])
		for adv_id in supporters:
			council.modify_loyalty(adv_id, 5.0)
		for adv in council.advisors:
			if not supporters.has(adv["id"]):
				council.modify_loyalty(adv["id"], -2.0)
	
	return outcomes
