## GameManager — Top-level game orchestrator.
##
## Tracks the active gameplay layer, overall game state, and handles layer
## switching with scene management.  Registered as the "GameManager" autoload.
class_name GameManagerClass
extends Node


#region Enums
enum GameState {
	MENU,
	PLAYING,
	PAUSED,
	EVENT,
	GAME_OVER,
}

enum Layer {
	VILLAGE,
	GOVERNANCE,
	CIVILISATION,
	PILGRIM,
}
#endregion


#region Constants
const LAYER_NAMES: Dictionary = {
	Layer.VILLAGE: "Village",
	Layer.GOVERNANCE: "Governance",
	Layer.CIVILISATION: "Civilisation",
	Layer.PILGRIM: "Pilgrim",
}

const VILLAGE_SCENE: String = "res://layers/village/scenes/village_layer.tscn"
const GOVERNANCE_SCENE: String = "res://layers/governance/scenes/governance_layer.tscn"
const CIVILISATION_SCENE: String = "res://layers/civilisation/scenes/civilisation_layer.tscn"
const PILGRIM_SCENE: String = "res://layers/pilgrim/scenes/pilgrim_layer.tscn"

const LAYER_SCENE_PATHS: Dictionary = {
	Layer.VILLAGE: VILLAGE_SCENE,
	Layer.GOVERNANCE: GOVERNANCE_SCENE,
	Layer.CIVILISATION: CIVILISATION_SCENE,
	Layer.PILGRIM: PILGRIM_SCENE,
}
#endregion


#region State
var current_state: GameState = GameState.MENU
var current_layer: Layer = Layer.VILLAGE

## Holds the instantiated layer scene root nodes, keyed by Layer enum value.
## null means the layer is not currently loaded.
var _layer_instances: Dictionary = {}

## Progression thresholds for unlocking layers.
## Village is always unlocked; others require minimum year offsets or axis values.
var _layer_unlock_rules: Dictionary = {
	Layer.VILLAGE: {"always": true},
	Layer.GOVERNANCE: {"min_years_elapsed": 10},
	Layer.CIVILISATION: {"min_years_elapsed": 30},
	Layer.PILGRIM: {"min_years_elapsed": 5},
}
#endregion


#region Lifecycle

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

#endregion


#region Public API — Game Flow

## Initialise a brand-new game session.
func start_new_game() -> void:
	GlobalState.reset()
	TurnManager.from_save_data({"start_year": -321, "current_year": -321})
	TurnManager.resume()
	get_tree().paused = false

	_unload_all_layers()
	current_state = GameState.PLAYING
	current_layer = Layer.VILLAGE
	_load_layer(Layer.VILLAGE)

	EventBus.game_started.emit()
	EventBus.notification.emit(
		"Welcome",
		"A new civilisation begins in %s." % TurnManager.get_current_year_display(),
		"info",
	)


## Load a saved game and restore the active gameplay scene.
func load_saved_game(is_autosave: bool = false, slot: int = 1) -> bool:
	var loaded := SaveSystem.load_game(is_autosave, slot)
	if not loaded:
		EventBus.notification.emit(
			"Load Failed",
			"No saved game was found.",
			"warning",
		)
		return false

	TurnManager.resume()
	get_tree().paused = false
	_unload_all_layers()
	current_state = GameState.PLAYING
	current_layer = Layer.VILLAGE
	_load_layer(Layer.VILLAGE)
	return true


## Pause the game.  Time stops advancing; the EVENT state is handled separately.
func pause_game() -> void:
	if current_state != GameState.PLAYING:
		return
	current_state = GameState.PAUSED
	TurnManager.pause()
	get_tree().paused = true
	EventBus.game_paused.emit()


## Resume the game from paused state.
func resume_game() -> void:
	if current_state != GameState.PAUSED:
		return
	current_state = GameState.PLAYING
	TurnManager.resume()
	get_tree().paused = false
	EventBus.game_resumed.emit()


## Show an event card overlay.  Pauses gameplay while the event is displayed.
func show_event(event_data: Dictionary) -> void:
	if current_state == GameState.PLAYING:
		current_state = GameState.EVENT
		TurnManager.pause()
		get_tree().paused = true
	EventBus.show_event_card.emit(event_data)


## Called after the player dismisses an event card — returns to PLAYING.
func dismiss_event() -> void:
	if current_state != GameState.EVENT:
		return
	current_state = GameState.PLAYING
	TurnManager.resume()
	get_tree().paused = false


## Return to the main menu, unloading all layers.
func quit_to_menu() -> void:
	_unload_all_layers()
	current_state = GameState.MENU
	TurnManager.pause()
	get_tree().paused = false
	EventBus.main_menu_opened.emit()

#endregion


#region Public API — Layer Switching

## Switch the active gameplay layer.
## Hides the current layer scene and shows (or loads) the target one.
## Emits [signal EventBus.layer_switched].
func switch_to_layer(layer: int) -> void:
	if current_state != GameState.PLAYING:
		push_warning("GameManager.switch_to_layer: cannot switch while state is %s" % GameState.keys()[current_state])
		return

	var target_layer: Layer = layer as Layer
	if not is_layer_unlocked(target_layer):
		EventBus.notification.emit(
			"Layer Locked",
			"%s layer is not yet unlocked." % get_layer_name(target_layer),
			"warning",
		)
		return

	var from_name: String = get_current_layer_name()

	# Hide current layer
	_set_layer_visible(current_layer, false)

	# Load target if needed, then show
	if not _layer_instances.has(target_layer):
		_load_layer(target_layer)
	_set_layer_visible(target_layer, true)

	current_layer = target_layer
	EventBus.layer_switched.emit(from_name, get_current_layer_name())


## Return the display name of the currently active layer.
func get_current_layer_name() -> String:
	return LAYER_NAMES.get(current_layer, "Unknown") as String


## Return the display name of any layer.
func get_layer_name(layer: int) -> String:
	return LAYER_NAMES.get(layer, "Unknown") as String


## Check whether a layer is unlocked based on progression rules.
func is_layer_unlocked(layer: int) -> bool:
	var target_layer: Layer = layer as Layer
	var rules: Dictionary = _layer_unlock_rules.get(target_layer, {}) as Dictionary

	if rules.get("always", false):
		return true

	# Time-based unlock
	if rules.has("min_years_elapsed"):
		var years_elapsed: int = TurnManager.get_current_year() - (-321)  # years since start
		if years_elapsed < (rules["min_years_elapsed"] as int):
			return false

	return true

#endregion


#region Internal — Scene Management

## Load a layer scene and add it to the scene tree.
func _load_layer(layer: Layer) -> void:
	var path: String = LAYER_SCENE_PATHS.get(layer, "") as String
	if path.is_empty():
		push_error("GameManager._load_layer: no scene path for layer %s" % Layer.keys()[layer])
		return

	if not ResourceLoader.exists(path):
		push_warning("GameManager._load_layer: scene '%s' does not exist yet (layer not implemented)" % path)
		return

	var scene: PackedScene = load(path) as PackedScene
	if scene == null:
		push_error("GameManager._load_layer: failed to load '%s'" % path)
		return

	var instance: Node = scene.instantiate()
	instance.name = "Layer_%s" % Layer.keys()[layer]
	get_tree().root.add_child.call_deferred(instance)
	_layer_instances[layer] = instance


## Show or hide a loaded layer scene.
func _set_layer_visible(layer: Layer, visible: bool) -> void:
	if not _layer_instances.has(layer):
		return
	var instance: Node = _layer_instances[layer] as Node
	if instance is CanvasItem:
		(instance as CanvasItem).visible = visible
	elif instance is Node3D:
		(instance as Node3D).visible = visible
	else:
		# Fallback: toggle process mode
		instance.process_mode = Node.PROCESS_MODE_INHERIT if visible else Node.PROCESS_MODE_DISABLED


## Unload every layer scene from the tree.
func _unload_all_layers() -> void:
	for layer: Layer in _layer_instances:
		var instance: Node = _layer_instances[layer] as Node
		if is_instance_valid(instance):
			instance.queue_free()
	_layer_instances.clear()

#endregion
