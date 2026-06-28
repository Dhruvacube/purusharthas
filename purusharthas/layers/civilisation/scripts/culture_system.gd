class_name CultureSystem
extends Node

func process_turn() -> void:
	var state = GlobalState.civilisation_state
	for hex in state.get("hexes", []):
		# passively increase culture over time based on Kama axis
		var kama = GlobalState.get_axis("kama")
		hex["culture_level"] += (kama / 100.0) * 5.0
