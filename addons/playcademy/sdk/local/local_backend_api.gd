extends Node

class_name LocalBackendAPI

# Generic signal for backend requests
signal request_succeeded(response_data)
signal request_failed(error_message)

var _base_url: String

func _init(base_url: String):
	_base_url = base_url.rstrip("/")

# ------------------------ GENERIC REQUEST ----------------------
func request(path: String, method: String = "GET", body: Dictionary = {}):
	var http := HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(_on_request_completed.bind(http))
	
	# Ensure path starts with /
	if not path.begins_with("/"):
		path = "/" + path
	
	var url = "%s%s" % [_base_url, path]
	var headers = ["Content-Type: application/json", "Authorization: Bearer sandbox-demo-token"]
	
	var http_method = _get_http_method(method)
	var json_string = ""
	
	if not body.is_empty():
		json_string = JSON.stringify(body)
	
	var err := http.request(url, headers, http_method, json_string if not body.is_empty() else "")
	
	if err != OK:
		printerr("[LocalBackendAPI] Failed to make %s %s request. Error code: %s" % [method, url, err])
		emit_signal("request_failed", "HTTP_REQUEST_FAILED")
		http.queue_free()

func _on_request_completed(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray, http: HTTPRequest):
	http.queue_free()
	if response_code != 200:
		emit_signal("request_failed", "HTTP_%d" % response_code)
		return
	var json = JSON.new()
	var parse_result = json.parse(body.get_string_from_utf8())
	if parse_result != OK:
		emit_signal("request_failed", "JSON_PARSE_ERROR")
		return
	var data = json.data
	emit_signal("request_succeeded", data)

func _get_http_method(method: String) -> HTTPClient.Method:
	match method.to_upper():
		"GET":
			return HTTPClient.METHOD_GET
		"POST":
			return HTTPClient.METHOD_POST
		"PUT":
			return HTTPClient.METHOD_PUT
		"PATCH":
			return HTTPClient.METHOD_PATCH
		"DELETE":
			return HTTPClient.METHOD_DELETE
		_:
			printerr("[LocalBackendAPI] Unknown HTTP method: %s, defaulting to GET" % method)
			return HTTPClient.METHOD_GET

