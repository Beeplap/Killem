class_name WeaponMaterials
extends RefCounted

## Centralized PBR Materials Provider for Procedural 3D Firearms
## Provides cached StandardMaterial3D configurations for metal, polymer, wood, brass, and emissive tritium sights.

static var _gunmetal_steel: StandardMaterial3D
static var _tactical_polymer: StandardMaterial3D
static var _weathered_wood: StandardMaterial3D
static var _brass: StandardMaterial3D
static var _tritium_green: StandardMaterial3D
static var _shell_red: StandardMaterial3D
static var _optic_red: StandardMaterial3D
static var _flashlight_glass: StandardMaterial3D

static func get_gunmetal_steel() -> StandardMaterial3D:
	if not _gunmetal_steel:
		_gunmetal_steel = StandardMaterial3D.new()
		_gunmetal_steel.resource_name = "GunmetalSteel"
		_gunmetal_steel.albedo_color = Color(0.12, 0.13, 0.14)
		_gunmetal_steel.metallic = 0.95
		_gunmetal_steel.roughness = 0.28
	return _gunmetal_steel

static func get_tactical_polymer() -> StandardMaterial3D:
	if not _tactical_polymer:
		_tactical_polymer = StandardMaterial3D.new()
		_tactical_polymer.resource_name = "TexturedTacticalPolymer"
		_tactical_polymer.albedo_color = Color(0.08, 0.08, 0.09)
		_tactical_polymer.metallic = 0.10
		_tactical_polymer.roughness = 0.75
	return _tactical_polymer

static func get_weathered_wood() -> StandardMaterial3D:
	if not _weathered_wood:
		_weathered_wood = StandardMaterial3D.new()
		_weathered_wood.resource_name = "WeatheredWood"
		_weathered_wood.albedo_color = Color(0.32, 0.16, 0.08)
		_weathered_wood.metallic = 0.05
		_weathered_wood.roughness = 0.55
	return _weathered_wood

static func get_brass() -> StandardMaterial3D:
	if not _brass:
		_brass = StandardMaterial3D.new()
		_brass.resource_name = "BrassShells"
		_brass.albedo_color = Color(0.85, 0.65, 0.18)
		_brass.metallic = 0.95
		_brass.roughness = 0.20
	return _brass

static func get_tritium_green() -> StandardMaterial3D:
	if not _tritium_green:
		_tritium_green = StandardMaterial3D.new()
		_tritium_green.resource_name = "TritiumGreenDots"
		_tritium_green.albedo_color = Color(0.2, 1.0, 0.3)
		_tritium_green.emission_enabled = true
		_tritium_green.emission = Color(0.2, 1.0, 0.3)
		_tritium_green.emission_energy_multiplier = 4.0
	return _tritium_green

static func get_shell_red() -> StandardMaterial3D:
	if not _shell_red:
		_shell_red = StandardMaterial3D.new()
		_shell_red.resource_name = "ShotgunShellRed"
		_shell_red.albedo_color = Color(0.72, 0.11, 0.10)
		_shell_red.metallic = 0.08
		_shell_red.roughness = 0.38
	return _shell_red

static func get_optic_red() -> StandardMaterial3D:
	if not _optic_red:
		_optic_red = StandardMaterial3D.new()
		_optic_red.resource_name = "OpticReticleRed"
		_optic_red.albedo_color = Color(1.0, 0.15, 0.1)
		_optic_red.emission_enabled = true
		_optic_red.emission = Color(1.0, 0.15, 0.1)
		_optic_red.emission_energy_multiplier = 5.0
	return _optic_red

static func get_flashlight_glass() -> StandardMaterial3D:
	if not _flashlight_glass:
		_flashlight_glass = StandardMaterial3D.new()
		_flashlight_glass.resource_name = "FlashlightGlass"
		_flashlight_glass.albedo_color = Color(0.9, 0.95, 1.0, 0.8)
		_flashlight_glass.metallic = 0.1
		_flashlight_glass.roughness = 0.1
		_flashlight_glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return _flashlight_glass
