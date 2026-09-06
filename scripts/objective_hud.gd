extends CanvasLayer
class_name ObjectiveHUD

@onready var mission_title: Label = $Container/Panel/VBox/MissionTitle
@onready var objectives_list: VBoxContainer = $Container/Panel/VBox/ObjectivesList

func _ready() -> void:
	if CampaignManager:
		CampaignManager.objective_updated.connect(_on_objective_updated)
		CampaignManager.level_started.connect(_on_level_started)
	refresh_display()

func _on_level_started(_lvl_idx: int, _lvl_name: String) -> void:
	refresh_display()

func _on_objective_updated(_id: String, _text: String, _cur: int, _tgt: int, _done: bool) -> void:
	refresh_display()

func refresh_display() -> void:
	if not CampaignManager:
		return
	
	var lvl_data = CampaignManager.LEVELS[CampaignManager.current_level_index]
	if mission_title:
		mission_title.text = lvl_data.get("name", "MISSION OBJECTIVES").to_upper()
	
	if not objectives_list:
		return
	
	for c in objectives_list.get_children():
		c.queue_free()
	
	for obj in CampaignManager.active_objectives:
		var lbl = Label.new()
		var check = "[X] " if obj["completed"] else "[  ] "
		var progress = " (%d/%d)" % [obj["current"], obj["target"]] if obj["target"] > 1 else ""
		lbl.text = check + obj["text"] + progress
		
		if obj["completed"]:
			lbl.modulate = Color(0.3, 1.0, 0.45)
		else:
			lbl.modulate = Color(0.9, 0.92, 0.95)
		
		lbl.add_theme_font_size_override("font_size", 13)
		objectives_list.add_child(lbl)
