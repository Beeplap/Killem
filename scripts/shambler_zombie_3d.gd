extends BaseZombie3D
class_name ShamblerZombie3D

var walk_cycle: float = 0.0

@onready var torso_node: Node3D = $Visuals/Torso
@onready var head_node: Node3D = $Visuals/Torso/Head
@onready var left_arm: Node3D = $Visuals/Torso/LeftArm
@onready var right_arm: Node3D = $Visuals/Torso/RightArm

func _ready() -> void:
	max_hp = 90.0
	move_speed = 2.8
	attack_damage = 15.0
	attack_range = 1.35
	attack_cooldown = 1.0
	score_value = 100
	turn_speed = 9.0
	super._ready()

func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	
	if is_dead:
		return
	
	# Procedural shuffling gait animation
	var horiz_speed = Vector2(velocity.x, velocity.z).length()
	if horiz_speed > 0.2:
		walk_cycle += delta * 6.5
		if torso_node:
			torso_node.rotation.z = sin(walk_cycle) * 0.08
			torso_node.rotation.y = sin(walk_cycle * 0.5) * 0.06
		if left_arm and right_arm:
			left_arm.rotation.x = deg_to_rad(-70.0) + sin(walk_cycle) * 0.28
			right_arm.rotation.x = deg_to_rad(-70.0) - sin(walk_cycle) * 0.28
		if head_node:
			head_node.rotation.x = sin(walk_cycle * 2.0) * 0.05
	else:
		if left_arm and right_arm:
			left_arm.rotation.x = lerp_angle(left_arm.rotation.x, deg_to_rad(-55.0), delta * 8.0)
			right_arm.rotation.x = lerp_angle(right_arm.rotation.x, deg_to_rad(-55.0), delta * 8.0)

func perform_melee_attack() -> void:
	# Lunge attack visual animation
	if left_arm and right_arm:
		left_arm.rotation.x = deg_to_rad(-110.0)
		right_arm.rotation.x = deg_to_rad(-110.0)
	super.perform_melee_attack()
