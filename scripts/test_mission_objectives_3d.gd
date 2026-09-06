extends Node3D

var tests_passed: int = 0
var tests_failed: int = 0

func _ready() -> void:
	print("\n=======================================================")
	print("[TEST] RUNNING MISSION OBJECTIVES & INTERACTION SYSTEM VERIFICATION...")
	print("=======================================================")
	run_tests()

func assert_test(cond: bool, test_name: String) -> void:
	if cond:
		tests_passed += 1
		print("  [PASS] ", test_name)
	else:
		tests_failed += 1
		printerr("  [FAIL] ", test_name)

func run_tests() -> void:
	test_mission_manager()
	test_keycard_pickup()
	test_blast_door()
	test_generator_defense()
	test_data_terminal()
	test_objective_marker()
	test_objective_tracker_hud()
	
	print("=======================================================")
	print("[TEST SUMMARY] Passed: %d, Failed: %d" % [tests_passed, tests_failed])
	print("=======================================================\n")
	
	if tests_failed == 0:
		print("[TEST] ALL MISSION OBJECTIVE SYSTEMS PASSED!")
	else:
		printerr("[TEST] SOME TESTS FAILED!")

func test_mission_manager() -> void:
	print("[TEST] Testing MissionManager...")
	var mm = MissionManager.new()
	add_child(mm)
	
	mm.add_objective("test_obj_1", "Test Objective 1", "Description", "keycard_hunt")
	mm.add_objective("test_obj_2", "Test Objective 2", "Description", "generator_defense")
	
	assert_test(mm.active_objectives.size() == 2, "MissionManager registered 2 objectives")
	assert_test(not mm.has_all_completed(), "Objectives not yet complete")
	
	mm.update_progress("test_obj_2", 0.5)
	assert_test(is_equal_approx(mm.active_objectives["test_obj_2"]["progress"], 0.5), "MissionManager progress update clamped/set correctly")
	
	mm.complete_objective("test_obj_1")
	assert_test(mm.active_objectives["test_obj_1"]["completed"], "Objective 1 marked completed")
	assert_test(not mm.has_all_completed(), "All objectives not complete when 1 remaining")
	
	mm.complete_objective("test_obj_2")
	assert_test(mm.has_all_completed(), "All objectives marked complete")
	mm.queue_free()

func test_keycard_pickup() -> void:
	print("[TEST] Testing KeycardPickup3D...")
	Global.keycards_collected.clear()
	assert_test(not Global.has_keycard("yellow"), "Global initially has no keycard")
	
	var keycard = KeycardPickup3D.new()
	keycard.keycard_color = "yellow"
	add_child(keycard)
	
	var dummy_player = CharacterBody3D.new()
	dummy_player.add_to_group("player3d")
	add_child(dummy_player)
	
	keycard._on_body_entered(dummy_player)
	assert_test(Global.has_keycard("yellow"), "Keycard collected and registered in Global")
	assert_test(Global.keycards_collected.has("yellow"), "Yellow keycard present in keycards_collected")
	
	dummy_player.queue_free()

func test_blast_door() -> void:
	print("[TEST] Testing BlastDoor3D...")
	var door = BlastDoor3D.new()
	door.required_keycard = "yellow"
	add_child(door)
	
	assert_test(not door.is_open, "Blast door initially closed")
	door.open_door()
	assert_test(door.is_open, "Blast door opens and triggers tween animation")
	door.queue_free()

func test_generator_defense() -> void:
	print("[TEST] Testing GeneratorDefense3D...")
	var gen = GeneratorDefense3D.new()
	gen.defense_duration = 2.0 # short for testing
	add_child(gen)
	
	assert_test(gen.current_state == GeneratorDefense3D.State.INACTIVE, "Generator initially inactive")
	
	var flags = {"wave": false}
	gen.generator_defense_wave.connect(func(_w): flags["wave"] = true)
	
	gen.start_defense()
	assert_test(gen.current_state == GeneratorDefense3D.State.DEFENDING, "Generator enters DEFENDING state")
	assert_test(flags["wave"], "Generator emitted initial defense wave signal")
	
	# Simulate defense countdown
	gen._process(2.5)
	assert_test(gen.current_state == GeneratorDefense3D.State.COMPLETED, "Generator completes defense when timer expires")
	gen.queue_free()

func test_data_terminal() -> void:
	print("[TEST] Testing DataTerminal3D...")
	var term = DataTerminal3D.new()
	term.hack_duration = 5.0
	add_child(term)
	
	assert_test(term.current_state == DataTerminal3D.State.LOCKED, "Terminal initially locked")
	
	var flags = {"breach": false}
	term.room_breach_triggered.connect(func(): flags["breach"] = true)
	
	term._on_interaction_progress(0.2)
	assert_test(term.current_state == DataTerminal3D.State.HACKING, "Terminal transitions to HACKING on progress")
	assert_test(flags["breach"], "Terminal emitted room breach signal")
	
	term.complete_hack()
	assert_test(term.current_state == DataTerminal3D.State.COMPLETED, "Terminal completed hack")
	term.queue_free()

func test_objective_marker() -> void:
	print("[TEST] Testing ObjectiveMarker3D...")
	var marker = ObjectiveMarker3D.new()
	marker.marker_text = "TEST TARGET"
	marker.marker_color = Color.CYAN
	add_child(marker)
	
	assert_test(marker._label != null, "ObjectiveMarker3D created internal Label3D")
	assert_test(marker._label.billboard == BaseMaterial3D.BILLBOARD_ENABLED, "Label3D billboard enabled")
	marker.queue_free()

func test_objective_tracker_hud() -> void:
	print("[TEST] Testing ObjectiveTrackerHUD...")
	var hud = ObjectiveTrackerHUD.new()
	add_child(hud)
	
	hud.add_objective_entry("test_hud_1", "Objective Alpha")
	assert_test(hud._objectives.has("test_hud_1"), "HUD recorded objective entry")
	
	hud.update_objective_entry("test_hud_1", 0.75)
	var bar: ProgressBar = hud._objectives["test_hud_1"]["progress"]
	assert_test(is_equal_approx(bar.value, 75.0), "HUD updated progress bar to 75%")
	
	hud.complete_objective_entry("test_hud_1")
	var chk: RichTextLabel = hud._objectives["test_hud_1"]["checkbox"]
	assert_test(chk.text.contains("[x]"), "HUD displayed completed checkmark [x]")
	hud.queue_free()
