extends Node

class_name LocalScoresAPI

# Signals for submit operation
signal submit_succeeded(score_data)
signal submit_failed(error_message)

# Signals for getByUser operation
signal get_by_user_succeeded(scores_data)
signal get_by_user_failed(error_message)

var _base_url: String

func _init(base_url: String):
	_base_url = base_url.rstrip("/")

# ------------------------ SUBMIT SCORE ----------------------
func submit(score: int, metadata: Dictionary = {}):
	var http := HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(_on_submit_completed.bind(http))
	
	# In local development, let sandbox determine the game context
	var url = "%s/scores" % _base_url
	var headers = ["Content-Type: application/json"]
	
	# Build request body
	var request_body = {
		"score": score
	}
	
	# Add metadata if provided
	if not metadata.is_empty():
		request_body["metadata"] = metadata
	
	var json_string = JSON.stringify(request_body)
	var err := http.request(url, headers, HTTPClient.METHOD_POST, json_string)
	
	if err != OK:
		printerr("[LocalScoresAPI] Failed to make POST %s request. Error code: %s" % [url, err])
		emit_signal("submit_failed", "HTTP_REQUEST_FAILED")
		http.queue_free()

func _on_submit_completed(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray, http: HTTPRequest):
	http.queue_free()
	if response_code < 200 or response_code >= 300:
		printerr("[LocalScoresAPI] /games/*/scores HTTP %d" % response_code)
		emit_signal("submit_failed", "HTTP_%d" % response_code)
		return
	var json = JSON.new()
	var parse_result = json.parse(body.get_string_from_utf8())
	if parse_result != OK:
		printerr("[LocalScoresAPI] Failed parsing JSON from /games/*/scores. Error code: %d" % parse_result)
		emit_signal("submit_failed", "JSON_PARSE_ERROR")
		return
	var data = json.data
	emit_signal("submit_succeeded", data)

# ------------------------ GET BY USER ----------------------
func get_by_user(user_id: String, options: Dictionary = {}):
	var http := HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(_on_get_by_user_completed.bind(http))
	
	# Build URL with query parameters - sandbox determines game context
	var url = "%s/users/%s/scores" % [_base_url, user_id]
	var params = []
	
	# Add limit parameter if provided
	if options.has("limit"):
		params.append("limit=%d" % int(options.get("limit")))
	
	if params.size() > 0:
		url += "?" + "&".join(params)
	
	var err := http.request(url)
	if err != OK:
		printerr("[LocalScoresAPI] Failed to make GET %s request. Error code: %s" % [url, err])
		emit_signal("get_by_user_failed", "HTTP_REQUEST_FAILED")
		http.queue_free()

func _on_get_by_user_completed(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray, http: HTTPRequest):
	http.queue_free()
	if response_code < 200 or response_code >= 300:
		printerr("[LocalScoresAPI] /games/*/users/*/scores HTTP %d" % response_code)
		emit_signal("get_by_user_failed", "HTTP_%d" % response_code)
		return
	var json = JSON.new()
	var parse_result = json.parse(body.get_string_from_utf8())
	if parse_result != OK:
		printerr("[LocalScoresAPI] Failed parsing JSON from /games/*/users/*/scores. Error code: %d" % parse_result)
		emit_signal("get_by_user_failed", "JSON_PARSE_ERROR")
		return
	var data = json.data
	emit_signal("get_by_user_succeeded", data)
