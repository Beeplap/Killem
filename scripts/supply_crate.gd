extends Area2D

@export var capture_radius: float = 90.0
@export var capture_time_required: float = 5.0

var capture_progress: float = 0.0
var player_inside: bool = false
var is_captured: bool = false

@onready var sprite: Sprite2D = $Sprite2D
@onready var flare_light: PointLight2D = $FlareLight
@onready var smoke_particles: CPUParticles2D = $SmokeParticles

func _ready() -> void:
	add_to_group("objectives")
	collision_layer = 0
	collision_mask = 1 # Player layer
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	ProceduralTextures.add_drop_shadow(self, Vector2(0, 10), Vector2(0.9, 0.4))

func _process(delta: float) -> void:
	if is_captured:
		return
	
	# Smoke flare pulse
	if flare_light:
		flare_light.energy = 1.6 + sin(Time.get_ticks_msec() * 0.008) * 0.5
	
	if player_inside:
		capture_progress += delta
		queue_redraw()
		if capture_progress >= capture_time_required:
			complete_capture()
	elif capture_progress > 0.0:
		# Slow decay if player leaves zone
		capture_progress = max(0.0, capture_progress - delta * 0.5)
		queue_redraw()

func _draw() -> void:
	if is_captured:
		return
	
	# Draw perimeter zone
	draw_arc(Vector2.ZERO, capture_radius, 0.0, TAU, 36, Color(1.0, 0.4, 0.2, 0.25), 1.5)
	
	# Draw capture progress meter
	if capture_progress > 0.0:
		var pct = clampf(capture_progress / capture_time_required, 0.0, 1.0)
		var end_angle = -PI * 0.5 + pct * TAU
		draw_arc(Vector2.ZERO, capture_radius, -PI * 0.5, end_angle, 36, Color(0.3, 0.95, 0.4, 0.9), 3.5)

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		player_inside = true

func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		player_inside = false

func complete_capture() -> void:
	is_captured = true
	queue_redraw()
	
	# Grant Perk in sequence
	if not Global.perk_extended_mags:
		Global.unlock_perk("extended_mags")
	elif not Global.perk_armor_plating:
		Global.unlock_perk("armor_plating")
	elif not Global.perk_full_auto:
		Global.unlock_perk("full_auto")
	else:
		Global.perk_unlocked.emit("MAXIMUM OVERHAUL", "Full ammo replenishment and reinforced tactical defenses!")
	
	# Restock Deployables
	Global.deployable_barbed_wire += 2
	Global.deployable_claymores += 2
	Global.deployable_turrets += 1
	Global.deployables_updated.emit(Global.deployable_barbed_wire, Global.deployable_claymores, Global.deployable_turrets)
	
	# Ammo & Health surge
	Global.add_ammo_crate()
	Global.heal_player(50.0)
	
	# Victory FX
	var level = get_tree().current_scene
	if level:
		var burst = CPUParticles2D.new()
		burst.emitting = true
		burst.one_shot = true
		burst.explosiveness = 0.95
		burst.amount = 28
		burst.lifetime = 0.7
		burst.spread = 180.0
		burst.initial_velocity_min = 90.0
		burst.initial_velocity_max = 220.0
		burst.scale_amount_min = 2.5
		burst.scale_amount_max = 5.0
		burst.color = Color(0.3, 1.0, 0.4, 1.0)
		burst.global_position = global_position
		burst.finished.connect(burst.queue_free)
		level.add_child(burst)
	
	if flare_light:
		flare_light.color = Color(0.3, 1.0, 0.4, 1.0)
		flare_light.energy = 2.5
	
	var tween = create_tween()
	tween.tween_interval(1.5)
	tween.tween_property(self, "modulate:a", 0.0, 0.8)
	tween.tween_callback(queue_free)
