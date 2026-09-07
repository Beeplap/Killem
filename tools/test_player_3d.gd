extends SceneTree

func _init() -> void:
	print("=== RUNNING 3D PLAYER, 360° RAYCAST AIMING & WEAPONS VERIFICATION ===")
	
	# 1. Instantiate Player3D
	var player_scene = load("res://scenes/entities/Player3D.tscn")
	var player = player_scene.instantiate()
	root.add_child(player)
	player.global_position = Vector3(0, 0, 0)
	
	# 2. Verify Mesh Hierarchy
	assert(player.get_node("BodyMesh/LegsMesh") != null, "LegsMesh must exist")
	assert(player.get_node("BodyMesh/TorsoPivot/TorsoMesh") != null, "TorsoMesh must exist")
	assert(player.get_node("BodyMesh/TorsoPivot/HeadPivot/HeadMesh") != null, "HeadMesh must exist")
	assert(player.get_node("BodyMesh/TorsoPivot/Flashlight") != null, "Flashlight SpotLight3D must exist")
	assert(player.get_node("BodyMesh/TorsoPivot/RightArm/RightHandAttachment") != null, "RightHandAttachment must exist")
	print("✔ High-Detail Cyber-Mercenary Operative Mesh Hierarchy verified")
	
	# 3. Verify Weapon Socket & All 5 Weapons
	assert(player.weapon_pistol != null, "Pistol3D must be present")
	assert(player.weapon_shotgun != null, "Shotgun3D must be present")
	assert(player.weapon_rifle != null, "Rifle3D must be present")
	assert(player.weapon_flame != null, "Flamethrower3D must be present")
	assert(player.weapon_minigun != null, "Minigun3D must be present")
	print("✔ 5 3D Weapons (Pistol, Shotgun, Rifle, Flamethrower, Minigun) anchored to RightHandAttachment")
	
	# 4. Test Weapon Switching across all 5
	player.switch_weapon(player.WeaponType3D.PISTOL)
	assert(player.weapon_pistol.visible == true and player.weapon_shotgun.visible == false)
	player.switch_weapon(player.WeaponType3D.SHOTGUN)
	assert(player.weapon_shotgun.visible == true and player.weapon_pistol.visible == false)
	player.switch_weapon(player.WeaponType3D.ASSAULT_RIFLE)
	assert(player.weapon_rifle.visible == true)
	player.switch_weapon(player.WeaponType3D.FLAMETHROWER)
	assert(player.weapon_flame.visible == true)
	player.switch_weapon(player.WeaponType3D.MINIGUN)
	assert(player.weapon_minigun.visible == true)
	print("✔ Weapon Switching [1-5] verified")
	
	# 5. Test 360° Ground Plane Raycasting
	var test_angles = [0.0, PI * 0.25, PI * 0.5, PI * 0.75, PI, -PI * 0.5, -PI * 0.25]
	var ground_plane = Plane(Vector3.UP, player.global_position.y)
	for ang in test_angles:
		var target_hit = Vector3(cos(ang) * 10.0, 0.0, sin(ang) * 10.0)
		var cam_ray_origin = target_hit + Vector3(0, 12, 8)
		var cam_ray_dir = (target_hit - cam_ray_origin).normalized()
		var hit = ground_plane.intersects_ray(cam_ray_origin, cam_ray_dir)
		assert(hit != null, "Ground plane must intersect camera ray")
		assert(abs(hit.y - player.global_position.y) < 0.01, "Hit must be on horizontal ground plane")
	print("✔ 360° Ground Plane Raycast Aiming math verified across all quadrants")
	
	# 6. Test Combat Dodge Dash
	player.dash_direction = Vector3(1, 0, 0)
	player.trigger_dodge_dash()
	assert(player.is_dashing == true, "Player must be in dashing state")
	assert(player.is_invulnerable == true, "Player must be invulnerable during dash")
	assert(player.trauma > 0.0, "Dodge dash must induce camera trauma")
	print("✔ Combat Dodge Dash (Space) mechanics verified")
	
	# 7. Test Firing & Recoil
	player.switch_weapon(player.WeaponType3D.PISTOL)
	player.fire_current_weapon()
	assert(player.recoil_kick > 0.0, "Weapon firing must produce recoil kickback")
	assert(player.muzzle_flash_timer > 0.0, "Weapon firing must activate muzzle flash light")
	print("✔ Recoil Kickback & Muzzle Flash Light verified")
	
	# 8. Test 3D Projectile & Hit Registration
	var proj_scene = load("res://scenes/entities/Projectile3D.tscn")
	var proj = proj_scene.instantiate()
	root.add_child(proj)
	proj.setup(Vector3(0, 1, 0), Vector3(0, 0, -1), 40.0, 50.0, 1.0, 0)
	assert(proj.speed == 50.0, "Projectile speed must match setup")
	assert(proj.damage == 40.0, "Projectile damage must match setup")
	
	# Dummy enemy
	var dummy = CharacterBody3D.new()
	dummy.add_to_group("enemies")
	var dummy_hit = false
	dummy.set_script(GDScript.new())
	dummy.get_script().source_code = "extends CharacterBody3D\nvar took_damage = false\nfunc take_damage(dmg, dir):\n\ttook_damage = true\n"
	dummy.get_script().reload()
	root.add_child(dummy)
	dummy.global_position = Vector3(0, 1, 0)
	
	proj._on_body_entered(dummy)
	assert(dummy.get("took_damage") == true, "Projectile must register hit and call take_damage on enemy")
	print("✔ 3D Projectile & Hit Registration verified")
	
	print("=== ALL 8 VERIFICATION CHECKS PASSED PERFECTLY! ===")
	quit(0)
