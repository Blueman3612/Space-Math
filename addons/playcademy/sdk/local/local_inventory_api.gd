extends Node

class_name LocalInventoryAPI

signal get_all_succeeded(inventory_data)
signal get_all_failed(error_message)

signal add_succeeded(response_data)
signal add_failed(error_message)

signal remove_succeeded(response_data)
signal remove_failed(error_message)

signal changed(change_data)

var _base_url: String

func _init(base_url: String):
	_base_url = base_url.rstrip("/")

# ------------------------ GET ALL ----------------------
func get_all():
	var http := HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(_on_get_all_completed.bind(http))
	var headers = PackedStringArray(["Authorization: Bearer sandbox-demo-token"])
	var err := http.request("%s/inventory" % _base_url, headers)
	if err != OK:
		emit_signal("get_all_failed", "HTTP_REQUEST_FAILED")
		http.queue_free()

func _on_get_all_completed(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray, http: HTTPRequest):
	http.queue_free()
	if response_code != 200:
		emit_signal("get_all_failed", "HTTP_%d" % response_code)
		return
	var json = JSON.new()
	var parse_result = json.parse(body.get_string_from_utf8())
	if parse_result != OK:
		emit_signal("get_all_failed", "JSON_PARSE_ERROR")
		return
	var data = json.data
	emit_signal("get_all_succeeded", data)

# ------------------------ ADD ----------------------
func add(item_id: String, quantity: int = 1):
	var payload = {"itemId": item_id, "qty": quantity}
	var http := HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(_on_add_completed.bind(http))
	var headers := PackedStringArray(["Content-Type: application/json", "Authorization: Bearer sandbox-demo-token"])
	var err := http.request("%s/inventory/add" % _base_url, headers, HTTPClient.METHOD_POST, JSON.stringify(payload))
	if err != OK:
		emit_signal("add_failed", "HTTP_REQUEST_FAILED")
		http.queue_free()

func _on_add_completed(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray, http: HTTPRequest):
	http.queue_free()
	if response_code != 200:
		emit_signal("add_failed", "HTTP_%d" % response_code)
		return
	var json = JSON.new()
	var parse_result = json.parse(body.get_string_from_utf8())
	if parse_result != OK:
		emit_signal("add_failed", "JSON_PARSE_ERROR")
		return
	var data = json.data
	emit_signal("add_succeeded", data)
	emit_signal("changed", data)

# ------------------------ REMOVE ----------------------
func remove(item_id: String, quantity: int = 1):
	var payload = {"itemId": item_id, "qty": quantity}
	var http := HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(_on_remove_completed.bind(http))
	var headers := PackedStringArray(["Content-Type: application/json", "Authorization: Bearer sandbox-demo-token"])
	var err := http.request("%s/inventory/remove" % _base_url, headers, HTTPClient.METHOD_POST, JSON.stringify(payload))
	if err != OK:
		emit_signal("remove_failed", "HTTP_REQUEST_FAILED")
		http.queue_free()

func _on_remove_completed(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray, http: HTTPRequest):
	http.queue_free()
	if response_code != 200:
		emit_signal("remove_failed", "HTTP_%d" % response_code)
		return
	var json = JSON.new()
	var parse_result = json.parse(body.get_string_from_utf8())
	if parse_result != OK:
		emit_signal("remove_failed", "JSON_PARSE_ERROR")
		return
	var data = json.data
	emit_signal("remove_succeeded", data)
	emit_signal("changed", data) 