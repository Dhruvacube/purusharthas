## EventBus — Centralized signal relay for decoupled communication.
##
## Every system emits and listens to signals through this single autoload,
## keeping inter-system coupling to zero.  Also contains the cross-layer
## propagation logic from the GDD.
class_name EventBusClass
extends Node


#region Layer Events
signal village_event(event_type: String, data: Dictionary)
signal governance_event(event_type: String, data: Dictionary)
signal civilisation_event(event_type: String, data: Dictionary)
signal pilgrim_event(event_type: String, data: Dictionary)
#endregion


#region Time Signals
signal season_changed(season_name: String, year: int)
signal decade_changed(decade: int, era: String)
signal year_changed(year: int)
#endregion


#region State Signals
signal axis_changed(axis_name: String, old_value: float, new_value: float)
signal resource_changed(resource_name: String, old_value: float, new_value: float)
#endregion


#region UI Signals
signal notification(title: String, message: String, severity: String)
signal show_event_card(event_data: Dictionary)
signal layer_switched(from_layer: String, to_layer: String)
#endregion


#region Game Flow Signals
signal game_started()
signal game_paused()
signal game_resumed()
signal game_saved()
signal game_loaded()
#endregion


#region Cross-Layer Signal
signal cross_layer_effect(source_layer: String, target_layer: String, effect_type: String, data: Dictionary)
#endregion


#region Cross-Layer Helpers

## Convenience method: emit the cross_layer_effect signal AND register a modifier
## on GlobalState in one call.
## [param data] may contain optional keys used by process_cross_layer_event:
##   target_resource, magnitude, duration_turns, reason.
func emit_cross_layer_effect(source: String, target: String, effect_type: String, data: Dictionary) -> void:
	cross_layer_effect.emit(source, target, effect_type, data)

	# If the caller provided enough info, register a modifier automatically.
	if data.has("target_resource") and data.has("magnitude") and data.has("duration_turns"):
		var modifier: Dictionary = {
			"source_layer": source,
			"target_layer": target,
			"target_resource": data["target_resource"],
			"magnitude": data["magnitude"],
			"duration_turns": data["duration_turns"],
			"remaining_turns": data.get("remaining_turns", data["duration_turns"]),
			"reason": data.get("reason", "%s -> %s : %s" % [source, target, effect_type]),
		}
		GlobalState.add_modifier(modifier)

#endregion


#region Cross-Layer Propagation Rules (GDD)

## Process a major event from [param source_layer] and propagate its effects to
## every other layer according to the GDD's cross-layer rules.
##
## Recognised event_type strings:
##   "village_famine", "governance_temple_tax_exemption",
##   "civilisation_expansion", "pilgrim_tirtha_achieved",
##   "village_panchayat_revolt"
func process_cross_layer_event(source_layer: String, event_type: String, data: Dictionary) -> void:
	match event_type:
		"village_famine":
			_propagate_village_famine(data)
		"governance_temple_tax_exemption":
			_propagate_governance_temple_tax_exemption(data)
		"civilisation_expansion":
			_propagate_civilisation_expansion(data)
		"pilgrim_tirtha_achieved":
			_propagate_pilgrim_tirtha_achieved(data)
		"village_panchayat_revolt":
			_propagate_village_panchayat_revolt(data)
		_:
			push_warning("EventBus.process_cross_layer_event: unrecognised event '%s' from '%s'" % [event_type, source_layer])

# ── Individual propagation methods ──────────────────────────────────────────

## Village famine -> tax drop in governance, pilgrim drop on route, expansion slow in civ.
func _propagate_village_famine(data: Dictionary) -> void:
	var severity: float = float(data.get("severity", 1.0))

	emit_cross_layer_effect("village", "governance", "famine_tax_drop", {
		"target_resource": "treasury",
		"magnitude": -20.0 * severity,
		"duration_turns": 3,
		"reason": "Village famine reduces tax collection",
	})

	emit_cross_layer_effect("village", "pilgrim", "famine_pilgrim_drop", {
		"target_resource": "morale",
		"magnitude": -10.0 * severity,
		"duration_turns": 2,
		"reason": "Famine reduces pilgrim traffic on route",
	})

	emit_cross_layer_effect("village", "civilisation", "famine_expansion_slow", {
		"target_resource": "culture",
		"magnitude": -5.0 * severity,
		"duration_turns": 4,
		"reason": "Famine slows civilisational expansion",
	})

	notification.emit(
		"Famine Spreads",
		"A village famine is affecting governance revenue, pilgrim routes, and civilisational growth.",
		"warning",
	)


## Governance temple tax exemption -> route donations surge, village temple
## upkeep free, culture rise in civ.
func _propagate_governance_temple_tax_exemption(data: Dictionary) -> void:
	emit_cross_layer_effect("governance", "pilgrim", "temple_tax_donations_surge", {
		"target_resource": "treasury",
		"magnitude": 15.0,
		"duration_turns": 4,
		"reason": "Temple tax exemption increases route donations",
	})

	emit_cross_layer_effect("governance", "village", "temple_upkeep_free", {
		"target_resource": "treasury",
		"magnitude": 10.0,
		"duration_turns": 4,
		"reason": "Temple upkeep subsidised by governance exemption",
	})

	emit_cross_layer_effect("governance", "civilisation", "temple_culture_rise", {
		"target_resource": "culture",
		"magnitude": 8.0,
		"duration_turns": 5,
		"reason": "Temple patronage enriches civilisational culture",
	})

	notification.emit(
		"Temple Tax Exemption",
		"Governance grants temple tax exemptions, boosting donations, village upkeep, and culture.",
		"info",
	)


## Civilisation expands to new region -> new trade goods in village, new
## destinations on route, new province in governance.
func _propagate_civilisation_expansion(data: Dictionary) -> void:
	var region_name: String = data.get("region_name", "Unknown Region") as String

	emit_cross_layer_effect("civilisation", "village", "expansion_trade_goods", {
		"target_resource": "treasury",
		"magnitude": 12.0,
		"duration_turns": 6,
		"reason": "New trade goods from %s" % region_name,
	})

	emit_cross_layer_effect("civilisation", "pilgrim", "expansion_new_destinations", {
		"target_resource": "culture",
		"magnitude": 5.0,
		"duration_turns": 4,
		"reason": "New pilgrimage destinations in %s" % region_name,
	})

	emit_cross_layer_effect("civilisation", "governance", "expansion_new_province", {
		"target_resource": "artha",
		"magnitude": 3.0,
		"duration_turns": 5,
		"reason": "New province %s added to governance" % region_name,
	})

	notification.emit(
		"Civilisation Expands",
		"Expansion into %s brings new trade, pilgrim destinations, and a province to govern." % region_name,
		"info",
	)


## Pilgrim route achieves Tirtha -> village morale permanent boost, governance
## Dharma rise, civ sacred architecture unlock.
func _propagate_pilgrim_tirtha_achieved(data: Dictionary) -> void:
	var tirtha_name: String = data.get("tirtha_name", "Unknown Tirtha") as String

	# Permanent boost → very long duration
	emit_cross_layer_effect("pilgrim", "village", "tirtha_morale_boost", {
		"target_resource": "morale",
		"magnitude": 2.0,
		"duration_turns": 100,
		"reason": "Tirtha %s grants lasting morale to villages" % tirtha_name,
	})

	emit_cross_layer_effect("pilgrim", "governance", "tirtha_dharma_rise", {
		"target_resource": "dharma",
		"magnitude": 5.0,
		"duration_turns": 6,
		"reason": "Tirtha %s elevates Dharma in governance" % tirtha_name,
	})

	emit_cross_layer_effect("pilgrim", "civilisation", "tirtha_sacred_architecture", {
		"target_resource": "culture",
		"magnitude": 10.0,
		"duration_turns": 8,
		"reason": "Sacred architecture unlocked by Tirtha %s" % tirtha_name,
	})

	notification.emit(
		"Tirtha Achieved!",
		"The pilgrim route has reached %s — morale, Dharma, and culture soar." % tirtha_name,
		"positive",
	)


## Village Panchayat revolt -> governance Artha drop, civ regional instability,
## route pilgrim drop.
func _propagate_village_panchayat_revolt(data: Dictionary) -> void:
	var intensity: float = float(data.get("intensity", 1.0))

	emit_cross_layer_effect("village", "governance", "revolt_artha_drop", {
		"target_resource": "artha",
		"magnitude": -8.0 * intensity,
		"duration_turns": 3,
		"reason": "Panchayat revolt destabilises governance wealth",
	})

	emit_cross_layer_effect("village", "civilisation", "revolt_regional_instability", {
		"target_resource": "morale",
		"magnitude": -6.0 * intensity,
		"duration_turns": 4,
		"reason": "Regional instability from Panchayat revolt",
	})

	emit_cross_layer_effect("village", "pilgrim", "revolt_pilgrim_drop", {
		"target_resource": "morale",
		"magnitude": -5.0 * intensity,
		"duration_turns": 2,
		"reason": "Unrest deters pilgrims on the route",
	})

	notification.emit(
		"Panchayat Revolt!",
		"A village Panchayat revolt shakes governance, civilisation stability, and pilgrim traffic.",
		"danger",
	)

#endregion
