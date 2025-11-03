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
		var js_body = JavaScriptBridge.create_object("Object")
		for key in body:
			js_body[key] = body[key]
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
