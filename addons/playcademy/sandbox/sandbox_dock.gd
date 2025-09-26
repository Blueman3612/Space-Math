@tool
extends Control
class_name PlaycademySandboxDock

var sandbox_manager: PlaycademySandboxManager

# UI Elements
var status_label: Label
var url_label: Label
var start_button: Button
var stop_button: Button
var restart_button: Button
var auto_start_checkbox: CheckBox

func _init():
	name = "Playcademy Sandbox"
	set_custom_minimum_size(Vector2(200, 300))

func setup_with_manager(manager: PlaycademySandboxManager):
	sandbox_manager = manager
	_create_ui()
	_connect_signals()
	_update_ui()

func _create_ui():
	# Main container
	var vbox = VBoxContainer.new()
	add_child(vbox)
	
	# Title
	var title = Label.new()
	title.text = "Playcademy Sandbox"
	title.add_theme_font_size_override("font_size", 16)
	vbox.add_child(title)
	
	vbox.add_child(HSeparator.new())
	
	# Status section
	var status_container = VBoxContainer.new()
	vbox.add_child(status_container)
	
	var status_title = Label.new()
	status_title.text = "Status:"
	status_title.add_theme_font_size_override("font_size", 12)
	status_container.add_child(status_title)
	
	status_label = Label.new()
	status_label.text = "Stopped"
	status_label.add_theme_color_override("font_color", Color.GRAY)
	status_container.add_child(status_label)
	
	# URL section
	var url_container = VBoxContainer.new()
	vbox.add_child(url_container)
	
	var url_title = Label.new()
	url_title.text = "URL:"
	url_title.add_theme_font_size_override("font_size", 12)
	url_container.add_child(url_title)
	
	url_label = Label.new()
	url_label.text = "Not running"
	url_label.add_theme_color_override("font_color", Color.GRAY)
	url_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	url_container.add_child(url_label)
	
	vbox.add_child(HSeparator.new())
	
	# Controls section
	var controls_container = VBoxContainer.new()
	vbox.add_child(controls_container)
	
	# Start button
	start_button = Button.new()
	start_button.text = "Start Sandbox"
	start_button.pressed.connect(_on_start_pressed)
	controls_container.add_child(start_button)
	
	# Stop button
	stop_button = Button.new()
	stop_button.text = "Stop Sandbox"
	stop_button.pressed.connect(_on_stop_pressed)
	controls_container.add_child(stop_button)
	
	# Restart button
	restart_button = Button.new()
	restart_button.text = "Restart Sandbox"
	restart_button.pressed.connect(_on_restart_pressed)
	controls_container.add_child(restart_button)
	
	vbox.add_child(HSeparator.new())
	
	# Settings section
	var settings_container = VBoxContainer.new()
	vbox.add_child(settings_container)
	
	var settings_title = Label.new()
	settings_title.text = "Settings:"
	settings_title.add_theme_font_size_override("font_size", 12)
	settings_container.add_child(settings_title)
	
	# Auto-start checkbox
	auto_start_checkbox = CheckBox.new()
	auto_start_checkbox.text = "Auto-start on project open"
	auto_start_checkbox.toggled.connect(_on_auto_start_toggled)
	settings_container.add_child(auto_start_checkbox)

func _connect_signals():
	if sandbox_manager:
		sandbox_manager.status_changed.connect(_on_status_changed)
		sandbox_manager.sandbox_started.connect(_on_sandbox_started)
		sandbox_manager.sandbox_stopped.connect(_on_sandbox_stopped)
		sandbox_manager.sandbox_failed.connect(_on_sandbox_failed)

func _update_ui():
	if not sandbox_manager:
		return
	
	var status = sandbox_manager.get_status()
	var status_string = sandbox_manager.get_status_string()
	
	# Update status label and color
	status_label.text = status_string
	match status:
		PlaycademySandboxManager.SandboxStatus.RUNNING:
			status_label.add_theme_color_override("font_color", Color.GREEN)
		PlaycademySandboxManager.SandboxStatus.STARTING:
			status_label.add_theme_color_override("font_color", Color.YELLOW)
		PlaycademySandboxManager.SandboxStatus.ERROR:
			status_label.add_theme_color_override("font_color", Color.RED)
		_:
			status_label.add_theme_color_override("font_color", Color.GRAY)
	
	# Update URL
	var url = sandbox_manager.get_sandbox_url()
	if url.is_empty():
		url_label.text = "Not running"
		url_label.add_theme_color_override("font_color", Color.GRAY)
	else:
		url_label.text = url
		url_label.add_theme_color_override("font_color", Color.CYAN)
	
	# Update button states
	var is_running = status == PlaycademySandboxManager.SandboxStatus.RUNNING
	var is_starting = status == PlaycademySandboxManager.SandboxStatus.STARTING
	var is_stopping = status == PlaycademySandboxManager.SandboxStatus.STOPPING
	
	start_button.disabled = is_running or is_starting
	stop_button.disabled = not is_running and not is_starting
	restart_button.disabled = is_starting or is_stopping
	
	# Update auto-start checkbox
	auto_start_checkbox.button_pressed = sandbox_manager.is_auto_start_enabled()

func _on_start_pressed():
	if sandbox_manager:
		sandbox_manager.start_sandbox()

func _on_stop_pressed():
	if sandbox_manager:
		sandbox_manager.stop_sandbox()

func _on_restart_pressed():
	if sandbox_manager:
		sandbox_manager.restart_sandbox()

func _on_auto_start_toggled(pressed: bool):
	ProjectSettings.set_setting("playcademy/sandbox/auto_start", pressed)
	ProjectSettings.save()

func _on_status_changed(status_string: String):
	_update_ui()

func _on_sandbox_started(url: String):
	_update_ui()

func _on_sandbox_stopped():
	_update_ui()

func _on_sandbox_failed(error: String):
	_update_ui()
	print("[PlaycademySandbox] Sandbox failed: ", error)
	
	# Show error dialog
	var dialog = AcceptDialog.new()
	dialog.dialog_text = "Sandbox Error:\n" + error
	dialog.title = "Playcademy Sandbox Error"
	add_child(dialog)
	dialog.popup_centered()
	dialog.confirmed.connect(func(): dialog.queue_free()) 