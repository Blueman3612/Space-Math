extends Node

class_name LocalTimebackAPI

# Signals for activity operations
signal end_activity_succeeded(response_data)
signal end_activity_failed(error_message)
signal pause_activity_failed(error_message)
signal resume_activity_failed(error_message)

# Signals for user context
signal user_context_received(data: Dictionary)
signal user_context_failed(error_message: String)

var _base_url: String
var _sandbox_url: String = ""

# User context (role and enrollments)
var _role: String = "student"
var _enrollments: Array = []
var _user_context_loaded: bool = false

# Internal state for tracking current activity
var _activity_start_time: int = 0
var _activity_metadata: Dictionary = {}
var _activity_in_progress: bool = false
var _paused_time: int = 0  # Accumulated paused duration in milliseconds
var _pause_start_time: int = 0  # When current pause started (0 if not paused)

func _init(base_url: String, sandbox_url: String = ""):
	_base_url = base_url.rstrip("/")
	_sandbox_url = sandbox_url.rstrip("/") if sandbox_url else ""

# Get the user's TimeBack role (student, parent, teacher, administrator)
var role: String:
	get:
		return _role

# Get the user's TimeBack enrollments for this game
# Returns an array of dictionaries with { subject, grade, courseId }
var enrollments: Array:
	get:
		return _enrollments

# Set role and enrollments (called by PlaycademySDK after fetching user data)
func set_user_context(user_role: String, user_enrollments: Array):
	_role = user_role if user_role else "student"
	_enrollments = user_enrollments if user_enrollments else []
	_user_context_loaded = true
	print("[LocalTimebackAPI] User context set: role=%s, enrollments=%d" % [_role, _enrollments.size()])

# Fetch user context from sandbox (role and enrollments)
func fetch_user_context():
	if _sandbox_url.is_empty():
		printerr("[LocalTimebackAPI] Cannot fetch user context: sandbox URL not set")
		emit_signal("user_context_failed", "NO_SANDBOX_URL")
		return
	
	var http := HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(_on_user_context_completed.bind(http))
	
	var url = "%s/users/me" % _sandbox_url
	var headers = ["Authorization: Bearer sandbox-demo-token"]
	var err := http.request(url, headers)
	
	if err != OK:
		printerr("[LocalTimebackAPI] Failed to fetch user context. Error code: %s" % err)
		emit_signal("user_context_failed", "HTTP_REQUEST_FAILED")
		http.queue_free()

func _on_user_context_completed(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray, http: HTTPRequest):
	http.queue_free()
	
	if response_code != 200:
		emit_signal("user_context_failed", "HTTP_%d" % response_code)
		return
	
	var json = JSON.new()
	var parse_result = json.parse(body.get_string_from_utf8())
	if parse_result != OK:
		emit_signal("user_context_failed", "JSON_PARSE_ERROR")
		return
	
	var data = json.data
	
	# Extract timeback data from user response
	if data.has("timeback") and data["timeback"] != null:
		var tb = data["timeback"]
		_role = tb.get("role", "student")
		_enrollments = tb.get("enrollments", [])
	else:
		_role = "student"
		_enrollments = []
	
	_user_context_loaded = true
	print("[LocalTimebackAPI] User context loaded: role=%s, enrollments=%d" % [_role, _enrollments.size()])
	emit_signal("user_context_received", {"role": _role, "enrollments": _enrollments})

# Start tracking an activity
func start_activity(metadata: Dictionary):
	_activity_start_time = Time.get_ticks_msec()
	_activity_metadata = metadata.duplicate()
	_activity_in_progress = true
	_paused_time = 0
	_pause_start_time = 0
	print("[LocalTimebackAPI] Started activity: ", _activity_metadata.get("activityId", "unknown"))

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
# score_data should contain: { correctQuestions: int, totalQuestions: int, xpAwarded: int (optional) }
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
	
	var score_percentage = (float(correct_questions) / float(total_questions) * 100.0) if total_questions > 0 else 0.0
	
	print("[LocalTimebackAPI] Ending activity: %ds, %.1f%% (%d/%d)%s" % [
		duration_seconds,
		score_percentage, 
		correct_questions, 
		total_questions,
		(" - XP Override: %d" % xp_awarded) if xp_awarded != null else ""
	])
	
	var http := HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(_on_end_activity_completed.bind(http))
	
	var url = "%s/integrations/timeback/end-activity" % _base_url
	var headers = ["Content-Type: application/json", "Authorization: Bearer sandbox-demo-token"]
	
	var score_data_dict = {
		"correctQuestions": correct_questions,
		"totalQuestions": total_questions
	}
	
	# Add optional XP override
	if xp_awarded != null:
		score_data_dict["xpAwarded"] = xp_awarded
	
	var request_body = {
		"activityData": _activity_metadata,
		"scoreData": score_data_dict,
		"timingData": {
			"durationSeconds": int(duration_seconds)
		}
	}
	
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
