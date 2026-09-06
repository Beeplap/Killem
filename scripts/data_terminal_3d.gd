class_name DataTerminal3D
extends Node3D

signal hack_started
signal hack_progress(progress: float)
signal terminal_hacked
signal room_breach_triggered

enum State { LOCKED, HACKING, COMPLETED }

@export var hack_duration: float = 15.0

var current_state: State = State.LOCKED
var _marker: Node3D = null
var _screen: MeshInstance3D = null
var _light: OmniLight3D = null

func _ready() -> void:
	# Solid Collision
	var static_body = StaticBody3D.new()
	var col = CollisionShape3D.new()
	var col_shape = BoxShape3D.new()
	col_shape.size = Vector3(0.8, 1.4, 0.6)
	col.shape = col_shape
	col.position.y = 0.7
	static_body.add_child(col)
	add_child(static_body)
	
	# Terminal Body Mesh
	var mesh_instance = MeshInstance3D.new()
	var box_mesh = BoxMesh.new()
	box_mesh.size = Vector3(0.8, 1.4, 0.6)
	mesh_instance.mesh = box_mesh
	mesh_instance.position.y = 0.7
	var body_mat = StandardMaterial3D.new()
	body_mat.albedo_color = Color(0.15, 0.18, 0.2)
	body_mat.metallic = 0.7
	body_mat.roughness = 0.35
	mesh_instance.material_override = body_mat
	add_child(mesh_instance)
	
	# Terminal Screen
	_screen = MeshInstance3D.new()
	var screen_mesh = PlaneMesh.new()
	screen_mesh.size = Vector2(0.6, 0.5)
	_screen.mesh = screen_mesh
	
	var material = StandardMaterial3D.new()
	material.albedo_color = Color(0.1, 1.0, 0.4)
	material.emission_enabled = true
	material.emission = Color(0.1, 1.0, 0.4)
	material.emission_energy_multiplier = 2.5
	_screen.material_override = material
	
	_screen.position = Vector3(0, 0.9, 0.31)
	_screen.rotation_degrees = Vector3(90, 0, 0)
	add_child(_screen)
	
	# Glow Light
	_light = OmniLight3D.new()
	_light.light_color = Color(0.2, 1.0, 0.5)
	_light.omni_range = 3.5
	_light.light_energy = 1.0
	_light.position = Vector3(0, 1.0, 0.5)
	add_child(_light)
	
	# 3D Objective Marker
	var marker_script = load("res://scripts/objective_marker_3d.gd")
	if marker_script:
		_marker = Node3D.new()
		_marker.set_script(marker_script)
		_marker.set("marker_text", "MILITARY TERMINAL")
		_marker.set("marker_color", Color(0.2, 0.85, 1.0))
		add_child(_marker)
		_marker.position.y = 1.2
	
	# Interactable Area
	var interactable_script = load("res://scripts/interactable_3d.gd")
	if interactable_script:
		var interactable = Area3D.new()
		interactable.set_script(interactable_script)
		interactable.name = "Interactable3D"
		interactable.interaction_text = "Hack Survivor Data Terminal"
		interactable.hold_duration = hack_duration
		interactable.interacted.connect(_on_interacted)
		interactable.interaction_progress.connect(_on_interaction_progress)
		
		var interact_col = CollisionShape3D.new()
		var interact_shape = BoxShape3D.new()
		interact_shape.size = Vector3(2.5, 2.0, 2.5)
		interact_col.shape = interact_shape
		interact_col.position.y = 0.7
		interactable.add_child(interact_col)
		add_child(interactable)

func _on_interaction_progress(progress: float) -> void:
	if current_state == State.LOCKED or current_state == State.HACKING:
		if current_state == State.LOCKED and progress > 0.0:
			current_state = State.HACKING
			hack_started.emit()
			room_breach_triggered.emit()
			Global.play_sound("boss_alarm", global_position)
			if _marker:
				_marker.set("marker_text", "HACKING IN PROGRESS")
				_marker.set("marker_color", Color(1.0, 0.4, 0.1))
		
		hack_progress.emit(progress)

func _on_interacted(_interactor: Node = null) -> void:
	if current_state != State.COMPLETED:
		complete_hack()

func complete_hack() -> void:
	current_state = State.COMPLETED
	hack_progress.emit(1.0)
	terminal_hacked.emit()
	Global.play_sound("perk", global_position)
	
	if _screen and _screen.material_override:
		var mat = _screen.material_override as StandardMaterial3D
		if mat:
			mat.albedo_color = Color(0.2, 0.6, 1.0)
			mat.emission = Color(0.2, 0.6, 1.0)
	
	if _light:
		_light.light_color = Color(0.2, 0.6, 1.0)
		_light.light_energy = 1.5
	
	if _marker:
		_marker.queue_free()
	
	var interactable = get_node_or_null("Interactable3D")
	if interactable:
		interactable.queue_free()
