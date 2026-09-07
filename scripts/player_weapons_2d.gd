class_name PlayerWeapons2D
extends Node2D

## 2D Tactical Weapon Visual System
## Renders 5 high-detail military firearm models under the player's weapon mount:
## [1] 9mm Pistol, [2] Shotgun, [3] AK Assault Rifle, [4] Flamethrower, [5] Rotary Minigun.

@onready var pistol: Node2D = $Pistol
@onready var shotgun: Node2D = $Shotgun
@onready var ak: Node2D = $AK
@onready var flamethrower: Node2D = $Flamethrower
@onready var minigun: Node2D = $Minigun

var _active_weapon: Node2D = null
var _kick_tween: Tween
var _spin_angle: float = 0.0

func _ready() -> void:
	Global.weapon_changed.connect(_on_weapon_changed)
	switch_weapon(Global.current_weapon)

func _on_weapon_changed(_new_weapon: int) -> void:
	switch_weapon(Global.current_weapon)

func switch_weapon(weapon_type: int) -> void:
	if pistol: pistol.visible = (weapon_type == Global.WeaponType.PISTOL)
	if shotgun: shotgun.visible = (weapon_type == Global.WeaponType.SHOTGUN)
	if ak: ak.visible = (weapon_type == Global.WeaponType.ASSAULT_RIFLE)
	if flamethrower: flamethrower.visible = (weapon_type == Global.WeaponType.FLAMETHROWER)
	if minigun: minigun.visible = (weapon_type == Global.WeaponType.MINIGUN)
	
	match weapon_type:
		Global.WeaponType.PISTOL: _active_weapon = pistol
		Global.WeaponType.SHOTGUN: _active_weapon = shotgun
		Global.WeaponType.ASSAULT_RIFLE: _active_weapon = ak
		Global.WeaponType.FLAMETHROWER: _active_weapon = flamethrower
		Global.WeaponType.MINIGUN: _active_weapon = minigun
		_: _active_weapon = pistol

func get_active_weapon_node() -> Node2D:
	if _active_weapon:
		return _active_weapon
	return pistol

func get_muzzle_marker() -> Marker2D:
	var w = get_active_weapon_node()
	if w and w.has_node("Muzzle"):
		return w.get_node("Muzzle") as Marker2D
	return null

func get_ejection_marker() -> Marker2D:
	var w = get_active_weapon_node()
	if w and w.has_node("Ejection"):
		return w.get_node("Ejection") as Marker2D
	return null

func apply_recoil_kick(kick_distance: float = 4.5) -> void:
	if _kick_tween and _kick_tween.is_valid():
		_kick_tween.kill()
	_kick_tween = create_tween()
	position.x = -kick_distance
	_kick_tween.tween_property(self, "position:x", 0.0, 0.09).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

func update_minigun_spin(delta: float, is_spinning: bool, speed: float) -> void:
	if minigun and minigun.visible and is_spinning:
		_spin_angle += speed * delta * 24.0
		var barrel_pack = minigun.get_node_or_null("BarrelAssembly")
		if barrel_pack:
			barrel_pack.position.y = sin(_spin_angle) * 1.5
