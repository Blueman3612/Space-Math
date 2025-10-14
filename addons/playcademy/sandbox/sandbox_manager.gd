@tool
extends Node
class_name PlaycademySandboxManager

signal sandbox_started(url: String)
signal sandbox_stopped()
signal sandbox_failed(error: String)
signal status_changed(status: String)

enum SandboxStatus {
	STOPPED,
	STARTING,
	RUNNING,
	STOPPING,
	ERROR
}

var current_status: SandboxStatus = SandboxStatus.STOPPED
var sandbox_url: String = ""
var sandbox_port: int = 4321
var sandbox_process: int = -1

# Project settings keys
const SETTING_AUTO_START = "playcademy/sandbox/auto_start"
const SETTING_PORT = "playcademy/sandbox/port"
const SETTING_VERBOSE = "playcademy/sandbox/verbose"

func _ready():
	# Initialize project settings with defaults
	_ensure_project_settings()

func _ensure_project_settings():
	if not ProjectSettings.has_setting(SETTING_AUTO_START):
		ProjectSettings.set_setting(SETTING_AUTO_START, true)
	
	if not ProjectSettings.has_setting(SETTING_PORT):
		ProjectSettings.set_setting(SETTING_PORT, 4321)
	
	if not ProjectSettings.has_setting(SETTING_VERBOSE):
		ProjectSettings.set_setting(SETTING_VERBOSE, false)
	
	# Save settings
	ProjectSettings.save()

func is_auto_start_enabled() -> bool:
	return ProjectSettings.get_setting(SETTING_AUTO_START, true)

func get_sandbox_port() -> int:
	return ProjectSettings.get_setting(SETTING_PORT, 4321)

func is_verbose_enabled() -> bool:
	return ProjectSettings.get_setting(SETTING_VERBOSE, false)

func auto_start_if_enabled():
	if is_auto_start_enabled():
		start_sandbox()

func ensure_sandbox_running():
	if current_status != SandboxStatus.RUNNING:
		start_sandbox()

func start_sandbox():
	if current_status == SandboxStatus.RUNNING or current_status == SandboxStatus.STARTING:
		return
	
	_set_status(SandboxStatus.STARTING)
	
	var port = get_sandbox_port()
	var verbose = is_verbose_enabled()
	
	# Check if we have npm or bun available
	var runtime_info = _find_js_runtime()
	if runtime_info.is_empty():
		_handle_error("Neither npm nor bun found. Please install Node.js (npm) or Bun:\n• npm: https://nodejs.org\n• bun: curl -fsSL https://bun.sh/install | bash")
		return
	
	var runtime_path = runtime_info["path"]
	var runtime_type = runtime_info["type"]
	
	# Prepare command arguments based on runtime
	print("[PlaycademySandbox] Using runtime: %s" % [runtime_type])
	
	var args = []
	if runtime_type == "npm":
		args = [
			"@playcademy/sandbox",
			"--port", str(port)
		]
	else:  # bun
		args = [
			"x",
			"@playcademy/sandbox",
			"--port", str(port)
		]
	
	if verbose:
		args.append("--verbose")
	
	# Extract project info for seeding
	var project_name = ProjectSettings.get_setting("application/config/name", "godot-game")
	var project_slug = project_name.to_lower().replace(" ", "-")
	args.append_array(["--project-name", project_name])
	args.append_array(["--project-slug", project_slug])
	
	# Log the command being run
	print("[PlaycademySandbox] Starting sandbox with command: %s %s" % [runtime_path, " ".join(args)])
	
	# Start the process
	sandbox_process = OS.create_process(runtime_path, args)
	
	if sandbox_process == -1:
		var install_cmd = "npm install -g @playcademy/sandbox" if runtime_type == "npm" else "bun add -g @playcademy/sandbox"
		_handle_error("Failed to start sandbox. The @playcademy/sandbox package may not be installed. Try: " + install_cmd)
		return
	
	print("[PlaycademySandbox] Sandbox process started (PID: %d), waiting for startup..." % sandbox_process)
	
	# Wait for the process to fully start and bind to a port (can take up to 5 seconds)
	await get_tree().create_timer(5.0).timeout
	print("[PlaycademySandbox] Startup wait complete, discovering actual port...")
	_check_sandbox_health()

func stop_sandbox():
	if current_status == SandboxStatus.STOPPED or current_status == SandboxStatus.STOPPING:
		return
	
	_set_status(SandboxStatus.STOPPING)
	
	if sandbox_process != -1:
		# Kill the process and all its children
		# The PID from create_process is just the wrapper (npx/bun), 
		# so we need to kill the entire process group
		_kill_process_tree(sandbox_process)
		sandbox_process = -1
	
	# Also try to kill any process listening on the sandbox port as a backup
	if sandbox_port > 0:
		_kill_process_on_port(sandbox_port)
	
	sandbox_url = ""
	_set_status(SandboxStatus.STOPPED)
	emit_signal("sandbox_stopped")

func restart_sandbox():
	stop_sandbox()
	await get_tree().create_timer(1.0).timeout
	start_sandbox()

func get_status() -> SandboxStatus:
	return current_status

func get_status_string() -> String:
	match current_status:
		SandboxStatus.STOPPED:
			return "Stopped"
		SandboxStatus.STARTING:
			return "Starting..."
		SandboxStatus.RUNNING:
			return "Running"
		SandboxStatus.STOPPING:
			return "Stopping..."
		SandboxStatus.ERROR:
			return "Error"
		_:
			return "Unknown"

func get_sandbox_url() -> String:
	return sandbox_url

func _set_status(status: SandboxStatus):
	if current_status != status:
		current_status = status
		emit_signal("status_changed", get_status_string())

func _handle_error(error_message: String):
	print("[PlaycademySandbox] Error: ", error_message)
	_set_status(SandboxStatus.ERROR)
	emit_signal("sandbox_failed", error_message)

func _find_js_runtime() -> Dictionary:
	# Try bun first (faster), then npm/npx as fallback
	var runtimes = [
		{"type": "bun", "detect_cmd": "bun", "run_cmd": "bun"},
		{"type": "npm", "detect_cmd": "npm", "run_cmd": "npx"}
	]
	
	for runtime in runtimes:
		var paths = _get_runtime_paths(runtime.detect_cmd)
		for path in paths:
			if _test_runtime_executable(path):
				# Replace the detection command with the run command in the path
				var run_path = path.replace(runtime.detect_cmd, runtime.run_cmd)
				return {"type": runtime.type, "path": run_path}
	
	return {}

func _get_runtime_paths(cmd: String) -> Array:
	var possible_paths = []
	
	# Add common system paths
	if OS.get_name() == "macOS" or OS.get_name() == "Linux":
		var home = OS.get_environment("HOME")
		if cmd == "npm":
			possible_paths.append_array([
				"/usr/local/bin/npm",
				"/opt/homebrew/bin/npm",
				"/usr/bin/npm",
				home + "/.nvm/versions/node/*/bin/npm"
			])
		else:  # bun
			possible_paths.append_array([
				"/usr/local/bin/bun",
				"/opt/homebrew/bin/bun",
				"/usr/bin/bun",
				home + "/.bun/bin/bun"
			])
	elif OS.get_name() == "Windows":
		var username = OS.get_environment("USERNAME")
		if cmd == "npm":
			possible_paths.append_array([
				"C:\\Program Files\\nodejs\\npm.cmd",
				"C:\\Users\\" + username + "\\AppData\\Roaming\\npm\\npm.cmd",
				"npm.cmd"
			])
		else:  # bun
			possible_paths.append_array([
				"C:\\Users\\" + username + "\\.bun\\bin\\bun.exe",
				"bun.exe"
			])
	
	# Also try just the command name in case it's in PATH
	possible_paths.append(cmd)
	
	return possible_paths

func _test_runtime_executable(path: String) -> bool:
	# Test if the executable exists and works
	var output = []
	var exit_code = OS.execute(path, ["--version"], output)
	return exit_code == 0



var _port_scan_index = 0
var _port_scan_range = [4321, 4322, 4323, 4324, 4325, 4326, 4327, 4328, 4329, 4330]
var _discovered_port: int = 0

func _check_sandbox_health():
	# Discover the actual port the sandbox is running on
	_port_scan_index = 0
	_discover_sandbox_port()

func _discover_sandbox_port():
	if _port_scan_index >= _port_scan_range.size():
		_handle_error("Sandbox process started but not responding on any port 4321-4330. The process may have crashed or failed to bind to a port.")
		return
	
	var port = _port_scan_range[_port_scan_index]
	var health_url = "http://localhost:%d/health" % port
	
	print("[PlaycademySandbox] Checking for sandbox on port %d... (attempt %d/%d)" % [port, _port_scan_index + 1, _port_scan_range.size()])
	
	var http_request = HTTPRequest.new()
	add_child(http_request)
	http_request.request_completed.connect(_on_port_scan_completed)
	http_request.timeout = 2.0
	
	var error = http_request.request(health_url)
	if error != OK:
		print("[PlaycademySandbox] Failed to make request to port %d: %s" % [port, error])
		http_request.queue_free()
		_try_next_port()

func _on_port_scan_completed(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray):
	# Find and clean up the HTTPRequest node
	for child in get_children():
		if child is HTTPRequest:
			child.queue_free()
			break
	
	var current_port = _port_scan_range[_port_scan_index]
	
	if response_code == 200:
		print("[PlaycademySandbox] Found sandbox running on port %d!" % current_port)
		_discovered_port = current_port
		sandbox_port = current_port
		sandbox_url = "http://localhost:%d/api" % current_port
		_set_status(SandboxStatus.RUNNING)
		emit_signal("sandbox_started", sandbox_url)
		print("[PlaycademySandbox] Sandbox is running at: ", sandbox_url)
	else:
		# Handle timeout, connection refused, or other HTTP errors
		if result == HTTPRequest.RESULT_TIMEOUT:
			print("[PlaycademySandbox] Port %d timed out, trying next port..." % current_port)
		elif response_code == 0:
			print("[PlaycademySandbox] Port %d connection failed, trying next port..." % current_port)
		else:
			print("[PlaycademySandbox] Port %d returned HTTP %d, trying next port..." % [current_port, response_code])
		_try_next_port()

func _try_next_port():
	_port_scan_index += 1
	_discover_sandbox_port()

func _kill_process_tree(pid: int):
	"""Kill a process and all its children"""
	print("[PlaycademySandbox] Killing process tree for PID %d" % pid)
	
	if OS.get_name() == "Windows":
		# Windows: Use taskkill to kill process tree
		OS.execute("taskkill", ["/F", "/T", "/PID", str(pid)])
	else:
		# Unix-like (macOS, Linux): Kill the process group
		# First try with SIGTERM (graceful)
		OS.execute("kill", ["-TERM", str(pid)])
		# Wait a moment
		OS.delay_msec(500)
		# Then force kill with SIGKILL if still running
		OS.execute("kill", ["-9", str(pid)])

func _kill_process_on_port(port: int):
	"""Kill any process listening on the specified port"""
	print("[PlaycademySandbox] Killing process on port %d" % port)
	
	if OS.get_name() == "Windows":
		# Windows: Find and kill process on port
		var output = []
		OS.execute("cmd", ["/c", "netstat -ano | findstr :%d" % port], output)
		if output.size() > 0:
			var line = output[0]
			# Extract PID from netstat output
			var parts = line.split(" ", false)
			if parts.size() > 0:
				var pid = parts[-1].strip_edges()
				OS.execute("taskkill", ["/F", "/PID", pid])
	elif OS.get_name() == "macOS":
		# macOS: Use lsof to find and kill process
		OS.execute("sh", ["-c", "lsof -ti tcp:%d | xargs kill -9" % port])
	else:
		# Linux: Use fuser to kill process on port
		OS.execute("fuser", ["-k", "%d/tcp" % port])

func _exit_tree():
	stop_sandbox() 
