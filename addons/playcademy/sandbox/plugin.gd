@tool
extends EditorPlugin

const SandboxManager = preload("res://addons/playcademy/sandbox/sandbox_manager.gd")
const SandboxDock = preload("res://addons/playcademy/sandbox/sandbox_dock.gd")

var sandbox_manager: SandboxManager
var sandbox_dock: SandboxDock

const PLUGIN_NAME := "Playcademy Sandbox"

func _get_plugin_name():
	return PLUGIN_NAME

func _enter_tree() -> void:
	# Register project settings
	_register_project_settings()
	
	# Initialize sandbox manager
	sandbox_manager = SandboxManager.new()
	add_child(sandbox_manager)
	
	# Create and add the dock
	sandbox_dock = SandboxDock.new()
	sandbox_dock.setup_with_manager(sandbox_manager)
	add_control_to_dock(DOCK_SLOT_LEFT_UL, sandbox_dock)
	
	# Connect to project run signals if available
	if EditorInterface.get_editor_main_screen():
		# Auto-start sandbox when plugin loads (project opened)
		sandbox_manager.auto_start_if_enabled()

func _exit_tree() -> void:
	# Clean up dock
	if sandbox_dock:
		remove_control_from_docks(sandbox_dock)
		sandbox_dock.queue_free()
		sandbox_dock = null
	
	# Clean up sandbox manager
	if sandbox_manager:
		sandbox_manager.stop_sandbox()
		sandbox_manager.queue_free()
		sandbox_manager = null

func _has_main_screen() -> bool:
	return false

# Called when the project is about to run
func _build() -> bool:
	if sandbox_manager and sandbox_manager.is_auto_start_enabled():
		sandbox_manager.ensure_sandbox_running()
	return true

func _register_project_settings():
	var settings = [
		{
			"name": "playcademy/sandbox/auto_start",
			"type": TYPE_BOOL,
			"default": true,
			"hint": PROPERTY_HINT_NONE,
			"hint_string": "",
			"usage": PROPERTY_USAGE_DEFAULT,
			"description": "Automatically start the sandbox when the project opens"
		},
		{
			"name": "playcademy/sandbox/port",
			"type": TYPE_INT,
			"default": 4321,
			"hint": PROPERTY_HINT_RANGE,
			"hint_string": "1024,65535,1",
			"usage": PROPERTY_USAGE_DEFAULT,
			"description": "Port number for the sandbox server"
		},
		{
			"name": "playcademy/sandbox/verbose",
			"type": TYPE_BOOL,
			"default": false,
			"hint": PROPERTY_HINT_NONE,
			"hint_string": "",
			"usage": PROPERTY_USAGE_DEFAULT,
			"description": "Enable verbose logging for sandbox operations"
		},
		{
			"name": "playcademy/sandbox/url",
			"type": TYPE_STRING,
			"default": "http://localhost:4321",
			"hint": PROPERTY_HINT_NONE,
			"hint_string": "",
			"usage": PROPERTY_USAGE_DEFAULT,
			"description": "Base URL for the sandbox server"
		}
	]
	
	for setting in settings:
		if not ProjectSettings.has_setting(setting.name):
			ProjectSettings.set_setting(setting.name, setting.default)
		
		# Add the setting to the project settings UI
		var property_info = {
			"name": setting.name,
			"type": setting.type,
			"hint": setting.hint,
			"hint_string": setting.hint_string,
			"usage": setting.usage
		}
		ProjectSettings.add_property_info(property_info)
	
	# Save the settings
	ProjectSettings.save() 