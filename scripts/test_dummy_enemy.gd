extends CharacterBody3D

var took_damage: bool = false

func take_damage(_dmg: float, _dir: Vector3) -> void:
	took_damage = true
