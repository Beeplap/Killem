extends Node3D
class_name BlastDoor3D

@export var required_keycard: String = "yellow"
@export var door_width: float = 4.0
@export var door_height: float = 3.5

signal door_opened

@onready var static_body: StaticBody3D = get_node_or_null("StaticBody3D")
@onready var collision_shape: CollisionShape3D = get_node_or_null("StaticBody3D/CollisionShape3D")
@onready var mesh: MeshInstance3D = get_node_or_null("MeshInstance3D")
@onready var interactable = get_node_or_null("Interactable3D")

var is_open: bool = false
var _marker: Node3D = null

func _ready() -> void:
	# Add Objective Marker
	var marker_script = load("res://scripts/objective_marker_3d.gd")
	if marker_script:
		_marker = Node3D.new()
		_marker.set_script(marker_script)
		_marker.set("marker_text", "BLAST DOOR")
		_marker.set("marker_color", Color(1.0, 0.45, 0.1))
		add_child(_marker)
		_marker.position.y = 1.0
	
	if interactable:
		interactable.set("interaction_text", "Insert " + required_keycard.capitalize() + " Keycard")
		interactable.set("requires_keycard", true)
		interactable.set("required_keycard_color", required_keycard)
		if interactable.has_signal("interacted"):
			interactable.connect("interacted", Callable(self, "_on_interacted"))

func _on_interacted(_interactor: Node) -> void:
	if is_open:
		return
	
	if Global.has_keycard(required_keycard):
		open_door()

func open_door() -> void:
	if is_open:
		return
	is_open = true
	Global.play_sound("gate_slam")
	
	if collision_shape:
		collision_shape.set_deferred("disabled", true)
	
	if interactable:
		interactable.queue_free()
	
	if _marker:
		_marker.queue_free()
	
	door_opened.emit()
	
	if mesh:
		var tween = create_tween()
		tween.set_ease(Tween.EASE_IN_OUT)
		tween.set_trans(Tween.TRANS_QUAD)
		tween.tween_property(mesh, "position:y", mesh.position.y + door_height, 1.5)
