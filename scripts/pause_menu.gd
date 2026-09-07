extends CanvasLayer
class_name TacticalPauseMenu

# Tactical Pause & Settings Drawer
# Handles game pause, audio mix controls, graphics toggles, and screen shake intensity.
# Process mode set to PROCESS_MODE_ALWAYS to operate while tree is paused.

@onready var menu_root: Control = $MenuRoot
@onready var master_slider: HSlider = $MenuRoot/Panel/VBox/AudioGrid/MasterSlider
@onready var music_slider: HSlider = $MenuRoot/Panel/VBox/AudioGrid/MusicSlider
@onready var weapons_slider: HSlider = $MenuRoot/Panel/VBox/AudioGrid/WeaponsSlider
@onready var zombies_slider: HSlider = $MenuRoot/Panel/VBox/AudioGrid/ZombiesSlider

@onready var vsync_check: CheckButton = $MenuRoot/Panel/VBox/GraphicsGrid/VsyncCheck
@onready var fullscreen_check: CheckButton = $MenuRoot/Panel/VBox/GraphicsGrid/FullscreenCheck
@onready var shake_slider: HSlider = $MenuRoot/Panel/VBox/GraphicsGrid/ShakeBox/ShakeSlider
@onready var shake_label: Label = $MenuRoot/Panel/VBox/GraphicsGrid/ShakeBox/ShakeVal

@onready var resume_btn: Button = $MenuRoot/Panel/VBox/Buttons/ResumeButton
@onready var restart_btn: Button = $MenuRoot/Panel/VBox/Buttons/RestartButton
@onready var quit_btn: Button = $MenuRoot/Panel/VBox/Buttons/QuitButton

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 100
	visible = false
	if menu_root:
		menu_root.visible = false
	
	_connect_controls()
	_load_current_settings()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") or (event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE):
		toggle_pause()

func toggle_pause() -> void:
	var new_state = not get_tree().paused
	set_pause_state(new_state)

func set_pause_state(should_pause: bool) -> void:
	get_tree().paused = should_pause
	visible = should_pause
	if menu_root:
		menu_root.visible = should_pause
	
	if should_pause:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		_load_current_settings()
	else:
		Input.mouse_mode = Input.MOUSE_MODE_HIDDEN

func _connect_controls() -> void:
	if master_slider:
		master_slider.value_changed.connect(func(val): _set_bus_volume("Master", val))
	if music_slider:
		music_slider.value_changed.connect(func(val): _set_bus_volume("Music", val))
	if weapons_slider:
		weapons_slider.value_changed.connect(func(val): _set_bus_volume("Weapons", val))
	if zombies_slider:
		zombies_slider.value_changed.connect(func(val): _set_bus_volume("Zombies", val))
	
	if vsync_check:
		vsync_check.toggled.connect(_on_vsync_toggled)
	if fullscreen_check:
		fullscreen_check.toggled.connect(_on_fullscreen_toggled)
	if shake_slider:
		shake_slider.value_changed.connect(_on_shake_changed)
	
	if resume_btn:
		resume_btn.pressed.connect(func(): set_pause_state(false))
	if restart_btn:
		restart_btn.pressed.connect(_on_restart_pressed)
	if quit_btn:
		quit_btn.pressed.connect(_on_quit_pressed)

func _load_current_settings() -> void:
	if master_slider:
		master_slider.value = _get_bus_volume("Master")
	if music_slider:
		music_slider.value = _get_bus_volume("Music")
	if weapons_slider:
		weapons_slider.value = _get_bus_volume("Weapons")
	if zombies_slider:
		zombies_slider.value = _get_bus_volume("Zombies")
	
	if vsync_check:
		var vsync = DisplayServer.window_get_vsync_mode()
		vsync_check.button_pressed = (vsync != DisplayServer.VSYNC_DISABLED)
	
	if fullscreen_check:
		var mode = DisplayServer.window_get_mode()
		fullscreen_check.button_pressed = (mode == DisplayServer.WINDOW_MODE_FULLSCREEN or mode == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)
	
	if shake_slider:
		var s_val = Global.screenshake_multiplier if Global else 1.0
		shake_slider.value = s_val * 100.0
		if shake_label:
			shake_label.text = "%d%%" % int(shake_slider.value)

func _get_bus_volume(bus_name: String) -> float:
	var idx = AudioServer.get_bus_index(bus_name)
	if idx >= 0:
		if AudioServer.is_bus_mute(idx):
			return 0.0
		return db_to_linear(AudioServer.get_bus_volume_db(idx)) * 100.0
	return 100.0

func _set_bus_volume(bus_name: String, value_pct: float) -> void:
	var idx = AudioServer.get_bus_index(bus_name)
	if idx >= 0:
		if value_pct <= 0.5:
			AudioServer.set_bus_mute(idx, true)
		else:
			AudioServer.set_bus_mute(idx, false)
			var db = linear_to_db(value_pct / 100.0)
			AudioServer.set_bus_volume_db(idx, db)

func _on_vsync_toggled(enabled: bool) -> void:
	var mode = DisplayServer.VSYNC_ENABLED if enabled else DisplayServer.VSYNC_DISABLED
	DisplayServer.window_set_vsync_mode(mode)

func _on_fullscreen_toggled(enabled: bool) -> void:
	var mode = DisplayServer.WINDOW_MODE_FULLSCREEN if enabled else DisplayServer.WINDOW_MODE_WINDOWED
	DisplayServer.window_set_mode(mode)

func _on_shake_changed(value: float) -> void:
	if Global:
		Global.screenshake_multiplier = value / 100.0
	if shake_label:
		shake_label.text = "%d%%" % int(value)

func _on_restart_pressed() -> void:
	get_tree().paused = false
	if Global:
		Global.reset_state()
	get_tree().reload_current_scene()

func _on_quit_pressed() -> void:
	get_tree().paused = false
	if Global:
		Global.reset_state()
	get_tree().change_scene_to_file("res://scenes/ui/MainMenu.tscn")
