class_name HitboxPart3D
extends Area3D

enum BodyZone { HEAD, TORSO, LIMBS, WEAKPOINT }

@export var zone: BodyZone = BodyZone.TORSO
@export var damage_multiplier: float = 1.0
@export var parent_entity: Node3D

func _ready() -> void:
	# Set collision layer specifically to Hitbox layer (Layer 5 / bitmask value 16)
	collision_layer = 16
	collision_mask = 0
	monitoring = false
	monitorable = true
	
	# Auto-resolve parent entity if not explicitly wired in the inspector
	if parent_entity == null:
		var curr: Node = get_parent()
		while curr != null:
			if curr is CharacterBody3D or curr.is_in_group("enemies"):
				parent_entity = curr as Node3D
				break
			curr = curr.get_parent()

func receive_damage(raw_damage: float, hit_direction: Vector3 = Vector3.ZERO) -> Dictionary:
	var final_damage: float = raw_damage * damage_multiplier
	var is_crit: bool = (damage_multiplier > 1.0)
	
	# Notify parent entity
	if parent_entity and is_instance_valid(parent_entity):
		if parent_entity.has_method("apply_damage"):
			parent_entity.apply_damage(final_damage, is_crit, hit_direction, int(zone))
		elif parent_entity.has_method("take_damage"):
			parent_entity.take_damage(final_damage, hit_direction)
	
	return {
		"damage": final_damage,
		"is_crit": is_crit,
		"zone": zone,
		"multiplier": damage_multiplier
	}
