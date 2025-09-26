extends Node

signal profile_received(user_data: Dictionary)
signal profile_fetch_failed(error_message: String)

var _users_api

func _init(playcademy_client: JavaScriptObject):
	_users_api = UsersAPI.new(playcademy_client)
	_users_api.profile_received.connect(_on_original_profile_received)
	_users_api.profile_fetch_failed.connect(_on_original_profile_fetch_failed)

func me():
	_users_api.me()

func _on_original_profile_received(user_data):
	var user_dict = _js_object_to_dict(user_data)
	emit_signal("profile_received", user_dict)

func _on_original_profile_fetch_failed(error_message: String):
	emit_signal("profile_fetch_failed", error_message)

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