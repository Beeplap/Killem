extends Node

## GameManager Compatibility Proxy
## Bridges Global and EconomyManager to satisfy the unified GameManager API.

var current_wave: int:
	get:
		return Global.current_wave
	set(val):
		Global.current_wave = val
		Global.wave_changed.emit(val)

var total_score: int:
	get:
		return Global.score
	set(val):
		Global.score = val
		Global.score_changed.emit(val, Global.kills)

var scrap: int:
	get:
		var eco = get_node_or_null("/root/EconomyManager")
		return eco.player_scrap if eco else 0
	set(val):
		var eco = get_node_or_null("/root/EconomyManager")
		if eco:
			eco.player_scrap = val
			eco.scrap_changed.emit(val)
