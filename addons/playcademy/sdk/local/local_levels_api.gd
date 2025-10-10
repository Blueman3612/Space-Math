extends Node

class_name LocalLevelsAPI

# Signals for get operation (user level info)
signal get_succeeded(level_data)
signal get_failed(error_message)

# Signals for progress operation
signal progress_succeeded(progress_data)
signal progress_failed(error_message)

# Signals for addXP operation
signal add_xp_succeeded(result_data)
signal add_xp_failed(error_message)

# Signals for config operations
signal config_list_succeeded(configs_data)
signal config_list_failed(error_message)
signal config_get_succeeded(config_data)
signal config_get_failed(error_message)

# Level system events (emitted when operations succeed)
signal level_up(old_level, new_level, credits_awarded)
signal xp_gained(amount, total_xp_earned, leveled_up)

var _base_url: String

func _init(base_url: String):
	_base_url = base_url.rstrip("/")

# ------------------------ GET USER LEVEL ----------------------
func get_level():
	var http := HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(_on_get_completed.bind(http))
	var headers = PackedStringArray(["Authorization: Bearer sandbox-demo-token"])
	var err := http.request("%s/users/level" % _base_url, headers)
	if err != OK:
		printerr("[LocalLevelsAPI] Failed to make GET /users/level request. Error code: ", err)
		emit_signal("get_failed", "HTTP_REQUEST_FAILED")
		http.queue_free()

func _on_get_completed(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray, http: HTTPRequest):
	http.queue_free()
	if response_code != 200:
		printerr("[LocalLevelsAPI] /users/level HTTP %d" % response_code)
		emit_signal("get_failed", "HTTP_%d" % response_code)
		return
	var json = JSON.new()
	var parse_result = json.parse(body.get_string_from_utf8())
	if parse_result != OK:
		printerr("[LocalLevelsAPI] Failed parsing JSON from /users/level. Error code: %d" % parse_result)
		emit_signal("get_failed", "JSON_PARSE_ERROR")
		return
	var data = json.data
	emit_signal("get_succeeded", data)

# ------------------------ GET USER PROGRESS ----------------------
func progress():
	var http := HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(_on_progress_completed.bind(http))
	var headers = PackedStringArray(["Authorization: Bearer sandbox-demo-token"])
	var err := http.request("%s/users/level/progress" % _base_url, headers)
	if err != OK:
		printerr("[LocalLevelsAPI] Failed to make GET /users/level/progress request. Error code: ", err)
		emit_signal("progress_failed", "HTTP_REQUEST_FAILED")
		http.queue_free()

func _on_progress_completed(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray, http: HTTPRequest):
	http.queue_free()
	if response_code != 200:
		printerr("[LocalLevelsAPI] /users/level/progress HTTP %d" % response_code)
		emit_signal("progress_failed", "HTTP_%d" % response_code)
		return
	var json = JSON.new()
	var parse_result = json.parse(body.get_string_from_utf8())
	if parse_result != OK:
		printerr("[LocalLevelsAPI] Failed parsing JSON from /users/level/progress. Error code: %d" % parse_result)
		emit_signal("progress_failed", "JSON_PARSE_ERROR")
		return
	var data = json.data
	emit_signal("progress_succeeded", data)

# ------------------------ ADD XP ----------------------
func add_xp(amount: int):
	var payload = {"amount": amount}
	var http := HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(_on_add_xp_completed.bind(http))
	var headers := PackedStringArray(["Content-Type: application/json", "Authorization: Bearer sandbox-demo-token"])
	var err := http.request("%s/users/xp/add" % _base_url, headers, HTTPClient.METHOD_POST, JSON.stringify(payload))
	if err != OK:
		printerr("[LocalLevelsAPI] Failed to make POST /users/xp/add request. Error code: ", err)
		emit_signal("add_xp_failed", "HTTP_REQUEST_FAILED")
		http.queue_free()

func _on_add_xp_completed(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray, http: HTTPRequest):
	http.queue_free()
	if response_code != 200:
		printerr("[LocalLevelsAPI] /users/xp/add HTTP %d" % response_code)
		emit_signal("add_xp_failed", "HTTP_%d" % response_code)
		return
	var json = JSON.new()
	var parse_result = json.parse(body.get_string_from_utf8())
	if parse_result != OK:
		printerr("[LocalLevelsAPI] Failed parsing JSON from /users/xp/add. Error code: %d" % parse_result)
		emit_signal("add_xp_failed", "JSON_PARSE_ERROR")
		return
	var data = json.data
	emit_signal("add_xp_succeeded", data)
	
	# Emit level system events based on the result
	if data != null and typeof(data) == TYPE_DICTIONARY:
		if data.has("leveledUp") and data.leveledUp:
			var old_level = data.newLevel - 1  # This is a simplification
			emit_signal("level_up", old_level, data.newLevel, data.creditsAwarded)
		
		if data.has("totalXP"):
			emit_signal("xp_gained", data.totalXP, data.totalXP, data.leveledUp)

# ------------------------ CONFIG LIST ----------------------
func config_list():
	var http := HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(_on_config_list_completed.bind(http))
	var headers = PackedStringArray(["Authorization: Bearer sandbox-demo-token"])
	var err := http.request("%s/levels/config" % _base_url, headers)
	if err != OK:
		printerr("[LocalLevelsAPI] Failed to make GET /levels/config request. Error code: ", err)
		emit_signal("config_list_failed", "HTTP_REQUEST_FAILED")
		http.queue_free()

func _on_config_list_completed(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray, http: HTTPRequest):
	http.queue_free()
	if response_code != 200:
		printerr("[LocalLevelsAPI] /levels/config HTTP %d" % response_code)
		emit_signal("config_list_failed", "HTTP_%d" % response_code)
		return
	var json = JSON.new()
	var parse_result = json.parse(body.get_string_from_utf8())
	if parse_result != OK:
		printerr("[LocalLevelsAPI] Failed parsing JSON from /levels/config. Error code: %d" % parse_result)
		emit_signal("config_list_failed", "JSON_PARSE_ERROR")
		return
	var data = json.data
	emit_signal("config_list_succeeded", data)

# ------------------------ CONFIG GET ----------------------
func config_get(level: int):
	var http := HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(_on_config_get_completed.bind(http))
	var headers = PackedStringArray(["Authorization: Bearer sandbox-demo-token"])
	var err := http.request("%s/levels/config/%d" % [_base_url, level], headers)
	if err != OK:
		printerr("[LocalLevelsAPI] Failed to make GET /levels/config/%d request. Error code: " % level, err)
		emit_signal("config_get_failed", "HTTP_REQUEST_FAILED")
		http.queue_free()

func _on_config_get_completed(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray, http: HTTPRequest):
	http.queue_free()
	if response_code != 200:
		printerr("[LocalLevelsAPI] /levels/config/X HTTP %d" % response_code)
		emit_signal("config_get_failed", "HTTP_%d" % response_code)
		return
	var json = JSON.new()
	var parse_result = json.parse(body.get_string_from_utf8())
	if parse_result != OK:
		printerr("[LocalLevelsAPI] Failed parsing JSON from /levels/config/X. Error code: %d" % parse_result)
		emit_signal("config_get_failed", "JSON_PARSE_ERROR")
		return
	var data = json.data
	emit_signal("config_get_succeeded", data) 