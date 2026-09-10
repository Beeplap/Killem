class_name LanDiscovery
extends Node

## Automated UDP LAN Discovery System for KillEm Co-op Multiplayer
## Enables seamless zero-config server discovery over local networks.
## Broadcaster runs on Host (port 7778).
## Scanner runs on Clients browsing the LAN menu.

signal server_found(server_info: Dictionary)
signal server_updated(server_info: Dictionary)
signal server_removed(server_key: String)
signal server_list_updated(servers: Array[Dictionary])

const BROADCAST_PORT: int = 7778
const STALE_TIMEOUT_SEC: float = 3.5
const BROADCAST_INTERVAL_SEC: float = 1.0

# Broadcaster State
var is_broadcasting: bool = false
var broadcast_peer: PacketPeerUDP = null
var broadcast_timer: float = 0.0
var broadcast_data: Dictionary = {}

# Scanner State
var is_listening: bool = false
var listen_peer: PacketPeerUDP = null
var known_servers: Dictionary = {} # Key: "IP:Port" -> Dictionary

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

func _process(delta: float) -> void:
	if is_broadcasting:
		_process_broadcast(delta)
	
	if is_listening:
		_process_listening(delta)

# ------------------------------------------------------------------------------
# BROADCASTER (Runs on Host)
# ------------------------------------------------------------------------------

func start_broadcasting(server_name: String, game_port: int = 7777, max_players: int = 16, current_players: int = 1, wave: int = 1) -> bool:
	stop_broadcasting()
	
	broadcast_peer = PacketPeerUDP.new()
	broadcast_peer.set_broadcast_enabled(true)
	
	broadcast_data = {
		"server_name": server_name,
		"host_ip": get_local_ip(),
		"port": game_port,
		"players": current_players,
		"max_players": max_players,
		"wave": wave,
		"timestamp": Time.get_ticks_msec()
	}
	
	is_broadcasting = true
	broadcast_timer = BROADCAST_INTERVAL_SEC # Send immediately on first tick
	print("[LAN DISCOVERY] Started broadcasting server: '%s' on port %d" % [server_name, game_port])
	return true

func update_broadcast_data(players: int, wave: int, server_name: String = "") -> void:
	if not is_broadcasting:
		return
	broadcast_data["players"] = players
	broadcast_data["wave"] = wave
	if not server_name.is_empty():
		broadcast_data["server_name"] = server_name

func stop_broadcasting() -> void:
	if not is_broadcasting and broadcast_peer == null:
		return
	is_broadcasting = false
	if broadcast_peer:
		broadcast_peer.close()
		broadcast_peer = null
	print("[LAN DISCOVERY] Stopped broadcasting server.")

func _process_broadcast(delta: float) -> void:
	broadcast_timer += delta
	if broadcast_timer < BROADCAST_INTERVAL_SEC:
		return
	broadcast_timer = 0.0
	
	if broadcast_peer == null:
		return
	
	broadcast_data["timestamp"] = Time.get_ticks_msec()
	var payload_str: String = JSON.stringify(broadcast_data)
	var packet_data: PackedByteArray = payload_str.to_utf8_buffer()
	
	# Broadcast to LAN subnet
	broadcast_peer.set_dest_address("255.255.255.255", BROADCAST_PORT)
	broadcast_peer.put_packet(packet_data)
	
	# Also send to localhost for same-machine dual-instance testing
	broadcast_peer.set_dest_address("127.0.0.1", BROADCAST_PORT)
	broadcast_peer.put_packet(packet_data)

# ------------------------------------------------------------------------------
# SCANNER / LISTENER (Runs on Client)
# ------------------------------------------------------------------------------

func start_listening() -> bool:
	stop_listening()
	
	listen_peer = PacketPeerUDP.new()
	# Bind with reuse_address so multiple local instances can listen to announcements
	var err = listen_peer.bind(BROADCAST_PORT, "*")
	if err != OK:
		print("[LAN DISCOVERY] Failed to bind scanner on port %d (Error: %d)" % [BROADCAST_PORT, err])
		listen_peer.close()
		listen_peer = null
		return false
	
	is_listening = true
	known_servers.clear()
	print("[LAN DISCOVERY] Scanner active and listening on port %d..." % BROADCAST_PORT)
	return true

func stop_listening() -> void:
	if not is_listening and listen_peer == null:
		return
	is_listening = false
	if listen_peer:
		listen_peer.close()
		listen_peer = null
	known_servers.clear()
	print("[LAN DISCOVERY] Scanner stopped.")

func _process_listening(_delta: float) -> void:
	if listen_peer == null:
		return
	
	var list_changed: bool = false
	var current_time_sec: float = Time.get_ticks_msec() * 0.001
	
	# Drain incoming UDP packets
	while listen_peer.get_available_packet_count() > 0:
		var packet: PackedByteArray = listen_peer.get_packet()
		var sender_ip: String = listen_peer.get_packet_ip()
		var packet_str: String = packet.get_string_from_utf8()
		
		var json_result = JSON.parse_string(packet_str)
		if typeof(json_result) != TYPE_DICTIONARY:
			continue
		
		var data: Dictionary = json_result
		var port: int = int(data.get("port", 7777))
		var host_ip: String = sender_ip
		# If received via loopback or empty, use sender IP
		if host_ip == "127.0.0.1" and data.has("host_ip") and not String(data["host_ip"]).is_empty():
			# Keep 127.0.0.1 for local test if connecting locally, or store host_ip
			pass
		
		var server_key: String = "%s:%d" % [sender_ip, port]
		var server_name: String = str(data.get("server_name", "Unknown Squad"))
		var players: int = int(data.get("players", 1))
		var max_players: int = int(data.get("max_players", 16))
		var wave: int = int(data.get("wave", 1))
		var sent_timestamp: int = int(data.get("timestamp", 0))
		
		var estimated_ping: int = 12
		if sent_timestamp > 0:
			var now_msec: int = Time.get_ticks_msec()
			if now_msec >= sent_timestamp:
				estimated_ping = clampi(now_msec - sent_timestamp, 4, 999)
		
		var server_entry: Dictionary = {
			"key": server_key,
			"ip": sender_ip,
			"port": port,
			"server_name": server_name,
			"players": players,
			"max_players": max_players,
			"wave": wave,
			"ping": estimated_ping,
			"last_seen": current_time_sec
		}
		
		if not known_servers.has(server_key):
			known_servers[server_key] = server_entry
			server_found.emit(server_entry)
			list_changed = true
			print("[LAN DISCOVERY] Discovered server: %s (%s)" % [server_name, server_key])
		else:
			known_servers[server_key] = server_entry
			server_updated.emit(server_entry)
			list_changed = true
	
	# Cull stale servers inactive for > STALE_TIMEOUT_SEC (3.5s)
	var keys_to_remove: Array[String] = []
	for key in known_servers:
		var entry: Dictionary = known_servers[key]
		if current_time_sec - entry["last_seen"] > STALE_TIMEOUT_SEC:
			keys_to_remove.append(key)
	
	for key in keys_to_remove:
		print("[LAN DISCOVERY] Removing stale server: %s" % key)
		known_servers.erase(key)
		server_removed.emit(key)
		list_changed = true
	
	if list_changed:
		server_list_updated.emit(get_server_list())

func get_server_list() -> Array[Dictionary]:
	var list: Array[Dictionary] = []
	for key in known_servers:
		list.append(known_servers[key])
	return list

# ------------------------------------------------------------------------------
# UTILITIES
# ------------------------------------------------------------------------------

static func get_local_ip() -> String:
	var addresses = IP.get_local_addresses()
	for addr in addresses:
		# Exclude loopback and link-local IPv6 addresses
		if addr.contains(":") or addr.begins_with("127.") or addr.begins_with("169.254."):
			continue
		return addr
	return "127.0.0.1"

func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		stop_broadcasting()
		stop_listening()
