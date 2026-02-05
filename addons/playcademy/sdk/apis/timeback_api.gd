class_name TimebackAPI extends RefCounted

# Signals for activity operations
signal end_activity_succeeded(response_data)
signal end_activity_failed(error_message)
signal pause_activity_failed(error_message)
signal resume_activity_failed(error_message)

# Signals for user operations
signal user_fetch_succeeded(user_data: Dictionary)
signal user_fetch_failed(error_message: String)

# Signals for XP operations
signal xp_fetch_succeeded(xp_data: Dictionary)
signal xp_fetch_failed(error_message: String)

var _main_client: JavaScriptObject

# To keep JS callbacks alive for ongoing operations
var _end_activity_resolve_cb_js: JavaScriptObject = null
var _end_activity_reject_cb_js: JavaScriptObject = null
var _user_fetch_resolve_cb_js: JavaScriptObject = null
var _user_fetch_reject_cb_js: JavaScriptObject = null
var _xp_fetch_resolve_cb_js: JavaScriptObject = null
var _xp_fetch_reject_cb_js: JavaScriptObject = null

# Internal state for tracking current activity
var _activity_start_time: int = 0
var _activity_metadata: Dictionary = {}
var _activity_in_progress: bool = false

# User context object
var _user: TimebackUser

# XP cache state (5 second TTL)
const XP_CACHE_TTL_MS: int = 5000
var _xp_cache: Dictionary = {}  # { cache_key: { "data": Dictionary, "timestamp": int } }

func _init(client_js_object: JavaScriptObject):
	_main_client = client_js_object
	_user = TimebackUser.new(self)

# ============================================================================
# USER PROPERTY
# ============================================================================
# Access TimeBack user data via Playcademy.timeback.user
# Matches TypeScript SDK's client.timeback.user structure
#
# Properties:
#   - user.id: String - TimeBack user ID
#   - user.role: String - student, parent, teacher, administrator
#   - user.enrollments: Array - [{ subject, grade, courseId }]
#   - user.organizations: Array - [{ id, name, type }]
#   - user.xp: TimebackUserXp - XP data accessor
#
# Methods:
#   - user.fetch() - Fetch fresh data from server (emits user_fetch_succeeded/failed)
#   - user.xp.fetch() - Fetch XP data from server (emits xp_fetch_succeeded/failed)
# ============================================================================
var user: TimebackUser:
	get:
		return _user

# ============================================================================
# DEPRECATED: Direct role/enrollments access
# Use user.role and user.enrollments instead
# ============================================================================

## @deprecated Use user.role instead
var role: String:
	get:
		return _user.role

## @deprecated Use user.enrollments instead
var enrollments: Array:
	get:
		return _user.enrollments

# ============================================================================
# ACTIVITY TRACKING
# ============================================================================

# Start tracking an activity
# metadata should contain:
#   - activityId: String (required) - unique identifier for the activity
#   - grade: int (required) - grade level for multi-grade course routing
#   - subject: String (required) - subject area (e.g., "FastMath", "Reading")
#   - activityName: String (optional) - display name for the activity
#   - courseId: String (optional) - course identifier
#   - courseName: String (optional) - course display name
func start_activity(metadata: Dictionary):
	if _main_client == null:
		printerr("[TimebackAPI] Main client not set. Cannot call start_activity().")
		return
	
	if not ('timeback' in _main_client and 
			_main_client.timeback is JavaScriptObject and 
			'startActivity' in _main_client.timeback):
		printerr("[TimebackAPI] client.timeback.startActivity() path not found.")
		return
	
	# Validate required fields
	if not metadata.has("activityId"):
		printerr("[TimebackAPI] start_activity() requires 'activityId' in metadata.")
		return
	if not metadata.has("grade"):
		printerr("[TimebackAPI] start_activity() requires 'grade' in metadata.")
		return
	if not metadata.has("subject"):
		printerr("[TimebackAPI] start_activity() requires 'subject' in metadata.")
		return
	
	# Build metadata object for JavaScript
	var js_metadata = JavaScriptBridge.create_object("Object")
	
	# Required fields
	js_metadata["activityId"] = metadata.get("activityId")
	js_metadata["grade"] = int(metadata.get("grade"))
	js_metadata["subject"] = metadata.get("subject")
	
	# Optional fields - only set if provided
	if metadata.has("activityName"):
		js_metadata["activityName"] = metadata.get("activityName")
	if metadata.has("courseId"):
		js_metadata["courseId"] = metadata.get("courseId")
	if metadata.has("courseName"):
		js_metadata["courseName"] = metadata.get("courseName")
	
	# Call JavaScript SDK's startActivity
	_main_client.timeback.startActivity(js_metadata)
	
	_activity_start_time = Time.get_ticks_msec()
	_activity_metadata = metadata.duplicate()
	_activity_in_progress = true
	print("[TimebackAPI] Started activity: ", _activity_metadata.get("activityId", "unknown"), " (Grade ", metadata.get("grade"), ", ", metadata.get("subject"), ")")

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
# score_data should contain: { correctQuestions: int, totalQuestions: int, xpAwarded: float (optional), masteredUnits: int (optional) }
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
	var mastered_units = score_data.get("masteredUnits", null)
	
	var score_percentage = (float(correct_questions) / float(total_questions) * 100.0) if total_questions > 0 else 0.0
	
	var log_parts = ["[TimebackAPI] Ending activity: %.1f%% (%d/%d)" % [score_percentage, correct_questions, total_questions]]
	if xp_awarded != null:
		log_parts.append(" - XP Override: %.2f" % xp_awarded)
	if mastered_units != null:
		log_parts.append(" - Mastered Units: %d" % mastered_units)
	print("".join(log_parts))
	
	# Build score data object for JavaScript (matching browser SDK API)
	var js_score_data = JavaScriptBridge.create_object("Object")
	js_score_data["correctQuestions"] = correct_questions
	js_score_data["totalQuestions"] = total_questions
	
	# Add optional XP override
	if xp_awarded != null:
		js_score_data["xpAwarded"] = xp_awarded
	
	# Add optional mastered units
	if mastered_units != null:
		js_score_data["masteredUnits"] = mastered_units
	
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

# ============================================================================
# USER FETCH CALLBACKS
# ============================================================================

func _on_user_fetch_resolved(args: Array):
	if args.size() > 0:
		var result = args[0]
		var user_data = {}
		
		if result is JavaScriptObject:
			user_data["id"] = str(result.id) if 'id' in result and result.id != null else ""
			user_data["role"] = str(result.role) if 'role' in result and result.role != null else "student"
			user_data["enrollments"] = _convert_js_array_to_enrollments(result.enrollments if 'enrollments' in result else null)
			user_data["organizations"] = _convert_js_array_to_organizations(result.organizations if 'organizations' in result else null)
		
		emit_signal("user_fetch_succeeded", user_data)
	else:
		emit_signal("user_fetch_failed", "USER_FETCH_RESOLVED_NO_DATA")
	_clear_user_fetch_callbacks()

func _on_user_fetch_rejected(args: Array):
	var error_message = "USER_FETCH_PROMISE_REJECTED"
	
	if args.size() > 0:
		var error_obj = args[0]
		if error_obj is JavaScriptObject and "message" in error_obj:
			error_message = str(error_obj.message)
		else:
			error_message = str(error_obj)
		printerr("[TimebackAPI] User fetch failed: ", error_message)
	else:
		printerr("[TimebackAPI] User fetch failed: Unknown error")
	
	emit_signal("user_fetch_failed", error_message)
	_clear_user_fetch_callbacks()

func _clear_user_fetch_callbacks():
	_user_fetch_resolve_cb_js = null
	_user_fetch_reject_cb_js = null

# ============================================================================
# XP FETCH CALLBACKS
# ============================================================================

func _on_xp_fetch_resolved_with_cache(args: Array, cache_key: String):
	if args.size() > 0:
		var result = args[0]
		if result == null or not result is JavaScriptObject:
			emit_signal("xp_fetch_failed", "INVALID_XP_RESPONSE")
			_clear_xp_fetch_callbacks()
			return
		var xp_data = _convert_js_xp_response(result)
		var emit_xp_data = xp_data.duplicate(true)
		if not cache_key.is_empty():
			_set_cached_xp(cache_key, xp_data)
		emit_signal("xp_fetch_succeeded", emit_xp_data)
	else:
		emit_signal("xp_fetch_failed", "XP_FETCH_RESOLVED_NO_DATA")
	_clear_xp_fetch_callbacks()

func _on_xp_fetch_rejected(args: Array):
	var error_message = "XP_FETCH_PROMISE_REJECTED"
	
	if args.size() > 0:
		var error_obj = args[0]
		if error_obj is JavaScriptObject and "message" in error_obj:
			error_message = str(error_obj.message)
		else:
			error_message = str(error_obj)
		printerr("[TimebackAPI] XP fetch failed: ", error_message)
	else:
		printerr("[TimebackAPI] XP fetch failed: Unknown error")
	
	emit_signal("xp_fetch_failed", error_message)
	_clear_xp_fetch_callbacks()

func _clear_xp_fetch_callbacks():
	_xp_fetch_resolve_cb_js = null
	_xp_fetch_reject_cb_js = null

# ============================================================================
# HELPER METHODS
# ============================================================================

func _convert_js_xp_response(js_result) -> Dictionary:
	var xp_data: Dictionary = {}
	
	if js_result == null or not js_result is JavaScriptObject:
		return xp_data
	
	xp_data["totalXp"] = int(js_result.totalXp) if 'totalXp' in js_result and js_result.totalXp != null else 0
	if 'todayXp' in js_result and js_result.todayXp != null:
		xp_data["todayXp"] = int(js_result.todayXp)
	if 'courses' in js_result and js_result.courses != null:
		xp_data["courses"] = _convert_js_array_to_courses(js_result.courses)
	
	return xp_data

func _convert_js_array_to_courses(js_array) -> Array:
	var result: Array = []
	if js_array == null or not js_array is JavaScriptObject:
		return result
	
	var length = js_array.length if 'length' in js_array else 0
	for i in range(length):
		var item = js_array[i]
		if item is JavaScriptObject:
			var course: Dictionary = {
				"grade": int(item.grade) if 'grade' in item else 0,
				"subject": str(item.subject) if 'subject' in item else "",
				"title": str(item.title) if 'title' in item else "",
				"totalXp": int(item.totalXp) if 'totalXp' in item else 0
			}
			if 'todayXp' in item and item.todayXp != null:
				course["todayXp"] = int(item.todayXp)
			result.append(course)
	return result

func _get_xp_cache_key(options: Dictionary) -> String:
	var grade_str = str(options.get("grade", ""))
	var subject_str = str(options.get("subject", ""))
	var include_arr = options.get("include", [])
	var include_sorted = include_arr.duplicate()
	include_sorted.sort()
	var include_str = ",".join(include_sorted)
	return "%s:%s:%s" % [grade_str, subject_str, include_str]

func _get_cached_xp(cache_key: String) -> Dictionary:
	if not _xp_cache.has(cache_key):
		return {}
	var entry = _xp_cache[cache_key]
	var now = Time.get_ticks_msec()
	if now - entry["timestamp"] > XP_CACHE_TTL_MS:
		_xp_cache.erase(cache_key)
		return {}
	var data = entry.get("data", {})
	if data is Dictionary:
		return data.duplicate(true)
	return {}

func _set_cached_xp(cache_key: String, data: Dictionary):
	_xp_cache[cache_key] = {
		"data": data.duplicate(true),
		"timestamp": Time.get_ticks_msec()
	}

func _convert_js_array_to_enrollments(js_array) -> Array:
	var result: Array = []
	if js_array == null or not js_array is JavaScriptObject:
		return result
	
	var length = js_array.length if 'length' in js_array else 0
	for i in range(length):
		var item = js_array[i]
		if item is JavaScriptObject:
			result.append({
				"subject": str(item.subject) if 'subject' in item else "",
				"grade": int(item.grade) if 'grade' in item else 0,
				"courseId": str(item.courseId) if 'courseId' in item else ""
			})
	return result

func _convert_js_array_to_organizations(js_array) -> Array:
	var result: Array = []
	if js_array == null or not js_array is JavaScriptObject:
		return result
	
	var length = js_array.length if 'length' in js_array else 0
	for i in range(length):
		var item = js_array[i]
		if item is JavaScriptObject:
			result.append({
				"id": str(item.id) if 'id' in item else "",
				"name": str(item.name) if 'name' in item else "",
				"type": str(item.type) if 'type' in item else ""
			})
	return result

# ============================================================================
# TIMEBACK USER CLASS
# ============================================================================
# Provides access to TimeBack user data matching TypeScript SDK's client.timeback.user
# ============================================================================
class TimebackUser extends RefCounted:
	var _api: TimebackAPI
	var _xp: TimebackUserXp
	
	func _init(api: TimebackAPI):
		_api = api
		_xp = TimebackUserXp.new(api)
	
	# XP data access for the current user
	# Call xp.fetch() to get XP from the server
	var xp: TimebackUserXp:
		get:
			return _xp
	
	# Get the user's TimeBack ID
	var id: String:
		get:
			# Try to get from JS SDK client.timeback.user.id
			if _api._main_client != null and 'timeback' in _api._main_client:
				var tb = _api._main_client.timeback
				if tb is JavaScriptObject and 'user' in tb:
					var user_obj = tb.user
					if user_obj is JavaScriptObject and 'id' in user_obj:
						var val = user_obj.id
						if val != null:
							return str(val)
			
			# Fall back to window.playcademyTimebackId (set by shell.html)
			var js_window = JavaScriptBridge.get_interface("window")
			if js_window != null and 'playcademyTimebackId' in js_window:
				var val = js_window.playcademyTimebackId
				if val != null:
					return str(val)
			
			return ""
	
	# Get the user's TimeBack role (student, parent, teacher, administrator)
	var role: String:
		get:
			# Try to get from JS SDK client.timeback.user.role
			if _api._main_client != null and 'timeback' in _api._main_client:
				var tb = _api._main_client.timeback
				if tb is JavaScriptObject and 'user' in tb:
					var user_obj = tb.user
					if user_obj is JavaScriptObject and 'role' in user_obj:
						var val = user_obj.role
						if val != null:
							return str(val)
			
			# Fall back to window.playcademyTimebackRole (set by shell.html)
			var js_window = JavaScriptBridge.get_interface("window")
			if js_window != null and 'playcademyTimebackRole' in js_window:
				var val = js_window.playcademyTimebackRole
				if val != null:
					return str(val)
			
			return ""
	
	# Get the user's TimeBack enrollments for this game
	# Returns an array of dictionaries with { subject, grade, courseId }
	var enrollments: Array:
		get:
			var result: Array = []
			
			# Try to get from JS SDK client.timeback.user.enrollments
			if _api._main_client != null and 'timeback' in _api._main_client:
				var tb = _api._main_client.timeback
				if tb is JavaScriptObject and 'user' in tb:
					var user_obj = tb.user
					if user_obj is JavaScriptObject and 'enrollments' in user_obj:
						var js_enrollments = user_obj.enrollments
						result = _api._convert_js_array_to_enrollments(js_enrollments)
						if result.size() > 0:
							return result
			
			# Fall back to window.playcademyTimebackEnrollments (set by shell.html)
			var js_window = JavaScriptBridge.get_interface("window")
			if js_window != null and 'playcademyTimebackEnrollments' in js_window:
				var js_enrollments = js_window.playcademyTimebackEnrollments
				result = _api._convert_js_array_to_enrollments(js_enrollments)
			
			return result
	
	# Get the user's TimeBack organizations (schools/districts)
	# Returns an array of dictionaries with { id, name, type }
	var organizations: Array:
		get:
			var result: Array = []
			
			# Try to get from JS SDK client.timeback.user.organizations
			if _api._main_client != null and 'timeback' in _api._main_client:
				var tb = _api._main_client.timeback
				if tb is JavaScriptObject and 'user' in tb:
					var user_obj = tb.user
					if user_obj is JavaScriptObject and 'organizations' in user_obj:
						var js_orgs = user_obj.organizations
						result = _api._convert_js_array_to_organizations(js_orgs)
						if result.size() > 0:
							return result
			
			# Fall back to window.playcademyTimebackOrganizations (set by shell.html)
			var js_window = JavaScriptBridge.get_interface("window")
			if js_window != null and 'playcademyTimebackOrganizations' in js_window:
				var js_orgs = js_window.playcademyTimebackOrganizations
				result = _api._convert_js_array_to_organizations(js_orgs)
			
			return result
	
	# Fetch fresh TimeBack user data from the server
	# Emits user_fetch_succeeded(user_data: Dictionary) or user_fetch_failed(error_message: String)
	# The user_data dictionary contains: { id, role, enrollments, organizations }
	#
	# @param options - Optional dictionary with { force: bool } to bypass cache
	func fetch(options: Dictionary = {}):
		if _api._main_client == null:
			printerr("[TimebackAPI] Main client not set. Cannot fetch user data.")
			_api.emit_signal("user_fetch_failed", "MAIN_CLIENT_NULL")
			return
		
		if not ('timeback' in _api._main_client and 
				_api._main_client.timeback is JavaScriptObject and 
				'user' in _api._main_client.timeback):
			printerr("[TimebackAPI] client.timeback.user path not found.")
			_api.emit_signal("user_fetch_failed", "USER_PATH_NOT_FOUND")
			return
		
		var user_obj = _api._main_client.timeback.user
		if not (user_obj is JavaScriptObject and 'fetch' in user_obj):
			printerr("[TimebackAPI] client.timeback.user.fetch() not found.")
			_api.emit_signal("user_fetch_failed", "FETCH_METHOD_NOT_FOUND")
			return
		
		# Build options object for JavaScript
		var js_options = JavaScriptBridge.create_object("Object")
		if options.has("force"):
			js_options["force"] = options.get("force")
		
		var promise = user_obj.fetch(js_options)
		
		if promise == null or not promise is JavaScriptObject:
			printerr("[TimebackAPI] user.fetch() did not return a Promise.")
			_api.emit_signal("user_fetch_failed", "NOT_A_PROMISE")
			return
		
		var on_resolve = Callable(_api, "_on_user_fetch_resolved").bind()
		var on_reject = Callable(_api, "_on_user_fetch_rejected").bind()
		
		_api._user_fetch_resolve_cb_js = JavaScriptBridge.create_callback(on_resolve)
		_api._user_fetch_reject_cb_js = JavaScriptBridge.create_callback(on_reject)
		
		promise.then(_api._user_fetch_resolve_cb_js, _api._user_fetch_reject_cb_js)
		print("[TimebackAPI] Fetching fresh user data...")

# ============================================================================
# TIMEBACK USER XP CLASS
# ============================================================================
# Provides access to TimeBack XP data matching TypeScript SDK's client.timeback.user.xp
# ============================================================================
class TimebackUserXp extends RefCounted:
	var _api: TimebackAPI
	
	func _init(api: TimebackAPI):
		_api = api
	
	# Fetch XP data from the server
	# Emits xp_fetch_succeeded(xp_data: Dictionary) or xp_fetch_failed(error_message: String)
	# The xp_data dictionary contains: { totalXp: int, todayXp?: int, courses?: Array }
	# Each course in courses array: { grade: int, subject: String, title: String, totalXp: int, todayXp?: int }
	#
	# @param options - Optional dictionary with:
	#   - grade: int (must be used with subject)
	#   - subject: String (must be used with grade)
	#   - include: Array of Strings ("perCourse", "today")
	#   - force: bool - bypass 5s cache
	func fetch(options: Dictionary = {}):
		var has_grade = options.has("grade")
		var has_subject = options.has("subject")
		if has_grade != has_subject:
			printerr("[TimebackAPI] XP fetch: Both grade and subject must be provided together.")
			_api.emit_signal("xp_fetch_failed", "GRADE_SUBJECT_MISMATCH")
			return
		
		var force = options.get("force", false)
		var cache_key = _api._get_xp_cache_key(options)
		if not force:
			var cached = _api._get_cached_xp(cache_key)
			if not cached.is_empty():
				print("[TimebackAPI] Returning cached XP data")
				_api.emit_signal("xp_fetch_succeeded", cached)
				return
		
		if _api._main_client == null:
			printerr("[TimebackAPI] Main client not set. Cannot fetch XP data.")
			_api.emit_signal("xp_fetch_failed", "MAIN_CLIENT_NULL")
			return
		
		if not ('timeback' in _api._main_client and 
				_api._main_client.timeback is JavaScriptObject and 
				'user' in _api._main_client.timeback):
			printerr("[TimebackAPI] client.timeback.user path not found.")
			_api.emit_signal("xp_fetch_failed", "USER_PATH_NOT_FOUND")
			return
		
		var user_obj = _api._main_client.timeback.user
		if not (user_obj is JavaScriptObject and 'xp' in user_obj):
			printerr("[TimebackAPI] client.timeback.user.xp not found.")
			_api.emit_signal("xp_fetch_failed", "XP_PATH_NOT_FOUND")
			return
		
		var xp_obj = user_obj.xp
		if not (xp_obj is JavaScriptObject and 'fetch' in xp_obj):
			printerr("[TimebackAPI] client.timeback.user.xp.fetch() not found.")
			_api.emit_signal("xp_fetch_failed", "FETCH_METHOD_NOT_FOUND")
			return
		
		var js_options = JavaScriptBridge.create_object("Object")
		if has_grade:
			js_options["grade"] = int(options.get("grade"))
		if has_subject:
			js_options["subject"] = str(options.get("subject"))
		if options.has("include"):
			var include_arr = options.get("include")
			var js_include = JavaScriptBridge.create_object("Array")
			for i in range(include_arr.size()):
				js_include.push(include_arr[i])
			js_options["include"] = js_include
		if force:
			js_options["force"] = true
		
		var promise = xp_obj.fetch(js_options)
		
		if promise == null or not promise is JavaScriptObject:
			printerr("[TimebackAPI] xp.fetch() did not return a Promise.")
			_api.emit_signal("xp_fetch_failed", "NOT_A_PROMISE")
			return
		
		var on_resolve = Callable(_api, "_on_xp_fetch_resolved_with_cache").bind(cache_key)
		var on_reject = Callable(_api, "_on_xp_fetch_rejected").bind()
		
		_api._xp_fetch_resolve_cb_js = JavaScriptBridge.create_callback(on_resolve)
		_api._xp_fetch_reject_cb_js = JavaScriptBridge.create_callback(on_reject)
		
		promise.then(_api._xp_fetch_resolve_cb_js, _api._xp_fetch_reject_cb_js)
		print("[TimebackAPI] Fetching XP data...")
