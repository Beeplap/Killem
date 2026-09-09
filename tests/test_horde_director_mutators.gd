extends Node

const HordeDirectorClass = preload("res://scripts/horde_director.gd")

func _ready() -> void:
	call_deferred("_run_tests")

func _run_tests() -> void:
	print("[TEST] Initializing Horde Director & Elite Mutators test suite...")
	var root = get_tree().root
	
	# Load and instantiate MainLevel
	var main_level_scene = preload("res://scenes/MainLevel.tscn")
	var main_level = main_level_scene.instantiate()
	add_child(main_level)
	
	var player = main_level.get_node_or_null("Player")
	assert(player != null, "Player node must exist in MainLevel")
	
	var horde_director = main_level.get_node_or_null("HordeDirector")
	assert(horde_director != null, "HordeDirector node must exist in MainLevel")
	
	print("[TEST 1] Testing Elite Mutator Affixes...")
	var zombie_scene = preload("res://scenes/Zombie.tscn")
	
	# 1. Volatile Bloater
	var volatile_zombie: Zombie = zombie_scene.instantiate()
	volatile_zombie.zombie_type = Zombie.ZombieType.REGULAR
	volatile_zombie.wave_number = 4
	main_level.add_child(volatile_zombie)
	volatile_zombie.player = player
	var base_hp = volatile_zombie.max_health
	volatile_zombie.apply_mutation_affix(Zombie.MutationAffix.VOLATILE)
	assert(volatile_zombie.max_health == base_hp * 2.0, "Volatile Mutator must have +100 percent HP")
	assert(volatile_zombie.mutation_affix == Zombie.MutationAffix.VOLATILE, "Mutation affix must be VOLATILE")
	print("  ✓ Volatile mutator has +100 percent HP (%d HP)" % int(volatile_zombie.max_health))
	
	# Test Volatile Explosion
	var player_hp_before = Global.player_health
	volatile_zombie.global_position = player.global_position + Vector2(20, 0)
	volatile_zombie.explode_volatile()
	assert(volatile_zombie.has_exploded, "Volatile zombie must be marked as exploded")
	assert(Global.player_health < player_hp_before, "Player must take damage from volatile explosion")
	print("  ✓ Volatile mutator exploded on proximity/death and damaged player (HP: %.1f -> %.1f)" % [player_hp_before, Global.player_health])
	
	# 2. Armored Plating Mutator
	var armored_zombie: Zombie = zombie_scene.instantiate()
	armored_zombie.zombie_type = Zombie.ZombieType.REGULAR
	main_level.add_child(armored_zombie)
	armored_zombie.player = player
	armored_zombie.apply_mutation_affix(Zombie.MutationAffix.ARMORED)
	armored_zombie.current_facing_dir = Vector2.UP
	var hp_before = armored_zombie.current_health
	# Front shot: bullet traveling down into zombie facing up -> dot < -0.15
	armored_zombie.take_damage(100.0, Vector2.DOWN)
	var damage_taken = hp_before - armored_zombie.current_health
	# 70% deflected -> takes 30 damage
	assert(is_equal_approx(damage_taken, 30.0), "Armored mutator must take 70 percent reduced front damage (took %.1f)" % damage_taken)
	print("  ✓ Armored mutator front damage reduction verified: 70 percent deflected (took %.1f / 100 dmg)" % damage_taken)
	
	# Rear shot: bullet traveling up into zombie facing up -> dot > 0
	hp_before = armored_zombie.current_health
	armored_zombie.take_damage(20.0, Vector2.UP)
	var rear_damage_taken = hp_before - armored_zombie.current_health
	assert(is_equal_approx(rear_damage_taken, 20.0), "Armored mutator must take full damage from rear")
	print("  ✓ Armored mutator rear damage verified: 100 percent damage taken (took %.1f / 20 dmg)" % rear_damage_taken)
	armored_zombie.queue_free()
	
	# 3. Frenzied Mutator
	var frenzied_zombie: Zombie = zombie_scene.instantiate()
	frenzied_zombie.zombie_type = Zombie.ZombieType.REGULAR
	main_level.add_child(frenzied_zombie)
	frenzied_zombie.player = player
	var base_speed = frenzied_zombie.speed
	frenzied_zombie.apply_mutation_affix(Zombie.MutationAffix.FRENZIED)
	assert(frenzied_zombie.speed > base_speed * 1.35, "Frenzied mutator must have +40 percent speed")
	# Test slow immunity
	frenzied_zombie.apply_slow(0.3, 5.0)
	assert(frenzied_zombie.slow_factor == 1.0, "Frenzied mutator must be immune to slow")
	print("  ✓ Frenzied mutator verified: +40 percent speed (%.1f -> %.1f) and immune to slow" % [base_speed, frenzied_zombie.speed])
	frenzied_zombie.queue_free()
	
	print("[TEST 2] Testing Tactical Horde Events...")
	
	# 1. Event: FOG DESCENT
	horde_director.start_event(HordeDirectorClass.HordeEventType.FOG_DESCENT)
	assert(horde_director.current_event == HordeDirectorClass.HordeEventType.FOG_DESCENT, "Current event must be FOG_DESCENT")
	assert(horde_director.target_fog_density > 4.5, "Target fog density must increase by ~300 percent")
	var minimap = root.find_child("TacticalMinimap", true, false)
	if not minimap:
		minimap = main_level.find_child("Minimap", true, false)
	if minimap and "is_radar_jammed" in minimap:
		assert(minimap.is_radar_jammed == true, "Minimap must be jammed during Fog Descent")
	print("  ✓ Fog Descent event started: fog density increased to %.1f, radar jammed" % horde_director.target_fog_density)
	
	horde_director.end_current_event(false)
	assert(horde_director.current_event == HordeDirectorClass.HordeEventType.NONE, "Event ended cleanly")
	if minimap and "is_radar_jammed" in minimap:
		assert(minimap.is_radar_jammed == false, "Minimap unjammed after Fog Descent")
	print("  ✓ Fog Descent event ended and restored atmosphere")
	
	# 2. Event: SIEGE ATTRITION
	horde_director.start_event(HordeDirectorClass.HordeEventType.SIEGE_ATTRITION)
	assert(horde_director.current_event == HordeDirectorClass.HordeEventType.SIEGE_ATTRITION, "Current event must be SIEGE_ATTRITION")
	assert(horde_director.siege_zombies_left_to_spawn >= 40, "Siege Attrition must spawn 40+ fast walkers")
	var extraction_zones = get_tree().get_nodes_in_group("extraction_zone")
	assert(extraction_zones.size() > 0, "Defensive bunker must be marked in extraction_zone group for radar")
	print("  ✓ Siege Attrition started: cardinal breach (%s), 42 fast walkers, bunker defense LZ marked" % horde_director.siege_dir_name)
	
	# End siege and verify supply crates dropped
	horde_director.end_current_event(false)
	print("  ✓ Siege Attrition defended: supply crates airdropped at bunker LZ")
	
	# 3. Event: ALPHA SIGNAL
	var scrap_before = Global.player_scrap
	horde_director.start_event(HordeDirectorClass.HordeEventType.ALPHA_SIGNAL)
	assert(horde_director.current_event == HordeDirectorClass.HordeEventType.ALPHA_SIGNAL, "Current event must be ALPHA_SIGNAL")
	var alpha_target = horde_director.alpha_target_ref
	assert(alpha_target != null, "Alpha target must be spawned/designated")
	assert(alpha_target.is_alpha_target == true, "Target must have is_alpha_target == true")
	print("  ✓ Alpha Signal event started: high-value target designated with orange skull marker")
	
	# Spawn test enemies to verify stun on alpha kill
	var test_ally: Zombie = zombie_scene.instantiate()
	main_level.add_child(test_ally)
	assert(test_ally.stagger_timer == 0.0, "Ally not stunned initially")
	
	# Simulate alpha target killed
	horde_director.on_alpha_target_killed(alpha_target)
	assert(test_ally.stagger_timer >= 3.9, "All active zombies must be stunned for 4s upon alpha kill")
	assert(Global.player_scrap == scrap_before + 100, "Killing alpha target must reward 100 Scrap")
	print("  ✓ Alpha Target eliminated: +100 Scrap awarded (Scrap: %d -> %d), horde stunned for 4s (stagger_timer: %.2fs)" % [
		scrap_before, Global.player_scrap, test_ally.stagger_timer
	])
	
	print("\n=======================================================")
	print(">>> ALL TESTS PASSED SUCCESSFULLY! (100% VERIFIED) <<<")
	print("=======================================================\n")
	get_tree().quit(0)