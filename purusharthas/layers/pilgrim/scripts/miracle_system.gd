class_name MiracleSystem
extends Node

func process_turn() -> void:
	# Check for rare miracles
	var moksha = GlobalState.get_axis("moksha")
	if moksha > 90 and randf() < 0.05:
		EventBus.notification.emit("Miracle Occurred!", "A miracle has been witnessed on the pilgrim route, increasing Moksha.", "positive")
		GlobalState.modify_axis("moksha", 5.0)
