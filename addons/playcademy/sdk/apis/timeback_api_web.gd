extends Node

const TimebackAPI = preload("res://addons/playcademy/sdk/apis/timeback_api.gd")

# Signals for record_progress operation
signal record_progress_succeeded(response_data: Dictionary)
signal record_progress_failed(error_message: String)

# Signals for record_session_end operation
signal record_session_end_succeeded(response_data: Dictionary)
signal record_session_end_failed(error_message: String)

# Signals for award_xp operation
signal award_xp_succeeded(response_data: Dictionary)
signal award_xp_failed(error_message: String)

var _timeback_api

func _init(playcademy_client: JavaScriptObject):
	_timeback_api = TimebackAPI.new(playcademy_client)
	_timeback_api.record_progress_succeeded.connect(_on_original_record_progress_succeeded)
	_timeback_api.record_progress_failed.connect(_on_original_record_progress_failed)
	_timeback_api.record_session_end_succeeded.connect(_on_original_record_session_end_succeeded)
	_timeback_api.record_session_end_failed.connect(_on_original_record_session_end_failed)
	_timeback_api.award_xp_succeeded.connect(_on_original_award_xp_succeeded)
	_timeback_api.award_xp_failed.connect(_on_original_award_xp_failed)
	print("[TimebackAPIWeb] Web-specific TimeBack API initialized.")

func record_progress(progress_data: Dictionary):
	_timeback_api.record_progress(progress_data)

func record_session_end(session_data: Dictionary):
	_timeback_api.record_session_end(session_data)

func award_xp(xp_amount: int, metadata: Dictionary):
	_timeback_api.award_xp(xp_amount, metadata)

# Signal forwarding
func _on_original_record_progress_succeeded(response_data):
	emit_signal("record_progress_succeeded", response_data)

func _on_original_record_progress_failed(error_message: String):
	emit_signal("record_progress_failed", error_message)

func _on_original_record_session_end_succeeded(response_data):
	emit_signal("record_session_end_succeeded", response_data)

func _on_original_record_session_end_failed(error_message: String):
	emit_signal("record_session_end_failed", error_message)

func _on_original_award_xp_succeeded(response_data):
	emit_signal("award_xp_succeeded", response_data)

func _on_original_award_xp_failed(error_message: String):
	emit_signal("award_xp_failed", error_message)

