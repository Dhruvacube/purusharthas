class_name FacilitySystem
extends Node

func process_turn() -> void:
	var state = GlobalState.pilgrim_state
	for facility in state.get("facilities", []):
		# Maintain facilities
		pass
