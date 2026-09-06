extends Node

signal objective_updated(obj_id: String, text: String, current: int, target: int, is_done: bool)
signal mission_completed(summary: Dictionary)
signal level_started(level_idx: int, level_name: String)

const LEVELS: Array[Dictionary] = [
	{
		"id": "level_01",
		"scene_path": "res://scenes/levels/Level_01_RailDepot.tscn",
		"name": "Level 1 - Quarantine Rail Depot",
		"subtitle": "SECURE POWER • OVERRIDE SWITCH • DEFEAT TRAINYARD MUTATOR",
		"objectives": [
			{"id": "battery_cells", "text": "Collect Battery Cells", "current": 0, "target": 2, "completed": false},
			{"id": "rail_switch", "text": "Override Rail Switch", "current": 0, "target": 1, "completed": false},
			{"id": "defeat_boss", "text": "Eliminate Trainyard Mutator", "current": 0, "target": 1, "completed": false}
		]
	},
	{
		"id": "level_02",
		"scene_path": "res://scenes/levels/Level_02_ResearchLabs.tscn",
		"name": "Level 2 - Subterranean Research Labs",
		"subtitle": "PURGE CHEMICAL LEAKS • ACQUIRE KEYCARD • ELIMINATE GOLIATH",
		"objectives": [
			{"id": "purge_leaks", "text": "Purge Chemical Leak Valves", "current": 0, "target": 2, "completed": false},
			{"id": "master_keycard", "text": "Acquire Master Keycard", "current": 0, "target": 1, "completed": false},
			{"id": "defeat_boss", "text": "Defeat Goliath Subject 0", "current": 0, "target": 1, "completed": false}
		]
	},
	{
		"id": "level_03",
		"scene_path": "res://scenes/levels/Level_03_MetroCore.tscn",
		"name": "Level 3 - Fallen Metropolitan Core",
		"subtitle": "TRANSMIT SOS • SURVIVE TITAN SIEGE • REACH EVACUATION",
		"objectives": [
			{"id": "radio_tower", "text": "Transmit Military Air Evac SOS", "current": 0, "target": 1, "completed": false},
			{"id": "survive_siege", "text": "Survive the Metro Titan Siege", "current": 0, "target": 1, "completed": false},
			{"id": "defeat_boss", "text": "Eliminate the Apex Titan", "current": 0, "target": 1, "completed": false}
		]
	}
]

var current_level_index: int = 0
var unlocked_level_index: int = 0
var active_objectives: Array[Dictionary] = []

# Mission Statistics
var mission_start_time: float = 0.0
var shots_fired: int = 0
var shots_hit: int = 0
var level_kills: int = 0
var initial_score: int = 0

# Persistent Inventory across stages
var saved_weapon: int = 0 # Pistol
var saved_shotgun_ammo: int = 24
var saved_rifle_ammo: int = 90
var saved_flame_fuel: int = 150
var saved_minigun_ammo: int = 300
var saved_player_health: float = 100.0
var saved_player_max_health: float = 100.0
var saved_barbed_wire: int = 2
var saved_claymores: int = 2
var saved_turrets: int = 1
var saved_perk_full_auto: bool = false
var saved_perk_extended_mags: bool = false
var saved_perk_armor_plating: bool = false

func _ready() -> void:
	start_mission(0)

func start_mission(level_idx: int) -> void:
	current_level_index = clamp(level_idx, 0, LEVELS.size() - 1)
	unlocked_level_index = max(unlocked_level_index, current_level_index)
	
	# Deep copy objectives template
	active_objectives.clear()
	var template = LEVELS[current_level_index]["objectives"]
	for obj in template:
		active_objectives.append(obj.duplicate(true))
	
	mission_start_time = Time.get_ticks_msec() / 1000.0
	shots_fired = 0
	shots_hit = 0
	level_kills = 0
	initial_score = Global.score
	
	level_started.emit(current_level_index, LEVELS[current_level_index]["name"])

func update_objective(obj_id: String, amount: int = 1) -> void:
	for obj in active_objectives:
		if obj["id"] == obj_id:
			obj["current"] = min(obj["target"], obj["current"] + amount)
			if obj["current"] >= obj["target"]:
				obj["completed"] = true
			
			objective_updated.emit(obj["id"], obj["text"], obj["current"], obj["target"], obj["completed"])
			Global.play_sound("perk")
			break

func are_all_objectives_complete() -> bool:
	for obj in active_objectives:
		if not obj["completed"]:
			return false
	return true

func record_shot_fired() -> void:
	shots_fired += 1

func record_shot_hit() -> void:
	shots_hit += 1

func record_kill() -> void:
	level_kills += 1

func get_mission_summary() -> Dictionary:
	var current_time = Time.get_ticks_msec() / 1000.0
	var elapsed = max(0.1, current_time - mission_start_time)
	var mins = int(elapsed / 60.0)
	var secs = int(elapsed) % 60
	var time_str = "%02d:%02d" % [mins, secs]
	
	var acc: float = 100.0
	if shots_fired > 0:
		acc = clampf((float(shots_hit) / float(shots_fired)) * 100.0, 0.0, 100.0)
	
	var gained_score = max(0, Global.score - initial_score)
	var lvl_name = LEVELS[current_level_index]["name"]
	
	return {
		"level_name": lvl_name,
		"time_elapsed": elapsed,
		"time_formatted": time_str,
		"kills": level_kills,
		"accuracy": acc,
		"score": gained_score,
		"total_score": Global.score,
		"is_final_level": (current_level_index >= LEVELS.size() - 1)
	}

func save_player_state(player: Node3D = null) -> void:
	saved_player_health = Global.player_health
	saved_player_max_health = Global.player_max_health
	saved_shotgun_ammo = Global.shotgun_ammo
	saved_rifle_ammo = Global.rifle_ammo
	saved_flame_fuel = Global.flamethrower_fuel
	saved_minigun_ammo = Global.minigun_ammo
	saved_barbed_wire = Global.deployable_barbed_wire
	saved_claymores = Global.deployable_claymores
	saved_turrets = Global.deployable_turrets
	saved_perk_full_auto = Global.perk_full_auto
	saved_perk_extended_mags = Global.perk_extended_mags
	saved_perk_armor_plating = Global.perk_armor_plating
	
	if player and player.get("current_weapon") != null:
		saved_weapon = int(player.current_weapon)
	else:
		saved_weapon = int(Global.current_weapon)

func restore_player_state(player: Node3D = null) -> void:
	Global.player_health = saved_player_health
	Global.player_max_health = saved_player_max_health
	Global.shotgun_ammo = saved_shotgun_ammo
	Global.rifle_ammo = saved_rifle_ammo
	Global.flamethrower_fuel = saved_flame_fuel
	Global.minigun_ammo = saved_minigun_ammo
	Global.deployable_barbed_wire = saved_barbed_wire
	Global.deployable_claymores = saved_claymores
	Global.deployable_turrets = saved_turrets
	Global.perk_full_auto = saved_perk_full_auto
	Global.perk_extended_mags = saved_perk_extended_mags
	Global.perk_armor_plating = saved_perk_armor_plating
	Global.health_changed.emit(Global.player_health, Global.player_max_health)
	Global.emit_current_ammo()
	
	if player and player.has_method("switch_weapon"):
		player.switch_weapon(saved_weapon)

func load_level(idx: int) -> void:
	if idx < 0 or idx >= LEVELS.size():
		return
	
	var player = get_tree().get_first_node_in_group("player")
	save_player_state(player)
	
	start_mission(idx)
	get_tree().change_scene_to_file(LEVELS[idx]["scene_path"])

func load_next_level() -> void:
	if current_level_index < LEVELS.size() - 1:
		load_level(current_level_index + 1)
	else:
		# Final level loop or return to level 1
		load_level(0)
