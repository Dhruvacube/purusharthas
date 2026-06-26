extends Node

const MAIN_MENU_SCENE := preload("res://ui/screens/main_menu.tscn")
const VILLAGE_HUD_SCENE := preload("res://ui/village_hud.tscn")

var _main_menu: Control
var _hud: Control

func _ready() -> void:
	EventBus.game_started.connect(_on_game_started)
	EventBus.game_loaded.connect(_on_game_loaded)
	EventBus.main_menu_opened.connect(_on_main_menu_opened)
	_show_main_menu()

func _show_main_menu() -> void:
	if _main_menu == null:
		_main_menu = MAIN_MENU_SCENE.instantiate() as Control
		add_child(_main_menu)
	_main_menu.visible = true

func _hide_main_menu() -> void:
	if _main_menu != null:
		_main_menu.visible = false

func _ensure_hud() -> void:
	if _hud == null:
		_hud = VILLAGE_HUD_SCENE.instantiate() as Control
		add_child(_hud)
	_hud.visible = true

func _remove_hud() -> void:
	if _hud != null:
		_hud.queue_free()
		_hud = null

func _on_game_started() -> void:
	_hide_main_menu()
	_ensure_hud()

func _on_game_loaded() -> void:
	_hide_main_menu()
	_ensure_hud()

func _on_main_menu_opened() -> void:
	_remove_hud()
	_show_main_menu()
