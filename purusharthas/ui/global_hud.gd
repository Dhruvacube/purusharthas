class_name GlobalHUD
extends Control

const ICONS: Dictionary = {
	"population": "res://assets/art/ui/population.svg",
	"food": "res://assets/art/ui/food.svg",
	"gold": "res://assets/art/ui/gold.svg",
	"morale": "res://assets/art/ui/morale.svg",
	"trust": "res://assets/art/ui/trust.svg",
	"culture": "res://assets/art/ui/culture.svg",
	"season_kharif": "res://assets/art/ui/season_kharif.svg",
	"season_rabi": "res://assets/art/ui/season_rabi.svg",
	"season_zaid": "res://assets/art/ui/season_zaid.svg",
	"warning": "res://assets/art/ui/warning.svg",
}

var _resource_labels: Dictionary = {}
var _time_label: Label
var _toast_container: VBoxContainer
var _save_slot_select: OptionButton

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS
	_build_ui()
	EventBus.season_changed.connect(_on_state_signal)
	EventBus.resource_changed.connect(_on_state_signal)
	EventBus.axis_changed.connect(_on_state_signal)
	EventBus.layer_switched.connect(_on_layer_switched)
	EventBus.notification.connect(_on_notification)
	call_deferred("_update_all")

func _build_ui() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)

	var root := MarginContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("margin_left", 16)
	root.add_theme_constant_override("margin_top", 14)
	root.add_theme_constant_override("margin_right", 16)
	root.add_theme_constant_override("margin_bottom", 14)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	var layout := VBoxContainer.new()
	layout.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(layout)

	# TOP BAR
	var top_bar := _build_top_bar()
	layout.add_child(top_bar)

	var fill := Control.new()
	fill.size_flags_vertical = Control.SIZE_EXPAND_FILL
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layout.add_child(fill)

	# BOTTOM BAR
	var bottom_bar := _build_bottom_bar()
	layout.add_child(bottom_bar)
	
	_build_toasts()

func _build_top_bar() -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(0, 70)
	_style_panel(panel, Color(0.10, 0.07, 0.04, 0.86))

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	panel.add_child(row)

	_time_label = Label.new()
	_time_label.custom_minimum_size = Vector2(210, 0)
	_time_label.add_theme_font_size_override("font_size", 20)
	row.add_child(_time_label)

	for item in [
		["population", "Pop"],
		["food", "Food"],
		["gold", "Gold"],
		["morale", "Morale"],
		["trust", "Trust"],
		["culture", "Culture"],
	]:
		var box := _icon_value(item[0], item[1])
		row.add_child(box)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)

	# Purushartha Axes
	var axes_box := HBoxContainer.new()
	axes_box.add_theme_constant_override("separation", 20)
	row.add_child(axes_box)
	
	axes_box.add_child(_axis_display("Dharma", Color(0.85, 0.45, 0.15, 1.0)))
	axes_box.add_child(_axis_display("Artha", Color(0.85, 0.70, 0.15, 1.0)))
	axes_box.add_child(_axis_display("Kama", Color(0.60, 0.20, 0.70, 1.0)))
	axes_box.add_child(_axis_display("Moksha", Color(0.85, 0.85, 0.80, 1.0)))

	return panel

func _axis_display(axis_name: String, color: Color) -> Control:
	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(100, 0)
	box.add_theme_constant_override("separation", 2)
	
	var label := Label.new()
	label.text = axis_name
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 14)
	box.add_child(label)
	
	var bar := ProgressBar.new()
	bar.custom_minimum_size = Vector2(0, 16)
	bar.max_value = 100
	bar.value = 50
	bar.show_percentage = true
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.set_corner_radius_all(4)
	bar.add_theme_stylebox_override("fill", sb)
	
	var sb_bg := StyleBoxFlat.new()
	sb_bg.bg_color = Color(0.1, 0.1, 0.1, 1.0)
	sb_bg.border_width_bottom = 1
	sb_bg.border_width_left = 1
	sb_bg.border_width_right = 1
	sb_bg.border_width_top = 1
	sb_bg.border_color = Color(0.3, 0.3, 0.3, 1.0)
	sb_bg.set_corner_radius_all(4)
	bar.add_theme_stylebox_override("background", sb_bg)
	
	box.add_child(bar)
	_resource_labels["axis_" + axis_name.to_lower()] = bar
	
	return box

func _build_bottom_bar() -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(0, 76)
	_style_panel(panel, Color(0.10, 0.07, 0.04, 0.86))

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	panel.add_child(row)

	row.add_child(_layer_button("Layer I: Village (Dharma)", GameManager.Layer.VILLAGE, Color(0.85, 0.45, 0.15, 1.0)))
	row.add_child(_layer_button("Layer II: Governance (Artha)", GameManager.Layer.GOVERNANCE, Color(0.85, 0.70, 0.15, 1.0)))
	row.add_child(_layer_button("Layer III: Civilisation (Kama)", GameManager.Layer.CIVILISATION, Color(0.60, 0.20, 0.70, 1.0)))
	row.add_child(_layer_button("Layer IV: Pilgrim (Moksha)", GameManager.Layer.PILGRIM, Color(0.85, 0.85, 0.80, 1.0)))

	var fill := Control.new()
	fill.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(fill)

	_save_slot_select = OptionButton.new()
	_save_slot_select.custom_minimum_size = Vector2(92, 40)
	for slot in range(1, SaveSystem.MANUAL_SLOT_COUNT + 1):
		_save_slot_select.add_item("Slot %d" % slot)
	row.add_child(_save_slot_select)

	var save_button := Button.new()
	save_button.text = "Save"
	save_button.pressed.connect(_on_save_pressed)
	row.add_child(save_button)

	var load_button := Button.new()
	load_button.text = "Load"
	load_button.pressed.connect(_on_load_pressed)
	row.add_child(load_button)

	var menu_button := Button.new()
	menu_button.text = "Menu"
	menu_button.pressed.connect(_on_menu_pressed)
	row.add_child(menu_button)

	var end_button := Button.new()
	end_button.text = "End Turn (Advance Time)"
	end_button.icon = _load_icon("season_kharif")
	end_button.custom_minimum_size = Vector2(200, 46)
	_style_button(end_button)
	end_button.pressed.connect(_on_next_turn_pressed)
	row.add_child(end_button)
	return panel

func _layer_button(text: String, layer: int, color: Color) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(160, 40)
	button.add_theme_color_override("font_color", color)
	_style_button(button)
	button.pressed.connect(_on_layer_pressed.bind(layer))
	return button

func _build_toasts() -> void:
	var top_right := MarginContainer.new()
	top_right.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	top_right.offset_left = -430
	top_right.offset_top = 86
	top_right.offset_right = -18
	top_right.offset_bottom = 420
	top_right.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(top_right)

	_toast_container = VBoxContainer.new()
	_toast_container.add_theme_constant_override("separation", 8)
	_toast_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_right.add_child(_toast_container)

func _icon_value(key: String, label_text: String) -> Control:
	var box := HBoxContainer.new()
	box.add_theme_constant_override("separation", 5)

	var icon := TextureRect.new()
	icon.texture = _load_icon(key)
	icon.custom_minimum_size = Vector2(28, 28)
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	box.add_child(icon)

	var label := Label.new()
	label.custom_minimum_size = Vector2(96, 0)
	label.text = "%s: -" % label_text
	box.add_child(label)
	_resource_labels[key] = label
	return box

func _style_panel(panel: PanelContainer, color: Color) -> void:
	var tex_path := "res://assets/art/ui/panel_parchment.jpg"
	if ResourceLoader.exists(tex_path):
		var style := StyleBoxTexture.new()
		style.texture = load(tex_path) as Texture2D
		style.texture_margin_left = 32.0
		style.texture_margin_top = 32.0
		style.texture_margin_right = 32.0
		style.texture_margin_bottom = 32.0
		style.modulate_color = color
		panel.add_theme_stylebox_override("panel", style)
	else:
		var style := StyleBoxFlat.new()
		style.bg_color = color
		style.border_color = Color(0.83, 0.55, 0.16, 0.95)
		style.set_border_width_all(2)
		style.set_corner_radius_all(6)
		style.set_content_margin(SIDE_LEFT, 14)
		style.set_content_margin(SIDE_TOP, 10)
		style.set_content_margin(SIDE_RIGHT, 14)
		style.set_content_margin(SIDE_BOTTOM, 10)
		panel.add_theme_stylebox_override("panel", style)

func _style_button(button: Button) -> void:
	var tex_path := "res://assets/art/ui/button_terracotta.jpg"
	if ResourceLoader.exists(tex_path):
		var style := StyleBoxTexture.new()
		style.texture = load(tex_path) as Texture2D
		style.texture_margin_left = 16.0
		style.texture_margin_top = 16.0
		style.texture_margin_right = 16.0
		style.texture_margin_bottom = 16.0
		button.add_theme_stylebox_override("normal", style)
		button.add_theme_stylebox_override("hover", style)
		button.add_theme_stylebox_override("pressed", style)
		button.add_theme_stylebox_override("disabled", style)

func _load_icon(key: String) -> Texture2D:
	var path: String = ICONS.get(key, "res://assets/art/ui/warning.svg")
	if ResourceLoader.exists(path):
		return load(path) as Texture2D
	return null

func _update_all() -> void:
	var season := TurnManager.get_current_season_name()
	_time_label.text = "%s  |  %s" % [TurnManager.get_current_year_display(), season]

	_set_resource_text("population", "Pop", GlobalState.get_resource("population"))
	_set_resource_text("food", "Food", GlobalState.get_resource("food"))
	_set_resource_text("gold", "Gold", GlobalState.get_resource("treasury"))
	_set_resource_text("culture", "Culture", GlobalState.get_resource("culture"))
	_set_resource_text("morale", "Morale", GlobalState.get_resource("morale"))
	
	# The village trust
	_set_resource_text("trust", "Trust", GlobalState.village_state.get("trust", 0.0))
	
	_set_axis("dharma", GlobalState.get_axis("dharma"))
	_set_axis("artha", GlobalState.get_axis("artha"))
	_set_axis("kama", GlobalState.get_axis("kama"))
	_set_axis("moksha", GlobalState.get_axis("moksha"))

func _set_resource_text(key: String, label_text: String, value: Variant) -> void:
	if not _resource_labels.has(key):
		return
	var label := _resource_labels[key] as Label
	if value is int:
		label.text = "%s: %d" % [label_text, value]
	else:
		label.text = "%s: %.1f" % [label_text, float(value)]

func _set_axis(key: String, value: float) -> void:
	if _resource_labels.has("axis_" + key):
		var bar: ProgressBar = _resource_labels["axis_" + key]
		bar.value = value

func _on_next_turn_pressed() -> void:
	# Advance time. If village is loaded, it should handle it, else turn manager.
	var village := get_tree().get_first_node_in_group("village_manager")
	if village != null:
		village.end_season()
	else:
		TurnManager.advance_season()
	_update_all()

func _on_layer_pressed(layer: int) -> void:
	GameManager.switch_to_layer(layer)
	_update_all()

func _on_layer_switched(_from_layer: String, _to_layer: String) -> void:
	_update_all()

func _on_save_pressed() -> void:
	SaveSystem.save_game(false, _selected_save_slot())

func _on_load_pressed() -> void:
	GameManager.load_saved_game(false, _selected_save_slot())

func _on_menu_pressed() -> void:
	GameManager.quit_to_menu()

func _selected_save_slot() -> int:
	if _save_slot_select == null:
		return 1
	return max(_save_slot_select.selected + 1, 1)

func _on_state_signal(_a: Variant = null, _b: Variant = null, _c: Variant = null) -> void:
	_update_all()

func _on_notification(title: String, message: String, severity: String) -> void:
	if _toast_container == null:
		return
	var toast := PanelContainer.new()
	toast.custom_minimum_size = Vector2(390, 0)
	_style_panel(toast, _toast_color(severity))

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 3)
	toast.add_child(box)

	var title_label := Label.new()
	title_label.text = title
	title_label.add_theme_font_size_override("font_size", 16)
	title_label.add_theme_color_override("font_color", Color(0.9, 0.8, 0.6))
	box.add_child(title_label)

	var message_label := Label.new()
	message_label.text = message
	message_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(message_label)

	_toast_container.add_child(toast)
	while _toast_container.get_child_count() > 4:
		_toast_container.get_child(0).queue_free()

	var timer := Timer.new()
	timer.one_shot = true
	timer.wait_time = 4.0
	timer.timeout.connect(toast.queue_free)
	toast.add_child(timer)
	timer.start()

func _toast_color(severity: String) -> Color:
	match severity:
		"warning":
			return Color(0.42, 0.26, 0.06, 0.93)
		"danger":
			return Color(0.34, 0.08, 0.06, 0.93)
		"positive":
			return Color(0.09, 0.30, 0.13, 0.93)
		_:
			return Color(0.10, 0.07, 0.04, 0.93)
