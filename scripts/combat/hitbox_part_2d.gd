class_name HitboxPart2D
extends Area2D

## Modular Anatomical Hitbox Component (2D)
## Attached to individual anatomical zones (Head, Torso, Limbs, Weakpoint)
## Maps precision collisions to accurate damage multipliers (e.g. 2.0x Headshot, 2.5x Weakpoint).

enum BodyZone { HEAD, TORSO, LIMBS, WEAKPOINT }

@export var zone: BodyZone = BodyZone.TORSO
@export var damage_multiplier: float = 1.0
@export var parent_entity: Node2D

func _ready() -> void:
	# Layer 5 (value 16) specifically dedicated to Hitbox registration
	collision_layer = 16
	collision_mask = 0
	monitoring = false
	monitorable = true
	
	# Auto-resolve parent entity if not explicitly wired in inspector
	if parent_entity == null:
		var curr: Node = get_parent()
		while curr != null:
			if curr is CharacterBody2D or curr.is_in_group("enemies"):
				parent_entity = curr as Node2D
				break
			curr = curr.get_parent()

func receive_damage(raw_damage: float, hit_direction: Vector2 = Vector2.ZERO) -> Dictionary:
	if parent_entity == null or not is_instance_valid(parent_entity):
		var curr: Node = get_parent()
		while curr != null:
			if curr is CharacterBody2D or curr.is_in_group("enemies"):
				parent_entity = curr as Node2D
				break
			curr = curr.get_parent()
	
	var final_damage: float = raw_damage * damage_multiplier
	var is_crit: bool = (damage_multiplier > 1.0)
	
	# Dispatch damage to parent entity
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
