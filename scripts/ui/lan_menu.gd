class_name LanMenu
extends CanvasLayer

## Tactical Co-op LAN Menu
## Integrates UDP LAN server scanning, real-time server list display,
## hosting setup with up to 16 players, and direct IP fallback.

@export var game_level_scene: String = "res://scenes/MainLevel.tscn"

@onready var modal_container: Control = $ModalBackdrop
@onready var server_name_input: LineEdit = $ModalBackdrop/Panel/Margin/VBox/Columns/HostCol/ServerNameInput
@onready var max_players_spin: SpinBox = $ModalBackdrop/Panel/Margin/VBox/Columns/HostCol/MaxPlayersSpin
@onready var host_port_input: LineEdit = $ModalBackdrop/Panel/Margin/VBox/Columns/HostCol/HostPortInput
@onready var host_button: Button = $ModalBackdrop/Panel/Margin/VBox/Columns/HostCol/HostButton

@onready var scanner_status_label: Label = $ModalBackdrop/Panel/Margin/VBox/Columns/JoinCol/ScannerStatusLabel
@onready var server_item_list: ItemList = $ModalBackdrop/Panel/Margin/VBox/Columns/JoinCol/ServerItemList
@onready var connect_button: Button = $ModalBackdrop/Panel/Margin/VBox/Columns/JoinCol/JoinActionRow/ConnectButton
@onready var refresh_button: Button = $ModalBackdrop/Panel/Margin/VBox/Columns/JoinCol/JoinActionRow/RefreshButton

@onready var direct_ip_input: LineEdit = $ModalBackdrop/Panel/Margin/VBox/Columns/JoinCol/DirectBox/DirectIPInput
@onready var direct_port_input: LineEdit = $ModalBackdrop/Panel/Margin/VBox/Columns/JoinCol/DirectBox/DirectPortInput
@onready var direct_connect_btn: Button = $ModalBackdrop/Panel/Margin/VBox/Columns/JoinCol/DirectBox/DirectConnectButton

@onready var status_bar_label: Label = $ModalBackdrop/Panel/Margin/VBox/Footer/StatusLabel
@onready var close_button: Button = $ModalBackdrop/Panel/Margin/VBox/Footer/CloseButton

var detected_servers: Array[Dictionary] = []
var selected_server_index: int = -1

func _ready() -> void:
	visible = false
	_connect_signals()

func _connect_signals() -> void:
	if host_button:
		host_button.pressed.connect(_on_host_pressed)
	if connect_button:
		connect_button.pressed.connect(_on_connect_pressed)
		connect_button.disabled = true
	if refresh_button:
		refresh_button.pressed.connect(_on_refresh_pressed)
	if direct_connect_btn:
		direct_connect_btn.pressed.connect(_on_direct_connect_pressed)
	if close_button:
		close_button.pressed.connect(close_menu)
	
	if server_item_list:
		server_item_list.item_selected.connect(_on_server_item_selected)
		server_item_list.item_activated.connect(func(_idx: int): _on_connect_pressed())

func open_menu() -> void:
	visible = true
	selected_server_index = -1
	if connect_button:
		connect_button.disabled = true
	
	# Set default server name based on machine / OS
	if server_name_input:
		var username = OS.get_environment("USERNAME")
		if username.is_empty():
			username = OS.get_environment("USER")
		if username.is_empty():
			username = "Striker"
		server_name_input.text = "%s's Squad" % username
	
	# Connect NetworkManager & LanDiscovery events
	var discovery = NetworkManager.get_lan_discovery() if NetworkManager else null
	if discovery:
		if not discovery.server_list_updated.is_connected(_on_server_list_updated):
			discovery.server_list_updated.connect(_on_server_list_updated)
		discovery.start_listening()
	
	if NetworkManager:
		if not NetworkManager.connected_to_server.is_connected(_on_connected_to_server):
			NetworkManager.connected_to_server.connect(_on_connected_to_server)
		if not NetworkManager.connection_failed.is_connected(_on_connection_failed):
			NetworkManager.connection_failed.connect(_on_connection_failed)
		if not NetworkManager.server_disconnected.is_connected(_on_server_disconnected):
			NetworkManager.server_disconnected.connect(_on_server_disconnected)
	
	_set_status("Scanning local subnet on UDP 7778 for active Squads...", Color(0.3, 0.85, 1.0))

func close_menu() -> void:
	visible = false
	var discovery = NetworkManager.get_lan_discovery() if NetworkManager else null
	if discovery:
		discovery.stop_listening()
		if discovery.server_list_updated.is_connected(_on_server_list_updated):
			discovery.server_list_updated.disconnect(_on_server_list_updated)

func _on_server_list_updated(servers: Array[Dictionary]) -> void:
	detected_servers = servers
	if server_item_list == null:
		return
	
	server_item_list.clear()
	
	if detected_servers.is_empty():
		server_item_list.add_item("No active LAN Squads detected. Start hosting or use Direct IP.")
		server_item_list.set_item_disabled(0, true)
		if connect_button:
			connect_button.disabled = true
		selected_server_index = -1
		return
	
	for i in range(detected_servers.size()):
		var s = detected_servers[i]
		var item_str = "[%s]  Wave %d  •  Players: %d/%d  •  Ping: %dms  •  (%s:%d)" % [
			str(s.get("server_name", "Squad")).to_upper(),
			int(s.get("wave", 1)),
			int(s.get("players", 1)),
			int(s.get("max_players", 16)),
			int(s.get("ping", 12)),
			str(s.get("ip", "127.0.0.1")),
			int(s.get("port", 7777))
		]
		server_item_list.add_item(item_str)
	
	if selected_server_index >= 0 and selected_server_index < detected_servers.size():
		server_item_list.select(selected_server_index)
		if connect_button:
			connect_button.disabled = false
	else:
		selected_server_index = -1
		if connect_button:
			connect_button.disabled = true

func _on_server_item_selected(index: int) -> void:
	if index >= 0 and index < detected_servers.size():
		selected_server_index = index
		if connect_button:
			connect_button.disabled = false
		var s = detected_servers[index]
		_set_status("Selected Squad: %s (%s:%d)" % [s.get("server_name"), s.get("ip"), s.get("port")], Color(0.95, 0.85, 0.3))

func _on_host_pressed() -> void:
	var s_name = server_name_input.text.strip_edges() if server_name_input else "Alpha Squad"
	if s_name.is_empty():
		s_name = "Alpha Squad"
	
	var port = int(host_port_input.text.strip_edges()) if host_port_input and not host_port_input.text.is_empty() else 7777
	var max_p = int(max_players_spin.value) if max_players_spin else 16
	# max_clients = max_players - 1 (since host is 1 player)
	var max_clients = clampi(max_p - 1, 1, 15)
	
	_set_status("Initializing Tactical Server: '%s' (Port: %d)..." % [s_name, port], Color(0.3, 0.95, 0.55))
	
	var err = NetworkManager.host_game(s_name, port, max_clients)
	if err != OK:
		_set_status("Host failed: Error code %d" % err, Color(0.95, 0.3, 0.2))
		return
	
	Global.reset_state()
	Global.play_sound("wave_start")
	close_menu()
	get_tree().change_scene_to_file(game_level_scene)

func _on_connect_pressed() -> void:
	if selected_server_index < 0 or selected_server_index >= detected_servers.size():
		_set_status("Select an active Squad from the list first.", Color(0.95, 0.5, 0.2))
		return
	
	var s = detected_servers[selected_server_index]
	var ip = str(s.get("ip", "127.0.0.1"))
	var port = int(s.get("port", 7777))
	_execute_join(ip, port)

func _on_direct_connect_pressed() -> void:
	var ip = direct_ip_input.text.strip_edges() if direct_ip_input else "127.0.0.1"
	if ip.is_empty():
		ip = "127.0.0.1"
	var port = int(direct_port_input.text.strip_edges()) if direct_port_input and not direct_port_input.text.is_empty() else 7777
	_execute_join(ip, port)

func _execute_join(ip: String, port: int) -> void:
	_set_status("Connecting to Tactical Host at %s:%d..." % [ip, port], Color(0.3, 0.85, 1.0))
	if connect_button:
		connect_button.disabled = true
	if direct_connect_btn:
		direct_connect_btn.disabled = true
	
	var err = NetworkManager.join_game(ip, port)
	if err != OK:
		_set_status("Connection initialization failed: Error %d" % err, Color(0.95, 0.3, 0.2))
		if connect_button: connect_button.disabled = false
		if direct_connect_btn: direct_connect_btn.disabled = false

func _on_connected_to_server() -> void:
	_set_status("Connection established! Deploying to combat sector...", Color(0.3, 0.95, 0.55))
	Global.reset_state()
	Global.play_sound("wave_start")
	close_menu()
	get_tree().change_scene_to_file(game_level_scene)

func _on_connection_failed() -> void:
	_set_status("Connection refused or timed out. Verify IP and Port.", Color(0.95, 0.3, 0.2))
	if connect_button: connect_button.disabled = (selected_server_index < 0)
	if direct_connect_btn: direct_connect_btn.disabled = false

func _on_server_disconnected() -> void:
	_set_status("Host closed the session or server connection lost.", Color(0.95, 0.6, 0.2))
	if connect_button: connect_button.disabled = (selected_server_index < 0)
	if direct_connect_btn: direct_connect_btn.disabled = false

func _on_refresh_pressed() -> void:
	var discovery = NetworkManager.get_lan_discovery() if NetworkManager else null
	if discovery:
		discovery.start_listening()
	_set_status("Rescanning local network broadcast packets on port 7778...", Color(0.3, 0.85, 1.0))

func _set_status(msg: String, color: Color) -> void:
	if status_bar_label:
		status_bar_label.text = msg
		status_bar_label.add_theme_color_override("font_color", color)
