extends Node

# Level manager - handles level button creation, pack outlines, and level availability

# Node references
var main_menu_node: Control  # Reference to the MainMenu node
var grade_label: Label  # Reference to the GradeLabel node
var left_button: Button  # Reference to the LeftButton for grade navigation
var right_button: Button  # Reference to the RightButton for grade navigation

# Page container system - stores loaded pages for smooth transitions
var loaded_pages = {}  # Dictionary: {global_page_index: Control (container)}
var current_global_page_index = 0  # Current page being viewed
var page_transition_tween: Tween = null  # Active tween for page transitions

# Level button data for all loaded pages
var all_level_buttons = {}  # Dictionary: {global_page_index: Array of button data}

# Legacy references (for compatibility)
var level_buttons = []  # Points to current page's buttons
var level_pack_outlines = []  # Points to current page's outlines
var label_settings_64: LabelSettings  # Label settings for button numbers
var star_icon_texture: Texture2D  # Texture for star icons

# Play button for new players (assessment not completed)
var play_button: Button = null

# XP Warning
var xp_warning_label: Label = null  # Reference to the XpWarning label

func initialize(main_node: Control):
	"""Initialize level manager with references to needed nodes"""
	main_menu_node = main_node.get_node("MainMenu")
	grade_label = main_menu_node.get_node("GradeLabel")
	left_button = main_menu_node.get_node("LeftButton")
	right_button = main_menu_node.get_node("RightButton")
	play_button = main_menu_node.get_node_or_null("PlayButton")
	label_settings_64 = load("res://assets/label settings/GravityBold64.tres")
	star_icon_texture = load("res://assets/sprites/Star Icon.png")
	
	# Get XP warning label reference
	xp_warning_label = main_menu_node.get_node_or_null("XpWarning")
	if xp_warning_label:
		xp_warning_label.visible = false
	
	# Connect PlayButton if it exists
	if play_button:
		play_button.pressed.connect(StateManager._on_play_button_pressed)
		UIManager.connect_button_sounds(play_button)
	
	# Calculate initial global page index
	current_global_page_index = get_global_page_index(GameConfig.current_grade, GameConfig.current_grade_page)

# ============================================
# Grade Navigation Functions
# ============================================

func get_grade_data(grade: int) -> Dictionary:
	"""Get the level data for a specific grade"""
	if GameConfig.GRADE_LEVELS.has(grade):
		return GameConfig.GRADE_LEVELS[grade]
	return {}

func get_current_grade_data() -> Dictionary:
	"""Get the level data for the currently selected grade"""
	return get_grade_data(GameConfig.current_grade)

func calculate_grade_pages(grade: int) -> Array:
	"""Calculate which levels go on each page for a grade.
	Returns an array of pages, where each page is an array of {category, level_indices} dicts."""
	var grade_data = get_grade_data(grade)
	if grade_data.is_empty():
		return []
	
	var pages = []
	var current_page_levels = []  # Array of {category_name, category, start_index, end_index}
	var current_x = GameConfig.level_button_start_position.x
	var current_row = 0
	
	for category in grade_data.categories:
		var category_name = category.name
		var category_levels = category.levels
		var category_start_index = 0
		var levels_on_current_page = 0
		
		for level_index in range(category_levels.size()):
			var remaining_levels = category_levels.size() - level_index
			
			# Check if this is the start of a new category segment
			var is_first_in_segment = (level_index == category_start_index)
			if is_first_in_segment and current_page_levels.size() > 0 or (is_first_in_segment and current_x > GameConfig.level_button_start_position.x):
				# Add spacing before category
				if current_x > GameConfig.level_button_start_position.x:
					current_x += abs(GameConfig.pack_outline_offset.x)
			
			var button_right_edge = current_x + GameConfig.level_button_size.x
			var needs_wrap = button_right_edge > GameConfig.level_button_start_position.x + GameConfig.max_row_width
			
			# Check for single-button split prevention
			if not needs_wrap and is_first_in_segment and remaining_levels > 1:
				var second_button_right_edge = current_x + GameConfig.level_button_spacing.x + GameConfig.level_button_size.x
				if second_button_right_edge > GameConfig.level_button_start_position.x + GameConfig.max_row_width:
					needs_wrap = true
			
			if needs_wrap:
				current_row += 1
				current_x = GameConfig.level_button_start_position.x
				
				# Check if we need a new page
				if current_row >= GameConfig.max_rows_per_screen:
					# Save current category progress if any
					if levels_on_current_page > 0:
						current_page_levels.append({
							"category_name": category_name,
							"category": category,
							"start_index": category_start_index,
							"end_index": level_index - 1
						})
					
					# Start new page
					if current_page_levels.size() > 0:
						pages.append(current_page_levels)
					current_page_levels = []
					current_row = 0
					category_start_index = level_index
					levels_on_current_page = 0
			
			# "Place" button
			current_x += GameConfig.level_button_spacing.x
			levels_on_current_page += 1
		
		# End of category - record it
		if levels_on_current_page > 0:
			current_page_levels.append({
				"category_name": category_name,
				"category": category,
				"start_index": category_start_index,
				"end_index": category_levels.size() - 1
			})
			levels_on_current_page = 0
	
	# Add final page
	if current_page_levels.size() > 0:
		pages.append(current_page_levels)
	
	return pages

func get_total_pages_for_grade(grade: int) -> int:
	"""Get the total number of pages for a grade"""
	var pages = calculate_grade_pages(grade)
	return max(1, pages.size())

func get_current_grade_total_pages() -> int:
	"""Get total pages for the current grade"""
	return get_total_pages_for_grade(GameConfig.current_grade)

# ============================================
# Global Page Index System
# ============================================

func get_total_global_pages() -> int:
	"""Get total number of pages across all grades"""
	var total = 0
	for grade in GameConfig.GRADES:
		total += get_total_pages_for_grade(grade)
	return total

func get_global_page_index(grade: int, page: int) -> int:
	"""Convert grade + page to global page index (0-indexed)"""
	var global_index = 0
	for g in GameConfig.GRADES:
		if g == grade:
			return global_index + page - 1  # page is 1-indexed
		global_index += get_total_pages_for_grade(g)
	return 0

func get_grade_and_page_from_global_index(global_index: int) -> Dictionary:
	"""Convert global page index to grade + page"""
	var running_index = 0
	for grade in GameConfig.GRADES:
		var pages_in_grade = get_total_pages_for_grade(grade)
		if global_index < running_index + pages_in_grade:
			return {"grade": grade, "page": global_index - running_index + 1}
		running_index += pages_in_grade
	# Fallback to last grade, last page
	var last_grade = GameConfig.GRADES[GameConfig.GRADES.size() - 1]
	return {"grade": last_grade, "page": get_total_pages_for_grade(last_grade)}

func has_previous_screen() -> bool:
	"""Check if there's a previous screen available"""
	return current_global_page_index > 0

func has_next_screen() -> bool:
	"""Check if there's a next screen available"""
	return current_global_page_index < get_total_global_pages() - 1

func go_to_previous_screen() -> bool:
	"""Go to the previous screen. Returns true if successful."""
	if has_previous_screen():
		current_global_page_index -= 1
		var grade_page = get_grade_and_page_from_global_index(current_global_page_index)
		GameConfig.current_grade = grade_page.grade
		GameConfig.current_grade_page = grade_page.page
		return true
	return false

func go_to_next_screen() -> bool:
	"""Go to the next screen. Returns true if successful."""
	if has_next_screen():
		current_global_page_index += 1
		var grade_page = get_grade_and_page_from_global_index(current_global_page_index)
		GameConfig.current_grade = grade_page.grade
		GameConfig.current_grade_page = grade_page.page
		return true
	return false

# Legacy functions for backwards compatibility
func has_previous_grade() -> bool:
	return has_previous_screen()

func has_next_grade() -> bool:
	return has_next_screen()

func go_to_previous_grade() -> bool:
	return go_to_previous_screen()

func go_to_next_grade() -> bool:
	return go_to_next_screen()

# ============================================
# Level Button Creation
# ============================================

func create_level_buttons():
	"""Initialize the page system and load the first page"""
	# Clear all loaded pages
	clear_all_pages()
	
	# Ensure global page index is synced
	current_global_page_index = get_global_page_index(GameConfig.current_grade, GameConfig.current_grade_page)
	
	# Load and position the current page
	load_page(current_global_page_index)
	position_page_container(current_global_page_index, 0)  # Position at center (offset 0)
	
	# Update display
	update_grade_display()

func load_page(global_page_index: int) -> Control:
	"""Load a page into a container and return it. Returns existing container if already loaded."""
	if loaded_pages.has(global_page_index):
		return loaded_pages[global_page_index]
	
	# Get grade and page from global index
	var grade_page = get_grade_and_page_from_global_index(global_page_index)
	var grade = grade_page.grade
	var page = grade_page.page
	
	# Create page container - must have same size/anchors as parent for button positioning to work
	var page_container = Control.new()
	page_container.name = "PageContainer_" + str(global_page_index)
	page_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	page_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	page_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	page_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_menu_node.add_child(page_container)
	
	# Store container
	loaded_pages[global_page_index] = page_container
	all_level_buttons[global_page_index] = []
	
	# Get page data
	var pages = calculate_grade_pages(grade)
	if pages.is_empty() or page - 1 >= pages.size():
		return page_container
	
	var page_data = pages[page - 1]
	
	# Calculate global button number offset
	var global_button_number = 1
	# Add buttons from previous grades
	for g in GameConfig.GRADES:
		if g >= grade:
			break
		var g_pages = calculate_grade_pages(g)
		for p in g_pages:
			for segment in p:
				global_button_number += segment.end_index - segment.start_index + 1
	# Add buttons from previous pages in this grade
	for prev_page_idx in range(page - 1):
		for segment in pages[prev_page_idx]:
			global_button_number += segment.end_index - segment.start_index + 1
	
	var current_row_buttons = []
	var current_row_outlines = []
	var current_x = GameConfig.level_button_start_position.x
	var current_y = GameConfig.level_button_start_position.y
	var current_row_start_x = current_x
	var categories_labeled_on_page = {}  # Track which categories have already shown their label on this page
	
	# Iterate through each category segment on this page
	for segment in page_data:
		var category_name = segment.category_name
		var category = segment.category
		var category_levels = category.levels
		var theme_color = GameConfig.CATEGORY_COLORS.get(category_name, Color(0.5, 0.5, 0.5))
		
		var category_first_button_in_row = true
		var category_buttons_in_row = []
		var outline_start_x = 0.0
		
		for level_index in range(segment.start_index, segment.end_index + 1):
			var level_data = category_levels[level_index]
			var remaining_in_segment = segment.end_index - level_index + 1
			
			if category_first_button_in_row:
				if current_row_buttons.size() > 0:
					current_x += abs(GameConfig.pack_outline_offset.x)
				outline_start_x = current_x
			
			var button_right_edge = current_x + GameConfig.level_button_size.x
			var needs_wrap = button_right_edge > GameConfig.level_button_start_position.x + GameConfig.max_row_width
			
			if not needs_wrap and category_first_button_in_row and remaining_in_segment > 1:
				var second_button_right_edge = current_x + GameConfig.level_button_spacing.x + GameConfig.level_button_size.x
				if second_button_right_edge > GameConfig.level_button_start_position.x + GameConfig.max_row_width:
					needs_wrap = true
			
			if needs_wrap:
				if category_buttons_in_row.size() > 0:
					var show_label = not categories_labeled_on_page.has(category_name)
					create_pack_outline_in_container(page_container, category_name, category_buttons_in_row, outline_start_x, current_row_outlines, theme_color, show_label)
					categories_labeled_on_page[category_name] = true
					category_buttons_in_row.clear()
				
				finalize_and_center_row(current_row_buttons, current_row_outlines, current_row_start_x)
				
				current_x = GameConfig.level_button_start_position.x
				current_y += GameConfig.level_button_spacing.y
				current_row_start_x = current_x
				current_row_buttons.clear()
				current_row_outlines.clear()
				
				category_first_button_in_row = true
				outline_start_x = current_x
			
			var button_position = Vector2(current_x, current_y)
			var button = create_grade_level_button_in_container(page_container, global_button_number, category_name, level_index, level_data, button_position, theme_color)
			
			current_row_buttons.append(button)
			category_buttons_in_row.append(button)
			all_level_buttons[global_page_index].append({
				"button": button,
				"category_name": category_name,
				"level_index": level_index,
				"level_data": level_data,
				"global_number": global_button_number
			})
			
			current_x += GameConfig.level_button_spacing.x
			global_button_number += 1
			category_first_button_in_row = false
		
		if category_buttons_in_row.size() > 0:
			var show_label = not categories_labeled_on_page.has(category_name)
			create_pack_outline_in_container(page_container, category_name, category_buttons_in_row, outline_start_x, current_row_outlines, theme_color, show_label)
			categories_labeled_on_page[category_name] = true
			category_buttons_in_row.clear()
	
	if current_row_buttons.size() > 0:
		finalize_and_center_row(current_row_buttons, current_row_outlines, current_row_start_x)
	
	# Update level_buttons to point to current page's buttons for compatibility
	if global_page_index == current_global_page_index:
		level_buttons = all_level_buttons[global_page_index]
	
	return page_container

func position_page_container(global_page_index: int, x_offset: float):
	"""Position a page container at the given X offset from center"""
	if not loaded_pages.has(global_page_index):
		return
	var container = loaded_pages[global_page_index]
	# Use offset_left/offset_right to slide the container since it has full rect anchors
	container.offset_left = x_offset
	container.offset_right = x_offset

func animate_all_pages_to_positions():
	"""Animate all loaded pages to their correct positions relative to current page"""
	# Kill existing tween if any
	if page_transition_tween and page_transition_tween.is_valid():
		page_transition_tween.kill()
	
	page_transition_tween = create_tween()
	page_transition_tween.set_ease(GameConfig.page_transition_ease)
	page_transition_tween.set_trans(Tween.TRANS_QUAD)
	page_transition_tween.set_parallel(true)
	
	for page_index in loaded_pages.keys():
		var container = loaded_pages[page_index]
		var offset_from_current = page_index - current_global_page_index
		var target_x = offset_from_current * GameConfig.page_width
		# Animate both offset_left and offset_right to slide the container
		page_transition_tween.tween_property(container, "offset_left", target_x, GameConfig.page_transition_duration)
		page_transition_tween.tween_property(container, "offset_right", target_x, GameConfig.page_transition_duration)

func clear_all_pages():
	"""Remove all loaded page containers"""
	for page_index in loaded_pages.keys():
		var container = loaded_pages[page_index]
		if container and is_instance_valid(container):
			container.queue_free()
	loaded_pages.clear()
	all_level_buttons.clear()
	level_buttons = []

func clear_level_buttons():
	"""Legacy function - calls clear_all_pages"""
	clear_all_pages()

func update_grade_display():
	"""Update the grade label and navigation button states"""
	var assessment_completed = SaveManager.is_assessment_completed()
	
	if grade_label:
		if not assessment_completed:
			# New player - hide grade label
			grade_label.visible = false
		else:
			grade_label.visible = true
			var total_pages = get_current_grade_total_pages()
			if total_pages > 1:
				# Show page number for multi-page grades
				grade_label.text = "Grade " + str(GameConfig.current_grade) + " (" + str(GameConfig.current_grade_page) + "/" + str(total_pages) + ")"
			else:
				grade_label.text = "Grade " + str(GameConfig.current_grade)
	
	# Update navigation buttons visibility based on assessment completion
	if left_button:
		if not assessment_completed:
			left_button.visible = false
		else:
			left_button.visible = true
			var can_go_left = has_previous_screen()
			left_button.disabled = not can_go_left
			var left_icon = left_button.get_node_or_null("Icon")
			if left_icon:
				left_icon.modulate.a = 0.5 if left_button.disabled else 1.0
	
	if right_button:
		if not assessment_completed:
			right_button.visible = false
		else:
			right_button.visible = true
			var can_go_right = has_next_screen()
			right_button.disabled = not can_go_right
			var right_icon = right_button.get_node_or_null("Icon")
			if right_icon:
				right_icon.modulate.a = 0.5 if right_button.disabled else 1.0
	
	# Update PlayButton visibility
	if play_button:
		play_button.visible = not assessment_completed

func switch_to_previous_grade():
	"""Switch to the previous page with smooth animation"""
	if not has_previous_screen():
		return
	
	# Update current page index
	go_to_previous_screen()
	
	# Load the new page if not already loaded
	load_page(current_global_page_index)
	
	# Position new page immediately to the left (will animate in)
	position_page_container(current_global_page_index, -GameConfig.page_width)
	
	# Animate all pages to their new positions
	animate_all_pages_to_positions()
	
	# Update display and stars
	update_grade_display()
	update_menu_stars()
	update_level_availability()
	
	# Update level_buttons reference to current page
	if all_level_buttons.has(current_global_page_index):
		level_buttons = all_level_buttons[current_global_page_index]

func switch_to_next_grade():
	"""Switch to the next page with smooth animation"""
	if not has_next_screen():
		return
	
	# Update current page index
	go_to_next_screen()
	
	# Load the new page if not already loaded
	load_page(current_global_page_index)
	
	# Position new page immediately to the right (will animate in)
	position_page_container(current_global_page_index, GameConfig.page_width)
	
	# Animate all pages to their new positions
	animate_all_pages_to_positions()
	
	# Update display and stars
	update_grade_display()
	update_menu_stars()
	update_level_availability()
	
	# Update level_buttons reference to current page
	if all_level_buttons.has(current_global_page_index):
		level_buttons = all_level_buttons[current_global_page_index]

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

func create_grade_level_button_in_container(container: Control, global_number: int, _category_name: String, _level_index: int, level_data: Dictionary, button_position: Vector2, theme_color: Color) -> Button:
	"""Create a level button inside a page container"""
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
	
	# Add button to container instead of main_menu_node
	container.add_child(button)
	
	# Connect button press
	button.pressed.connect(StateManager._on_grade_level_button_pressed.bind(level_data))
	UIManager.connect_button_sounds(button)
	
	# Connect hover signals for XP warning
	button.mouse_entered.connect(_on_level_button_hover_enter.bind(level_data))
	button.mouse_exited.connect(_on_level_button_hover_exit)
	
	return button

func _on_level_button_hover_enter(level_data: Dictionary):
	"""Show XP warning when hovering over a level with 3 stars"""
	if not xp_warning_label:
		return
	
	var level_id = level_data.get("id", "")
	var stars = SaveManager.get_grade_level_stars(level_id)
	
	# Show warning if level has 3 stars (reduced XP for replay)
	xp_warning_label.visible = (stars >= 3)

func _on_level_button_hover_exit():
	"""Hide XP warning when mouse leaves level button"""
	if xp_warning_label:
		xp_warning_label.visible = false

func create_pack_outline_in_container(container: Control, pack_name: String, pack_buttons: Array, start_x: float, row_outlines: Array, theme_color: Color, show_label_text: bool = true):
	"""Create a level pack outline inside a page container.
	If show_label_text is false, the label text will be hidden (for duplicate pack labels on same page)."""
	if pack_buttons.size() == 0:
		return
	
	var num_buttons = pack_buttons.size()
	var outline_width = GameConfig.pack_outline_base_width + (num_buttons - 1) * GameConfig.level_button_spacing.x
	
	var first_button = pack_buttons[0]
	var outline_x = start_x + GameConfig.pack_outline_offset.x
	var outline_y = first_button.offset_top + GameConfig.pack_outline_offset.y
	
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
	
	var shape_horizontal = ColorRect.new()
	shape_horizontal.name = "ShapeHorizontal"
	shape_horizontal.position = Vector2(0, 0)
	shape_horizontal.size = Vector2(outline_width, GameConfig.pack_outline_height)
	shape_horizontal.color = theme_color
	outline_container.add_child(shape_horizontal)
	
	var tail_horizontal = Sprite2D.new()
	tail_horizontal.name = "TailHorizontal"
	var triangle_texture = load("res://assets/sprites/Triangle.png")
	tail_horizontal.texture = triangle_texture
	tail_horizontal.self_modulate = theme_color
	tail_horizontal.position = Vector2(outline_width + 32, GameConfig.pack_outline_height / 2.0)
	tail_horizontal.scale = Vector2(2, 1)
	outline_container.add_child(tail_horizontal)
	
	var shape_vertical = ColorRect.new()
	shape_vertical.name = "ShapeVertical"
	shape_vertical.position = Vector2(0, GameConfig.pack_outline_height)
	shape_vertical.size = Vector2(GameConfig.pack_outline_height, GameConfig.pack_outline_vertical_height)
	shape_vertical.color = theme_color
	outline_container.add_child(shape_vertical)
	
	var tail_vertical = Sprite2D.new()
	tail_vertical.name = "TailVertical"
	tail_vertical.texture = triangle_texture
	tail_vertical.self_modulate = theme_color
	tail_vertical.position = Vector2(GameConfig.pack_outline_height / 2.0, GameConfig.pack_outline_height + GameConfig.pack_outline_vertical_height + 32)
	tail_vertical.rotation = 4.712389
	tail_vertical.scale = Vector2(-2, 1)
	outline_container.add_child(tail_vertical)
	
	var label_settings_24 = load("res://assets/label settings/GravityBold24Plain.tres")
	var label = Label.new()
	label.name = "Label"
	label.position = Vector2(4, 4)
	label.size = Vector2(outline_width - 8, GameConfig.pack_outline_height - 8)
	label.text = pack_name if show_label_text else ""  # Hide label text for duplicate pack on same page
	label.label_settings = label_settings_24
	outline_container.add_child(label)
	
	# Add to container instead of main_menu_node
	container.add_child(outline_container)
	row_outlines.append(outline_container)

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
	# Update stars for all loaded pages
	for page_index in all_level_buttons.keys():
		for button_data in all_level_buttons[page_index]:
			var button = button_data.button
			if not is_instance_valid(button):
				continue
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
	# Update availability for all loaded pages
	for page_index in all_level_buttons.keys():
		# Track the previous level in each category
		var category_prev_level = {}  # category_name -> previous level_id
		
		for button_data in all_level_buttons[page_index]:
			var button = button_data.button
			if not is_instance_valid(button):
				continue
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
					# Check if previous level in this category has enough stars to unlock this level
					var prev_level_id = category_prev_level.get(category_name, "")
					if prev_level_id != "":
						var prev_stars = SaveManager.get_grade_level_stars(prev_level_id)
						should_be_available = prev_stars >= GameConfig.stars_required_to_unlock_next_level
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
	
	# Update grade display (navigation buttons) based on assessment completion
	update_grade_display()

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

func initialize_with_assessment_check():
	"""Initialize the level manager. New players see PlayButton only, returning players see level packs."""
	var assessment_completed = SaveManager.is_assessment_completed()
	
	# Always start at Grade 1
	GameConfig.current_grade = 1
	GameConfig.current_grade_page = 1
	
	# Update global page index
	current_global_page_index = get_global_page_index(GameConfig.current_grade, GameConfig.current_grade_page)
	
	# For new players, don't create level buttons yet - they'll see PlayButton instead
	# Level buttons will be created after assessment completion
	if not assessment_completed:
		# Just update the display (which will show PlayButton and hide navigation)
		update_grade_display()
		return
	
	# For returning players, create level buttons as normal
	create_level_buttons()
	update_menu_stars()
	update_level_availability()
