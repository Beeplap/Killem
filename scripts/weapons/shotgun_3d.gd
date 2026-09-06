class_name Shotgun3D
extends Node3D

## 12-Gauge Tactical Pump-Action Shotgun Controller
## Features procedural cycling pump-action forend, muzzle flash, pellet spark dispersion, and side-ejection acoustics.

@onready var pump: Node3D = get_node_or_null("Pump")
@onready var muzzle: Node3D = get_node_or_null("Muzzle")
@onready var muzzle_flash: OmniLight3D = get_node_or_null("Muzzle/MuzzleFlash")
@onready var muzzle_particles: GPUParticles3D = get_node_or_null("Muzzle/MuzzleParticles")
@onready var ejection_port: Node3D = get_node_or_null("EjectionPort")

var _pump_rest_pos: Vector3 = Vector3.ZERO
var _pump_tween: Tween
var _flash_timer: float = 0.0

func _ready() -> void:
	if pump:
		_pump_rest_pos = pump.position
	if muzzle_flash:
		muzzle_flash.visible = false

func _process(delta: float) -> void:
	if _flash_timer > 0.0:
		_flash_timer -= delta
		if _flash_timer <= 0.0 and muzzle_flash:
			muzzle_flash.visible = false

## Triggers heavy 12-gauge blast and mechanical pump-action rack sequence
func fire() -> void:
	# 1. Muzzle Flash & Heavy Spark Burst
	if muzzle_flash:
		muzzle_flash.visible = true
		_flash_timer = 0.06
	if muzzle_particles:
		muzzle_particles.restart()
		muzzle_particles.emitting = true
	
	# 2. Sequential Mechanical Pump Cycle (0.35s total duration)
	pump_cycle()

func pump_cycle() -> void:
	if not pump:
		return
	
	if _pump_tween and _pump_tween.is_valid():
		_pump_tween.kill()
	
	_pump_tween = create_tween()
	var racked_pos = _pump_rest_pos + Vector3(0, 0, -0.15)
	
	# Stagger pump rack slightly after immediate heavy blast
	_pump_tween.tween_interval(0.12)
	
	# Rack back 0.15m
	_pump_tween.tween_property(pump, "position", racked_pos, 0.14).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_pump_tween.tween_callback(func():
		var eject_pos = ejection_port.global_position if ejection_port else global_position
		# Trigger spent red shell casing bounce
		PlayerShooting.play_casing_bounce(get_tree(), eject_pos, 0.12)
		
		# Play mechanical pump rack audio
		var audio_mgr = Engine.get_main_loop().root.get_node_or_null("AudioManager") if Engine.get_main_loop() else null
		if audio_mgr and audio_mgr.has_method("play_sound"):
			audio_mgr.play_sound("shotgun_pump", eject_pos, "Weapons")
		else:
			Global.play_sound("perk", eject_pos)
	)
	
	# Push forward into chambered battery
	_pump_tween.tween_property(pump, "position", _pump_rest_pos, 0.14).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)

func get_muzzle_position() -> Vector3:
	if muzzle:
		return muzzle.global_position
	var legacy_marker = get_node_or_null("MuzzleMarker")
	if legacy_marker:
		return legacy_marker.global_position
	return global_position
