class_name SuccessionSystem
extends Node

func check_succession() -> bool:
	var state = GlobalState.governance_state
	if state.get("king_age", 20) >= 60:
		state["king_age"] = 20
		state["reign_decades"] = 0
		return true
	return false
