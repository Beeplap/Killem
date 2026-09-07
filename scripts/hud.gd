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
@onready var game_over_panel: Control = $GameOverPanel

@onready var wave_banner: PanelContainer = $WaveBanner
@onready var banner_title: Label = $WaveBanner/VBox/TitleLabel
@onready var banner_subtitle: Label = $WaveBanner/VBox/SubtitleLabel

# Tactical Equipment Cards
@onready var wire_card: Button = get_node_or_null("TacticalEquipment/DeployablesBar/WireCard")
@onready var mine_card: Button = get_node_or_null("TacticalEquipment/DeployablesBar/MineCard")
@onready var turret_card: Button = get_node_or_null("TacticalEquipment/DeployablesBar/TurretCard")

@onready var wire_stock: Label = get_node_or_null("TacticalEquipment/DeployablesBar/WireCard/HBox/Stock")
@onready var mine_stock: Label = get_node_or_null("TacticalEquipment/DeployablesBar/MineCard/HBox/Stock")
@onready var turret_stock: Label = get_node_or_null("TacticalEquipment/DeployablesBar/TurretCard/HBox/Stock")

@onready var wire_icon: TextureRect = get_node_or_null("TacticalEquipment/DeployablesBar/WireCard/HBox/Icon")
@onready var mine_icon: TextureRect = get_node_or_null("TacticalEquipment/DeployablesBar/MineCard/HBox/Icon")
@onready var turret_icon: TextureRect = get_node_or_null("TacticalEquipment/DeployablesBar/TurretCard/HBox/Icon")

var weapon_cards: Array[Button] = []
var weapon_ammo_labels: Array[Label] = []
var weapon_icons: Array[TextureRect] = []
var deployable_cards: Array[Button] = []

var banner_hide_timer: SceneTreeTimer = null

# Custom StyleBoxes for Tactical Highlight Borders
var style_inactive: StyleBoxFlat
var style_weapon_active: StyleBoxFlat
var style_deploy_active: StyleBoxFlat

func _ready() -> void:
	_init_styles()
	_collect_equipment_nodes()
	_setup_card_icons()
	
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
	Global.weapon_changed.connect(_on_weapon_changed)
	Global.active_deployable_changed.connect(_on_active_deployable_changed)
	
	if wave_banner:
		wave_banner.visible = false
	game_over_panel.visible = false
	
	_on_health_changed(Global.player_health, Global.player_max_health)
	Global.emit_current_ammo()
	_on_score_changed(Global.score, Global.kills)
	_on_wave_changed(Global.current_wave)
	_on_roll_cooldown_updated(1.5, 1.5)
	_on_deployables_updated(Global.deployable_barbed_wire, Global.deployable_claymores, Global.deployable_turrets)
	_on_weapon_changed(Global.current_weapon)
	_on_active_deployable_changed(Global.active_deployable_type)
	_update_all_weapon_ammo()

func _init_styles() -> void:
	# Inactive Dark Slate
	style_inactive = StyleBoxFlat.new()
	style_inactive.bg_color = Color(0.07, 0.09, 0.11, 0.90)
	style_inactive.border_color = Color(0.25, 0.28, 0.32, 0.85)
	style_inactive.set_border_width_all(1)
	style_inactive.set_corner_radius_all(4)
	
	# Active Weapon Amber Highlight
	style_weapon_active = StyleBoxFlat.new()
	style_weapon_active.bg_color = Color(0.12, 0.16, 0.20, 0.96)
	style_weapon_active.border_color = Color(0.98, 0.82, 0.15, 1.0)
	style_weapon_active.set_border_width_all(2)
	style_weapon_active.set_corner_radius_all(4)
	style_weapon_active.shadow_color = Color(0.98, 0.82, 0.15, 0.35)
	style_weapon_active.shadow_size = 4
	
	# Active Deployable Tactical Green Highlight
	style_deploy_active = StyleBoxFlat.new()
	style_deploy_active.bg_color = Color(0.08, 0.18, 0.14, 0.95)
	style_deploy_active.border_color = Color(0.20, 0.95, 0.55, 1.0)
	style_deploy_active.set_border_width_all(2)
	style_deploy_active.set_corner_radius_all(4)
	style_deploy_active.shadow_color = Color(0.20, 0.95, 0.55, 0.35)
	style_deploy_active.shadow_size = 4

func _collect_equipment_nodes() -> void:
	weapon_cards.clear()
	weapon_ammo_labels.clear()
	weapon_icons.clear()
	
	for i in range(1, 6):
		var card = get_node_or_null("TacticalEquipment/WeaponCardsBar/Card%d" % i) as Button
		if card:
			weapon_cards.append(card)
			var ammo_lbl = card.get_node_or_null("VBox/Ammo") as Label
			if ammo_lbl:
				weapon_ammo_labels.append(ammo_lbl)
			var icon = card.get_node_or_null("VBox/Icon") as TextureRect
			if icon:
				weapon_icons.append(icon)
	
	deployable_cards.clear()
	if wire_card: deployable_cards.append(wire_card)
	if mine_card: deployable_cards.append(mine_card)
	if turret_card: deployable_cards.append(turret_card)

func _setup_card_icons() -> void:
	# Populate procedural weapon silhouettes
	for i in range(weapon_icons.size()):
		if is_instance_valid(weapon_icons[i]):
			weapon_icons[i].texture = ProceduralTextures.get_weapon_icon(i)
	
	# Populate procedural deployable icons
	if wire_icon:
		wire_icon.texture = ProceduralTextures.get_deployable_icon(0)
	if mine_icon:
		mine_icon.texture = ProceduralTextures.get_deployable_icon(1)
	if turret_icon:
		turret_icon.texture = ProceduralTextures.get_deployable_icon(2)

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
	if wire_stock:
		wire_stock.text = "x%d" % wires
		wire_stock.modulate = Color(0.2, 0.95, 0.55) if wires > 0 else Color(0.95, 0.3, 0.3)
	if mine_stock:
		mine_stock.text = "x%d" % mines
		mine_stock.modulate = Color(0.2, 0.95, 0.55) if mines > 0 else Color(0.95, 0.3, 0.3)
	if turret_stock:
		turret_stock.text = "x%d" % turrets
		turret_stock.modulate = Color(0.2, 0.95, 0.55) if turrets > 0 else Color(0.95, 0.3, 0.3)

func _on_active_deployable_changed(deploy_type: int) -> void:
	for i in range(deployable_cards.size()):
		var card = deployable_cards[i]
		if not is_instance_valid(card):
			continue
		
		if i == deploy_type:
			card.add_theme_stylebox_override("normal", style_deploy_active)
			card.add_theme_stylebox_override("hover", style_deploy_active)
			
			# Tactile [Q] cycle animation pulse
			var tween = create_tween()
			card.scale = Vector2(1.12, 1.12)
			tween.tween_property(card, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		else:
			card.add_theme_stylebox_override("normal", style_inactive)
			card.add_theme_stylebox_override("hover", style_inactive)
			card.scale = Vector2.ONE

func _on_weapon_changed(new_weapon: Global.WeaponType) -> void:
	var active_idx = int(new_weapon)
	for i in range(weapon_cards.size()):
		var card = weapon_cards[i]
		if not is_instance_valid(card):
			continue
		
		if i == active_idx:
			card.add_theme_stylebox_override("normal", style_weapon_active)
			card.add_theme_stylebox_override("hover", style_weapon_active)
		else:
			card.add_theme_stylebox_override("normal", style_inactive)
			card.add_theme_stylebox_override("hover", style_inactive)
	
	_update_all_weapon_ammo()

func _update_all_weapon_ammo() -> void:
	if weapon_ammo_labels.size() >= 5:
		weapon_ammo_labels[0].text = "AMMO: ∞"
		weapon_ammo_labels[1].text = "%d / %d" % [Global.shotgun_ammo, Global.shotgun_max_ammo]
		weapon_ammo_labels[2].text = "%d / %d" % [Global.rifle_ammo, Global.rifle_max_ammo]
		weapon_ammo_labels[3].text = "%d / %d" % [Global.flamethrower_fuel, Global.flamethrower_max_fuel]
		weapon_ammo_labels[4].text = "%d / %d" % [Global.minigun_ammo, Global.minigun_max_ammo]

func _on_ammo_changed(weapon_name: String, current: int, max_val: int) -> void:
	if weapon_label:
		weapon_label.text = weapon_name
	if ammo_label:
		if current >= 999:
			ammo_label.text = "AMMO: ∞"
		else:
			ammo_label.text = "AMMO: %d / %d" % [current, max_val]
	
	_update_all_weapon_ammo()

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

func _on_wire_card_pressed() -> void:
	Global.set_active_deployable(0)

func _on_mine_card_pressed() -> void:
	Global.set_active_deployable(1)

func _on_turret_card_pressed() -> void:
	Global.set_active_deployable(2)

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
