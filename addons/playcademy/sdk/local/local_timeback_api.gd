extends Node

class_name LocalTimebackAPI

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

var _base_url: String
var _sandbox_url: String = ""

# User context data
var _user_id: String = ""
var _user_role: String = "student"
var _user_enrollments: Array = []
var _user_organizations: Array = []
var _user_context_loaded: bool = false

# Internal state for tracking current activity
var _activity_start_time: int = 0
var _activity_metadata: Dictionary = {}
var _activity_in_progress: bool = false
var _paused_time: int = 0  # Accumulated paused duration in milliseconds
var _pause_start_time: int = 0  # When current pause started (0 if not paused)

# User context object
var _user: LocalTimebackUser

# XP cache state (5 second TTL)
const XP_CACHE_TTL_MS: int = 5000
var _xp_cache: Dictionary = {}  # { cache_key: { "data": Dictionary, "timestamp": int } }

func _init(base_url: String, sandbox_url: String = ""):
	_base_url = base_url.rstrip("/")
	_sandbox_url = sandbox_url.rstrip("/") if sandbox_url else ""
	_user = LocalTimebackUser.new(self)

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
#   - user.xp: LocalTimebackUserXp - XP data accessor
#
# Methods:
#   - user.fetch() - Fetch fresh data from server (emits user_fetch_succeeded/failed)
#   - user.xp.fetch() - Fetch XP data from server (emits xp_fetch_succeeded/failed)
# ============================================================================
var user: LocalTimebackUser:
	get:
		return _user

# ============================================================================
# DEPRECATED: Direct role/enrollments access
# Use user.role and user.enrollments instead
# ============================================================================

## @deprecated Use user.role instead
var role: String:
	get:
		return _user_role

## @deprecated Use user.enrollments instead
var enrollments: Array:
	get:
		return _user_enrollments

# Set user context (called by PlaycademySDK after fetching user data)
func set_user_context(user_id: String, user_role: String, user_enrollments: Array, user_organizations: Array = []):
	_user_id = user_id if user_id else ""
	_user_role = user_role if user_role else "student"
	_user_enrollments = user_enrollments if user_enrollments else []
	_user_organizations = user_organizations if user_organizations else []
	_user_context_loaded = true
	print("[LocalTimebackAPI] User context set: id=%s, role=%s, enrollments=%d, organizations=%d" % [_user_id, _user_role, _user_enrollments.size(), _user_organizations.size()])

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
	# Validate required fields
	if not metadata.has("activityId"):
		printerr("[LocalTimebackAPI] start_activity() requires 'activityId' in metadata.")
		return
	if not metadata.has("grade"):
		printerr("[LocalTimebackAPI] start_activity() requires 'grade' in metadata.")
		return
	if not metadata.has("subject"):
		printerr("[LocalTimebackAPI] start_activity() requires 'subject' in metadata.")
		return
	
	_activity_start_time = Time.get_ticks_msec()
	_activity_metadata = metadata.duplicate()
	_activity_in_progress = true
	_paused_time = 0
	_pause_start_time = 0
	print("[LocalTimebackAPI] Started activity: ", _activity_metadata.get("activityId", "unknown"), " (Grade ", metadata.get("grade"), ", ", metadata.get("subject"), ")")

# Pause the current activity timer
# Paused time is not counted toward the activity duration
func pause_activity():
	if not _activity_in_progress:
		printerr("[LocalTimebackAPI] No activity in progress. Call start_activity() first.")
		emit_signal("pause_activity_failed", "NO_ACTIVITY_IN_PROGRESS")
		return
	if _pause_start_time > 0:
		printerr("[LocalTimebackAPI] Activity is already paused.")
		emit_signal("pause_activity_failed", "ALREADY_PAUSED")
		return
	_pause_start_time = Time.get_ticks_msec()
	print("[LocalTimebackAPI] Activity paused")

# Resume the current activity timer after a pause
func resume_activity():
	if not _activity_in_progress:
		printerr("[LocalTimebackAPI] No activity in progress. Call start_activity() first.")
		emit_signal("resume_activity_failed", "NO_ACTIVITY_IN_PROGRESS")
		return
	if _pause_start_time == 0:
		printerr("[LocalTimebackAPI] Activity is not paused.")
		emit_signal("resume_activity_failed", "NOT_PAUSED")
		return
	var pause_duration = Time.get_ticks_msec() - _pause_start_time
	_paused_time += pause_duration
	_pause_start_time = 0
	print("[LocalTimebackAPI] Activity resumed (paused for %d ms)" % pause_duration)

# End the current activity and submit results
# XP is calculated server-side with attempt-aware multipliers
# score_data should contain: { correctQuestions: int, totalQuestions: int, xpAwarded: int (optional), masteredUnits: int (optional) }
func end_activity(score_data: Dictionary):
	if not _activity_in_progress:
		printerr("[LocalTimebackAPI] No activity in progress. Call start_activity() first.")
		emit_signal("end_activity_failed", "NO_ACTIVITY_IN_PROGRESS")
		return
	
	# If activity is still paused when ending, resume it first
	if _pause_start_time > 0:
		var pause_duration = Time.get_ticks_msec() - _pause_start_time
		_paused_time += pause_duration
		_pause_start_time = 0
	
	# Calculate duration excluding paused time
	var end_time = Time.get_ticks_msec()
	var total_elapsed = end_time - _activity_start_time
	var active_time = total_elapsed - _paused_time
	var duration_seconds = float(active_time) / 1000.0
	
	var correct_questions = score_data.get("correctQuestions", 0)
	var total_questions = score_data.get("totalQuestions", 1)
	var xp_awarded = score_data.get("xpAwarded", null)
	var mastered_units = score_data.get("masteredUnits", null)
	
	var score_percentage = (float(correct_questions) / float(total_questions) * 100.0) if total_questions > 0 else 0.0
	
	var log_parts = ["[LocalTimebackAPI] Ending activity: %ds, %.1f%% (%d/%d)" % [duration_seconds, score_percentage, correct_questions, total_questions]]
	if xp_awarded != null:
		log_parts.append(" - XP Override: %d" % xp_awarded)
	if mastered_units != null:
		log_parts.append(" - Mastered Units: %d" % mastered_units)
	print("".join(log_parts))
	
	var http := HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(_on_end_activity_completed.bind(http))
	
	var url = "%s/integrations/timeback/end-activity" % _base_url
	var headers = ["Content-Type: application/json", "Authorization: Bearer sandbox-demo-token"]
	
	var score_data_dict = {
		"correctQuestions": correct_questions,
		"totalQuestions": total_questions
	}
	
	var request_body = {
		"activityData": _activity_metadata,
		"scoreData": score_data_dict,
		"timingData": {
			"durationSeconds": int(duration_seconds)
		}
	}
	
	# Add optional XP override to request body
	if xp_awarded != null:
		request_body["xpEarned"] = xp_awarded
	
	# Add optional mastered units to request body
	if mastered_units != null:
		request_body["masteredUnits"] = mastered_units
	
	var json_string = JSON.stringify(request_body)
	var err := http.request(url, headers, HTTPClient.METHOD_POST, json_string)
	
	if err != OK:
		printerr("[LocalTimebackAPI] Failed to make POST %s request. Error code: %s" % [url, err])
		emit_signal("end_activity_failed", "HTTP_REQUEST_FAILED")
		_activity_in_progress = false
		http.queue_free()

func _on_end_activity_completed(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray, http: HTTPRequest):
	http.queue_free()
	_activity_in_progress = false
	
	if response_code != 200:
		emit_signal("end_activity_failed", "HTTP_%d" % response_code)
		return
	var json = JSON.new()
	var parse_result = json.parse(body.get_string_from_utf8())
	if parse_result != OK:
		emit_signal("end_activity_failed", "JSON_PARSE_ERROR")
		return
	var data = json.data
	emit_signal("end_activity_succeeded", data)

# ============================================================================
# USER FETCH HANDLER
# ============================================================================

func _fetch_user_from_sandbox(options: Dictionary = {}):
	if _sandbox_url.is_empty():
		printerr("[LocalTimebackAPI] Cannot fetch user context: sandbox URL not set")
		emit_signal("user_fetch_failed", "NO_SANDBOX_URL")
		return
	
	var http := HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(_on_user_fetch_completed.bind(http))
	
	var url = "%s/users/me" % _sandbox_url
	var url_headers = ["Authorization: Bearer sandbox-demo-token"]
	var err := http.request(url, url_headers)
	
	if err != OK:
		printerr("[LocalTimebackAPI] Failed to fetch user context. Error code: %s" % err)
		emit_signal("user_fetch_failed", "HTTP_REQUEST_FAILED")
		http.queue_free()

func _on_user_fetch_completed(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray, http: HTTPRequest):
	http.queue_free()
	
	if response_code != 200:
		emit_signal("user_fetch_failed", "HTTP_%d" % response_code)
		return
	
	var json = JSON.new()
	var parse_result = json.parse(body.get_string_from_utf8())
	if parse_result != OK:
		emit_signal("user_fetch_failed", "JSON_PARSE_ERROR")
		return
	
	var data = json.data
	
	# Extract timeback data from user response
	if data.has("timeback") and data["timeback"] != null:
		var tb = data["timeback"]
		_user_id = tb.get("id", "")
		_user_role = tb.get("role", "student")
		_user_enrollments = tb.get("enrollments", [])
		_user_organizations = tb.get("organizations", [])
	else:
		_user_id = ""
		_user_role = "student"
		_user_enrollments = []
		_user_organizations = []
	
	_user_context_loaded = true
	print("[LocalTimebackAPI] User context loaded: id=%s, role=%s, enrollments=%d, organizations=%d" % [_user_id, _user_role, _user_enrollments.size(), _user_organizations.size()])
	
	var user_data = {
		"id": _user_id,
		"role": _user_role,
		"enrollments": _user_enrollments,
		"organizations": _user_organizations
	}
	emit_signal("user_fetch_succeeded", user_data)

# ============================================================================
# XP FETCH HANDLER
# ============================================================================

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

func _is_timeback_not_configured_response(data: Dictionary) -> bool:
	return data.get("__playcademyDevWarning", "") == "timeback-not-configured"

func _fetch_xp_from_backend(options: Dictionary = {}):
	# Validate grade/subject pairing
	var has_grade = options.has("grade")
	var has_subject = options.has("subject")
	if has_grade != has_subject:
		printerr("[LocalTimebackAPI] XP fetch: Both grade and subject must be provided together.")
		emit_signal("xp_fetch_failed", "GRADE_SUBJECT_MISMATCH")
		return
	
	# Check cache unless force is true
	var force = options.get("force", false)
	var cache_key = _get_xp_cache_key(options)
	if not force:
		var cached = _get_cached_xp(cache_key)
		if not cached.is_empty():
			print("[LocalTimebackAPI] Returning cached XP data")
			emit_signal("xp_fetch_succeeded", cached)
			return
	
	print("[LocalTimebackAPI] Fetching XP data...")
	var http := HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(_on_xp_fetch_completed.bind(http, cache_key))
	
	var query_parts: Array = []
	if has_grade:
		query_parts.append("grade=%s" % str(options.get("grade")).uri_encode())
	if has_subject:
		query_parts.append("subject=%s" % str(options.get("subject")).uri_encode())
	if options.has("include"):
		var include_arr = options.get("include")
		if include_arr.size() > 0:
			query_parts.append("include=%s" % ",".join(include_arr).uri_encode())
	
	var query_string = "&".join(query_parts)
	var url = "%s/integrations/timeback/xp" % _base_url
	if not query_string.is_empty():
		url = "%s?%s" % [url, query_string]
	
	var headers = ["Authorization: Bearer sandbox-demo-token"]
	var err := http.request(url, headers)
	
	if err != OK:
		printerr("[LocalTimebackAPI] Failed to make GET %s request. Error code: %s" % [url, err])
		emit_signal("xp_fetch_failed", "HTTP_REQUEST_FAILED")
		http.queue_free()

func _on_xp_fetch_completed(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray, http: HTTPRequest, cache_key: String):
	http.queue_free()
	
	if response_code != 200:
		emit_signal("xp_fetch_failed", "HTTP_%d" % response_code)
		return
	
	var json = JSON.new()
	var parse_result = json.parse(body.get_string_from_utf8())
	if parse_result != OK:
		emit_signal("xp_fetch_failed", "JSON_PARSE_ERROR")
		return
	
	var data = json.data
	if data is Dictionary:
		# If backend is running without Timeback integration enabled, it returns a stub response
		# with __playcademyDevWarning=timeback-not-configured. In local dev, fall back to the
		# sandbox mock endpoint so XP demos work out of the box.
		if _is_timeback_not_configured_response(data):
			print("[LocalTimebackAPI] Backend Timeback not configured; falling back to sandbox XP")
			_fetch_xp_from_sandbox(cache_key)
			return
		
		_set_cached_xp(cache_key, data)
		var emit_data: Dictionary = data.duplicate(true)
		emit_signal("xp_fetch_succeeded", emit_data)
	else:
		emit_signal("xp_fetch_failed", "INVALID_XP_RESPONSE")

func _fetch_xp_from_sandbox(cache_key: String):
	if _sandbox_url.is_empty():
		emit_signal("xp_fetch_failed", "NO_SANDBOX_URL")
		return
	if _user_id.is_empty():
		emit_signal("xp_fetch_failed", "NO_USER_ID")
		return
	
	# cache_key format: "<grade>:<subject>:<includeCsv>"
	var parts = cache_key.split(":", false)
	var grade_str = parts[0] if parts.size() > 0 else ""
	var subject_str = parts[1] if parts.size() > 1 else ""
	var include_str = parts[2] if parts.size() > 2 else ""
	
	var query_parts: Array = []
	if not grade_str.is_empty() and not subject_str.is_empty():
		query_parts.append("grade=%s" % grade_str.uri_encode())
		query_parts.append("subject=%s" % subject_str.uri_encode())
	if not include_str.is_empty():
		query_parts.append("include=%s" % include_str.uri_encode())
	
	var query_string = "&".join(query_parts)
	var url = "%s/timeback/student-xp/%s" % [_sandbox_url, _user_id]
	if not query_string.is_empty():
		url = "%s?%s" % [url, query_string]
	
	var http := HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(_on_xp_fetch_completed_from_sandbox.bind(http, cache_key))
	
	var headers = ["Authorization: Bearer sandbox-demo-token"]
	var err := http.request(url, headers)
	if err != OK:
		printerr("[LocalTimebackAPI] Failed to make GET %s request. Error code: %s" % [url, err])
		emit_signal("xp_fetch_failed", "HTTP_REQUEST_FAILED")
		http.queue_free()

func _on_xp_fetch_completed_from_sandbox(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray, http: HTTPRequest, cache_key: String):
	http.queue_free()
	
	if response_code != 200:
		emit_signal("xp_fetch_failed", "HTTP_%d" % response_code)
		return
	
	var json = JSON.new()
	var parse_result = json.parse(body.get_string_from_utf8())
	if parse_result != OK:
		emit_signal("xp_fetch_failed", "JSON_PARSE_ERROR")
		return
	
	var data = json.data
	if data is Dictionary:
		_set_cached_xp(cache_key, data)
		var emit_data: Dictionary = data.duplicate(true)
		emit_signal("xp_fetch_succeeded", emit_data)
	else:
		emit_signal("xp_fetch_failed", "INVALID_XP_RESPONSE")

# ============================================================================
# LOCAL TIMEBACK USER CLASS
# ============================================================================
# Provides access to TimeBack user data matching TypeScript SDK's client.timeback.user
# ============================================================================
class LocalTimebackUser extends RefCounted:
	var _api: LocalTimebackAPI
	var _xp: LocalTimebackUserXp
	
	func _init(api: LocalTimebackAPI):
		_api = api
		_xp = LocalTimebackUserXp.new(api)
	
	# XP data access for the current user
	# Call xp.fetch() to get XP from the server
	var xp: LocalTimebackUserXp:
		get:
			return _xp
	
	# Get the user's TimeBack ID
	var id: String:
		get:
			return _api._user_id
	
	# Get the user's TimeBack role (student, parent, teacher, administrator)
	var role: String:
		get:
			return _api._user_role
	
	# Get the user's TimeBack enrollments for this game
	# Returns an array of dictionaries with { subject, grade, courseId }
	var enrollments: Array:
		get:
			return _api._user_enrollments
	
	# Get the user's TimeBack organizations (schools/districts)
	# Returns an array of dictionaries with { id, name, type }
	var organizations: Array:
		get:
			return _api._user_organizations
	
	# Fetch fresh TimeBack user data from the server
	# Emits user_fetch_succeeded(user_data: Dictionary) or user_fetch_failed(error_message: String)
	# The user_data dictionary contains: { id, role, enrollments, organizations }
	#
	# @param options - Optional dictionary with { force: bool } to bypass cache
	func fetch(options: Dictionary = {}):
		_api._fetch_user_from_sandbox(options)
		print("[LocalTimebackAPI] Fetching fresh user data...")

# ============================================================================
# LOCAL TIMEBACK USER XP CLASS
# ============================================================================
# Provides access to TimeBack XP data matching TypeScript SDK's client.timeback.user.xp
# ============================================================================
class LocalTimebackUserXp extends RefCounted:
	var _api: LocalTimebackAPI
	
	func _init(api: LocalTimebackAPI):
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
		_api._fetch_xp_from_backend(options)
