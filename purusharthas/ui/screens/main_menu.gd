class_name MainMenu
extends Control

const GOLD := Color(0.95, 0.68, 0.18, 1.0)
const OCHRE := Color(0.80, 0.47, 0.13, 1.0)
const INDIGO := Color(0.18, 0.03, 0.33, 1.0)
const IVORY := Color(1.0, 1.0, 0.94, 1.0)

var _manual_load_buttons: Array[Button] = []
var _autosave_button: Button
var _status_label: Label

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build_ui()
	_refresh_save_buttons()

func _build_ui() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)

	var background := ColorRect.new()
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	background.color = Color(0.07, 0.045, 0.03, 1.0)
	add_child(background)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(520, 560)
	_style_panel(panel)
	center.add_child(panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 18)
	panel.add_child(box)

	var title := Label.new()
	title.text = "Purusharthas"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 44)
	title.add_theme_color_override("font_color", INDIGO)
	box.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "Village Builder Prototype"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 18)
	subtitle.add_theme_color_override("font_color", Color(0.25, 0.16, 0.08, 1.0))
	box.add_child(subtitle)

	var divider := HSeparator.new()
	box.add_child(divider)

	var new_game := _menu_button("New Game")
	new_game.pressed.connect(_on_new_game_pressed)
	box.add_child(new_game)

	for slot in range(1, SaveSystem.MANUAL_SLOT_COUNT + 1):
		var load_button := _menu_button("Load Manual Slot %d" % slot)
		load_button.pressed.connect(_on_load_pressed.bind(false, slot))
		box.add_child(load_button)
		_manual_load_buttons.append(load_button)

	_autosave_button = _menu_button("Load Autosave")
	_autosave_button.pressed.connect(_on_load_pressed.bind(true, 1))
	box.add_child(_autosave_button)

	var quit := _menu_button("Quit")
	quit.pressed.connect(_on_quit_pressed)
	box.add_child(quit)

	_status_label = Label.new()
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status_label.add_theme_color_override("font_color", Color(0.24, 0.15, 0.08, 1.0))
	box.add_child(_status_label)

	var note := Label.new()
	note.text = "Governance, Civilisation, and Pilgrim layers unlock later."
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.add_theme_color_override("font_color", Color(0.36, 0.25, 0.14, 1.0))
	box.add_child(note)

func _style_panel(panel: PanelContainer) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = IVORY
	style.border_color = OCHRE
	style.set_border_width_all(3)
	style.set_corner_radius_all(6)
	style.set_content_margin(SIDE_LEFT, 34)
	style.set_content_margin(SIDE_TOP, 30)
	style.set_content_margin(SIDE_RIGHT, 34)
	style.set_content_margin(SIDE_BOTTOM, 30)
	panel.add_theme_stylebox_override("panel", style)

func _menu_button(text: String) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(0, 48)
	button.add_theme_font_size_override("font_size", 18)
	return button

func _refresh_save_buttons() -> void:
	var has_autosave := SaveSystem.has_save(true)
	for index in range(_manual_load_buttons.size()):
		var slot := index + 1
		_manual_load_buttons[index].disabled = not SaveSystem.has_save(false, slot)
	_autosave_button.disabled = not has_autosave

	var details: Array[String] = []
	for slot in range(1, SaveSystem.MANUAL_SLOT_COUNT + 1):
		if SaveSystem.has_save(false, slot):
			details.append("Slot %d: %s" % [slot, _format_save_info(SaveSystem.get_save_info(false, slot))])
	if has_autosave:
		details.append("Autosave: %s" % _format_save_info(SaveSystem.get_save_info(true)))
	if details.is_empty():
		_status_label.text = "No saves found yet."
	else:
		_status_label.text = "\n".join(details)

func _format_save_info(info: Dictionary) -> String:
	if info.is_empty():
		return "save available"
	return "%s, %s" % [
		info.get("game_year_display", "unknown year"),
		info.get("season", "unknown season"),
	]

func _on_new_game_pressed() -> void:
	GameManager.start_new_game()

func _on_load_pressed(is_autosave: bool, slot: int) -> void:
	var ok := GameManager.load_saved_game(is_autosave, slot)
	if not ok:
		_refresh_save_buttons()

func _on_quit_pressed() -> void:
	get_tree().quit()
