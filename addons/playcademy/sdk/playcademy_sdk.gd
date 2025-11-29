extends Node

# Main SDK Signals
signal sdk_ready
signal sdk_initialization_failed(error_message)

const UsersAPIWeb = preload("res://addons/playcademy/sdk/apis/users_api_web.gd")
const RuntimeAPIWeb = preload("res://addons/playcademy/sdk/apis/runtime_api_web.gd")
const CreditsAPIWeb = preload("res://addons/playcademy/sdk/apis/credits_api_web.gd")
const ScoresAPIWeb = preload("res://addons/playcademy/sdk/apis/scores_api_web.gd")
const TimebackAPIWeb = preload("res://addons/playcademy/sdk/apis/timeback_api_web.gd")
const BackendAPIWeb = preload("res://addons/playcademy/sdk/apis/backend_api_web.gd")

var playcademy_client: JavaScriptObject = null
var is_sdk_initialized := false

# --- Public SDK Namespaces ---
# Implemented (6/8):
var users      # User profile + inventory management
var runtime    # getGameToken, exit
var backend    # Custom game API routes
var credits    # Credits management
var scores     # Submit scores
var timeback   # TimeBack XP tracking

# Not yet implemented (2/8):
# identity - OAuth connections
# realtime - WebSocket multiplayer tokens

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

		credits = CreditsAPIWeb.new(users)
		if credits == null:
			printerr("[PlaycademySDK.gd] CRITICAL: CreditsAPIWeb failed to instantiate!")
			_on_sdk_initialization_failed_from_js(["CreditsAPI_INSTANTIATION_FAILED"])
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

		print("[PlaycademySDK.gd] Main Client assigned. Game SDK namespaces instantiated: users (+ inventory), runtime, credits, scores, timeback, backend")
		emit_signal("sdk_ready")
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
	
	var result = playcademy_client.ping()
	return str(result)


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
	_initialize_mock_client()

func _initialize_mock_client():
	# Read server info from per-user registry
	var home = OS.get_environment("HOME")
	var registry_path = home + "/.playcademy/.proc"
	
	# Defaults (fallback if registry doesn't exist)
	var sandbox_api_url = "http://localhost:4321/api"
	var game_backend_url = "http://localhost:8788/api"
	
	# Try to discover actual URLs from registry
	var file = FileAccess.open(registry_path, FileAccess.READ)
	if file:
		var json_result = JSON.parse_string(file.get_as_text())
		file.close()
		
		if json_result != null:
			var registry = json_result
			var my_project = ProjectSettings.globalize_path("res://").rstrip("/")  # Remove trailing slash
			
			# Find servers for this project
			for key in registry:
				var server = registry[key]
				if server.projectRoot == my_project:
					if key.begins_with("sandbox-"):
						sandbox_api_url = server.url
						print("[PlaycademySDK.gd] Found sandbox from registry: ", sandbox_api_url)
					elif key.begins_with("backend-"):
						game_backend_url = server.url
						print("[PlaycademySDK.gd] Found backend from registry: ", game_backend_url)

	is_sdk_initialized = true

	# Instantiate local HTTP-based wrappers (aligned with public game SDK)
	# For local development, let the sandbox handle game context server-side
	users = preload("res://addons/playcademy/sdk/local/local_users_api.gd").new(sandbox_api_url)
	runtime = preload("res://addons/playcademy/sdk/local/local_runtime_api.gd").new(sandbox_api_url)
	credits = preload("res://addons/playcademy/sdk/local/local_credits_api.gd").new(users)
	scores = preload("res://addons/playcademy/sdk/local/local_scores_api.gd").new(sandbox_api_url)
	timeback = preload("res://addons/playcademy/sdk/local/local_timeback_api.gd").new(game_backend_url, sandbox_api_url)
	backend = preload("res://addons/playcademy/sdk/local/local_backend_api.gd").new(game_backend_url)

	add_child(users)
	add_child(runtime)
	add_child(scores)
	add_child(timeback)
	add_child(backend)
	
	# Fetch TimeBack user context (role and enrollments)
	timeback.fetch_user_context()

	print("[PlaycademySDK.gd] Local development mode: Game SDK namespaces ready (users + inventory, runtime, credits, scores, timeback, backend)")
	emit_signal("sdk_ready")


func _handle_sandbox_connection_failed(error_message: String):
	print("[PlaycademySDK.gd] Local development mode unavailable: ", error_message)
	print("[PlaycademySDK.gd] SDK will initialize in offline mode")
	emit_signal("sdk_initialization_failed", "LOCAL_DEVELOPMENT_UNAVAILABLE")

# Example callback function if needed later
# func _on_js_event(args_array):
# 	 print("[PlaycademySDK.gd] Received event from JS: ", args_array) 
