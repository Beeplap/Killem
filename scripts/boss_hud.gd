extends CanvasLayer

@onready var root_container: Control = get_node_or_null("BossHUDContainer")
@onready var health_bar: ProgressBar = get_node_or_null("BossHUDContainer/PanelContainer/VBox/BarContainer/HealthBar")
@onready var ghost_bar: ProgressBar = get_node_or_null("BossHUDContainer/PanelContainer/VBox/BarContainer/GhostBar")
@onready var boss_name_label: Label = get_node_or_null("BossHUDContainer/PanelContainer/VBox/NameContainer/BossNameLabel")
@onready var phase_label: Label = get_node_or_null("BossHUDContainer/PanelContainer/VBox/NameContainer/PhaseLabel")
@onready var health_text: Label = get_node_or_null("BossHUDContainer/PanelContainer/VBox/BarContainer/HealthText")
@onready var warning_flash: Panel = get_node_or_null("BossHUDContainer/PanelContainer/VBox/WarningFlash")

var target_health: float = 2500.0
var max_health: float = 2500.0
var current_displayed_health: float = 2500.0
var ghost_health: float = 2500.0
var is_active: bool = false
var is_animating_in: bool = false
var target_y: float = 24.0
var current_phase: int = 1

func _ready() -> void:
	if root_container:
		root_container.modulate.a = 0.0
		root_container.position.y = -120.0
		root_container.visible = false
	if warning_flash:
		warning_flash.modulate.a = 0.0

func _process(delta: float) -> void:
	if not is_active and not is_animating_in:
		return
	
	# Smooth entrance animation
	if is_animating_in and root_container:
		root_container.position.y = lerpf(root_container.position.y, target_y, delta * 6.0)
		root_container.modulate.a = lerpf(root_container.modulate.a, 1.0, delta * 7.0)
		if abs(root_container.position.y - target_y) < 1.0:
			root_container.position.y = target_y
			root_container.modulate.a = 1.0
			is_animating_in = false
	
	# Smooth health catchup
	current_displayed_health = move_toward(current_displayed_health, target_health, delta * (max_health * 0.8))
	if health_bar:
		health_bar.value = current_displayed_health
	
	# Lagging ghost bar
	if ghost_health > target_health:
		ghost_health = move_toward(ghost_health, target_health, delta * (max_health * 0.35))
	else:
		ghost_health = target_health
	if ghost_bar:
		ghost_bar.value = ghost_health
	
	# Update text
	if health_text:
		var pct = int(clampf((target_health / max_health) * 100.0, 0.0, 100.0))
		health_text.text = "%d / %d HP  (%d%%)" % [int(max(0, target_health)), int(max_health), pct]
	
	# Warning flash pulse during phase 3 or enrage
	if warning_flash and current_phase >= 2:
		var pulse = (sin(Time.get_ticks_msec() * 0.008) * 0.5 + 0.5)
		warning_flash.modulate.a = pulse * (0.45 if current_phase == 2 else 0.85)

func activate_boss(boss_name: String, hp: float, m_hp: float) -> void:
	is_active = true
	is_animating_in = true
	max_health = m_hp
	target_health = hp
	current_displayed_health = hp
	ghost_health = hp
	current_phase = 1
	
	if root_container:
		root_container.visible = true
		root_container.position.y = -120.0
		root_container.modulate.a = 0.0
	
	if health_bar:
		health_bar.max_value = max_health
		health_bar.value = target_health
	if ghost_bar:
		ghost_bar.max_value = max_health
		ghost_bar.value = ghost_health
	if boss_name_label:
		boss_name_label.text = boss_name
	if phase_label:
		phase_label.text = "PHASE 1: DORMANT AGGRESSION"
		phase_label.modulate = Color(0.95, 0.75, 0.2)
	
	Global.play_sound("boss_alarm")

func update_boss_health(new_hp: float, _max_val: float = -1.0) -> void:
	target_health = max(0.0, new_hp)

func set_phase(phase: int) -> void:
	current_phase = phase
	if phase_label:
		match phase:
			1:
				phase_label.text = "PHASE 1: DORMANT AGGRESSION"
				phase_label.modulate = Color(0.95, 0.75, 0.2)
			2:
				phase_label.text = "PHASE 2: ENRAGED BIOMASS • PLAGUE SPAWN"
				phase_label.modulate = Color(1.0, 0.35, 0.15)
			3:
				phase_label.text = "PHASE 3: CORE MELTDOWN • WEAK POINT EXPOSED!"
				phase_label.modulate = Color(1.0, 0.1, 0.25)

func boss_defeated() -> void:
	is_active = false
	target_health = 0.0
	if phase_label:
		phase_label.text = "CONTAINMENT RESTORED • APEX ANOMALY ELIMINATED"
		phase_label.modulate = Color(0.3, 1.0, 0.4)
	
	if root_container:
		var tween = create_tween()
		tween.tween_property(root_container, "modulate:a", 0.0, 3.5).set_delay(2.0)
		tween.tween_callback(func(): root_container.visible = false)
