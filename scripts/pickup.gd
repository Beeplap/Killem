extends Area2D

enum PickupType { HEALTH, AMMO }

@export var pickup_type: PickupType = PickupType.HEALTH
@export var health_amount: float = 35.0

var pulse_time: float = 0.0

@onready var sprite: Sprite2D = $Sprite2D

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	pulse_time = randf() * TAU
	if sprite:
		if pickup_type == PickupType.HEALTH:
			sprite.texture = load("res://assets/textures/props/pickup_health.png")
		else:
			sprite.texture = load("res://assets/textures/props/pickup_ammo.png")

func _process(delta: float) -> void:
	pulse_time += delta * 4.0
	if sprite:
		sprite.position.y = sin(pulse_time) * 3.0

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		if pickup_type == PickupType.HEALTH:
			Global.heal_player(health_amount)
			Global.play_sound("pickup_health", global_position)
		elif pickup_type == PickupType.AMMO:
			Global.add_ammo_crate()
			Global.play_sound("pickup_ammo", global_position)
		else:
			Global.play_sound("pickup", global_position)
		
		queue_free()
