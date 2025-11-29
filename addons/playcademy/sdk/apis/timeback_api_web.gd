extends Node

const TimebackAPI = preload("res://addons/playcademy/sdk/apis/timeback_api.gd")

# Signals for activity operations
signal end_activity_succeeded(response_data: Dictionary)
signal end_activity_failed(error_message: String)
signal pause_activity_failed(error_message: String)
signal resume_activity_failed(error_message: String)

var _timeback_api

func _init(playcademy_client: JavaScriptObject):
	_timeback_api = TimebackAPI.new(playcademy_client)
	_timeback_api.end_activity_succeeded.connect(_on_original_end_activity_succeeded)
	_timeback_api.end_activity_failed.connect(_on_original_end_activity_failed)
	_timeback_api.pause_activity_failed.connect(_on_original_pause_activity_failed)
	_timeback_api.resume_activity_failed.connect(_on_original_resume_activity_failed)

# Get the user's TimeBack role (student, parent, teacher, administrator)
var role: String:
	get:
		return _timeback_api.role

# Get the user's TimeBack enrollments for this game
# Returns an array of dictionaries with { subject, grade, courseId }
var enrollments: Array:
	get:
		return _timeback_api.enrollments

func start_activity(metadata: Dictionary):
	_timeback_api.start_activity(metadata)

func pause_activity():
	_timeback_api.pause_activity()

func resume_activity():
	_timeback_api.resume_activity()

func end_activity(score_data: Dictionary):
	_timeback_api.end_activity(score_data)

# Signal forwarding
func _on_original_end_activity_succeeded(response_data):
	emit_signal("end_activity_succeeded", response_data)

func _on_original_end_activity_failed(error_message: String):
	emit_signal("end_activity_failed", error_message)

func _on_original_pause_activity_failed(error_message: String):
	emit_signal("pause_activity_failed", error_message)

func _on_original_resume_activity_failed(error_message: String):
	emit_signal("resume_activity_failed", error_message)
