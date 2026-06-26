class_name VillageHUD
extends Control

const ICONS: Dictionary = {
	"population": "res://assets/art/ui/population.svg",
	"food": "res://assets/art/ui/food.svg",
	"gold": "res://assets/art/ui/gold.svg",
	"morale": "res://assets/art/ui/morale.svg",
	"trust": "res://assets/art/ui/trust.svg",
	"culture": "res://assets/art/ui/culture.svg",
	"swaraj": "res://assets/art/ui/gram_swaraj.svg",
	"kharif": "res://assets/art/ui/season_kharif.svg",
	"rabi": "res://assets/art/ui/season_rabi.svg",
	"zaid": "res://assets/art/ui/season_zaid.svg",
	"season_kharif": "res://assets/art/ui/season_kharif.svg",
	"season_rabi": "res://assets/art/ui/season_rabi.svg",
	"season_zaid": "res://assets/art/ui/season_zaid.svg",
	"warning": "res://assets/art/ui/warning.svg",
}

const LABOR_CATEGORIES: Dictionary = {
	"FARMING": "Farming",
	"CRAFT_PRODUCTION": "Crafts",
	"TRADE_CARAVANS": "Trade",
	"TEMPLE_UPKEEP": "Temple",
	"COMMUNITY_SERVICE": "Community",
}

var village_manager: VillageManager
var _resource_labels: Dictionary = {}
var _labor_sliders: Dictionary = {}
var _labor_values: Dictionary = {}
var _updating_labor: bool = false
var _bind_attempts: int = 0

var _time_label: Label
var _labor_panel: Control
var _status_panel: Control
var _unallocated_label: Label
var _phase_label: Label
var _food_status_label: Label
var _swaraj_label: Label
var _swaraj_breakdown_label: Label
var _production_label: Label
var _card_count_label: Label
var _materials_label: Label
var _building_select: OptionButton
var _building_info_label: Label
var _building_summary_label: Label
var _save_slot_select: OptionButton
var _modal_shade: ColorRect
var _modal_panel: PanelContainer
var _modal_icon: TextureRect
var _modal_title: Label
var _modal_description: RichTextLabel
var _modal_choices: VBoxContainer
var _toast_container: VBoxContainer
var _building_ids: Array[String] = []

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS
	_build_ui()
	EventBus.game_started.connect(_on_game_started)
	EventBus.season_changed.connect(_on_state_signal)
	EventBus.resource_changed.connect(_on_state_signal)
	EventBus.notification.connect(_on_notification)
	EventBus.layer_switched.connect(_on_layer_switched)
	call_deferred("_bind_village_manager")

func _on_game_started() -> void:
	call_deferred("_bind_village_manager")

func _bind_village_manager() -> void:
	var node := get_tree().get_first_node_in_group("village_manager")
	if node == null:
		_update_all()
		if int(GameManager.current_state) == 1 and _bind_attempts < 8:
			_bind_attempts += 1
			call_deferred("_bind_village_manager")
		return

	village_manager = node as VillageManager
	if village_manager == null:
		return
	_bind_attempts = 0

	if not village_manager.village_state_changed.is_connected(_on_village_state_changed):
		village_manager.village_state_changed.connect(_on_village_state_changed)
	if not village_manager.pending_cards_changed.is_connected(_on_pending_cards_changed):
		village_manager.pending_cards_changed.connect(_on_pending_cards_changed)
	if not village_manager.production_resolved.is_connected(_on_production_resolved):
		village_manager.production_resolved.connect(_on_production_resolved)

	_update_all()
	_show_next_pending_card()

func _build_ui() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)

	var root := MarginContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("margin_left", 16)
	root.add_theme_constant_override("margin_top", 14)
	root.add_theme_constant_override("margin_right", 16)
	root.add_theme_constant_override("margin_bottom", 14)
	add_child(root)

	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 12)
	root.add_child(layout)

	layout.add_child(_build_top_bar())

	var middle := HBoxContainer.new()
	middle.size_flags_vertical = Control.SIZE_EXPAND_FILL
	middle.add_theme_constant_override("separation", 12)
	layout.add_child(middle)

	_labor_panel = _build_labor_panel()
	middle.add_child(_labor_panel)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	middle.add_child(spacer)

	_status_panel = _build_status_panel()
	middle.add_child(_status_panel)
	layout.add_child(_build_bottom_bar())
	_build_modal()
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

	var fill := Control.new()
	fill.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(fill)

	_phase_label = Label.new()
	_phase_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_phase_label.custom_minimum_size = Vector2(190, 0)
	row.add_child(_phase_label)
	return panel

func _build_labor_panel() -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(350, 0)
	_style_panel(panel, Color(0.12, 0.08, 0.05, 0.90))

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	panel.add_child(box)

	var title := Label.new()
	title.text = "Labor"
	title.add_theme_font_size_override("font_size", 22)
	box.add_child(title)

	_unallocated_label = Label.new()
	box.add_child(_unallocated_label)

	for category: String in LABOR_CATEGORIES.keys():
		var row := VBoxContainer.new()
		row.add_theme_constant_override("separation", 3)
		box.add_child(row)

		var label_row := HBoxContainer.new()
		row.add_child(label_row)

		var name_label := Label.new()
		name_label.text = LABOR_CATEGORIES[category]
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label_row.add_child(name_label)

		var value_label := Label.new()
		value_label.custom_minimum_size = Vector2(42, 0)
		value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		label_row.add_child(value_label)
		_labor_values[category] = value_label

		var slider := HSlider.new()
		slider.min_value = 0
		slider.step = 1
		slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		slider.value_changed.connect(_on_labor_slider_changed.bind(category))
		row.add_child(slider)
		_labor_sliders[category] = slider

	var auto_button := Button.new()
	auto_button.text = "Auto Allocate"
	auto_button.pressed.connect(_on_auto_allocate_pressed)
	box.add_child(auto_button)
	return panel

func _build_status_panel() -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(360, 0)
	_style_panel(panel, Color(0.12, 0.08, 0.05, 0.90))

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	panel.add_child(box)

	var title := Label.new()
	title.text = "Village"
	title.add_theme_font_size_override("font_size", 22)
	box.add_child(title)

	_food_status_label = Label.new()
	box.add_child(_food_status_label)

	_swaraj_label = Label.new()
	_swaraj_label.add_theme_font_size_override("font_size", 18)
	box.add_child(_swaraj_label)

	_swaraj_breakdown_label = Label.new()
	_swaraj_breakdown_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_swaraj_breakdown_label)

	_production_label = Label.new()
	_production_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_production_label)

	_card_count_label = Label.new()
	box.add_child(_card_count_label)

	var build_title := Label.new()
	build_title.text = "Build"
	build_title.add_theme_font_size_override("font_size", 18)
	box.add_child(build_title)

	_materials_label = Label.new()
	box.add_child(_materials_label)

	_building_select = OptionButton.new()
	_building_select.item_selected.connect(_on_building_selected)
	box.add_child(_building_select)

	_building_info_label = Label.new()
	_building_info_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_building_info_label)

	var build_button := Button.new()
	build_button.text = "Place Building"
	build_button.pressed.connect(_on_place_building_pressed)
	box.add_child(build_button)

	_building_summary_label = Label.new()
	_building_summary_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_building_summary_label)
	return panel

func _build_bottom_bar() -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(0, 76)
	_style_panel(panel, Color(0.10, 0.07, 0.04, 0.86))

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	panel.add_child(row)

	row.add_child(_layer_button("Village", 0))
	row.add_child(_layer_button("Governance", 1))
	row.add_child(_layer_button("Civilisation", 2))
	row.add_child(_layer_button("Pilgrim", 3))

	var fill := Control.new()
	fill.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(fill)

	var cards_button := Button.new()
	cards_button.text = "Open Decision"
	cards_button.icon = _load_icon("warning")
	cards_button.pressed.connect(_show_next_pending_card)
	row.add_child(cards_button)

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
	end_button.text = "End Season"
	end_button.icon = _load_icon("season_kharif")
	end_button.custom_minimum_size = Vector2(180, 46)
	end_button.pressed.connect(_on_next_turn_pressed)
	row.add_child(end_button)
	return panel

func _layer_button(text: String, layer: int) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(112, 40)
	button.pressed.connect(_on_layer_pressed.bind(layer))
	return button

func _build_modal() -> void:
	_modal_shade = ColorRect.new()
	_modal_shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_modal_shade.color = Color(0.02, 0.015, 0.01, 0.62)
	_modal_shade.visible = false
	add_child(_modal_shade)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_modal_shade.add_child(center)

	_modal_panel = PanelContainer.new()
	_modal_panel.custom_minimum_size = Vector2(560, 360)
	_style_panel(_modal_panel, Color(0.93, 0.86, 0.70, 0.98))
	center.add_child(_modal_panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	_modal_panel.add_child(box)

	var title_row := HBoxContainer.new()
	title_row.add_theme_constant_override("separation", 10)
	box.add_child(title_row)

	_modal_icon = TextureRect.new()
	_modal_icon.custom_minimum_size = Vector2(42, 42)
	_modal_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	title_row.add_child(_modal_icon)

	_modal_title = Label.new()
	_modal_title.add_theme_font_size_override("font_size", 24)
	_modal_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_row.add_child(_modal_title)

	_modal_description = RichTextLabel.new()
	_modal_description.custom_minimum_size = Vector2(0, 95)
	_modal_description.fit_content = true
	_modal_description.scroll_active = false
	_modal_description.bbcode_enabled = false
	box.add_child(_modal_description)

	_modal_choices = VBoxContainer.new()
	_modal_choices.add_theme_constant_override("separation", 8)
	box.add_child(_modal_choices)

func _build_toasts() -> void:
	var top_right := MarginContainer.new()
	top_right.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	top_right.offset_left = -430
	top_right.offset_top = 86
	top_right.offset_right = -18
	top_right.offset_bottom = 420
	top_right.add_theme_constant_override("margin_left", 0)
	top_right.add_theme_constant_override("margin_top", 0)
	top_right.add_theme_constant_override("margin_right", 0)
	top_right.add_theme_constant_override("margin_bottom", 0)
	add_child(top_right)

	_toast_container = VBoxContainer.new()
	_toast_container.add_theme_constant_override("separation", 8)
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

func _load_icon(key: String) -> Texture2D:
	var path: String = ICONS.get(key, "res://assets/art/ui/warning.svg")
	if ResourceLoader.exists(path):
		return load(path) as Texture2D
	return null

func _update_all() -> void:
	_update_resources()
	_update_labor()
	_update_status()
	_update_build_panel()
	_update_layer_visibility()

func _update_resources() -> void:
	var state := GlobalState.village_state
	var season := TurnManager.get_current_season_name()
	var season_key := season.to_lower()
	var season_icon := _load_icon("season_%s" % season_key)
	_time_label.text = "%s  |  %s" % [TurnManager.get_current_year_display(), season]

	_set_resource_text("population", "Pop", state.get("population", 0))
	_set_resource_text("food", "Food", state.get("food_stored", 0.0))
	_set_resource_text("gold", "Gold", state.get("gold", 0.0))
	_set_resource_text("morale", "Morale", state.get("morale", 0.0))
	_set_resource_text("trust", "Trust", state.get("trust", 0.0))
	_set_resource_text("culture", "Culture", state.get("culture_points", 0.0))

	if season_icon != null:
		# Keep the icon warm in the import cache; the visible season is textual for now.
		pass

	var phase := "No village"
	if village_manager != null:
		phase = village_manager.current_phase.capitalize()
	_phase_label.text = "Phase: %s" % phase

func _set_resource_text(key: String, label_text: String, value: Variant) -> void:
	if not _resource_labels.has(key):
		return
	var label := _resource_labels[key] as Label
	if value is int:
		label.text = "%s: %d" % [label_text, value]
	else:
		label.text = "%s: %.1f" % [label_text, float(value)]

func _update_labor() -> void:
	_updating_labor = true
	var total := 0
	var unallocated := 0
	var allocation: Dictionary = {}
	if village_manager != null:
		total = village_manager.get_total_labor()
		unallocated = village_manager.get_unallocated_labor()
		allocation = village_manager.get_labor_allocation()
	_unallocated_label.text = "Available: %d / %d" % [unallocated, total]
	for category: String in LABOR_CATEGORIES.keys():
		var slider := _labor_sliders[category] as HSlider
		var value_label := _labor_values[category] as Label
		slider.max_value = max(total, 1)
		slider.value = int(allocation.get(category, 0))
		value_label.text = str(int(slider.value))
	_updating_labor = false

func _update_status() -> void:
	if village_manager == null:
		_food_status_label.text = "Waiting for village..."
		return
	var score := village_manager.get_gram_swaraj_score()
	_food_status_label.text = "Food status: %s" % village_manager.get_food_status().capitalize()
	_swaraj_label.text = "Gram Swaraj: %.1f (%s)" % [
		float(score.get("total", 0.0)),
		village_manager.gram_swaraj.get_score_tier().capitalize(),
	]
	_swaraj_breakdown_label.text = "Food %.0f | Culture %.0f | Trust %.0f | Trade %.0f" % [
		float(score.get("food_security", 0.0)),
		float(score.get("cultural_vibrancy", 0.0)),
		float(score.get("panchayat_trust", 0.0)),
		float(score.get("trade_connections", 0.0)),
	]
	var production := village_manager.get_last_production_results()
	if production.is_empty():
		_production_label.text = "Last production: none yet"
	else:
		_production_label.text = "Last production: Food +%.1f | Gold +%.1f | Culture +%.1f | Morale +%.1f" % [
			float(production.get("food_produced", 0.0)),
			float(production.get("trade_income", 0.0)),
			float(production.get("culture_generated", 0.0)),
			float(production.get("morale_change", 0.0)),
		]
	_card_count_label.text = "Pending decisions: %d" % village_manager.get_pending_cards().size()

func _update_build_panel() -> void:
	if village_manager == null:
		return
	var state := GlobalState.village_state
	_materials_label.text = "Wood %.0f | Stone %.0f" % [
		float(state.get("wood", 0.0)),
		float(state.get("stone", 0.0)),
	]

	var definitions := village_manager.get_building_definitions()
	if _building_select.item_count != definitions.size():
		var selected_id := _get_selected_building_id()
		_building_select.clear()
		_building_ids.clear()
		for building_id: String in definitions.keys():
			var definition: Dictionary = definitions[building_id]
			_building_ids.append(building_id)
			_building_select.add_item(definition.get("name", building_id.capitalize()))
		var selected_index: int = max(_building_ids.find(selected_id), 0)
		if not _building_ids.is_empty():
			_building_select.select(selected_index)

	_update_selected_building_info()
	_update_building_summary()

func _update_selected_building_info() -> void:
	var building_id := _get_selected_building_id()
	if building_id.is_empty() or village_manager == null:
		_building_info_label.text = "No buildings loaded."
		return
	var definitions := village_manager.get_building_definitions()
	var definition: Dictionary = definitions.get(building_id, {})
	_building_info_label.text = "%s | Cost: %s" % [
		definition.get("description", ""),
		_format_cost(definition.get("cost", {})),
	]

func _update_building_summary() -> void:
	var summary := village_manager.get_building_summary()
	if summary.is_empty():
		_building_summary_label.text = "Buildings: none placed"
		return
	var definitions := village_manager.get_building_definitions()
	var parts: Array[String] = []
	for building_id: String in summary.keys():
		var definition: Dictionary = definitions.get(building_id, {})
		parts.append("%s x%d" % [definition.get("name", building_id), int(summary[building_id])])
	_building_summary_label.text = "Buildings: %s" % ", ".join(parts)

func _format_cost(cost: Dictionary) -> String:
	if cost.is_empty():
		return "free"
	var parts: Array[String] = []
	for key: String in cost.keys():
		parts.append("%s %s" % [key.capitalize(), cost[key]])
	return ", ".join(parts)

func _get_selected_building_id() -> String:
	if _building_select == null or _building_select.selected < 0:
		return ""
	var index := _building_select.selected
	if index >= 0 and index < _building_ids.size():
		return _building_ids[index]
	return ""

func _on_labor_slider_changed(value: float, category: String) -> void:
	if _updating_labor or village_manager == null:
		return
	var ok := village_manager.set_labor_allocation(category, int(value))
	if not ok:
		_update_labor()
		return
	_update_all()

func _on_auto_allocate_pressed() -> void:
	if village_manager == null:
		return
	village_manager.auto_allocate_labor()
	_update_all()

func _on_building_selected(_index: int) -> void:
	_update_selected_building_info()

func _on_place_building_pressed() -> void:
	if village_manager == null:
		return
	var building_id := _get_selected_building_id()
	if building_id.is_empty():
		return
	var placed := village_manager.place_building_next_available(building_id)
	if not placed:
		EventBus.notification.emit(
			"Cannot Build",
			"The village lacks resources, population, or free build space for that building.",
			"warning",
		)
	_update_all()

func _on_next_turn_pressed() -> void:
	if village_manager == null:
		_bind_village_manager()
	if village_manager != null:
		village_manager.end_season()
	else:
		TurnManager.advance_season()
	_update_all()
	_show_next_pending_card()

func _on_layer_pressed(layer: int) -> void:
	GameManager.switch_to_layer(layer)
	_update_all()

func _on_layer_switched(_from_layer: String, _to_layer: String) -> void:
	_update_layer_visibility()

func _update_layer_visibility() -> void:
	var is_village := int(GameManager.current_layer) == 0
	if _labor_panel != null:
		_labor_panel.visible = is_village
	if _status_panel != null:
		_status_panel.visible = is_village

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

func _show_next_pending_card() -> void:
	if village_manager == null:
		return
	var cards := village_manager.get_pending_cards()
	if cards.is_empty():
		_modal_shade.visible = false
		return
	_show_card(cards[0])

func _show_card(card: Dictionary) -> void:
	_modal_shade.visible = true
	_modal_icon.texture = load(card.get("icon_path", "res://assets/art/ui/warning.svg")) as Texture2D
	_modal_title.text = card.get("title", "Decision")
	_modal_description.text = card.get("description", "")
	for child in _modal_choices.get_children():
		child.queue_free()

	var card_id := int(card.get("card_id", -1))
	for choice: Dictionary in card.get("choices", []):
		var button := Button.new()
		button.text = choice.get("text", "Choose")
		button.tooltip_text = choice.get("description", "")
		button.custom_minimum_size = Vector2(0, 42)
		button.pressed.connect(_on_choice_pressed.bind(card_id, choice.get("id", "")))
		_modal_choices.add_child(button)

func _on_choice_pressed(card_id: int, choice_id: String) -> void:
	if village_manager == null:
		return
	village_manager.resolve_pending_card(card_id, choice_id)
	_update_all()
	_show_next_pending_card()

func _on_village_state_changed() -> void:
	_update_all()

func _on_pending_cards_changed(cards: Array) -> void:
	_update_status()
	if _modal_shade.visible and cards.is_empty():
		_modal_shade.visible = false

func _on_production_resolved(results: Dictionary) -> void:
	_update_all()

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
