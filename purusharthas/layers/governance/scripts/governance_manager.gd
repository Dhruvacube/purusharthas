class_name GovernanceManager
extends Node2D

signal governance_state_changed()
signal governance_events_changed(events: Array)

const EVENTS_PATH := "res://data/events/governance_events.json"

@onready var council_system: CouncilSystem = $CouncilSystem

var events_data: Array = []
var pending_events: Array[Dictionary] = []
var _last_queued_decade: int = -1

func _ready() -> void:
	if GlobalState.governance_state.is_empty():
		_init_governance_state()
	_load_events()
	EventBus.decade_changed.connect(_on_decade_changed)
	council_system.advisor_loyalty_changed.connect(_on_advisor_loyalty_changed)
	if pending_events.is_empty():
		_queue_decade_events()
	governance_state_changed.emit()

func _init_governance_state() -> void:
	GlobalState.governance_state = {
		"reign_name": "First Reign",
		"reign_decades": 0,
		"resolved_events": [],
		"instability": 0.0,
		"legacy_history": [],
	}

func get_advisors() -> Array:
	return council_system.get_advisors()

func get_pending_events() -> Array:
	return pending_events.duplicate(true)

func get_axis_values() -> Dictionary:
	return {
		"dharma": GlobalState.get_axis("dharma"),
		"artha": GlobalState.get_axis("artha"),
		"kama": GlobalState.get_axis("kama"),
		"moksha": GlobalState.get_axis("moksha"),
	}

func get_legacy_score() -> float:
	var axes := get_axis_values()
	var total := 0.0
	for key: String in axes.keys():
		total += float(axes[key])
	return total / 4.0

func get_legacy_title() -> String:
	var axes := get_axis_values()
	var best_axis := "balanced"
	var best_value := -1.0
	for key: String in axes.keys():
		var value := float(axes[key])
		if value > best_value:
			best_axis = key
			best_value = value
	if GlobalState.get_balance_score() >= 82.0:
		return "Sarvamangala"
	match best_axis:
		"dharma":
			return "The Just"
		"artha":
			return "The Builder"
		"kama":
			return "The Patron"
		"moksha":
			return "The Ascetic"
		_:
			return "The Remembered"

func resolve_governance_event(event_id: String, choice_id: String) -> Dictionary:
	var event_index := -1
	var event_data: Dictionary = {}
	for i in range(pending_events.size()):
		if pending_events[i].get("id", "") == event_id:
			event_index = i
			event_data = pending_events[i]
			break
	if event_index == -1:
		return {}

	var choice: Dictionary = {}
	for candidate: Dictionary in event_data.get("choices", []):
		if candidate.get("id", "") == choice_id:
			choice = candidate
			break
	if choice.is_empty():
		return {}

	for axis: String in (choice.get("axis_shifts", {}) as Dictionary).keys():
		GlobalState.modify_axis(axis, float(choice["axis_shifts"][axis]))

	for resource: String in (choice.get("resource_deltas", {}) as Dictionary).keys():
		GlobalState.modify_resource(resource, float(choice["resource_deltas"][resource]))

	council_system.apply_loyalty_changes(choice.get("advisor_loyalty", {}) as Dictionary)

	if choice.has("cross_layer_event"):
		EventBus.process_cross_layer_event("governance", choice.get("cross_layer_event", ""), {})

	GlobalState.governance_state["resolved_events"].append({
		"event_id": event_id,
		"choice_id": choice_id,
		"decade": TurnManager.get_current_decade(),
	})
	pending_events.remove_at(event_index)
	_check_imbalances()
	governance_state_changed.emit()
	governance_events_changed.emit(get_pending_events())
	return choice

func force_next_decade() -> void:
	for i in range(30):
		TurnManager.advance_season()
	GlobalState.governance_state["reign_decades"] = int(GlobalState.governance_state.get("reign_decades", 0)) + 1
	_queue_decade_events()

func _load_events() -> void:
	if not FileAccess.file_exists(EVENTS_PATH):
		return
	var text := FileAccess.get_file_as_string(EVENTS_PATH)
	var parsed: Variant = JSON.parse_string(text)
	if parsed is Array:
		events_data = (parsed as Array).duplicate(true)

func _queue_decade_events() -> void:
	var decade := TurnManager.get_current_decade()
	if _last_queued_decade == decade and not pending_events.is_empty():
		return
	_last_queued_decade = decade
	var pool := events_data.duplicate(true)
	pool.shuffle()
	var count: int = min(2, pool.size())
	for i in range(count):
		pending_events.append(pool[i])
	governance_events_changed.emit(get_pending_events())

func _check_imbalances() -> void:
	var dharma := GlobalState.get_axis("dharma")
	var artha := GlobalState.get_axis("artha")
	var kama := GlobalState.get_axis("kama")
	var moksha := GlobalState.get_axis("moksha")
	if artha > 75.0 and dharma < 35.0:
		_add_instability(10.0, "Peasant unrest rises as wealth outruns justice.")
	if moksha > 75.0 and artha < 35.0:
		_add_instability(7.0, "Military readiness weakens under excessive withdrawal.")
	if kama < 28.0:
		_add_instability(6.0, "Cultural stagnation spreads through the court.")
	if dharma > 78.0 and kama < 35.0:
		_add_instability(4.0, "Rigid virtue chills public celebration.")

func _add_instability(delta: float, message: String) -> void:
	GlobalState.governance_state["instability"] = clampf(
		float(GlobalState.governance_state.get("instability", 0.0)) + delta,
		0.0,
		100.0
	)
	EventBus.notification.emit("Governance Imbalance", message, "warning")

func _on_decade_changed(_decade: int, _era: String) -> void:
	GlobalState.governance_state["reign_decades"] = int(GlobalState.governance_state.get("reign_decades", 0)) + 1
	_queue_decade_events()
	governance_state_changed.emit()

func _on_advisor_loyalty_changed(_advisor_id: String, _old_value: float, _new_value: float) -> void:
	governance_state_changed.emit()
