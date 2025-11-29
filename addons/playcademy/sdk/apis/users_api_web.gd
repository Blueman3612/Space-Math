extends Node

const UsersAPI = preload("res://addons/playcademy/sdk/apis/users_api.gd")

# User profile signals
signal profile_received(user_data: Dictionary)
signal profile_fetch_failed(error_message: String)

# Inventory signals
signal inventory_get_all_succeeded(inventory_data: Array)
signal inventory_get_all_failed(error_message: String)
signal inventory_add_succeeded(response_data: Dictionary)
signal inventory_add_failed(error_message: String)
signal inventory_remove_succeeded(response_data: Dictionary)
signal inventory_remove_failed(error_message: String)
signal inventory_changed(change_data)

var _users_api

func _init(playcademy_client: JavaScriptObject):
	_users_api = UsersAPI.new(playcademy_client)
	_users_api.profile_received.connect(_on_original_profile_received)
	_users_api.profile_fetch_failed.connect(_on_original_profile_fetch_failed)
	_users_api.inventory_get_all_succeeded.connect(_on_original_inventory_get_all_succeeded)
	_users_api.inventory_get_all_failed.connect(_on_original_inventory_get_all_failed)
	_users_api.inventory_add_succeeded.connect(_on_original_inventory_add_succeeded)
	_users_api.inventory_add_failed.connect(_on_original_inventory_add_failed)
	_users_api.inventory_remove_succeeded.connect(_on_original_inventory_remove_succeeded)
	_users_api.inventory_remove_failed.connect(_on_original_inventory_remove_failed)
	_users_api.inventory_changed.connect(_on_original_inventory_changed)

func me():
	_users_api.me()

# Inventory methods
func inventory_get_all():
	_users_api.inventory_get_all()

func inventory_add(item_id: String, quantity: int = 1):
	_users_api.inventory_add(item_id, quantity)

func inventory_remove(item_id: String, quantity: int = 1):
	_users_api.inventory_remove(item_id, quantity)

func _on_original_profile_received(user_data):
	var user_dict = _js_object_to_dict(user_data)
	emit_signal("profile_received", user_dict)

func _on_original_profile_fetch_failed(error_message: String):
	emit_signal("profile_fetch_failed", error_message)

# Inventory signal handlers
func _on_original_inventory_get_all_succeeded(inventory_data):
	var inventory_array = _js_object_to_array(inventory_data)
	emit_signal("inventory_get_all_succeeded", inventory_array)

func _on_original_inventory_get_all_failed(error_message: String):
	emit_signal("inventory_get_all_failed", error_message)

func _on_original_inventory_add_succeeded(response_data):
	var response_dict = _js_object_to_dict(response_data)
	emit_signal("inventory_add_succeeded", response_dict)

func _on_original_inventory_add_failed(error_message: String):
	emit_signal("inventory_add_failed", error_message)

func _on_original_inventory_remove_succeeded(response_data):
	var response_dict = _js_object_to_dict(response_data)
	emit_signal("inventory_remove_succeeded", response_dict)

func _on_original_inventory_remove_failed(error_message: String):
	emit_signal("inventory_remove_failed", error_message)

func _on_original_inventory_changed(change_data):
	emit_signal("inventory_changed", change_data)

func _js_object_to_dict(js_obj) -> Dictionary:
	if js_obj == null:
		return {}
	
	if js_obj is Dictionary:
		return js_obj  
	
	if not js_obj is JavaScriptObject:
		print("[UsersAPIWeb] Warning: Expected JavaScriptObject, got: ", typeof(js_obj))
		return {}
	
	# Convert JavaScriptObject properties to Dictionary
	var result = {}
	
	var properties = ["id", "name", "username", "email", "emailVerified", "image", "role", "developerStatus", "createdAt", "updatedAt"]
	
	for prop in properties:
		if js_obj.hasOwnProperty(prop):
			result[prop] = js_obj[prop]
	
	return result

func _js_object_to_array(js_obj) -> Array:
	if js_obj == null:
		return []
	
	if js_obj is Array:
		return js_obj
	
	if not js_obj is JavaScriptObject:
		print("[UsersAPIWeb] Warning: Expected JavaScriptObject array, got: ", typeof(js_obj))
		return []
	
	# Convert JavaScript array to Godot Array
	var result = []
	if 'length' in js_obj:
		var length = int(js_obj.length)
		for i in range(length):
			result.append(js_obj[i])
	
	return result