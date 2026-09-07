class_name SettingsMenu
extends CanvasLayer

## Comprehensive Modular Settings & Optimization Pipeline
## Supports device-aware dynamic FPS limits, Low-to-Ultra graphics scalability,
## audio bus mixing, touch controls toggle, and persistent user configuration.

signal closed

const SETTINGS_FILE: String = "user://settings.cfg"

# Display & FPS
@onready var display_mode_option: OptionButton = get_node_or_null("Root/Panel/VBox/Tabs/Display/DisplayGrid/DisplayModeOption")
@onready var vsync_check: CheckButton = get_node_or_null("Root/Panel/VBox/Tabs/Display/DisplayGrid/VsyncCheck")
@onready var fps_option: OptionButton = get_node_or_null("Root/Panel/VBox/Tabs/Display/DisplayGrid/FpsOption")

# Graphics
@onready var quality_preset_option: OptionButton = get_node_or_null("Root/Panel/VBox/Tabs/Graphics/GraphicsGrid/PresetOption")
@onready var msaa_option: OptionButton = get_node_or_null("Root/Panel/VBox/Tabs/Graphics/GraphicsGrid/MsaaOption")
@onready var res_scale_slider: HSlider = get_node_or_null("Root/Panel/VBox/Tabs/Graphics/GraphicsGrid/ResScaleSlider")
@onready var res_scale_label: Label = get_node_or_null("Root/Panel/VBox/Tabs/Graphics/GraphicsGrid/ResScaleVal")
@onready var shake_slider: HSlider = get_node_or_null("Root/Panel/VBox/Tabs/Graphics/GraphicsGrid/ShakeSlider")
@onready var shake_label: Label = get_node_or_null("Root/Panel/VBox/Tabs/Graphics/GraphicsGrid/ShakeVal")

# Audio
@onready var master_slider: HSlider = get_node_or_null("Root/Panel/VBox/Tabs/Audio/AudioGrid/MasterSlider")
@onready var music_slider: HSlider = get_node_or_null("Root/Panel/VBox/Tabs/Audio/AudioGrid/MusicSlider")
@onready var sfx_slider: HSlider = get_node_or_null("Root/Panel/VBox/Tabs/Audio/AudioGrid/SfxSlider")

# Controls
@onready var touch_ctrl_option: OptionButton = get_node_or_null("Root/Panel/VBox/Tabs/Controls/ControlsGrid/TouchOption")

# Navigation
@onready var tab_container: TabContainer = get_node_or_null("Root/Panel/VBox/Tabs")
@onready var save_btn: Button = get_node_or_null("Root/Panel/VBox/Footer/SaveButton")
@onready var close_btn: Button = get_node_or_null("Root/Panel/VBox/Footer/CloseButton")

var _available_fps_values: Array[int] = []

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 110
	visible = false
	
	_setup_fps_options()
	_setup_dropdowns()
	_connect_signals()
	load_and_apply_settings()

func open_settings() -> void:
	visible = true
	_load_ui_from_current_state()

func close_settings() -> void:
	visible = false
	closed.emit()

func _setup_fps_options() -> void:
	if not fps_option:
		return
	
	fps_option.clear()
	_available_fps_values.clear()
	
	# Device physical refresh rate detection
	var screen_hz: float = DisplayServer.screen_get_refresh_rate()
	if screen_hz <= 0:
		screen_hz = 60.0
	var native_hz: int = int(round(screen_hz))
	
	# Option 0: 30 FPS (Power Saver)
	fps_option.add_item("30 FPS (Battery Saver)")
	_available_fps_values.append(30)
	
	# Option 1: 60 FPS (Balanced)
	fps_option.add_item("60 FPS (Balanced)")
	_available_fps_values.append(60)
	
	# Option 2: Screen Native (if > 60)
	if native_hz > 60:
		fps_option.add_item("%d FPS (Device Native)" % native_hz)
		_available_fps_values.append(native_hz)
	
	# Option: 120 FPS (High Refresh if screen supports 120+ or wasn't added)
	if native_hz != 120 and native_hz > 60:
		fps_option.add_item("120 FPS (Ultra Smooth)")
		_available_fps_values.append(120)
	
	# Option: Unlimited (0)
	fps_option.add_item("Unlimited")
	_available_fps_values.append(0)

func _setup_dropdowns() -> void:
	if display_mode_option:
		display_mode_option.clear()
		display_mode_option.add_item("Windowed")
		display_mode_option.add_item("Borderless Fullscreen")
		display_mode_option.add_item("Exclusive Fullscreen")
	
	if quality_preset_option:
		quality_preset_option.clear()
		quality_preset_option.add_item("Low (Performance)")
		quality_preset_option.add_item("Medium (Balanced)")
		quality_preset_option.add_item("High (Detailed)")
		quality_preset_option.add_item("Ultra (Cinematic)")
	
	if msaa_option:
		msaa_option.clear()
		msaa_option.add_item("Disabled")
		msaa_option.add_item("2X MSAA")
		msaa_option.add_item("4X MSAA")
		msaa_option.add_item("8X MSAA")
	
	if touch_ctrl_option:
		touch_ctrl_option.clear()
		touch_ctrl_option.add_item("Auto (Detect Touchscreen)")
		touch_ctrl_option.add_item("Always Enabled")
		touch_ctrl_option.add_item("Disabled")

func _connect_signals() -> void:
	if save_btn:
		save_btn.pressed.connect(_on_save_pressed)
	if close_btn:
		close_btn.pressed.connect(_on_close_pressed)
	
	if quality_preset_option:
		quality_preset_option.item_selected.connect(_on_preset_selected)
	
	if res_scale_slider:
		res_scale_slider.value_changed.connect(func(val):
			if res_scale_label:
				res_scale_label.text = "%d%%" % int(val * 100.0)
		)
	
	if shake_slider:
		shake_slider.value_changed.connect(func(val):
			if shake_label:
				shake_label.text = "%d%%" % int(val * 100.0)
			Global.screenshake_multiplier = val
		)
	
	# Real-time audio updates
	if master_slider:
		master_slider.value_changed.connect(func(val): _set_bus_volume("Master", val))
	if music_slider:
		music_slider.value_changed.connect(func(val): _set_bus_volume("Music", val))
	if sfx_slider:
		sfx_slider.value_changed.connect(func(val):
			_set_bus_volume("SFX", val)
			_set_bus_volume("Weapons", val)
			_set_bus_volume("Foley", val)
		)

func _on_preset_selected(idx: int) -> void:
	match idx:
		0: # Low
			if res_scale_slider: res_scale_slider.value = 0.70
			if msaa_option: msaa_option.selected = 0 # Disabled
		1: # Medium
			if res_scale_slider: res_scale_slider.value = 0.85
			if msaa_option: msaa_option.selected = 1 # 2X
		2: # High
			if res_scale_slider: res_scale_slider.value = 1.00
			if msaa_option: msaa_option.selected = 2 # 4X
		3: # Ultra
			if res_scale_slider: res_scale_slider.value = 1.00
			if msaa_option: msaa_option.selected = 3 # 8X

func _load_ui_from_current_state() -> void:
	# FPS
	var current_max = Engine.max_fps
	var fps_idx = _available_fps_values.find(current_max)
	if fps_idx >= 0 and fps_option:
		fps_option.selected = fps_idx
	
	# Display
	var mode = DisplayServer.window_get_mode()
	if display_mode_option:
		match mode:
			DisplayServer.WINDOW_MODE_WINDOWED: display_mode_option.selected = 0
			DisplayServer.WINDOW_MODE_FULLSCREEN: display_mode_option.selected = 1
			DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN: display_mode_option.selected = 2
	
	if vsync_check:
		vsync_check.button_pressed = (DisplayServer.window_get_vsync_mode() != DisplayServer.VSYNC_DISABLED)
	
	# Audio
	if master_slider: master_slider.value = _get_bus_linear_volume("Master")
	if music_slider: music_slider.value = _get_bus_linear_volume("Music")
	if sfx_slider: sfx_slider.value = _get_bus_linear_volume("SFX")
	
	# Graphics
	if shake_slider:
		shake_slider.value = Global.screenshake_multiplier
	if touch_ctrl_option:
		touch_ctrl_option.selected = Global.mobile_controls_enabled

func _set_bus_volume(bus_name: String, linear_val: float) -> void:
	var idx = AudioServer.get_bus_index(bus_name)
	if idx < 0:
		return
	if linear_val <= 0.001:
		AudioServer.set_bus_mute(idx, true)
	else:
		AudioServer.set_bus_mute(idx, false)
		var db = linear_to_db(linear_val)
		AudioServer.set_bus_volume_db(idx, db)

func _get_bus_linear_volume(bus_name: String) -> float:
	var idx = AudioServer.get_bus_index(bus_name)
	if idx < 0:
		return 1.0
	if AudioServer.is_bus_mute(idx):
		return 0.0
	return db_to_linear(AudioServer.get_bus_volume_db(idx))

func _on_save_pressed() -> void:
	save_settings()
	Global.play_sound("perk")
	close_settings()

func _on_close_pressed() -> void:
	Global.play_sound("hit")
	close_settings()

func save_settings() -> void:
	var config = ConfigFile.new()
	
	# 1. FPS Limit
	if fps_option and fps_option.selected >= 0 and fps_option.selected < _available_fps_values.size():
		var target_fps = _available_fps_values[fps_option.selected]
		Engine.max_fps = target_fps
		config.set_value("video", "max_fps", target_fps)
	
	# 2. Display Mode & V-Sync
	if display_mode_option:
		var mode_idx = display_mode_option.selected
		config.set_value("video", "display_mode", mode_idx)
		match mode_idx:
			0: DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
			1: DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
			2: DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)
	
	if vsync_check:
		var vsync = vsync_check.button_pressed
		config.set_value("video", "vsync", vsync)
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if vsync else DisplayServer.VSYNC_DISABLED)
	
	# 3. Graphics Quality & Resolution Scale
	if quality_preset_option:
		config.set_value("graphics", "preset", quality_preset_option.selected)
	if res_scale_slider:
		var scale_val = res_scale_slider.value
		config.set_value("graphics", "res_scale", scale_val)
		get_viewport().scaling_3d_scale = scale_val
	
	if msaa_option:
		var msaa_idx = msaa_option.selected
		config.set_value("graphics", "msaa", msaa_idx)
		match msaa_idx:
			0: get_viewport().msaa_3d = Viewport.MSAA_DISABLED
			1: get_viewport().msaa_3d = Viewport.MSAA_2X
			2: get_viewport().msaa_3d = Viewport.MSAA_4X
			3: get_viewport().msaa_3d = Viewport.MSAA_8X
	
	if shake_slider:
		config.set_value("graphics", "screenshake", shake_slider.value)
		Global.screenshake_multiplier = shake_slider.value
	
	# 4. Audio
	if master_slider:
		config.set_value("audio", "master", master_slider.value)
	if music_slider:
		config.set_value("audio", "music", music_slider.value)
	if sfx_slider:
		config.set_value("audio", "sfx", sfx_slider.value)
	
	# 5. Mobile Controls Override
	if touch_ctrl_option:
		var touch_mode = touch_ctrl_option.selected
		Global.mobile_controls_enabled = touch_mode
		config.set_value("controls", "touch_controls", touch_mode)
		
		var mobile_hud = get_tree().get_first_node_in_group("mobile_controls")
		if not mobile_hud:
			var nodes = get_tree().get_nodes_in_group("crosshair")
			for n in nodes:
				var p = n.get_parent()
				if p and p.has_node("MobileControls"):
					mobile_hud = p.get_node("MobileControls")
					break
		if mobile_hud and mobile_hud.has_method("_update_visibility"):
			mobile_hud._update_visibility()
	
	config.save(SETTINGS_FILE)

func load_and_apply_settings() -> void:
	var config = ConfigFile.new()
	var err = config.load(SETTINGS_FILE)
	if err != OK:
		# Use hardware defaults
		_apply_hardware_defaults()
		return
	
	# Apply Video
	var max_fps = config.get_value("video", "max_fps", 60)
	Engine.max_fps = max_fps
	
	var vsync = config.get_value("video", "vsync", true)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if vsync else DisplayServer.VSYNC_DISABLED)
	
	var mode_idx = config.get_value("video", "display_mode", 0)
	match mode_idx:
		0: DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		1: DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		2: DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)
	
	# Apply Graphics
	var res_scale = config.get_value("graphics", "res_scale", 1.0)
	get_viewport().scaling_3d_scale = res_scale
	
	var msaa_idx = config.get_value("graphics", "msaa", 1)
	match msaa_idx:
		0: get_viewport().msaa_3d = Viewport.MSAA_DISABLED
		1: get_viewport().msaa_3d = Viewport.MSAA_2X
		2: get_viewport().msaa_3d = Viewport.MSAA_4X
		3: get_viewport().msaa_3d = Viewport.MSAA_8X
	
	Global.screenshake_multiplier = config.get_value("graphics", "screenshake", 1.0)
	
	# Apply Audio
	_set_bus_volume("Master", config.get_value("audio", "master", 0.85))
	_set_bus_volume("Music", config.get_value("audio", "music", 0.70))
	var sfx_v = config.get_value("audio", "sfx", 0.85)
	_set_bus_volume("SFX", sfx_v)
	_set_bus_volume("Weapons", sfx_v)
	_set_bus_volume("Foley", sfx_v)
	
	# Apply Controls
	Global.mobile_controls_enabled = config.get_value("controls", "touch_controls", 0)

func _apply_hardware_defaults() -> void:
	var screen_hz = DisplayServer.screen_get_refresh_rate()
	if screen_hz <= 0: screen_hz = 60.0
	Engine.max_fps = int(round(screen_hz))
	Global.screenshake_multiplier = 1.0
	Global.mobile_controls_enabled = 0
