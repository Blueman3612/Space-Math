class_name InventoryAPI extends RefCounted

# Signals for get_all operation (renamed from get)
signal get_all_succeeded(inventory_data)
signal get_all_failed(error_message)

# Signals for add operation
signal add_succeeded(response_data)
signal add_failed(error_message)

# Signals for remove operation
signal remove_succeeded(response_data)
signal remove_failed(error_message)

signal changed(change_data)

var _main_client: JavaScriptObject

# To keep JS callbacks alive for ongoing operations
var _get_all_resolve_cb_js: JavaScriptObject = null
var _get_all_reject_cb_js: JavaScriptObject = null
var _add_resolve_cb_js: JavaScriptObject = null
var _add_reject_cb_js: JavaScriptObject = null
var _remove_resolve_cb_js: JavaScriptObject = null
var _remove_reject_cb_js: JavaScriptObject = null

func _init(client_js_object: JavaScriptObject):
	_main_client = client_js_object
	
	# TODO: Subscribe to the JS SDK's event bus for 'inventoryChange' events
	# and emit the Godot 'changed' signal when those JS events fire.
	# This would require additional JavaScriptBridge.create_callback calls for event listeners:
	# - _main_client.on('inventoryChange', inventory_change_callback)
	# Currently we manually emit 'changed' signals based on API response data as a workaround.
	# This pattern should be implemented across all Godot SDK APIs for consistency.


# Corresponds to client.users.inventory.get()
func get_all():
	if _main_client == null:
		printerr("[InventoryAPI] Main client not set. Cannot call get_all().")
		emit_signal("get_all_failed", "MAIN_CLIENT_NULL")
		return

	if not ('users' in _main_client and 
			_main_client.users is JavaScriptObject and 
			'inventory' in _main_client.users and 
			_main_client.users.inventory is JavaScriptObject and 
			'get' in _main_client.users.inventory):
		printerr("[InventoryAPI] client.users.inventory.get() path not found for get_all().")
		emit_signal("get_all_failed", "METHOD_PATH_INVALID")
		return

	var promise = _main_client.users.inventory.get()

	if not promise is JavaScriptObject:
		printerr("[InventoryAPI] inventory.get() did not return a Promise for get_all().")
		emit_signal("get_all_failed", "NOT_A_PROMISE")
		return

	var on_resolve = Callable(self, "_on_get_all_resolved").bind()
	var on_reject = Callable(self, "_on_get_all_rejected").bind()

	_get_all_resolve_cb_js = JavaScriptBridge.create_callback(on_resolve)
	_get_all_reject_cb_js = JavaScriptBridge.create_callback(on_reject)

	promise.then(_get_all_resolve_cb_js, _get_all_reject_cb_js)

func _on_get_all_resolved(args: Array):
	if args.size() == 0:
		printerr("[InventoryAPI] Get inventory promise resolved with no data arguments.")
		emit_signal("get_all_succeeded", [])
		_clear_get_all_callbacks()
		return

	var raw_inventory_data = args[0] 
	var normalized_inventory_data = []
	var inv_len = int(raw_inventory_data.length)

	for i in range(inv_len):
		var item_entry_js = raw_inventory_data[i]

		if item_entry_js == null:
			printerr("[InventoryAPI] WARNING: Encountered null item entry at index %d. Skipping." % i)
			continue

		var item_data_dict = {}
		
		# Convert the JavaScript item object to a Dictionary
		var item_js = item_entry_js.item
		if item_js != null and item_js is JavaScriptObject:
			var item_dict = {}
			var item_properties = ["id", "slug", "displayName", "description", "type", "imageUrl", "metadata"]
			for prop in item_properties:
				if item_js.hasOwnProperty(prop):
					item_dict[prop] = item_js[prop]
			item_data_dict["item"] = item_dict
		else:
			# Fallback for non-JS environments or if item is already a dict
			item_data_dict["item"] = item_js

		var raw_quantity = item_entry_js.quantity
		var int_quantity = 0

		if raw_quantity != null:
			if typeof(raw_quantity) == TYPE_INT:
				int_quantity = int(raw_quantity)
			elif typeof(raw_quantity) == TYPE_FLOAT:
				int_quantity = int(raw_quantity) # Truncate
			elif typeof(raw_quantity) == TYPE_STRING:
				if String(raw_quantity).is_valid_int():
					int_quantity = String(raw_quantity).to_int()
				else:
					printerr("[InventoryAPI] WARNING: Quantity for item at index %d is a non-integer string: '%s'. Defaulting to 0." % [i, raw_quantity])
			else:
				printerr("[InventoryAPI] WARNING: Quantity for item at index %d has unexpected type: %s. Value: '%s'. Defaulting to 0." % [i, typeof(raw_quantity), raw_quantity])
		
		item_data_dict["quantity"] = int_quantity
		normalized_inventory_data.append(item_data_dict)
			
	emit_signal("get_all_succeeded", normalized_inventory_data)
	_clear_get_all_callbacks()

func _on_get_all_rejected(args: Array):
	printerr("[InventoryAPI] Get inventory failed: ", args[0] if args.size() > 0 else "Unknown error")
	var error_msg = "FETCH_REJECTED_UNKNOWN"
	if args.size() > 0: error_msg = str(args[0])
	emit_signal("get_all_failed", error_msg)
	_clear_get_all_callbacks()

func _clear_get_all_callbacks():
	_get_all_resolve_cb_js = null
	_get_all_reject_cb_js = null


# Corresponds to client.users.inventory.add(itemId, qty)
func add(item_id: String, quantity: int = 1):
	if _main_client == null:
		printerr("[InventoryAPI] Main client not set. Cannot call add().")
		emit_signal("add_failed", "MAIN_CLIENT_NULL")
		return
	
	if not ('users' in _main_client and 
			_main_client.users is JavaScriptObject and 
			'inventory' in _main_client.users and 
			_main_client.users.inventory is JavaScriptObject and 
			'add' in _main_client.users.inventory):
		printerr("[InventoryAPI] client.users.inventory.add() path not found.")
		emit_signal("add_failed", "METHOD_PATH_INVALID")
		return

	var promise = _main_client.users.inventory.add(item_id, quantity)

	if not promise is JavaScriptObject:
		printerr("[InventoryAPI] add() did not return a Promise.")
		emit_signal("add_failed", "NOT_A_PROMISE")
		return

	var on_resolve = Callable(self, "_on_add_resolved").bind()
	var on_reject = Callable(self, "_on_add_rejected").bind()

	_add_resolve_cb_js = JavaScriptBridge.create_callback(on_resolve)
	_add_reject_cb_js = JavaScriptBridge.create_callback(on_reject)

	promise.then(_add_resolve_cb_js, _add_reject_cb_js)

func _on_add_resolved(args: Array):
	var response_data = null
	if args.size() > 0: response_data = args[0]
	emit_signal("add_succeeded", response_data)
	emit_signal("changed", response_data)
	_clear_add_callbacks()

func _on_add_rejected(args: Array):
	printerr("[InventoryAPI] Add item failed: ", args[0] if args.size() > 0 else "Unknown error")
	var error_msg = "ADD_REJECTED_UNKNOWN"
	if args.size() > 0: error_msg = str(args[0])
	emit_signal("add_failed", error_msg)
	_clear_add_callbacks()

func _clear_add_callbacks():
	_add_resolve_cb_js = null
	_add_reject_cb_js = null


# Corresponds to client.users.inventory.remove(itemId, qty)
func remove(item_id: String, quantity: int = 1):
	if _main_client == null:
		printerr("[InventoryAPI] Main client not set. Cannot call remove().")
		emit_signal("remove_failed", "MAIN_CLIENT_NULL")
		return

	if not ('users' in _main_client and 
			_main_client.users is JavaScriptObject and 
			'inventory' in _main_client.users and 
			_main_client.users.inventory is JavaScriptObject and 
			'remove' in _main_client.users.inventory):
		printerr("[InventoryAPI] client.users.inventory.remove() path not found.")
		emit_signal("remove_failed", "METHOD_PATH_INVALID")
		return

	var promise = _main_client.users.inventory.remove(item_id, quantity)

	if not promise is JavaScriptObject:
		printerr("[InventoryAPI] remove() did not return a Promise.")
		emit_signal("remove_failed", "NOT_A_PROMISE")
		return

	var on_resolve = Callable(self, "_on_remove_resolved").bind()
	var on_reject = Callable(self, "_on_remove_rejected").bind()

	_remove_resolve_cb_js = JavaScriptBridge.create_callback(on_resolve)
	_remove_reject_cb_js = JavaScriptBridge.create_callback(on_reject)

	promise.then(_remove_resolve_cb_js, _remove_reject_cb_js)

func _on_remove_resolved(args: Array):
	var response_data = null
	if args.size() > 0: response_data = args[0]
	emit_signal("remove_succeeded", response_data)
	emit_signal("changed", response_data)
	_clear_remove_callbacks()

func _on_remove_rejected(args: Array):
	printerr("[InventoryAPI] Remove item failed: ", args[0] if args.size() > 0 else "Unknown error")
	var error_msg = "REMOVE_REJECTED_UNKNOWN"
	if args.size() > 0: error_msg = str(args[0])
	emit_signal("remove_failed", error_msg)
	_clear_remove_callbacks()

func _clear_remove_callbacks():
	_remove_resolve_cb_js = null
	_remove_reject_cb_js = null


# TODO: Implement listening to JS event bus for 'inventoryChange'
# func _on_js_inventory_changed_event(args: Array):
# 	 print("[InventoryAPI] Received 'inventoryChange' event from JS SDK event bus. Args: ", args)
# 	 if args.size() > 0:
# 		 emit_signal("changed", args[0])
# 	 else:
# 		 emit_signal("changed", null) # Or some default notification data 
