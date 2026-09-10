extends Node3D
class_name PingMarker3D

## Tactical Ping Marker 3D
## Displays a synchronized tactical billboard marker in the 3D world for 6.0 seconds.

enum PingType { MOVE, ENEMY, SUPPLIES }

@export var ping_type: PingType = PingType.MOVE
@export var lifetime: float = 6.0

var time_alive: float = 0.0
var tracked_target: Node3D = null

@onready var label: Label3D = get_node_or_null("Label3D")

func _ready() -> void:
	top_level = true

func setup_ping(type: int, world_pos: Vector3, target: Node3D = null) -> void:
	ping_type = type as PingType
	global_position = world_pos
	tracked_target = target
	time_alive = 0.0
	
	if label:
		match ping_type:
			PingType.MOVE:
				label.text = "▼ MOVE HERE"
				label.modulate = Color(0.98, 0.85, 0.15)
			PingType.ENEMY:
				label.text = "⊕ FOCUS TARGET"
				label.modulate = Color(1.0, 0.22, 0.2)
			PingType.SUPPLIES:
				label.text = "◆ SUPPLIES"
				label.modulate = Color(0.25, 0.8, 1.0)
	
	var audio_mgr = get_node_or_null("/root/AudioManager")
	if audio_mgr and audio_mgr.has_method("play_sound_3d"):
		audio_mgr.play_sound_3d("radio_chatter", world_pos, AudioManager.BUS_FOLEY)

func _process(delta: float) -> void:
	time_alive += delta
	
	if tracked_target and is_instance_valid(tracked_target):
		global_position = tracked_target.global_position + Vector3(0, 1.8, 0)
	
	if time_alive >= lifetime:
		queue_free()
