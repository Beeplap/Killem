extends Node

## GameManager Autoload
## Central game state controller managing wave progress, scores, economy, and multiplayer synchronization.

var current_wave: int = 1:
	set(val):
		_current_wave = val
		if has_node("/root/Global"):
			var g = get_node("/root/Global")
			g.current_wave = val
			if g.has_signal("wave_changed"):
				g.wave_changed.emit(val)
	get:
		if has_node("/root/Global"):
			return get_node("/root/Global").current_wave
		return _current_wave

var total_score: int = 0:
	set(val):
		_total_score = val
		if has_node("/root/Global"):
			var g = get_node("/root/Global")
			g.score = val
			if g.has_signal("score_changed"):
				g.score_changed.emit(val, g.kills if "kills" in g else 0)
	get:
		if has_node("/root/Global"):
			return get_node("/root/Global").score
		return _total_score

var scrap: int = 0:
	set(val):
		_scrap = val
		if has_node("/root/Global"):
			var g = get_node("/root/Global")
			if "player_scrap" in g:
				g.player_scrap = val
			if g.has_signal("scrap_changed"):
				g.scrap_changed.emit(val)
		var eco = get_node_or_null("/root/EconomyManager")
		if eco and "player_scrap" in eco:
			eco.player_scrap = val
			if eco.has_signal("scrap_changed"):
				eco.scrap_changed.emit(val)
	get:
		if has_node("/root/Global") and "player_scrap" in get_node("/root/Global"):
			return get_node("/root/Global").player_scrap
		var eco = get_node_or_null("/root/EconomyManager")
		if eco and "player_scrap" in eco:
			return eco.player_scrap
		return _scrap

var is_game_over: bool = false

var _current_wave: int = 1
var _total_score: int = 0
var _scrap: int = 0

func reset_game() -> void:
	_current_wave = 1
	_total_score = 0
	_scrap = 0
	is_game_over = false
	if has_node("/root/Global"):
		get_node("/root/Global").reset_game()
