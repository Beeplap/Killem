extends BaseZombie3D
class_name ShamblerZombie3D

## High-Detail 3D Shambler Zombie with Procedural Clothing Variations
## Supports multiple outfit styles (Flannel Shirt, Tank Top + Bandana, Denim Workwear)
## and dynamic color palettes so that every zombie in the horde wears distinct clothes.

enum OutfitStyle { FLANNEL_SHIRT, TANK_TOP, DENIM_WORKWEAR, CONVICT_HAZARD }

@export var outfit_style: OutfitStyle = OutfitStyle.FLANNEL_SHIRT

var walk_cycle: float = 0.0

@onready var torso_node: Node3D = $Visuals/Torso
@onready var head_node: Node3D = $Visuals/Torso/Head
@onready var left_arm: Node3D = $Visuals/Torso/LeftArm
@onready var right_arm: Node3D = $Visuals/Torso/RightArm
@onready var left_leg: Node3D = get_node_or_null("Visuals/LeftLeg")
@onready var right_leg: Node3D = get_node_or_null("Visuals/RightLeg")

@onready var flannel_mesh: MeshInstance3D = get_node_or_null("Visuals/Torso/FlannelShirt")
@onready var tank_mesh: MeshInstance3D = get_node_or_null("Visuals/Torso/TankTop")
@onready var bandana_mesh: MeshInstance3D = get_node_or_null("Visuals/Torso/Head/Bandana")
@onready var left_sleeve: MeshInstance3D = get_node_or_null("Visuals/Torso/LeftArm/Sleeve")
@onready var right_sleeve: MeshInstance3D = get_node_or_null("Visuals/Torso/RightArm/Sleeve")

func _ready() -> void:
	max_hp = 90.0
	move_speed = 2.8
	attack_damage = 15.0
	attack_range = 1.35
	attack_cooldown = 1.0
	score_value = 100
	turn_speed = 9.0
	
	_apply_random_clothing_variation()
	super._ready()

func _apply_random_clothing_variation() -> void:
	# Randomly choose clothing style
	var styles = [OutfitStyle.FLANNEL_SHIRT, OutfitStyle.TANK_TOP, OutfitStyle.DENIM_WORKWEAR, OutfitStyle.CONVICT_HAZARD]
	outfit_style = styles.pick_random()
	
	match outfit_style:
		OutfitStyle.FLANNEL_SHIRT:
			if flannel_mesh: flannel_mesh.visible = true
			if tank_mesh: tank_mesh.visible = false
			if bandana_mesh: bandana_mesh.visible = false
			if left_sleeve: left_sleeve.visible = true
			if right_sleeve: right_sleeve.visible = true
			
		OutfitStyle.TANK_TOP:
			# Garwalfs Model 3: Olive tank top + Red bandana
			if flannel_mesh: flannel_mesh.visible = false
			if tank_mesh: tank_mesh.visible = true
			if bandana_mesh: bandana_mesh.visible = true
			if left_sleeve: left_sleeve.visible = false
			if right_sleeve: right_sleeve.visible = false
			
		OutfitStyle.DENIM_WORKWEAR:
			if flannel_mesh:
				flannel_mesh.visible = true
				# Tint to blue denim
				var mat = flannel_mesh.get_active_material(0)
				if mat:
					var dup_mat = mat.duplicate()
					dup_mat.albedo_color = Color(0.4, 0.65, 1.0)
					flannel_mesh.material_override = dup_mat
					if left_sleeve: left_sleeve.material_override = dup_mat
					if right_sleeve: right_sleeve.material_override = dup_mat
			if tank_mesh: tank_mesh.visible = false
			if bandana_mesh: bandana_mesh.visible = false
			
		OutfitStyle.CONVICT_HAZARD:
			if flannel_mesh:
				flannel_mesh.visible = true
				var mat = flannel_mesh.get_active_material(0)
				if mat:
					var dup_mat = mat.duplicate()
					dup_mat.albedo_color = Color(1.1, 0.65, 0.2) # Orange hazard
					flannel_mesh.material_override = dup_mat
					if left_sleeve: left_sleeve.material_override = dup_mat
					if right_sleeve: right_sleeve.material_override = dup_mat
			if tank_mesh: tank_mesh.visible = false
			if bandana_mesh: bandana_mesh.visible = false

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
		if left_leg and right_leg:
			left_leg.rotation.x = sin(walk_cycle) * 0.45
			right_leg.rotation.x = -sin(walk_cycle) * 0.45
	else:
		if left_arm and right_arm:
			left_arm.rotation.x = lerp_angle(left_arm.rotation.x, deg_to_rad(-55.0), delta * 8.0)
			right_arm.rotation.x = lerp_angle(right_arm.rotation.x, deg_to_rad(-55.0), delta * 8.0)
		if left_leg and right_leg:
			left_leg.rotation.x = lerp_angle(left_leg.rotation.x, 0.0, delta * 8.0)
			right_leg.rotation.x = lerp_angle(right_leg.rotation.x, 0.0, delta * 8.0)

func perform_melee_attack() -> void:
	# Lunge attack visual animation
	if left_arm and right_arm:
		left_arm.rotation.x = deg_to_rad(-110.0)
		right_arm.rotation.x = deg_to_rad(-110.0)
	super.perform_melee_attack()
