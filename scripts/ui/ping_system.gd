extends Node2D
class_name PingSystem

## Tactical Ping Engine
## Listens for Middle-Click (PC) or HUD/Mobile button.
## Raycasts into the world to identify targets (Enemies, Supplies, or Movement destinations).
## Spawns synchronized PingMarkers for 6.0 seconds across all squad members.

signal ping_created(type: int, world_pos: Vector2, target_node: Node2D)

enum PingType { MOVE, ENEMY, SUPPLIES }

const PING_MARKER_SCENE = preload("res://scenes/ui/PingMarker.tscn")

@export var max_target_detect_radius: float = 48.0

func _ready() -> void:
	add_to_group("ping_system")
	z_index = 35

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_MIDDLE and event.pressed:
			var mouse_pos = get_global_mouse_position()
			trigger_ping(mouse_pos)
			get_viewport().set_input_as_handled()

func trigger_ping(world_pos = null) -> void:
	var target_pos: Vector2
	if world_pos != null and world_pos is Vector2:
		target_pos = world_pos
	else:
		# Fallback to local player aiming direction or screen center
		var player = _get_local_player()
		if player and is_instance_valid(player):
			var aim_dir = (get_global_mouse_position() - player.global_position).normalized()
			if Global.virtual_aim_active and Global.virtual_aim_dir != Vector2.ZERO:
				aim_dir = Global.virtual_aim_dir
			target_pos = player.global_position + aim_dir * 180.0
		else:
			target_pos = get_global_mouse_position()
	
	# Raycast / Query physics and groups to detect target
	var ping_type: int = PingType.MOVE
	var target_node: Node2D = _detect_target_at_pos(target_pos)
	
	if target_node and is_instance_valid(target_node):
		if target_node.is_in_group("enemies") or target_node.is_in_group("boss"):
			ping_type = PingType.ENEMY
			target_pos = target_node.global_position
		elif target_node.is_in_group("pickups") or target_node.is_in_group("crates") or target_node.is_in_group("ammo") or target_node.is_in_group("supply_drops") or target_node.is_in_group("armory_pods"):
			ping_type = PingType.SUPPLIES
			target_pos = target_node.global_position
	
	# Broadcast or spawn locally
	if NetworkManager.is_network_active():
		var node_path: NodePath = target_node.get_path() if is_instance_valid(target_node) else NodePath("")
		net_spawn_ping.rpc(ping_type, target_pos, node_path)
	else:
		_execute_spawn_ping(ping_type, target_pos, target_node)

@rpc("any_peer", "call_local", "reliable")
func net_spawn_ping(type_idx: int, pos: Vector2, target_path: NodePath) -> void:
	var target: Node2D = null
	if not target_path.is_empty():
		target = get_node_or_null(target_path) as Node2D
	_execute_spawn_ping(type_idx, pos, target)

func _execute_spawn_ping(type_idx: int, pos: Vector2, target: Node2D = null) -> void:
	var marker = PING_MARKER_SCENE.instantiate() as PingMarker
	add_child(marker)
	marker.setup_ping(type_idx, pos, target)
	ping_created.emit(type_idx, pos, target)
	
	# UI feedback toast
	match type_idx:
		PingType.MOVE:
			Global.show_notification("TACTICAL PING", "Waypoint placed: MOVE HERE", Color(0.98, 0.85, 0.15))
		PingType.ENEMY:
			Global.show_notification("TACTICAL PING", "Priority target: FOCUS TARGET", Color(1.0, 0.25, 0.2))
		PingType.SUPPLIES:
			Global.show_notification("TACTICAL PING", "Resources marked: SUPPLIES", Color(0.25, 0.8, 1.0))

func _detect_target_at_pos(pos: Vector2) -> Node2D:
	# 1. Direct space state point query
	var space_state = get_world_2d().direct_space_state
	if space_state:
		var point_query = PhysicsPointQueryParameters2D.new()
		point_query.position = pos
		point_query.collide_with_areas = true
		point_query.collide_with_bodies = true
		var results = space_state.intersect_point(point_query, 16)
		for res in results:
			var col = res.collider
			if col and is_instance_valid(col):
				if col.is_in_group("enemies") or col.is_in_group("boss"):
					return col
				if col.is_in_group("pickups") or col.is_in_group("crates") or col.is_in_group("ammo") or col.is_in_group("supply_drops") or col.is_in_group("armory_pods"):
					return col
	
	# 2. Proximity search for nearby enemies within detect radius
	var best_dist = max_target_detect_radius
	var best_candidate: Node2D = null
	
	var enemies = get_tree().get_nodes_in_group("enemies")
	for e in enemies:
		if is_instance_valid(e) and e is Node2D:
			var d = pos.distance_to(e.global_position)
			if d < best_dist:
				best_dist = d
				best_candidate = e
	
	if best_candidate != null:
		return best_candidate
	
	# 3. Proximity search for nearby supplies/drops within detect radius
	var supplies = get_tree().get_nodes_in_group("pickups") + get_tree().get_nodes_in_group("supply_drops") + get_tree().get_nodes_in_group("armory_pods")
	for s in supplies:
		if is_instance_valid(s) and s is Node2D:
			var d = pos.distance_to(s.global_position)
			if d < best_dist:
				best_dist = d
				best_candidate = s
	
	return best_candidate

func _get_local_player() -> Node2D:
	var players = get_tree().get_nodes_in_group("player")
	for p in players:
		if is_instance_valid(p) and p is Node2D:
			if NetworkManager.is_network_active() and p.has_method("is_multiplayer_authority"):
				if p.is_multiplayer_authority():
					return p
			else:
				return p
	return null
