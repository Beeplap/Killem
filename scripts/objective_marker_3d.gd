extends Node3D
class_name ObjectiveMarker3D

@export var marker_text: String = "OBJECTIVE"
@export var marker_color: Color = Color.YELLOW
@export var show_distance: bool = true

var _label: Label3D
var _base_y: float = 2.8

func _ready() -> void:
	_label = Label3D.new()
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.modulate = marker_color
	_label.pixel_size = 0.008
	_label.font_size = 36
	_label.outline_size = 6
	_label.outline_modulate = Color(0, 0, 0, 0.9)
	_label.no_depth_test = true
	_label.position.y = _base_y
	add_child(_label)

func _process(_delta: float) -> void:
	var players = get_tree().get_nodes_in_group("player3d")
	var nearest_player: Node3D = null
	var min_dist = INF
	
	for p in players:
		var d = global_position.distance_to(p.global_position)
		if d < min_dist:
			min_dist = d
			nearest_player = p
			
	if nearest_player == null:
		_label.visible = false
		return
		
	if min_dist < 3.0:
		_label.visible = false
		return
		
	_label.visible = true
	
	if show_distance:
		_label.text = "%s: %dm" % [marker_text, int(min_dist)]
	else:
		_label.text = marker_text
		
	var time_msec = Time.get_ticks_msec()
	var alpha = 0.8 + 0.2 * sin(time_msec * 0.003)
	
	var color = marker_color
	color.a = alpha
	_label.modulate = color
	
	var time_sec = time_msec * 0.001
	_label.position.y = _base_y + 0.15 * sin(time_sec * 2.0)
