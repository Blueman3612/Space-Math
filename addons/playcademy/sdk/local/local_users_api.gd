extends Node

class_name LocalUsersAPI

signal profile_received(profile_data)
signal profile_fetch_failed(error_message)

var _base_url: String

func _init(base_url: String):
	_base_url = base_url.rstrip("/")

# Public API --------------------------------------------------------
# Mirrors JS SDK method `client.users.me()`
func me():
	var http := HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(_on_request_completed.bind(http))
	var headers = PackedStringArray(["Authorization: Bearer sandbox-demo-token"])
	var err := http.request("%s/users/me" % _base_url, headers)
	if err != OK:
		printerr("[LocalUsersAPI] Failed to make GET /users/me request. Error code: ", err)
		emit_signal("profile_fetch_failed", "HTTP_REQUEST_FAILED")
		http.queue_free()

# ------------------------------------------------------------------
func _on_request_completed(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray, http: HTTPRequest):
	http.queue_free()

	if response_code != 200:
		printerr("[LocalUsersAPI] /users/me HTTP %d" % response_code)
		emit_signal("profile_fetch_failed", "HTTP_%d" % response_code)
		return

	var json = JSON.new()
	var parse_result = json.parse(body.get_string_from_utf8())
	if parse_result != OK:
		printerr("[LocalUsersAPI] Failed parsing JSON from /users/me. Error code: %d" % parse_result)
		emit_signal("profile_fetch_failed", "JSON_PARSE_ERROR")
		return

	var data = json.data
	emit_signal("profile_received", data) 