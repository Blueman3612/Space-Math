class_name TimebackAPI extends RefCounted

# Signals for activity operations
signal end_activity_succeeded(response_data)
signal end_activity_failed(error_message)
signal pause_activity_failed(error_message)
signal resume_activity_failed(error_message)

var _main_client: JavaScriptObject

# To keep JS callbacks alive for ongoing operations
var _end_activity_resolve_cb_js: JavaScriptObject = null
var _end_activity_reject_cb_js: JavaScriptObject = null

# Internal state for tracking current activity
var _activity_start_time: int = 0
var _activity_metadata: Dictionary = {}
var _activity_in_progress: bool = false

func _init(client_js_object: JavaScriptObject):
	_main_client = client_js_object

# Start tracking an activity
func start_activity(metadata: Dictionary):
	if _main_client == null:
		printerr("[TimebackAPI] Main client not set. Cannot call start_activity().")
		return
	
	if not ('timeback' in _main_client and 
			_main_client.timeback is JavaScriptObject and 
			'startActivity' in _main_client.timeback):
		printerr("[TimebackAPI] client.timeback.startActivity() path not found.")
		return
	
	# Build metadata object for JavaScript
	var js_metadata = JavaScriptBridge.create_object("Object")
	js_metadata["activityId"] = metadata.get("activityId", "unknown")
	
	# Call JavaScript SDK's startActivity
	_main_client.timeback.startActivity(js_metadata)
	
	_activity_start_time = Time.get_ticks_msec()
	_activity_metadata = metadata.duplicate()
	_activity_in_progress = true
	print("[TimebackAPI] Started activity: ", _activity_metadata.get("activityId", "unknown"))

# Pause the current activity timer
# Paused time is not counted toward the activity duration
func pause_activity():
	if not _activity_in_progress:
		printerr("[TimebackAPI] No activity in progress. Call start_activity() first.")
		emit_signal("pause_activity_failed", "NO_ACTIVITY_IN_PROGRESS")
		return
	
	if _main_client == null:
		printerr("[TimebackAPI] Main client not set. Cannot call pause_activity().")
		emit_signal("pause_activity_failed", "MAIN_CLIENT_NULL")
		return
	
	if not ('timeback' in _main_client and 
			_main_client.timeback is JavaScriptObject and 
			'pauseActivity' in _main_client.timeback):
		printerr("[TimebackAPI] client.timeback.pauseActivity() path not found.")
		emit_signal("pause_activity_failed", "METHOD_PATH_INVALID")
		return
	
	# Call JavaScript SDK's pauseActivity
	_main_client.timeback.pauseActivity()
	print("[TimebackAPI] Activity paused")

# Resume the current activity timer after a pause
func resume_activity():
	if not _activity_in_progress:
		printerr("[TimebackAPI] No activity in progress. Call start_activity() first.")
		emit_signal("resume_activity_failed", "NO_ACTIVITY_IN_PROGRESS")
		return
	
	if _main_client == null:
		printerr("[TimebackAPI] Main client not set. Cannot call resume_activity().")
		emit_signal("resume_activity_failed", "MAIN_CLIENT_NULL")
		return
	
	if not ('timeback' in _main_client and 
			_main_client.timeback is JavaScriptObject and 
			'resumeActivity' in _main_client.timeback):
		printerr("[TimebackAPI] client.timeback.resumeActivity() path not found.")
		emit_signal("resume_activity_failed", "METHOD_PATH_INVALID")
		return
	
	# Call JavaScript SDK's resumeActivity
	_main_client.timeback.resumeActivity()
	print("[TimebackAPI] Activity resumed")

# End the current activity and submit results
# XP is calculated server-side with attempt-aware multipliers
# score_data should contain: { correctQuestions: int, totalQuestions: int, xpAwarded: int (optional) }
func end_activity(score_data: Dictionary):
	if not _activity_in_progress:
		printerr("[TimebackAPI] No activity in progress. Call start_activity() first.")
		emit_signal("end_activity_failed", "NO_ACTIVITY_IN_PROGRESS")
		return
	
	if _main_client == null:
		printerr("[TimebackAPI] Main client not set. Cannot call end_activity().")
		emit_signal("end_activity_failed", "MAIN_CLIENT_NULL")
		_activity_in_progress = false
		return

	if not ('timeback' in _main_client and 
			_main_client.timeback is JavaScriptObject and 
			'endActivity' in _main_client.timeback):
		printerr("[TimebackAPI] client.timeback.endActivity() path not found.")
		emit_signal("end_activity_failed", "METHOD_PATH_INVALID")
		_activity_in_progress = false
		return

	var correct_questions = score_data.get("correctQuestions", 0)
	var total_questions = score_data.get("totalQuestions", 1)
	var xp_awarded = score_data.get("xpAwarded", null)
	
	var score_percentage = (float(correct_questions) / float(total_questions) * 100.0) if total_questions > 0 else 0.0
	
	print("[TimebackAPI] Ending activity: %.1f%% (%d/%d)%s" % [
		score_percentage, 
		correct_questions, 
		total_questions,
		(" - XP Override: %d" % xp_awarded) if xp_awarded != null else ""
	])
	
	# Build score data object for JavaScript (matching browser SDK API)
	var js_score_data = JavaScriptBridge.create_object("Object")
	js_score_data["correctQuestions"] = correct_questions
	js_score_data["totalQuestions"] = total_questions
	
	# Add optional XP override
	if xp_awarded != null:
		js_score_data["xpAwarded"] = xp_awarded
	
	var promise = _main_client.timeback.endActivity(js_score_data)

	if promise == null:
		printerr("[TimebackAPI] timeback.endActivity() returned null.")
		emit_signal("end_activity_failed", "NULL_RETURN")
		_activity_in_progress = false
		return
	
	if not promise is JavaScriptObject:
		printerr("[TimebackAPI] timeback.endActivity() did not return a Promise (returned: ", typeof(promise), ")")
		emit_signal("end_activity_failed", "NOT_A_PROMISE")
		_activity_in_progress = false
		return

	var on_resolve = Callable(self, "_on_end_activity_resolved").bind()
	var on_reject = Callable(self, "_on_end_activity_rejected").bind()

	_end_activity_resolve_cb_js = JavaScriptBridge.create_callback(on_resolve)
	_end_activity_reject_cb_js = JavaScriptBridge.create_callback(on_reject)

	promise.then(_end_activity_resolve_cb_js, _end_activity_reject_cb_js)

func _on_end_activity_resolved(args: Array):
	_activity_in_progress = false
	if args.size() > 0:
		var result_data = args[0]
		emit_signal("end_activity_succeeded", result_data)
	else:
		emit_signal("end_activity_failed", "END_ACTIVITY_RESOLVED_NO_DATA")
	_clear_end_activity_callbacks()

func _on_end_activity_rejected(args: Array):
	_activity_in_progress = false
	var error_message = "END_ACTIVITY_PROMISE_REJECTED"
	
	if args.size() > 0:
		var error_obj = args[0]
		# Try to extract meaningful error information from JavaScript Error object
		if error_obj is JavaScriptObject:
			# Try to get error.message, error.toString(), or JSON.stringify(error)
			var error_str = ""
			
			# Try error.message first (standard for Error objects)
			if "message" in error_obj:
				error_str = str(error_obj.message)
			
			# Try error.toString() as fallback
			if error_str.is_empty() and "toString" in error_obj:
				var to_string_result = error_obj.toString()
				if to_string_result != null:
					error_str = str(to_string_result)
			
			# If we got something useful, use it
			if not error_str.is_empty():
				error_message = error_str
				printerr("[TimebackAPI] End activity failed: ", error_str)
			else:
				# Last resort: try to access common error properties
				var error_parts = []
				if "name" in error_obj:
					error_parts.append("name: " + str(error_obj.name))
				if "code" in error_obj:
					error_parts.append("code: " + str(error_obj.code))
				if "status" in error_obj:
					error_parts.append("status: " + str(error_obj.status))
				
				if error_parts.size() > 0:
					error_message = ", ".join(error_parts)
					printerr("[TimebackAPI] End activity failed: ", error_message)
				else:
					printerr("[TimebackAPI] End activity failed with unknown JavaScript error (unable to extract message)")
		else:
			# Not a JavaScript object, just convert to string
			error_message = str(error_obj)
			printerr("[TimebackAPI] End activity failed: ", error_message)
	else:
		printerr("[TimebackAPI] End activity failed: Unknown error (no error details provided)")
	
	emit_signal("end_activity_failed", error_message)
	_clear_end_activity_callbacks()

func _clear_end_activity_callbacks():
	_end_activity_resolve_cb_js = null
	_end_activity_reject_cb_js = null
