class_name PlayerShooting
extends RefCounted

## Modular Tactical Weapon Audio & Mechanics Controller
## Handles multi-layer firing cues, mechanical foley, pump racks, reload sequences, and casing pings.

static func _get_global() -> Node:
	if Engine.get_main_loop() and Engine.get_main_loop().root:
		return Engine.get_main_loop().root.get_node_or_null("Global")
	return null

static func play_weapon_fire_audio(weapon_name: String, position = null) -> void:
	var audio_mgr = Engine.get_main_loop().root.get_node_or_null("AudioManager") if Engine.get_main_loop() else null
	if audio_mgr and audio_mgr.has_method("play_weapon_shot"):
		audio_mgr.play_weapon_shot(weapon_name, position)
	else:
		var g = _get_global()
		if g: g.play_sound(weapon_name, position)

static func play_empty_click(position = null) -> void:
	var audio_mgr = Engine.get_main_loop().root.get_node_or_null("AudioManager") if Engine.get_main_loop() else null
	if audio_mgr and audio_mgr.has_method("play_weapon_foley"):
		audio_mgr.play_weapon_foley("dry_fire", position)
	else:
		var g = _get_global()
		if g: g.play_sound("dry_fire", position)

static func play_reload_sequence(tree: SceneTree, position = null) -> void:
	var audio_mgr = tree.root.get_node_or_null("AudioManager") if tree else null
	
	# Step 1: Magazine release click (t = 0.0s)
	if audio_mgr:
		audio_mgr.play_weapon_foley("reload_mag_out", position)
	else:
		var g = _get_global()
		if g: g.play_sound("hit", position)
	
	# Step 2: Fresh magazine insertion (t = 0.45s)
	tree.create_timer(0.45).timeout.connect(func():
		if audio_mgr:
			audio_mgr.play_weapon_foley("reload_mag_in", position)
		else:
			var g2 = _get_global()
			if g2: g2.play_sound("perk", position)
	)
	
	# Step 3: Bolt-catch slap / chamber rack (t = 0.90s)
	tree.create_timer(0.90).timeout.connect(func():
		if audio_mgr:
			audio_mgr.play_weapon_foley("reload_bolt_rack", position)
		else:
			var g3 = _get_global()
			if g3: g3.play_sound("rifle", position)
	)

static func play_casing_bounce(tree: SceneTree, position = null, delay: float = 0.25) -> void:
	tree.create_timer(delay).timeout.connect(func():
		var casing_variant = "casing_%d" % (randi() % 3 + 1)
		var audio_mgr = tree.root.get_node_or_null("AudioManager") if tree else null
		if audio_mgr:
			audio_mgr.play_sound(casing_variant, position, "Foley")
		else:
			var g = _get_global()
			if g: g.play_sound("hit", position)
	)
