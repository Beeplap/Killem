class_name Pistol3D
extends Node3D

## Tactical 9mm Pistol Controller
## Handles procedural slide recoil blowback, muzzle flash lighting, particle discharge, and casing ejection.

@onready var slide: Node3D = get_node_or_null("Slide")
@onready var muzzle: Node3D = get_node_or_null("Muzzle")
@onready var muzzle_flash: OmniLight3D = get_node_or_null("Muzzle/MuzzleFlash")
@onready var muzzle_particles: GPUParticles3D = get_node_or_null("Muzzle/MuzzleParticles")
@onready var ejection_port: Node3D = get_node_or_null("EjectionPort")

var _slide_rest_pos: Vector3 = Vector3.ZERO
var _blowback_tween: Tween
var _flash_timer: float = 0.0

func _ready() -> void:
	if slide:
		_slide_rest_pos = slide.position
	if muzzle_flash:
		muzzle_flash.visible = false

func _process(delta: float) -> void:
	if _flash_timer > 0.0:
		_flash_timer -= delta
		if _flash_timer <= 0.0 and muzzle_flash:
			muzzle_flash.visible = false

## Triggers mechanical firing animation, slide blowback, muzzle flash, and brass ejection
func fire() -> void:
	# 1. Slide Recoil Blowback (-Z snap backward for 0.05s, return forward in 0.08s)
	if slide:
		if _blowback_tween and _blowback_tween.is_valid():
			_blowback_tween.kill()
		_blowback_tween = create_tween()
		var kick_pos = _slide_rest_pos + Vector3(0, 0, -0.04)
		_blowback_tween.tween_property(slide, "position", kick_pos, 0.05).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		_blowback_tween.tween_property(slide, "position", _slide_rest_pos, 0.08).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	
	# 2. Muzzle Flash & Sparks
	if muzzle_flash:
		muzzle_flash.visible = true
		_flash_timer = 0.05
	if muzzle_particles:
		muzzle_particles.restart()
		muzzle_particles.emitting = true
	
	# 3. Tactical Shell Casing Bounce
	var eject_pos = ejection_port.global_position if ejection_port else global_position
	PlayerShooting.play_casing_bounce(get_tree(), eject_pos, 0.22)

func get_muzzle_position() -> Vector3:
	if muzzle:
		return muzzle.global_position
	var legacy_marker = get_node_or_null("MuzzleMarker")
	if legacy_marker:
		return legacy_marker.global_position
	return global_position
