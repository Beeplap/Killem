extends Area2D
class_name ReviveZone

## Tactical Squad Revive Zone
## Attaches to downed players. Monitors proximity of alive teammates.
## When an alive teammate holds [E], channels revive over 4.0s.
## Displays a radial revive progress bar with medical cross reticle.
## Any damage sustained by the reviver immediately interrupts and cancels the channel.
## On completion, restores the downed player to 35% HP and clears downed state.

signal revive_started(reviver: Node2D)
signal revive_interrupted(reason: String)
signal revive_completed(downed_player: Node2D)

const REVIVE_DURATION: float = 4.0
const REVIVE_HEALTH_RATIO: float = 0.35

var is_active: bool = false
var revive_progress: float = 0.0
var current_reviver: Node2D = null

# Radial UI rendering properties
var radius: float = 24.0
var ring_width: float = 4.5
var progress_color: Color = Color(0.2, 0.95, 0.55)
var bg_color: Color = Color(0.1, 0.13, 0.16, 0.85)
var pulse_time: float = 0.0

@onready var collision_shape: CollisionShape2D = get_node_or_null("CollisionShape2D")

func _ready() -> void:
	z_index = 25
	monitoring = false
	monitorable = false
	visible = false
	set_process(false)

func activate() -> void:
	is_active = true
	revive_progress = 0.0
	current_reviver = null
	monitoring = true
	monitorable = true
	visible = true
	set_process(true)
	queue_redraw()

func deactivate() -> void:
	_cancel_channel("DEACTIVATED")
	is_active = false
	monitoring = false
	monitorable = false
	visible = false
	set_process(false)
	queue_redraw()

func _process(delta: float) -> void:
	if not is_active:
		return
	
	pulse_time += delta * 4.0
	
	var parent_player = get_parent()
	if not parent_player or not is_instance_valid(parent_player):
		return
	
	# If parent is no longer downed or is dead, deactivate
	if not parent_player.get("is_downed") or Global.is_game_over:
		deactivate()
		return
	
	# Find candidate alive teammates inside area
	var candidates: Array[Node2D] = []
	for body in get_overlapping_bodies():
		if is_instance_valid(body) and body != parent_player and body.is_in_group("player"):
			if not body.get("is_downed") and body.get("health", 100.0) > 0.0:
				candidates.append(body)
	
	if candidates.is_empty():
		if current_reviver != null:
			_cancel_channel("OUT OF RANGE")
		queue_redraw()
		return
	
	# Pick candidate: local player takes priority, or first valid teammate
	var candidate: Node2D = null
	for c in candidates:
		var is_local = c.is_multiplayer_authority() if NetworkManager.is_network_active() and c.has_method("is_multiplayer_authority") else true
		if is_local:
			candidate = c
			break
	if candidate == null and not candidates.is_empty():
		candidate = candidates[0]
	
	# Detect holding [E] (or simulated interaction flag)
	var is_pressing_e = Input.is_key_pressed(KEY_E) or Input.is_action_pressed("interact")
	if candidate and candidate.get("is_reviving"):
		is_pressing_e = true
	
	if is_pressing_e and candidate != null:
		if current_reviver != candidate:
			_start_channel(candidate)
		
		# Accumulate channel time
		revive_progress += delta
		queue_redraw()
		
		if revive_progress >= REVIVE_DURATION:
			_complete_revive(parent_player)
	else:
		if current_reviver != null:
			_cancel_channel("INPUT RELEASED")
		queue_redraw()

func _start_channel(reviver: Node2D) -> void:
	current_reviver = reviver
	revive_progress = 0.0
	
	# Listen for damage on reviver to cancel channel immediately
	if reviver.has_signal("player_took_damage") and not reviver.player_took_damage.is_connected(_on_reviver_took_damage):
		reviver.player_took_damage.connect(_on_reviver_took_damage)
	
	revive_started.emit(reviver)
	var audio_mgr = get_node_or_null("/root/AudioManager")
	if audio_mgr and audio_mgr.has_method("play_sound"):
		audio_mgr.play_sound("keycard_chirp")

func _on_reviver_took_damage(_amount: float) -> void:
	_cancel_channel("REVIVE INTERRUPTED: UNDER FIRE!")
	Global.show_notification("REVIVE INTERRUPTED", "Damage taken while reviving squad member!", Color(1.0, 0.3, 0.2))

func _cancel_channel(reason: String = "") -> void:
	if current_reviver != null:
		if current_reviver.has_signal("player_took_damage") and current_reviver.player_took_damage.is_connected(_on_reviver_took_damage):
			current_reviver.player_took_damage.disconnect(_on_reviver_took_damage)
		current_reviver = null
	
	if revive_progress > 0.0:
		revive_progress = 0.0
		revive_interrupted.emit(reason)
		queue_redraw()

func _complete_revive(parent_player: Node2D) -> void:
	if current_reviver != null:
		if current_reviver.has_signal("player_took_damage") and current_reviver.player_took_damage.is_connected(_on_reviver_took_damage):
			current_reviver.player_took_damage.disconnect(_on_reviver_took_damage)
		current_reviver = null
	
	revive_progress = 0.0
	revive_completed.emit(parent_player)
	
	if parent_player.has_method("revive"):
		parent_player.revive(REVIVE_HEALTH_RATIO)
	
	deactivate()

func _draw() -> void:
	if not is_active:
		return
	
	var draw_pos = Vector2(0, -48)
	var r = radius
	
	# Base tactical ring backing
	draw_circle(draw_pos, r + 4.0, bg_color)
	draw_arc(draw_pos, r, 0, TAU, 36, Color(0.3, 0.42, 0.52, 0.7), 2.0)
	
	if current_reviver != null and revive_progress > 0.0:
		# Radial progress arc
		var pct = clampf(revive_progress / REVIVE_DURATION, 0.0, 1.0)
		var start_angle = -PI / 2.0
		var end_angle = start_angle + (pct * TAU)
		
		# Pulsing glow arc
		var pulse = 1.0 + sin(pulse_time) * 0.12
		draw_arc(draw_pos, r, start_angle, end_angle, 48, progress_color * pulse, ring_width)
		
		# Center medical cross
		var cross_size = 7.0
		var cross_thick = 3.0
		var cross_col = Color(0.2, 1.0, 0.6, 0.95)
		draw_line(draw_pos - Vector2(cross_size, 0), draw_pos + Vector2(cross_size, 0), cross_col, cross_thick)
		draw_line(draw_pos - Vector2(0, cross_size), draw_pos + Vector2(0, cross_size), cross_col, cross_thick)
		
		# Countdown text
		var time_left = max(0.0, REVIVE_DURATION - revive_progress)
		var text = "REVIVING %.1fs" % time_left
		var font = ThemeDB.fallback_font
		if font:
			var font_size = 11
			var text_size = font.get_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size)
			draw_string(font, draw_pos + Vector2(-text_size.x * 0.5, -r - 8), text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size, progress_color)
	else:
		# Idle prompt icon
		var cross_size = 6.0
		var cross_thick = 2.5
		var icon_col = Color(0.9, 0.95, 1.0, 0.85)
		draw_line(draw_pos - Vector2(cross_size, 0), draw_pos + Vector2(cross_size, 0), icon_col, cross_thick)
		draw_line(draw_pos - Vector2(0, cross_size), draw_pos + Vector2(0, cross_size), icon_col, cross_thick)
		
		var text = "[HOLD E] REVIVE"
		var font = ThemeDB.fallback_font
		if font:
			var font_size = 11
			var text_size = font.get_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size)
			draw_string(font, draw_pos + Vector2(-text_size.x * 0.5, -r - 8), text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size, Color(0.95, 0.85, 0.2, 0.9))
