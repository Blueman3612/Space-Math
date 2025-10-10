extends Node

class_name LocalTimebackAPI

# Signals for record_progress operation
signal record_progress_succeeded(response_data)
signal record_progress_failed(error_message)

# Signals for record_session_end operation
signal record_session_end_succeeded(response_data)
signal record_session_end_failed(error_message)

# Signals for award_xp operation
signal award_xp_succeeded(response_data)
signal award_xp_failed(error_message)

var _base_url: String

func _init(base_url: String):
	_base_url = base_url.rstrip("/")

# ------------------------ RECORD PROGRESS ----------------------
func record_progress(progress_data: Dictionary):
	var http := HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(_on_record_progress_completed.bind(http))
	
	var url = "%s/integrations/timeback/progress" % _base_url
	var headers = ["Content-Type: application/json", "Authorization: Bearer sandbox-demo-token"]
	
	var request_body = {
		"progressData": progress_data
	}
	
	var json_string = JSON.stringify(request_body)
	var err := http.request(url, headers, HTTPClient.METHOD_POST, json_string)
	
	if err != OK:
		printerr("[LocalTimebackAPI] Failed to make POST %s request. Error code: %s" % [url, err])
		emit_signal("record_progress_failed", "HTTP_REQUEST_FAILED")
		http.queue_free()

func _on_record_progress_completed(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray, http: HTTPRequest):
	http.queue_free()
	if response_code != 200:
		emit_signal("record_progress_failed", "HTTP_%d" % response_code)
		return
	var json = JSON.new()
	var parse_result = json.parse(body.get_string_from_utf8())
	if parse_result != OK:
		emit_signal("record_progress_failed", "JSON_PARSE_ERROR")
		return
	var data = json.data
	emit_signal("record_progress_succeeded", data)

# ------------------------ RECORD SESSION END ----------------------
func record_session_end(session_data: Dictionary):
	var http := HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(_on_record_session_end_completed.bind(http))
	
	var url = "%s/integrations/timeback/session-end" % _base_url
	var headers = ["Content-Type: application/json", "Authorization: Bearer sandbox-demo-token"]
	
	var request_body = {
		"sessionData": session_data
	}
	
	var json_string = JSON.stringify(request_body)
	var err := http.request(url, headers, HTTPClient.METHOD_POST, json_string)
	
	if err != OK:
		printerr("[LocalTimebackAPI] Failed to make POST %s request. Error code: %s" % [url, err])
		emit_signal("record_session_end_failed", "HTTP_REQUEST_FAILED")
		http.queue_free()

func _on_record_session_end_completed(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray, http: HTTPRequest):
	http.queue_free()
	if response_code != 200:
		emit_signal("record_session_end_failed", "HTTP_%d" % response_code)
		return
	var json = JSON.new()
	var parse_result = json.parse(body.get_string_from_utf8())
	if parse_result != OK:
		emit_signal("record_session_end_failed", "JSON_PARSE_ERROR")
		return
	var data = json.data
	emit_signal("record_session_end_succeeded", data)

# ------------------------ AWARD XP ----------------------
func award_xp(xp_amount: int, metadata: Dictionary):
	var http := HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(_on_award_xp_completed.bind(http))
	
	var url = "%s/integrations/timeback/award-xp" % _base_url
	var headers = ["Content-Type: application/json", "Authorization: Bearer sandbox-demo-token"]
	
	var request_body = {
		"xpAmount": xp_amount,
		"metadata": metadata
	}
	
	var json_string = JSON.stringify(request_body)
	var err := http.request(url, headers, HTTPClient.METHOD_POST, json_string)
	
	if err != OK:
		printerr("[LocalTimebackAPI] Failed to make POST %s request. Error code: %s" % [url, err])
		emit_signal("award_xp_failed", "HTTP_REQUEST_FAILED")
		http.queue_free()

func _on_award_xp_completed(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray, http: HTTPRequest):
	http.queue_free()
	if response_code != 200:
		emit_signal("award_xp_failed", "HTTP_%d" % response_code)
		return
	var json = JSON.new()
	var parse_result = json.parse(body.get_string_from_utf8())
	if parse_result != OK:
		emit_signal("award_xp_failed", "JSON_PARSE_ERROR")
		return
	var data = json.data
	emit_signal("award_xp_succeeded", data)

