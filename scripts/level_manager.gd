extends Node

# Level manager - handles level button creation, pack outlines, and level availability

# Node references
var main_menu_node: Control  # Reference to the MainMenu node
var grade_label: Label  # Reference to the GradeLabel node
var left_button: Button  # Reference to the LeftButton for grade navigation
var right_button: Button  # Reference to the RightButton for grade navigation

# Dynamic level button references
var level_buttons = []  # Array to store dynamically created level buttons (each entry: {button: Button, category_name: String, level_index: int, level_data: Dictionary, global_number: int})
var level_pack_outlines = []  # Array to store dynamically created pack outline nodes
var label_settings_64: LabelSettings  # Label settings for button numbers
var star_icon_texture: Texture2D  # Texture for star icons

func initialize(main_node: Control):
	"""Initialize level manager with references to needed nodes"""
	main_menu_node = main_node.get_node("MainMenu")
	grade_label = main_menu_node.get_node("GradeLabel")
	left_button = main_menu_node.get_node("LeftButton")
	right_button = main_menu_node.get_node("RightButton")
	label_settings_64 = load("res://assets/label settings/GravityBold64.tres")
	star_icon_texture = load("res://assets/sprites/Star Icon.png")

# ============================================
# Grade Navigation & Star Threshold Functions
# ============================================

func calculate_level_thresholds(mastery_count: int) -> Dictionary:
	"""Calculate star thresholds based on mastery count.
	Formula:
	- Total problems = ceil(mastery_count / 0.85)
	- 3 star accuracy = mastery_count
	- 2 star accuracy = 2 * mastery_count - total
	- 1 star accuracy = 3 * mastery_count - 2 * total
	Time requirements are fixed for all levels:
	- 3 stars: 2:00 (120s), 2 stars: 2:30 (150s), 1 star: 3:00 (180s)
	"""
	var total_problems = int(ceil(mastery_count / 0.85))
	var star3_accuracy = mastery_count
	var star2_accuracy = 2 * mastery_count - total_problems
	var star1_accuracy = 3 * mastery_count - 2 * total_problems
	
	return {
		"problems": total_problems,
		"star1": {"accuracy": star1_accuracy, "time": 180.0},
		"star2": {"accuracy": star2_accuracy, "time": 150.0},
		"star3": {"accuracy": star3_accuracy, "time": 120.0}
	}

func get_grade_data(grade: int) -> Dictionary:
	"""Get the level data for a specific grade"""
	if GameConfig.GRADE_LEVELS.has(grade):
		return GameConfig.GRADE_LEVELS[grade]
	return {}

func get_current_grade_data() -> Dictionary:
	"""Get the level data for the currently selected grade"""
	return get_grade_data(GameConfig.current_grade)

func has_previous_grade() -> bool:
	"""Check if there's a previous grade available"""
	var current_index = GameConfig.GRADES.find(GameConfig.current_grade)
	return current_index > 0

func has_next_grade() -> bool:
	"""Check if there's a next grade available"""
	var current_index = GameConfig.GRADES.find(GameConfig.current_grade)
	return current_index < GameConfig.GRADES.size() - 1

func go_to_previous_grade() -> bool:
	"""Go to the previous grade. Returns true if successful."""
	if has_previous_grade():
		var current_index = GameConfig.GRADES.find(GameConfig.current_grade)
		GameConfig.current_grade = GameConfig.GRADES[current_index - 1]
		return true
	return false

func go_to_next_grade() -> bool:
	"""Go to the next grade. Returns true if successful."""
	if has_next_grade():
		var current_index = GameConfig.GRADES.find(GameConfig.current_grade)
		GameConfig.current_grade = GameConfig.GRADES[current_index + 1]
		return true
	return false

# ============================================
# Level Button Creation
# ============================================

func create_level_buttons():
	"""Dynamically create level buttons for the current grade"""
	# Clear any existing buttons first
	clear_level_buttons()
	
	# Update grade label and navigation buttons
	update_grade_display()
	
	var grade_data = get_current_grade_data()
	if grade_data.is_empty():
		print("Error: No data for current grade")
		return
	
	var global_button_number = 1
	var current_row_buttons = []  # Track buttons in current row for centering
	var current_row_outlines = []  # Track outlines in current row for centering
	var current_x = GameConfig.level_button_start_position.x
	var current_y = GameConfig.level_button_start_position.y
	var current_row_start_x = current_x
	
	# Iterate through each category in the current grade
	for category in grade_data.categories:
		var category_name = category.name
		var category_levels = category.levels
		var theme_color = GameConfig.CATEGORY_COLORS.get(category_name, Color(0.5, 0.5, 0.5))
		
		var category_first_button_in_row = true  # Track if this is the first button of the category in this row
		var category_buttons_in_row = []  # Track buttons of this category in current row
		var outline_start_x = 0.0  # Track where outline should start
		
		# Iterate through each level in the category
		for level_index in range(category_levels.size()):
			var level_data = category_levels[level_index]
			
			# Check if this button is the first in a new category segment on this row
			if category_first_button_in_row:
				# Add extra spacing if not the first category on the row
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
				
				# Create new outline for continuation of category on new row
				if category_buttons_in_row.size() > 0:
					# Finalize previous row's category outline
					create_pack_outline(category_name, category_buttons_in_row, outline_start_x, current_row_outlines, theme_color)
					category_buttons_in_row.clear()
				
				# Reset for new row
				category_first_button_in_row = true
				outline_start_x = current_x
			
			# Create button at current position
			var button_position = Vector2(current_x, current_y)
			var button = create_grade_level_button(global_button_number, category_name, level_index, level_data, button_position, theme_color)
			
			# Track button
			current_row_buttons.append(button)
			category_buttons_in_row.append(button)
			level_buttons.append({
				"button": button,
				"category_name": category_name,
				"level_index": level_index,
				"level_data": level_data,
				"global_number": global_button_number
			})
			
			# Move to next button position
			current_x += GameConfig.level_button_spacing.x
			global_button_number += 1
			category_first_button_in_row = false
		
		# Create outline for this category segment (or final segment if wrapped)
		if category_buttons_in_row.size() > 0:
			create_pack_outline(category_name, category_buttons_in_row, outline_start_x, current_row_outlines, theme_color)
			category_buttons_in_row.clear()
	
	# Finalize and center the last row
	if current_row_buttons.size() > 0:
		finalize_and_center_row(current_row_buttons, current_row_outlines, current_row_start_x)

func clear_level_buttons():
	"""Remove all existing level buttons and outlines"""
	# Remove all level buttons
	for button_data in level_buttons:
		if button_data.button and is_instance_valid(button_data.button):
			button_data.button.queue_free()
	level_buttons.clear()
	
	# Remove all pack outlines
	for outline in level_pack_outlines:
		if outline and is_instance_valid(outline):
			outline.queue_free()
	level_pack_outlines.clear()

func update_grade_display():
	"""Update the grade label and navigation button states"""
	if grade_label:
		grade_label.text = "Grade " + str(GameConfig.current_grade)
	
	if left_button:
		left_button.disabled = not has_previous_grade()
		var left_icon = left_button.get_node_or_null("Icon")
		if left_icon:
			left_icon.modulate.a = 0.5 if left_button.disabled else 1.0
	
	if right_button:
		right_button.disabled = not has_next_grade()
		var right_icon = right_button.get_node_or_null("Icon")
		if right_icon:
			right_icon.modulate.a = 0.5 if right_button.disabled else 1.0

func switch_to_previous_grade():
	"""Switch to the previous grade and recreate buttons"""
	if go_to_previous_grade():
		create_level_buttons()
		update_menu_stars()
		update_level_availability()

func switch_to_next_grade():
	"""Switch to the next grade and recreate buttons"""
	if go_to_next_grade():
		create_level_buttons()
		update_menu_stars()
		update_level_availability()

func create_grade_level_button(global_number: int, _category_name: String, _level_index: int, level_data: Dictionary, button_position: Vector2, theme_color: Color) -> Button:
	"""Create a single level button for the grade-based system"""
	var button = Button.new()
	button.name = "LevelButton_" + level_data.id
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
	
	# Set tooltip to level name
	button.tooltip_text = level_data.name
	
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
	
	# Connect button press - pass level_data instead of pack/track info
	button.pressed.connect(StateManager._on_grade_level_button_pressed.bind(level_data))
	UIManager.connect_button_sounds(button)
	
	return button

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
		var level_data = button_data.level_data
		var level_id = level_data.id
		
		# Get save data for this level using the new level ID format
		var stars_earned = SaveManager.get_grade_level_stars(level_id)
		
		# Update star sprites
		var contents = button.get_node("Contents")
		if contents:
			for star_num in range(1, 4):
				var star_sprite = contents.get_node("Star" + str(star_num))
				if star_sprite:
					star_sprite.frame = 1 if star_num <= stars_earned else 0

func update_level_availability():
	"""Update level button availability based on category-based progression within current grade"""
	# Track the previous level in each category
	var category_prev_level = {}  # category_name -> previous level_id
	
	for button_data in level_buttons:
		var button = button_data.button
		var category_name = button_data.category_name
		var level_data = button_data.level_data
		var level_id = level_data.id
		var level_index = button_data.level_index
		
		var should_be_available = true
		
		# First level of each category is always available
		if level_index > 0:
			# Check if current level has at least 1 star (already unlocked)
			var current_stars = SaveManager.get_grade_level_stars(level_id)
			if current_stars > 0:
				should_be_available = true
			else:
				# Check if previous level in this category has at least 1 star
				var prev_level_id = category_prev_level.get(category_name, "")
				if prev_level_id != "":
					var prev_stars = SaveManager.get_grade_level_stars(prev_level_id)
					should_be_available = prev_stars > 0
				else:
					should_be_available = false
		
		# Track this level as the previous for the next iteration
		category_prev_level[category_name] = level_id
		
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
	
	# Check if all levels across all packs have at least 1 star (legacy check)
	var all_levels_completed = true
	for pack_name in GameConfig.legacy_level_pack_order:
		var pack_config = GameConfig.legacy_level_packs[pack_name]
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
	"""Get the global level number (1-11) for a pack and index (legacy)"""
	var global_num = 1
	for pack in GameConfig.legacy_level_pack_order:
		var pack_config = GameConfig.legacy_level_packs[pack]
		if pack == pack_name:
			return global_num + pack_level_index
		else:
			global_num += pack_config.levels.size()
	return 1  # Fallback
