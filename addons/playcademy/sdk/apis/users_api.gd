class_name UsersAPI extends RefCounted

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

var _main_client: JavaScriptObject
var _resolve_cb_js: JavaScriptObject = null
var _reject_cb_js: JavaScriptObject = null

# Inventory operation callbacks
var _inv_get_resolve_cb_js: JavaScriptObject = null
var _inv_get_reject_cb_js: JavaScriptObject = null
var _inv_add_resolve_cb_js: JavaScriptObject = null
var _inv_add_reject_cb_js: JavaScriptObject = null
var _inv_remove_resolve_cb_js: JavaScriptObject = null
var _inv_remove_reject_cb_js: JavaScriptObject = null

func _init(client_js_object: JavaScriptObject):
	_main_client = client_js_object

func me():
	if _main_client == null:
		printerr("[UsersAPI] Main client not set. Cannot call me().")
		emit_signal("profile_fetch_failed", "MAIN_CLIENT_NULL")
		return

	if not ('users' in _main_client and _main_client.users is JavaScriptObject and 'me' in _main_client.users):
		printerr("[UsersAPI] client.users.me() path not found on JavaScriptObject.")
		emit_signal("profile_fetch_failed", "METHOD_PATH_INVALID")
		return

	var promise = _main_client.users.me()

	if not promise is JavaScriptObject:
		printerr("[UsersAPI] _main_client.users.me() did not return a JavaScriptObject (expected Promise).")
		emit_signal("profile_fetch_failed", "NOT_A_PROMISE")
		return

	var on_resolve_cb = Callable(self, "_on_profile_resolved").bind()
	var on_reject_cb = Callable(self, "_on_profile_rejected").bind()

	# Store JS callbacks in member variables to keep them alive
	_resolve_cb_js = JavaScriptBridge.create_callback(on_resolve_cb)
	_reject_cb_js = JavaScriptBridge.create_callback(on_reject_cb)

	promise.then(_resolve_cb_js, _reject_cb_js)

func _on_profile_resolved(args: Array):
	if args.size() > 0:
		# Godot side (e.g., Main.gd) will handle this in a function connected to 'profile_received',
		emit_signal("profile_received", args[0])
	else:
		emit_signal("profile_fetch_failed", "PROFILE_RESOLVED_NO_DATA")

	# Optional: clear stored callbacks now that promise resolved
	_resolve_cb_js = null
	_reject_cb_js = null

func _on_profile_rejected(args: Array):
	printerr("[UsersAPI] Profile fetch failed: ", args[0] if args.size() > 0 else "Unknown error")
	var error_msg = "PROFILE_REJECTED_UNKNOWN"
	if args.size() > 0:
		error_msg = str(args[0])
	emit_signal("profile_fetch_failed", error_msg)

	# Clear stored callbacks
	_resolve_cb_js = null
	_reject_cb_js = null

# ═══════════════════════════════════════════════════════════════════
# Inventory Methods (nested under users.inventory.*)
# ═══════════════════════════════════════════════════════════════════

# Corresponds to client.users.inventory.get()
func inventory_get_all():
	if _main_client == null:
		printerr("[UsersAPI] Main client not set. Cannot call inventory_get_all().")
		emit_signal("inventory_get_all_failed", "MAIN_CLIENT_NULL")
		return

	if not ('users' in _main_client and 
			_main_client.users is JavaScriptObject and 
			'inventory' in _main_client.users and 
			_main_client.users.inventory is JavaScriptObject and 
			'get' in _main_client.users.inventory):
		printerr("[UsersAPI] client.users.inventory.get() path not found.")
		emit_signal("inventory_get_all_failed", "METHOD_PATH_INVALID")
		return

	var promise = _main_client.users.inventory.get()

	if not promise is JavaScriptObject:
		printerr("[UsersAPI] inventory.get() did not return a Promise.")
		emit_signal("inventory_get_all_failed", "NOT_A_PROMISE")
		return

	var on_resolve = Callable(self, "_on_inventory_get_resolved").bind()
	var on_reject = Callable(self, "_on_inventory_get_rejected").bind()

	_inv_get_resolve_cb_js = JavaScriptBridge.create_callback(on_resolve)
	_inv_get_reject_cb_js = JavaScriptBridge.create_callback(on_reject)

	promise.then(_inv_get_resolve_cb_js, _inv_get_reject_cb_js)

func _on_inventory_get_resolved(args: Array):
	if args.size() == 0:
		emit_signal("inventory_get_all_succeeded", [])
		_clear_inventory_get_callbacks()
		return

	var raw_inventory_data = args[0] 
	var normalized_inventory_data = []
	var inv_len = int(raw_inventory_data.length)

	for i in range(inv_len):
		var item_entry_js = raw_inventory_data[i]
		if item_entry_js == null:
			continue

		var item_data_dict = {}
		
		# Convert JavaScript item object to Dictionary
		var item_js = item_entry_js.item
		if item_js != null and item_js is JavaScriptObject:
			var item_dict = {}
			var item_properties = ["id", "slug", "displayName", "description", "type", "imageUrl", "metadata"]
			for prop in item_properties:
				if item_js.hasOwnProperty(prop):
					item_dict[prop] = item_js[prop]
			item_data_dict["item"] = item_dict
		else:
			item_data_dict["item"] = item_js

		var raw_quantity = item_entry_js.quantity
		var int_quantity = 0

		if raw_quantity != null:
			if typeof(raw_quantity) == TYPE_INT:
				int_quantity = int(raw_quantity)
			elif typeof(raw_quantity) == TYPE_FLOAT:
				int_quantity = int(raw_quantity)
			elif typeof(raw_quantity) == TYPE_STRING:
				if String(raw_quantity).is_valid_int():
					int_quantity = String(raw_quantity).to_int()
		
		item_data_dict["quantity"] = int_quantity
		normalized_inventory_data.append(item_data_dict)
			
	emit_signal("inventory_get_all_succeeded", normalized_inventory_data)
	_clear_inventory_get_callbacks()

func _on_inventory_get_rejected(args: Array):
	var error_msg = "FETCH_REJECTED_UNKNOWN"
	if args.size() > 0:
		error_msg = str(args[0])
	emit_signal("inventory_get_all_failed", error_msg)
	_clear_inventory_get_callbacks()

func _clear_inventory_get_callbacks():
	_inv_get_resolve_cb_js = null
	_inv_get_reject_cb_js = null

# Corresponds to client.users.inventory.add(itemId, qty)
func inventory_add(item_id: String, quantity: int = 1):
	if _main_client == null:
		printerr("[UsersAPI] Main client not set. Cannot call inventory_add().")
		emit_signal("inventory_add_failed", "MAIN_CLIENT_NULL")
		return
	
	if not ('users' in _main_client and 
			_main_client.users is JavaScriptObject and 
			'inventory' in _main_client.users and 
			_main_client.users.inventory is JavaScriptObject and 
			'add' in _main_client.users.inventory):
		printerr("[UsersAPI] client.users.inventory.add() path not found.")
		emit_signal("inventory_add_failed", "METHOD_PATH_INVALID")
		return

	var promise = _main_client.users.inventory.add(item_id, quantity)

	if not promise is JavaScriptObject:
		printerr("[UsersAPI] inventory.add() did not return a Promise.")
		emit_signal("inventory_add_failed", "NOT_A_PROMISE")
		return

	var on_resolve = Callable(self, "_on_inventory_add_resolved").bind()
	var on_reject = Callable(self, "_on_inventory_add_rejected").bind()

	_inv_add_resolve_cb_js = JavaScriptBridge.create_callback(on_resolve)
	_inv_add_reject_cb_js = JavaScriptBridge.create_callback(on_reject)

	promise.then(_inv_add_resolve_cb_js, _inv_add_reject_cb_js)

func _on_inventory_add_resolved(args: Array):
	var response_data = null
	if args.size() > 0:
		response_data = args[0]
	emit_signal("inventory_add_succeeded", response_data)
	emit_signal("inventory_changed", response_data)
	_clear_inventory_add_callbacks()

func _on_inventory_add_rejected(args: Array):
	var error_msg = "ADD_REJECTED_UNKNOWN"
	if args.size() > 0:
		error_msg = str(args[0])
	emit_signal("inventory_add_failed", error_msg)
	_clear_inventory_add_callbacks()

func _clear_inventory_add_callbacks():
	_inv_add_resolve_cb_js = null
	_inv_add_reject_cb_js = null

# Corresponds to client.users.inventory.remove(itemId, qty)
func inventory_remove(item_id: String, quantity: int = 1):
	if _main_client == null:
		printerr("[UsersAPI] Main client not set. Cannot call inventory_remove().")
		emit_signal("inventory_remove_failed", "MAIN_CLIENT_NULL")
		return

	if not ('users' in _main_client and 
			_main_client.users is JavaScriptObject and 
			'inventory' in _main_client.users and 
			_main_client.users.inventory is JavaScriptObject and 
			'remove' in _main_client.users.inventory):
		printerr("[UsersAPI] client.users.inventory.remove() path not found.")
		emit_signal("inventory_remove_failed", "METHOD_PATH_INVALID")
		return

	var promise = _main_client.users.inventory.remove(item_id, quantity)

	if not promise is JavaScriptObject:
		printerr("[UsersAPI] inventory.remove() did not return a Promise.")
		emit_signal("inventory_remove_failed", "NOT_A_PROMISE")
		return

	var on_resolve = Callable(self, "_on_inventory_remove_resolved").bind()
	var on_reject = Callable(self, "_on_inventory_remove_rejected").bind()

	_inv_remove_resolve_cb_js = JavaScriptBridge.create_callback(on_resolve)
	_inv_remove_reject_cb_js = JavaScriptBridge.create_callback(on_reject)

	promise.then(_inv_remove_resolve_cb_js, _inv_remove_reject_cb_js)

func _on_inventory_remove_resolved(args: Array):
	var response_data = null
	if args.size() > 0:
		response_data = args[0]
	emit_signal("inventory_remove_succeeded", response_data)
	emit_signal("inventory_changed", response_data)
	_clear_inventory_remove_callbacks()

func _on_inventory_remove_rejected(args: Array):
	var error_msg = "REMOVE_REJECTED_UNKNOWN"
	if args.size() > 0:
		error_msg = str(args[0])
	emit_signal("inventory_remove_failed", error_msg)
	_clear_inventory_remove_callbacks()

func _clear_inventory_remove_callbacks():
	_inv_remove_resolve_cb_js = null
	_inv_remove_reject_cb_js = null