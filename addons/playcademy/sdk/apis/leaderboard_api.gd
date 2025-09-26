class_name LeaderboardAPI extends RefCounted

# Signals for fetch operation
signal fetch_succeeded(leaderboard_data)
signal fetch_failed(error_message)

# Signals for getUserRank operation
signal get_user_rank_succeeded(rank_data)
signal get_user_rank_failed(error_message)

var _main_client: JavaScriptObject

# To keep JS callbacks alive for ongoing operations
var _fetch_resolve_cb_js: JavaScriptObject = null
var _fetch_reject_cb_js: JavaScriptObject = null
var _get_user_rank_resolve_cb_js: JavaScriptObject = null
var _get_user_rank_reject_cb_js: JavaScriptObject = null

func _init(client_js_object: JavaScriptObject):
	_main_client = client_js_object
	print("[LeaderboardAPI] Initialized with client.")

# Corresponds to client.leaderboard.fetch(options?) - gameId auto-injected
func fetch(options: Dictionary = {}):
	if _main_client == null:
		printerr("[LeaderboardAPI] Main client not set. Cannot call fetch().")
		emit_signal("fetch_failed", "MAIN_CLIENT_NULL")
		return

	if not ('leaderboard' in _main_client and 
			_main_client.leaderboard is JavaScriptObject and 
			'fetch' in _main_client.leaderboard):
		printerr("[LeaderboardAPI] client.leaderboard.fetch() path not found.")
		emit_signal("fetch_failed", "METHOD_PATH_INVALID")
		return

	# Auto-inject gameId from client context unless explicitly provided
	var merged_options = options.duplicate()
	if not merged_options.has("gameId"):
		var game_id = _main_client['gameId']
		if game_id != null:
			merged_options["gameId"] = game_id

	print("[LeaderboardAPI] Calling _main_client.leaderboard.fetch() with gameId...")
	var promise
	if merged_options.is_empty():
		promise = _main_client.leaderboard.fetch()
	else:
		# Convert Godot Dictionary to JavaScript object
		var js_options = JavaScriptBridge.create_object("Object")
		for key in merged_options:
			js_options[key] = merged_options[key]
		promise = _main_client.leaderboard.fetch(js_options)

	if not promise is JavaScriptObject:
		printerr("[LeaderboardAPI] leaderboard.fetch() did not return a Promise.")
		emit_signal("fetch_failed", "NOT_A_PROMISE")
		return

	var on_resolve = Callable(self, "_on_fetch_resolved").bind()
	var on_reject = Callable(self, "_on_fetch_rejected").bind()

	_fetch_resolve_cb_js = JavaScriptBridge.create_callback(on_resolve)
	_fetch_reject_cb_js = JavaScriptBridge.create_callback(on_reject)

	promise.then(_fetch_resolve_cb_js, _fetch_reject_cb_js)
	print("[LeaderboardAPI] .then() called on leaderboard.fetch() promise.")

func _on_fetch_resolved(args: Array):
	print("[LeaderboardAPI] Fetch promise resolved. Args: ", args)
	if args.size() > 0:
		var result_data = args[0]
		emit_signal("fetch_succeeded", result_data)
	else:
		emit_signal("fetch_failed", "FETCH_RESOLVED_NO_DATA")
	_clear_fetch_callbacks()

func _on_fetch_rejected(args: Array):
	print("[LeaderboardAPI] Fetch promise rejected. Args: ", args)
	var error_message = "FETCH_PROMISE_REJECTED"
	if args.size() > 0:
		error_message = str(args[0])
	emit_signal("fetch_failed", error_message)
	_clear_fetch_callbacks()

func _clear_fetch_callbacks():
	_fetch_resolve_cb_js = null
	_fetch_reject_cb_js = null

# Get the current user's rank in the current game - convenience method
func get_my_rank():
	var game_id = _main_client['gameId'] if _main_client else null
	if game_id == null:
		printerr("[LeaderboardAPI] No gameId found in client context for get_my_rank().")
		emit_signal("get_user_rank_failed", "NO_GAME_ID_CONTEXT")
		return
	
	# For current user, we can use a special endpoint that doesn't require userId
	# But for now, we'll use the same getUserRank with current user context
	# TODO: This would need the current user ID from the client context
	printerr("[LeaderboardAPI] get_my_rank() not fully implemented - need current user ID from client context")
	emit_signal("get_user_rank_failed", "NOT_IMPLEMENTED")

# Corresponds to client.leaderboard.getUserRank(gameId, userId) - gameId defaults to current game
func get_user_rank(user_id: String, game_id: String = ""):
	if _main_client == null:
		printerr("[LeaderboardAPI] Main client not set. Cannot call get_user_rank().")
		emit_signal("get_user_rank_failed", "MAIN_CLIENT_NULL")
		return

	if not ('leaderboard' in _main_client and 
			_main_client.leaderboard is JavaScriptObject and 
			'getUserRank' in _main_client.leaderboard):
		printerr("[LeaderboardAPI] client.leaderboard.getUserRank() path not found.")
		emit_signal("get_user_rank_failed", "METHOD_PATH_INVALID")
		return

	# Use provided gameId or default to current game context
	var resolved_game_id = game_id
	if resolved_game_id.is_empty():
		resolved_game_id = _main_client['gameId']
		if resolved_game_id == null:
			printerr("[LeaderboardAPI] No gameId provided and no gameId in client context.")
			emit_signal("get_user_rank_failed", "NO_GAME_ID_CONTEXT")
			return

	print("[LeaderboardAPI] Calling _main_client.leaderboard.getUserRank(%s, %s)..." % [resolved_game_id, user_id])
	var promise = _main_client.leaderboard.getUserRank(resolved_game_id, user_id)

	if not promise is JavaScriptObject:
		printerr("[LeaderboardAPI] leaderboard.getUserRank() did not return a Promise.")
		emit_signal("get_user_rank_failed", "NOT_A_PROMISE")
		return

	var on_resolve = Callable(self, "_on_get_user_rank_resolved").bind()
	var on_reject = Callable(self, "_on_get_user_rank_rejected").bind()

	_get_user_rank_resolve_cb_js = JavaScriptBridge.create_callback(on_resolve)
	_get_user_rank_reject_cb_js = JavaScriptBridge.create_callback(on_reject)

	promise.then(_get_user_rank_resolve_cb_js, _get_user_rank_reject_cb_js)
	print("[LeaderboardAPI] .then() called on leaderboard.getUserRank() promise.")

func _on_get_user_rank_resolved(args: Array):
	print("[LeaderboardAPI] Get user rank promise resolved. Args: ", args)
	if args.size() > 0:
		var result_data = args[0]
		emit_signal("get_user_rank_succeeded", result_data)
	else:
		emit_signal("get_user_rank_failed", "GET_USER_RANK_RESOLVED_NO_DATA")
	_clear_get_user_rank_callbacks()

func _on_get_user_rank_rejected(args: Array):
	print("[LeaderboardAPI] Get user rank promise rejected. Args: ", args)
	var error_message = "GET_USER_RANK_PROMISE_REJECTED"
	if args.size() > 0:
		error_message = str(args[0])
	emit_signal("get_user_rank_failed", error_message)
	_clear_get_user_rank_callbacks()

func _clear_get_user_rank_callbacks():
	_get_user_rank_resolve_cb_js = null
	_get_user_rank_reject_cb_js = null
