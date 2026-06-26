## SaveSystem — Persistent save / load functionality.
##
## Serialises GlobalState and TurnManager into JSON files stored under
## user://saves/.  Supports manual saves, autosaves, metadata inspection,
## and deletion.  Registered as the "SaveSystem" autoload.
class_name SaveSystemClass
extends Node


#region Constants
const SAVE_DIR: String = "user://saves/"
const AUTOSAVE_FILE: String = "autosave.json"
const MANUAL_SAVE_FILE: String = "manual_save.json"
const SAVE_VERSION: int = 1
#endregion


#region Public API

## Persist the current game state to disk.
## Returns true on success, false on failure.
func save_game(is_autosave: bool = false) -> bool:
	_ensure_save_dir()

	var file_name: String = AUTOSAVE_FILE if is_autosave else MANUAL_SAVE_FILE
	var file_path: String = SAVE_DIR + file_name

	var save_data: Dictionary = _build_save_data()
	var json_string: String = JSON.stringify(save_data, "\t")

	var file: FileAccess = FileAccess.open(file_path, FileAccess.WRITE)
	if file == null:
		push_error("SaveSystem.save_game: cannot open '%s' — %s" % [file_path, error_string(FileAccess.get_open_error())])
		return false

	file.store_string(json_string)
	file.close()

	EventBus.game_saved.emit()
	EventBus.notification.emit(
		"Game Saved",
		"Progress saved to %s." % file_name,
		"info",
	)
	return true


## Load game state from disk and restore GlobalState + TurnManager.
## Returns true on success, false on failure.
func load_game(is_autosave: bool = false) -> bool:
	var file_name: String = AUTOSAVE_FILE if is_autosave else MANUAL_SAVE_FILE
	var file_path: String = SAVE_DIR + file_name

	if not FileAccess.file_exists(file_path):
		push_warning("SaveSystem.load_game: file '%s' not found" % file_path)
		return false

	var file: FileAccess = FileAccess.open(file_path, FileAccess.READ)
	if file == null:
		push_error("SaveSystem.load_game: cannot open '%s' — %s" % [file_path, error_string(FileAccess.get_open_error())])
		return false

	var json_string: String = file.get_as_text()
	file.close()

	var parsed: Variant = JSON.parse_string(json_string)
	if parsed == null or not (parsed is Dictionary):
		push_error("SaveSystem.load_game: invalid JSON in '%s'" % file_path)
		return false

	var data: Dictionary = parsed as Dictionary

	# Version check
	var version: int = int(data.get("save_version", 0))
	if version > SAVE_VERSION:
		push_warning("SaveSystem.load_game: save version %d is newer than supported %d" % [version, SAVE_VERSION])

	_restore_save_data(data)

	EventBus.game_loaded.emit()
	EventBus.notification.emit(
		"Game Loaded",
		"Progress restored from %s." % file_name,
		"info",
	)
	return true


## Check whether a save file exists.
func has_save(is_autosave: bool = false) -> bool:
	var file_name: String = AUTOSAVE_FILE if is_autosave else MANUAL_SAVE_FILE
	return FileAccess.file_exists(SAVE_DIR + file_name)


## Delete a save file.
func delete_save(is_autosave: bool = false) -> void:
	var file_name: String = AUTOSAVE_FILE if is_autosave else MANUAL_SAVE_FILE
	var file_path: String = SAVE_DIR + file_name
	if FileAccess.file_exists(file_path):
		DirAccess.remove_absolute(file_path)


## Return save metadata without fully loading the game state.
## Returns an empty dictionary if the save doesn't exist.
func get_save_info(is_autosave: bool = false) -> Dictionary:
	var file_name: String = AUTOSAVE_FILE if is_autosave else MANUAL_SAVE_FILE
	var file_path: String = SAVE_DIR + file_name

	if not FileAccess.file_exists(file_path):
		return {}

	var file: FileAccess = FileAccess.open(file_path, FileAccess.READ)
	if file == null:
		return {}

	var json_string: String = file.get_as_text()
	file.close()

	var parsed: Variant = JSON.parse_string(json_string)
	if parsed == null or not (parsed is Dictionary):
		return {}

	var data: Dictionary = parsed as Dictionary
	var meta: Dictionary = data.get("metadata", {}) as Dictionary
	return meta

#endregion


#region Internal

## Build the complete save payload.
func _build_save_data() -> Dictionary:
	return {
		"save_version": SAVE_VERSION,
		"metadata": {
			"save_date": Time.get_datetime_string_from_system(true),
			"game_year": TurnManager.get_current_year(),
			"game_year_display": TurnManager.get_current_year_display(),
			"season": TurnManager.get_current_season_name(),
			"seasons_elapsed": TurnManager.get_seasons_elapsed(),
		},
		"global_state": GlobalState.to_save_data(),
		"turn_manager": TurnManager.to_save_data(),
	}


## Restore GlobalState and TurnManager from a loaded save dictionary.
func _restore_save_data(data: Dictionary) -> void:
	if data.has("global_state"):
		GlobalState.from_save_data(data["global_state"] as Dictionary)
	if data.has("turn_manager"):
		TurnManager.from_save_data(data["turn_manager"] as Dictionary)


## Create the save directory if it doesn't already exist.
func _ensure_save_dir() -> void:
	if not DirAccess.dir_exists_absolute(SAVE_DIR):
		var err: Error = DirAccess.make_dir_recursive_absolute(SAVE_DIR)
		if err != OK:
			push_error("SaveSystem._ensure_save_dir: failed to create '%s' — %s" % [SAVE_DIR, error_string(err)])

#endregion
