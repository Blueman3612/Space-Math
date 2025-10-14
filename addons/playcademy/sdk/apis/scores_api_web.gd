extends Node

const ScoresAPI = preload("res://addons/playcademy/sdk/apis/scores_api.gd")

# Signals for submit operation
signal submit_succeeded(score_data: Dictionary)
signal submit_failed(error_message: String)

# Signals for getByUser operation
signal get_by_user_succeeded(scores_data: Array)
signal get_by_user_failed(error_message: String)

var _scores_api

func _init(playcademy_client: JavaScriptObject):
	_scores_api = ScoresAPI.new(playcademy_client)
	_scores_api.submit_succeeded.connect(_on_original_submit_succeeded)
	_scores_api.submit_failed.connect(_on_original_submit_failed)
	_scores_api.get_by_user_succeeded.connect(_on_original_get_by_user_succeeded)
	_scores_api.get_by_user_failed.connect(_on_original_get_by_user_failed)

func submit(score: int, metadata: Dictionary = {}):
	_scores_api.submit(score, metadata)

func get_by_user(user_id: String, options: Dictionary = {}):
	_scores_api.get_by_user(user_id, options)

# Signal forwarding from core API to web API
func _on_original_submit_succeeded(score_data):
	emit_signal("submit_succeeded", score_data)

func _on_original_submit_failed(error_message):
	emit_signal("submit_failed", error_message)

func _on_original_get_by_user_succeeded(scores_data):
	emit_signal("get_by_user_succeeded", scores_data)

func _on_original_get_by_user_failed(error_message):
	emit_signal("get_by_user_failed", error_message)
