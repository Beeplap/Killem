extends CanvasLayer
class_name TacticalArmoryMenu

## Modular Tactical Armory & Upgrade Station UI
## Provides defensive deployables restock and permanent per-run weapon modifications.

@onready var menu_root: Control = $MenuRoot
@onready var scrap_label: Label = $MenuRoot/Panel/VBox/Header/ScrapBox/ScrapLabel

# Restock Buttons
@onready var btn_grenade: Button = $MenuRoot/Panel/VBox/ContentHBox/RestockCol/GrenadeCard/Button
@onready var btn_barbwire: Button = $MenuRoot/Panel/VBox/ContentHBox/RestockCol/BarbwireCard/Button
@onready var btn_turret: Button = $MenuRoot/Panel/VBox/ContentHBox/RestockCol/TurretCard/Button

@onready var stock_grenade: Label = $MenuRoot/Panel/VBox/ContentHBox/RestockCol/GrenadeCard/StockLabel
@onready var stock_barbwire: Label = $MenuRoot/Panel/VBox/ContentHBox/RestockCol/BarbwireCard/StockLabel
@onready var stock_turret: Label = $MenuRoot/Panel/VBox/ContentHBox/RestockCol/TurretCard/StockLabel

# Upgrade Buttons
@onready var btn_barrel: Button = $MenuRoot/Panel/VBox/ContentHBox/UpgradeCol/BarrelCard/Button
@onready var btn_drum: Button = $MenuRoot/Panel/VBox/ContentHBox/UpgradeCol/DrumCard/Button
@onready var btn_hollow_point: Button = $MenuRoot/Panel/VBox/ContentHBox/UpgradeCol/HollowPointCard/Button
@onready var btn_high_voltage: Button = $MenuRoot/Panel/VBox/ContentHBox/UpgradeCol/VoltageCard/Button

@onready var close_btn: Button = $MenuRoot/Panel/VBox/Footer/CloseButton

var _opened_timestamp: float = 0.0
var _e_released_since_open: bool = false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 95
	visible = false
	if menu_root:
		menu_root.visible = false
		var backdrop = menu_root.get_node_or_null("Backdrop")
		if backdrop:
			backdrop.gui_input.connect(func(ev: InputEvent):
				if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
					var elapsed = (Time.get_ticks_msec() / 1000.0) - _opened_timestamp
					if elapsed >= 0.25:
						close()
			)
	
	_connect_buttons()
	EconomyManager.scrap_changed.connect(func(_val): if visible: _update_ui())

func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	
	# Detect when the player releases E after opening the menu
	if event is InputEventKey and event.keycode == KEY_E and not event.pressed:
		_e_released_since_open = true
		return
	
	# Ignore OS key repeats / echo events
	if event.is_echo():
		return
	
	var elapsed = (Time.get_ticks_msec() / 1000.0) - _opened_timestamp
	if elapsed < 0.25:
		return
	
	# ESC or UI cancel (Controller B / Back)
	if event.is_action_pressed("ui_cancel") or (event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE):
		close()
		get_viewport().set_input_as_handled()
		return
	
	# E only closes if it has been fully released and pressed again
	if event is InputEventKey and event.pressed and event.keycode == KEY_E:
		if _e_released_since_open:
			close()
			get_viewport().set_input_as_handled()
			return

func open() -> void:
	visible = true
	_opened_timestamp = Time.get_ticks_msec() / 1000.0
	_e_released_since_open = not Input.is_key_pressed(KEY_E)
	
	if menu_root:
		menu_root.visible = true
		var backdrop = menu_root.get_node_or_null("Backdrop")
		if backdrop:
			backdrop.modulate.a = 0.0
			var tween_bg = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
			tween_bg.tween_property(backdrop, "modulate:a", 1.0, 0.15)
		
		var panel = menu_root.get_node_or_null("Panel")
		if panel:
			panel.pivot_offset = panel.size * 0.5
			panel.scale = Vector2(0.92, 0.92)
			panel.modulate.a = 0.0
			var tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
			tween.tween_property(panel, "scale", Vector2.ONE, 0.20).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			tween.parallel().tween_property(panel, "modulate:a", 1.0, 0.15)
	
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_update_ui()

func close() -> void:
	if not visible:
		return
	
	visible = false
	if menu_root:
		menu_root.visible = false
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
	EconomyManager.armory_closed.emit()

func _connect_buttons() -> void:
	if btn_grenade:
		btn_grenade.pressed.connect(func(): EconomyManager.buy_grenade_refill(); _update_ui())
	if btn_barbwire:
		btn_barbwire.pressed.connect(func(): EconomyManager.buy_barbwire_kit(); _update_ui())
	if btn_turret:
		btn_turret.pressed.connect(func(): EconomyManager.buy_turret_kit(); _update_ui())
	
	if btn_barrel:
		btn_barrel.pressed.connect(func(): EconomyManager.buy_match_grade_barrel(); _update_ui())
	if btn_drum:
		btn_drum.pressed.connect(func(): EconomyManager.buy_extended_drum(); _update_ui())
	if btn_hollow_point:
		btn_hollow_point.pressed.connect(func(): EconomyManager.buy_hollow_point(); _update_ui())
	if btn_high_voltage:
		btn_high_voltage.pressed.connect(func(): EconomyManager.buy_high_voltage_wire(); _update_ui())
	
	if close_btn:
		close_btn.pressed.connect(close)

func _update_ui() -> void:
	var scrap = EconomyManager.player_scrap
	if scrap_label:
		scrap_label.text = "SCRAP: %d" % scrap
	
	# Restock buttons
	if stock_grenade:
		stock_grenade.text = "IN STOCK: x%d" % Global.deployable_grenades
	if stock_barbwire:
		stock_barbwire.text = "IN STOCK: x%d" % Global.deployable_barbwire
	if stock_turret:
		stock_turret.text = "IN STOCK: x%d" % Global.deployable_turrets
	
	if btn_grenade:
		btn_grenade.disabled = not EconomyManager.can_afford(EconomyManager.COST_GRENADE)
	if btn_barbwire:
		btn_barbwire.disabled = not EconomyManager.can_afford(EconomyManager.COST_BARBWIRE)
	if btn_turret:
		btn_turret.disabled = not EconomyManager.can_afford(EconomyManager.COST_TURRET)
	
	# Upgrade: Match-Grade Barrel
	if btn_barrel:
		if EconomyManager.mod_match_grade_barrel:
			btn_barrel.text = "INSTALLED [ACTIVE]"
			btn_barrel.disabled = true
			btn_barrel.modulate = Color(0.35, 1.0, 0.55)
		else:
			btn_barrel.text = "[75 SCRAP] PURCHASE"
			btn_barrel.disabled = not EconomyManager.can_afford(EconomyManager.COST_MATCH_GRADE_BARREL)
			btn_barrel.modulate = Color.WHITE
	
	# Upgrade: Extended Drum
	if btn_drum:
		if EconomyManager.mod_extended_drum:
			btn_drum.text = "INSTALLED [ACTIVE]"
			btn_drum.disabled = true
			btn_drum.modulate = Color(0.35, 1.0, 0.55)
		else:
			btn_drum.text = "[90 SCRAP] PURCHASE"
			btn_drum.disabled = not EconomyManager.can_afford(EconomyManager.COST_EXTENDED_DRUM)
			btn_drum.modulate = Color.WHITE
	
	# Upgrade: Hollow-Point Rounds
	if btn_hollow_point:
		if EconomyManager.mod_hollow_point:
			btn_hollow_point.text = "INSTALLED [ACTIVE]"
			btn_hollow_point.disabled = true
			btn_hollow_point.modulate = Color(0.35, 1.0, 0.55)
		else:
			btn_hollow_point.text = "[120 SCRAP] PURCHASE"
			btn_hollow_point.disabled = not EconomyManager.can_afford(EconomyManager.COST_HOLLOW_POINT)
			btn_hollow_point.modulate = Color.WHITE
	
	# Upgrade: High-Voltage Wire
	if btn_high_voltage:
		if EconomyManager.mod_high_voltage_wire:
			btn_high_voltage.text = "INSTALLED [ACTIVE]"
			btn_high_voltage.disabled = true
			btn_high_voltage.modulate = Color(0.35, 1.0, 0.55)
		else:
			btn_high_voltage.text = "[140 SCRAP] PURCHASE"
			btn_high_voltage.disabled = not EconomyManager.can_afford(EconomyManager.COST_HIGH_VOLTAGE_WIRE)
			btn_high_voltage.modulate = Color.WHITE
