extends Node2D

## Automated Verification Suite: Downed State, Revive Zone & Tactical Ping System

const PING_SYSTEM_SCRIPT = preload("res://scripts/ui/ping_system.gd")
const PING_MARKER_SCRIPT = preload("res://scripts/ui/ping_marker.gd")

func _ready() -> void:
	print("--- BEGIN TEST: DOWNED STATE, REVIVE LOOP & TACTICAL PING SYSTEM ---")
	
	_test_downed_state_and_crawl()
	_test_revive_damage_interruption()
	_test_revive_completion()
	_test_squad_wipe_condition()
	_test_ping_system()
	
	print("=================================================================")
	print("✔ ALL DOWNED STATE, REVIVE & PING SYSTEM TESTS PASSED SUCCESSFULLY")
	print("=================================================================")
	get_tree().quit(0)

func _test_downed_state_and_crawl() -> void:
	print("\n[TEST 1] Downed State & Crawl Mechanics...")
	Global.reset_state()
	
	var player_scene = preload("res://scenes/Player.tscn")
	var p1 = player_scene.instantiate()
	p1.name = "1"
	add_child(p1)
	
	var p2 = player_scene.instantiate()
	p2.name = "2"
	add_child(p2)
	
	assert(p1.is_in_group("player"), "P1 must be in group 'player'")
	assert(p2.is_in_group("player"), "P2 must be in group 'player'")
	assert(p1.get_alive_teammates_count() == 1, "P1 should detect 1 alive teammate (P2)")
	assert(not p1.is_downed, "P1 should not start in downed state")
	
	# Inflict lethal damage to P1
	p1._execute_take_damage(150.0)
	
	assert(p1.is_downed, "P1 must enter is_downed = true when health reaches 0 and teammate is alive")
	assert(not Global.is_game_over, "Game Over must NOT trigger while teammate P2 is still alive")
	assert(p1.bleed_out_timer == 30.0, "Bleed out timer must initialize to 30.0s")
	assert(Global.current_weapon == Global.WeaponType.PISTOL, "Downed player must have weapon locked to Pistol")
	
	# Verify dash/roll blocked
	var stamina_before = p1.stamina
	p1.start_dodge_roll()
	assert(not p1.is_rolling, "Dodge roll must be blocked while downed")
	assert(p1.stamina == stamina_before, "Stamina should not be consumed when roll is blocked")
	
	# Verify ReviveZone activated
	var rz = p1.get_node_or_null("ReviveZone")
	assert(rz != null, "ReviveZone must exist on Player node")
	assert(rz.is_active, "ReviveZone must be active while player is downed")
	
	remove_child(p1); p1.free()
	remove_child(p2); p2.free()
	print("  ✔ Downed state entered, bleed-out started, roll blocked, weapon locked to Pistol")

func _test_revive_damage_interruption() -> void:
	print("\n[TEST 2] Revive Zone Channel & Damage Interruption...")
	Global.reset_state()
	
	var player_scene = preload("res://scenes/Player.tscn")
	var p1 = player_scene.instantiate()
	p1.name = "1"
	add_child(p1)
	
	var p2 = player_scene.instantiate()
	p2.name = "2"
	add_child(p2)
	
	p1._execute_take_damage(150.0)
	assert(p1.is_downed, "P1 should be downed")
	
	var rz = p1.get_node_or_null("ReviveZone") as ReviveZone
	assert(rz != null and rz.is_active, "ReviveZone should be active")
	
	# Simulate P2 starting channel
	rz._start_channel(p2)
	assert(rz.current_reviver == p2, "Reviver must be registered as P2")
	rz.revive_progress = 1.5
	
	# Reviver takes damage -> channel must cancel immediately!
	p2.player_took_damage.emit(15.0)
	assert(rz.revive_progress == 0.0, "Revive progress must reset to 0.0 upon reviver taking damage")
	assert(rz.current_reviver == null, "Reviver channel must be severed upon taking damage")
	
	remove_child(p1); p1.free()
	remove_child(p2); p2.free()
	print("  ✔ Revive channel cancelled and reset when reviver takes damage")

func _test_revive_completion() -> void:
	print("\n[TEST 3] Revive Channel Completion & 35% HP Restoration...")
	Global.reset_state()
	
	var player_scene = preload("res://scenes/Player.tscn")
	var p1 = player_scene.instantiate()
	p1.name = "1"
	add_child(p1)
	
	var p2 = player_scene.instantiate()
	p2.name = "2"
	add_child(p2)
	
	p1._execute_take_damage(150.0)
	assert(p1.is_downed, "P1 should be downed")
	
	var rz = p1.get_node_or_null("ReviveZone") as ReviveZone
	assert(rz != null and rz.is_active, "ReviveZone should be active")
	
	# Complete revive
	rz._start_channel(p2)
	rz.revive_progress = 4.0
	rz._complete_revive(p1)
	
	assert(not p1.is_downed, "P1 downed state must be cleared after revive")
	assert(is_equal_approx(p1.health, p1.max_health * 0.35), "P1 must be restored to 35% of max health")
	assert(not rz.is_active, "ReviveZone must deactivate once revive is completed")
	assert(p1.invulnerability_timer > 0.0, "P1 must have i-frames grace period after being revived")
	
	remove_child(p1); p1.free()
	remove_child(p2); p2.free()
	print("  ✔ Revive completed: downed cleared, 35% HP restored, i-frames granted")

func _test_squad_wipe_condition() -> void:
	print("\n[TEST 4] Squad Wipe (All Squad Members Downed simultaneously)...")
	Global.reset_state()
	assert(not Global.is_game_over, "Game should not be over initially")
	
	var player_scene = preload("res://scenes/Player.tscn")
	var p1 = player_scene.instantiate()
	p1.name = "1"
	add_child(p1)
	
	var p2 = player_scene.instantiate()
	p2.name = "2"
	add_child(p2)
	
	# Down P1
	p1._execute_take_damage(150.0)
	assert(p1.is_downed, "P1 should be downed")
	assert(not Global.is_game_over, "Game over should not trigger with P2 alive")
	
	# Now down P2 (all players now downed!)
	p2._execute_take_damage(150.0)
	assert(Global.is_game_over, "All players downed simultaneously must trigger Game Over")
	
	remove_child(p1); p1.free()
	remove_child(p2); p2.free()
	print("  ✔ All players downed simultaneously triggers true death / Game Over")

func _test_ping_system() -> void:
	print("\n[TEST 5] Tactical Ping System (Move, Enemy, Supplies)...")
	
	var ping_sys_scene = preload("res://scenes/ui/PingSystem.tscn")
	var ping_sys = ping_sys_scene.instantiate()
	add_child(ping_sys)
	
	# 1. Test Default Move Ping
	var move_pos = Vector2(120, 80)
	ping_sys.trigger_ping(move_pos)
	var markers = ping_sys.get_children()
	assert(markers.size() >= 1, "PingSystem should spawn a PingMarker")
	var m1 = markers[-1]
	assert(m1.ping_type == PING_MARKER_SCRIPT.PingType.MOVE, "Default ping must be PingType.MOVE")
	assert(m1.lifetime == 6.0, "Ping lifetime must be 6.0s")
	
	# 2. Test Enemy Ping
	var enemy_dummy = Node2D.new()
	enemy_dummy.add_to_group("enemies")
	enemy_dummy.global_position = Vector2(400, 300)
	add_child(enemy_dummy)
	
	ping_sys.trigger_ping(Vector2(405, 302)) # Close to enemy
	markers = ping_sys.get_children()
	var m2 = markers[-1]
	assert(m2.ping_type == PING_MARKER_SCRIPT.PingType.ENEMY, "Targeting an enemy must set PingType.ENEMY")
	assert(m2.tracked_target == enemy_dummy, "Enemy ping should track the enemy node")
	
	# 3. Test Supplies Ping
	var supply_dummy = Node2D.new()
	supply_dummy.add_to_group("pickups")
	supply_dummy.global_position = Vector2(-200, 150)
	add_child(supply_dummy)
	
	ping_sys.trigger_ping(Vector2(-198, 148)) # Close to supply
	markers = ping_sys.get_children()
	var m3 = markers[-1]
	assert(m3.ping_type == PING_MARKER_SCRIPT.PingType.SUPPLIES, "Targeting supplies must set PingType.SUPPLIES")
	
	# Clean up
	remove_child(enemy_dummy); enemy_dummy.free()
	remove_child(supply_dummy); supply_dummy.free()
	remove_child(ping_sys); ping_sys.free()
	print("  ✔ Ping markers verified: MOVE (Yellow), ENEMY (Red tracking), SUPPLIES (Blue), 6.0s lifetime")
