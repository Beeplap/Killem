extends Node

## Tactical Network Manager Singleton for KillEm Co-op Multiplayer
## Manages ENetMultiplayerPeer connection lifecycle, 16-player hosting,
## client join sequences, bandwidth optimization (30Hz tick rate),
## state replication, and hot-join synchronization.

signal peer_connected(peer_id: int)
signal peer_disconnected(peer_id: int)
signal connected_to_server()
signal connection_failed()
signal server_disconnected()
signal match_state_synced(wave: int, score: int, scrap: int)
signal player_list_changed()

const DEFAULT_PORT: int = 7777
const MAX_PLAYERS_CAP: int = 16
const NETWORK_TICK_HZ: float = 30.0

var peer: ENetMultiplayerPeer = null
var current_server_name: String = "Alpha Squad"
var current_port: int = DEFAULT_PORT
var max_player_limit: int = 16
var connected_peers: Array[int] = []

const LAN_DISCOVERY_SCRIPT = preload("res://scripts/network/lan_discovery.gd")
var lan_discovery: Node = null

# Network rate optimization
var net_tick_timer: float = 0.0
const NET_TICK_INTERVAL: float = 1.0 / NETWORK_TICK_HZ

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	# Instantiate dedicated child LAN Discovery node
	lan_discovery = LAN_DISCOVERY_SCRIPT.new()
	lan_discovery.name = "LanDiscovery"
	add_child(lan_discovery)

func get_lan_discovery() -> Node:
	return lan_discovery
	
	_connect_multiplayer_signals()

func _connect_multiplayer_signals() -> void:
	multiplayer.peer_connected.connect(_on_multiplayer_peer_connected)
	multiplayer.peer_disconnected.connect(_on_multiplayer_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_multiplayer_connected_to_server)
	multiplayer.connection_failed.connect(_on_multiplayer_connection_failed)
	multiplayer.server_disconnected.connect(_on_multiplayer_server_disconnected)

# ------------------------------------------------------------------------------
# HOST OPERATIONS
# ------------------------------------------------------------------------------

func host_game(server_name: String, port: int = DEFAULT_PORT, max_clients: int = 15) -> Error:
	disconnect_game()
	
	current_server_name = server_name if not server_name.is_empty() else "Alpha Squad"
	current_port = port
	max_player_limit = clampi(max_clients + 1, 2, MAX_PLAYERS_CAP)
	
	peer = ENetMultiplayerPeer.new()
	# Up to 15 remote clients + 1 host = 16 total
	var err: Error = peer.create_server(port, max_clients)
	if err != OK:
		print("[NETWORK] Failed to create ENet server on port %d! (Error: %d)" % [port, err])
		peer = null
		return err
	
	multiplayer.multiplayer_peer = peer
	multiplayer.multiplayer_poll = true
	connected_peers.clear()
	
	# Start background UDP LAN announcements
	lan_discovery.start_broadcasting(current_server_name, current_port, max_player_limit, 1, Global.current_wave)
	
	# Connect wave change to broadcast announcements
	if not Global.wave_changed.is_connected(_on_wave_changed):
		Global.wave_changed.connect(_on_wave_changed)
	
	print("[NETWORK] Server created successfully! Hosting '%s' on port %d (Max: %d players)" % [
		current_server_name, current_port, max_player_limit
	])
	return OK

# ------------------------------------------------------------------------------
# CLIENT OPERATIONS
# ------------------------------------------------------------------------------

func join_game(target_ip: String, port: int = DEFAULT_PORT) -> Error:
	disconnect_game()
	
	var sanitized_ip = target_ip.strip_edges()
	if sanitized_ip.is_empty():
		sanitized_ip = "127.0.0.1"
	
	current_port = port
	peer = ENetMultiplayerPeer.new()
	var err: Error = peer.create_client(sanitized_ip, port)
	if err != OK:
		print("[NETWORK] Failed to create ENet client targetting %s:%d (Error: %d)" % [sanitized_ip, port, err])
		peer = null
		return err
	
	multiplayer.multiplayer_peer = peer
	multiplayer.multiplayer_poll = true
	connected_peers.clear()
	
	print("[NETWORK] Attempting to connect to %s:%d..." % [sanitized_ip, port])
	return OK

func disconnect_game() -> void:
	if lan_discovery:
		lan_discovery.stop_broadcasting()
		lan_discovery.stop_listening()
	
	if Global.wave_changed.is_connected(_on_wave_changed):
		Global.wave_changed.disconnect(_on_wave_changed)
	
	if peer:
		peer.close()
		peer = null
	
	multiplayer.multiplayer_peer = null
	connected_peers.clear()
	print("[NETWORK] Disconnected and multiplayer peer reset.")

# ------------------------------------------------------------------------------
# MULTIPLAYER SIGNAL HANDLERS
# ------------------------------------------------------------------------------

func _on_multiplayer_peer_connected(id: int) -> void:
	print("[NETWORK] Peer connected: %d" % id)
	if not connected_peers.has(id):
		connected_peers.append(id)
	
	if is_server():
		# Update LAN broadcaster with updated squad count
		lan_discovery.update_broadcast_data(get_player_count(), Global.current_wave)
		
		# Send current world snapshot to late-joining client (Hot-Join synchronization)
		sync_initial_state.rpc_id(id, Global.current_wave, Global.score, GameManager.scrap)
	
	peer_connected.emit(id)
	player_list_changed.emit()

func _on_multiplayer_peer_disconnected(id: int) -> void:
	print("[NETWORK] Peer disconnected: %d" % id)
	connected_peers.erase(id)
	
	if is_server():
		lan_discovery.update_broadcast_data(get_player_count(), Global.current_wave)
	
	peer_disconnected.emit(id)
	player_list_changed.emit()

func _on_multiplayer_connected_to_server() -> void:
	print("[NETWORK] Successfully connected to server!")
	connected_to_server.emit()

func _on_multiplayer_connection_failed() -> void:
	print("[NETWORK] Connection attempt to server failed.")
	disconnect_game()
	connection_failed.emit()

func _on_multiplayer_server_disconnected() -> void:
	print("[NETWORK] Server disconnected.")
	disconnect_game()
	server_disconnected.emit()

func _on_wave_changed(wave_num: int) -> void:
	if is_server() and lan_discovery:
		lan_discovery.update_broadcast_data(get_player_count(), wave_num)

# ------------------------------------------------------------------------------
# STATE SYNCHRONIZATION RPC
# ------------------------------------------------------------------------------

@rpc("call_remote", "reliable")
func sync_initial_state(current_wave: int, score: int, scrap: int) -> void:
	# Client updates HUD, wave tracking, and economy immediately
	GameManager.current_wave = current_wave
	GameManager.total_score = score
	GameManager.scrap = scrap
	print("[NETWORK] Initial match state synchronized: Wave %d | Score %d | Scrap %d" % [current_wave, score, scrap])
	match_state_synced.emit(current_wave, score, scrap)

# ------------------------------------------------------------------------------
# STATUS HELPERS
# ------------------------------------------------------------------------------

func is_server() -> bool:
	return multiplayer.has_multiplayer_peer() and multiplayer.is_server()

func is_network_active() -> bool:
	if not multiplayer.has_multiplayer_peer():
		return false
	return multiplayer.multiplayer_peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED

func get_local_peer_id() -> int:
	if multiplayer.has_multiplayer_peer():
		return multiplayer.get_unique_id()
	return 1

func get_player_count() -> int:
	if not is_network_active():
		return 1
	# 1 (local peer) + remote connected peers
	return 1 + connected_peers.size()
