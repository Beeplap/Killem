extends Node

func _ready() -> void:
	print("=== RUNNING PHANTOM CAMERA PLUGIN INTEGRATION VERIFICATION ===")
	
	# 1. Verify Project Settings Plugin & Autoload
	var editor_plugins = ProjectSettings.get_setting("editor_plugins/enabled", PackedStringArray())
	assert(editor_plugins.has("res://addons/phantom_camera"), "Phantom Camera plugin must be enabled in project.godot [editor_plugins]")
	print("✔ 1. Phantom Camera plugin enabled in [editor_plugins]")
	
	var pcam_mgr = get_node_or_null("/root/PhantomCameraManager")
	assert(pcam_mgr != null, "PhantomCameraManager autoload must be running at /root/PhantomCameraManager")
	print("✔ 2. PhantomCameraManager autoload singleton running")
	
	# 2. Instantiate MainLevel and verify camera architecture
	var main_scene = load("res://scenes/MainLevel.tscn")
	assert(main_scene != null, "MainLevel.tscn must load successfully")
	var level = main_scene.instantiate()
	add_child(level)
	
	var cam_controller = level.get_node_or_null("CameraController")
	assert(cam_controller != null, "MainLevel must contain CameraController node")
	assert(cam_controller is CameraController, "CameraController must extend CameraController script")
	
	var main_cam: Camera2D = cam_controller.main_camera
	assert(main_cam != null, "CameraController must have primary MainCamera2D")
	assert(not main_cam.ignore_rotation, "MainCamera2D ignore_rotation must be false for rotational trauma shake")
	
	var host = cam_controller.host
	assert(host != null, "MainCamera2D must have PhantomCameraHost child")
	assert(host is PhantomCameraHost, "host node must be a PhantomCameraHost instance")
	print("✔ 3. MainCamera2D and PhantomCameraHost verified")
	
	# 3. Verify Player Phantom Camera properties
	var player_pcam: PhantomCamera2D = cam_controller.player_pcam
	assert(player_pcam != null, "CameraController must have PlayerPhantomCamera2D")
	assert(player_pcam.priority == 10, "PlayerPhantomCamera2D default priority must be 10")
	assert(player_pcam.follow_mode == PhantomCamera2D.FollowMode.SIMPLE or player_pcam.follow_mode == PhantomCamera2D.FollowMode.GLUED, "Player PCam follow_mode must be SIMPLE or GLUED")
	assert(player_pcam.follow_damping == true, "Player PCam follow_damping must be enabled")
	assert(player_pcam.follow_damping_value == Vector2(0.15, 0.15), "Player PCam damping factor must be 0.15")
	assert(player_pcam.follow_target == level.get_node("Player"), "Player PCam follow_target must be Player node")
	print("✔ 4. PlayerPhantomCamera2D damping, follow mode, and target verified")
	
	# 4. Verify Aiming Lookahead
	assert(cam_controller.lookahead_enabled == true, "Aiming lookahead must be enabled")
	# Simulate looking 300px to the right
	var player = level.get_node("Player")
	player.global_position = Vector2(0, 0)
	# Process delta frames to let lookahead lerp
	for i in range(30):
		cam_controller._process(0.016)
	
	# Emulate aim lookahead toward target (200, 0)
	var test_aim = Vector2(200.0, 0.0)
	var expected_lookahead = test_aim * cam_controller.lookahead_weight
	cam_controller.current_lookahead_offset = expected_lookahead
	cam_controller._handle_aiming_lookahead(0.016)
	assert(player_pcam.follow_offset.length() > 0.0, "Aiming lookahead must update player_pcam.follow_offset")
	print("✔ 5. Aiming downrange lookahead hook verified")
	
	# 5. Verify Rotational Trauma Shake
	# Test Weapon fire trauma
	Global.current_weapon = Global.WeaponType.SHOTGUN
	cam_controller._on_player_fired()
	assert(cam_controller.trauma >= 0.40, "Shotgun fire must add high trauma (>= 0.40), got: %f" % cam_controller.trauma)
	
	# Test Explosion trauma
	cam_controller._on_explosion_occurred()
	assert(cam_controller.trauma >= 0.65, "Explosion must trigger high trauma (>= 0.65), got: %f" % cam_controller.trauma)
	
	# Test AK / Assault Rifle has zero trauma (as requested by user)
	cam_controller.trauma = 0.0
	Global.current_weapon = Global.WeaponType.ASSAULT_RIFLE
	cam_controller._on_player_fired()
	assert(cam_controller.trauma == 0.0, "Assault Rifle must have zero screen shake trauma")
	
	# Process trauma shake decay
	cam_controller.trauma = 0.5
	cam_controller._handle_trauma_shake(0.05)
	assert(cam_controller.trauma < 0.5, "Trauma must decay smoothly over time")
	print("✔ 6. Dynamic rotational trauma shake (shotgun, explosion, AK zero-shake) verified")
	
	# 6. Verify Boss Encounter Framing & Secondary PhantomCamera
	var boss_pcam: PhantomCamera2D = cam_controller.boss_pcam
	assert(boss_pcam != null, "CameraController must have BossPhantomCamera2D")
	assert(boss_pcam.follow_mode == PhantomCamera2D.FollowMode.GROUP, "Boss PCam follow_mode must be GROUP (3)")
	assert(boss_pcam.auto_zoom == true, "Boss PCam auto_zoom must be enabled")
	assert(boss_pcam.priority == 0, "Boss PCam must be priority 0 when inactive")
	
	# Create a mock boss node to test encounter framing
	var mock_boss = Node2D.new()
	mock_boss.name = "MockColossusBoss"
	mock_boss.position = Vector2(500, 300)
	level.add_child(mock_boss)
	
	# Trigger boss encounter
	cam_controller.trigger_boss_encounter(mock_boss)
	assert(boss_pcam.priority == 25, "Boss PCam priority must be 25 when boss encounter triggers")
	assert(boss_pcam.priority > player_pcam.priority, "Boss PCam must override Player PCam priority")
	assert(boss_pcam.follow_targets.has(player) and boss_pcam.follow_targets.has(mock_boss), "Boss PCam follow_targets must contain both player and boss")
	print("✔ 7. Boss encounter group framing transition (priority 25, targets=[player, boss]) verified")
	
	# Defeat boss and verify return to player camera
	cam_controller.end_boss_encounter()
	assert(boss_pcam.priority == 0, "Boss PCam priority must return to 0 when boss is defeated")
	print("✔ 8. Return to Player PCam after boss defeat verified")
	
	print("\n=== ALL PHANTOM CAMERA CHECKS PASSED WITH FLYING COLORS! ===")
	level.queue_free()
	get_tree().quit(0)
