extends Node

class_name LocalLeaderboardAPI

# Signals for fetch operation
signal fetch_succeeded(leaderboard_data)
signal fetch_failed(error_message)

# Signals for getUserRank operation
signal get_user_rank_succeeded(rank_data)
signal get_user_rank_failed(error_message)

var _base_url: String

func _init(base_url: String): 
	_base_url = base_url.rstrip("/")

# ------------------------ FETCH LEADERBOARD ----------------------
func fetch(options: Dictionary = {}):
	var http := HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(_on_fetch_completed.bind(http, options))
	
	# Build URL with query parameters
	var url = "%s/leaderboard" % _base_url
	var params = []

	# timeframe (default all_time)
	var timeframe = str(options.get("timeframe", "all_time")).uri_encode()
	params.append("timeframe=%s" % timeframe)

	# limit (default 10)
	var limit_val = int(options.get("limit", 10))
	params.append("limit=%d" % limit_val)

	# offset (default 0)
	var offset_val = int(options.get("offset", 0))
	params.append("offset=%d" % offset_val)

	# For local development, sandbox handles game context
	# gameId parameter ignored - sandbox knows which game we're developing
	
	if params.size() > 0:
		url += "?" + "&".join(params)
	
	var headers = PackedStringArray(["Authorization: Bearer sandbox-demo-token"])
	var err := http.request(url, headers)
	if err != OK:
		printerr("[LocalLeaderboardAPI] Failed to make GET %s request. Error code: %s" % [url, err])
		emit_signal("fetch_failed", "HTTP_REQUEST_FAILED")
		http.queue_free()

func _on_fetch_completed(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray, http: HTTPRequest, options: Dictionary):
	http.queue_free()
	if response_code < 200 or response_code >= 300:
		printerr("[LocalLeaderboardAPI] /leaderboard HTTP %d" % response_code)
		emit_signal("fetch_failed", "HTTP_%d" % response_code)
		return
	var json = JSON.new()
	var parse_result = json.parse(body.get_string_from_utf8())
	if parse_result != OK:
		printerr("[LocalLeaderboardAPI] Failed parsing JSON from /leaderboard. Error code: %d" % parse_result)
		emit_signal("fetch_failed", "JSON_PARSE_ERROR")
		return
	var data = json.data
	emit_signal("fetch_succeeded", data)

# Get current user's rank in current game - convenience method  
func get_my_rank():
	# TODO: Need to get current user ID from context
	printerr("[LocalLeaderboardAPI] get_my_rank() not fully implemented - need current user ID")
	emit_signal("get_user_rank_failed", "NOT_IMPLEMENTED")

# ------------------------ GET USER RANK ----------------------
func get_user_rank(user_id: String, game_id: String = ""):
	# In local development, sandbox handles game context
	var http := HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(_on_get_user_rank_completed.bind(http))
	
	var url = "%s/users/%s/rank" % [_base_url, user_id]
	var headers = PackedStringArray(["Authorization: Bearer sandbox-demo-token"])
	var err := http.request(url, headers)
	if err != OK:
		printerr("[LocalLeaderboardAPI] Failed to make GET %s request. Error code: %s" % [url, err])
		emit_signal("get_user_rank_failed", "HTTP_REQUEST_FAILED")
		http.queue_free()

func _on_get_user_rank_completed(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray, http: HTTPRequest):
	http.queue_free()
	if response_code < 200 or response_code >= 300:
		printerr("[LocalLeaderboardAPI] /games/*/users/*/rank HTTP %d" % response_code)
		emit_signal("get_user_rank_failed", "HTTP_%d" % response_code)
		return
	var json = JSON.new()
	var parse_result = json.parse(body.get_string_from_utf8())
	if parse_result != OK:
		printerr("[LocalLeaderboardAPI] Failed parsing JSON from /games/*/users/*/rank. Error code: %d" % parse_result)
		emit_signal("get_user_rank_failed", "JSON_PARSE_ERROR")
		return
	var data = json.data
	emit_signal("get_user_rank_succeeded", data)
