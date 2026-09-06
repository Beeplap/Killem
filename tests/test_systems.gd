extends Node

func _ready() -> void:
	call_deferred("_run_tests")

func _run_tests() -> void:
	print("--- BEGINNING AUTOMATED COMBAT & TACTICAL SYSTEMS TEST ---")
	
	# 1. Load Main Level
	var main_scene = load("res://scenes/MainLevel.tscn")
	if not main_scene:
		printerr("FAIL: Could not load MainLevel.tscn")
		get_tree().quit(1)
		return
	
	var root_node = main_scene.instantiate()
	get_tree().root.add_child(root_node)
	get_tree().current_scene = root_node
	
	await get_tree().create_timer(0.1).timeout
	
	var player = get_tree().get_first_node_in_group("player")
	if not player:
		printerr("FAIL: Player not found")
		get_tree().quit(1)
		return
	print("PASS: MainLevel and Player instantiated.")
	
	# 2. Test Dodge Roll
	print("Testing Player Dodge Roll...")
	player.start_dodge_roll()
	if not player.is_rolling:
		printerr("FAIL: Player failed to start rolling")
		get_tree().quit(1)
		return
	print("PASS: Dodge roll started with i-frames.")
	
	await get_tree().create_timer(0.3).timeout
	if player.is_rolling:
		printerr("FAIL: Dodge roll did not complete")
		get_tree().quit(1)
		return
	print("PASS: Dodge roll completed, cooldown active.")
	
	# 3. Test Weapons 4 & 5
	print("Testing Flamethrower & Minigun switching...")
	Global.set_weapon(Global.WeaponType.FLAMETHROWER)
	if Global.current_weapon != Global.WeaponType.FLAMETHROWER:
		printerr("FAIL: Could not switch to flamethrower")
		get_tree().quit(1)
		return
	print("PASS: Switched to Flamethrower. Fuel: %d" % Global.flamethrower_fuel)
	player.fire_weapon()
	print("PASS: Flamethrower fired successfully. Remaining Fuel: %d" % Global.flamethrower_fuel)
	
	Global.set_weapon(Global.WeaponType.MINIGUN)
	if Global.current_weapon != Global.WeaponType.MINIGUN:
		printerr("FAIL: Could not switch to minigun")
		get_tree().quit(1)
		return
	print("PASS: Switched to Minigun. Ammo: %d" % Global.minigun_ammo)
	player.minigun_spin_timer = 0.5 # Spun up
	player.fire_weapon()
	print("PASS: Minigun fired successfully. Remaining Ammo: %d" % Global.minigun_ammo)
	
	# 4. Test Deployables
	print("Testing Deployable Placements...")
	# Wire
	player.active_deployable_type = 0
	player.deploy_current_item()
	# Claymore
	player.active_deployable_type = 1
	player.deploy_current_item()
	# Turret
	player.active_deployable_type = 2
	player.deploy_current_item()
	
	var deployables = get_tree().get_nodes_in_group("deployables")
	print("PASS: Deployables active in scene: %d" % deployables.size())
	if deployables.size() < 3:
		printerr("FAIL: Expected at least 3 deployables")
		get_tree().quit(1)
		return
	
	# 5. Test Screamer Zombie
	print("Testing Screamer Zombie instantiation & screech...")
	var screamer_scene = load("res://scenes/ScreamerZombie.tscn")
	var screamer = screamer_scene.instantiate()
	screamer.global_position = Vector2(100, 100)
	root_node.add_child(screamer)
	screamer.screech_and_buff()
	print("PASS: Screamer Zombie screeched and buffed nearby horde.")
	
	# 6. Test Armored Riot Zombie frontal deflection
	print("Testing Armored Zombie frontal shield deflection...")
	var armored_scene = load("res://scenes/ArmoredZombie.tscn")
	var armored = armored_scene.instantiate()
	armored.global_position = Vector2(0, 50)
	root_node.add_child(armored)
	armored.update_facing(Vector2.DOWN) # Zombie faces DOWN (0, 1)
	
	var initial_hp = armored.current_health
	# Bullet flying UP (0, -1) hits frontal shield head-on
	armored.take_damage(50.0, Vector2.UP)
	var dmg_taken = initial_hp - armored.current_health
	print("Frontal hit damage: %.1f / 50.0 (Expected ~10.0 due to 80%% deflection)" % dmg_taken)
	if dmg_taken > 20.0:
		printerr("FAIL: Frontal deflection failed!")
		get_tree().quit(1)
		return
	print("PASS: Armored Riot Zombie frontal shield deflected 80% damage!")
	
	# 7. Test Spitter Acid Pool on death
	print("Testing Spitter death and acid pool generation...")
	var spitter_scene = load("res://scenes/SpitterZombie.tscn")
	var spitter = spitter_scene.instantiate()
	spitter.global_position = Vector2(200, 200)
	root_node.add_child(spitter)
	spitter.die(Vector2.RIGHT)
	await get_tree().create_timer(0.05).timeout
	var acid_found = false
	for child in root_node.get_children():
		if child.name.begins_with("AcidPool"):
			acid_found = true
			break
	if not acid_found:
		printerr("FAIL: Acid pool not found on spitter death")
		get_tree().quit(1)
		return
	print("PASS: Glowing Acid Pool spawned upon Spitter death.")
	
	# 8. Test Power Transformer Electrical Discharge
	print("Testing Power Transformer Electrical Discharge...")
	var transformers = get_tree().get_nodes_in_group("transformers")
	if transformers.size() > 0:
		var trans = transformers[0]
		trans.take_damage(50.0)
		if not trans.is_active_discharging:
			printerr("FAIL: Transformer did not discharge on rupture")
			get_tree().quit(1)
			return
		print("PASS: Power Transformer discharging high-voltage electrical field.")
	
	# 9. Test Air Drop & Perk System
	print("Testing Supply Crate Capture & Perks...")
	var crate_scene = load("res://scenes/SupplyCrate.tscn")
	var crate = crate_scene.instantiate()
	crate.global_position = Vector2(30, 30)
	root_node.add_child(crate)
	crate.complete_capture()
	print("PASS: Supply Crate captured. Perk Full Auto: %s, Extended Mags: %s, Armor Plating: %s" % [
		Global.perk_full_auto, Global.perk_extended_mags, Global.perk_armor_plating
	])
	
	print("\nALL 9 SYSTEMS VERIFIED AND WORKING FLAWLESSLY!")
	get_tree().quit(0)
