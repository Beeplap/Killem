class_name KeycardPickup3D
extends Area3D

@export_enum("yellow", "blue", "red") var keycard_color: String = "yellow"

var _start_y: float = 0.0
var _time: float = 0.0

func _ready() -> void:
	monitoring = true
	collision_layer = 16
	collision_mask = 1
	
	var collision_shape = CollisionShape3D.new()
	var box_shape = BoxShape3D.new()
	box_shape.size = Vector3(0.5, 0.5, 0.5)
	collision_shape.shape = box_shape
	add_child(collision_shape)
	
	var mesh_instance = MeshInstance3D.new()
	var box_mesh = BoxMesh.new()
	box_mesh.size = Vector3(0.3, 0.02, 0.2)
	mesh_instance.mesh = box_mesh
	
	var material = StandardMaterial3D.new()
	var color = Color(1, 0.85, 0.1)
	if keycard_color == "blue":
		color = Color(0.2, 0.5, 1.0)
	elif keycard_color == "red":
		color = Color(1, 0.2, 0.15)
	
	material.albedo_color = color
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = 1.2
	mesh_instance.material_override = material
	add_child(mesh_instance)
	
	var light = OmniLight3D.new()
	light.light_color = color
	light.omni_range = 3.5
	light.light_energy = 1.2
	add_child(light)
	
	# Add 3D Objective Marker
	var marker_script = load("res://scripts/objective_marker_3d.gd")
	if marker_script:
		var marker = Node3D.new()
		marker.set_script(marker_script)
		marker.set("marker_text", keycard_color.to_upper() + " KEYCARD")
		marker.set("marker_color", color)
		add_child(marker)
	
	body_entered.connect(_on_body_entered)
	_start_y = global_position.y

func _process(delta: float) -> void:
	_time += delta
	rotation.y += 1.5 * delta
	
	var bob_offset = sin(_time * 3.0) * 0.1
	global_position.y = _start_y + bob_offset

func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("player") or body.is_in_group("player3d"):
		if Global.has_method("collect_keycard"):
			Global.collect_keycard(keycard_color)
		elif Global and "keycards_collected" in Global:
			Global.keycards_collected.append(keycard_color)
			Global.play_sound("pickup")
		
		queue_free()
