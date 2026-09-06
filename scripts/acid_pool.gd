extends Area2D

@export var duration: float = 6.0
@export var damage_per_second: float = 16.0
@export var tick_rate: float = 0.25

var life_timer: float = 6.0
var tick_timer: float = 0.0
var player_inside: bool = false
var player_ref: Node2D = null

@onready var sprite: Sprite2D = $Sprite2D
@onready var acid_light: PointLight2D = $PointLight2D
@onready var bubble_particles: CPUParticles2D = $CPUParticles2D

func _ready() -> void:
	life_timer = duration
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	area_entered.connect(_on_area_entered)
	cleanse_ground()

func _process(delta: float) -> void:
	life_timer -= delta
	tick_timer -= delta
	
	# Light pulse
	if acid_light:
		acid_light.energy = 0.85 + sin(life_timer * 6.0) * 0.25
	
	if tick_timer <= 0.0:
		tick_timer = tick_rate
		if player_inside and is_instance_valid(player_ref) and player_ref.has_method("take_damage"):
			player_ref.take_damage(damage_per_second * tick_rate)
	
	# Fade out during last 0.8s
	if life_timer <= 0.8:
		var alpha = life_timer / 0.8
		modulate.a = alpha
		if acid_light:
			acid_light.energy = alpha * 0.8
	
	if life_timer <= 0.0:
		queue_free()

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		player_inside = true
		player_ref = body

func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		player_inside = false

func _on_area_entered(area: Area2D) -> void:
	if area.is_in_group("blood_splat") or area.is_in_group("corpse"):
		area.queue_free()

func cleanse_ground() -> void:
	# Dissolve any existing blood splats in vicinity
	var level = get_tree().current_scene
	if level:
		for child in level.get_children():
			if child.is_in_group("blood_splats") or child.name.begins_with("BloodSplat"):
				if global_position.distance_to(child.global_position) < 60.0:
					child.queue_free()
