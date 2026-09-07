class_name CameraController
extends Node2D

## Dynamic Combat Camera Controller powered by Phantom Camera
## Manages PhantomCameraHost, PlayerPhantomCamera2D, and BossPhantomCamera2D
## Features:
## - Smooth positional damping tracking player (damping = true, factor 0.15)
## - Aiming lookahead: offsets camera target downrange toward mouse crosshair
## - Dynamic rotational trauma shake for weapon firing, shotgun blasts, and explosions
## - Boss encounter framing: smoothly tweens to frame both player and boss via target group framing

@onready var main_camera: Camera2D = get_node_or_null("MainCamera2D")
@onready var host: PhantomCameraHost = get_node_or_null("MainCamera2D/PhantomCameraHost")
@onready var player_pcam: PhantomCamera2D = get_node_or_null("PlayerPhantomCamera2D")
@onready var boss_pcam: PhantomCamera2D = get_node_or_null("BossPhantomCamera2D")

@export var player: Node2D = null

# Aiming lookahead parameters
@export var lookahead_enabled: bool = true
@export var max_lookahead_dist: float = 140.0
@export var lookahead_weight: float = 0.28
@export var lookahead_lerp_speed: float = 6.5
var current_lookahead_offset: Vector2 = Vector2.ZERO

# Trauma and dynamic rotational shake parameters
var trauma: float = 0.0
@export var trauma_decay: float = 2.4
@export var max_shake_roll: float = 0.065 # Radians (~3.7 degrees)
@export var max_shake_offset: Vector2 = Vector2(24.0, 18.0)

var active_boss_target: Node2D = null

func _ready() -> void:
	if not player:
		_find_player()
	
	_setup_cameras()
	
	# Connect to global signals
	if not Global.player_fired.is_connected(_on_player_fired):
		Global.player_fired.connect(_on_player_fired)
	if not Global.explosion_occurred.is_connected(_on_explosion_occurred):
		Global.explosion_occurred.connect(_on_explosion_occurred)
	if not Global.boss_spawned.is_connected(_on_boss_spawned):
		Global.boss_spawned.connect(_on_boss_spawned)
	if not Global.boss_defeated.is_connected(_on_boss_defeated):
		Global.boss_defeated.connect(_on_boss_defeated)
	if not Global.camera_trauma_requested.is_connected(add_trauma):
		Global.camera_trauma_requested.connect(add_trauma)

func _setup_cameras() -> void:
	if main_camera:
		main_camera.ignore_rotation = false # Critical for rotational trauma shake
	
	if player_pcam:
		player_pcam.priority = 10
		player_pcam.follow_mode = PhantomCamera2D.FollowMode.SIMPLE
		if player:
			player_pcam.follow_target = player
		player_pcam.follow_damping = true
		player_pcam.follow_damping_value = Vector2(0.15, 0.15)
	
	if boss_pcam:
		boss_pcam.priority = 0 # Inactive by default
		boss_pcam.follow_mode = PhantomCamera2D.FollowMode.GROUP
		if player:
			boss_pcam.follow_targets = [player]
		boss_pcam.follow_damping = true
		boss_pcam.follow_damping_value = Vector2(0.15, 0.15)
		boss_pcam.auto_zoom = true
		boss_pcam.auto_zoom_min = 0.65
		boss_pcam.auto_zoom_max = 1.15
		boss_pcam.auto_zoom_margin = Vector4(160.0, 120.0, 160.0, 120.0)
		
		# Configure smooth tween for boss encounter framing
		var tween_res = PhantomCameraTween.new()
		tween_res.duration = 1.2
		tween_res.transition = Tween.TRANS_CUBIC
		tween_res.ease = Tween.EASE_IN_OUT
		boss_pcam.tween_resource = tween_res

func _find_player() -> void:
	var p = get_tree().get_first_node_in_group("player")
	if p and p is Node2D:
		player = p
		if player_pcam:
			player_pcam.follow_target = player
		if boss_pcam and (boss_pcam.follow_targets.is_empty() or not boss_pcam.follow_targets.has(player)):
			var targets: Array[Node2D] = [player]
			if active_boss_target and is_instance_valid(active_boss_target):
				targets.append(active_boss_target)
			boss_pcam.follow_targets = targets

func _process(delta: float) -> void:
	if not is_instance_valid(player):
		_find_player()
		return
	
	_handle_aiming_lookahead(delta)
	_handle_trauma_shake(delta)

func _handle_aiming_lookahead(delta: float) -> void:
	if not lookahead_enabled or not player_pcam:
		return
	
	var mouse_pos = get_global_mouse_position()
	var to_mouse = mouse_pos - player.global_position
	var target_lookahead = to_mouse * lookahead_weight
	if target_lookahead.length() > max_lookahead_dist:
		target_lookahead = target_lookahead.normalized() * max_lookahead_dist
	
	current_lookahead_offset = current_lookahead_offset.lerp(target_lookahead, delta * lookahead_lerp_speed)
	player_pcam.follow_offset = current_lookahead_offset

func _handle_trauma_shake(delta: float) -> void:
	if trauma <= 0.0:
		return
	
	trauma = maxf(0.0, trauma - trauma_decay * delta)
	var shake = trauma * trauma # Quadratic trauma curve
	var roll = randf_range(-1.0, 1.0) * max_shake_roll * shake
	var offset = Vector2(
		randf_range(-1.0, 1.0) * max_shake_offset.x * shake,
		randf_range(-1.0, 1.0) * max_shake_offset.y * shake
	)
	
	var noise_transform = Transform2D(roll, offset)
	
	# Determine currently active PhantomCamera to deliver noise
	var active_pcam: PhantomCamera2D = player_pcam
	if boss_pcam and boss_pcam.priority > player_pcam.priority:
		active_pcam = boss_pcam
	
	if active_pcam:
		active_pcam.noise_emitted.emit(noise_transform)

func add_trauma(amount: float) -> void:
	trauma = clampf(trauma + amount, 0.0, 1.0)

func trigger_shake(intensity: float, _duration: float = 0.1) -> void:
	add_trauma(clampf(intensity * 0.06, 0.1, 0.85))

func _on_player_fired() -> void:
	match Global.current_weapon:
		Global.WeaponType.PISTOL:
			add_trauma(0.12)
		Global.WeaponType.SHOTGUN:
			add_trauma(0.42)
		Global.WeaponType.ASSAULT_RIFLE:
			# Screen shake removed completely for Assault Rifle / AK
			pass
		Global.WeaponType.FLAMETHROWER:
			add_trauma(0.04)
		Global.WeaponType.MINIGUN:
			add_trauma(0.08)

func _on_explosion_occurred() -> void:
	add_trauma(0.65)

func _on_boss_spawned(boss_node: Node2D) -> void:
	if not is_instance_valid(boss_node):
		return
	active_boss_target = boss_node
	if boss_pcam and player:
		boss_pcam.follow_targets = [player, boss_node]
		boss_pcam.priority = 25 # Smoothly tweens to frame both player and boss!

func _on_boss_defeated(_boss_node: Node2D) -> void:
	active_boss_target = null
	if boss_pcam:
		boss_pcam.priority = 0 # Smoothly tweens back to player_pcam

## API for tests and external encounters
func trigger_boss_encounter(boss_node: Node2D) -> void:
	_on_boss_spawned(boss_node)

func end_boss_encounter() -> void:
	_on_boss_defeated(null)
