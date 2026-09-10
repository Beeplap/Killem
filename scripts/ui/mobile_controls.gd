class_name MobileControls
extends CanvasLayer

## Dual-Platform Mobile Touch Controls
## Implements a twin-stick virtual touch layer (left move joystick, right aim/auto-fire stick)
## and tactical action buttons (Roll, Deploy, Cycle, Reload) with responsive safe-area anchors.

@onready var mobile_canvas: Control = $MobileCanvas
@onready var left_base: Control = $MobileCanvas/LeftZone/LeftBase
@onready var left_knob: Control = $MobileCanvas/LeftZone/LeftBase/Knob
@onready var right_base: Control = $MobileCanvas/RightZone/RightBase
@onready var right_knob: Control = $MobileCanvas/RightZone/RightBase/Knob

@onready var btn_ping: Button = get_node_or_null("MobileCanvas/ActionButtons/PingBtn")
@onready var btn_roll: Button = $MobileCanvas/ActionButtons/RollBtn
@onready var btn_deploy: Button = $MobileCanvas/ActionButtons/DeployBtn
@onready var btn_cycle: Button = $MobileCanvas/ActionButtons/CycleBtn
@onready var btn_reload: Button = $MobileCanvas/ActionButtons/ReloadBtn

const JOYSTICK_RADIUS: float = 64.0
const DEADZONE: float = 0.15
const AUTO_FIRE_THRESHOLD: float = 0.60

var _left_touch_id: int = -1
var _left_center: Vector2 = Vector2.ZERO
var _left_vector: Vector2 = Vector2.ZERO

var _right_touch_id: int = -1
var _right_center: Vector2 = Vector2.ZERO
var _right_vector: Vector2 = Vector2.ZERO
var _is_firing: bool = false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 15
	_update_visibility()
	_connect_action_buttons()

func _update_visibility() -> void:
	var override_mode = Global.mobile_controls_enabled if "mobile_controls_enabled" in Global else 0
	match override_mode:
		1: # Forced On
			visible = true
		2: # Forced Off
			visible = false
		_: # Auto Detect
			var is_touch = DisplayServer.is_touchscreen_available() or OS.has_feature("mobile")
			visible = is_touch

func _on_ping_pressed() -> void:
	var ping_sys = get_tree().get_first_node_in_group("ping_system")
	if ping_sys and ping_sys.has_method("trigger_ping"):
		ping_sys.trigger_ping()

func _connect_action_buttons() -> void:
	if btn_ping:
		btn_ping.pressed.connect(_on_ping_pressed)
	if btn_roll:
		btn_roll.pressed.connect(_on_roll_pressed)
	if btn_deploy:
		btn_deploy.pressed.connect(_on_deploy_pressed)
	if btn_cycle:
		btn_cycle.pressed.connect(_on_cycle_pressed)
	if btn_reload:
		btn_reload.pressed.connect(_on_reload_pressed)

func _input(event: InputEvent) -> void:
	if not visible:
		return
	
	if event is InputEventScreenTouch:
		_handle_touch(event)
	elif event is InputEventScreenDrag:
		_handle_drag(event)

func _handle_touch(event: InputEventScreenTouch) -> void:
	var viewport_size = get_viewport().get_visible_rect().size
	var pos = event.position
	
	if event.pressed:
		# Left half of screen (Move stick)
		if pos.x < viewport_size.x * 0.45 and _left_touch_id == -1:
			_left_touch_id = event.index
			_left_center = left_base.global_position + Vector2(JOYSTICK_RADIUS, JOYSTICK_RADIUS)
			_update_left_knob(pos)
		# Right half of screen (Aim stick)
		elif pos.x > viewport_size.x * 0.55 and pos.y > viewport_size.y * 0.35 and _right_touch_id == -1:
			_right_touch_id = event.index
			_right_center = right_base.global_position + Vector2(JOYSTICK_RADIUS, JOYSTICK_RADIUS)
			_update_right_knob(pos)
	else:
		if event.index == _left_touch_id:
			_release_left()
		elif event.index == _right_touch_id:
			_release_right()

func _handle_drag(event: InputEventScreenDrag) -> void:
	if event.index == _left_touch_id:
		_update_left_knob(event.position)
	elif event.index == _right_touch_id:
		_update_right_knob(event.position)

func _update_left_knob(touch_pos: Vector2) -> void:
	var diff = touch_pos - _left_center
	var dist = diff.length()
	var clamped_diff = diff
	if dist > JOYSTICK_RADIUS:
		clamped_diff = diff.normalized() * JOYSTICK_RADIUS
	
	if left_knob:
		left_knob.position = clamped_diff
	
	var norm_vec = clamped_diff / JOYSTICK_RADIUS
	if norm_vec.length() < DEADZONE:
		_left_vector = Vector2.ZERO
		_clear_move_actions()
	else:
		_left_vector = norm_vec
		_apply_move_actions(_left_vector)

func _apply_move_actions(vec: Vector2) -> void:
	# Emulate input actions with directional strength
	_set_action("move_left", max(0.0, -vec.x))
	_set_action("move_right", max(0.0, vec.x))
	_set_action("move_up", max(0.0, -vec.y))
	_set_action("move_down", max(0.0, vec.y))

func _set_action(action_name: String, strength: float) -> void:
	if strength > 0.1:
		Input.action_press(action_name, strength)
	else:
		Input.action_release(action_name)

func _clear_move_actions() -> void:
	Input.action_release("move_left")
	Input.action_release("move_right")
	Input.action_release("move_up")
	Input.action_release("move_down")

func _release_left() -> void:
	_left_touch_id = -1
	_left_vector = Vector2.ZERO
	if left_knob:
		left_knob.position = Vector2.ZERO
	_clear_move_actions()

func _update_right_knob(touch_pos: Vector2) -> void:
	var diff = touch_pos - _right_center
	var dist = diff.length()
	var clamped_diff = diff
	if dist > JOYSTICK_RADIUS:
		clamped_diff = diff.normalized() * JOYSTICK_RADIUS
	
	if right_knob:
		right_knob.position = clamped_diff
	
	var length_ratio = dist / JOYSTICK_RADIUS
	if length_ratio > 0.1:
		_right_vector = diff.normalized()
		Global.virtual_aim_active = true
		Global.virtual_aim_dir = _right_vector
		
		# Auto-fire when dragged past 0.6 radius
		if length_ratio >= AUTO_FIRE_THRESHOLD:
			if not _is_firing:
				_is_firing = true
				Input.action_press("shoot")
		else:
			if _is_firing:
				_is_firing = false
				Input.action_release("shoot")
	else:
		_right_vector = Vector2.ZERO
		if _is_firing:
			_is_firing = false
			Input.action_release("shoot")

func _release_right() -> void:
	_right_touch_id = -1
	_right_vector = Vector2.ZERO
	Global.virtual_aim_active = false
	if right_knob:
		right_knob.position = Vector2.ZERO
	if _is_firing:
		_is_firing = false
		Input.action_release("shoot")

func _on_roll_pressed() -> void:
	var player = get_tree().get_first_node_in_group("player")
	if player and player.has_method("start_dodge_roll"):
		player.start_dodge_roll()
	elif player and player.has_method("start_dash"):
		player.start_dash()

func _on_deploy_pressed() -> void:
	var player = get_tree().get_first_node_in_group("player")
	if player and player.has_method("deploy_current_item"):
		player.deploy_current_item()

func _on_cycle_pressed() -> void:
	Global.set_active_deployable(Global.active_deployable_type + 1)
	Global.play_sound("hit")

func _on_reload_pressed() -> void:
	var player = get_tree().get_first_node_in_group("player")
	var pos = player.global_position if player else null
	PlayerShooting.play_reload_sequence(get_tree(), pos)
