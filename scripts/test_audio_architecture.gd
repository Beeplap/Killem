extends Node

func _ready() -> void:
	print("=== RUNNING MODULAR TACTICAL AUDIO TEST SUITE ===")
	test_audio_buses()
	test_audio_effects()
	test_audio_manager_singleton()
	test_sound_playback()
	test_ducking()
	print("=== ALL AUDIO ARCHITECTURE TESTS PASSED SUCCESSFULLY! ===")
	var audio_mgr = get_node_or_null("/root/AudioManager")
	if audio_mgr:
		audio_mgr.stop_all()
	await get_tree().create_timer(0.1).timeout
	get_tree().quit(0)

func test_audio_buses() -> void:
	print("[TEST] Validating Audio Bus Hierarchy...")
	var expected_buses = [
		"Master",
		"Music",
		"SFX",
		"Weapons",
		"Zombies",
		"Foley",
		"Pickups_UI"
	]
	
	var bus_count = AudioServer.bus_count
	assert(bus_count >= 7, "Expected at least 7 audio buses, found %d" % bus_count)
	
	var bus_names: Array[String] = []
	for i in range(bus_count):
		bus_names.append(AudioServer.get_bus_name(i))
	
	for expected in expected_buses:
		assert(bus_names.has(expected), "Audio bus '%s' not found in AudioServer! Existing: %s" % [expected, str(bus_names)])
		print("  -> Found bus: ", expected)
	
	# Validate bus routing
	var weapons_idx = AudioServer.get_bus_index("Weapons")
	var weapons_send = AudioServer.get_bus_send(weapons_idx)
	assert(weapons_send == "SFX", "Weapons bus send should be SFX, got: %s" % weapons_send)
	
	var zombies_idx = AudioServer.get_bus_index("Zombies")
	var zombies_send = AudioServer.get_bus_send(zombies_idx)
	assert(zombies_send == "SFX", "Zombies bus send should be SFX, got: %s" % zombies_send)
	
	var foley_idx = AudioServer.get_bus_index("Foley")
	var foley_send = AudioServer.get_bus_send(foley_idx)
	assert(foley_send == "SFX", "Foley bus send should be SFX, got: %s" % foley_send)
	
	var pickups_idx = AudioServer.get_bus_index("Pickups_UI")
	var pickups_send = AudioServer.get_bus_send(pickups_idx)
	assert(pickups_send == "SFX", "Pickups_UI bus send should be SFX, got: %s" % pickups_send)
	
	print("[PASS] Bus hierarchy & routing verified.")

func test_audio_effects() -> void:
	print("[TEST] Validating Audio Bus Effects...")
	# 1. Master Limiter
	var master_idx = AudioServer.get_bus_index("Master")
	var master_effect_count = AudioServer.get_bus_effect_count(master_idx)
	assert(master_effect_count >= 1, "Master bus must have at least 1 effect (Limiter)")
	var master_effect = AudioServer.get_bus_effect(master_idx, 0)
	assert(master_effect is AudioEffectLimiter, "Master bus effect 0 must be AudioEffectLimiter, got %s" % master_effect.get_class())
	print("  -> Master Limiter present (Ceiling: %.2f dB, Threshold: %.2f dB)" % [master_effect.ceiling_db, master_effect.threshold_db])
	
	# 2. Weapons Compressor
	var weapons_idx = AudioServer.get_bus_index("Weapons")
	assert(AudioServer.get_bus_effect_count(weapons_idx) >= 1, "Weapons bus must have AudioEffectCompressor")
	var weapons_effect = AudioServer.get_bus_effect(weapons_idx, 0)
	assert(weapons_effect is AudioEffectCompressor, "Weapons bus effect 0 must be AudioEffectCompressor")
	print("  -> Weapons Compressor present (Attack: %.2f ms, Release: %.2f ms)" % [weapons_effect.attack_us, weapons_effect.release_ms])
	
	# 3. Zombies Reverb
	var zombies_idx = AudioServer.get_bus_index("Zombies")
	assert(AudioServer.get_bus_effect_count(zombies_idx) >= 1, "Zombies bus must have AudioEffectReverb")
	var zombies_effect = AudioServer.get_bus_effect(zombies_idx, 0)
	assert(zombies_effect is AudioEffectReverb, "Zombies bus effect 0 must be AudioEffectReverb")
	print("  -> Zombies Reverb present (Room size: %.2f, Wet: %.2f)" % [zombies_effect.room_size, zombies_effect.wet])
	
	# 4. Pickups EQ
	var pickups_idx = AudioServer.get_bus_index("Pickups_UI")
	assert(AudioServer.get_bus_effect_count(pickups_idx) >= 1, "Pickups_UI bus must have AudioEffectEQ")
	var pickups_effect = AudioServer.get_bus_effect(pickups_idx, 0)
	assert(pickups_effect is AudioEffectEQ, "Pickups_UI bus effect 0 must be AudioEffectEQ")
	print("  -> Pickups_UI EQ present")
	
	print("[PASS] Audio bus effects verified.")

func test_audio_manager_singleton() -> void:
	print("[TEST] Validating AudioManager Autoload & Pooling...")
	var audio_mgr = get_node_or_null("/root/AudioManager")
	assert(audio_mgr != null, "AudioManager Autoload singleton must exist at /root/AudioManager")
	
	assert(audio_mgr.get("_pool_3d") != null, "_pool_3d array must exist in AudioManager")
	var pool_3d: Array = audio_mgr.get("_pool_3d")
	assert(pool_3d.size() == 24, "AudioManager must pool 24 AudioStreamPlayer3D instances, got %d" % pool_3d.size())
	
	var pool_2d: Array = audio_mgr.get("_pool_2d")
	assert(pool_2d.size() == 16, "AudioManager must pool 16 AudioStreamPlayer2D instances, got %d" % pool_2d.size())
	
	var pool_ui: Array = audio_mgr.get("_pool_ui")
	assert(pool_ui.size() == 8, "AudioManager must pool 8 AudioStreamPlayer instances, got %d" % pool_ui.size())
	
	# Verify randomizer wrapping
	var cache: Dictionary = audio_mgr.get("_sound_cache")
	assert(cache.size() >= 20, "AudioManager sound cache should have preloaded at least 20 sounds, found %d" % cache.size())
	for s_name in ["pistol", "shotgun", "rifle", "mutant_roar", "pickup_ammo", "footstep_concrete"]:
		assert(cache.has(s_name), "Sound '%s' must be cached in AudioManager" % s_name)
		assert(cache[s_name] is AudioStreamRandomizer, "Cached sound '%s' must be wrapped in AudioStreamRandomizer" % s_name)
	
	print("[PASS] Pools and cache verified (24x 3D, 16x 2D, 8x UI).")

func test_sound_playback() -> void:
	print("[TEST] Validating 3D, 2D, and UI Sound Playback...")
	var audio_mgr = get_node_or_null("/root/AudioManager")
	
	# 3D
	var p3d = audio_mgr.play_sound("pistol", Vector3(10, 0, 5))
	assert(p3d != null and p3d is AudioStreamPlayer3D, "play_sound with Vector3 must return an AudioStreamPlayer3D")
	assert(p3d.playing, "AudioStreamPlayer3D must be playing")
	assert(p3d.bus == "Weapons", "Pistol bus must be Weapons, got: %s" % p3d.bus)
	
	# 2D
	var p2d = audio_mgr.play_sound_2d("rifle", Vector2(50, 50))
	assert(p2d != null and p2d is AudioStreamPlayer2D, "play_sound_2d must return an AudioStreamPlayer2D")
	assert(p2d.playing, "AudioStreamPlayer2D must be playing")
	assert(p2d.bus == "Weapons", "Rifle bus must be Weapons, got: %s" % p2d.bus)
	
	# UI
	var p_ui = audio_mgr.play_sound_ui("pickup_ammo")
	assert(p_ui != null and p_ui is AudioStreamPlayer, "play_sound_ui must return an AudioStreamPlayer")
	assert(p_ui.playing, "UI player must be playing")
	assert(p_ui.bus == "Pickups_UI", "Pickup bus must be Pickups_UI, got: %s" % p_ui.bus)
	
	# Zombie / Monster 3D
	var p_mutant = audio_mgr.play_sound("mutant_roar", Vector3(-4, 0, 2))
	assert(p_mutant != null and p_mutant is AudioStreamPlayer3D, "mutant_roar must return 3D player")
	assert(p_mutant.bus == "Zombies", "Mutant roar bus must be Zombies, got: %s" % p_mutant.bus)
	
	# Foley 3D
	var p_step = audio_mgr.play_sound("footstep_concrete", Vector3(1, 0, 0))
	assert(p_step != null and p_step.bus == "Foley", "Footstep bus must be Foley, got: %s" % p_step.bus)
	
	# Global wrapper backward compatibility
	Global.play_sound("stomp_crash", Vector3(0, 0, 0))
	Global.play_sound("pickup_health")
	
	print("[PASS] Sound playback and bus routing verified.")

func test_ducking() -> void:
	print("[TEST] Validating Sidechain Weapon Ducking...")
	var audio_mgr = get_node_or_null("/root/AudioManager")
	var sfx_idx = AudioServer.get_bus_index("SFX")
	AudioServer.set_bus_volume_db(sfx_idx, 0.0)
	var initial_db = AudioServer.get_bus_volume_db(sfx_idx)
	
	audio_mgr.duck_sfx_for_weapon(-3.5)
	var ducked_db = AudioServer.get_bus_volume_db(sfx_idx)
	assert(ducked_db < initial_db, "SFX bus volume should be ducked below initial dB! Initial: %.2f, Ducked: %.2f" % [initial_db, ducked_db])
	print("  -> Ducking confirmed (Initial: %.2f dB, Ducked: %.2f dB)" % [initial_db, ducked_db])
	print("[PASS] Sidechain ducking verified.")
