extends Node3D
class_name ToxicPuddle3D

@export var damage_per_tick: float = 6.0
@export var tick_interval: float = 0.5
@export var duration: float = 5.0

var tick_timer: float = 0.0
var lifetime: float = 0.0
var is_active: bool = true
var overlapping_player: CharacterBody3D = null

@onready var area: Area3D = $Area3D
@onready var decal: Decal = $Decal
@onready var particles: CPUParticles3D = $CPUParticles3D

func _ready() -> void:
	if area:
		area.body_entered.connect(_on_body_entered)
		area.body_exited.connect(_on_body_exited)

func _physics_process(delta: float) -> void:
	if not is_active:
		return
	
	lifetime += delta
	tick_timer += delta
	
	if tick_timer >= tick_interval:
		tick_timer = 0.0
		if overlapping_player and is_instance_valid(overlapping_player):
			if overlapping_player.has_method("take_damage"):
				overlapping_player.take_damage(damage_per_tick)
				if Engine.has_singleton("Global") or "Global" in get_tree().root:
					Global.play_sound("hit")
	
	# Shrink and fade before despawn
	if lifetime >= duration - 0.6:
		scale = scale.move_toward(Vector3.ZERO, delta * 1.8)
	
	if lifetime >= duration:
		is_active = false
		queue_free()

func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("player") or body.is_in_group("player3d"):
		overlapping_player = body as CharacterBody3D

func _on_body_exited(body: Node3D) -> void:
	if body == overlapping_player:
		overlapping_player = null
