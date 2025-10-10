extends Node

# Main SDK Signals
signal sdk_ready
signal sdk_initialization_failed(error_message)

const UsersAPIWeb = preload("res://addons/playcademy/sdk/apis/users_api_web.gd")
const RuntimeAPIWeb = preload("res://addons/playcademy/sdk/apis/runtime_api_web.gd")
const InventoryAPIWeb = preload("res://addons/playcademy/sdk/apis/inventory_api_web.gd")
const LevelsAPIWeb = preload("res://addons/playcademy/sdk/apis/levels_api_web.gd")
const CreditsAPIWeb = preload("res://addons/playcademy/sdk/apis/credits_api_web.gd")
const LeaderboardAPIWeb = preload("res://addons/playcademy/sdk/apis/leaderboard_api_web.gd")
const ScoresAPIWeb = preload("res://addons/playcademy/sdk/apis/scores_api_web.gd")
const TimebackAPIWeb = preload("res://addons/playcademy/sdk/apis/timeback_api_web.gd")
const BackendAPIWeb = preload("res://addons/playcademy/sdk/apis/backend_api_web.gd")

var playcademy_client: JavaScriptObject = null
var is_sdk_initialized := false

# --- Public Sub-APIs ---
var users
var runtime
var inventory
var levels
var credits
var leaderboard
var scores
var timeback
var backend

# --- Main PlaycademySDK Methods ---
func _ready():
	print("[PlaycademySDK.gd] SDK Node Initializing...")

	if not OS.has_feature("web"):
		print("[PlaycademySDK.gd] Not a web build. Checking for local development sandbox...")
		_try_local_sandbox_connection()
		return

	var js_window = JavaScriptBridge.get_interface("window")
	if js_window == null:
		print("[PlaycademySDK.gd] Failed to get JS window object.")
		emit_signal("sdk_initialization_failed", "NO_JS_WINDOW")
		return

	var sdk_init_cb = Callable(self, "_on_sdk_initialized_from_js").bind()
	js_window.godotPlaycademySDKInitializedCallback = JavaScriptBridge.create_callback(sdk_init_cb)
	print("[PlaycademySDK.gd] JS callback 'godotPlaycademySDKInitializedCallback' registered.")

	var sdk_fail_cb = Callable(self, "_on_sdk_initialization_failed_from_js").bind()
	js_window.godotPlaycademySDKInitializationFailedCallback = JavaScriptBridge.create_callback(sdk_fail_cb)
	print("[PlaycademySDK.gd] JS failure callback 'godotPlaycademySDKInitializationFailedCallback' registered.")
	
	var js_sdk_ready_flag = js_window.isPlaycademyReady
	if js_sdk_ready_flag == true:
		var client_from_js_direct = js_window.playcademyClient
		if client_from_js_direct is JavaScriptObject:
			_on_sdk_initialized_from_js([client_from_js_direct])
		else:
			_on_sdk_initialization_failed_from_js(["Playcademy is ready but client is invalid (direct check)"])
	else:
		print("[PlaycademySDK.gd] SDK not yet ready. Waiting for JS callback.")


func _on_sdk_initialized_from_js(args_array: Array):
	if is_sdk_initialized:
		return

	if args_array.size() > 0 and args_array[0] is JavaScriptObject:
		playcademy_client = args_array[0]
		is_sdk_initialized = true
		
		users = UsersAPIWeb.new(playcademy_client)
		if users == null:
			printerr("[PlaycademySDK.gd] CRITICAL: UsersAPIWeb failed to instantiate!")
			_on_sdk_initialization_failed_from_js(["UsersAPI_INSTANTIATION_FAILED"])
			return

		runtime = RuntimeAPIWeb.new(playcademy_client)
		if runtime == null:
			printerr("[PlaycademySDK.gd] CRITICAL: RuntimeAPIWeb failed to instantiate!")
			_on_sdk_initialization_failed_from_js(["RuntimeAPI_INSTANTIATION_FAILED"])
			return

		inventory = InventoryAPIWeb.new(playcademy_client)
		if inventory == null:
			printerr("[PlaycademySDK.gd] CRITICAL: InventoryAPIWeb failed to instantiate!")
			_on_sdk_initialization_failed_from_js(["InventoryAPI_INSTANTIATION_FAILED"])
			return

		levels = LevelsAPIWeb.new(playcademy_client)
		if levels == null:
			printerr("[PlaycademySDK.gd] CRITICAL: LevelsAPIWeb failed to instantiate!")
			_on_sdk_initialization_failed_from_js(["LevelsAPI_INSTANTIATION_FAILED"])
			return

		credits = CreditsAPIWeb.new(inventory)
		if credits == null:
			printerr("[PlaycademySDK.gd] CRITICAL: CreditsAPIWeb failed to instantiate!")
			_on_sdk_initialization_failed_from_js(["CreditsAPI_INSTANTIATION_FAILED"])
			return

		leaderboard = LeaderboardAPIWeb.new(playcademy_client)
		if leaderboard == null:
			printerr("[PlaycademySDK.gd] CRITICAL: LeaderboardAPIWeb failed to instantiate!")
			_on_sdk_initialization_failed_from_js(["LeaderboardAPI_INSTANTIATION_FAILED"])
			return

		scores = ScoresAPIWeb.new(playcademy_client)
		if scores == null:
			printerr("[PlaycademySDK.gd] CRITICAL: ScoresAPIWeb failed to instantiate!")
			_on_sdk_initialization_failed_from_js(["ScoresAPI_INSTANTIATION_FAILED"])
			return

		timeback = TimebackAPIWeb.new(playcademy_client)
		if timeback == null:
			printerr("[PlaycademySDK.gd] CRITICAL: TimebackAPIWeb failed to instantiate!")
			_on_sdk_initialization_failed_from_js(["TimebackAPI_INSTANTIATION_FAILED"])
			return

		backend = BackendAPIWeb.new(playcademy_client)
		if backend == null:
			printerr("[PlaycademySDK.gd] CRITICAL: BackendAPIWeb failed to instantiate!")
			_on_sdk_initialization_failed_from_js(["BackendAPI_INSTANTIATION_FAILED"])
			return

		print("[PlaycademySDK.gd] Main Client assigned. Sub-APIs (Users, Runtime, Inventory, Levels, Credits, Leaderboard, Scores, Timeback, Backend) instantiated.")
		emit_signal("sdk_ready")
		test_sdk_ping()
	else:
		var error_msg = "SDK init callback: Invalid or no client argument."
		if args_array.size() > 0:
			error_msg = "SDK init callback: Argument was not a JavaScriptObject. Type: %s" % typeof(args_array[0])
		else:
			error_msg = "SDK init callback: No arguments received from JS."
		print("[PlaycademySDK.gd] ERROR: %s" % error_msg)
		_on_sdk_initialization_failed_from_js([error_msg])


func _on_sdk_initialization_failed_from_js(args_array: Array):
	if is_sdk_initialized: return 

	var error_message = "SDK_INIT_FAILED_UNKNOWN"
	if args_array.size() > 0:
		error_message = str(args_array[0])
	print("[PlaycademySDK.gd] SDK Initialization FAILED. Error: ", error_message)
	emit_signal("sdk_initialization_failed", error_message)
	_cleanup_js_callbacks()


func is_ready() -> bool:
	return is_sdk_initialized

func get_client_js_object() -> JavaScriptObject:
	if not is_ready():
		printerr("[PlaycademySDK] SDK not ready. Cannot get client JSObject.")
	return playcademy_client

func ping() -> String:
	if not is_ready() or playcademy_client == null:
		printerr("[PlaycademySDK] Cannot ping: SDK not ready or client null.")
		return "ERROR: SDK_NOT_READY"
	
	print("[PlaycademySDK] GDScript wrapper calling client.ping()...")
	var result = playcademy_client.ping()
	print("[PlaycademySDK] Ping direct result from JS: ", result)
	return str(result)

func test_sdk_ping():
	if not is_ready() or playcademy_client == null:
		print("[PlaycademySDK] test_sdk_ping (auto): SDK not ready or client null.")
		return
	var ping_result = ping()
	print("[PlaycademySDK] Auto-Ping result (via wrapper): ", ping_result)


func _cleanup_js_callbacks():
	print("[PlaycademySDK.gd] Cleaning up JS callbacks from window object...")
	var js_window = JavaScriptBridge.get_interface("window")
	if js_window != null:
		if 'godotPlaycademySDKInitializedCallback' in js_window:
			js_window.godotPlaycademySDKInitializedCallback = null
		if 'godotPlaycademySDKInitializationFailedCallback' in js_window:
			js_window.godotPlaycademySDKInitializationFailedCallback = null

func _exit_tree():
	_cleanup_js_callbacks()

# Local development sandbox support
func _try_local_sandbox_connection():
	print("[PlaycademySDK.gd] Attempting to connect to local development sandbox...")
	
	# Try to discover the actual sandbox port (it may not be 4321 if that port was busy)
	_discover_sandbox_port()

var _port_scan_index = 0
var _port_scan_range = [4321, 4322, 4323, 4324, 4325, 4326, 4327, 4328, 4329, 4330]

func _discover_sandbox_port():
	if _port_scan_index >= _port_scan_range.size():
		_handle_sandbox_connection_failed("No sandbox found on ports 4321-4330")
		return
	
	var port = _port_scan_range[_port_scan_index]
	var health_url = "http://localhost:%d/health" % port
	
	print("[PlaycademySDK.gd] Scanning for sandbox on port %d..." % port)
	
	var http_request = HTTPRequest.new()
	add_child(http_request)
	http_request.request_completed.connect(_on_port_scan_result)
	
	http_request.timeout = 2.0
	
	var error = http_request.request(health_url)
	if error != OK:
		print("[PlaycademySDK.gd] Failed to make request to port %d: %s" % [port, error])
		http_request.queue_free()
		_try_next_port()

func _on_port_scan_result(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray):
	# Find and clean up the HTTPRequest node
	for child in get_children():
		if child is HTTPRequest:
			child.queue_free()
			break
	
	var current_port = _port_scan_range[_port_scan_index]
	
	if response_code == 200:
		print("[PlaycademySDK.gd] Found sandbox running on port %d!" % current_port)
		_found_sandbox_port = current_port
		_initialize_mock_client()
	else:
		# Handle timeout, connection refused, or other HTTP errors
		if result == HTTPRequest.RESULT_TIMEOUT:
			print("[PlaycademySDK.gd] Port %d timed out, trying next port..." % current_port)
		elif response_code == 0:
			print("[PlaycademySDK.gd] Port %d connection failed, trying next port..." % current_port)
		else:
			print("[PlaycademySDK.gd] Port %d returned HTTP %d, trying next port..." % [current_port, response_code])
		_try_next_port()

func _try_next_port():
	_port_scan_index += 1
	_discover_sandbox_port()

var _found_sandbox_port: int = 0

func _initialize_mock_client():
	# Communicate with the local sandbox via HTTP using the discovered port
	var sandbox_api_url = "http://localhost:%d/api" % _found_sandbox_port
	# Game backend runs on different port (matches TypeScript SDK gameUrl)
	var game_backend_url = "http://localhost:8788/api"

	is_sdk_initialized = true

	# Instantiate local HTTP-based wrappers
	# For local development, let the sandbox handle game context server-side
	users = preload("res://addons/playcademy/sdk/local/local_users_api.gd").new(sandbox_api_url)
	runtime = preload("res://addons/playcademy/sdk/local/local_runtime_api.gd").new(sandbox_api_url)
	inventory = preload("res://addons/playcademy/sdk/local/local_inventory_api.gd").new(sandbox_api_url)
	levels = preload("res://addons/playcademy/sdk/local/local_levels_api.gd").new(sandbox_api_url)
	credits = preload("res://addons/playcademy/sdk/local/local_credits_api.gd").new(inventory)
	leaderboard = preload("res://addons/playcademy/sdk/local/local_leaderboard_api.gd").new(sandbox_api_url)
	scores = preload("res://addons/playcademy/sdk/local/local_scores_api.gd").new(sandbox_api_url)
	timeback = preload("res://addons/playcademy/sdk/local/local_timeback_api.gd").new(game_backend_url)
	backend = preload("res://addons/playcademy/sdk/local/local_backend_api.gd").new(game_backend_url)

	add_child(users)
	add_child(runtime)
	add_child(inventory)
	add_child(levels)
	add_child(leaderboard)
	add_child(scores)
	add_child(timeback)
	add_child(backend)

	emit_signal("sdk_ready")


func _handle_sandbox_connection_failed(error_message: String):
	print("[PlaycademySDK.gd] Local development mode unavailable: ", error_message)
	print("[PlaycademySDK.gd] SDK will initialize in offline mode")
	emit_signal("sdk_initialization_failed", "LOCAL_DEVELOPMENT_UNAVAILABLE")

# Example callback function if needed later
# func _on_js_event(args_array):
# 	 print("[PlaycademySDK.gd] Received event from JS: ", args_array) 
