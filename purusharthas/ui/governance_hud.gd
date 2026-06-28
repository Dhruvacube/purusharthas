class_name GovernanceHUD
extends Control

@onready var advisors_label: Label = $AdvisorsPanel/AdvisorsLabel

func _ready() -> void:
	EventBus.decade_changed.connect(_on_decade_changed)
	EventBus.axis_changed.connect(_on_axis_changed)
	var council = get_tree().get_first_node_in_group("council_system")
	if council:
		council.council_updated.connect(_update_advisors_display)
		
	_update_advisors_display()

func _on_decade_changed(decade: int, era: String) -> void:
	pass

func _on_axis_changed(axis: String, old_v: float, new_v: float) -> void:
	pass


func _update_advisors_display() -> void:
	var council = get_tree().get_first_node_in_group("council_system")
	if not council:
		return
		
	var txt = "Council:\n"
	for adv in council.advisors:
		txt += "%s (%s) - Loyalty: %.1f\n" % [adv["name"], adv["title"], adv["current_loyalty"]]
	
	advisors_label.text = txt
