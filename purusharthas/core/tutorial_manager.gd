extends Node

var _tour_steps = [
	{
		"title": "Welcome to Purusharthas",
		"message": "You are the ruler of an ancient Indian civilisation. Your goal is not just conquest, but balance.",
	},
	{
		"title": "The Four Aims of Life",
		"message": "Look at the top right. You must balance Dharma (Duty), Artha (Wealth), Kama (Joy), and Moksha (Liberation).",
	},
	{
		"title": "Layer I: The Village (Dharma)",
		"message": "You start in the Village Layer. Assign labor, build structures, and survive the seasons to generate resources.",
	},
	{
		"title": "Layer II: Governance (Artha)",
		"message": "As you grow, you will unlock Governance. Manage your council, enact policies, and collect taxes.",
	},
	{
		"title": "Layer III: Civilisation (Kama)",
		"message": "Expand your borders on the hex map, construct grand wonders, and spread your culture.",
	},
	{
		"title": "Layer IV: Pilgrim Route (Moksha)",
		"message": "Finally, manage the spiritual journey of your people by building temples and resting places along the sacred route.",
	},
	{
		"title": "The Kathakaar",
		"message": "I am the Kathakaar, the storyteller. I will observe your reign. Keep the balance, Raja, and let the first season begin!",
	}
]

var _current_step: int = 0
var _is_tour_active: bool = false

func _ready() -> void:
	EventBus.game_started.connect(_on_game_started)

func _on_game_started() -> void:
	# Start the tour if we haven't played before, or just always for now
	_current_step = 0
	_is_tour_active = true
	_show_next_step()

func _show_next_step() -> void:
	if _current_step < _tour_steps.size():
		var step = _tour_steps[_current_step]
		# Emit notification with infinite/long duration, or we just rely on normal toast for now
		# Toasts fade out, so a tutorial modal would be better, but we will use EventBus.notification for now 
		# and simulate a tour by triggering them sequentially. 
		# Actually, since it's a tour, let's use the Notification system but make the user click to continue.
		# For now, let's just emit them one by one with a timer.
		EventBus.notification.emit(step["title"], step["message"], "info")
		_current_step += 1
		
		# Auto-advance for now, 5 seconds per step
		var timer = get_tree().create_timer(5.0)
		timer.timeout.connect(_show_next_step)
	else:
		_is_tour_active = false
