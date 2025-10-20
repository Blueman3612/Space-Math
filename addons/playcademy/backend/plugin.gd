@tool
extends EditorPlugin

const BackendManager = preload("res://addons/playcademy/backend/backend_manager.gd")
const BackendPanel = preload("res://addons/playcademy/backend/backend_dock.gd")

var backend_manager: BackendManager
var backend_panel: BackendPanel

const PLUGIN_NAME := "Playcademy Backend"

func _get_plugin_name():
	return PLUGIN_NAME

func _enter_tree() -> void:
	# Register project settings
	_register_project_settings()
	
	# Initialize backend manager
	backend_manager = BackendManager.new()
	add_child(backend_manager)
	
	# Create and add to bottom panel (wide horizontal space for logs)
	backend_panel = BackendPanel.new()
	backend_panel.setup_with_manager(backend_manager)
	add_control_to_bottom_panel(backend_panel, "Playcademy")
	
	# Auto-start servers when plugin loads (project opened)
	if EditorInterface.get_editor_main_screen():
		backend_manager.auto_start_if_enabled()

func _exit_tree() -> void:
	# Clean up panel
	if backend_panel:
		remove_control_from_bottom_panel(backend_panel)
		backend_panel.queue_free()
		backend_panel = null
	
	# Clean up backend manager
	if backend_manager:
		backend_manager.stop_servers()
		backend_manager.queue_free()
		backend_manager = null

func _has_main_screen() -> bool:
	return false

# Called when the project is about to run
func _build() -> bool:
	if backend_manager and backend_manager.is_auto_start_enabled():
		backend_manager.ensure_servers_running()
	return true

func _register_project_settings():
	var settings = [
		{
			"name": "playcademy/backend/auto_start",
			"type": TYPE_BOOL,
			"default": true,
			"hint": PROPERTY_HINT_NONE,
			"hint_string": "",
			"usage": PROPERTY_USAGE_DEFAULT,
			"description": "Automatically start dev servers when the project opens"
		},
		{
			"name": "playcademy/backend/sandbox_port",
			"type": TYPE_INT,
			"default": 4321,
			"hint": PROPERTY_HINT_RANGE,
			"hint_string": "1024,65535,1",
			"usage": PROPERTY_USAGE_DEFAULT,
			"description": "Preferred port for the sandbox server"
		},
		{
			"name": "playcademy/backend/backend_port",
			"type": TYPE_INT,
			"default": 8788,
			"hint": PROPERTY_HINT_RANGE,
			"hint_string": "1024,65535,1",
			"usage": PROPERTY_USAGE_DEFAULT,
			"description": "Preferred port for the backend server"
		},
		{
			"name": "playcademy/backend/verbose",
			"type": TYPE_BOOL,
			"default": false,
			"hint": PROPERTY_HINT_NONE,
			"hint_string": "",
			"usage": PROPERTY_USAGE_DEFAULT,
			"description": "Enable verbose logging for dev server operations"
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