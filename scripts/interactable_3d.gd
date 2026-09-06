extends Area3D
class_name Interactable3D

signal interacted(player: Node3D)
signal interaction_progress(progress: float)

@export var interaction_text: String = "Hold to Override"
@export var interaction_key: String = "E"
@export var hold_duration: float = 0.0
@export var requires_keycard: bool = false
@export var required_keycard_color: String = ""

var _prompt_label: Label3D
var _players_in_range: Array[Node3D] = []
var _hold_timer: float = 0.0
var _is_holding: bool = false
var _key_pressed_last_frame: bool = false

func _ready() -> void:
	collision_layer = 16
	collision_mask = 1
	
	_prompt_label = Label3D.new()
	_prompt_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_prompt_label.visible = false
	_prompt_label.position = Vector3(0, 1.5, 0)
	_prompt_label.pixel_size = 0.005
	_prompt_label.no_depth_test = true
	add_child(_prompt_label)
	
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _process(delta: float) -> void:
	if _players_in_range.is_empty():
		return
		
	var player = _players_in_range[0]
	
	var has_keycard = true
	if requires_keycard:
		has_keycard = false
		var global_node = get_node_or_null("/root/Global")
		if global_node and "keycards_collected" in global_node:
			if required_keycard_color in global_node.keycards_collected:
				has_keycard = true
	
	if not has_keycard:
		_prompt_label.text = "[LOCKED] Requires " + required_keycard_color.capitalize() + " Keycard"
		_prompt_label.modulate = Color.RED
		_is_holding = false
		_hold_timer = 0.0
		return
		
	_prompt_label.modulate = Color.WHITE
	
	var interact_pressed = false
	if InputMap.has_action("interact"):
		interact_pressed = Input.is_action_pressed("interact")
	else:
		interact_pressed = Input.is_key_pressed(KEY_E)
		
	var interact_just_pressed = interact_pressed and not _key_pressed_last_frame
	_key_pressed_last_frame = interact_pressed
	
	if hold_duration <= 0.0:
		_prompt_label.text = "[%s] %s" % [interaction_key, interaction_text]
		if interact_just_pressed:
			interacted.emit(player)
	else:
		if interact_pressed:
			_hold_timer += delta
			var progress = clampf(_hold_timer / hold_duration, 0.0, 1.0)
			interaction_progress.emit(progress)
			
			var blocks = int(progress * 10)
			var bar = "█".repeat(blocks) + "░".repeat(10 - blocks)
			var percent = int(progress * 100)
			_prompt_label.text = "[%s] %s %d%%" % [interaction_key, bar, percent]
			
			if progress >= 1.0 and not _is_holding:
				_is_holding = true
				interacted.emit(player)
		else:
			_hold_timer = 0.0
			_is_holding = false
			_prompt_label.text = "[%s] %s" % [interaction_key, interaction_text]
			interaction_progress.emit(0.0)

func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("player3d"):
		if body not in _players_in_range:
			_players_in_range.append(body)
			_prompt_label.visible = true
			_hold_timer = 0.0
			_is_holding = false

func _on_body_exited(body: Node3D) -> void:
	if body in _players_in_range:
		_players_in_range.erase(body)
		if _players_in_range.is_empty():
			_prompt_label.visible = false
			_hold_timer = 0.0
			_is_holding = false
			interaction_progress.emit(0.0)
