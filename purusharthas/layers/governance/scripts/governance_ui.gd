class_name GovernanceUI
extends Control

const AXIS_LABELS: Dictionary = {
	"dharma": "Dharma",
	"artha": "Artha",
	"kama": "Kama",
	"moksha": "Moksha",
}

var governance_manager: GovernanceManager
var _axis_bars: Dictionary = {}
var _advisor_box: VBoxContainer
var _event_title: Label
var _event_description: RichTextLabel
var _choice_box: VBoxContainer
var _legacy_label: Label

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS
	_build_ui()
	call_deferred("_bind_manager")

func _bind_manager() -> void:
	var node := get_tree().get_first_node_in_group("governance_manager")
	governance_manager = node as GovernanceManager
	if governance_manager == null:
		return
	governance_manager.governance_state_changed.connect(_update_all)
	governance_manager.governance_events_changed.connect(_on_events_changed)
	_update_all()

func _build_ui() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)

	var root := MarginContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("margin_left", 16)
	root.add_theme_constant_override("margin_top", 96)
	root.add_theme_constant_override("margin_right", 16)
	root.add_theme_constant_override("margin_bottom", 96)
	add_child(root)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	root.add_child(row)

	row.add_child(_build_left_panel())
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)
	row.add_child(_build_right_panel())

func _build_left_panel() -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(360, 0)
	_style_panel(panel, Color(0.10, 0.07, 0.04, 0.90))
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	panel.add_child(box)

	var title := Label.new()
	title.text = "Council"
	title.add_theme_font_size_override("font_size", 22)
	box.add_child(title)

	for axis: String in AXIS_LABELS.keys():
		var label := Label.new()
		label.text = AXIS_LABELS[axis]
		box.add_child(label)
		var bar := ProgressBar.new()
		bar.min_value = 0
		bar.max_value = 100
		box.add_child(bar)
		_axis_bars[axis] = bar

	_legacy_label = Label.new()
	_legacy_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_legacy_label)

	_advisor_box = VBoxContainer.new()
	_advisor_box.add_theme_constant_override("separation", 6)
	box.add_child(_advisor_box)
	return panel

func _build_right_panel() -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(390, 0)
	_style_panel(panel, Color(0.93, 0.86, 0.70, 0.96))
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	panel.add_child(box)

	var title := Label.new()
	title.text = "Decade Council"
	title.add_theme_font_size_override("font_size", 22)
	box.add_child(title)

	_event_title = Label.new()
	_event_title.add_theme_font_size_override("font_size", 18)
	box.add_child(_event_title)

	_event_description = RichTextLabel.new()
	_event_description.custom_minimum_size = Vector2(0, 120)
	_event_description.fit_content = true
	_event_description.scroll_active = false
	box.add_child(_event_description)

	_choice_box = VBoxContainer.new()
	_choice_box.add_theme_constant_override("separation", 8)
	box.add_child(_choice_box)

	var decade_button := Button.new()
	decade_button.text = "Advance Decade"
	decade_button.pressed.connect(_on_advance_decade_pressed)
	box.add_child(decade_button)
	return panel

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

func _update_all() -> void:
	if governance_manager == null:
		return
	var axes := governance_manager.get_axis_values()
	for axis: String in _axis_bars.keys():
		(_axis_bars[axis] as ProgressBar).value = float(axes.get(axis, 0.0))

	_legacy_label.text = "Legacy %.1f - %s | Instability %.1f" % [
		governance_manager.get_legacy_score(),
		governance_manager.get_legacy_title(),
		float(GlobalState.governance_state.get("instability", 0.0)),
	]

	for child in _advisor_box.get_children():
		child.queue_free()
	for advisor: Dictionary in governance_manager.get_advisors():
		var label := Label.new()
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.text = "%s (%s) - Loyalty %.0f" % [
			advisor.get("name", "Advisor"),
			advisor.get("role", "Council"),
			float(advisor.get("loyalty", 0.0)),
		]
		_advisor_box.add_child(label)

	_show_event(governance_manager.get_pending_events().front() if not governance_manager.get_pending_events().is_empty() else {})

func _show_event(event_data: Dictionary) -> void:
	for child in _choice_box.get_children():
		child.queue_free()
	if event_data.is_empty():
		_event_title.text = "No pending council matter"
		_event_description.text = "Advance time or resolve village seasons to reach the next decade."
		return
	_event_title.text = event_data.get("title", "Council Matter")
	_event_description.text = event_data.get("description", "")
	for choice: Dictionary in event_data.get("choices", []):
		var button := Button.new()
		button.text = choice.get("text", "Choose")
		button.tooltip_text = _choice_tooltip(choice)
		button.pressed.connect(_on_choice_pressed.bind(event_data.get("id", ""), choice.get("id", "")))
		_choice_box.add_child(button)

func _choice_tooltip(choice: Dictionary) -> String:
	var axis_parts: Array[String] = []
	for axis: String in (choice.get("axis_shifts", {}) as Dictionary).keys():
		axis_parts.append("%s %+d" % [axis.capitalize(), int(choice["axis_shifts"][axis])])
	return ", ".join(axis_parts)

func _on_choice_pressed(event_id: String, choice_id: String) -> void:
	if governance_manager == null:
		return
	governance_manager.resolve_governance_event(event_id, choice_id)
	_update_all()

func _on_advance_decade_pressed() -> void:
	if governance_manager != null:
		governance_manager.force_next_decade()
	_update_all()

func _on_events_changed(_events: Array) -> void:
	_update_all()
