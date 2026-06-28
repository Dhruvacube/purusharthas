class_name GovernanceManager
extends Node2D

@onready var council_system: CouncilSystem = $CouncilSystem
@onready var decade_manager: DecadeManager = $DecadeManager
@onready var succession_system: SuccessionSystem = $SuccessionSystem
@onready var governance_event_system: GovernanceEventSystem = $GovernanceEventSystem

func _ready() -> void:
	EventBus.decade_changed.connect(_on_decade_changed)
	if GlobalState.governance_state.is_empty():
		_init_governance_state()

func _init_governance_state() -> void:
	GlobalState.governance_state = {
		"king_age": 20,
		"king_name": "Raja Ashoka",
		"dynasty": "Maurya",
		"tax_rate": 0.1,
		"reign_decades": 0,
		"stability": 50.0
	}

func _on_decade_changed(decade: int, era: String) -> void:
	var state = GlobalState.governance_state
	state["king_age"] += 10
	state["reign_decades"] += 1
	
	var village_gold = GlobalState.village_state.get("gold", 0.0)
	var tax = village_gold * state["tax_rate"]
	GlobalState.village_state["gold"] = village_gold - tax
	GlobalState.modify_resource("treasury", tax)
	
	_check_imbalances()
	
	if succession_system.check_succession():
		EventBus.notification.emit("Succession", "The Raja has grown old. A new heir must take the throne.", "info")

func _check_imbalances() -> void:
	var dharma = GlobalState.get_axis("dharma")
	var artha = GlobalState.get_axis("artha")
	var kama = GlobalState.get_axis("kama")
	var moksha = GlobalState.get_axis("moksha")
	
	if artha > 70 and dharma < 30:
		EventBus.notification.emit("Peasant Revolt", "High taxation and low righteousness have sparked a revolt!", "warning")
		GlobalState.modify_resource("morale", -20)
	
	if moksha > 70 and artha < 30:
		EventBus.notification.emit("Military Weakness", "Too much focus on the spiritual has left our borders undefended.", "warning")
		GlobalState.modify_resource("treasury", -50)
		
	if kama < 30:
		EventBus.notification.emit("Cultural Stagnation", "The arts are dying.", "info")
		GlobalState.modify_resource("culture", -5)
