class_name BackendAPI extends RefCounted

# Generic signal for backend requests
signal request_succeeded(response_data)
signal request_failed(error_message)

var _main_client: JavaScriptObject

# To keep JS callbacks alive for ongoing operations
var _request_resolve_cb_js: JavaScriptObject = null
var _request_reject_cb_js: JavaScriptObject = null

func _init(client_js_object: JavaScriptObject):
	_main_client = client_js_object

# --- Helpers ---------------------------------------------------------------
# Convert a GDScript value (Dictionary/Array/scalars) into a plain JavaScript
# object/array recursively so it can be safely consumed by browser JS APIs.
func _to_js_value(value):
	var t := typeof(value)
	match t:
		TYPE_DICTIONARY:
			var js_obj: JavaScriptObject = JavaScriptBridge.create_object("Object")
			for key in value.keys():
				var js_key := str(key)
				js_obj[js_key] = _to_js_value(value[key])
			return js_obj
		TYPE_ARRAY:
			var js_arr: JavaScriptObject = JavaScriptBridge.create_object("Array")
			for item in value:
				# Push by calling JS Array.prototype.push
				js_arr.push(_to_js_value(item))
			return js_arr
		TYPE_NIL, TYPE_BOOL, TYPE_INT, TYPE_FLOAT, TYPE_STRING:
			return value
		_:
			# Fallback – stringify unknown Godot types
			return str(value)

# Call any custom game backend route
# Example: backend.request("/custom-route", "POST", {"data": "value"})
func request(path: String, method: String = "GET", body: Dictionary = {}):
	if _main_client == null:
		printerr("[BackendAPI] Main client not set. Cannot call request().")
		emit_signal("request_failed", "MAIN_CLIENT_NULL")
		return

	if not ('backend' in _main_client and 
			_main_client.backend is JavaScriptObject and 
			'request' in _main_client.backend):
		printerr("[BackendAPI] client.backend.request() path not found.")
		emit_signal("request_failed", "METHOD_PATH_INVALID")
		return
	
	var promise
	if body.is_empty():
		promise = _main_client.backend.request(path, method)
	else:
		# Recursively convert GDScript Dictionary/Array tree into a plain JS object
		var js_body = _to_js_value(body)
		promise = _main_client.backend.request(path, method, js_body)

	if not promise is JavaScriptObject:
		printerr("[BackendAPI] backend.request() did not return a Promise.")
		emit_signal("request_failed", "NOT_A_PROMISE")
		return

	var on_resolve = Callable(self, "_on_request_resolved").bind()
	var on_reject = Callable(self, "_on_request_rejected").bind()

	_request_resolve_cb_js = JavaScriptBridge.create_callback(on_resolve)
	_request_reject_cb_js = JavaScriptBridge.create_callback(on_reject)

	promise.then(_request_resolve_cb_js, _request_reject_cb_js)

func _on_request_resolved(args: Array):
	if args.size() > 0:
		var result_data = args[0]
		
		# Convert JavaScriptObject response to GDScript Dictionary
		# This ensures proper handling of nested objects and avoids JavaScriptObject issues
		if typeof(result_data) == TYPE_OBJECT:
			# Get window object and store the response temporarily
			var window = JavaScriptBridge.get_interface("window")
			window._gdscript_temp_response = result_data
			
			# Stringify the stored object
			var json_str = JavaScriptBridge.eval("JSON.stringify(window._gdscript_temp_response)", true)
			
			# Clean up
			JavaScriptBridge.eval("delete window._gdscript_temp_response", true)
			
			# Convert JS string to GDScript string and parse
			var gdscript_json = str(json_str)
			var parsed_result = JSON.parse_string(gdscript_json)
			if parsed_result != null:
				result_data = parsed_result
			else:
				printerr("[BackendAPI] Failed to parse response JSON")
		
		emit_signal("request_succeeded", result_data)
	else:
		emit_signal("request_failed", "REQUEST_RESOLVED_NO_DATA")
	_clear_request_callbacks()

func _on_request_rejected(args: Array):
	printerr("[BackendAPI] Request failed: ", args[0] if args.size() > 0 else "Unknown error")
	var error_message = "REQUEST_PROMISE_REJECTED"
	if args.size() > 0:
		error_message = str(args[0])
	emit_signal("request_failed", error_message)
	_clear_request_callbacks()

func _clear_request_callbacks():
	_request_resolve_cb_js = null
	_request_reject_cb_js = null
