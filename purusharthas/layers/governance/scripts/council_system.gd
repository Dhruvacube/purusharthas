class_name CouncilSystem
extends Node

var advisors: Array = []
signal council_updated()

func _ready() -> void:
	_load_advisors()
	add_to_group("council_system")

func _load_advisors() -> void:
	var path = "res://data/characters/advisors.json"
	if FileAccess.file_exists(path):
		var text = FileAccess.get_file_as_string(path)
		var json = JSON.parse_string(text)
		if json != null and typeof(json) == TYPE_ARRAY:
			for adv in json:
				var a = adv.duplicate()
				a["current_loyalty"] = float(a.get("base_loyalty", 50.0))
				advisors.append(a)

func modify_loyalty(advisor_id: String, delta: float) -> void:
	for adv in advisors:
		if adv["id"] == advisor_id:
			adv["current_loyalty"] = clampf(adv["current_loyalty"] + delta, 0.0, 100.0)
			council_updated.emit()
			return
