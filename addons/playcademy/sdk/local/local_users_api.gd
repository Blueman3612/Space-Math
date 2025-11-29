extends Node

class_name LocalUsersAPI

# User profile signals
signal profile_received(profile_data)
signal profile_fetch_failed(error_message)

# Inventory signals
signal inventory_get_all_succeeded(inventory_data)
signal inventory_get_all_failed(error_message)
signal inventory_add_succeeded(response_data)
signal inventory_add_failed(error_message)
signal inventory_remove_succeeded(response_data)
signal inventory_remove_failed(error_message)
signal inventory_changed(change_data)

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

# ═══════════════════════════════════════════════════════════════════
# Inventory Methods (nested under users.inventory.*)
# ═══════════════════════════════════════════════════════════════════

# Mirrors JS SDK method `client.users.inventory.get()`
func inventory_get_all():
	var http := HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(_on_inventory_get_all_completed.bind(http))
	var headers = PackedStringArray(["Authorization: Bearer sandbox-demo-token"])
	var err := http.request("%s/inventory" % _base_url, headers)
	if err != OK:
		emit_signal("inventory_get_all_failed", "HTTP_REQUEST_FAILED")
		http.queue_free()

func _on_inventory_get_all_completed(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray, http: HTTPRequest):
	http.queue_free()
	if response_code != 200:
		emit_signal("inventory_get_all_failed", "HTTP_%d" % response_code)
		return
	var json = JSON.new()
	var parse_result = json.parse(body.get_string_from_utf8())
	if parse_result != OK:
		emit_signal("inventory_get_all_failed", "JSON_PARSE_ERROR")
		return
	var data = json.data
	emit_signal("inventory_get_all_succeeded", data)

# Mirrors JS SDK method `client.users.inventory.add(itemId, qty)`
func inventory_add(item_id: String, quantity: int = 1):
	var payload = {"itemId": item_id, "qty": quantity}
	var http := HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(_on_inventory_add_completed.bind(http))
	var headers := PackedStringArray(["Content-Type: application/json", "Authorization: Bearer sandbox-demo-token"])
	var err := http.request("%s/inventory/add" % _base_url, headers, HTTPClient.METHOD_POST, JSON.stringify(payload))
	if err != OK:
		emit_signal("inventory_add_failed", "HTTP_REQUEST_FAILED")
		http.queue_free()

func _on_inventory_add_completed(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray, http: HTTPRequest):
	http.queue_free()
	if response_code != 200:
		emit_signal("inventory_add_failed", "HTTP_%d" % response_code)
		return
	var json = JSON.new()
	var parse_result = json.parse(body.get_string_from_utf8())
	if parse_result != OK:
		emit_signal("inventory_add_failed", "JSON_PARSE_ERROR")
		return
	var data = json.data
	emit_signal("inventory_add_succeeded", data)
	emit_signal("inventory_changed", data)

# Mirrors JS SDK method `client.users.inventory.remove(itemId, qty)`
func inventory_remove(item_id: String, quantity: int = 1):
	var payload = {"itemId": item_id, "qty": quantity}
	var http := HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(_on_inventory_remove_completed.bind(http))
	var headers := PackedStringArray(["Content-Type: application/json", "Authorization: Bearer sandbox-demo-token"])
	var err := http.request("%s/inventory/remove" % _base_url, headers, HTTPClient.METHOD_POST, JSON.stringify(payload))
	if err != OK:
		emit_signal("inventory_remove_failed", "HTTP_REQUEST_FAILED")
		http.queue_free()

func _on_inventory_remove_completed(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray, http: HTTPRequest):
	http.queue_free()
	if response_code != 200:
		emit_signal("inventory_remove_failed", "HTTP_%d" % response_code)
		return
	var json = JSON.new()
	var parse_result = json.parse(body.get_string_from_utf8())
	if parse_result != OK:
		emit_signal("inventory_remove_failed", "JSON_PARSE_ERROR")
		return
	var data = json.data
	emit_signal("inventory_remove_succeeded", data)
	emit_signal("inventory_changed", data)