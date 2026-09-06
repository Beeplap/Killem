class_name MissionManager
extends Node

signal objective_added(obj_id: String, obj_data: Dictionary)
signal objective_completed(obj_id: String)
signal objective_updated(obj_id: String, obj_data: Dictionary)
signal all_objectives_complete

var active_objectives: Dictionary = {}

func add_objective(obj_id: String, title: String, description: String, type: String) -> void:
	if active_objectives.has(obj_id):
		push_warning("MissionManager: Objective %s already exists." % obj_id)
		return
		
	var obj_data = {
		"title": title,
		"description": description,
		"completed": false,
		"progress": 0.0,
		"type": type
	}
	active_objectives[obj_id] = obj_data
	objective_added.emit(obj_id, obj_data)

func complete_objective(obj_id: String) -> void:
	if not active_objectives.has(obj_id):
		push_warning("MissionManager: Cannot complete unknown objective %s." % obj_id)
		return
		
	if active_objectives[obj_id]["completed"]:
		return
		
	active_objectives[obj_id]["completed"] = true
	active_objectives[obj_id]["progress"] = 1.0
	objective_completed.emit(obj_id)
	
	if has_all_completed():
		all_objectives_complete.emit()

func update_progress(obj_id: String, progress: float) -> void:
	if not active_objectives.has(obj_id):
		push_warning("MissionManager: Cannot update unknown objective %s." % obj_id)
		return
		
	if active_objectives[obj_id]["completed"]:
		return
		
	active_objectives[obj_id]["progress"] = clampf(progress, 0.0, 1.0)
	objective_updated.emit(obj_id, active_objectives[obj_id])

func has_all_completed() -> bool:
	if active_objectives.is_empty():
		return false
	
	for obj in active_objectives.values():
		if not obj["completed"]:
			return false
	return true

func get_active_objectives() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for obj in active_objectives.values():
		result.append(obj)
	return result
