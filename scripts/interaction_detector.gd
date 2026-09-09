extends Node2D
class_name InteractionDetector

## Proximity Contextual UI & "Service All" Bulk Maintenance Engine
## Detects depleted turrets and damaged barbwire within 110px.
## Manages [E] single-target servicing (3.0s) and [F] bulk "Service All" servicing (N x 3.0s).

@export var interaction_radius: float = 120.0

var nearby_serviceables: Array[Node2D] = []
var candidates: Array[Node2D]:
	get: return nearby_serviceables
var nearest_target: Node2D = null

# Single channel state ([E])
var is_channeling_single: bool = false
var single_channel_time: float = 0.0
const SINGLE_SERVICE_DURATION: float = 3.0

# Bulk channel state ([F])
var is_channeling_bulk: bool = false
var bulk_channel_time: float = 0.0

@onready var prompt_panel: Control = $PromptPanel
@onready var prompt_label: Label = $PromptPanel/VBox/PromptLabel
@onready var progress_bar: ProgressBar = $PromptPanel/VBox/ProgressBar

func _ready() -> void:
	z_index = 20
	top_level = true
	if prompt_panel:
		prompt_panel.visible = false

func _process(delta: float) -> void:
	var player = get_parent()
	if not player or not is_instance_valid(player) or not (player is Node2D):
		return
	
	global_position = player.global_position
	
	_scan_serviceables(player.global_position)
	
	if nearby_serviceables.is_empty():
		_reset_channeling()
		if prompt_panel:
			prompt_panel.visible = false
		return
	
	if prompt_panel:
		prompt_panel.visible = true
	
	var count = nearby_serviceables.size()
	
	# Key input detection: E (Single), F (Bulk)
	var pressing_e = Input.is_key_pressed(KEY_E)
	var pressing_f = Input.is_key_pressed(KEY_F)
	
	# 1. Bulk Servicing [F]
	if pressing_f and count >= 2:
		is_channeling_bulk = true
		is_channeling_single = false
		single_channel_time = 0.0
		
		bulk_channel_time += delta
		var total_duration = SINGLE_SERVICE_DURATION * float(count)
		
		if progress_bar:
			progress_bar.max_value = total_duration
			progress_bar.value = bulk_channel_time
			progress_bar.modulate = Color(0.3, 0.95, 0.45)
		
		if prompt_label:
			prompt_label.text = "[HOLDING F] SERVICING ALL (%d/%d)... %.1fs" % [
				int(bulk_channel_time / SINGLE_SERVICE_DURATION),
				count,
				max(0.0, total_duration - bulk_channel_time)
			]
		
		# Check sequential completion per 3.0s
		var completed_chunks = int(bulk_channel_time / SINGLE_SERVICE_DURATION)
		for i in range(min(completed_chunks, count)):
			_apply_service(nearby_serviceables[i])
		
		if bulk_channel_time >= total_duration:
			# Complete all
			for item in nearby_serviceables:
				_apply_service(item)
			Global.play_sound("perk")
			_reset_channeling()
		return
	else:
		if is_channeling_bulk and not pressing_f:
			is_channeling_bulk = false
			bulk_channel_time = 0.0
	
	# 2. Single Target Servicing [E]
	if pressing_e and nearest_target and is_instance_valid(nearest_target):
		is_channeling_single = true
		single_channel_time += delta
		
		if progress_bar:
			progress_bar.max_value = SINGLE_SERVICE_DURATION
			progress_bar.value = single_channel_time
			progress_bar.modulate = Color(0.2, 0.85, 1.0)
		
		var action_name = "RELOADING TURRET" if nearest_target.is_in_group("turrets") else "REPAIRING BARBWIRE"
		if prompt_label:
			prompt_label.text = "[HOLDING E] %s... %.1fs" % [action_name, max(0.0, SINGLE_SERVICE_DURATION - single_channel_time)]
		
		if single_channel_time >= SINGLE_SERVICE_DURATION:
			_apply_service(nearest_target)
			Global.play_sound("perk")
			_reset_channeling()
		return
	else:
		if is_channeling_single and not pressing_e:
			is_channeling_single = false
			single_channel_time = 0.0
	
	# Idle prompt display
	if progress_bar:
		progress_bar.value = 0.0
	
	if prompt_label:
		if count >= 2:
			prompt_label.text = "[HOLD E] Service Target (3.0s) | [HOLD F] Service All (%d x 3.0s)" % count
		else:
			var target_type = "Reload Turret" if (nearest_target and nearest_target.is_in_group("turrets")) else "Repair Barbwire"
			prompt_label.text = "[HOLD E] %s (3.0s)" % target_type

func _scan_serviceables(p_pos: Vector2) -> void:
	nearby_serviceables.clear()
	nearest_target = null
	var min_dist = 999999.0
	
	# 1. Turrets needing ammo
	var turrets = get_tree().get_nodes_in_group("turrets")
	for t in turrets:
		if is_instance_valid(t) and t is Node2D:
			var needs = t.get("needs_ammo") or (t.get("current_ammo") != null and t.current_ammo <= 0)
			if needs:
				var d = p_pos.distance_to(t.global_position)
				if d <= interaction_radius:
					nearby_serviceables.append(t)
					if d < min_dist:
						min_dist = d
						nearest_target = t
	
	# 2. Barbwire needing repair
	var wires = get_tree().get_nodes_in_group("barbwire")
	for w in wires:
		if is_instance_valid(w) and w is Node2D:
			var max_d = w.get("max_durability") if w.get("max_durability") else 250.0
			var cur_d = w.get("current_durability") if w.get("current_durability") else 250.0
			if cur_d < max_d or w.get("needs_repair"):
				var d = p_pos.distance_to(w.global_position)
				if d <= interaction_radius:
					nearby_serviceables.append(w)
					if d < min_dist:
						min_dist = d
						nearest_target = w

func _apply_service(node: Node2D) -> void:
	if not is_instance_valid(node):
		return
	if node.has_method("perform_service"):
		node.perform_service()
	elif node.has_method("reload_turret"):
		node.reload_turret()
	elif node.has_method("repair_wire"):
		node.repair_wire()

func _reset_channeling() -> void:
	is_channeling_single = false
	single_channel_time = 0.0
	is_channeling_bulk = false
	bulk_channel_time = 0.0
	if progress_bar:
		progress_bar.value = 0.0
