extends CharacterBody2D

@export var move_speed: float = 240.0
@export var acceleration: float = 2800.0
@export var friction: float = 3200.0

@onready var camera: Camera2D = get_node_or_null("Camera2D")
@onready var muzzle: Marker2D = $Muzzle
@onready var sprite: Sprite2D = $Sprite2D
@onready var flashlight: PointLight2D = get_node_or_null("Flashlight")
@onready var muzzle_flash: PointLight2D = get_node_or_null("MuzzleFlash")
@onready var weapon_mount: PlayerWeapons2D = get_node_or_null("WeaponMount")
@onready var placement_ghost: PlacementGhost = get_node_or_null("PlacementGhost")

var target_zoom: Vector2 = Vector2(1.15, 1.15)
var min_zoom: Vector2 = Vector2(0.65, 0.65)
var max_zoom: Vector2 = Vector2(1.85, 1.85)

var fire_cooldown: float = 0.0
var invulnerability_timer: float = 0.0
var muzzle_flash_timer: float = 0.0

# Phasing Dodge Roll & Stamina State
var is_rolling: bool = false
var roll_timer: float = 0.0
var roll_dir: Vector2 = Vector2.ZERO
var ghost_trail_timer: float = 0.0
const ROLL_DURATION: float = 0.25
const ROLL_SPEED_MULT: float = 2.5

var stamina: float = 100.0
const MAX_STAMINA: float = 100.0
const DASH_STAMINA_COST: float = 50.0
const STAMINA_REGEN_RATE: float = 15.0 # 15.0/sec
const STAMINA_REGEN_DELAY: float = 0.8 # 0.8s delay after expenditure
var stamina_regen_delay_timer: float = 0.0

# Out-of-Combat Passive Health Regeneration
var time_since_last_damage: float = 0.0

# Health & Downed Revive State
var health: float = 100.0
var max_health: float = 100.0
var is_downed: bool = false
var bleed_out_timer: float = 30.0
const BLEED_OUT_DURATION: float = 30.0

signal player_took_damage(amount: float)
signal player_downed_state_changed(downed: bool)

# Deployable Mode [G] & Blueprint Placement
var deployable_mode: bool = false
var blueprint_rotation: float = 0.0
var active_deployable_type: int = 0 # 0: Grenade, 1: Barbwire, 2: Turret

# Minigun State
var minigun_spin_timer: float = 0.0
const MINIGUN_SPINUP_TIME: float = 0.40

const CASING_POOL_SCRIPT = preload("res://scripts/casing_pool.gd")

# Screen shake & Trauma system
var trauma: float = 0.0
@export var trauma_decay: float = 1.5
@export var max_shake_offset: Vector2 = Vector2(28.0, 20.0)
@export var max_shake_roll: float = 0.055

# Dependencies
var bullet_pool: Node2D = null
var casing_pool: Node2D = null
var tactical_crosshair: Control = null

func _enter_tree() -> void:
	if name.is_valid_int():
		set_multiplayer_authority(name.to_int())

func _ready() -> void:
	add_to_group("player")
	
	health = Global.player_health
	max_health = Global.player_max_health
	_setup_revive_zone()
	
	if name.is_valid_int():
		set_multiplayer_authority(name.to_int())
	
	_setup_network_synchronizer()
	_setup_player_indicator()
	
	var is_local = is_multiplayer_authority() if NetworkManager.is_network_active() else true
	
	if is_local:
		Global.health_changed.emit(Global.player_health, Global.player_max_health)
		Global.emit_current_ammo()
		Global.deployables_updated.emit(Global.deployable_grenades, Global.deployable_barbwire, Global.deployable_turrets)
		Global.roll_cooldown_updated.emit(stamina, MAX_STAMINA)
		Global.active_deployable_changed.connect(func(type: int):
			active_deployable_type = type
		)
		active_deployable_type = Global.active_deployable_type
		
		var cam_ctrl = get_tree().get_first_node_in_group("camera_controller")
		if cam_ctrl and cam_ctrl.has_method("set_player_target"):
			cam_ctrl.set_player_target(self)
	else:
		if placement_ghost:
			placement_ghost.visible = false
			placement_ghost.set_process(false)
	
	if placement_ghost:
		placement_ghost.set_armed(false)
	
	var detector = get_node_or_null("InteractionDetector")
	if detector == null and is_local:
		var detector_scene = preload("res://scenes/mechanics/InteractionDetector.tscn")
		detector = detector_scene.instantiate()
		add_child(detector)
	
	ProceduralTextures.add_drop_shadow(self, Vector2(0, 14), Vector2(0.85, 0.42))
	
	if muzzle_flash:
		muzzle_flash.enabled = false
	
	call_deferred("_find_dependencies")

func _setup_revive_zone() -> void:
	var revive_zone = get_node_or_null("ReviveZone")
	if revive_zone == null:
		var rz_scene = preload("res://scenes/mechanics/ReviveZone.tscn")
		revive_zone = rz_scene.instantiate()
		revive_zone.name = "ReviveZone"
		add_child(revive_zone)

func _setup_network_synchronizer() -> void:
	var sync = get_node_or_null("MultiplayerSynchronizer")
	if sync == null:
		sync = MultiplayerSynchronizer.new()
		sync.name = "MultiplayerSynchronizer"
		add_child(sync)
	
	sync.replication_interval = 0.033 # 30 Hz tick rate
	sync.delta_interval = 0.033
	var config = SceneReplicationConfig.new()
	config.add_property(NodePath(".:position"))
	config.property_set_replication_mode(NodePath(".:position"), SceneReplicationConfig.REPLICATION_MODE_ALWAYS)
	config.add_property(NodePath(".:rotation"))
	config.property_set_replication_mode(NodePath(".:rotation"), SceneReplicationConfig.REPLICATION_MODE_ALWAYS)
	config.add_property(NodePath(".:velocity"))
	config.property_set_replication_mode(NodePath(".:velocity"), SceneReplicationConfig.REPLICATION_MODE_ALWAYS)
	config.add_property(NodePath("Sprite2D:frame"))
	config.property_set_replication_mode(NodePath("Sprite2D:frame"), SceneReplicationConfig.REPLICATION_MODE_ALWAYS)
	config.add_property(NodePath("WeaponMount:rotation"))
	config.property_set_replication_mode(NodePath("WeaponMount:rotation"), SceneReplicationConfig.REPLICATION_MODE_ALWAYS)
	config.add_property(NodePath("WeaponMount:scale"))
	config.property_set_replication_mode(NodePath("WeaponMount:scale"), SceneReplicationConfig.REPLICATION_MODE_ALWAYS)
	config.add_property(NodePath(".:is_rolling"))
	config.property_set_replication_mode(NodePath(".:is_rolling"), SceneReplicationConfig.REPLICATION_MODE_ALWAYS)
	config.add_property(NodePath(".:is_downed"))
	config.property_set_replication_mode(NodePath(".:is_downed"), SceneReplicationConfig.REPLICATION_MODE_ALWAYS)
	sync.replication_config = config

func _setup_player_indicator() -> void:
	var label = Label.new()
	label.name = "SquadTag"
	var peer_id_num = name.to_int() if name.is_valid_int() else 1
	var is_local = is_multiplayer_authority() if NetworkManager.is_network_active() else true
	
	if peer_id_num == 1:
		label.text = "HOST" if not is_local else "YOU (HOST)"
	else:
		label.text = "P%d" % peer_id_num if not is_local else "YOU (P%d)" % peer_id_num
	
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.position = Vector2(-40, -38)
	label.custom_minimum_size = Vector2(80, 20)
	label.add_theme_font_size_override("font_size", 10)
	if is_local:
		label.add_theme_color_override("font_color", Color(0.3, 0.95, 0.55, 0.9))
	else:
		label.add_theme_color_override("font_color", Color(0.35, 0.75, 1.0, 0.85))
	add_child(label)

func _update_squad_tag() -> void:
	var label = get_node_or_null("SquadTag") as Label
	if not label:
		return
	var peer_id_num = name.to_int() if name.is_valid_int() else 1
	var is_local = is_multiplayer_authority() if NetworkManager.is_network_active() else true
	var name_prefix = "HOST" if peer_id_num == 1 else "P%d" % peer_id_num
	if is_local:
		name_prefix = "YOU (HOST)" if peer_id_num == 1 else "YOU (P%d)" % peer_id_num
	
	if is_downed:
		label.text = "%s [DOWNED %ds]" % [name_prefix, int(ceil(bleed_out_timer))]
		label.add_theme_color_override("font_color", Color(1.0, 0.25, 0.2, 1.0))
	else:
		label.text = name_prefix
		if is_local:
			label.add_theme_color_override("font_color", Color(0.3, 0.95, 0.55, 0.9))
		else:
			label.add_theme_color_override("font_color", Color(0.35, 0.75, 1.0, 0.85))

func _find_dependencies() -> void:
	bullet_pool = get_tree().get_first_node_in_group("bullet_pool")
	tactical_crosshair = get_tree().get_first_node_in_group("crosshair")
	
	casing_pool = get_tree().get_first_node_in_group("casing_pool")
	if casing_pool == null:
		var level = get_tree().current_scene
		if level:
			casing_pool = CASING_POOL_SCRIPT.new()
			casing_pool.name = "CasingPool"
			casing_pool.add_to_group("casing_pool")
			level.add_child(casing_pool)
	
	var damage_text_mgr = get_tree().get_first_node_in_group("damage_text_manager")
	if damage_text_mgr == null:
		var level = get_tree().current_scene
		if level:
			var dtm = DamageTextManager.new()
			dtm.name = "DamageTextManager"
			dtm.add_to_group("damage_text_manager")
			level.add_child(dtm)

func _unhandled_input(event: InputEvent) -> void:
	if Global.is_game_over:
		return
	if NetworkManager.is_network_active() and not is_multiplayer_authority():
		return
	
	if is_downed:
		# Downed players are locked to the Pistol and cannot deploy items or roll
		if event is InputEventKey and event.pressed:
			if event.keycode == KEY_R:
				if NetworkManager.is_network_active():
					net_reload.rpc()
				else:
					_execute_reload()
		return
	
	# Mouse Wheel: Blueprint Rotation (in deployable mode) OR Camera Zoom (in weapon mode)
	if event is InputEventMouseButton and event.pressed:
		if deployable_mode and placement_ghost and placement_ghost.is_armed:
			if event.button_index == MOUSE_BUTTON_WHEEL_UP:
				blueprint_rotation = fposmod(blueprint_rotation + deg_to_rad(15.0), TAU)
				placement_ghost.rotate_blueprint(deg_to_rad(15.0))
				get_viewport().set_input_as_handled()
				return
			elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				blueprint_rotation = fposmod(blueprint_rotation - deg_to_rad(15.0), TAU)
				placement_ghost.rotate_blueprint(-deg_to_rad(15.0))
				get_viewport().set_input_as_handled()
				return
		else:
			if event.button_index == MOUSE_BUTTON_WHEEL_UP:
				target_zoom = (target_zoom + Vector2(0.12, 0.12)).clamp(min_zoom, max_zoom)
			elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				target_zoom = (target_zoom - Vector2(0.12, 0.12)).clamp(min_zoom, max_zoom)
	
	if event is InputEventKey and event.pressed:
		# [G] Toggle Throwable/Deployable Mode on/off
		if event.keycode == KEY_G:
			toggle_deployable_mode()
			get_viewport().set_input_as_handled()
			return
		
		# Slot Selection [1], [2], [3] in Deployable Mode OR Weapons [1]-[5] in Normal Mode
		if deployable_mode:
			if event.keycode == KEY_1:
				active_deployable_type = 0
				Global.set_active_deployable(0)
				Global.play_sound("hit")
				get_viewport().set_input_as_handled()
				return
			elif event.keycode == KEY_2:
				active_deployable_type = 1
				Global.set_active_deployable(1)
				Global.play_sound("hit")
				get_viewport().set_input_as_handled()
				return
			elif event.keycode == KEY_3:
				active_deployable_type = 2
				Global.set_active_deployable(2)
				Global.play_sound("hit")
				get_viewport().set_input_as_handled()
				return
		else:
			if event.keycode == KEY_1:
				Global.set_weapon(Global.WeaponType.PISTOL)
			elif event.keycode == KEY_2:
				Global.set_weapon(Global.WeaponType.SHOTGUN)
			elif event.keycode == KEY_3:
				Global.set_weapon(Global.WeaponType.ASSAULT_RIFLE)
			elif event.keycode == KEY_4:
				Global.set_weapon(Global.WeaponType.FLAMETHROWER)
			elif event.keycode == KEY_5:
				Global.set_weapon(Global.WeaponType.MINIGUN)
		
		if event.keycode == KEY_R:
			if NetworkManager.is_network_active():
				net_reload.rpc()
			else:
				_execute_reload()
		elif event.keycode == KEY_SPACE:
			start_dodge_roll()
		elif event.keycode == KEY_E:
			# If near a serviceable deployable, let InteractionDetector handle holding [E]
			var detector = get_node_or_null("InteractionDetector")
			var has_serviceable = detector and (
				(detector.get("nearby_serviceables") and not detector.nearby_serviceables.is_empty()) or
				(detector.get("candidates") and not detector.candidates.is_empty())
			)
			var near_interactable = false
			for pod in get_tree().get_nodes_in_group("armory_pods"):
				if is_instance_valid(pod) and pod.get("player_in_range"):
					near_interactable = true
					break
			if not near_interactable:
				for drop in get_tree().get_nodes_in_group("supply_drops"):
					if is_instance_valid(drop) and drop.get("player_in_range"):
						near_interactable = true
						break
			
			if not has_serviceable and not near_interactable and deployable_mode:
				deploy_current_item()
		elif event.keycode == KEY_Q:
			cycle_deployable()

@rpc("any_peer", "call_local", "reliable")
func net_reload() -> void:
	_execute_reload()

func _execute_reload() -> void:
	PlayerShooting.play_reload_sequence(get_tree(), global_position)

func toggle_deployable_mode() -> void:
	if is_downed:
		return
	deployable_mode = not deployable_mode
	if placement_ghost:
		placement_ghost.set_armed(deployable_mode)
	if deployable_mode:
		Global.show_notification("DEPLOYABLE MODE: ARMED", "[1] Grenade • [2] Barbwire • [3] Turret • Wheel: Rotate • [E] Deploy", Color(0.2, 0.95, 0.55))
	else:
		Global.show_notification("WEAPON MODE: ACTIVE", "Standard Combat Firearms Enabled", Color(0.98, 0.82, 0.15))
	Global.play_sound("hit")

var step_accumulator: float = 0.0
const STEP_THRESHOLD_WALK: float = 42.0
const STEP_THRESHOLD_DASH: float = 28.0

func cycle_deployable() -> void:
	if is_downed:
		return
	Global.set_active_deployable(Global.active_deployable_type + 1)
	Global.play_sound("hit")

func start_dodge_roll() -> void:
	if is_rolling or is_downed or stamina < DASH_STAMINA_COST or Global.is_game_over:
		return
	
	stamina -= DASH_STAMINA_COST
	stamina_regen_delay_timer = STAMINA_REGEN_DELAY
	Global.roll_cooldown_updated.emit(stamina, MAX_STAMINA)
	
	var input_dir: Vector2 = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if input_dir == Vector2.ZERO:
		if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT): input_dir.x -= 1.0
		if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT): input_dir.x += 1.0
		if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP): input_dir.y -= 1.0
		if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN): input_dir.y += 1.0
	
	var chosen_dir: Vector2 = input_dir.normalized() if input_dir != Vector2.ZERO else (get_global_mouse_position() - global_position).normalized()
	
	if NetworkManager.is_network_active():
		net_start_dodge_roll.rpc(chosen_dir)
	else:
		_execute_dodge_roll(chosen_dir)

@rpc("any_peer", "call_local", "reliable")
func net_start_dodge_roll(dir: Vector2) -> void:
	_execute_dodge_roll(dir)

func _execute_dodge_roll(dir: Vector2) -> void:
	roll_dir = dir
	is_rolling = true
	roll_timer = ROLL_DURATION
	invulnerability_timer = max(invulnerability_timer, ROLL_DURATION + 0.05) # Full i-frames
	
	# Phasing: Disable enemy collision (Layer 2) while keeping obstacle collision (Layer 3) active
	set_collision_mask_value(2, false)
	
	velocity = roll_dir * (move_speed * ROLL_SPEED_MULT)
	ghost_trail_timer = 0.0
	spawn_ghost_trail()
	
	var audio_mgr = get_node_or_null("/root/AudioManager")
	if audio_mgr and audio_mgr.has_method("play_boot_skid"):
		audio_mgr.play_boot_skid(global_position)
	else:
		Global.play_sound("roll")

func spawn_ghost_trail() -> void:
	if sprite == null:
		return
	var ghost = Sprite2D.new()
	ghost.texture = sprite.texture
	ghost.hframes = sprite.hframes
	ghost.vframes = sprite.vframes
	ghost.frame = sprite.frame
	ghost.global_position = sprite.global_position
	ghost.scale = sprite.global_scale
	ghost.rotation = sprite.global_rotation
	ghost.modulate = Color(0.4, 0.75, 1.0, 0.55)
	ghost.z_index = z_index - 1
	var level = get_tree().current_scene
	if level:
		level.add_child(ghost)
		var tween = level.create_tween()
		tween.tween_property(ghost, "modulate:a", 0.0, 0.22)
		tween.tween_callback(ghost.queue_free)

func deploy_current_item() -> void:
	var level = get_tree().current_scene
	if not level:
		return
	
	var mouse_pos = get_global_mouse_position()
	var to_mouse = mouse_pos - global_position
	var target_deploy_pos = global_position + to_mouse.limit_length(180.0)
	if placement_ghost:
		target_deploy_pos = placement_ghost.global_position
		if not placement_ghost.is_valid_placement and active_deployable_type != 0:
			Global.play_sound("empty_click")
			return
	
	var place_rot = placement_ghost.blueprint_rotation if placement_ghost else to_mouse.angle()
	
	# Spend local supplies
	match active_deployable_type:
		0:
			if Global.deployable_grenades <= 0:
				Global.show_notification("OUT OF GRENADES", "Replenish via tactical supply drop", Color(0.95, 0.3, 0.2))
				Global.play_sound("empty_click")
				return
			Global.deployable_grenades -= 1
		1:
			if Global.deployable_barbwire <= 0:
				Global.show_notification("OUT OF BARBWIRE", "Replenish via tactical supply drop", Color(0.95, 0.3, 0.2))
				Global.play_sound("empty_click")
				return
			Global.deployable_barbwire -= 1
		2:
			var active_turrets = get_tree().get_nodes_in_group("turrets")
			if active_turrets.size() >= 5:
				Global.show_notification("TURRET LIMIT REACHED (5/5)", "Maximum map deployment capacity reached", Color(1.0, 0.3, 0.2))
				Global.deployable_warning_triggered.emit("TURRET LIMIT REACHED (5/5)")
				Global.play_sound("empty_click")
				return
			if Global.deployable_turrets <= 0:
				Global.show_notification("OUT OF TURRETS", "Replenish via tactical supply drop", Color(0.95, 0.3, 0.2))
				Global.play_sound("empty_click")
				return
			Global.deployable_turrets -= 1
	
	Global.deployables_updated.emit(Global.deployable_grenades, Global.deployable_barbwire, Global.deployable_turrets)
	
	if NetworkManager.is_network_active():
		net_deploy_item.rpc(active_deployable_type, target_deploy_pos, place_rot)
	else:
		_execute_deploy_item(active_deployable_type, target_deploy_pos, place_rot)

@rpc("any_peer", "call_local", "reliable")
func net_deploy_item(item_type: int, target_pos: Vector2, place_rot: float) -> void:
	_execute_deploy_item(item_type, target_pos, place_rot)

func _execute_deploy_item(item_type: int, target_pos: Vector2, place_rot: float) -> void:
	var level = get_tree().current_scene
	if not level:
		return
	match item_type:
		0:
			var grenade_scene = preload("res://scenes/weapons/Grenade.tscn")
			var g = grenade_scene.instantiate()
			level.add_child(g)
			g.launch(global_position, target_pos)
			Global.play_sound("hit")
		1:
			var wire_scene = preload("res://scenes/deployables/Barbwire.tscn")
			var wire = wire_scene.instantiate()
			wire.global_position = target_pos
			wire.rotation = place_rot
			level.add_child(wire)
			Global.play_sound("hit")
		2:
			var turret_scene = preload("res://scenes/deployables/Turret.tscn")
			var turret = turret_scene.instantiate()
			turret.global_position = target_pos
			if turret.has_method("setup_placement"):
				turret.setup_placement(place_rot)
			level.add_child(turret)
			Global.play_sound("hit")

func _physics_process(delta: float) -> void:
	if Global.is_game_over:
		velocity = velocity.move_toward(Vector2.ZERO, friction * delta)
		move_and_slide()
		return
	
	# Remote proxy handling in networked sessions
	if NetworkManager.is_network_active() and not is_multiplayer_authority():
		if is_downed:
			if sprite:
				sprite.modulate = Color(1.0, 0.45, 0.45, 0.85)
				sprite.rotation = PI * 0.5
		elif sprite and sprite.rotation != 0.0:
			sprite.rotation = 0.0
		_update_squad_tag()
		
		if is_rolling:
			ghost_trail_timer -= delta
			if ghost_trail_timer <= 0.0:
				ghost_trail_timer = 0.045
				spawn_ghost_trail()
		if invulnerability_timer > 0.0:
			invulnerability_timer -= delta
			if invulnerability_timer <= 0.0 and sprite and not is_downed:
				sprite.modulate = Color.WHITE
		if muzzle_flash_timer > 0.0:
			muzzle_flash_timer -= delta
			if muzzle_flash_timer <= 0.0 and muzzle_flash:
				muzzle_flash.enabled = false
		move_and_slide()
		return
	
	# Downed State Processing
	if is_downed:
		bleed_out_timer -= delta
		_update_squad_tag()
		check_all_players_downed()
		if bleed_out_timer <= 0.0:
			die()
			return
	
	# Stamina regeneration: 15.0/sec with 0.8s delay after expenditure
	if stamina_regen_delay_timer > 0.0:
		stamina_regen_delay_timer -= delta
	elif stamina < MAX_STAMINA and not is_downed:
		stamina = min(MAX_STAMINA, stamina + STAMINA_REGEN_RATE * delta)
		Global.roll_cooldown_updated.emit(stamina, MAX_STAMINA)
	
	# Out-of-Combat Passive Health Regeneration (3.0s after damage, 0.8% max HP/sec)
	if not is_downed:
		time_since_last_damage += delta
		if time_since_last_damage >= 3.0 and Global.player_health < Global.player_max_health and not Global.is_game_over:
			Global.player_health = min(Global.player_max_health, Global.player_health + Global.player_max_health * 0.008 * delta)
			health = Global.player_health
			Global.health_changed.emit(Global.player_health, Global.player_max_health)
	
	# Active Dodge Roll burst
	if is_rolling:
		roll_timer -= delta
		ghost_trail_timer -= delta
		if ghost_trail_timer <= 0.0:
			ghost_trail_timer = 0.045
			spawn_ghost_trail()
		
		velocity = roll_dir * (move_speed * ROLL_SPEED_MULT)
		move_and_slide()
		
		step_accumulator += velocity.length() * delta
		if step_accumulator >= STEP_THRESHOLD_DASH:
			step_accumulator = 0.0
			_play_surface_footstep()
		
		if roll_timer <= 0.0:
			is_rolling = false
			# Restore collision against Layer 2 zombies after phasing
			set_collision_mask_value(2, true)
			var audio_mgr = get_node_or_null("/root/AudioManager")
			if audio_mgr and audio_mgr.has_method("play_boot_skid"):
				audio_mgr.play_boot_skid(global_position)
		
		handle_camera_and_shake(delta)
		return
	
	handle_movement(delta)
	handle_aiming()
	handle_shooting(delta)
	handle_camera_and_shake(delta)
	
	if invulnerability_timer > 0.0:
		invulnerability_timer -= delta
		if invulnerability_timer <= 0.0 and sprite and not is_downed:
			sprite.modulate = Color.WHITE
	
	if muzzle_flash_timer > 0.0:
		muzzle_flash_timer -= delta
		if muzzle_flash_timer <= 0.0 and muzzle_flash:
			muzzle_flash.enabled = false

func handle_movement(delta: float) -> void:
	var input_dir: Vector2 = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if input_dir == Vector2.ZERO:
		if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT): input_dir.x -= 1.0
		if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT): input_dir.x += 1.0
		if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP): input_dir.y -= 1.0
		if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN): input_dir.y += 1.0
		input_dir = input_dir.normalized()
	
	var effective_speed = move_speed
	# Downed crawl penalty (speed * 0.25)
	if is_downed:
		effective_speed = move_speed * 0.25
	elif Global.current_weapon == Global.WeaponType.MINIGUN and minigun_spin_timer > 0.05:
		effective_speed *= 0.80
	
	if input_dir != Vector2.ZERO:
		velocity = velocity.move_toward(input_dir * effective_speed, acceleration * delta)
	else:
		velocity = velocity.move_toward(Vector2.ZERO, friction * delta)
	move_and_slide()
	
	if velocity.length_squared() > 100.0:
		step_accumulator += velocity.length() * delta
		if step_accumulator >= STEP_THRESHOLD_WALK:
			step_accumulator = 0.0
			_play_surface_footstep()

func _play_surface_footstep() -> void:
	var surface = "gravel"
	if global_position.y > 60.0 and global_position.y < 380.0:
		surface = "asphalt"
	elif global_position.x < -400.0:
		surface = "metal"
	
	var audio_mgr = get_node_or_null("/root/AudioManager")
	if audio_mgr and audio_mgr.has_method("play_footstep"):
		audio_mgr.play_footstep(surface, global_position)

func _get_active_deployable_stock() -> int:
	match active_deployable_type:
		0: return Global.deployable_grenades
		1: return Global.deployable_barbwire
		2: return Global.deployable_turrets
	return 0

func handle_aiming() -> void:
	var mouse_pos = get_global_mouse_position()
	var aim_dir = (mouse_pos - global_position).normalized()
	if Global.virtual_aim_active and Global.virtual_aim_dir != Vector2.ZERO:
		aim_dir = Global.virtual_aim_dir
		mouse_pos = global_position + aim_dir * 180.0
	var angle = aim_dir.angle()
	
	var dir_idx = int(round(angle / (PI / 4.0)))
	if dir_idx < 0:
		dir_idx += 8
	dir_idx = dir_idx % 8
	
	if sprite:
		sprite.frame = dir_idx
	
	if weapon_mount:
		weapon_mount.position = Vector2(0, -4)
		weapon_mount.rotation = angle
		if aim_dir.x < 0.0:
			weapon_mount.scale.y = -1.0
		else:
			weapon_mount.scale.y = 1.0
	
	if flashlight:
		flashlight.rotation = angle
		flashlight.position = aim_dir * 16.0 + Vector2(0, -4)
	
	if muzzle:
		var custom_muzzle = weapon_mount.get_muzzle_marker() if weapon_mount else null
		if custom_muzzle:
			muzzle.global_position = custom_muzzle.global_position
		else:
			muzzle.position = aim_dir * 26.0 + Vector2(0, -4)
		muzzle.rotation = angle
	
	if muzzle_flash:
		muzzle_flash.position = muzzle.position if muzzle else aim_dir * 26.0
	
	# Blueprint Hologram: only active and visible when Deployable Mode [G] is armed
	if placement_ghost:
		if deployable_mode:
			var turret_capped = (get_tree().get_nodes_in_group("turrets").size() >= 5)
			placement_ghost.update_ghost(global_position, mouse_pos, active_deployable_type, _get_active_deployable_stock(), turret_capped)
		else:
			placement_ghost.visible = false

func handle_shooting(delta: float) -> void:
	if fire_cooldown > 0.0:
		fire_cooldown -= delta
	
	var is_pressing_fire: bool = Input.is_action_pressed("shoot") or Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	
	# Rotary Minigun Spool-up handling
	if Global.current_weapon == Global.WeaponType.MINIGUN:
		if is_pressing_fire:
			minigun_spin_timer += delta
			if weapon_mount:
				weapon_mount.update_minigun_spin(delta, true, minigun_spin_timer / MINIGUN_SPINUP_TIME)
			if minigun_spin_timer < MINIGUN_SPINUP_TIME and fmod(minigun_spin_timer, 0.20) < delta:
				Global.play_sound("minigun_spin")
		else:
			minigun_spin_timer = max(0.0, minigun_spin_timer - delta * 2.5)
			if weapon_mount:
				weapon_mount.update_minigun_spin(delta, minigun_spin_timer > 0.05, minigun_spin_timer / MINIGUN_SPINUP_TIME)
	
	var wants_to_shoot: bool = false
	if Global.current_weapon == Global.WeaponType.ASSAULT_RIFLE or Global.current_weapon == Global.WeaponType.FLAMETHROWER:
		wants_to_shoot = is_pressing_fire
	elif Global.current_weapon == Global.WeaponType.MINIGUN:
		wants_to_shoot = is_pressing_fire and minigun_spin_timer >= MINIGUN_SPINUP_TIME
	else:
		# Pistol / Shotgun
		if Global.perk_full_auto and Global.current_weapon == Global.WeaponType.PISTOL:
			wants_to_shoot = is_pressing_fire
		else:
			wants_to_shoot = Input.is_action_just_pressed("shoot") or (is_pressing_fire and fire_cooldown <= 0.0)
	
	if wants_to_shoot and fire_cooldown <= 0.0:
		if not Global.has_ammo(Global.current_weapon):
			PlayerShooting.play_empty_click(global_position)
			fire_cooldown = 0.25
			return
		
		fire_weapon()

func fire_weapon() -> void:
	if bullet_pool == null:
		_find_dependencies()
	
	var base_dir: Vector2 = (get_global_mouse_position() - global_position).normalized()
	var custom_muzzle = weapon_mount.get_muzzle_marker() if weapon_mount else null
	var spawn_pos: Vector2 = custom_muzzle.global_position if custom_muzzle else global_position + base_dir * 32.0 + Vector2(0, -4)
	
	# Consume ammo locally on firing peer
	Global.consume_ammo(Global.current_weapon)
	
	if NetworkManager.is_network_active():
		net_fire_weapon.rpc(Global.current_weapon, spawn_pos, base_dir)
	else:
		_execute_fire_weapon(Global.current_weapon, spawn_pos, base_dir)

@rpc("any_peer", "call_local", "reliable")
func net_fire_weapon(w_type: int, spawn_pos: Vector2, shoot_dir: Vector2) -> void:
	_execute_fire_weapon(w_type, spawn_pos, shoot_dir)

func _execute_fire_weapon(w_type: int, spawn_pos: Vector2, shoot_dir: Vector2) -> void:
	if bullet_pool == null:
		_find_dependencies()
	
	# Apply visual procedural recoil kick
	if weapon_mount:
		var kick_amount = 3.5
		match w_type:
			Global.WeaponType.PISTOL: kick_amount = 3.0
			Global.WeaponType.SHOTGUN: kick_amount = 6.0
			Global.WeaponType.ASSAULT_RIFLE: kick_amount = 3.2
			Global.WeaponType.FLAMETHROWER: kick_amount = 1.5
			Global.WeaponType.MINIGUN: kick_amount = 2.0
		weapon_mount.apply_recoil_kick(kick_amount)
	
	# Eject brass casing (except flamethrower)
	if w_type != Global.WeaponType.FLAMETHROWER and casing_pool:
		var custom_eject = weapon_mount.get_ejection_marker() if weapon_mount else null
		var eject_pos = custom_eject.global_position if custom_eject else global_position + shoot_dir * 14.0 + Vector2(0, -2)
		casing_pool.spawn_casing(eject_pos, shoot_dir)
	
	if muzzle_flash and w_type != Global.WeaponType.FLAMETHROWER:
		muzzle_flash.enabled = true
		muzzle_flash_timer = 0.04
	
	var is_local = is_multiplayer_authority() if NetworkManager.is_network_active() else true
	if is_local:
		Global.player_fired.emit()
	
	var laser = muzzle.get_node_or_null("LaserSight") if muzzle else null
	if laser and laser.has_method("add_recoil_scatter"):
		laser.add_recoil_scatter(0.04)
	
	var dmg_mult: float = Global.get_damage_multiplier()
	var spd_mult: float = Global.get_bullet_speed_multiplier()
	
	match w_type:
		Global.WeaponType.PISTOL:
			if bullet_pool:
				bullet_pool.spawn_bullet(spawn_pos, shoot_dir, 38.0 * dmg_mult, 950.0 * spd_mult, 1.8)
			if is_local:
				fire_cooldown = 0.12 if Global.perk_full_auto else 0.20
				add_trauma(0.14)
				if tactical_crosshair:
					tactical_crosshair.add_bloom(6.5)
			PlayerShooting.play_weapon_fire_audio("pistol", global_position)
		
		Global.WeaponType.SHOTGUN:
			var pellet_count: int = 6
			var spread_angle: float = 0.28
			for i in range(pellet_count):
				var angle_offset: float = randf_range(-spread_angle * 0.5, spread_angle * 0.5)
				var pellet_dir: Vector2 = shoot_dir.rotated(angle_offset)
				if bullet_pool:
					bullet_pool.spawn_bullet(spawn_pos, pellet_dir, 24.0 * dmg_mult, 800.0 * spd_mult, 0.75)
			if is_local:
				fire_cooldown = 0.70
				add_trauma(0.44)
				if tactical_crosshair:
					tactical_crosshair.add_bloom(19.0)
			PlayerShooting.play_weapon_fire_audio("shotgun", global_position)
		
		Global.WeaponType.ASSAULT_RIFLE:
			var spread: float = randf_range(-0.06, 0.06)
			if bullet_pool:
				bullet_pool.spawn_bullet(spawn_pos, shoot_dir.rotated(spread), 32.0 * dmg_mult, 1050.0 * spd_mult, 1.8)
			if is_local:
				fire_cooldown = 0.095
				if tactical_crosshair:
					tactical_crosshair.add_bloom(9.5)
			PlayerShooting.play_weapon_fire_audio("rifle", global_position)
		
		Global.WeaponType.FLAMETHROWER:
			process_flame_cone(shoot_dir, spawn_pos)
			if is_local:
				fire_cooldown = 0.08
				add_trauma(0.06)
				if tactical_crosshair:
					tactical_crosshair.add_bloom(12.0)
			PlayerShooting.play_weapon_fire_audio("flame", global_position)
		
		Global.WeaponType.MINIGUN:
			var spread: float = randf_range(-0.11, 0.11)
			if bullet_pool:
				bullet_pool.spawn_bullet(spawn_pos, shoot_dir.rotated(spread), 28.0 * dmg_mult, 1150.0 * spd_mult, 1.6)
			if is_local:
				fire_cooldown = 0.05 # 20 rounds / sec
				add_trauma(0.12)
				if tactical_crosshair:
					tactical_crosshair.add_bloom(14.0)
			PlayerShooting.play_weapon_fire_audio("minigun_fire", global_position)

func process_flame_cone(base_dir: Vector2, spawn_pos: Vector2) -> void:
	var level = get_tree().current_scene
	if not level:
		return
	
	# High pressure flame stream particles
	var flame = CPUParticles2D.new()
	flame.emitting = true
	flame.one_shot = true
	flame.explosiveness = 0.5
	flame.amount = 18
	flame.lifetime = 0.32
	flame.direction = base_dir
	flame.spread = 24.0
	flame.initial_velocity_min = 400.0
	flame.initial_velocity_max = 680.0
	flame.scale_amount_min = 5.0
	flame.scale_amount_max = 16.0
	flame.color = Color(1.0, 0.65, 0.15, 0.9)
	flame.global_position = spawn_pos
	flame.finished.connect(flame.queue_free)
	level.add_child(flame)
	
	var flame_range = 250.0
	var flame_cos = cos(deg_to_rad(28.0))
	
	# Damage & ignite enemies in cone
	var enemies = get_tree().get_nodes_in_group("enemies")
	for enemy in enemies:
		if is_instance_valid(enemy):
			var diff = enemy.global_position - spawn_pos
			var dist = diff.length()
			if dist <= flame_range:
				var dir = diff.normalized()
				if base_dir.dot(dir) >= flame_cos:
					if enemy.has_method("take_damage"):
						enemy.take_damage(16.0 * Global.get_damage_multiplier(), dir)
					if enemy.has_method("ignite"):
						enemy.ignite(4.0, 32.0)
	
	# Ignite / damage destructibles
	var props = get_tree().get_nodes_in_group("destructibles")
	for prop in props:
		if is_instance_valid(prop) and not (prop.get("is_broken")) and not (prop.get("is_burned_out")):
			var diff = prop.global_position - spawn_pos
			if diff.length() <= flame_range:
				if base_dir.dot(diff.normalized()) >= flame_cos:
					if prop.has_method("take_damage"):
						prop.take_damage(26.0, base_dir)

func add_trauma(amount: float) -> void:
	trauma = clampf(trauma + amount, 0.0, 1.0)
	Global.camera_trauma_requested.emit(amount)

func trigger_shake(intensity: float, _duration: float = 0.1) -> void:
	add_trauma(clampf(intensity * 0.06, 0.1, 0.85))

func handle_camera_and_shake(delta: float) -> void:
	if camera:
		camera.zoom = camera.zoom.lerp(target_zoom, delta * 8.0)
		
		if trauma > 0.0:
			trauma = max(0.0, trauma - trauma_decay * delta)
			var shake = trauma * trauma
			camera.offset = Vector2(
				randf_range(-1.0, 1.0) * max_shake_offset.x * shake,
				randf_range(-1.0, 1.0) * max_shake_offset.y * shake
			)
			camera.rotation = randf_range(-1.0, 1.0) * max_shake_roll * shake
		else:
			camera.offset = Vector2.ZERO
			camera.rotation = 0.0

func take_damage(amount: float, knockback_dir: Vector2 = Vector2.ZERO) -> void:
	if NetworkManager.is_network_active():
		net_take_damage.rpc(amount, knockback_dir)
	else:
		_execute_take_damage(amount, knockback_dir)

@rpc("any_peer", "call_local", "reliable")
func net_take_damage(amount: float, knockback_dir: Vector2 = Vector2.ZERO) -> void:
	_execute_take_damage(amount, knockback_dir)

func _execute_take_damage(amount: float, knockback_dir: Vector2 = Vector2.ZERO) -> void:
	if invulnerability_timer > 0.0 or Global.is_game_over:
		return
	
	time_since_last_damage = 0.0
	player_took_damage.emit(amount)
	
	if is_downed:
		# Taking damage while downed accelerates bleed-out
		bleed_out_timer = max(0.0, bleed_out_timer - amount * 0.15)
		if sprite:
			sprite.modulate = Color(1.0, 0.2, 0.2, 0.9)
		if bleed_out_timer <= 0.0:
			die()
		return
	
	var is_local = is_multiplayer_authority() if NetworkManager.is_network_active() else true
	health = max(0.0, health - amount)
	if is_local:
		Global.player_health = health
		Global.health_changed.emit(health, max_health)
		add_trauma(0.55)
	
	invulnerability_timer = 0.40
	if sprite:
		sprite.modulate = Color(1.0, 0.35, 0.35, 1.0)
	Global.play_sound("hit")
	
	if knockback_dir != Vector2.ZERO:
		velocity = knockback_dir.normalized() * 320.0
	
	if health <= 0.0:
		var alive_teammates = get_alive_teammates_count()
		if alive_teammates > 0:
			enter_downed_state()
		else:
			die()

func get_alive_teammates_count() -> int:
	var count = 0
	var players = get_tree().get_nodes_in_group("player")
	for p in players:
		if p != self and is_instance_valid(p):
			var p_hp = p.get("current_health") if "current_health" in p else (p.get("health") if "health" in p else 100.0)
			if not p.get("is_downed") and (p_hp == null or p_hp > 0.0):
				count += 1
	return count

func enter_downed_state() -> void:
	if is_downed:
		return
	if NetworkManager.is_network_active():
		net_set_downed.rpc(true)
	else:
		_execute_enter_downed()

@rpc("any_peer", "call_local", "reliable")
func net_set_downed(downed: bool) -> void:
	if downed:
		_execute_enter_downed()
	else:
		_execute_revive(0.35)

func _execute_enter_downed() -> void:
	if is_downed:
		return
	is_downed = true
	bleed_out_timer = BLEED_OUT_DURATION
	is_rolling = false
	set_collision_mask_value(2, true)
	
	if deployable_mode:
		deployable_mode = false
		if placement_ghost:
			placement_ghost.set_armed(false)
	
	var is_local = is_multiplayer_authority() if NetworkManager.is_network_active() else true
	if is_local:
		Global.set_weapon(Global.WeaponType.PISTOL)
	
	if sprite:
		sprite.modulate = Color(1.0, 0.45, 0.45, 0.85)
		sprite.rotation = PI * 0.5
	
	var revive_zone = get_node_or_null("ReviveZone")
	if revive_zone and revive_zone.has_method("activate"):
		revive_zone.activate()
	
	# Squad Down Warnings
	Global.military_alert_triggered.emit(
		"SQUAD MEMBER DOWN!",
		"REVIVE TEAMMATE BEFORE BLEEDOUT (%ds)" % int(bleed_out_timer),
		Color(1.0, 0.2, 0.15)
	)
	Global.show_notification("SQUAD MEMBER DOWN!", "Hold [E] near downed player to revive", Color(1.0, 0.25, 0.2))
	Global.play_sound("klaxon")
	
	Global.player_downed.emit(self)
	player_downed_state_changed.emit(true)
	_update_squad_tag()
	check_all_players_downed()

func revive(health_ratio: float = 0.35) -> void:
	if not is_downed:
		return
	if NetworkManager.is_network_active():
		net_set_downed.rpc(false)
	else:
		_execute_revive(health_ratio)

func _execute_revive(health_ratio: float = 0.35) -> void:
	if not is_downed:
		return
	is_downed = false
	bleed_out_timer = BLEED_OUT_DURATION
	health = max_health * health_ratio
	
	var is_local = is_multiplayer_authority() if NetworkManager.is_network_active() else true
	if is_local:
		Global.player_health = health
		Global.health_changed.emit(health, max_health)
	
	if sprite:
		sprite.modulate = Color.WHITE
		sprite.rotation = 0.0
	
	var revive_zone = get_node_or_null("ReviveZone")
	if revive_zone and revive_zone.has_method("deactivate"):
		revive_zone.deactivate()
	
	invulnerability_timer = 1.2
	
	var audio_mgr = get_node_or_null("/root/AudioManager")
	if audio_mgr and audio_mgr.has_method("play_sound"):
		audio_mgr.play_sound("perk")
	else:
		Global.play_sound("perk")
	
	Global.show_notification("TEAMMATE REVIVED", "Restored to 35% HP", Color(0.2, 0.95, 0.55))
	Global.player_revived.emit(self)
	player_downed_state_changed.emit(false)
	_update_squad_tag()

func die() -> void:
	if Global.is_game_over:
		return
	is_downed = false
	health = 0.0
	var is_local = is_multiplayer_authority() if NetworkManager.is_network_active() else true
	if is_local:
		Global.player_health = 0.0
		Global.trigger_player_death()
	else:
		var any_alive = false
		for p in get_tree().get_nodes_in_group("player"):
			if is_instance_valid(p) and not p.get("is_downed"):
				var p_hp = p.get("current_health") if "current_health" in p else (p.get("health") if "health" in p else 100.0)
				if p_hp == null or p_hp > 0.0:
					any_alive = true
					break
		if not any_alive:
			Global.trigger_player_death()

func check_all_players_downed() -> void:
	if Global.is_game_over:
		return
	var players = get_tree().get_nodes_in_group("player")
	if players.is_empty():
		return
	var any_alive = false
	for p in players:
		if is_instance_valid(p) and not p.get("is_downed"):
			var p_hp = p.get("current_health") if "current_health" in p else (p.get("health") if "health" in p else 100.0)
			if p_hp == null or p_hp > 0.0:
				any_alive = true
				break
	if not any_alive:
		die()
