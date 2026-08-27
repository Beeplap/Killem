extends Area2D

enum PickupType { HEALTH, AMMO }

@export var pickup_type: PickupType = PickupType.HEALTH
@export var health_amount: float = 35.0

var pulse_time: float = 0.0

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	pulse_time = randf() * TAU

func _process(delta: float) -> void:
	pulse_time += delta * 4.0
	queue_redraw()

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		if pickup_type == PickupType.HEALTH:
			Global.heal_player(health_amount)
		elif pickup_type == PickupType.AMMO:
			Global.add_ammo_crate()
		
		Global.play_sound("pickup")
		queue_free()

func _draw() -> void:
	var scale_pulse = 1.0 + sin(pulse_time) * 0.1
	
	if pickup_type == PickupType.HEALTH:
		# Medical Kit
		var bg_rect = Rect2(-11 * scale_pulse, -11 * scale_pulse, 22 * scale_pulse, 22 * scale_pulse)
		draw_rect(bg_rect, Color(0.1, 0.15, 0.12), true)
		draw_rect(bg_rect, Color(0.2, 0.8, 0.3), false, 2.0)
		# Green Cross
		draw_rect(Rect2(-3 * scale_pulse, -8 * scale_pulse, 6 * scale_pulse, 16 * scale_pulse), Color(0.2, 0.9, 0.3))
		draw_rect(Rect2(-8 * scale_pulse, -3 * scale_pulse, 16 * scale_pulse, 6 * scale_pulse), Color(0.2, 0.9, 0.3))
	else:
		# Ammo Box
		var bg_rect = Rect2(-12 * scale_pulse, -10 * scale_pulse, 24 * scale_pulse, 20 * scale_pulse)
		draw_rect(bg_rect, Color(0.2, 0.18, 0.1), true)
		draw_rect(bg_rect, Color(0.9, 0.75, 0.2), false, 2.0)
		# Ammo cartridges icon
		draw_rect(Rect2(-6 * scale_pulse, -5 * scale_pulse, 3 * scale_pulse, 10 * scale_pulse), Color(1.0, 0.85, 0.2))
		draw_rect(Rect2(-1 * scale_pulse, -5 * scale_pulse, 3 * scale_pulse, 10 * scale_pulse), Color(1.0, 0.85, 0.2))
		draw_rect(Rect2(4 * scale_pulse, -5 * scale_pulse, 3 * scale_pulse, 10 * scale_pulse), Color(1.0, 0.85, 0.2))
