class_name DynastySystem
extends Node

var dynasties: Dictionary = {}

func _ready() -> void:
	_load_dynasties()

func _load_dynasties() -> void:
	var path = "res://data/dynasties/dynasty_definitions.json"
	if FileAccess.file_exists(path):
		var text = FileAccess.get_file_as_string(path)
		var json = JSON.parse_string(text)
		if typeof(json) == TYPE_ARRAY:
			for dyn in json:
				dynasties[dyn["id"]] = dyn

func get_dynasty(id: String) -> Dictionary:
	return dynasties.get(id, {})
