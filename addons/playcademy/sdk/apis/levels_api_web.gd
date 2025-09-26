extends Node

# Signals for get operation (user level info)
signal get_succeeded(level_data: Dictionary)
signal get_failed(error_message: String)

# Signals for progress operation
signal progress_succeeded(progress_data: Dictionary)
signal progress_failed(error_message: String)

# Signals for addXP operation
signal add_xp_succeeded(result_data: Dictionary)
signal add_xp_failed(error_message: String)

# Signals for config operations
signal config_list_succeeded(configs_data: Array)
signal config_list_failed(error_message: String)
signal config_get_succeeded(config_data: Dictionary)
signal config_get_failed(error_message: String)

# Level system events (emitted when SDK events are received)
signal level_up(old_level: int, new_level: int, credits_awarded: int)
signal xp_gained(amount: int, total_xp_earned: int, leveled_up: bool)

var _levels_api

func _init(playcademy_client: JavaScriptObject):
	_levels_api = LevelsAPI.new(playcademy_client)
	_levels_api.get_succeeded.connect(_on_original_get_succeeded)
	_levels_api.get_failed.connect(_on_original_get_failed)
	_levels_api.progress_succeeded.connect(_on_original_progress_succeeded)
	_levels_api.progress_failed.connect(_on_original_progress_failed)
	_levels_api.add_xp_succeeded.connect(_on_original_add_xp_succeeded)
	_levels_api.add_xp_failed.connect(_on_original_add_xp_failed)
	_levels_api.config_list_succeeded.connect(_on_original_config_list_succeeded)
	_levels_api.config_list_failed.connect(_on_original_config_list_failed)
	_levels_api.config_get_succeeded.connect(_on_original_config_get_succeeded)
	_levels_api.config_get_failed.connect(_on_original_config_get_failed)
	_levels_api.level_up.connect(_on_original_level_up)
	_levels_api.xp_gained.connect(_on_original_xp_gained)
	print("[LevelsAPIWeb] Web-specific levels API initialized.")

func get_level():
	_levels_api.get_level()

func progress():
	_levels_api.progress()

func add_xp(amount: int):
	_levels_api.add_xp(amount)

func config_list():
	_levels_api.config_list()

func config_get(level: int):
	_levels_api.config_get(level)

func _on_original_get_succeeded(level_data):
	var converted_data = _js_object_to_dict(level_data)
	emit_signal("get_succeeded", converted_data)

func _on_original_get_failed(error_message: String):
	emit_signal("get_failed", error_message)

func _on_original_progress_succeeded(progress_data):
	var converted_data = _js_object_to_dict(progress_data)
	emit_signal("progress_succeeded", converted_data)

func _on_original_progress_failed(error_message: String):
	emit_signal("progress_failed", error_message)

func _on_original_add_xp_succeeded(result_data):
	var converted_data = _js_object_to_dict(result_data)
	emit_signal("add_xp_succeeded", converted_data)

func _on_original_add_xp_failed(error_message: String):
	emit_signal("add_xp_failed", error_message)

func _on_original_config_list_succeeded(configs_data):
	# Convert array of JavaScriptObjects to array of Dictionaries
	var converted_configs = []
	if configs_data != null and configs_data is JavaScriptObject:
		var configs_length = int(configs_data.length)
		for i in range(configs_length):
			var config_obj = configs_data[i]
			var converted_config = _js_object_to_dict(config_obj)
			converted_configs.append(converted_config)
	emit_signal("config_list_succeeded", converted_configs)

func _on_original_config_list_failed(error_message: String):
	emit_signal("config_list_failed", error_message)

func _on_original_config_get_succeeded(config_data):
	var converted_data = _js_object_to_dict(config_data)
	emit_signal("config_get_succeeded", converted_data)

func _on_original_config_get_failed(error_message: String):
	emit_signal("config_get_failed", error_message)

func _on_original_level_up(old_level: int, new_level: int, credits_awarded: int):
	emit_signal("level_up", old_level, new_level, credits_awarded)

func _on_original_xp_gained(amount: int, total_xp_earned: int, leveled_up: bool):
	emit_signal("xp_gained", amount, total_xp_earned, leveled_up)

func _js_object_to_dict(js_obj) -> Dictionary:
	if js_obj == null:
		return {}
	
	if js_obj is Dictionary:
		return js_obj  # Already a dictionary
	
	if not js_obj is JavaScriptObject:
		print("[LevelsAPIWeb] Warning: Expected JavaScriptObject, got: ", typeof(js_obj))
		return {}
	
	# Convert JavaScriptObject to Dictionary
	var result = {}
	
	# Common level data properties
	var level_properties = [
		"userId", "currentLevel", "currentXp", "totalXP", "lastLevelUpAt",
		"level", "xpRequired", "creditsReward", "xpToNextLevel", 
		"newLevel", "leveledUp", "creditsAwarded"
	]
	
	for prop in level_properties:
		if js_obj.hasOwnProperty(prop):
			result[prop] = js_obj[prop]
	
	return result 