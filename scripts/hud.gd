extends CanvasLayer

@onready var health_bar: ProgressBar = $VitalsContainer/VBox/HealthBar
@onready var health_label: Label = $VitalsContainer/VBox/HealthLabel
@onready var roll_bar: ProgressBar = get_node_or_null("VitalsContainer/VBox/RollBar")
@onready var roll_label: Label = get_node_or_null("VitalsContainer/VBox/RollLabel")

@onready var weapon_label: Label = $WeaponContainer/VBox/WeaponLabel
@onready var ammo_label: Label = $WeaponContainer/VBox/AmmoLabel
@onready var score_label: Label = $ScoreContainer/VBox/ScoreLabel
@onready var kills_label: Label = $ScoreContainer/VBox/KillsLabel
@onready var wave_label: Label = $WaveContainer/WaveLabel
@onready var deploy_label: Label = get_node_or_null("DeployablesContainer/DeployLabel")
@onready var game_over_panel: Control = $GameOverPanel

@onready var wave_banner: PanelContainer = $WaveBanner
@onready var banner_title: Label = $WaveBanner/VBox/TitleLabel
@onready var banner_subtitle: Label = $WaveBanner/VBox/SubtitleLabel

var banner_hide_timer: SceneTreeTimer = null

func _ready() -> void:
	Global.health_changed.connect(_on_health_changed)
	Global.ammo_changed.connect(_on_ammo_changed)
	Global.score_changed.connect(_on_score_changed)
	Global.wave_changed.connect(_on_wave_changed)
	Global.wave_cleared.connect(_on_wave_cleared)
	Global.wave_countdown.connect(_on_wave_countdown)
	Global.wave_started.connect(_on_wave_started)
	Global.player_died.connect(_on_player_died)
	Global.roll_cooldown_updated.connect(_on_roll_cooldown_updated)
	Global.deployables_updated.connect(_on_deployables_updated)
	Global.perk_unlocked.connect(_on_perk_unlocked)
	
	if wave_banner:
		wave_banner.visible = false
	game_over_panel.visible = false
	_on_health_changed(Global.player_health, Global.player_max_health)
	Global.emit_current_ammo()
	_on_score_changed(Global.score, Global.kills)
	_on_wave_changed(Global.current_wave)
	_on_roll_cooldown_updated(1.5, 1.5)
	_on_deployables_updated(Global.deployable_barbed_wire, Global.deployable_claymores, Global.deployable_turrets)

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

func _on_roll_cooldown_updated(current: float, max_val: float) -> void:
	if roll_bar:
		roll_bar.max_value = max_val
		roll_bar.value = current
	if roll_label:
		if current >= max_val:
			roll_label.text = "DODGE ROLL [SPACE]: READY"
			roll_label.modulate = Color(0.3, 0.9, 1.0, 1.0)
		else:
			roll_label.text = "DODGE ROLL [SPACE]: %.1fs" % (max_val - current)
			roll_label.modulate = Color(0.7, 0.75, 0.8, 0.8)

func _on_deployables_updated(wires: int, mines: int, turrets: int) -> void:
	if deploy_label:
		deploy_label.text = "[E] DEPLOY [Q: CYCLE] • ⚡ WIRE: %d | 💣 MINE: %d | 🔫 TURRET: %d" % [wires, mines, turrets]

func _on_perk_unlocked(perk_name: String, description: String) -> void:
	if wave_banner and banner_title and banner_subtitle:
		banner_title.text = "PERK UNLOCKED: " + perk_name
		banner_title.modulate = Color(0.3, 1.0, 0.45, 1.0)
		banner_subtitle.text = description
		banner_subtitle.modulate = Color(1.0, 0.9, 0.3, 1.0)
		wave_banner.visible = true
		
		var t = get_tree().create_timer(4.0)
		banner_hide_timer = t
		await t.timeout
		if banner_hide_timer == t and wave_banner.visible and banner_title.text.begins_with("PERK UNLOCKED"):
			wave_banner.visible = false

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

func _on_wave_cleared(wave_num: int, cooldown: float) -> void:
	if wave_banner and banner_title and banner_subtitle:
		banner_title.text = "WAVE %d CLEARED!" % wave_num
		banner_title.modulate = Color(0.98, 0.85, 0.18, 1.0)
		banner_subtitle.text = "SUPPLY BREAK: NEXT WAVE IN %ds" % int(ceil(cooldown))
		banner_subtitle.modulate = Color(0.4, 0.9, 1.0, 1.0)
		wave_banner.visible = true

func _on_wave_countdown(seconds_left: int) -> void:
	if wave_banner and banner_subtitle and wave_banner.visible:
		banner_subtitle.text = "SUPPLY BREAK: NEXT WAVE IN %ds" % seconds_left

func _on_wave_started(wave_num: int) -> void:
	if wave_banner and banner_title and banner_subtitle:
		banner_title.text = "WAVE %d INCOMING!" % wave_num
		banner_title.modulate = Color(1.0, 0.35, 0.25, 1.0)
		banner_subtitle.text = "HORDE DETECTED • TAKE POSITIONS"
		banner_subtitle.modulate = Color(0.9, 0.9, 0.95, 1.0)
		wave_banner.visible = true
		
		var t = get_tree().create_timer(2.4)
		banner_hide_timer = t
		await t.timeout
		if banner_hide_timer == t and wave_banner.visible and banner_title.text.begins_with("WAVE %d INCOMING!" % wave_num):
			wave_banner.visible = false

func _on_player_died() -> void:
	if game_over_panel:
		game_over_panel.visible = true
	if wave_banner:
		wave_banner.visible = false

func restart_game() -> void:
	Global.reset_state()
	get_tree().reload_current_scene()

func _on_weapon_btn_1_pressed() -> void:
	Global.set_weapon(Global.WeaponType.PISTOL)

func _on_weapon_btn_2_pressed() -> void:
	Global.set_weapon(Global.WeaponType.SHOTGUN)

func _on_weapon_btn_3_pressed() -> void:
	Global.set_weapon(Global.WeaponType.ASSAULT_RIFLE)

func _on_weapon_btn_4_pressed() -> void:
	Global.set_weapon(Global.WeaponType.FLAMETHROWER)

func _on_weapon_btn_5_pressed() -> void:
	Global.set_weapon(Global.WeaponType.MINIGUN)
