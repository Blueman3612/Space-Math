@tool
extends Control
class_name PlaycademyBackendDock

var backend_manager: PlaycademyBackendManager

# UI Elements
var sandbox_button: Button
var backend_button: Button
var log_display: RichTextLabel
var start_button: Button
var stop_button: Button
var restart_button: Button
var reset_db_button: Button
var auto_start_checkbox: CheckBox

var selected_server: String = "sandbox"  # "sandbox" or "backend"
var log_update_timer: Timer

func _init():
	name = "Playcademy"

func setup_with_manager(manager: PlaycademyBackendManager):
	backend_manager = manager
	_create_ui()
	_connect_signals()
	# Force initial update on next frame to ensure styles apply
	call_deferred("_update_ui")
	# Setup log polling after we're in the scene tree
	call_deferred("_setup_log_polling")

func _create_ui():
	# Main split container
	var split = HSplitContainer.new()
	split.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	split.split_offset = 200
	add_child(split)
	
	# Left column - Server list
	var left_panel = _create_left_panel()
	split.add_child(left_panel)
	
	# Right column - Logs
	var right_panel = _create_right_panel()
	split.add_child(right_panel)

func _create_left_panel() -> Control:
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_right", 4)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	margin.add_child(vbox)
	
	# Title
	var title = Label.new()
	title.text = "Servers"
	title.add_theme_font_size_override("font_size", 14)
	vbox.add_child(title)
	
	vbox.add_child(HSeparator.new())
	
	# Server buttons (selectable)
	sandbox_button = Button.new()
	sandbox_button.text = "Sandbox"
	sandbox_button.toggle_mode = true
	sandbox_button.button_pressed = false
	sandbox_button.disabled = true
	sandbox_button.set_h_size_flags(Control.SIZE_EXPAND_FILL)
	sandbox_button.pressed.connect(func(): _select_server("sandbox"))
	_apply_initial_button_style(sandbox_button)
	vbox.add_child(sandbox_button)
	
	backend_button = Button.new()
	backend_button.text = "Backend"
	backend_button.toggle_mode = true
	backend_button.button_pressed = false
	backend_button.disabled = true
	backend_button.set_h_size_flags(Control.SIZE_EXPAND_FILL)
	backend_button.pressed.connect(func(): _select_server("backend"))
	_apply_initial_button_style(backend_button)
	vbox.add_child(backend_button)
	
	vbox.add_child(HSeparator.new())
	
	# Control buttons
	start_button = Button.new()
	start_button.text = "Start"
	start_button.set_h_size_flags(Control.SIZE_EXPAND_FILL)
	start_button.pressed.connect(_on_start_pressed)
	vbox.add_child(start_button)
	
	stop_button = Button.new()
	stop_button.text = "Stop"
	stop_button.set_h_size_flags(Control.SIZE_EXPAND_FILL)
	stop_button.pressed.connect(_on_stop_pressed)
	vbox.add_child(stop_button)
	
	restart_button = Button.new()
	restart_button.text = "Restart"
	restart_button.set_h_size_flags(Control.SIZE_EXPAND_FILL)
	restart_button.pressed.connect(_on_restart_pressed)
	vbox.add_child(restart_button)
	
	reset_db_button = Button.new()
	reset_db_button.text = "Reset DB"
	reset_db_button.set_h_size_flags(Control.SIZE_EXPAND_FILL)
	reset_db_button.pressed.connect(_on_reset_db_pressed)
	vbox.add_child(reset_db_button)
	
	vbox.add_child(HSeparator.new())
	
	# Auto-start checkbox
	auto_start_checkbox = CheckBox.new()
	auto_start_checkbox.text = "Auto-start"
	auto_start_checkbox.set_h_size_flags(Control.SIZE_EXPAND_FILL)
	auto_start_checkbox.toggled.connect(_on_auto_start_toggled)
	vbox.add_child(auto_start_checkbox)
	
	# Spacer
	var spacer = Control.new()
	spacer.set_v_size_flags(Control.SIZE_EXPAND_FILL)
	vbox.add_child(spacer)
	
	return margin

func _create_right_panel() -> Control:
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 4)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	
	var vbox = VBoxContainer.new()
	vbox.set_v_size_flags(Control.SIZE_EXPAND_FILL)
	margin.add_child(vbox)
	
	# Log title
	var title = Label.new()
	title.text = "Output"
	title.add_theme_font_size_override("font_size", 14)
	vbox.add_child(title)
	
	# Log display
	log_display = RichTextLabel.new()
	log_display.set_v_size_flags(Control.SIZE_EXPAND_FILL)
	log_display.set_h_size_flags(Control.SIZE_EXPAND_FILL)
	log_display.scroll_following = true
	log_display.bbcode_enabled = false  # Plain text for better log display
	log_display.fit_content = false
	log_display.selection_enabled = true  # Allow selecting text for copying
	
	# Apply editor's monospace font
	call_deferred("_apply_monospace_font", log_display)
	
	vbox.add_child(log_display)
	
	return margin

func _apply_monospace_font(control: Control):
	# Get the editor's base control to access its theme
	var editor_base = EditorInterface.get_base_control()
	
	if editor_base:
		# Get the monospace font used in the Output panel
		var mono_font = editor_base.get_theme_font("output_source", "EditorFonts")
		var mono_font_size = editor_base.get_theme_font_size("output_source_size", "EditorFonts")
		
		# Apply to the control
		if mono_font:
			control.add_theme_font_override("mono_font", mono_font)
			control.add_theme_font_override("normal_font", mono_font)
		if mono_font_size > 0:
			control.add_theme_font_size_override("mono_font_size", mono_font_size)
			control.add_theme_font_size_override("normal_font_size", mono_font_size)

func _setup_log_polling():
	log_update_timer = Timer.new()
	log_update_timer.wait_time = 0.5  # Update logs every 500ms
	log_update_timer.timeout.connect(_update_logs)
	add_child(log_update_timer)
	log_update_timer.start()
	
	# Force initial log update
	call_deferred("_update_logs")

func _select_server(server_type: String):
	selected_server = server_type
	sandbox_button.button_pressed = (server_type == "sandbox")
	backend_button.button_pressed = (server_type == "backend")
	_update_logs()

func _update_logs():
	if not backend_manager or not log_display:
		return
	
	var log_path = backend_manager.get_log_path(selected_server)
	if not FileAccess.file_exists(log_path):
		if log_display.text != "[No output yet]":
			log_display.clear()
			log_display.text = "[No output yet]"
		return
	
	var file = FileAccess.open(log_path, FileAccess.READ)
	if file:
		var content = file.get_as_text()
		file.close()
		
		# Only update if content has changed to avoid flickering
		if log_display.text != content:
			# Remember if we were scrolled to bottom
			var was_at_bottom = log_display.scroll_following or log_display.get_v_scroll_bar().value >= log_display.get_v_scroll_bar().max_value - log_display.get_v_scroll_bar().page
			
			log_display.text = content
			
			# Force scroll to bottom if we were there before, or if scroll_following is enabled
			if was_at_bottom:
				call_deferred("_scroll_to_bottom")

func _scroll_to_bottom():
	if log_display and log_display.get_v_scroll_bar():
		log_display.get_v_scroll_bar().value = log_display.get_v_scroll_bar().max_value

func _connect_signals():
	if backend_manager:
		backend_manager.status_changed.connect(_on_status_changed)
		backend_manager.sandbox_started.connect(_on_sandbox_started)
		backend_manager.backend_started.connect(_on_backend_started)
		backend_manager.servers_stopped.connect(_on_servers_stopped)
		backend_manager.server_failed.connect(_on_server_failed)

func _update_ui():
	if not backend_manager:
		return
	
	var sandbox_status = backend_manager.get_sandbox_status()
	var backend_status = backend_manager.get_backend_status()
	
	# Update server button colors based on status
	_update_server_button(sandbox_button, sandbox_status)
	_update_server_button(backend_button, backend_status)
	
	# Enable/disable server buttons based on status
	sandbox_button.disabled = sandbox_status == PlaycademyBackendManager.ServerStatus.STOPPED
	backend_button.disabled = backend_status == PlaycademyBackendManager.ServerStatus.STOPPED
	
	# Update control buttons
	var any_running = sandbox_status == PlaycademyBackendManager.ServerStatus.RUNNING or backend_status == PlaycademyBackendManager.ServerStatus.RUNNING
	var any_starting = sandbox_status == PlaycademyBackendManager.ServerStatus.STARTING or backend_status == PlaycademyBackendManager.ServerStatus.STARTING
	var any_stopping = sandbox_status == PlaycademyBackendManager.ServerStatus.STOPPING or backend_status == PlaycademyBackendManager.ServerStatus.STOPPING
	
	start_button.disabled = any_running or any_starting
	stop_button.disabled = not any_running and not any_starting
	restart_button.disabled = any_starting or any_stopping
	
	auto_start_checkbox.button_pressed = backend_manager.is_auto_start_enabled()

func _apply_initial_button_style(button: Button):
	# Apply identical stopped styling to both buttons on creation
	var style = StyleBoxFlat.new()
	style.set_corner_radius_all(4)
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	style.bg_color = Color("#2a2a2a")
	button.add_theme_stylebox_override("normal", style)
	button.add_theme_stylebox_override("pressed", style)
	button.add_theme_stylebox_override("hover", style)
	button.add_theme_stylebox_override("focus", style)

func _update_server_button(button: Button, status: int):
	# Normal state - no border
	var normal_style = StyleBoxFlat.new()
	normal_style.set_corner_radius_all(4)
	normal_style.content_margin_left = 8
	normal_style.content_margin_right = 8
	normal_style.content_margin_top = 6
	normal_style.content_margin_bottom = 6
	normal_style.border_width_left = 0
	normal_style.border_width_right = 0
	normal_style.border_width_top = 0
	normal_style.border_width_bottom = 0
	
	# Pressed/selected state - with border
	var pressed_style = StyleBoxFlat.new()
	pressed_style.set_corner_radius_all(4)
	pressed_style.content_margin_left = 8
	pressed_style.content_margin_right = 8
	pressed_style.content_margin_top = 6
	pressed_style.content_margin_bottom = 6
	pressed_style.border_width_left = 2
	pressed_style.border_width_right = 2
	pressed_style.border_width_top = 2
	pressed_style.border_width_bottom = 2
	
	# Base colors by status (same background for both selected and unselected)
	var bg_color: Color
	var border_color: Color
	
	if status == PlaycademyBackendManager.ServerStatus.RUNNING:
		bg_color = Color("#1f3f1f")
		border_color = Color("#4a8a4a")
	elif status == PlaycademyBackendManager.ServerStatus.STARTING:
		bg_color = Color("#3f331f")
		border_color = Color("#8a7a4a")
	elif status == PlaycademyBackendManager.ServerStatus.ERROR:
		bg_color = Color("#3f1f1f")
		border_color = Color("#8a4a4a")
	else:
		# Stopped
		bg_color = Color("#2a2a2a")
		border_color = Color("#5a5a5a")
	
	normal_style.bg_color = bg_color
	pressed_style.bg_color = bg_color
	pressed_style.border_color = border_color
	
	# Apply styles consistently to all states
	button.add_theme_stylebox_override("normal", normal_style)
	button.add_theme_stylebox_override("hover", normal_style)
	button.add_theme_stylebox_override("pressed", pressed_style)
	button.add_theme_stylebox_override("focus", pressed_style)
	
	# Keep font color consistent (white) regardless of state
	var font_color = Color(1, 1, 1, 1)  # White
	button.add_theme_color_override("font_color", font_color)
	button.add_theme_color_override("font_pressed_color", font_color)
	button.add_theme_color_override("font_hover_color", font_color)
	button.add_theme_color_override("font_focus_color", font_color)
	button.add_theme_color_override("font_hover_pressed_color", font_color)
	button.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0))  # No outline
	button.add_theme_color_override("font_disabled_color", Color(1, 1, 1, 0.5))  # Dimmed when disabled

func _on_start_pressed():
	if backend_manager:
		backend_manager.start_servers()

func _on_stop_pressed():
	if backend_manager:
		backend_manager.stop_servers()

func _on_restart_pressed():
	if backend_manager:
		backend_manager.restart_servers()

func _on_reset_db_pressed():
	if backend_manager:
		backend_manager.reset_database()

func _on_auto_start_toggled(pressed: bool):
	ProjectSettings.set_setting("playcademy/backend/auto_start", pressed)
	ProjectSettings.save()

func _on_status_changed(status_string: String):
	_update_ui()

func _on_sandbox_started(url: String):
	_update_ui()

func _on_backend_started(url: String):
	_update_ui()

func _on_servers_stopped():
	_update_ui()

func _on_server_failed(server_type: String, error: String):
	_update_ui()

func _exit_tree():
	if log_update_timer:
		log_update_timer.stop()
