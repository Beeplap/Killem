extends CanvasLayer
class_name ObjectiveTrackerHUD

var _main_vbox: VBoxContainer
var _objective_container: VBoxContainer
var _scanline_tween: Tween

var _objectives: Dictionary = {}

func _ready() -> void:
	_build_ui()
	_start_scanline_effect()
	_connect_to_mission_manager.call_deferred()

func _build_ui() -> void:
	var margin_container = MarginContainer.new()
	margin_container.add_theme_constant_override("margin_left", 20)
	margin_container.add_theme_constant_override("margin_top", 20)
	add_child(margin_container)

	_main_vbox = VBoxContainer.new()
	_main_vbox.add_theme_constant_override("separation", 10)
	margin_container.add_child(_main_vbox)

	var header_panel = PanelContainer.new()
	var style_box = StyleBoxFlat.new()
	style_box.bg_color = Color(0.05, 0.08, 0.05, 0.75)
	style_box.corner_radius_top_left = 4
	style_box.corner_radius_top_right = 4
	style_box.corner_radius_bottom_left = 4
	style_box.corner_radius_bottom_right = 4
	style_box.border_width_left = 1
	style_box.border_width_right = 1
	style_box.border_width_top = 1
	style_box.border_width_bottom = 1
	style_box.border_color = Color(0.3, 0.5, 0.2, 0.6)
	header_panel.add_theme_stylebox_override("panel", style_box)
	_main_vbox.add_child(header_panel)

	var header_margin = MarginContainer.new()
	header_margin.add_theme_constant_override("margin_left", 10)
	header_margin.add_theme_constant_override("margin_right", 10)
	header_margin.add_theme_constant_override("margin_top", 5)
	header_margin.add_theme_constant_override("margin_bottom", 5)
	header_panel.add_child(header_margin)

	var header_label = Label.new()
	header_label.text = "MISSION OBJECTIVES"
	header_label.add_theme_color_override("font_color", Color(0.9, 0.95, 0.85))
	header_label.add_theme_font_size_override("font_size", 18)
	header_label.add_theme_constant_override("outline_size", 1) # Faux bold if font doesn't support it directly
	header_margin.add_child(header_label)

	_objective_container = VBoxContainer.new()
	_objective_container.add_theme_constant_override("separation", 5)
	_main_vbox.add_child(_objective_container)

func _start_scanline_effect() -> void:
	if _scanline_tween:
		_scanline_tween.kill()
	_scanline_tween = create_tween().set_loops()
	_scanline_tween.tween_property(_main_vbox, "modulate:a", 0.85, 2.0).set_trans(Tween.TRANS_SINE)
	_scanline_tween.tween_property(_main_vbox, "modulate:a", 1.0, 2.0).set_trans(Tween.TRANS_SINE)

func _connect_to_mission_manager() -> void:
	var managers = get_tree().get_nodes_in_group("mission_manager")
	if managers.size() > 0:
		var manager = managers[0]
		if manager.has_signal("objective_added"):
			manager.objective_added.connect(add_objective_entry)
		if manager.has_signal("objective_completed"):
			manager.objective_completed.connect(complete_objective_entry)
		if manager.has_signal("objective_updated"):
			manager.objective_updated.connect(update_objective_entry)

func add_objective_entry(obj_id: String, obj_data = null) -> void:
	if _objectives.has(obj_id):
		return
	var title: String = obj_id
	if obj_data is Dictionary and obj_data.has("title"):
		title = obj_data["title"]
	elif obj_data is String:
		title = obj_data

	var entry = HBoxContainer.new()
	entry.add_theme_constant_override("separation", 8)
	
	var checkbox = RichTextLabel.new()
	checkbox.bbcode_enabled = true
	checkbox.text = "[ ]"
	checkbox.fit_content = true
	checkbox.autowrap_mode = TextServer.AUTOWRAP_OFF
	checkbox.custom_minimum_size.x = 24
	checkbox.add_theme_color_override("default_color", Color(0.85, 0.9, 0.8))
	entry.add_child(checkbox)
	
	var title_label = RichTextLabel.new()
	title_label.bbcode_enabled = true
	title_label.text = title
	title_label.fit_content = true
	title_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	title_label.add_theme_color_override("default_color", Color(0.85, 0.9, 0.8))
	title_label.add_theme_font_size_override("normal_font_size", 14)
	entry.add_child(title_label)
	
	var progress_bar = ProgressBar.new()
	progress_bar.custom_minimum_size.x = 100
	progress_bar.custom_minimum_size.y = 12
	progress_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	progress_bar.visible = false
	progress_bar.show_percentage = true
	entry.add_child(progress_bar)
	
	_objective_container.add_child(entry)
	_objectives[obj_id] = {
		"container": entry,
		"checkbox": checkbox,
		"title": title_label,
		"progress": progress_bar,
		"raw_title": title
	}
	
	entry.position.x = -200
	var tween = create_tween()
	tween.tween_property(entry, "position:x", 0.0, 0.4).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)

func update_objective_entry(obj_id: String, obj_data = null) -> void:
	if not _objectives.has(obj_id):
		return
	var progress: float = 0.0
	if obj_data is Dictionary and obj_data.has("progress"):
		progress = obj_data["progress"]
	elif obj_data is float:
		progress = obj_data
	var entry_data = _objectives[obj_id]
	var bar: ProgressBar = entry_data["progress"]
	bar.visible = true
	bar.max_value = 100.0
	bar.value = clampf(progress * 100.0 if progress <= 1.0 else progress, 0.0, 100.0)

func complete_objective_entry(obj_id: String) -> void:
	if not _objectives.has(obj_id):
		return
	var entry_data = _objectives[obj_id]
	
	var checkbox: RichTextLabel = entry_data["checkbox"]
	checkbox.text = "[color=green][x][/color]"
	
	var title: RichTextLabel = entry_data["title"]
	var raw_title: String = entry_data["raw_title"]
	title.text = "[s]" + raw_title + "[/s]"
	title.add_theme_color_override("default_color", Color(0.5, 0.6, 0.45))
	
	var bar: ProgressBar = entry_data["progress"]
	bar.visible = false
	
	if Global.has_method("play_sound"):
		Global.play_sound("wave_clear")
		
	var container: Control = entry_data["container"]
	var tween = create_tween()
	tween.tween_property(container, "modulate", Color(0.3, 1.0, 0.3, 1.0), 0.2)
	tween.tween_property(container, "modulate", Color(1, 1, 1, 0.6), 0.5)

func remove_objective_entry(obj_id: String) -> void:
	if not _objectives.has(obj_id):
		return
	var entry_data = _objectives[obj_id]
	entry_data["container"].queue_free()
	_objectives.erase(obj_id)

func clear_all() -> void:
	for obj_id in _objectives.keys():
		remove_objective_entry(obj_id)
