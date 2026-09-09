class_name HordeDirector
extends Node2D

enum HordeEventType {
	NONE,
	FOG_DESCENT,
	SIEGE_ATTRITION,
	ALPHA_SIGNAL
}

const REGULAR_ZOMBIE_SCENE = preload("res://scenes/Zombie.tscn")
const SUPPLY_CRATE_SCENE = preload("res://scenes/SupplyCrate.tscn")

@export var enabled: bool = true
@export var min_wave_for_events: int = 3
@export var event_delay_in_wave: float = 18.0

var current_event: HordeEventType = HordeEventType.NONE
var event_timer: float = 0.0
var event_max_duration: float = 0.0
var wave_combat_time: float = 0.0
var wave_event_triggered: bool = false
var is_wave_active: bool = false
var current_wave: int = 1

# Fog Descent State
var fog_rect: ColorRect = null
var fog_mat: ShaderMaterial = null
var original_fog_density: float = 1.7
var original_fog_opacity: float = 0.08
var target_fog_density: float = 1.7
var target_fog_opacity: float = 0.08
var zombie_bus_idx: int = -1
var original_zombie_bus_volume: float = 0.0
var fog_groan_timer: float = 0.0

# Siege Attrition State
var siege_direction: Vector2 = Vector2.UP
var siege_dir_name: String = "North"
var siege_zombies_left_to_spawn: int = 0
var siege_spawn_timer: float = 0.0
var bunker_pos: Vector2 = Vector2(-460, 180)
var defensive_zone_marker: Node2D = null
var defensive_zone_ring: Node2D = null

# Alpha Signal State
var alpha_target_ref: Node2D = null
var alpha_defeated: bool = false

# Inner class for rendering animated tactical defense ring around bunker
class DefensivePerimeterVisual extends Node2D:
	var radius: float = 110.0
	func _process(_delta: float) -> void:
		queue_redraw()
	func _draw() -> void:
		var pulse = sin(Time.get_ticks_msec() * 0.007) * 0.5 + 0.5
		var col_outer = Color(0.2, 0.95, 0.5, 0.35 + pulse * 0.35)
		var col_inner = Color(1.0, 0.85, 0.2, 0.2 + pulse * 0.25)
		draw_arc(Vector2.ZERO, radius, 0.0, TAU, 48, col_outer, 2.5)
		draw_arc(Vector2.ZERO, radius - 10.0, 0.0, TAU, 36, col_inner, 1.5)

func _ready() -> void:
	add_to_group("horde_director")
	
	Global.wave_started.connect(_on_wave_started)
	Global.wave_cleared.connect(_on_wave_cleared)
	Global.player_died.connect(_on_player_died)
	
	zombie_bus_idx = AudioServer.get_bus_index("Zombies")
	if zombie_bus_idx != -1:
		original_zombie_bus_volume = AudioServer.get_bus_volume_db(zombie_bus_idx)
	
	_find_fog_rect()

func _find_fog_rect() -> void:
	var rect = get_tree().root.find_child("VolumetricFogRect", true, false)
	if rect and rect is ColorRect:
		fog_rect = rect
		if fog_rect.material is ShaderMaterial:
			fog_mat = fog_rect.material
			var d = fog_mat.get_shader_parameter("fog_density")
			if d != null and float(d) > 0.0:
				original_fog_density = float(d)
			var o = fog_mat.get_shader_parameter("overall_opacity")
			if o != null and float(o) > 0.0:
				original_fog_opacity = float(o)
			target_fog_density = original_fog_density
			target_fog_opacity = original_fog_opacity

func _process(delta: float) -> void:
	if not enabled or Global.is_game_over:
		return
	
	# Check for triggering tactical event during active wave
	if is_wave_active and not wave_event_triggered and current_wave >= min_wave_for_events:
		wave_combat_time += delta
		if wave_combat_time >= event_delay_in_wave:
			wave_event_triggered = true
			var roll = randf()
			if roll < 0.34:
				start_event(HordeEventType.FOG_DESCENT)
			elif roll < 0.67:
				start_event(HordeEventType.SIEGE_ATTRITION)
			else:
				start_event(HordeEventType.ALPHA_SIGNAL)
	
	# Process active event
	if current_event != HordeEventType.NONE:
		event_timer -= delta
		
		match current_event:
			HordeEventType.FOG_DESCENT:
				_process_fog_descent(delta)
			HordeEventType.SIEGE_ATTRITION:
				_process_siege_attrition(delta)
			HordeEventType.ALPHA_SIGNAL:
				_process_alpha_signal(delta)
		
		if event_timer <= 0.0:
			end_current_event(false)

func start_event(event_type: HordeEventType) -> void:
	if current_event != HordeEventType.NONE:
		end_current_event(true)
	
	current_event = event_type
	
	match event_type:
		HordeEventType.FOG_DESCENT:
			_init_fog_descent()
		HordeEventType.SIEGE_ATTRITION:
			_init_siege_attrition()
		HordeEventType.ALPHA_SIGNAL:
			_init_alpha_signal()

func _init_fog_descent() -> void:
	event_max_duration = 45.0
	event_timer = event_max_duration
	fog_groan_timer = 3.0
	
	_find_fog_rect()
	# Fog density increased by 300% (1.7 -> 5.1, opacity 0.08 -> 0.36)
	target_fog_density = 5.1
	target_fog_opacity = 0.36
	
	# Radar static
	var minimap = get_tree().get_first_node_in_group("minimap")
	if minimap and minimap.has_method("set_jammed"):
		minimap.set_jammed(true)
	
	# Boost zombie audio bus
	if zombie_bus_idx != -1:
		AudioServer.set_bus_volume_db(zombie_bus_idx, original_zombie_bus_volume + 5.0)
	
	Global.show_military_alert("CRITICAL THREAT: FOG DESCENT", "ATMOSPHERIC VOLATILITY +300% • SENSORS JAMMED • HOLD POSITION", Color(0.35, 0.85, 1.0))
	Global.horde_event_started.emit("FOG DESCENT")

func _process_fog_descent(delta: float) -> void:
	if fog_mat:
		var cur_d = fog_mat.get_shader_parameter("fog_density")
		var cur_o = fog_mat.get_shader_parameter("overall_opacity")
		if cur_d != null and cur_o != null:
			var new_d = lerpf(float(cur_d), target_fog_density, delta * 1.5)
			var new_o = lerpf(float(cur_o), target_fog_opacity, delta * 1.5)
			fog_mat.set_shader_parameter("fog_density", new_d)
			fog_mat.set_shader_parameter("overall_opacity", new_o)
	
	# Periodic louder groans
	fog_groan_timer -= delta
	if fog_groan_timer <= 0.0:
		fog_groan_timer = randf_range(4.5, 7.5)
		Global.play_sound("zombie_groan")

func _init_siege_attrition() -> void:
	event_max_duration = 38.0
	event_timer = event_max_duration
	siege_zombies_left_to_spawn = 42
	siege_spawn_timer = 0.0
	
	# Cardinal direction breach
	var dirs = [
		{"dir": Vector2.UP, "name": "North"},
		{"dir": Vector2.DOWN, "name": "South"},
		{"dir": Vector2.LEFT, "name": "West"},
		{"dir": Vector2.RIGHT, "name": "East"}
	]
	var pick = dirs.pick_random()
	siege_direction = pick["dir"]
	siege_dir_name = pick["name"]
	
	_create_defensive_bunker_marker()
	
	Global.show_military_alert("CRITICAL THREAT: SIEGE ATTRITION", "MASSIVE BREACH FROM %s • DEFEND BUNKER FOR AIRDROP" % siege_dir_name.to_upper(), Color(1.0, 0.35, 0.2))
	Global.horde_event_started.emit("SIEGE ATTRITION")

func _process_siege_attrition(delta: float) -> void:
	if siege_zombies_left_to_spawn > 0:
		siege_spawn_timer -= delta
		if siege_spawn_timer <= 0.0:
			siege_spawn_timer = 1.8
			var batch_count = mini(7, siege_zombies_left_to_spawn)
			_spawn_siege_batch(batch_count)
			siege_zombies_left_to_spawn -= batch_count

func _spawn_siege_batch(count: int) -> void:
	var player = get_tree().get_first_node_in_group("player")
	if not player:
		return
	
	var base_center = player.global_position
	
	for i in range(count):
		var offset = Vector2.ZERO
		if siege_direction == Vector2.UP:
			offset = Vector2(randf_range(-450, 450), randf_range(-820, -740))
		elif siege_direction == Vector2.DOWN:
			offset = Vector2(randf_range(-450, 450), randf_range(740, 820))
		elif siege_direction == Vector2.LEFT:
			offset = Vector2(randf_range(-860, -760), randf_range(-400, 400))
		elif siege_direction == Vector2.RIGHT:
			offset = Vector2(randf_range(760, 860), randf_range(-400, 400))
		
		var spawn_pos = base_center + offset
		var zombie = REGULAR_ZOMBIE_SCENE.instantiate()
		zombie.global_position = spawn_pos
		zombie.wave_number = current_wave
		zombie.speed = 175.0 # Fast walkers
		get_parent().call_deferred("add_child", zombie)

func _create_defensive_bunker_marker() -> void:
	if defensive_zone_marker == null:
		defensive_zone_marker = Node2D.new()
		defensive_zone_marker.name = "DefensiveBunkerZone"
		defensive_zone_marker.global_position = bunker_pos
		defensive_zone_marker.add_to_group("extraction_zone") # Draws flashing diamond on minimap
		if get_parent():
			get_parent().add_child(defensive_zone_marker)
		else:
			add_child(defensive_zone_marker)
	
	if defensive_zone_ring == null:
		var ring = DefensivePerimeterVisual.new()
		ring.name = "DefensivePerimeterVisual"
		ring.global_position = bunker_pos
		if get_parent():
			get_parent().add_child(ring)
		else:
			add_child(ring)
		defensive_zone_ring = ring

func _init_alpha_signal() -> void:
	event_max_duration = 30.0
	event_timer = event_max_duration
	alpha_defeated = false
	alpha_target_ref = null
	
	var player = get_tree().get_first_node_in_group("player")
	var spawn_pos = Vector2(0, 0)
	if player:
		var angle = randf() * TAU
		spawn_pos = player.global_position + Vector2(cos(angle), sin(angle)) * randf_range(500.0, 700.0)
	
	var alpha_zombie = REGULAR_ZOMBIE_SCENE.instantiate()
	alpha_zombie.global_position = spawn_pos
	alpha_zombie.wave_number = current_wave
	alpha_zombie.set_as_alpha_target()
	if get_parent():
		get_parent().add_child(alpha_zombie)
	else:
		add_child(alpha_zombie)
	alpha_target_ref = alpha_zombie
	
	Global.show_military_alert("EVENT: ALPHA SIGNAL", "ELIMINATE HIGH-VALUE ALPHA IN 30s TO STUN HORDE", Color(1.0, 0.55, 0.15))
	Global.horde_event_started.emit("ALPHA SIGNAL")

func _process_alpha_signal(_delta: float) -> void:
	if alpha_defeated:
		return
	
	if alpha_target_ref == null or not is_instance_valid(alpha_target_ref) or alpha_target_ref.get("current_health") <= 0.0:
		on_alpha_target_killed(alpha_target_ref)

func on_alpha_target_killed(target_node: Node2D) -> void:
	if current_event != HordeEventType.ALPHA_SIGNAL or alpha_defeated:
		return
	
	alpha_defeated = true
	var pos = target_node.global_position if is_instance_valid(target_node) else global_position
	
	# 1. Instantly stun all active zombies for 4s
	var enemies = get_tree().get_nodes_in_group("enemies")
	for e in enemies:
		if is_instance_valid(e) and e.has_method("stagger"):
			e.stagger(4.0)
	
	# 2. Reward 100 Scrap
	Global.add_scrap(100)
	
	# 3. Visual & Audio EMP Shockwave
	_spawn_emp_shockwave(pos)
	Global.play_sound("perk")
	Global.play_sound("electric_zap")
	
	Global.show_military_alert("ALPHA TARGET ELIMINATED", "+100 SCRAP REWARD • HORDE STUNNED (4s)", Color(0.3, 1.0, 0.45))
	end_current_event(false)

func _spawn_emp_shockwave(pos: Vector2) -> void:
	var level = get_tree().current_scene
	if not level:
		return
	
	var burst = CPUParticles2D.new()
	burst.global_position = pos
	burst.emitting = true
	burst.one_shot = true
	burst.explosiveness = 0.95
	burst.amount = 36
	burst.lifetime = 0.65
	burst.spread = 180.0
	burst.initial_velocity_min = 120.0
	burst.initial_velocity_max = 350.0
	burst.scale_amount_min = 3.5
	burst.scale_amount_max = 7.0
	burst.color = Color(0.25, 0.9, 1.0, 0.9)
	burst.finished.connect(burst.queue_free)
	level.add_child(burst)

func end_current_event(aborted: bool) -> void:
	var prev_event = current_event
	current_event = HordeEventType.NONE
	event_timer = 0.0
	
	match prev_event:
		HordeEventType.FOG_DESCENT:
			target_fog_density = original_fog_density
			target_fog_opacity = original_fog_opacity
			if fog_mat:
				fog_mat.set_shader_parameter("fog_density", original_fog_density)
				fog_mat.set_shader_parameter("overall_opacity", original_fog_opacity)
			
			var minimap = get_tree().get_first_node_in_group("minimap")
			if minimap and minimap.has_method("set_jammed"):
				minimap.set_jammed(false)
			
			if zombie_bus_idx != -1:
				AudioServer.set_bus_volume_db(zombie_bus_idx, original_zombie_bus_volume)
			
			if not aborted:
				Global.show_notification("ATMOSPHERE STABILIZED", "Atmospheric fog dispersed • Radar clear", Color(0.4, 0.9, 0.5))
			Global.horde_event_ended.emit("FOG DESCENT")
		
		HordeEventType.SIEGE_ATTRITION:
			if not aborted:
				_spawn_bunker_supply_crates()
				Global.show_military_alert("SIEGE DEFENSE SUCCESSFUL", "SUPPLY CRATES AIRDROPPED AT BUNKER LZ", Color(0.3, 1.0, 0.45))
			
			if defensive_zone_marker and is_instance_valid(defensive_zone_marker):
				defensive_zone_marker.queue_free()
				defensive_zone_marker = null
			if defensive_zone_ring and is_instance_valid(defensive_zone_ring):
				defensive_zone_ring.queue_free()
				defensive_zone_ring = null
			Global.horde_event_ended.emit("SIEGE ATTRITION")
		
		HordeEventType.ALPHA_SIGNAL:
			if not aborted and not alpha_defeated:
				if alpha_target_ref and is_instance_valid(alpha_target_ref) and alpha_target_ref.get("current_health") > 0:
					if alpha_target_ref.has_method("enrage"):
						alpha_target_ref.enrage(30.0)
					if "speed" in alpha_target_ref:
						alpha_target_ref.speed *= 1.45
					if "base_modulate" in alpha_target_ref:
						alpha_target_ref.base_modulate = Color(2.5, 0.3, 0.3, 1.0)
				Global.show_military_alert("ALPHA TARGET ESCAPED CONTROL", "MUTATION OVERCHARGE DETECTED", Color(1.0, 0.2, 0.2))
			Global.horde_event_ended.emit("ALPHA SIGNAL")

func _spawn_bunker_supply_crates() -> void:
	Global.play_sound("aircraft_flyby")
	var level = get_tree().current_scene
	if not level:
		level = get_parent()
	
	for offset in [Vector2(-35, 20), Vector2(35, 20)]:
		var crate = SUPPLY_CRATE_SCENE.instantiate()
		crate.global_position = bunker_pos + offset
		level.call_deferred("add_child", crate)

func _on_wave_started(wave_num: int) -> void:
	current_wave = wave_num
	is_wave_active = true
	wave_combat_time = 0.0
	wave_event_triggered = false

func _on_wave_cleared(_wave_num: int, _cooldown: float) -> void:
	is_wave_active = false
	if current_event != HordeEventType.NONE:
		end_current_event(false)

func _on_player_died() -> void:
	is_wave_active = false
	if current_event != HordeEventType.NONE:
		end_current_event(true)

func _exit_tree() -> void:
	if current_event != HordeEventType.NONE:
		end_current_event(true)
