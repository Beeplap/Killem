extends CanvasLayer

@onready var health_bar: ProgressBar = $VitalsContainer/VBox/HealthBar
@onready var health_label: Label = $VitalsContainer/VBox/HealthLabel
@onready var weapon_label: Label = $WeaponContainer/VBox/WeaponLabel
@onready var ammo_label: Label = $WeaponContainer/VBox/AmmoLabel
@onready var score_label: Label = $ScoreContainer/VBox/ScoreLabel
@onready var kills_label: Label = $ScoreContainer/VBox/KillsLabel
@onready var wave_label: Label = $WaveContainer/WaveLabel
@onready var game_over_panel: Control = $GameOverPanel

func _ready() -> void:
	Global.health_changed.connect(_on_health_changed)
	Global.ammo_changed.connect(_on_ammo_changed)
	Global.score_changed.connect(_on_score_changed)
	Global.wave_changed.connect(_on_wave_changed)
	Global.player_died.connect(_on_player_died)
	
	game_over_panel.visible = false
	_on_health_changed(Global.player_health, Global.player_max_health)
	Global.emit_current_ammo()
	_on_score_changed(Global.score, Global.kills)
	_on_wave_changed(Global.current_wave)

func _unhandled_input(event: InputEvent) -> void:
	if Global.is_game_over:
		if event is InputEventKey and event.pressed and event.keycode == KEY_R:
			restart_game()
		elif event is InputEventScreenTouch and event.pressed:
			restart_game()

func _on_health_changed(current: float, max_val: float) -> void:
	if health_bar:
		health_bar.max_value = max_val
		health_bar.value = current
	if health_label:
		health_label.text = "VITALS: %d / %d" % [int(current), int(max_val)]

func _on_ammo_changed(weapon_name: String, current: int, max_val: int) -> void:
	if weapon_label:
		weapon_label.text = weapon_name
	if ammo_label:
		if current >= 999:
			ammo_label.text = "AMMO: ∞"
		else:
			ammo_label.text = "AMMO: %d / %d" % [current, max_val]

func _on_score_changed(score: int, kills: int) -> void:
	if score_label:
		score_label.text = "SCORE: %06d" % score
	if kills_label:
		kills_label.text = "KILLS: %d" % kills

func _on_wave_changed(wave: int) -> void:
	if wave_label:
		wave_label.text = "WAVE %02d" % wave

func _on_player_died() -> void:
	if game_over_panel:
		game_over_panel.visible = true

func restart_game() -> void:
	Global.reset_state()
	get_tree().reload_current_scene()

func _on_weapon_btn_1_pressed() -> void:
	Global.set_weapon(Global.WeaponType.PISTOL)

func _on_weapon_btn_2_pressed() -> void:
	Global.set_weapon(Global.WeaponType.SHOTGUN)

func _on_weapon_btn_3_pressed() -> void:
	Global.set_weapon(Global.WeaponType.ASSAULT_RIFLE)
