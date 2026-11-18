extends Node
## Player decisions and story flags that later scenes may read. Autoload: GameState.

var flags: Dictionary = {}


func set_flag(key: String, value: Variant) -> void:
	flags[key] = value


func get_flag(key: String, default: Variant = null) -> Variant:
	return flags.get(key, default)
