class_name ScoresAPI extends RefCounted

# Signals for submit operation
signal submit_succeeded(score_data)
signal submit_failed(error_message)

# Signals for getByUser operation
signal get_by_user_succeeded(scores_data)
signal get_by_user_failed(error_message)

var _main_client: JavaScriptObject

# To keep JS callbacks alive for ongoing operations
var _submit_resolve_cb_js: JavaScriptObject = null
var _submit_reject_cb_js: JavaScriptObject = null
var _get_by_user_resolve_cb_js: JavaScriptObject = null
var _get_by_user_reject_cb_js: JavaScriptObject = null

func _init(client_js_object: JavaScriptObject):
	_main_client = client_js_object

# Corresponds to client.scores.submit(gameId, score, metadata?) - gameId auto-injected
func submit(score: int, metadata: Dictionary = {}):
	if _main_client == null:
		printerr("[ScoresAPI] Main client not set. Cannot call submit().")
		emit_signal("submit_failed", "MAIN_CLIENT_NULL")
		return

	if not ('scores' in _main_client and 
			_main_client.scores is JavaScriptObject and 
			'submit' in _main_client.scores):
		printerr("[ScoresAPI] client.scores.submit() path not found.")
		emit_signal("submit_failed", "METHOD_PATH_INVALID")
		return

	# Get gameId from client context
	var game_id = _main_client['gameId']
	if game_id == null:
		printerr("[ScoresAPI] No gameId found in client context.")
		emit_signal("submit_failed", "NO_GAME_ID_CONTEXT")
		return

	var promise
	if metadata.is_empty():
		promise = _main_client.scores.submit(game_id, score)
	else:
		# Convert Godot Dictionary to JavaScript object
		var js_metadata = JavaScriptBridge.create_object("Object")
		for key in metadata:
			js_metadata[key] = metadata[key]
		promise = _main_client.scores.submit(game_id, score, js_metadata)

	if not promise is JavaScriptObject:
		printerr("[ScoresAPI] scores.submit() did not return a Promise.")
		emit_signal("submit_failed", "NOT_A_PROMISE")
		return

	var on_resolve = Callable(self, "_on_submit_resolved").bind()
	var on_reject = Callable(self, "_on_submit_rejected").bind()

	_submit_resolve_cb_js = JavaScriptBridge.create_callback(on_resolve)
	_submit_reject_cb_js = JavaScriptBridge.create_callback(on_reject)

	promise.then(_submit_resolve_cb_js, _submit_reject_cb_js)

func _on_submit_resolved(args: Array):
	if args.size() > 0:
		var result_data = args[0]
		emit_signal("submit_succeeded", result_data)
	else:
		emit_signal("submit_failed", "SUBMIT_RESOLVED_NO_DATA")
	_clear_submit_callbacks()

func _on_submit_rejected(args: Array):
	printerr("[ScoresAPI] Submit failed: ", args[0] if args.size() > 0 else "Unknown error")
	var error_message = "SUBMIT_PROMISE_REJECTED"
	if args.size() > 0:
		error_message = str(args[0])
	emit_signal("submit_failed", error_message)
	_clear_submit_callbacks()

func _clear_submit_callbacks():
	_submit_resolve_cb_js = null
	_submit_reject_cb_js = null

# Corresponds to client.scores.getByUser(gameId, userId, options?) - gameId auto-injected
func get_by_user(user_id: String, options: Dictionary = {}):
	if _main_client == null:
		printerr("[ScoresAPI] Main client not set. Cannot call get_by_user().")
		emit_signal("get_by_user_failed", "MAIN_CLIENT_NULL")
		return

	if not ('scores' in _main_client and 
			_main_client.scores is JavaScriptObject and 
			'getByUser' in _main_client.scores):
		printerr("[ScoresAPI] client.scores.getByUser() path not found.")
		emit_signal("get_by_user_failed", "METHOD_PATH_INVALID")
		return

	# Get gameId from client context
	var game_id = _main_client['gameId']
	if game_id == null:
		printerr("[ScoresAPI] No gameId found in client context.")
		emit_signal("get_by_user_failed", "NO_GAME_ID_CONTEXT")
		return

	var promise
	if options.is_empty():
		promise = _main_client.scores.getByUser(game_id, user_id)
	else:
		# Convert Godot Dictionary to JavaScript object
		var js_options = JavaScriptBridge.create_object("Object")
		for key in options:
			js_options[key] = options[key]
		promise = _main_client.scores.getByUser(game_id, user_id, js_options)

	if not promise is JavaScriptObject:
		printerr("[ScoresAPI] scores.getByUser() did not return a Promise.")
		emit_signal("get_by_user_failed", "NOT_A_PROMISE")
		return

	var on_resolve = Callable(self, "_on_get_by_user_resolved").bind()
	var on_reject = Callable(self, "_on_get_by_user_rejected").bind()

	_get_by_user_resolve_cb_js = JavaScriptBridge.create_callback(on_resolve)
	_get_by_user_reject_cb_js = JavaScriptBridge.create_callback(on_reject)

	promise.then(_get_by_user_resolve_cb_js, _get_by_user_reject_cb_js)

func _on_get_by_user_resolved(args: Array):
	if args.size() > 0:
		var result_data = args[0]
		emit_signal("get_by_user_succeeded", result_data)
	else:
		emit_signal("get_by_user_failed", "GET_BY_USER_RESOLVED_NO_DATA")
	_clear_get_by_user_callbacks()

func _on_get_by_user_rejected(args: Array):
	printerr("[ScoresAPI] Get by user failed: ", args[0] if args.size() > 0 else "Unknown error")
	var error_message = "GET_BY_USER_PROMISE_REJECTED"
	if args.size() > 0:
		error_message = str(args[0])
	emit_signal("get_by_user_failed", error_message)
	_clear_get_by_user_callbacks()

func _clear_get_by_user_callbacks():
	_get_by_user_resolve_cb_js = null
	_get_by_user_reject_cb_js = null
