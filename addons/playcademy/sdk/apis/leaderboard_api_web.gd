extends Node

const LeaderboardAPI = preload("res://addons/playcademy/sdk/apis/leaderboard_api.gd")

# Signals for fetch operation
signal fetch_succeeded(leaderboard_data: Array)
signal fetch_failed(error_message: String)

# Signals for getUserRank operation
signal get_user_rank_succeeded(rank_data: Dictionary)
signal get_user_rank_failed(error_message: String)

var _leaderboard_api

func _init(playcademy_client: JavaScriptObject):
	_leaderboard_api = LeaderboardAPI.new(playcademy_client)
	_leaderboard_api.fetch_succeeded.connect(_on_original_fetch_succeeded)
	_leaderboard_api.fetch_failed.connect(_on_original_fetch_failed)
	_leaderboard_api.get_user_rank_succeeded.connect(_on_original_get_user_rank_succeeded)
	_leaderboard_api.get_user_rank_failed.connect(_on_original_get_user_rank_failed)

func fetch(options: Dictionary = {}):
	_leaderboard_api.fetch(options)

func get_my_rank():
	_leaderboard_api.get_my_rank()

func get_user_rank(user_id: String, game_id: String = ""):
	_leaderboard_api.get_user_rank(user_id, game_id)

# Signal forwarding from core API to web API
func _on_original_fetch_succeeded(leaderboard_data):
	emit_signal("fetch_succeeded", leaderboard_data)

func _on_original_fetch_failed(error_message):
	emit_signal("fetch_failed", error_message)

func _on_original_get_user_rank_succeeded(rank_data):
	emit_signal("get_user_rank_succeeded", rank_data)

func _on_original_get_user_rank_failed(error_message):
	emit_signal("get_user_rank_failed", error_message)
