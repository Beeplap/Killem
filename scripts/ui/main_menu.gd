class_name MainMenu
extends Control

## KillEm Main Landing Page
## Atmospheric post-apocalyptic title screen with tactile navigation,
## audio cues, settings drawer integration, and mobile platform adaptation.

@export var default_game_scene: String = "res://scenes/MainLevel.tscn"
@export var campaign_3d_scene: String = "res://scenes/levels/BaseLevel3D.tscn"

@onready var play_btn: Button = $Content/VBox/Buttons/PlayButton
@onready var lan_btn: Button = get_node_or_null("Content/VBox/Buttons/CoopLanButton")
@onready var play_3d_btn: Button = get_node_or_null("Content/VBox/Buttons/Play3DButton")
@onready var settings_btn: Button = $Content/VBox/Buttons/SettingsButton
@onready var quit_btn: Button = $Content/VBox/Buttons/QuitButton
@onready var settings_modal: CanvasLayer = $SettingsMenu
@onready var lan_modal: CanvasLayer = get_node_or_null("LanMenu")

@onready var hazard_light_1: PointLight2D = get_node_or_null("Background/HazardLight1")
@onready var hazard_light_2: PointLight2D = get_node_or_null("Background/HazardLight2")
@onready var background_fog: CPUParticles2D = get_node_or_null("Background/FogParticles")

func _ready() -> void:
	# Gracefully hide QUIT button on Mobile OS / Web
	if OS.has_feature("mobile") or OS.has_feature("web"):
		if quit_btn:
			quit_btn.visible = false
	
	_connect_buttons()
	_play_title_ambient()

func _connect_buttons() -> void:
	if play_btn:
		play_btn.pressed.connect(_on_play_pressed)
		play_btn.mouse_entered.connect(_on_button_hover)
	
	if lan_btn:
		lan_btn.pressed.connect(_on_lan_pressed)
		lan_btn.mouse_entered.connect(_on_button_hover)
	
	if play_3d_btn:
		play_3d_btn.pressed.connect(_on_play_3d_pressed)
		play_3d_btn.mouse_entered.connect(_on_button_hover)
	
	if settings_btn:
		settings_btn.pressed.connect(_on_settings_pressed)
		settings_btn.mouse_entered.connect(_on_button_hover)
	
	if quit_btn:
		quit_btn.pressed.connect(_on_quit_pressed)
		quit_btn.mouse_entered.connect(_on_button_hover)

func _process(_delta: float) -> void:
	# Hazard lights blinking cadence
	var time = Time.get_ticks_msec() * 0.001
	if hazard_light_1:
		var blink = 1.0 if fmod(time, 1.4) < 0.15 or (fmod(time, 1.4) > 0.25 and fmod(time, 1.4) < 0.40) else 0.15
		hazard_light_1.energy = blink * 1.8
	
	if hazard_light_2:
		var blink2 = 1.0 if fmod(time + 0.7, 1.8) < 0.20 else 0.12
		hazard_light_2.energy = blink2 * 1.6

func _play_title_ambient() -> void:
	var audio_mgr = Engine.get_main_loop().root.get_node_or_null("AudioManager") if Engine.get_main_loop() else null
	if audio_mgr and audio_mgr.has_method("play_sound"):
		audio_mgr.play_sound("wave_start")

func _on_button_hover() -> void:
	var audio_mgr = Engine.get_main_loop().root.get_node_or_null("AudioManager") if Engine.get_main_loop() else null
	if audio_mgr and audio_mgr.has_method("play_ui"):
		audio_mgr.play_ui("hit")

func _on_play_pressed() -> void:
	_launch_level(default_game_scene)

func _on_play_3d_pressed() -> void:
	_launch_level(campaign_3d_scene)

func _launch_level(scene_path: String) -> void:
	Global.play_sound("perk")
	Global.reset_state()
	
	# Transition fade
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.4)
	tween.tween_callback(func():
		get_tree().change_scene_to_file(scene_path)
	)

func _on_lan_pressed() -> void:
	Global.play_sound("perk")
	if lan_modal and lan_modal.has_method("open_menu"):
		lan_modal.open_menu()
	elif lan_modal:
		lan_modal.visible = true

func _on_settings_pressed() -> void:
	Global.play_sound("perk")
	if settings_modal and settings_modal.has_method("open_settings"):
		settings_modal.open_settings()
	elif settings_modal:
		settings_modal.visible = true

func _on_quit_pressed() -> void:
	Global.play_sound("gate_slam")
	get_tree().quit()
