## GlobalState — Shared civilisational state used by all four gameplay layers.
##
## Holds the four Purushartha axes, civilisational resources, per-layer state
## dictionaries, and an active modifiers system. Registered as the "GlobalState"
## autoload so every script can access it directly.
class_name GlobalStateClass
extends Node


#region Constants
const AXIS_MIN: float = 0.0
const AXIS_MAX: float = 100.0
const AXIS_DEFAULT: float = 50.0
const MORALE_MIN: float = 0.0
const MORALE_MAX: float = 100.0

const VALID_AXES: Array[String] = [
	"dharma", "artha", "kama", "moksha",
]

const VALID_RESOURCES: Array[String] = [
	"population", "treasury", "food", "culture", "morale",
]
#endregion


#region Purushartha Axes (0.0 – 100.0)
var _axes: Dictionary = {
	&"dharma": AXIS_DEFAULT,
	&"artha": AXIS_DEFAULT,
	&"kama": AXIS_DEFAULT,
	&"moksha": AXIS_DEFAULT,
}
#endregion


#region Civilisational Resources
var _resources: Dictionary = {
	&"population": 100,
	&"treasury": 500.0,
	&"food": 300.0,
	&"culture": 10.0,
	&"morale": 60.0,
}
#endregion


#region Per-Layer State
## Each gameplay layer populates its own dictionary at runtime.
var village_state: Dictionary = {}
var governance_state: Dictionary = {}
var civilisation_state: Dictionary = {}
var pilgrim_state: Dictionary = {}
#endregion


#region Active Modifiers
## Each modifier is a Dictionary with keys:
##   source_layer   : String
##   target_layer   : String
##   target_resource: String
##   magnitude      : float
##   duration_turns : int   (original duration)
##   remaining_turns: int
##   reason         : String
var active_modifiers: Array[Dictionary] = []
#endregion


#region Axis Methods

## Adjust one of the four Purushartha axes by [param delta], clamped to [0, 100].
## Emits [signal EventBus.axis_changed] with old and new values.
func modify_axis(axis: String, delta: float) -> void:
	var key: StringName = StringName(axis.to_lower())
	if not _axes.has(key):
		push_warning("GlobalState.modify_axis: unknown axis '%s'" % axis)
		return

	var old_value: float = _axes[key]
	var new_value: float = clampf(old_value + delta, AXIS_MIN, AXIS_MAX)
	_axes[key] = new_value

	if not is_equal_approx(old_value, new_value):
		EventBus.axis_changed.emit(axis, old_value, new_value)


## Return the current value of a Purushartha axis.
func get_axis(axis: String) -> float:
	var key: StringName = StringName(axis.to_lower())
	if not _axes.has(key):
		push_warning("GlobalState.get_axis: unknown axis '%s'" % axis)
		return 0.0
	return _axes[key]


## Calculate how balanced the four axes are.
## Returns 100.0 when all four axes are identical, lower when imbalanced.
## Uses normalised standard deviation: score = 100 * (1 - stdev / max_possible_stdev).
func get_balance_score() -> float:
	var values: Array[float] = []
	for key: StringName in _axes:
		values.append(_axes[key])

	# Mean
	var total: float = 0.0
	for v: float in values:
		total += v
	var mean: float = total / float(values.size())

	# Variance
	var sum_sq: float = 0.0
	for v: float in values:
		sum_sq += (v - mean) * (v - mean)
	var variance: float = sum_sq / float(values.size())
	var stdev: float = sqrt(variance)

	# Maximum possible stdev is 50.0 (one axis at 0, rest at 100 or vice-versa).
	var max_stdev: float = 50.0
	return clampf(100.0 * (1.0 - stdev / max_stdev), 0.0, 100.0)

#endregion


#region Resource Methods

## Modify a civilisational resource by [param delta].
## Population is kept as integer internally. Morale is clamped to [0, 100].
## Emits [signal EventBus.resource_changed].
func modify_resource(resource: String, delta: float) -> void:
	var key: StringName = StringName(resource.to_lower())
	if not _resources.has(key):
		push_warning("GlobalState.modify_resource: unknown resource '%s'" % resource)
		return

	var old_value: float = float(_resources[key])
	var new_value: float = old_value + delta

	# Special clamping rules
	if key == &"morale":
		new_value = clampf(new_value, MORALE_MIN, MORALE_MAX)
	elif key == &"population":
		new_value = maxf(new_value, 0.0)
		_resources[key] = int(new_value)
		if not is_equal_approx(old_value, float(int(new_value))):
			EventBus.resource_changed.emit(resource, old_value, float(int(new_value)))
		return
	else:
		# Treasury, food, culture can go negative (debt) but warn
		pass

	_resources[key] = new_value
	if not is_equal_approx(old_value, new_value):
		EventBus.resource_changed.emit(resource, old_value, new_value)


## Return the current value of a civilisational resource.
func get_resource(resource: String) -> float:
	var key: StringName = StringName(resource.to_lower())
	if not _resources.has(key):
		push_warning("GlobalState.get_resource: unknown resource '%s'" % resource)
		return 0.0
	return float(_resources[key])

#endregion


#region Modifier Methods

## Add a cross-layer modifier to the active list.
## Expected keys: source_layer, target_layer, target_resource, magnitude,
## duration_turns, remaining_turns, reason.
func add_modifier(modifier: Dictionary) -> void:
	# Validate required keys
	var required_keys: PackedStringArray = PackedStringArray([
		"source_layer", "target_layer", "target_resource",
		"magnitude", "duration_turns", "remaining_turns", "reason",
	])
	for key: String in required_keys:
		if not modifier.has(key):
			push_warning("GlobalState.add_modifier: missing key '%s'" % key)
			return

	active_modifiers.append(modifier.duplicate())


## Process one turn: apply each modifier's magnitude and decrement remaining_turns.
## Expired modifiers are removed afterwards.
func tick_modifiers() -> void:
	for modifier: Dictionary in active_modifiers:
		var target_resource: String = modifier.get("target_resource", "") as String
		var magnitude: float = modifier.get("magnitude", 0.0) as float

		# Apply to axis or resource
		if target_resource.to_lower() in VALID_AXES:
			modify_axis(target_resource, magnitude)
		elif target_resource.to_lower() in VALID_RESOURCES:
			modify_resource(target_resource, magnitude)
		else:
			push_warning("GlobalState.tick_modifiers: unknown target '%s'" % target_resource)

		modifier["remaining_turns"] = (modifier["remaining_turns"] as int) - 1

	remove_expired_modifiers()


## Remove modifiers whose remaining_turns have reached zero or below.
func remove_expired_modifiers() -> void:
	var kept: Array[Dictionary] = []
	for modifier: Dictionary in active_modifiers:
		if (modifier.get("remaining_turns", 0) as int) > 0:
			kept.append(modifier)
	active_modifiers = kept


## Return all active modifiers whose target_layer matches [param target_layer].
func get_active_modifiers(target_layer: String) -> Array:
	var result: Array[Dictionary] = []
	for modifier: Dictionary in active_modifiers:
		if (modifier.get("target_layer", "") as String) == target_layer:
			result.append(modifier)
	return result

#endregion


#region Serialisation

## Serialise the entire global state into a saveable Dictionary.
func to_save_data() -> Dictionary:
	return {
		"axes": _axes.duplicate(),
		"resources": _resources.duplicate(),
		"village_state": village_state.duplicate(true),
		"governance_state": governance_state.duplicate(true),
		"civilisation_state": civilisation_state.duplicate(true),
		"pilgrim_state": pilgrim_state.duplicate(true),
		"active_modifiers": active_modifiers.duplicate(true),
	}


## Restore state from a previously saved Dictionary.
func from_save_data(data: Dictionary) -> void:
	if data.has("axes"):
		var axes_data: Dictionary = data["axes"] as Dictionary
		for key: StringName in _axes:
			if axes_data.has(String(key)):
				_axes[key] = float(axes_data[String(key)])
			elif axes_data.has(key):
				_axes[key] = float(axes_data[key])

	if data.has("resources"):
		var res_data: Dictionary = data["resources"] as Dictionary
		for key: StringName in _resources:
			if res_data.has(String(key)):
				if key == &"population":
					_resources[key] = int(res_data[String(key)])
				else:
					_resources[key] = float(res_data[String(key)])
			elif res_data.has(key):
				if key == &"population":
					_resources[key] = int(res_data[key])
				else:
					_resources[key] = float(res_data[key])

	if data.has("village_state"):
		village_state = (data["village_state"] as Dictionary).duplicate(true)
	if data.has("governance_state"):
		governance_state = (data["governance_state"] as Dictionary).duplicate(true)
	if data.has("civilisation_state"):
		civilisation_state = (data["civilisation_state"] as Dictionary).duplicate(true)
	if data.has("pilgrim_state"):
		pilgrim_state = (data["pilgrim_state"] as Dictionary).duplicate(true)

	if data.has("active_modifiers"):
		active_modifiers.clear()
		for mod: Dictionary in data["active_modifiers"]:
			active_modifiers.append(mod.duplicate(true))

#endregion


#region Reset

## Reset everything to default initial state.
func reset() -> void:
	_axes = {
		&"dharma": AXIS_DEFAULT,
		&"artha": AXIS_DEFAULT,
		&"kama": AXIS_DEFAULT,
		&"moksha": AXIS_DEFAULT,
	}

	_resources = {
		&"population": 100,
		&"treasury": 500.0,
		&"food": 300.0,
		&"culture": 10.0,
		&"morale": 60.0,
	}

	village_state = {}
	governance_state = {}
	civilisation_state = {}
	pilgrim_state = {}
	active_modifiers.clear()

#endregion
