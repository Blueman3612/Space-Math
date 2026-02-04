extends Node

const TimebackAPI = preload("res://addons/playcademy/sdk/apis/timeback_api.gd")

# Signals for activity operations
signal end_activity_succeeded(response_data: Dictionary)
signal end_activity_failed(error_message: String)
signal pause_activity_failed(error_message: String)
signal resume_activity_failed(error_message: String)

# Signals for user operations
signal user_fetch_succeeded(user_data: Dictionary)
signal user_fetch_failed(error_message: String)

# Signals for XP operations
signal xp_fetch_succeeded(xp_data: Dictionary)
signal xp_fetch_failed(error_message: String)

var _timeback_api

func _init(playcademy_client: JavaScriptObject):
	_timeback_api = TimebackAPI.new(playcademy_client)
	_timeback_api.end_activity_succeeded.connect(_on_original_end_activity_succeeded)
	_timeback_api.end_activity_failed.connect(_on_original_end_activity_failed)
	_timeback_api.pause_activity_failed.connect(_on_original_pause_activity_failed)
	_timeback_api.resume_activity_failed.connect(_on_original_resume_activity_failed)
	_timeback_api.user_fetch_succeeded.connect(_on_original_user_fetch_succeeded)
	_timeback_api.user_fetch_failed.connect(_on_original_user_fetch_failed)
	_timeback_api.xp_fetch_succeeded.connect(_on_original_xp_fetch_succeeded)
	_timeback_api.xp_fetch_failed.connect(_on_original_xp_fetch_failed)

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
var user:
	get:
		return _timeback_api.user

# ============================================================================
# DEPRECATED: Direct role/enrollments access
# Use user.role and user.enrollments instead
# ============================================================================

## @deprecated Use user.role instead
var role: String:
	get:
		return _timeback_api.role

## @deprecated Use user.enrollments instead
var enrollments: Array:
	get:
		return _timeback_api.enrollments

# ============================================================================
# ACTIVITY METHODS
# ============================================================================

func start_activity(metadata: Dictionary):
	_timeback_api.start_activity(metadata)

func pause_activity():
	_timeback_api.pause_activity()

func resume_activity():
	_timeback_api.resume_activity()

func end_activity(score_data: Dictionary):
	_timeback_api.end_activity(score_data)

# ============================================================================
# SIGNAL FORWARDING
# ============================================================================

func _on_original_end_activity_succeeded(response_data):
	emit_signal("end_activity_succeeded", response_data)

func _on_original_end_activity_failed(error_message: String):
	emit_signal("end_activity_failed", error_message)

func _on_original_pause_activity_failed(error_message: String):
	emit_signal("pause_activity_failed", error_message)

func _on_original_resume_activity_failed(error_message: String):
	emit_signal("resume_activity_failed", error_message)

func _on_original_user_fetch_succeeded(user_data: Dictionary):
	emit_signal("user_fetch_succeeded", user_data)

func _on_original_user_fetch_failed(error_message: String):
	emit_signal("user_fetch_failed", error_message)

func _on_original_xp_fetch_succeeded(xp_data: Dictionary):
	emit_signal("xp_fetch_succeeded", xp_data)

func _on_original_xp_fetch_failed(error_message: String):
	emit_signal("xp_fetch_failed", error_message)
