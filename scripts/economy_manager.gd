extends Node

## Tactical Scrap Economy & Field Armory Manager
## Manages scrap currency, in-world physical drops, upgrade purchases, and drop pod deployments.

signal scrap_changed(current_scrap: int)
signal upgrade_purchased(upgrade_id: String, cost: int)
signal armory_opened
signal armory_closed

# Restock & Upgrade Costs
const COST_GRENADE: int = 25
const COST_BARBWIRE: int = 40
const COST_TURRET: int = 100

const COST_MATCH_GRADE_BARREL: int = 75
const COST_EXTENDED_DRUM: int = 90
const COST_HOLLOW_POINT: int = 120
const COST_HIGH_VOLTAGE_WIRE: int = 140

var player_scrap: int = 0

# Upgrade statuses
var mod_match_grade_barrel: bool = false
var mod_extended_drum: bool = false
var mod_hollow_point: bool = false
var mod_high_voltage_wire: bool = false

var scrap_drop_scene: PackedScene = null
var armory_pod_scene: PackedScene = null
var armory_menu_instance: CanvasLayer = null

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	scrap_drop_scene = load("res://scenes/interactables/ScrapDrop.tscn")
	armory_pod_scene = load("res://scenes/interactables/ArmoryPod.tscn")
	
	# Listen to wave clears for every-3-waves armory deployment
	Global.wave_cleared.connect(_on_wave_cleared)

func reset_state() -> void:
	player_scrap = 0
	mod_match_grade_barrel = false
	mod_extended_drum = false
	mod_hollow_point = false
	mod_high_voltage_wire = false
	Global.player_scrap = 0
	Global.mod_match_grade_barrel = false
	Global.mod_extended_drum = false
	Global.mod_hollow_point = false
	Global.mod_high_voltage_wire = false
	scrap_changed.emit(player_scrap)

func add_scrap(amount: int) -> void:
	player_scrap += amount
	Global.player_scrap = player_scrap
	scrap_changed.emit(player_scrap)
	if Global.has_signal("scrap_changed"):
		Global.scrap_changed.emit(player_scrap)

func spend_scrap(amount: int) -> bool:
	if player_scrap >= amount:
		player_scrap -= amount
		Global.player_scrap = player_scrap
		scrap_changed.emit(player_scrap)
		if Global.has_signal("scrap_changed"):
			Global.scrap_changed.emit(player_scrap)
		return true
	return false

func can_afford(amount: int) -> bool:
	return player_scrap >= amount

# Defensive Restock Transactions
func buy_grenade_refill() -> bool:
	if spend_scrap(COST_GRENADE):
		Global.deployable_grenades += 1
		Global.deployables_updated.emit(Global.deployable_grenades, Global.deployable_barbwire, Global.deployable_turrets)
		upgrade_purchased.emit("grenade_refill", COST_GRENADE)
		Global.play_sound("perk")
		return true
	Global.play_sound("empty_click")
	return false

func buy_barbwire_kit() -> bool:
	if spend_scrap(COST_BARBWIRE):
		Global.deployable_barbwire += 1
		Global.deployables_updated.emit(Global.deployable_grenades, Global.deployable_barbwire, Global.deployable_turrets)
		upgrade_purchased.emit("barbwire_kit", COST_BARBWIRE)
		Global.play_sound("perk")
		return true
	Global.play_sound("empty_click")
	return false

func buy_turret_kit() -> bool:
	if spend_scrap(COST_TURRET):
		Global.deployable_turrets += 1
		Global.deployables_updated.emit(Global.deployable_grenades, Global.deployable_barbwire, Global.deployable_turrets)
		upgrade_purchased.emit("turret_kit", COST_TURRET)
		Global.play_sound("perk")
		return true
	Global.play_sound("empty_click")
	return false

# Weapon Modifications Transactions
func buy_match_grade_barrel() -> bool:
	if mod_match_grade_barrel:
		return false
	if spend_scrap(COST_MATCH_GRADE_BARREL):
		mod_match_grade_barrel = true
		Global.mod_match_grade_barrel = true
		upgrade_purchased.emit("match_grade_barrel", COST_MATCH_GRADE_BARREL)
		Global.show_notification("UPGRADE INSTALLED: MATCH-GRADE BARREL", "+20% Weapon Damage, +10% Projectile Velocity", Color(0.2, 0.95, 0.55))
		Global.play_sound("perk")
		return true
	Global.play_sound("empty_click")
	return false

func buy_extended_drum() -> bool:
	if mod_extended_drum:
		return false
	if spend_scrap(COST_EXTENDED_DRUM):
		mod_extended_drum = true
		Global.mod_extended_drum = true
		Global.shotgun_max_ammo = int(Global.shotgun_max_ammo * 1.5)
		Global.rifle_max_ammo = int(Global.rifle_max_ammo * 1.5)
		Global.flamethrower_max_fuel = int(Global.flamethrower_max_fuel * 1.5)
		Global.minigun_max_ammo = int(Global.minigun_max_ammo * 1.5)
		Global.shotgun_ammo = Global.shotgun_max_ammo
		Global.rifle_ammo = Global.rifle_max_ammo
		Global.flamethrower_fuel = Global.flamethrower_max_fuel
		Global.minigun_ammo = Global.minigun_max_ammo
		Global.emit_current_ammo()
		upgrade_purchased.emit("extended_drum", COST_EXTENDED_DRUM)
		Global.show_notification("UPGRADE INSTALLED: EXTENDED DRUM", "+50% Ammo Capacity Across All Firearms", Color(0.2, 0.95, 0.55))
		Global.play_sound("perk")
		return true
	Global.play_sound("empty_click")
	return false

func buy_hollow_point() -> bool:
	if mod_hollow_point:
		return false
	if spend_scrap(COST_HOLLOW_POINT):
		mod_hollow_point = true
		Global.mod_hollow_point = true
		upgrade_purchased.emit("hollow_point", COST_HOLLOW_POINT)
		Global.show_notification("UPGRADE INSTALLED: HOLLOW-POINT ROUNDS", "2-Second Arterial Bleeding Damage-Over-Time", Color(0.2, 0.95, 0.55))
		Global.play_sound("perk")
		return true
	Global.play_sound("empty_click")
	return false

func buy_high_voltage_wire() -> bool:
	if mod_high_voltage_wire:
		return false
	if spend_scrap(COST_HIGH_VOLTAGE_WIRE):
		mod_high_voltage_wire = true
		Global.mod_high_voltage_wire = true
		upgrade_purchased.emit("high_voltage_wire", COST_HIGH_VOLTAGE_WIRE)
		Global.show_notification("UPGRADE INSTALLED: HIGH-VOLTAGE WIRE", "Electrocutes & Chain-Stuns Up to 3 Enemies", Color(0.2, 0.95, 0.55))
		Global.play_sound("perk")
		return true
	Global.play_sound("empty_click")
	return false

# In-World Physical Scrap Spawner
func spawn_scrap(pos: Vector2, amount: int) -> void:
	if scrap_drop_scene == null:
		scrap_drop_scene = load("res://scenes/interactables/ScrapDrop.tscn")
	if scrap_drop_scene == null:
		return
	
	var level = get_tree().current_scene
	if not level:
		return
	
	# Spawn 1 drop node with aggregated scrap value or multiple small parts if large amount
	var drops_to_spawn = 1
	var val_per_drop = amount
	if amount >= 10:
		drops_to_spawn = clampi(int(float(amount) / 4.0), 2, 4)
		val_per_drop = int(ceil(float(amount) / float(drops_to_spawn)))
	
	for i in range(drops_to_spawn):
		var drop = scrap_drop_scene.instantiate()
		drop.global_position = pos + Vector2(randf_range(-8.0, 8.0), randf_range(-8.0, 8.0))
		drop.scrap_value = val_per_drop
		level.call_deferred("add_child", drop)

# Armory Pod Deployment
func _on_wave_cleared(wave_num: int, _cooldown: float) -> void:
	# Automatically air-drops or unlocks every 3 waves (e.g. Wave 3, 6, 9...)
	if wave_num > 0 and wave_num % 3 == 0:
		spawn_armory_pod_at_center()

func spawn_armory_pod_at_center() -> void:
	var level = get_tree().current_scene
	if not level:
		return
	
	var player = get_tree().get_first_node_in_group("player")
	var target_pos = Vector2.ZERO
	if player:
		# Sector center or tactical position near player
		var offset = Vector2(randf_range(-80.0, 80.0), randf_range(-80.0, 80.0))
		target_pos = player.global_position + offset
	
	if armory_pod_scene == null:
		armory_pod_scene = load("res://scenes/interactables/ArmoryPod.tscn")
	if armory_pod_scene:
		var pod = armory_pod_scene.instantiate()
		pod.global_position = target_pos
		level.call_deferred("add_child", pod)
		Global.show_notification("FIELD ARMORY DROP INCOMING", "Tactical Vendor Station Deployed to Sector", Color(0.98, 0.82, 0.15))

func open_armory_ui() -> void:
	if armory_menu_instance == null or not is_instance_valid(armory_menu_instance):
		var menu_scene = load("res://scenes/ui/ArmoryMenu.tscn")
		if menu_scene:
			armory_menu_instance = menu_scene.instantiate()
			var level = get_tree().current_scene
			if level:
				level.add_child(armory_menu_instance)
	
	if armory_menu_instance and armory_menu_instance.has_method("open"):
		armory_menu_instance.open()
		armory_opened.emit()

func close_armory_ui() -> void:
	if armory_menu_instance and armory_menu_instance.has_method("close"):
		armory_menu_instance.close()
		armory_closed.emit()
