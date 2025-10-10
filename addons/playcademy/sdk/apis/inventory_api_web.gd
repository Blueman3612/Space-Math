extends Node

const InventoryAPI = preload("res://addons/playcademy/sdk/apis/inventory_api.gd")

signal get_all_succeeded(inventory_data: Array)
signal get_all_failed(error_message: String)
signal add_succeeded(response_data: Dictionary)
signal add_failed(error_message: String)
signal remove_succeeded(response_data: Dictionary)
signal remove_failed(error_message: String)
signal changed(change_data)

var _inventory_api

func _init(playcademy_client: JavaScriptObject):
	_inventory_api = InventoryAPI.new(playcademy_client)
	_inventory_api.get_all_succeeded.connect(_on_original_get_all_succeeded)
	_inventory_api.get_all_failed.connect(_on_original_get_all_failed)
	_inventory_api.add_succeeded.connect(_on_original_add_succeeded)
	_inventory_api.add_failed.connect(_on_original_add_failed)
	_inventory_api.remove_succeeded.connect(_on_original_remove_succeeded)
	_inventory_api.remove_failed.connect(_on_original_remove_failed)
	_inventory_api.changed.connect(_on_original_changed)

func get_all():
	_inventory_api.get_all()

func add(item_id: String, quantity: int):
	_inventory_api.add(item_id, quantity)

func remove(item_id: String, quantity: int):
	_inventory_api.remove(item_id, quantity)

func _on_original_get_all_succeeded(inventory_data: Array):
	# Convert array of JavaScriptObjects to array of Dictionaries
	var converted_inventory = []
	for item_entry in inventory_data:
		var converted_entry = _js_object_to_dict(item_entry)
		converted_inventory.append(converted_entry)
	emit_signal("get_all_succeeded", converted_inventory)

func _on_original_get_all_failed(error_message: String):
	emit_signal("get_all_failed", error_message)

func _on_original_add_succeeded(response_data):
	var converted_response = _js_object_to_dict(response_data)
	emit_signal("add_succeeded", converted_response)

func _on_original_add_failed(error_message: String):
	emit_signal("add_failed", error_message)

func _on_original_remove_succeeded(response_data):
	var converted_response = _js_object_to_dict(response_data)
	emit_signal("remove_succeeded", converted_response)

func _on_original_remove_failed(error_message: String):
	emit_signal("remove_failed", error_message)

func _on_original_changed(change_data):
	var converted_change_data = _js_object_to_dict(change_data)
	emit_signal("changed", converted_change_data)

func _js_object_to_dict(js_obj) -> Dictionary:
	if js_obj == null:
		return {}
	
	if js_obj is Dictionary:
		return js_obj  # Already a dictionary
	
	if not js_obj is JavaScriptObject:
		print("[InventoryAPIWeb] Warning: Expected JavaScriptObject, got: ", typeof(js_obj))
		return {}
	
	# Convert JavaScriptObject to Dictionary
	var result = {}
	
	if js_obj.hasOwnProperty("id"):
		result["id"] = js_obj.id
	if js_obj.hasOwnProperty("quantity"):
		result["quantity"] = js_obj.quantity
	if js_obj.hasOwnProperty("updatedAt"):
		result["updatedAt"] = js_obj.updatedAt
	
	# Handle nested item object
	if js_obj.hasOwnProperty("item") and js_obj.item != null:
		var item_obj = js_obj.item
		var item_dict = {}
		
		var item_properties = ["id", "slug", "displayName", "description", "type", "imageUrl", "metadata"]
		for prop in item_properties:
			if item_obj.hasOwnProperty(prop):
				item_dict[prop] = item_obj[prop]
		
		result["item"] = item_dict
	
	if js_obj.hasOwnProperty("newTotal"):
		result["newTotal"] = js_obj.newTotal
	
	return result 