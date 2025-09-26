class_name LevelsAPI extends RefCounted

# Signals for get operation (user level info)
signal get_succeeded(level_data)
signal get_failed(error_message)

# Signals for progress operation
signal progress_succeeded(progress_data)
signal progress_failed(error_message)

# Signals for addXP operation
signal add_xp_succeeded(result_data)
signal add_xp_failed(error_message)

# Signals for config operations
signal config_list_succeeded(configs_data)
signal config_list_failed(error_message)
signal config_get_succeeded(config_data)
signal config_get_failed(error_message)

# Level system events (emitted when SDK events are received)
signal level_up(old_level, new_level, credits_awarded)
signal xp_gained(amount, total_xp_earned, leveled_up)

var _main_client: JavaScriptObject

# To keep JS callbacks alive for ongoing operations
var _get_resolve_cb_js: JavaScriptObject = null
var _get_reject_cb_js: JavaScriptObject = null
var _progress_resolve_cb_js: JavaScriptObject = null
var _progress_reject_cb_js: JavaScriptObject = null
var _add_xp_resolve_cb_js: JavaScriptObject = null
var _add_xp_reject_cb_js: JavaScriptObject = null
var _config_list_resolve_cb_js: JavaScriptObject = null
var _config_list_reject_cb_js: JavaScriptObject = null
var _config_get_resolve_cb_js: JavaScriptObject = null
var _config_get_reject_cb_js: JavaScriptObject = null

func _init(client_js_object: JavaScriptObject):
	_main_client = client_js_object
	print("[LevelsAPI] Initialized with client.")
	
	# TODO: Subscribe to the JS SDK's event bus for 'levelUp' and 'xpGained' events
	# and emit the corresponding Godot signals when those JS events fire.
	# This would require additional JavaScriptBridge.create_callback calls for event listeners:
	# - _main_client.on('levelUp', level_up_callback) 
	# - _main_client.on('xpGained', xp_gained_callback)
	# Currently we manually emit events based on API response data as a workaround.
	# This pattern should be implemented across all Godot SDK APIs for consistency.


# Corresponds to client.levels.get()
func get_level():
	if _main_client == null:
		printerr("[LevelsAPI] Main client not set. Cannot call get_level().")
		emit_signal("get_failed", "MAIN_CLIENT_NULL")
		return

	if not ('levels' in _main_client and 
			_main_client.levels is JavaScriptObject and 
			'get' in _main_client.levels):
		printerr("[LevelsAPI] client.levels.get() path not found.")
		emit_signal("get_failed", "METHOD_PATH_INVALID")
		return

	print("[LevelsAPI] Calling _main_client.levels.get()...")
	var promise = _main_client.levels.get()

	if not promise is JavaScriptObject:
		printerr("[LevelsAPI] levels.get() did not return a Promise.")
		emit_signal("get_failed", "NOT_A_PROMISE")
		return

	var on_resolve = Callable(self, "_on_get_resolved").bind()
	var on_reject = Callable(self, "_on_get_rejected").bind()

	_get_resolve_cb_js = JavaScriptBridge.create_callback(on_resolve)
	_get_reject_cb_js = JavaScriptBridge.create_callback(on_reject)

	promise.then(_get_resolve_cb_js, _get_reject_cb_js)
	print("[LevelsAPI] .then() called on levels.get() promise.")

func _on_get_resolved(args: Array):
	print("[LevelsAPI] Get level promise resolved. Args: ", args)
	if args.size() > 0:
		emit_signal("get_succeeded", args[0])
	else:
		emit_signal("get_failed", "GET_RESOLVED_NO_DATA")
	_clear_get_callbacks()

func _on_get_rejected(args: Array):
	print("[LevelsAPI] Get level promise rejected. Args: ", args)
	var error_msg = "GET_REJECTED_UNKNOWN"
	if args.size() > 0: error_msg = str(args[0])
	emit_signal("get_failed", error_msg)
	_clear_get_callbacks()

func _clear_get_callbacks():
	_get_resolve_cb_js = null
	_get_reject_cb_js = null


# Corresponds to client.levels.progress()
func progress():
	if _main_client == null:
		printerr("[LevelsAPI] Main client not set. Cannot call progress().")
		emit_signal("progress_failed", "MAIN_CLIENT_NULL")
		return

	if not ('levels' in _main_client and 
			_main_client.levels is JavaScriptObject and 
			'progress' in _main_client.levels):
		printerr("[LevelsAPI] client.levels.progress() path not found.")
		emit_signal("progress_failed", "METHOD_PATH_INVALID")
		return

	print("[LevelsAPI] Calling _main_client.levels.progress()...")
	var promise = _main_client.levels.progress()

	if not promise is JavaScriptObject:
		printerr("[LevelsAPI] levels.progress() did not return a Promise.")
		emit_signal("progress_failed", "NOT_A_PROMISE")
		return

	var on_resolve = Callable(self, "_on_progress_resolved").bind()
	var on_reject = Callable(self, "_on_progress_rejected").bind()

	_progress_resolve_cb_js = JavaScriptBridge.create_callback(on_resolve)
	_progress_reject_cb_js = JavaScriptBridge.create_callback(on_reject)

	promise.then(_progress_resolve_cb_js, _progress_reject_cb_js)
	print("[LevelsAPI] .then() called on levels.progress() promise.")

func _on_progress_resolved(args: Array):
	print("[LevelsAPI] Progress promise resolved. Args: ", args)
	if args.size() > 0:
		emit_signal("progress_succeeded", args[0])
	else:
		emit_signal("progress_failed", "PROGRESS_RESOLVED_NO_DATA")
	_clear_progress_callbacks()

func _on_progress_rejected(args: Array):
	print("[LevelsAPI] Progress promise rejected. Args: ", args)
	var error_msg = "PROGRESS_REJECTED_UNKNOWN"
	if args.size() > 0: error_msg = str(args[0])
	emit_signal("progress_failed", error_msg)
	_clear_progress_callbacks()

func _clear_progress_callbacks():
	_progress_resolve_cb_js = null
	_progress_reject_cb_js = null


# Corresponds to client.levels.addXP(amount)
func add_xp(amount: int):
	if _main_client == null:
		printerr("[LevelsAPI] Main client not set. Cannot call add_xp().")
		emit_signal("add_xp_failed", "MAIN_CLIENT_NULL")
		return

	if not ('levels' in _main_client and 
			_main_client.levels is JavaScriptObject and 
			'addXP' in _main_client.levels):
		printerr("[LevelsAPI] client.levels.addXP() path not found.")
		emit_signal("add_xp_failed", "METHOD_PATH_INVALID")
		return

	print("[LevelsAPI] Calling _main_client.levels.addXP(%d)..." % amount)
	var promise = _main_client.levels.addXP(amount)

	if not promise is JavaScriptObject:
		printerr("[LevelsAPI] levels.addXP() did not return a Promise.")
		emit_signal("add_xp_failed", "NOT_A_PROMISE")
		return

	var on_resolve = Callable(self, "_on_add_xp_resolved").bind()
	var on_reject = Callable(self, "_on_add_xp_rejected").bind()

	_add_xp_resolve_cb_js = JavaScriptBridge.create_callback(on_resolve)
	_add_xp_reject_cb_js = JavaScriptBridge.create_callback(on_reject)

	promise.then(_add_xp_resolve_cb_js, _add_xp_reject_cb_js)
	print("[LevelsAPI] .then() called on levels.addXP() promise.")

func _on_add_xp_resolved(args: Array):
	print("[LevelsAPI] Add XP promise resolved. Args: ", args)
	if args.size() > 0:
		var result_data = args[0]
		emit_signal("add_xp_succeeded", result_data)
		
		# Emit level system events based on the result
		if result_data != null and result_data is JavaScriptObject:
			if result_data.hasOwnProperty("leveledUp") and result_data.leveledUp:
				var old_level = result_data.newLevel - 1  # This is a simplification
				emit_signal("level_up", old_level, result_data.newLevel, result_data.creditsAwarded)
			
			if result_data.hasOwnProperty("totalXP"):
				emit_signal("xp_gained", result_data.totalXP, result_data.totalXP, result_data.leveledUp)
	else:
		emit_signal("add_xp_failed", "ADD_XP_RESOLVED_NO_DATA")
	_clear_add_xp_callbacks()

func _on_add_xp_rejected(args: Array):
	print("[LevelsAPI] Add XP promise rejected. Args: ", args)
	var error_msg = "ADD_XP_REJECTED_UNKNOWN"
	if args.size() > 0: error_msg = str(args[0])
	emit_signal("add_xp_failed", error_msg)
	_clear_add_xp_callbacks()

func _clear_add_xp_callbacks():
	_add_xp_resolve_cb_js = null
	_add_xp_reject_cb_js = null


# Corresponds to client.levels.config.list()
func config_list():
	if _main_client == null:
		printerr("[LevelsAPI] Main client not set. Cannot call config_list().")
		emit_signal("config_list_failed", "MAIN_CLIENT_NULL")
		return

	if not ('levels' in _main_client and 
			_main_client.levels is JavaScriptObject and 
			'config' in _main_client.levels and
			_main_client.levels.config is JavaScriptObject and
			'list' in _main_client.levels.config):
		printerr("[LevelsAPI] client.levels.config.list() path not found.")
		emit_signal("config_list_failed", "METHOD_PATH_INVALID")
		return

	print("[LevelsAPI] Calling _main_client.levels.config.list()...")
	var promise = _main_client.levels.config.list()

	if not promise is JavaScriptObject:
		printerr("[LevelsAPI] levels.config.list() did not return a Promise.")
		emit_signal("config_list_failed", "NOT_A_PROMISE")
		return

	var on_resolve = Callable(self, "_on_config_list_resolved").bind()
	var on_reject = Callable(self, "_on_config_list_rejected").bind()

	_config_list_resolve_cb_js = JavaScriptBridge.create_callback(on_resolve)
	_config_list_reject_cb_js = JavaScriptBridge.create_callback(on_reject)

	promise.then(_config_list_resolve_cb_js, _config_list_reject_cb_js)
	print("[LevelsAPI] .then() called on levels.config.list() promise.")

func _on_config_list_resolved(args: Array):
	print("[LevelsAPI] Config list promise resolved. Args: ", args)
	if args.size() > 0:
		emit_signal("config_list_succeeded", args[0])
	else:
		emit_signal("config_list_failed", "CONFIG_LIST_RESOLVED_NO_DATA")
	_clear_config_list_callbacks()

func _on_config_list_rejected(args: Array):
	print("[LevelsAPI] Config list promise rejected. Args: ", args)
	var error_msg = "CONFIG_LIST_REJECTED_UNKNOWN"
	if args.size() > 0: error_msg = str(args[0])
	emit_signal("config_list_failed", error_msg)
	_clear_config_list_callbacks()

func _clear_config_list_callbacks():
	_config_list_resolve_cb_js = null
	_config_list_reject_cb_js = null


# Corresponds to client.levels.config.get(level)
func config_get(level: int):
	if _main_client == null:
		printerr("[LevelsAPI] Main client not set. Cannot call config_get().")
		emit_signal("config_get_failed", "MAIN_CLIENT_NULL")
		return

	if not ('levels' in _main_client and 
			_main_client.levels is JavaScriptObject and 
			'config' in _main_client.levels and
			_main_client.levels.config is JavaScriptObject and
			'get' in _main_client.levels.config):
		printerr("[LevelsAPI] client.levels.config.get() path not found.")
		emit_signal("config_get_failed", "METHOD_PATH_INVALID")
		return

	print("[LevelsAPI] Calling _main_client.levels.config.get(%d)..." % level)
	var promise = _main_client.levels.config.get(level)

	if not promise is JavaScriptObject:
		printerr("[LevelsAPI] levels.config.get() did not return a Promise.")
		emit_signal("config_get_failed", "NOT_A_PROMISE")
		return

	var on_resolve = Callable(self, "_on_config_get_resolved").bind()
	var on_reject = Callable(self, "_on_config_get_rejected").bind()

	_config_get_resolve_cb_js = JavaScriptBridge.create_callback(on_resolve)
	_config_get_reject_cb_js = JavaScriptBridge.create_callback(on_reject)

	promise.then(_config_get_resolve_cb_js, _config_get_reject_cb_js)
	print("[LevelsAPI] .then() called on levels.config.get() promise.")

func _on_config_get_resolved(args: Array):
	print("[LevelsAPI] Config get promise resolved. Args: ", args)
	if args.size() > 0:
		emit_signal("config_get_succeeded", args[0])
	else:
		emit_signal("config_get_failed", "CONFIG_GET_RESOLVED_NO_DATA")
	_clear_config_get_callbacks()

func _on_config_get_rejected(args: Array):
	print("[LevelsAPI] Config get promise rejected. Args: ", args)
	var error_msg = "CONFIG_GET_REJECTED_UNKNOWN"
	if args.size() > 0: error_msg = str(args[0])
	emit_signal("config_get_failed", error_msg)
	_clear_config_get_callbacks()

func _clear_config_get_callbacks():
	_config_get_resolve_cb_js = null
	_config_get_reject_cb_js = null 