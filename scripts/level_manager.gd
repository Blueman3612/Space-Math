extends Node

# Level manager - handles level button creation, pack outlines, and level availability

# Node references
var main_menu_node: Control  # Reference to the MainMenu node

# Dynamic level button references
var level_buttons = []  # Array to store dynamically created level buttons (each entry: {button: Button, pack_name: String, pack_level_index: int, global_number: int})
var level_pack_outlines = []  # Array to store dynamically created pack outline nodes
var label_settings_64: LabelSettings  # Label settings for button numbers
var star_icon_texture: Texture2D  # Texture for star icons

func initialize(main_node: Control):
	"""Initialize level manager with references to needed nodes"""
	main_menu_node = main_node.get_node("MainMenu")
	label_settings_64 = load("res://assets/label settings/GravityBold64.tres")
	star_icon_texture = load("res://assets/sprites/Star Icon.png")

func create_level_buttons():
	"""Dynamically create level buttons with level pack outlines"""
	var global_button_number = 1
	var current_row_buttons = []  # Track buttons in current row for centering
	var current_row_outlines = []  # Track outlines in current row for centering
	var current_x = GameConfig.level_button_start_position.x
	var current_y = GameConfig.level_button_start_position.y
	var current_row_start_x = current_x
	
	# Iterate through each pack in order
	for pack_name in GameConfig.level_pack_order:
		var pack_config = GameConfig.level_packs[pack_name]
		var pack_levels = pack_config.levels
		var theme_color = pack_config.theme_color
		
		var pack_first_button_in_row = true  # Track if this is the first button of the pack in this row
		var pack_buttons_in_row = []  # Track buttons of this pack in current row
		var outline_start_x = 0.0  # Track where outline should start
		
		# Iterate through each level in the pack
		for level_index in range(pack_levels.size()):
			var track_id = pack_levels[level_index]
			
			# Check if this button is the first in a new pack segment on this row
			if pack_first_button_in_row:
				# Add extra spacing if not the first pack on the row
				if current_row_buttons.size() > 0:
					current_x += abs(GameConfig.pack_outline_offset.x)
				outline_start_x = current_x
			
			# Calculate button right edge
			var button_right_edge = current_x + GameConfig.level_button_size.x
			
			# Check if we need to wrap to a new row
			if button_right_edge > GameConfig.level_button_start_position.x + GameConfig.max_row_width:
				# Finalize and center current row
				finalize_and_center_row(current_row_buttons, current_row_outlines, current_row_start_x)
				
				# Start new row
				current_x = GameConfig.level_button_start_position.x
				current_y += GameConfig.level_button_spacing.y
				current_row_start_x = current_x
				current_row_buttons.clear()
				current_row_outlines.clear()
				
				# Create new outline for continuation of pack on new row
				if pack_buttons_in_row.size() > 0:
					# Finalize previous row's pack outline
					create_pack_outline(pack_name, pack_buttons_in_row, outline_start_x, current_row_outlines, theme_color)
					pack_buttons_in_row.clear()
				
				# Reset for new row
				pack_first_button_in_row = true
				outline_start_x = current_x
			
			# Create button at current position
			var button_position = Vector2(current_x, current_y)
			var button = create_single_button(global_button_number, pack_name, level_index, track_id, button_position, theme_color)
			
			# Track button
			current_row_buttons.append(button)
			pack_buttons_in_row.append(button)
			level_buttons.append({
				"button": button,
				"pack_name": pack_name,
				"pack_level_index": level_index,
				"global_number": global_button_number
			})
			
			# Move to next button position
			current_x += GameConfig.level_button_spacing.x
			global_button_number += 1
			pack_first_button_in_row = false
		
		# Create outline for this pack segment (or final segment if wrapped)
		if pack_buttons_in_row.size() > 0:
			create_pack_outline(pack_name, pack_buttons_in_row, outline_start_x, current_row_outlines, theme_color)
			pack_buttons_in_row.clear()
	
	# Finalize and center the last row
	if current_row_buttons.size() > 0:
		finalize_and_center_row(current_row_buttons, current_row_outlines, current_row_start_x)

func create_single_button(global_number: int, pack_name: String, pack_level_index: int, track_id, button_position: Vector2, theme_color: Color) -> Button:
	"""Create a single level button"""
	var button = Button.new()
	button.name = "LevelButton_" + pack_name + "_" + str(pack_level_index)
	button.custom_minimum_size = GameConfig.level_button_size
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.self_modulate = theme_color
	
	# Set anchors and position (center anchored)
	button.anchor_left = 0.5
	button.anchor_top = 0.5
	button.anchor_right = 0.5
	button.anchor_bottom = 0.5
	button.offset_left = button_position.x
	button.offset_top = button_position.y
	button.offset_right = button_position.x + GameConfig.level_button_size.x
	button.offset_bottom = button_position.y + GameConfig.level_button_size.y
	button.grow_horizontal = Control.GROW_DIRECTION_BOTH
	button.grow_vertical = Control.GROW_DIRECTION_BOTH
	
	# Get tooltip from track data
	var question_data = QuestionManager.get_math_question(track_id)
	if question_data and question_data.has("title"):
		button.tooltip_text = question_data.title
	
	# Create Contents control
	var contents = Control.new()
	contents.name = "Contents"
	contents.set_anchors_preset(Control.PRESET_FULL_RECT)
	contents.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(contents)
	
	# Create Number label
	var number_label = Label.new()
	number_label.name = "Number"
	number_label.text = str(global_number)
	number_label.label_settings = label_settings_64
	number_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	number_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	number_label.position = Vector2(4, -32)
	number_label.size = Vector2(192, 192)
	contents.add_child(number_label)
	
	# Create star sprites
	var star_positions = [Vector2(44, 136), Vector2(96, 144), Vector2(148, 136)]
	for i in range(3):
		var star = Sprite2D.new()
		star.name = "Star" + str(i + 1)
		star.texture = star_icon_texture
		star.hframes = 2
		star.frame = 0  # Start with unearned star
		star.scale = Vector2(2, 2)
		star.position = star_positions[i]
		contents.add_child(star)
	
	# Add button to main menu
	main_menu_node.add_child(button)
	
	# Connect button press and sounds (note: will need to be implemented in StateManager)
	button.pressed.connect(StateManager._on_level_button_pressed.bind(pack_name, pack_level_index))
	UIManager.connect_button_sounds(button)
	
	return button

func create_pack_outline(pack_name: String, pack_buttons: Array, start_x: float, row_outlines: Array, theme_color: Color):
	"""Create a level pack outline for a segment of buttons"""
	if pack_buttons.size() == 0:
		return
	
	# Calculate outline width based on number of buttons
	var num_buttons = pack_buttons.size()
	var outline_width = GameConfig.pack_outline_base_width + (num_buttons - 1) * GameConfig.level_button_spacing.x
	
	# Get position from first button in segment
	var first_button = pack_buttons[0]
	var outline_x = start_x + GameConfig.pack_outline_offset.x
	var outline_y = first_button.offset_top + GameConfig.pack_outline_offset.y
	
	# Create outline container
	var outline_container = Control.new()
	outline_container.name = "LevelPackOutline_" + pack_name
	outline_container.anchor_left = 0.5
	outline_container.anchor_top = 0.5
	outline_container.anchor_right = 0.5
	outline_container.anchor_bottom = 0.5
	outline_container.offset_left = outline_x
	outline_container.offset_top = outline_y
	outline_container.offset_right = outline_x + 40
	outline_container.offset_bottom = outline_y + 40
	outline_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	# Create ShapeHorizontal
	var shape_horizontal = ColorRect.new()
	shape_horizontal.name = "ShapeHorizontal"
	shape_horizontal.position = Vector2(0, 0)
	shape_horizontal.size = Vector2(outline_width, GameConfig.pack_outline_height)
	shape_horizontal.color = theme_color
	outline_container.add_child(shape_horizontal)
	
	# Create TailHorizontal
	var tail_horizontal = Sprite2D.new()
	tail_horizontal.name = "TailHorizontal"
	var triangle_texture = load("res://assets/sprites/Triangle.png")
	tail_horizontal.texture = triangle_texture
	tail_horizontal.self_modulate = theme_color
	tail_horizontal.position = Vector2(outline_width + 32, GameConfig.pack_outline_height / 2.0)
	tail_horizontal.scale = Vector2(2, 1)
	outline_container.add_child(tail_horizontal)
	
	# Create ShapeVertical
	var shape_vertical = ColorRect.new()
	shape_vertical.name = "ShapeVertical"
	shape_vertical.position = Vector2(0, GameConfig.pack_outline_height)
	shape_vertical.size = Vector2(GameConfig.pack_outline_height, GameConfig.pack_outline_vertical_height)
	shape_vertical.color = theme_color
	outline_container.add_child(shape_vertical)
	
	# Create TailVertical
	var tail_vertical = Sprite2D.new()
	tail_vertical.name = "TailVertical"
	tail_vertical.texture = triangle_texture
	tail_vertical.self_modulate = theme_color
	tail_vertical.position = Vector2(GameConfig.pack_outline_height / 2.0, GameConfig.pack_outline_height + GameConfig.pack_outline_vertical_height + 32)
	tail_vertical.rotation = 4.712389  # -90 degrees in radians
	tail_vertical.scale = Vector2(-2, 1)
	outline_container.add_child(tail_vertical)
	
	# Create Label
	var label_settings_24 = load("res://assets/label settings/GravityBold24Plain.tres")
	var label = Label.new()
	label.name = "Label"
	label.position = Vector2(4, 4)
	label.size = Vector2(outline_width - 8, GameConfig.pack_outline_height - 8)
	label.text = pack_name
	label.label_settings = label_settings_24
	outline_container.add_child(label)
	
	# Add to main menu and track
	main_menu_node.add_child(outline_container)
	level_pack_outlines.append(outline_container)
	row_outlines.append(outline_container)

func finalize_and_center_row(row_buttons: Array, row_outlines: Array, _row_start_x: float):
	"""Center all buttons and outlines in a row by calculating equal padding"""
	if row_buttons.size() == 0:
		return
	
	# Calculate actual row width used (including outlines)
	var first_button = row_buttons[0]
	var last_button = row_buttons[row_buttons.size() - 1]
	
	# The leftmost point is the outline (which extends left of the first button)
	var row_left = first_button.offset_left + GameConfig.pack_outline_offset.x
	var row_right = last_button.offset_right
	var row_width = row_right - row_left
	
	# Calculate where the leftmost point should be to center the row
	# Available width is max_row_width (1792), centered within the screen
	# Screen is 1920 wide, buttons are center-anchored (anchor at 960)
	# Left boundary (in center-relative coords) = minimum_padding - 960 = 64 - 960 = -896
	var left_boundary = GameConfig.minimum_padding - 960.0  # Convert to center-relative coordinates
	var total_padding = GameConfig.max_row_width - row_width
	var padding_each_side = total_padding / 2.0
	
	# Target position for leftmost point
	var target_left = left_boundary + padding_each_side
	
	# Calculate offset needed to move current leftmost point to target
	var center_offset = target_left - row_left
	
	# Apply offset to all buttons in row
	for button in row_buttons:
		button.offset_left += center_offset
		button.offset_right += center_offset
	
	# Apply offset to all outlines in row
	for outline in row_outlines:
		outline.offset_left += center_offset
		outline.offset_right += center_offset

func update_menu_stars():
	"""Update the star display on menu level buttons based on save data"""
	for button_data in level_buttons:
		var button = button_data.button
		var pack_name = button_data.pack_name
		var pack_level_index = button_data.pack_level_index
		
		# Get save data for this level
		var stars_earned = 0
		if SaveManager.save_data.packs.has(pack_name):
			var pack_data = SaveManager.save_data.packs[pack_name]
			if pack_data.has("levels"):
				var level_key = str(pack_level_index)
				if pack_data.levels.has(level_key):
					stars_earned = pack_data.levels[level_key].highest_stars
		
		# Update star sprites
		var contents = button.get_node("Contents")
		if contents:
			for star_num in range(1, 4):
				var star_sprite = contents.get_node("Star" + str(star_num))
				if star_sprite:
					star_sprite.frame = 1 if star_num <= stars_earned else 0

func update_level_availability():
	"""Update level button availability based on pack-based progression"""
	for button_data in level_buttons:
		var button = button_data.button
		var pack_name = button_data.pack_name
		var pack_level_index = button_data.pack_level_index
		
		var should_be_available = true
		
		# First level of each pack is always available
		if pack_level_index > 0:
			# Check if previous level in this pack has at least 1 star
			var prev_level_key = str(pack_level_index - 1)
			if SaveManager.save_data.packs.has(pack_name) and SaveManager.save_data.packs[pack_name].has("levels"):
				if SaveManager.save_data.packs[pack_name].levels.has(prev_level_key):
					var prev_stars = SaveManager.save_data.packs[pack_name].levels[prev_level_key].highest_stars
					should_be_available = prev_stars > 0
				else:
					should_be_available = false
			else:
				should_be_available = false
		
		# Set button state
		button.disabled = not should_be_available
		
		# Update visual state
		var contents = button.get_node("Contents")
		if contents:
			if should_be_available:
				contents.modulate = Color(1, 1, 1, 1)  # Fully opaque
			else:
				contents.modulate = Color(1, 1, 1, 0.5)  # Half transparent
	
	# Update drill mode button availability
	update_drill_mode_availability()

func update_drill_mode_availability():
	"""Update drill mode button availability based on level completion across all packs"""
	var drill_mode_button = main_menu_node.get_node("DrillModeButton")
	if not drill_mode_button:
		return
	
	# Check if all levels across all packs have at least 1 star
	var all_levels_completed = true
	for pack_name in GameConfig.level_pack_order:
		var pack_config = GameConfig.level_packs[pack_name]
		if not SaveManager.save_data.packs.has(pack_name):
			all_levels_completed = false
			break
		
		var pack_data = SaveManager.save_data.packs[pack_name]
		if not pack_data.has("levels"):
			all_levels_completed = false
			break
		
		# Check each level in the pack
		for level_index in range(pack_config.levels.size()):
			var level_key = str(level_index)
			if not pack_data.levels.has(level_key):
				all_levels_completed = false
				break
			var stars = pack_data.levels[level_key].highest_stars
			if stars < 1:
				all_levels_completed = false
				break
		
		if not all_levels_completed:
			break
	
	# Set button state
	drill_mode_button.disabled = not all_levels_completed
	
	# Update visual state
	if all_levels_completed:
		drill_mode_button.modulate = Color(1, 1, 1, 1)  # Fully opaque
	else:
		drill_mode_button.modulate = Color(1, 1, 1, 0.5)  # Half transparent
	
	# Hide unlock requirements when drill mode becomes available
	var unlock_requirements = drill_mode_button.get_node("UnlockRequirements")
	if unlock_requirements:
		if all_levels_completed:
			unlock_requirements.visible = false

func get_global_level_number(pack_name: String, pack_level_index: int) -> int:
	"""Get the global level number (1-11) for a pack and index"""
	var global_num = 1
	for pack in GameConfig.level_pack_order:
		var pack_config = GameConfig.level_packs[pack]
		if pack == pack_name:
			return global_num + pack_level_index
		else:
			global_num += pack_config.levels.size()
	return 1  # Fallback

