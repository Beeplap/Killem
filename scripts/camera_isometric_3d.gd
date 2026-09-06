extends Camera3D

@export var target_path: NodePath
@export var smooth_speed: float = 8.0
@export var distance: float = 24.0
@export var follow_offset: Vector3 = Vector3.ZERO

var target: Node3D = null

func _ready() -> void:
	# Configure isometric angle exactly as specified: Vector3(-55, 45, 0)
	rotation_degrees = Vector3(-55.0, 45.0, 0.0)
	projection = Camera3D.PROJECTION_PERSPECTIVE
	fov = 35.0
	current = true
	
	if has_node(target_path):
		target = get_node(target_path)
	else:
		call_deferred("_find_target")

func _find_target() -> void:
	target = get_tree().get_first_node_in_group("player3d")
	if target == null:
		target = get_tree().get_first_node_in_group("player")

func _physics_process(delta: float) -> void:
	if target == null or not is_instance_valid(target):
		_find_target()
		return
	
	# Calculate backward isometric offset from rotation (-55 deg pitch, 45 deg yaw)
	var rot_rad_x = deg_to_rad(-55.0)
	var rot_rad_y = deg_to_rad(45.0)
	
	# Local forward vector is -Z. Local backward is +Z.
	# Rotating (0, 0, distance) by Y(45 deg) then X(-55 deg):
	var cam_offset = Vector3(
		distance * cos(rot_rad_x) * sin(rot_rad_y),
		distance * -sin(rot_rad_x),
		distance * cos(rot_rad_x) * cos(rot_rad_y)
	)
	
	var desired_pos = target.global_position + cam_offset + follow_offset
	if "trauma" in target and target.trauma > 0.0:
		var shake = target.trauma * target.trauma
		desired_pos += Vector3(
			randf_range(-1.0, 1.0) * 0.4 * shake,
			randf_range(-1.0, 1.0) * 0.25 * shake,
			randf_range(-1.0, 1.0) * 0.4 * shake
		)
	global_position = global_position.lerp(desired_pos, clampf(delta * smooth_speed, 0.0, 1.0))
	rotation_degrees = Vector3(-55.0, 45.0, 0.0)
