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
	var should_start = backend_manager and (backend_manager.is_sandbox_auto_start_enabled() or backend_manager.is_backend_auto_start_enabled())
	if should_start:
		backend_manager.ensure_servers_running()
	return true
