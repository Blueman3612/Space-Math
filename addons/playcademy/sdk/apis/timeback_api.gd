class_name TimebackAPI extends RefCounted

# Signals for recordProgress operation
signal record_progress_succeeded(response_data)
signal record_progress_failed(error_message)

# Signals for recordSessionEnd operation
signal record_session_end_succeeded(response_data)
signal record_session_end_failed(error_message)

# Signals for awardXP operation
signal award_xp_succeeded(response_data)
signal award_xp_failed(error_message)

var _main_client: JavaScriptObject

# To keep JS callbacks alive for ongoing operations
var _record_progress_resolve_cb_js: JavaScriptObject = null
var _record_progress_reject_cb_js: JavaScriptObject = null
var _record_session_end_resolve_cb_js: JavaScriptObject = null
var _record_session_end_reject_cb_js: JavaScriptObject = null
var _award_xp_resolve_cb_js: JavaScriptObject = null
var _award_xp_reject_cb_js: JavaScriptObject = null

func _init(client_js_object: JavaScriptObject):
	_main_client = client_js_object
	print("[TimebackAPI] Initialized with client.")

# Corresponds to client.timeback.recordProgress(progressData)
func record_progress(progress_data: Dictionary):
	if _main_client == null:
		printerr("[TimebackAPI] Main client not set. Cannot call record_progress().")
		emit_signal("record_progress_failed", "MAIN_CLIENT_NULL")
		return

	if not ('timeback' in _main_client and 
			_main_client.timeback is JavaScriptObject and 
			'recordProgress' in _main_client.timeback):
		printerr("[TimebackAPI] client.timeback.recordProgress() path not found.")
		emit_signal("record_progress_failed", "METHOD_PATH_INVALID")
		return

	print("[TimebackAPI] Calling _main_client.timeback.recordProgress()...")
	
	var js_progress_data = JavaScriptBridge.create_object("Object")
	for key in progress_data:
		js_progress_data[key] = progress_data[key]
	var promise = _main_client.timeback.recordProgress(js_progress_data)

	if not promise is JavaScriptObject:
		printerr("[TimebackAPI] timeback.recordProgress() did not return a Promise.")
		emit_signal("record_progress_failed", "NOT_A_PROMISE")
		return

	var on_resolve = Callable(self, "_on_record_progress_resolved").bind()
	var on_reject = Callable(self, "_on_record_progress_rejected").bind()

	_record_progress_resolve_cb_js = JavaScriptBridge.create_callback(on_resolve)
	_record_progress_reject_cb_js = JavaScriptBridge.create_callback(on_reject)

	promise.then(_record_progress_resolve_cb_js, _record_progress_reject_cb_js)
	print("[TimebackAPI] .then() called on timeback.recordProgress() promise.")

func _on_record_progress_resolved(args: Array):
	print("[TimebackAPI] Record progress promise resolved. Args: ", args)
	if args.size() > 0:
		var result_data = args[0]
		emit_signal("record_progress_succeeded", result_data)
	else:
		emit_signal("record_progress_failed", "RECORD_PROGRESS_RESOLVED_NO_DATA")
	_clear_record_progress_callbacks()

func _on_record_progress_rejected(args: Array):
	print("[TimebackAPI] Record progress promise rejected. Args: ", args)
	var error_message = "RECORD_PROGRESS_PROMISE_REJECTED"
	if args.size() > 0:
		error_message = str(args[0])
	emit_signal("record_progress_failed", error_message)
	_clear_record_progress_callbacks()

func _clear_record_progress_callbacks():
	_record_progress_resolve_cb_js = null
	_record_progress_reject_cb_js = null

# Corresponds to client.timeback.recordSessionEnd(sessionData)
func record_session_end(session_data: Dictionary):
	if _main_client == null:
		printerr("[TimebackAPI] Main client not set. Cannot call record_session_end().")
		emit_signal("record_session_end_failed", "MAIN_CLIENT_NULL")
		return

	if not ('timeback' in _main_client and 
			_main_client.timeback is JavaScriptObject and 
			'recordSessionEnd' in _main_client.timeback):
		printerr("[TimebackAPI] client.timeback.recordSessionEnd() path not found.")
		emit_signal("record_session_end_failed", "METHOD_PATH_INVALID")
		return

	print("[TimebackAPI] Calling _main_client.timeback.recordSessionEnd()...")
	
	var js_session_data = JavaScriptBridge.create_object("Object")
	for key in session_data:
		js_session_data[key] = session_data[key]
	var promise = _main_client.timeback.recordSessionEnd(js_session_data)

	if not promise is JavaScriptObject:
		printerr("[TimebackAPI] timeback.recordSessionEnd() did not return a Promise.")
		emit_signal("record_session_end_failed", "NOT_A_PROMISE")
		return

	var on_resolve = Callable(self, "_on_record_session_end_resolved").bind()
	var on_reject = Callable(self, "_on_record_session_end_rejected").bind()

	_record_session_end_resolve_cb_js = JavaScriptBridge.create_callback(on_resolve)
	_record_session_end_reject_cb_js = JavaScriptBridge.create_callback(on_reject)

	promise.then(_record_session_end_resolve_cb_js, _record_session_end_reject_cb_js)
	print("[TimebackAPI] .then() called on timeback.recordSessionEnd() promise.")

func _on_record_session_end_resolved(args: Array):
	print("[TimebackAPI] Record session end promise resolved. Args: ", args)
	if args.size() > 0:
		var result_data = args[0]
		emit_signal("record_session_end_succeeded", result_data)
	else:
		emit_signal("record_session_end_failed", "RECORD_SESSION_END_RESOLVED_NO_DATA")
	_clear_record_session_end_callbacks()

func _on_record_session_end_rejected(args: Array):
	print("[TimebackAPI] Record session end promise rejected. Args: ", args)
	var error_message = "RECORD_SESSION_END_PROMISE_REJECTED"
	if args.size() > 0:
		error_message = str(args[0])
	emit_signal("record_session_end_failed", error_message)
	_clear_record_session_end_callbacks()

func _clear_record_session_end_callbacks():
	_record_session_end_resolve_cb_js = null
	_record_session_end_reject_cb_js = null

# Corresponds to client.timeback.awardXP(xpAmount, metadata)
func award_xp(xp_amount: int, metadata: Dictionary):
	if _main_client == null:
		printerr("[TimebackAPI] Main client not set. Cannot call award_xp().")
		emit_signal("award_xp_failed", "MAIN_CLIENT_NULL")
		return

	if not ('timeback' in _main_client and 
			_main_client.timeback is JavaScriptObject and 
			'awardXP' in _main_client.timeback):
		printerr("[TimebackAPI] client.timeback.awardXP() path not found.")
		emit_signal("award_xp_failed", "METHOD_PATH_INVALID")
		return

	print("[TimebackAPI] Calling _main_client.timeback.awardXP(%d)..." % xp_amount)
	
	var js_metadata = JavaScriptBridge.create_object("Object")
	for key in metadata:
		js_metadata[key] = metadata[key]
	var promise = _main_client.timeback.awardXP(xp_amount, js_metadata)

	if not promise is JavaScriptObject:
		printerr("[TimebackAPI] timeback.awardXP() did not return a Promise.")
		emit_signal("award_xp_failed", "NOT_A_PROMISE")
		return

	var on_resolve = Callable(self, "_on_award_xp_resolved").bind()
	var on_reject = Callable(self, "_on_award_xp_rejected").bind()

	_award_xp_resolve_cb_js = JavaScriptBridge.create_callback(on_resolve)
	_award_xp_reject_cb_js = JavaScriptBridge.create_callback(on_reject)

	promise.then(_award_xp_resolve_cb_js, _award_xp_reject_cb_js)
	print("[TimebackAPI] .then() called on timeback.awardXP() promise.")

func _on_award_xp_resolved(args: Array):
	print("[TimebackAPI] Award XP promise resolved. Args: ", args)
	if args.size() > 0:
		var result_data = args[0]
		emit_signal("award_xp_succeeded", result_data)
	else:
		emit_signal("award_xp_failed", "AWARD_XP_RESOLVED_NO_DATA")
	_clear_award_xp_callbacks()

func _on_award_xp_rejected(args: Array):
	print("[TimebackAPI] Award XP promise rejected. Args: ", args)
	var error_message = "AWARD_XP_PROMISE_REJECTED"
	if args.size() > 0:
		error_message = str(args[0])
	emit_signal("award_xp_failed", error_message)
	_clear_award_xp_callbacks()

func _clear_award_xp_callbacks():
	_award_xp_resolve_cb_js = null
	_award_xp_reject_cb_js = null

