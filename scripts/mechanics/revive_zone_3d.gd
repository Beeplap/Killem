extends Area3D
class_name ReviveZone3D

## Tactical Squad Revive Zone 3D
## Attaches to downed 3D players. Monitors proximity of alive teammates.
## When an alive teammate holds [E], channels revive over 4.0s.

signal revive_started(reviver: Node3D)
signal revive_interrupted(reason: String)
signal revive_completed(downed_player: Node3D)

const REVIVE_DURATION: float = 4.0
const REVIVE_HEALTH_RATIO: float = 0.35

var is_active: bool = false
var revive_progress: float = 0.0
var current_reviver: Node3D = null

@onready var collision_shape: CollisionShape3D = get_node_or_null("CollisionShape3D")
@onready var prompt_label: Label3D = get_node_or_null("PromptLabel")

func _ready() -> void:
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
	if prompt_label:
		prompt_label.text = "[HOLD E] REVIVE"
		prompt_label.modulate = Color(0.95, 0.85, 0.2)

func deactivate() -> void:
	_cancel_channel("DEACTIVATED")
	is_active = false
	monitoring = false
	monitorable = false
	visible = false
	set_process(false)

func _process(delta: float) -> void:
	if not is_active:
		return
	
	var parent_player = get_parent()
	if not parent_player or not is_instance_valid(parent_player):
		return
	
	if not parent_player.get("is_downed") or Global.is_game_over:
		deactivate()
		return
	
	var candidates: Array[Node3D] = []
	for body in get_overlapping_bodies():
		if is_instance_valid(body) and body != parent_player and body.is_in_group("player"):
			var b_hp = body.get("current_health") if "current_health" in body else (body.get("health") if "health" in body else 100.0)
			if not body.get("is_downed") and (b_hp == null or b_hp > 0.0):
				candidates.append(body)
	
	if candidates.is_empty():
		if current_reviver != null:
			_cancel_channel("OUT OF RANGE")
		if prompt_label:
			prompt_label.text = "[HOLD E] REVIVE"
		return
	
	var candidate = candidates[0]
	var is_pressing_e = Input.is_key_pressed(KEY_E) or Input.is_action_pressed("interact")
	if candidate and candidate.get("is_reviving"):
		is_pressing_e = true
	
	if is_pressing_e and candidate != null:
		if current_reviver != candidate:
			current_reviver = candidate
			revive_progress = 0.0
			revive_started.emit(candidate)
			if reviver_has_damage_signal(candidate):
				candidate.player_took_damage.connect(_on_reviver_took_damage)
		
		revive_progress += delta
		if prompt_label:
			prompt_label.text = "REVIVING... %.1fs" % max(0.0, REVIVE_DURATION - revive_progress)
			prompt_label.modulate = Color(0.2, 0.95, 0.55)
		
		if revive_progress >= REVIVE_DURATION:
			_complete_revive(parent_player)
	else:
		if current_reviver != null:
			_cancel_channel("INPUT RELEASED")
		if prompt_label:
			prompt_label.text = "[HOLD E] REVIVE"
			prompt_label.modulate = Color(0.95, 0.85, 0.2)

func reviver_has_damage_signal(reviver: Node3D) -> bool:
	return reviver.has_signal("player_took_damage") and not reviver.player_took_damage.is_connected(_on_reviver_took_damage)

func _on_reviver_took_damage(_amount: float) -> void:
	_cancel_channel("REVIVE CANCELLED: REVIVER TOOK DAMAGE!")

func _cancel_channel(reason: String = "") -> void:
	if current_reviver != null:
		if current_reviver.has_signal("player_took_damage") and current_reviver.player_took_damage.is_connected(_on_reviver_took_damage):
			current_reviver.player_took_damage.disconnect(_on_reviver_took_damage)
		current_reviver = null
	
	if revive_progress > 0.0:
		revive_progress = 0.0
		revive_interrupted.emit(reason)

func _complete_revive(parent_player: Node3D) -> void:
	if current_reviver != null:
		if current_reviver.has_signal("player_took_damage") and current_reviver.player_took_damage.is_connected(_on_reviver_took_damage):
			current_reviver.player_took_damage.disconnect(_on_reviver_took_damage)
		current_reviver = null
	
	revive_progress = 0.0
	revive_completed.emit(parent_player)
	
	if parent_player.has_method("revive"):
		parent_player.revive(REVIVE_HEALTH_RATIO)
	
	deactivate()
