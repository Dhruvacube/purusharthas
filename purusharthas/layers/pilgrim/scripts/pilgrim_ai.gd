class_name PilgrimAI
extends Node

func process_turn() -> void:
	var state = GlobalState.pilgrim_state
	# Pilgrims generate Dharma and Moksha over time
	var moksha = GlobalState.get_axis("moksha")
	state["pilgrims_on_route"] = int(100 + (moksha * 2.0))
