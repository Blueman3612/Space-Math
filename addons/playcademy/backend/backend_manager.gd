@tool
extends Node
class_name PlaycademyBackendManager

signal sandbox_started(url: String)
signal backend_started(url: String)
signal servers_stopped()
signal server_failed(server_type: String, error: String)
signal status_changed(status: String)

enum ServerStatus {
	STOPPED,
	STARTING,
	RUNNING,
	STOPPING,
	ERROR
}

var sandbox_status: ServerStatus = ServerStatus.STOPPED
var backend_status: ServerStatus = ServerStatus.STOPPED
var sandbox_url: String = ""
var backend_url: String = ""
var sandbox_port: int = 4321
var backend_port: int = 8788
var sandbox_process: int = -1
var backend_process: int = -1
var sandbox_log_path: String = ""
var backend_log_path: String = ""

# Project settings keys - Sandbox
const SETTING_SANDBOX_AUTO_START = "playcademy/sandbox/auto_start"
const SETTING_SANDBOX_PORT = "playcademy/sandbox/port"
const SETTING_SANDBOX_VERBOSE = "playcademy/sandbox/verbose"
const SETTING_SANDBOX_URL = "playcademy/sandbox/url"

# Project settings keys - Backend
const SETTING_BACKEND_AUTO_START = "playcademy/backend/auto_start"
const SETTING_BACKEND_PORT = "playcademy/backend/port"
const SETTING_BACKEND_PROJECT_PATH = "playcademy/backend/project_path"

# Project settings keys - Timeback
const SETTING_TIMEBACK_STUDENT_ID = "playcademy/timeback/student_id"
const SETTING_TIMEBACK_ROLE = "playcademy/timeback/role"
const SETTING_TIMEBACK_ORG_ID = "playcademy/timeback/organization_id"
const SETTING_TIMEBACK_ORG_NAME = "playcademy/timeback/organization_name"
const SETTING_TIMEBACK_ORG_TYPE = "playcademy/timeback/organization_type"

# Dynamic course enrollment settings prefix
const SETTING_TIMEBACK_COURSES_PREFIX = "playcademy/timeback/courses/"

# Cache for discovered courses from config
var _config_courses: Array = []

func _ready():
	_ensure_project_settings()

func _ensure_project_settings():
	var needs_save = false
	
	# Sandbox settings - create if missing
	if not ProjectSettings.has_setting(SETTING_SANDBOX_AUTO_START):
		ProjectSettings.set_setting(SETTING_SANDBOX_AUTO_START, false)
		needs_save = true
	
	if not ProjectSettings.has_setting(SETTING_SANDBOX_PORT):
		ProjectSettings.set_setting(SETTING_SANDBOX_PORT, 4321)
		needs_save = true
	
	if not ProjectSettings.has_setting(SETTING_SANDBOX_VERBOSE):
		ProjectSettings.set_setting(SETTING_SANDBOX_VERBOSE, false)
		needs_save = true
	
	if not ProjectSettings.has_setting(SETTING_SANDBOX_URL):
		ProjectSettings.set_setting(SETTING_SANDBOX_URL, "http://localhost:4321")
		needs_save = true
	
	# Backend settings - create if missing
	if not ProjectSettings.has_setting(SETTING_BACKEND_AUTO_START):
		ProjectSettings.set_setting(SETTING_BACKEND_AUTO_START, false)
		needs_save = true
	
	if not ProjectSettings.has_setting(SETTING_BACKEND_PORT):
		ProjectSettings.set_setting(SETTING_BACKEND_PORT, 8788)
		needs_save = true
	
	if not ProjectSettings.has_setting(SETTING_BACKEND_PROJECT_PATH):
		# Auto-detect project path from Godot project root
		var detected_path = ProjectSettings.globalize_path("res://").rstrip("/")
		ProjectSettings.set_setting(SETTING_BACKEND_PROJECT_PATH, detected_path)
		needs_save = true
	
	# Timeback settings - create if missing
	if not ProjectSettings.has_setting(SETTING_TIMEBACK_STUDENT_ID):
		ProjectSettings.set_setting(SETTING_TIMEBACK_STUDENT_ID, "")
		needs_save = true
	
	if not ProjectSettings.has_setting(SETTING_TIMEBACK_ROLE):
		ProjectSettings.set_setting(SETTING_TIMEBACK_ROLE, "student")
		needs_save = true
	
	if not ProjectSettings.has_setting(SETTING_TIMEBACK_ORG_ID):
		ProjectSettings.set_setting(SETTING_TIMEBACK_ORG_ID, "")
		needs_save = true
	
	if not ProjectSettings.has_setting(SETTING_TIMEBACK_ORG_NAME):
		ProjectSettings.set_setting(SETTING_TIMEBACK_ORG_NAME, "")
		needs_save = true
	
	if not ProjectSettings.has_setting(SETTING_TIMEBACK_ORG_TYPE):
		ProjectSettings.set_setting(SETTING_TIMEBACK_ORG_TYPE, "department")
		needs_save = true
	
	# Register property info for all settings (must be done every load for UI visibility)
	_register_all_property_info()
	
	# Create dynamic settings for course enrollments from config
	_ensure_course_enrollment_settings()
	
	if needs_save:
		ProjectSettings.save()

func _register_all_property_info():
	"""Register property info for all settings - must be called every load for UI visibility"""
	# Sandbox settings
	ProjectSettings.set_initial_value(SETTING_SANDBOX_AUTO_START, false)
	ProjectSettings.add_property_info({
		"name": SETTING_SANDBOX_AUTO_START,
		"type": TYPE_BOOL,
	})
	
	ProjectSettings.set_initial_value(SETTING_SANDBOX_PORT, 4321)
	ProjectSettings.add_property_info({
		"name": SETTING_SANDBOX_PORT,
		"type": TYPE_INT,
		"hint": PROPERTY_HINT_RANGE,
		"hint_string": "1024,65535"
	})
	
	ProjectSettings.set_initial_value(SETTING_SANDBOX_VERBOSE, false)
	ProjectSettings.add_property_info({
		"name": SETTING_SANDBOX_VERBOSE,
		"type": TYPE_BOOL,
	})
	
	ProjectSettings.set_initial_value(SETTING_SANDBOX_URL, "http://localhost:4321")
	ProjectSettings.add_property_info({
		"name": SETTING_SANDBOX_URL,
		"type": TYPE_STRING,
		"hint": PROPERTY_HINT_PLACEHOLDER_TEXT,
		"hint_string": "http://localhost:4321"
	})
	
	# Backend settings
	ProjectSettings.set_initial_value(SETTING_BACKEND_AUTO_START, false)
	ProjectSettings.add_property_info({
		"name": SETTING_BACKEND_AUTO_START,
		"type": TYPE_BOOL,
	})
	
	ProjectSettings.set_initial_value(SETTING_BACKEND_PORT, 8788)
	ProjectSettings.add_property_info({
		"name": SETTING_BACKEND_PORT,
		"type": TYPE_INT,
		"hint": PROPERTY_HINT_RANGE,
		"hint_string": "1024,65535"
	})
	
	ProjectSettings.set_initial_value(SETTING_BACKEND_PROJECT_PATH, "")
	ProjectSettings.add_property_info({
		"name": SETTING_BACKEND_PROJECT_PATH,
		"type": TYPE_STRING,
		"hint": PROPERTY_HINT_PLACEHOLDER_TEXT,
		"hint_string": "Auto-detected from project root"
	})
	
	# Timeback settings
	ProjectSettings.set_initial_value(SETTING_TIMEBACK_STUDENT_ID, "")
	ProjectSettings.add_property_info({
		"name": SETTING_TIMEBACK_STUDENT_ID,
		"type": TYPE_STRING,
		"hint": PROPERTY_HINT_PLACEHOLDER_TEXT,
		"hint_string": "Leave empty for mock ID"
	})
	
	ProjectSettings.set_initial_value(SETTING_TIMEBACK_ROLE, "student")
	ProjectSettings.add_property_info({
		"name": SETTING_TIMEBACK_ROLE,
		"type": TYPE_STRING,
		"hint": PROPERTY_HINT_ENUM,
		"hint_string": "student,parent,teacher,administrator"
	})
	
	ProjectSettings.set_initial_value(SETTING_TIMEBACK_ORG_ID, "")
	ProjectSettings.add_property_info({
		"name": SETTING_TIMEBACK_ORG_ID,
		"type": TYPE_STRING,
		"hint": PROPERTY_HINT_PLACEHOLDER_TEXT,
		"hint_string": "Leave empty for mock org"
	})
	
	ProjectSettings.set_initial_value(SETTING_TIMEBACK_ORG_NAME, "")
	ProjectSettings.add_property_info({
		"name": SETTING_TIMEBACK_ORG_NAME,
		"type": TYPE_STRING,
		"hint": PROPERTY_HINT_PLACEHOLDER_TEXT,
		"hint_string": "Leave empty for 'Playcademy Studios'"
	})
	
	ProjectSettings.set_initial_value(SETTING_TIMEBACK_ORG_TYPE, "department")
	ProjectSettings.add_property_info({
		"name": SETTING_TIMEBACK_ORG_TYPE,
		"type": TYPE_STRING,
		"hint": PROPERTY_HINT_ENUM,
		"hint_string": "school,district,department,local,state,national"
	})

func is_sandbox_auto_start_enabled() -> bool:
	return ProjectSettings.get_setting(SETTING_SANDBOX_AUTO_START, false)

func get_sandbox_port() -> int:
	return ProjectSettings.get_setting(SETTING_SANDBOX_PORT, 4321)

func is_sandbox_verbose_enabled() -> bool:
	return ProjectSettings.get_setting(SETTING_SANDBOX_VERBOSE, false)

func get_sandbox_configured_url() -> String:
	return ProjectSettings.get_setting(SETTING_SANDBOX_URL, "http://localhost:4321")

func is_backend_auto_start_enabled() -> bool:
	return ProjectSettings.get_setting(SETTING_BACKEND_AUTO_START, false)

func get_backend_port() -> int:
	return ProjectSettings.get_setting(SETTING_BACKEND_PORT, 8788)

func get_backend_project_path() -> String:
	var path = ProjectSettings.get_setting(SETTING_BACKEND_PROJECT_PATH, "")
	if path.is_empty():
		# Fall back to auto-detected project root
		return ProjectSettings.globalize_path("res://").rstrip("/")
	return path

func get_timeback_student_id() -> String:
	return ProjectSettings.get_setting(SETTING_TIMEBACK_STUDENT_ID, "")

func get_timeback_role() -> String:
	return ProjectSettings.get_setting(SETTING_TIMEBACK_ROLE, "student")

func get_timeback_org_id() -> String:
	return ProjectSettings.get_setting(SETTING_TIMEBACK_ORG_ID, "")

func get_timeback_org_name() -> String:
	return ProjectSettings.get_setting(SETTING_TIMEBACK_ORG_NAME, "")

func get_timeback_org_type() -> String:
	return ProjectSettings.get_setting(SETTING_TIMEBACK_ORG_TYPE, "department")

func auto_start_if_enabled():
	var should_start = is_sandbox_auto_start_enabled() or is_backend_auto_start_enabled()
	if should_start:
		start_servers(true)  # Silent mode - don't show errors on auto-start failure

func ensure_servers_running():
	if sandbox_status != ServerStatus.RUNNING:
		start_servers(false)

func start_servers(silent: bool = false):
	start_sandbox(silent)
	
	# Check if playcademy.config.js or .json exists
	if _has_backend_config():
		start_backend(silent)

func _has_backend_config() -> bool:
	var project_root = ProjectSettings.globalize_path("res://")
	var config_js = project_root + "/playcademy.config.js"
	var config_json = project_root + "/playcademy.config.json"
	return FileAccess.file_exists(config_js) or FileAccess.file_exists(config_json)

func _build_timeback_cli_args() -> String:
	"""Build CLI arguments for Timeback configuration from project settings"""
	var args = ""
	
	var student_id = get_timeback_student_id()
	var role = get_timeback_role()
	var org_id = get_timeback_org_id()
	var org_name = get_timeback_org_name()
	var org_type = get_timeback_org_type()
	var excluded_courses = _get_excluded_courses()
	
	# Check if any timeback settings are configured (non-default values)
	var has_custom_settings = (
		not student_id.is_empty() or
		role != "student" or
		not org_id.is_empty() or
		not org_name.is_empty() or
		org_type != "department" or
		not excluded_courses.is_empty() or
		_has_timeback_config()
	)
	
	# Always pass student ID to enable mock mode when any timeback setting is configured
	if not student_id.is_empty():
		args += " --timeback-student-id \"%s\"" % student_id
	elif has_custom_settings:
		args += " --timeback-student-id mock"
	
	if role != "student":
		args += " --timeback-role %s" % role
	
	if not org_id.is_empty():
		args += " --timeback-org-id \"%s\"" % org_id
	
	if not org_name.is_empty():
		args += " --timeback-org-name \"%s\"" % org_name
	
	if org_type != "department":
		args += " --timeback-org-type %s" % org_type
	
	if not excluded_courses.is_empty():
		args += " --timeback-excluded-courses \"%s\"" % excluded_courses
	
	return args

func _has_timeback_config() -> bool:
	"""Check if playcademy.config.js has TimeBack integration configured"""
	var project_root = ProjectSettings.globalize_path("res://")
	var config_js = project_root + "/playcademy.config.js"
	var config_json = project_root + "/playcademy.config.json"
	
	# Try JSON config first (easier to parse)
	if FileAccess.file_exists(config_json):
		var file = FileAccess.open(config_json, FileAccess.READ)
		if file:
			var content = file.get_as_text()
			file.close()
			var json_result = JSON.parse_string(content)
			if json_result != null:
				if json_result.has("integrations") and json_result["integrations"].has("timeback"):
					return true
	
	# For JS config, do a simple text search for timeback
	if FileAccess.file_exists(config_js):
		var file = FileAccess.open(config_js, FileAccess.READ)
		if file:
			var content = file.get_as_text()
			file.close()
			# Look for timeback in integrations section
			if "timeback" in content and "integrations" in content:
				return true
	
	return false

func _load_config_courses() -> Array:
	"""Load courses from playcademy.config.json and return as array of {subject, grade}"""
	var project_root = ProjectSettings.globalize_path("res://")
	var config_json = project_root + "/playcademy.config.json"
	
	if not FileAccess.file_exists(config_json):
		return []
	
	var file = FileAccess.open(config_json, FileAccess.READ)
	if not file:
		return []
	
	var content = file.get_as_text()
	file.close()
	
	var json_result = JSON.parse_string(content)
	if json_result == null:
		return []
	
	if not json_result.has("integrations"):
		return []
	
	var integrations = json_result["integrations"]
	if not integrations.has("timeback"):
		return []
	
	var timeback = integrations["timeback"]
	if not timeback.has("courses"):
		return []
	
	var courses = timeback["courses"]
	if not courses is Array:
		return []
	
	var result = []
	for course in courses:
		if course.has("subject") and course.has("grade"):
			result.append({
				"subject": course["subject"],
				"grade": course["grade"]
			})
	
	return result

func _get_course_setting_key(subject: String, grade: int) -> String:
	"""Get the project setting key for a course enrollment"""
	# Replace : with _ for valid setting name
	var course_key = "%s_%d" % [subject, grade]
	return SETTING_TIMEBACK_COURSES_PREFIX + course_key

func _ensure_course_enrollment_settings():
	"""Create/update project settings for each course found in config"""
	_config_courses = _load_config_courses()
	
	if _config_courses.is_empty():
		return
	
	var needs_save = false
	
	for course in _config_courses:
		var setting_key = _get_course_setting_key(course["subject"], course["grade"])
		
		# Create setting if it doesn't exist (default to enrolled = 1)
		if not ProjectSettings.has_setting(setting_key):
			ProjectSettings.set_setting(setting_key, 1)  # 1 = Enrolled
			needs_save = true
		
		# Register property info for UI visibility with enum dropdown
		ProjectSettings.set_initial_value(setting_key, 1)
		ProjectSettings.add_property_info({
			"name": setting_key,
			"type": TYPE_INT,
			"hint": PROPERTY_HINT_ENUM,
			"hint_string": "Not Enrolled,Enrolled"  # 0 = Not Enrolled, 1 = Enrolled
		})
	
	if needs_save:
		ProjectSettings.save()

func _get_excluded_courses() -> String:
	"""Get comma-separated list of excluded courses based on project settings"""
	var excluded = []
	
	for course in _config_courses:
		var setting_key = _get_course_setting_key(course["subject"], course["grade"])
		var enrollment_value = ProjectSettings.get_setting(setting_key, 1)  # Default to enrolled
		
		# 0 = Not Enrolled, 1 = Enrolled
		if enrollment_value == 0:
			# Format as "Subject:Grade" for CLI
			var course_key = "%s:%d" % [course["subject"], course["grade"]]
			excluded.append(course_key)
	
	return ",".join(excluded)

func get_log_path(server_type: String) -> String:
	if server_type == "sandbox":
		return sandbox_log_path
	else:
		return backend_log_path

func _create_log_file_path(server_type: String) -> String:
	var tmp_dir = OS.get_environment("TMPDIR") if OS.get_environment("TMPDIR") else "/tmp"
	var pid = OS.get_process_id()
	return tmp_dir.path_join("playcademy-%s-%d.log" % [server_type, pid])

func start_sandbox(silent: bool = false):
	if sandbox_status == ServerStatus.RUNNING or sandbox_status == ServerStatus.STARTING:
		return
	
	var port = get_sandbox_port()
	var verbose = is_sandbox_verbose_enabled()
	
	var runtime_info = _find_js_runtime()
	if runtime_info.is_empty():
		if not silent:
			_handle_error("sandbox", "Neither npm nor bun found. Please install Node.js (npm) or Bun:\n• npm: https://nodejs.org\n• bun: curl -fsSL https://bun.sh/install | bash")
		return
	
	var runtime_path = runtime_info["path"]
	var runtime_type = runtime_info["type"]
	
	sandbox_status = ServerStatus.STARTING
	emit_signal("status_changed", get_status_string())
	
	# Create log file for output capture
	sandbox_log_path = _create_log_file_path("sandbox")
	
	var args = []
	var shell_cmd = ""
	if runtime_type == "npm":
		shell_cmd = "NO_COLOR=1 npx --yes @playcademy/sandbox --port %d --quiet" % port
	else:
		shell_cmd = "NO_COLOR=1 bun x --silent @playcademy/sandbox --port %d --quiet" % port
	
	# Always enable verbose logging for useful output in the dock
	shell_cmd += " --verbose"
	
	var project_name = ProjectSettings.get_setting("application/config/name", "godot-game")
	var project_slug = project_name.to_lower().replace(" ", "-")
	shell_cmd += " --project-name \"%s\" --project-slug %s" % [project_name, project_slug]
	
	# Add TimeBack configuration from project settings
	var timeback_args = _build_timeback_cli_args()
	if not timeback_args.is_empty():
		shell_cmd += timeback_args
		print("[PlaycademyBackend] TimeBack config: role=%s" % get_timeback_role())
	
	# Redirect output to log file
	shell_cmd += " > %s 2>&1" % sandbox_log_path
	
	# Use shell to handle redirection
	if OS.get_name() == "Windows":
		args = ["cmd", "/c", shell_cmd]
		sandbox_process = OS.create_process("cmd", args.slice(1))
	else:
		args = ["sh", "-c", shell_cmd]
		sandbox_process = OS.create_process("sh", args.slice(1))
	
	if sandbox_process == -1:
		sandbox_status = ServerStatus.STOPPED
		if not silent:
			_handle_error("sandbox", "Failed to start sandbox process. Check that bun or npm is installed.")
		return
	
	var command = "%s %s" % [runtime_type, "@playcademy/sandbox --port " + str(port)]
	print("[PlaycademyBackend] Starting sandbox (PID %d): %s" % [sandbox_process, command])
	
	# Start checking registry (retry for 5 seconds)
	_check_server_registry("sandbox", 0, silent)

func start_backend(silent: bool = false):
	if backend_status == ServerStatus.RUNNING or backend_status == ServerStatus.STARTING:
		return
	
	var port = get_backend_port()
	
	var runtime_info = _find_js_runtime()
	if runtime_info.is_empty():
		if not silent:
			_handle_error("backend", "Neither npm nor bun found")
		return
	
	var runtime_path = runtime_info["path"]
	var runtime_type = runtime_info["type"]
	
	backend_status = ServerStatus.STARTING
	emit_signal("status_changed", get_status_string())
	
	# Create log file for output capture
	backend_log_path = _create_log_file_path("backend")
	
	var shell_cmd = ""
	if runtime_type == "npm":
		shell_cmd = "NO_COLOR=1 npx --yes playcademy dev --port %d" % port
	else:
		shell_cmd = "NO_COLOR=1 bun x playcademy dev --port %d" % port
	
	# Redirect output to log file
	shell_cmd += " > %s 2>&1" % backend_log_path
	
	# Use shell to handle redirection
	var args = []
	if OS.get_name() == "Windows":
		args = ["cmd", "/c", shell_cmd]
		backend_process = OS.create_process("cmd", args.slice(1))
	else:
		args = ["sh", "-c", shell_cmd]
		backend_process = OS.create_process("sh", args.slice(1))
	
	if backend_process == -1:
		backend_status = ServerStatus.STOPPED
		if not silent:
			_handle_error("backend", "Failed to start backend server")
		return
	
	var command = "%s %s" % [runtime_type, "playcademy dev --port " + str(port)]
	print("[PlaycademyBackend] Starting backend (PID %d): %s" % [backend_process, command])
	
	# Start checking registry
	_check_server_registry("backend", 0, silent)

func stop_servers():
	stop_sandbox()
	stop_backend()

func stop_sandbox():
	if sandbox_status == ServerStatus.STOPPED or sandbox_status == ServerStatus.STOPPING:
		return
	
	sandbox_status = ServerStatus.STOPPING
	emit_signal("status_changed", get_status_string())
	
	# Get the actual sandbox PID from the registry (not the shell wrapper)
	var actual_pid = _get_server_pid_from_registry("sandbox")
	var shell_pid = sandbox_process
	
	if actual_pid != -1:
		# Try to send SIGINT for graceful shutdown (Unix only)
		if OS.get_name() != "Windows":
			var output = []
			OS.execute("kill", ["-2", str(actual_pid)], output)
			# Wait briefly for cleanup handler to run
			await get_tree().create_timer(0.5).timeout
		
		# Kill process if still alive (or on Windows)
		OS.kill(actual_pid)
	
	# Also kill the shell wrapper process
	if shell_pid != -1:
		OS.kill(shell_pid)
		sandbox_process = -1
	
	# Manually clean up registry (in case cleanup handler didn't run)
	if actual_pid != -1:
		_cleanup_registry_entry_by_pid("sandbox", actual_pid)
	
	# Append shutdown message to log
	if sandbox_log_path and FileAccess.file_exists(sandbox_log_path):
		var log_file = FileAccess.open(sandbox_log_path, FileAccess.READ_WRITE)
		if log_file:
			log_file.seek_end()
			log_file.store_string("\n\n[Server stopped by Godot plugin]\n")
			log_file.close()
	
	sandbox_url = ""
	sandbox_status = ServerStatus.STOPPED
	emit_signal("status_changed", get_status_string())

func stop_backend():
	if backend_status == ServerStatus.STOPPED or backend_status == ServerStatus.STOPPING:
		return
	
	backend_status = ServerStatus.STOPPING
	emit_signal("status_changed", get_status_string())
	
	# Get the actual backend PID from the registry (not the shell wrapper)
	var actual_pid = _get_server_pid_from_registry("backend")
	var shell_pid = backend_process
	
	if actual_pid != -1:
		# Try to send SIGINT for graceful shutdown (Unix only)
		if OS.get_name() != "Windows":
			var output = []
			OS.execute("kill", ["-2", str(actual_pid)], output)
			# Wait briefly for cleanup handler to run
			await get_tree().create_timer(0.5).timeout
		
		# Kill process if still alive (or on Windows)
		OS.kill(actual_pid)
	
	# Also kill the shell wrapper process
	if shell_pid != -1:
		OS.kill(shell_pid)
		backend_process = -1
	
	# Manually clean up registry (in case cleanup handler didn't run)
	if actual_pid != -1:
		_cleanup_registry_entry_by_pid("backend", actual_pid)
	
	# Append shutdown message to log
	if backend_log_path and FileAccess.file_exists(backend_log_path):
		var log_file = FileAccess.open(backend_log_path, FileAccess.READ_WRITE)
		if log_file:
			log_file.seek_end()
			log_file.store_string("\n\n[Server stopped by Godot plugin]\n")
			log_file.close()
	
	backend_url = ""
	backend_status = ServerStatus.STOPPED
	emit_signal("status_changed", get_status_string())

func restart_servers():
	stop_servers()
	await get_tree().create_timer(1.0).timeout
	start_servers()

func reset_database():
	"""Reset the sandbox database by stopping servers and restarting with recreateDb flag"""
	print("[PlaycademyBackend] Resetting sandbox database...")
	stop_servers()
	await get_tree().create_timer(1.0).timeout
	
	# Restart sandbox with recreate flag
	_start_sandbox_with_recreate()
	
	# Restart backend if it was running
	if _has_backend_config():
		start_backend(false)

func _start_sandbox_with_recreate():
	"""Start sandbox with --recreate-db flag to force fresh database"""
	if sandbox_status == ServerStatus.RUNNING or sandbox_status == ServerStatus.STARTING:
		return
	
	var port = get_sandbox_port()
	
	var runtime_info = _find_js_runtime()
	if runtime_info.is_empty():
		_handle_error("sandbox", "Neither npm nor bun found")
		return
	
	var runtime_type = runtime_info["type"]
	
	sandbox_status = ServerStatus.STARTING
	emit_signal("status_changed", get_status_string())
	
	sandbox_log_path = _create_log_file_path("sandbox")
	
	var shell_cmd = ""
	if runtime_type == "npm":
		shell_cmd = "NO_COLOR=1 npx --yes @playcademy/sandbox --port %d --quiet" % port
	else:
		shell_cmd = "NO_COLOR=1 bun x --silent @playcademy/sandbox --port %d --quiet" % port
	
	var project_name = ProjectSettings.get_setting("application/config/name", "godot-game")
	var project_slug = project_name.to_lower().replace(" ", "-")
	shell_cmd += " --project-name \"%s\" --project-slug %s" % [project_name, project_slug]
	
	# Add recreate-db flag
	shell_cmd += " --recreate-db"
	
	# Add TimeBack configuration from project settings
	shell_cmd += _build_timeback_cli_args()
	
	shell_cmd += " > %s 2>&1" % sandbox_log_path
	
	var args = []
	if OS.get_name() == "Windows":
		args = ["cmd", "/c", shell_cmd]
		sandbox_process = OS.create_process("cmd", args.slice(1))
	else:
		args = ["sh", "-c", shell_cmd]
		sandbox_process = OS.create_process("sh", args.slice(1))
	
	if sandbox_process == -1:
		sandbox_status = ServerStatus.STOPPED
		_handle_error("sandbox", "Failed to start sandbox with database reset")
		return
	
	print("[PlaycademyBackend] Starting sandbox with database reset (PID %d)" % sandbox_process)
	_check_server_registry("sandbox", 0, false)

func get_sandbox_status() -> ServerStatus:
	return sandbox_status

func get_backend_status() -> ServerStatus:
	return backend_status

func get_status_string() -> String:
	var parts = []
	
	# Only show non-stopped statuses
	if sandbox_status == ServerStatus.RUNNING:
		parts.append("Sandbox: Running")
	elif sandbox_status == ServerStatus.STARTING:
		parts.append("Sandbox: Starting...")
	elif sandbox_status == ServerStatus.ERROR:
		parts.append("Sandbox: Error")
	elif sandbox_status == ServerStatus.STOPPING:
		parts.append("Sandbox: Stopping...")
	
	if backend_status == ServerStatus.RUNNING:
		parts.append("Backend: Running")
	elif backend_status == ServerStatus.STARTING:
		parts.append("Backend: Starting...")
	elif backend_status == ServerStatus.ERROR:
		parts.append("Backend: Error")
	elif backend_status == ServerStatus.STOPPING:
		parts.append("Backend: Stopping...")
	
	if parts.is_empty():
		return "Stopped"
	
	return " | ".join(parts)

func get_sandbox_url() -> String:
	return sandbox_url

func get_backend_url() -> String:
	return backend_url

func _handle_error(server_type: String, error_message: String):
	print("[PlaycademyBackend] %s error: %s" % [server_type, error_message])
	
	if server_type == "sandbox":
		sandbox_status = ServerStatus.ERROR
	else:
		backend_status = ServerStatus.ERROR
	
	emit_signal("server_failed", server_type, error_message)
	emit_signal("status_changed", get_status_string())

# Get the actual server PID from the port registry
func _get_server_pid_from_registry(server_type: String) -> int:
	var home = OS.get_environment("HOME")
	var registry_path = home + "/.playcademy/.proc"
	var file = FileAccess.open(registry_path, FileAccess.READ)
	
	if not file:
		return -1
	
	var registry_text = file.get_as_text()
	file.close()
	
	var json_result = JSON.parse_string(registry_text)
	if json_result == null:
		return -1
	
	var registry = json_result
	var my_project = ProjectSettings.globalize_path("res://").rstrip("/")
	
	# Find server for this project and return its PID
	for key in registry:
		if key.begins_with(server_type + "-"):
			var server = registry[key]
			if server.projectRoot == my_project:
				return server.pid
	
	return -1

# Check server registry with retry logic (retry every 500ms for 10 seconds = 20 attempts)
var _retry_counts = {"sandbox": 0, "backend": 0}
const MAX_RETRIES = 20
const RETRY_INTERVAL = 0.5

func _check_server_registry(server_type: String, attempt: int, silent: bool = false):
	if attempt >= MAX_RETRIES:
		var port = get_sandbox_port() if server_type == "sandbox" else get_backend_port()
		if server_type == "sandbox":
			sandbox_status = ServerStatus.STOPPED
		else:
			backend_status = ServerStatus.STOPPED
		
		if not silent:
			_handle_error(server_type, "Server failed to start. Port %d may be in use by another process.\nStop the other server or change the port in Project Settings." % port)
		emit_signal("status_changed", get_status_string())
		return
	
	var home = OS.get_environment("HOME")
	var registry_path = home + "/.playcademy/.proc"
	var file = FileAccess.open(registry_path, FileAccess.READ)
	
	if not file:
		# Registry doesn't exist yet, retry silently
		await get_tree().create_timer(RETRY_INTERVAL).timeout
		_check_server_registry(server_type, attempt + 1, silent)
		return
	
	var registry_text = file.get_as_text()
	file.close()
	
	var json_result = JSON.parse_string(registry_text)
	if json_result == null:
		# Failed to parse, retry silently
		await get_tree().create_timer(RETRY_INTERVAL).timeout
		_check_server_registry(server_type, attempt + 1, silent)
		return
	
	var registry = json_result
	var my_project = ProjectSettings.globalize_path("res://").rstrip("/")
	
	# Find server for this project
	for key in registry:
		if key.begins_with(server_type + "-"):
			var server = registry[key]
			if server.projectRoot == my_project:
				if server_type == "sandbox":
					sandbox_port = server.port
					sandbox_url = server.url
					sandbox_status = ServerStatus.RUNNING
					emit_signal("sandbox_started", sandbox_url)
					print("[PlaycademyBackend] ✓ Sandbox: %s" % sandbox_url)
				else:
					backend_port = server.port
					backend_url = server.url
					backend_status = ServerStatus.RUNNING
					emit_signal("backend_started", backend_url)
					print("[PlaycademyBackend] ✓ Backend: %s" % backend_url)
				
				emit_signal("status_changed", get_status_string())
				return
	
	# Not found yet, retry silently
	await get_tree().create_timer(RETRY_INTERVAL).timeout
	_check_server_registry(server_type, attempt + 1, silent)

func _find_js_runtime() -> Dictionary:
	var runtimes = [
		{"type": "bun", "cmd": "bun"},
		{"type": "npm", "cmd": "npm"}
	]
	
	for runtime in runtimes:
		var paths = _get_runtime_paths(runtime.cmd)
		for path in paths:
			if _test_runtime_executable(path):
				return {"type": runtime.type, "path": path}
	
	return {}

func _get_runtime_paths(cmd: String) -> Array:
	var possible_paths = []
	
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
	
	possible_paths.append(cmd)
	return possible_paths

func _test_runtime_executable(path: String) -> bool:
	var output = []
	var exit_code = OS.execute(path, ["--version"], output)
	return exit_code == 0

func _cleanup_registry_entry_by_pid(server_type: String, pid: int):
	"""Manually remove a server from the registry by PID"""
	var home = OS.get_environment("HOME")
	var registry_path = home + "/.playcademy/.proc"
	var file = FileAccess.open(registry_path, FileAccess.READ)
	
	if not file:
		return  # Nothing to clean up
	
	var registry_text = file.get_as_text()
	file.close()
	
	var json_result = JSON.parse_string(registry_text)
	if json_result == null:
		return
	
	var registry = json_result
	var keys_to_remove = []
	
	# Find entries matching this PID
	for key in registry:
		if key.begins_with(server_type + "-"):
			var server = registry[key]
			if server.pid == pid:
				keys_to_remove.append(key)
	
	# Remove entries
	for key in keys_to_remove:
		registry.erase(key)
	
	# Write back
	if keys_to_remove.size() > 0:
		var write_file = FileAccess.open(registry_path, FileAccess.WRITE)
		if write_file:
			write_file.store_string(JSON.stringify(registry, "\t"))
			write_file.close()
			print("[PlaycademyBackend] Cleaned up %d %s entries from registry" % [keys_to_remove.size(), server_type])

func _cleanup_log_files():
	# Clean up log files
	if sandbox_log_path and FileAccess.file_exists(sandbox_log_path):
		DirAccess.remove_absolute(sandbox_log_path)
	if backend_log_path and FileAccess.file_exists(backend_log_path):
		DirAccess.remove_absolute(backend_log_path)

func _exit_tree():
	stop_servers()
	_cleanup_log_files()
