extends Node

func _ready() -> void:
	call_deferred("_run_tests")

func _run_tests() -> void:
	print("=== BEGINNING AUTOMATED SCRAP ECONOMY & FIELD ARMORY TESTS ===")
	
	# 1. Test EconomyManager Initial State & Scrap Accumulation
	print("\n--- 1. Testing Scrap Economy Manager ---")
	EconomyManager.reset_state()
	assert(EconomyManager.player_scrap == 0, "Initial scrap should be 0")
	assert(Global.player_scrap == 0, "Global scrap should match EconomyManager")
	
	EconomyManager.add_scrap(50)
	assert(EconomyManager.player_scrap == 50, "Scrap should increase to 50")
	assert(Global.player_scrap == 50, "Global player_scrap should be 50")
	assert(EconomyManager.can_afford(40), "Should afford 40 scrap")
	assert(not EconomyManager.can_afford(60), "Should not afford 60 scrap")
	
	var spent = EconomyManager.spend_scrap(20)
	assert(spent == true, "Spending 20 scrap should succeed")
	assert(EconomyManager.player_scrap == 30, "Remaining scrap should be 30")
	print("✔ Scrap tracking and balance manipulation verified.")
	
	# 2. Test Zombie Scrap Drops
	print("\n--- 2. Testing Zombie Scrap Drops ---")
	var zombie_scene = load("res://scenes/Zombie.tscn")
	var walker = zombie_scene.instantiate()
	walker.zombie_type = 0 # REGULAR
	add_child(walker)
	
	# Test walker drop logic
	var prev_scrap = EconomyManager.player_scrap
	walker.spawn_scrap_drop()
	walker.queue_free()
	print("✔ Zombie walker scrap drop executed without errors.")
	
	# 3. Test ScrapDrop Entity & Magnetic Pull
	print("\n--- 3. Testing ScrapDrop Pickup Entity ---")
	var scrap_drop_scene = load("res://scenes/interactables/ScrapDrop.tscn")
	var scrap_drop = scrap_drop_scene.instantiate()
	scrap_drop.scrap_value = 5
	scrap_drop.global_position = Vector2(50, 0)
	add_child(scrap_drop)
	
	var before_collect = EconomyManager.player_scrap
	scrap_drop.collect()
	assert(EconomyManager.player_scrap == before_collect + 5, "Collecting scrap drop should add scrap")
	print("✔ ScrapDrop entity collection verified.")
	
	# 4. Test Armory Restock Transactions
	print("\n--- 4. Testing Armory Restock Transactions ---")
	EconomyManager.add_scrap(200)
	var g_before = Global.deployable_grenades
	var b_before = Global.deployable_barbwire
	var t_before = Global.deployable_turrets
	
	var bought_g = EconomyManager.buy_grenade_refill()
	assert(bought_g, "Should purchase grenade refill")
	assert(Global.deployable_grenades == g_before + 1, "Grenade stock should increase by 1")
	
	var bought_w = EconomyManager.buy_barbwire_kit()
	assert(bought_w, "Should purchase barbwire kit")
	assert(Global.deployable_barbwire == b_before + 1, "Barbwire stock should increase by 1")
	
	var bought_t = EconomyManager.buy_turret_kit()
	assert(bought_t, "Should purchase turret kit")
	assert(Global.deployable_turrets == t_before + 1, "Turret stock should increase by 1")
	print("✔ Defensive restock purchases verified.")
	
	# 5. Test Weapon Modifications (Per-Run Buffs)
	print("\n--- 5. Testing Weapon Modifications (Per-Run Buffs) ---")
	EconomyManager.add_scrap(500)
	
	# Match-Grade Barrel
	assert(Global.get_damage_multiplier() == 1.0, "Default damage multiplier should be 1.0")
	assert(Global.get_bullet_speed_multiplier() == 1.0, "Default bullet speed multiplier should be 1.0")
	var bought_barrel = EconomyManager.buy_match_grade_barrel()
	assert(bought_barrel, "Should purchase Match-Grade Barrel")
	assert(EconomyManager.mod_match_grade_barrel == true, "mod_match_grade_barrel should be true")
	assert(is_equal_approx(Global.get_damage_multiplier(), 1.20), "+20% Damage multiplier verified")
	assert(is_equal_approx(Global.get_bullet_speed_multiplier(), 1.10), "+10% Bullet speed multiplier verified")
	# Re-purchase should fail
	assert(not EconomyManager.buy_match_grade_barrel(), "Duplicate purchase should be blocked")
	print("✔ Match-Grade Barrel upgrade verified.")
	
	# Extended Drum
	var max_ammo_before = Global.shotgun_max_ammo
	var bought_drum = EconomyManager.buy_extended_drum()
	assert(bought_drum, "Should purchase Extended Drum")
	assert(EconomyManager.mod_extended_drum == true, "mod_extended_drum should be true")
	assert(Global.shotgun_max_ammo > max_ammo_before, "Extended Drum should increase max ammo")
	print("✔ Extended Drum upgrade verified.")
	
	# Hollow-Point Rounds
	var bought_hp = EconomyManager.buy_hollow_point()
	assert(bought_hp, "Should purchase Hollow-Point Rounds")
	assert(EconomyManager.mod_hollow_point == true, "mod_hollow_point should be true")
	assert(Global.mod_hollow_point == true, "Global.mod_hollow_point should be true")
	print("✔ Hollow-Point Rounds upgrade verified.")
	
	# High-Voltage Wire
	var bought_wire = EconomyManager.buy_high_voltage_wire()
	assert(bought_wire, "Should purchase High-Voltage Wire")
	assert(EconomyManager.mod_high_voltage_wire == true, "mod_high_voltage_wire should be true")
	assert(Global.mod_high_voltage_wire == true, "Global.mod_high_voltage_wire should be true")
	print("✔ High-Voltage Wire upgrade verified.")
	
	# 6. Test ArmoryPod & ArmoryMenu UI
	print("\n--- 6. Testing ArmoryPod & ArmoryMenu UI ---")
	var pod_scene = load("res://scenes/interactables/ArmoryPod.tscn")
	var pod = pod_scene.instantiate()
	add_child(pod)
	assert(pod != null, "ArmoryPod should instantiate")
	pod._on_pod_landed()
	assert(pod.current_state == pod.PodState.LANDED, "ArmoryPod landed state verified")
	pod.queue_free()
	
	var menu_scene = load("res://scenes/ui/ArmoryMenu.tscn")
	var menu = menu_scene.instantiate()
	add_child(menu)
	menu.open()
	assert(menu.visible == true, "ArmoryMenu should be visible when opened")
	menu.close()
	assert(menu.visible == false, "ArmoryMenu should be hidden when closed")
	menu.queue_free()
	print("✔ ArmoryPod and ArmoryMenu UI state transitions verified.")
	
	print("\n=== ALL SCRAP ECONOMY & FIELD ARMORY TESTS PASSED SUCCESSFULLY! ===")
	get_tree().quit(0)
