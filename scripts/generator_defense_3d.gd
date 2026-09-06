class_name GeneratorDefense3D
extends Node3D

signal defense_started
signal defense_progress(progress: float)
signal defense_completed
signal defense_failed
signal generator_damaged(health: float)
signal generator_defense_wave(wave_index: int)
signal objective_completed

enum State { INACTIVE, FUELING, DEFENDING, COMPLETED, FAILED }

@export var defense_duration: float = 45.0
@export var generator_health: float = 100.0

var current_state: State = State.INACTIVE
var time_remaining: float = 0.0
var _light: OmniLight3D
var _marker: Node3D = null
var _wave_counter: int = 1
var _last_wave_time: float = 0.0

func _ready() -> void:
	# 3D Physical Static Body for generator
	var static_body = StaticBody3D.new()
	var col_shape = CollisionShape3D.new()
	var box_shape = BoxShape3D.new()
	box_shape.size = Vector3(1.4, 1.8, 1.2)
	col_shape.shape = box_shape
	col_shape.position.y = 0.9
	static_body.add_child(col_shape)
	add_child(static_body)
	
	# Mesh Visuals
	var mesh_instance = MeshInstance3D.new()
	var box_mesh = BoxMesh.new()
	box_mesh.size = Vector3(1.4, 1.8, 1.2)
	mesh_instance.mesh = box_mesh
	mesh_instance.position.y = 0.9
	
	var material = StandardMaterial3D.new()
	material.albedo_color = Color(0.18, 0.42, 0.22)
	material.metallic = 0.6
	material.roughness = 0.5
	mesh_instance.material_override = material
	add_child(mesh_instance)
	
	# Light
	_light = OmniLight3D.new()
	_light.light_color = Color(1.0, 0.9, 0.4)
	_light.omni_range = 6.0
	_light.light_energy = 0.0
	_light.position.y = 1.6
	add_child(_light)
	
	# Objective Marker
	var marker_script = load("res://scripts/objective_marker_3d.gd")
	if marker_script:
		_marker = Node3D.new()
		_marker.set_script(marker_script)
		_marker.set("marker_text", "POWER GENERATOR")
		_marker.set("marker_color", Color(0.3, 1.0, 0.4))
		add_child(_marker)
		_marker.position.y = 1.0
	
	# Interactable Area
	var interactable_script = load("res://scripts/interactable_3d.gd")
	if interactable_script:
		var interactable = Area3D.new()
		interactable.set_script(interactable_script)
		interactable.name = "Interactable3D"
		interactable.interaction_text = "Insert Fuel & Activate Generator"
		interactable.hold_duration = 2.0
		interactable.interacted.connect(_on_interacted)
		
		var interact_col = CollisionShape3D.new()
		var interact_shape = BoxShape3D.new()
		interact_shape.size = Vector3(3.5, 2.5, 3.5)
		interact_col.shape = interact_shape
		interact_col.position.y = 0.9
		interactable.add_child(interact_col)
		add_child(interactable)

func _on_interacted(_interactor: Node = null) -> void:
	if current_state == State.INACTIVE or current_state == State.FUELING:
		start_defense()

func start_defense() -> void:
	current_state = State.DEFENDING
	time_remaining = defense_duration
	_wave_counter = 1
	_last_wave_time = defense_duration
	defense_started.emit()
	generator_defense_wave.emit(1)
	Global.play_sound("wave_start")
	if _marker:
		_marker.set("marker_text", "DEFEND GENERATOR")
		_marker.set("marker_color", Color(1.0, 0.2, 0.2))

func _process(delta: float) -> void:
	if current_state == State.DEFENDING:
		time_remaining -= delta
		var progress = clampf(1.0 - (time_remaining / defense_duration), 0.0, 1.0)
		defense_progress.emit(progress)
		
		# Light flicker
		_light.light_energy = 1.4 + sin(Time.get_ticks_msec() * 0.015) * 0.6
		
		# Trigger periodic siege waves every 10s
		if (_last_wave_time - time_remaining) >= 10.0:
			_last_wave_time = time_remaining
			_wave_counter += 1
			generator_defense_wave.emit(_wave_counter)
			Global.play_sound("zombie_groan")
		
		if time_remaining <= 0.0:
			complete_defense()

func take_damage(amount: float) -> void:
	if current_state != State.DEFENDING:
		return
		
	generator_health -= amount
	generator_damaged.emit(generator_health)
	
	if generator_health <= 0.0:
		fail_defense()

func complete_defense() -> void:
	current_state = State.COMPLETED
	defense_progress.emit(1.0)
	_light.light_color = Color(0.2, 1.0, 0.4)
	_light.light_energy = 2.5
	defense_completed.emit()
	objective_completed.emit()
	Global.play_sound("wave_clear")
	
	if _marker:
		_marker.queue_free()
	
	var interactable = get_node_or_null("Interactable3D")
	if interactable:
		interactable.queue_free()

func fail_defense() -> void:
	current_state = State.FAILED
	_light.light_energy = 1.0
	_light.light_color = Color(1.0, 0.0, 0.0)
	defense_failed.emit()
