extends Control

# Game state enum
enum GameState { MENU, PLAY, GAME_OVER }

# Math facts data and RNG
var math_facts = {}
var rng = RandomNumberGenerator.new()

# Game configuration variables
var blink_interval = 0.5  # Time for underscore blink cycle (fade in/out)
var max_answer_chars = 4  # Maximum characters for answer input
var animation_duration = 0.5  # Duration for label animations in seconds
var transition_delay = 0.1  # Delay before generating new question
var backspace_hold_time = 0.15  # Time to hold backspace before it repeats
var scroll_boost_multiplier = 80.0  # How much to boost background scroll speed on submission
var feedback_max_alpha = 0.1  # Maximum alpha for feedback color overlay
var problems_per_level = 5  # Number of problems to complete before returning to menu

# Title animation variables
var title_bounce_speed = 2.0  # Speed of the sin wave animation
var title_bounce_distance = 16.0  # Distance of the bounce in pixels

# Menu position constants
const menu_above_screen = Vector2(0, -1144)
const menu_below_screen = Vector2(0, 1144)
const menu_on_screen = Vector2(0, 0)

# Track progression mapping (button index to track number, ordered by difficulty)
const track_progression = [12, 9, 6, 10, 8, 11, 7, 5]

# Position variables
var primary_position = Vector2(416, 476)  # Main problem position
var off_screen_top = Vector2(416, 1276)   # Off-screen top position
var off_screen_bottom = Vector2(416, -324) # Off-screen bottom position

# Game state variables
var current_state = GameState.MENU
var current_problem_label: Label
var current_question = null  # Store current question data
var current_track = 0  # Current track being played
var problems_completed = 0  # Number of problems completed in current level
var user_answer = ""
var blink_timer = 0.0
var underscore_visible = true
var label_settings_resource: LabelSettings
var answer_submitted = false  # Track if current problem has been submitted
var backspace_timer = 0.0  # Timer for backspace hold functionality
var backspace_held = false  # Track if backspace is being held
var backspace_just_pressed = false  # Track if backspace was just pressed this frame
var feedback_color_rect: ColorRect  # Reference to the feedback color overlay
var main_menu_node: Control  # Reference to the MainMenu node
var game_over_node: Control  # Reference to the GameOver node
var title_sprite: Sprite2D  # Reference to the Title sprite
var title_base_position: Vector2  # Store the original position of the title
var title_animation_time = 0.0  # Track time for sin wave animation

func _ready():
	# Load and parse the math facts JSON
	var file = FileAccess.open("res://tools/math-facts.json", FileAccess.READ)
	if file:
		var json_string = file.get_as_text()
		file.close()
		
		var json = JSON.new()
		var parse_result = json.parse(json_string)
		if parse_result == OK:
			math_facts = json.data
		# Math facts loaded successfully
		else:
			print("Error parsing JSON: ", json.get_error_message())
	else:
		print("Could not open math-facts.json")
	
	# Initialize random number generator
	rng.randomize()
	
	# Load label settings resource
	label_settings_resource = load("res://assets/label settings/GravityBold128.tres")
	
	# Get reference to feedback color overlay, main menu, and game over
	feedback_color_rect = get_node("FeedbackColor")
	main_menu_node = get_node("MainMenu")
	game_over_node = get_node("GameOver")
	title_sprite = main_menu_node.get_node("Title")
	
	# Store the original position of the title for animation
	if title_sprite:
		title_base_position = title_sprite.position
	
	# Connect menu buttons
	connect_menu_buttons()
	connect_game_over_buttons()

func _input(event):
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_R:
			# Regenerate space background
			var space_bg = get_node("BackgroundLayer/SpaceBackground")
			if space_bg and space_bg.has_method("regenerate"):
				space_bg.regenerate()
		
		# Handle number input and negative sign (only during PLAY state and if not submitted)
		if current_state == GameState.PLAY and not answer_submitted:
			if event.keycode >= KEY_0 and event.keycode <= KEY_9:
				var digit = str(event.keycode - KEY_0)
				var effective_length = user_answer.length()
				if user_answer.begins_with("-"):
					effective_length -= 1  # Don't count negative sign toward limit
				if effective_length < max_answer_chars:
					user_answer += digit
					AudioManager.play_tick()  # Play tick sound on digit input
			
			# Handle negative sign (only at the beginning)
			elif event.keycode == KEY_MINUS and user_answer == "":
				user_answer = "-"
				AudioManager.play_tick()  # Play tick sound on minus input
			
			# Handle keypad numbers
			elif event.keycode >= KEY_KP_0 and event.keycode <= KEY_KP_9:
				var digit = str(event.keycode - KEY_KP_0)
				var effective_length = user_answer.length()
				if user_answer.begins_with("-"):
					effective_length -= 1  # Don't count negative sign toward limit
				if effective_length < max_answer_chars:
					user_answer += digit
					AudioManager.play_tick()  # Play tick sound on keypad digit input
	
	# Handle immediate backspace press detection (only during PLAY state)
	if Input.is_action_just_pressed("Backspace") and current_state == GameState.PLAY and not answer_submitted:
		backspace_just_pressed = true
	
	# Handle submit (only during PLAY state)
	if Input.is_action_just_pressed("Submit") and current_state == GameState.PLAY:
		submit_answer()

func _process(delta):
	# Animate title during MENU state
	if current_state == GameState.MENU and title_sprite:
		title_animation_time += delta * title_bounce_speed
		var bounce_offset = sin(title_animation_time) * title_bounce_distance
		title_sprite.position = title_base_position + Vector2(0, bounce_offset)
	
	# Only process game logic during PLAY state
	if current_state == GameState.PLAY:
		# Update blink timer
		blink_timer += delta
		if blink_timer >= blink_interval:
			blink_timer = 0.0
			underscore_visible = not underscore_visible
		
		# Handle backspace - immediate response for single press, hold for repeat
		if backspace_just_pressed and not answer_submitted:
			# Immediate backspace on first press
			if user_answer.length() > 0:
				user_answer = user_answer.substr(0, user_answer.length() - 1)
				AudioManager.play_tick()
			backspace_just_pressed = false
			backspace_timer = 0.0
		
		# Handle backspace hold functionality
		if Input.is_action_pressed("Backspace") and not answer_submitted:
			if not backspace_held:
				backspace_timer += delta
				if backspace_timer >= backspace_hold_time:
					backspace_held = true
					backspace_timer = 0.0
			else:
				# Repeat backspace every 0.05 seconds while held
				backspace_timer += delta
				if backspace_timer >= 0.05:
					backspace_timer = 0.0
					if user_answer.length() > 0:
						user_answer = user_answer.substr(0, user_answer.length() - 1)
						AudioManager.play_tick()
		else:
			# Reset hold state when backspace is released
			backspace_held = false
			backspace_timer = 0.0
		
		# Update problem display
		update_problem_display()

func setup_initial_problem():
	# Get the existing Problem label and set it up as current
	current_problem_label = get_node("Problem")
	if current_problem_label:
		current_problem_label.position = primary_position
		current_problem_label.label_settings = label_settings_resource
		# Only generate question if math facts are loaded
		if not math_facts.is_empty():
			generate_new_question()
		else:
			print("Math facts not loaded, cannot generate question")

func generate_new_question():
	user_answer = ""
	answer_submitted = false  # Reset submission state for new question
	# Store current question for answer checking later
	# Use the current track set by the level button
	current_question = get_math_question(current_track)
	if not current_question:
		print("Failed to generate question for track ", current_track)

func update_problem_display():
	if current_problem_label and current_question:
		var base_text = current_question.question + " = "
		var display_text = base_text + user_answer
		
		# Add blinking underscore only if not submitted
		if not answer_submitted and underscore_visible:
			display_text += "_"
		
		current_problem_label.text = display_text

func submit_answer():
	if user_answer == "" or user_answer == "-" or answer_submitted:
		return  # Don't submit empty answers, just minus sign, or already submitted
	
	print("Submitting answer: ", user_answer)
	
	# Mark as submitted to prevent further input
	answer_submitted = true
	
	# Check if answer is correct
	var user_answer_int = int(user_answer)
	var is_correct = (user_answer_int == current_question.result)
	
	# Set color based on correctness, play sound, and show feedback overlay
	if current_problem_label:
		if is_correct:
			current_problem_label.modulate = Color(0, 1, 0)  # Green for correct
			AudioManager.play_correct()  # Play correct sound
			show_feedback_flash(Color(0, 1, 0))  # Green feedback flash
			print("✓ Correct! Answer was ", current_question.result)
		else:
			current_problem_label.modulate = Color(1, 0, 0)  # Red for incorrect
			AudioManager.play_incorrect()  # Play incorrect sound
			show_feedback_flash(Color(1, 0, 0))  # Red feedback flash
			print("✗ Incorrect. Answer was ", current_question.result, ", you entered ", user_answer_int)
	
	# Wait to show the color feedback (if transition_delay > 0)
	if transition_delay > 0.0:
		await get_tree().create_timer(transition_delay).timeout
	
	# Trigger scroll speed boost effect after transition delay
	var space_bg = get_node("BackgroundLayer/SpaceBackground")
	if space_bg and space_bg.has_method("boost_scroll_speed"):
		space_bg.boost_scroll_speed(scroll_boost_multiplier, animation_duration * 2.0)
	
	# Move current label up and off screen (fire and forget)
	if current_problem_label:
		var old_label = current_problem_label
		var tween = create_tween()
		tween.set_ease(Tween.EASE_OUT)
		tween.set_trans(Tween.TRANS_EXPO)
		tween.tween_property(old_label, "position", off_screen_top, animation_duration)
		tween.tween_callback(old_label.queue_free)
	
	# Increment problems completed
	problems_completed += 1
	
	# Check if we've completed the required number of problems
	if problems_completed >= problems_per_level:
		# Wait for the transition delay, then go to game over
		await get_tree().create_timer(transition_delay).timeout
		go_to_game_over()
	else:
		# Create new problem - continue playing
		create_new_problem_label()
		generate_new_question()

func create_new_problem_label():
	# Create new label
	var new_label = Label.new()
	new_label.label_settings = label_settings_resource
	new_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	new_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	new_label.position = off_screen_bottom
	new_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	new_label.modulate = Color(1, 1, 1)  # Reset to white color
	
	# Add to scene
	add_child(new_label)
	
	# Set as current problem label IMMEDIATELY
	current_problem_label = new_label
	
	# Animate to center position (fire and forget)
	var tween = create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_EXPO)
	tween.tween_property(new_label, "position", primary_position, animation_duration)


func get_math_question(track = null, grade = null, operator = null, no_zeroes = false):
	if not math_facts.has("grades"):
		return null
	
	var questions = []
	var question_title = ""
	var question_grade = ""
	
	# Priority: track > grade > operator
	if track != null:
		# Find questions from specific track
		var track_key = "TRACK" + str(track)
		for grade_key in math_facts.grades:
			var grade_data = math_facts.grades[grade_key]
			if grade_data.has("tracks") and grade_data.tracks.has(track_key):
				questions = grade_data.tracks[track_key].facts
				question_title = grade_data.tracks[track_key].title
				question_grade = grade_data.name
				break
		
		# If track not found, pick random existing track
		if questions.is_empty():
			var available_tracks = []
			for grade_key in math_facts.grades:
				var grade_data = math_facts.grades[grade_key]
				if grade_data.has("tracks"):
					for available_track_key in grade_data.tracks:
						if available_track_key not in available_tracks:
							available_tracks.append(available_track_key)
			
			if not available_tracks.is_empty():
				var random_track_key = available_tracks[rng.randi() % available_tracks.size()]
				for grade_key in math_facts.grades:
					var grade_data = math_facts.grades[grade_key]
					if grade_data.has("tracks") and grade_data.tracks.has(random_track_key):
						questions = grade_data.tracks[random_track_key].facts
						question_title = grade_data.tracks[random_track_key].title
						question_grade = grade_data.name
						break
	
	elif grade != null:
		# Handle grade selection
		var grade_key = ""
		if grade >= 5:
			grade_key = "grade-5"  # "Grades 5 and Above"
		else:
			grade_key = "grade-" + str(grade)
		
		if math_facts.grades.has(grade_key):
			var grade_data = math_facts.grades[grade_key]
			question_grade = grade_data.name
			
			# If operator is also specified, try to find questions with that operator
			if operator != null:
				var operator_str = get_operator_string(operator)
				var matching_questions = []
				var matching_title = ""
				
				for grade_track_key in grade_data.tracks:
					var track_data = grade_data.tracks[grade_track_key]
					for fact in track_data.facts:
						if fact.operator == operator_str:
							matching_questions.append(fact)
							if matching_title == "":
								matching_title = track_data.title
				
				if not matching_questions.is_empty():
					questions = matching_questions
					question_title = matching_title
				else:
					# Fallback: find closest grade with that operator
					var closest_result = find_closest_grade_with_operator(grade, operator)
					if not closest_result.questions.is_empty():
						questions = closest_result.questions
						question_title = "Closest grade match"
						question_grade = closest_result.grade_name
			else:
				# Get all questions from the grade
				for grade_track_key in grade_data.tracks:
					var track_data = grade_data.tracks[grade_track_key]
					questions.append_array(track_data.facts)
					if question_title == "":
						question_title = grade_data.name
	
	elif operator != null:
		# Get all questions with specific operator
		var operator_str = get_operator_string(operator)
		for grade_key in math_facts.grades:
			var grade_data = math_facts.grades[grade_key]
			if grade_data.has("tracks"):
				for op_track_key in grade_data.tracks:
					var track_data = grade_data.tracks[op_track_key]
					for fact in track_data.facts:
						if fact.operator == operator_str:
							questions.append(fact)
		question_title = "Operator: " + operator_str
		question_grade = "Mixed"
	
	# Filter out questions with zeroes if no_zeroes is true
	if no_zeroes:
		var filtered_questions = []
		for question in questions:
			var has_zero = false
			for operand in question.operands:
				if operand == 0:
					has_zero = true
					break
			if not has_zero:
				filtered_questions.append(question)
		questions = filtered_questions
	
	# Return random question from filtered results
	if questions.is_empty():
		return null
	
	var random_question = questions[rng.randi() % questions.size()]
	
	# Generate question without answer (format integers without decimals)
	var operand1 = int(random_question.operands[0]) if random_question.operands[0] == int(random_question.operands[0]) else random_question.operands[0]
	var operand2 = int(random_question.operands[1]) if random_question.operands[1] == int(random_question.operands[1]) else random_question.operands[1]
	var question_text = str(operand1) + " " + random_question.operator + " " + str(operand2)
	
	return {
		"operands": random_question.operands,
		"operator": random_question.operator,
		"result": random_question.result,
		"expression": random_question.expression,
		"question": question_text,
		"title": question_title,
		"grade": question_grade
	}

func get_operator_string(operator_int):
	match operator_int:
		0: return "+"
		1: return "-"
		2: return "x"
		3: return "/"
		_: return "+"

func find_closest_grade_with_operator(target_grade, operator):
	var operator_str = get_operator_string(operator)
	var grade_distances = []
	
	# Check all grades for the operator
	for i in range(1, 6):  # grades 1-5
		var grade_key_to_find = ""
		if i >= 5:
			grade_key_to_find = "grade-5"
		else:
			grade_key_to_find = "grade-" + str(i)
		
		if math_facts.grades.has(grade_key_to_find):
			var grade_data_to_find = math_facts.grades[grade_key_to_find]
			var found_operator = false
			
			for closest_track_key in grade_data_to_find.tracks:
				var track_data = grade_data_to_find.tracks[closest_track_key]
				for fact in track_data.facts:
					if fact.operator == operator_str:
						found_operator = true
						break
				if found_operator:
					break
			
			if found_operator:
				var distance = abs(target_grade - i)
				grade_distances.append({"grade": i, "distance": distance})
	
	# Sort by distance and get closest
	grade_distances.sort_custom(func(a, b): return a.distance < b.distance)
	
	if grade_distances.is_empty():
		return []
	
	var closest_grade = grade_distances[0].grade
	var grade_key = ""
	if closest_grade >= 5:
		grade_key = "grade-5"
	else:
		grade_key = "grade-" + str(closest_grade)
	
	var questions = []
	var grade_data = math_facts.grades[grade_key]
	for final_track_key in grade_data.tracks:
		var track_data = grade_data.tracks[final_track_key]
		for fact in track_data.facts:
			if fact.operator == operator_str:
				questions.append(fact)
	
	return {
		"questions": questions,
		"grade_name": grade_data.name
	}

func show_feedback_flash(flash_color: Color):
	"""Show a colored flash overlay that fades in then out with smooth timing"""
	if not feedback_color_rect:
		return
	
	# Start with the color at 0 alpha (invisible)
	feedback_color_rect.modulate = Color(flash_color.r, flash_color.g, flash_color.b, 0.0)
	
	# Create tween for the two-phase animation
	var tween = create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_EXPO)
	
	# Phase 1: Fade in from 0 to feedback_max_alpha over transition_delay
	tween.tween_property(feedback_color_rect, "modulate:a", feedback_max_alpha, transition_delay)
	
	# Phase 2: Fade out from feedback_max_alpha to 0 over animation_duration * 2
	tween.tween_property(feedback_color_rect, "modulate:a", 0.0, animation_duration * 2.0)

func connect_menu_buttons():
	"""Connect all menu buttons to their respective functions"""
	# Connect level buttons (1-8)
	for i in range(1, 9):
		var button_name = "LevelButton" + str(i)
		var level_button = main_menu_node.get_node(button_name)
		if level_button:
			level_button.pressed.connect(_on_level_button_pressed.bind(i))
	
	# Connect exit button
	var exit_button = main_menu_node.get_node("ExitButton")
	if exit_button:
		exit_button.pressed.connect(_on_exit_button_pressed)

func _on_level_button_pressed(level: int):
	"""Handle level button press - only respond during MENU state"""
	if current_state != GameState.MENU:
		return
	
	# Set the track based on the level button pressed
	current_track = track_progression[level - 1]  # Convert 1-based to 0-based index
	start_play_state()

func _on_exit_button_pressed():
	"""Handle exit button press - only respond during MENU state"""
	if current_state != GameState.MENU:
		return
	
	get_tree().quit()

func start_play_state():
	"""Transition from MENU to PLAY state"""
	current_state = GameState.PLAY
	problems_completed = 0
	
	# First animate menu down off screen (downward)
	var tween = create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_EXPO)
	tween.tween_property(main_menu_node, "position", menu_below_screen, animation_duration)
	
	# After the downward animation completes, teleport to above screen
	tween.tween_callback(func(): main_menu_node.position = menu_above_screen)
	
	# Trigger scroll speed boost effect
	var space_bg = get_node("BackgroundLayer/SpaceBackground")
	if space_bg and space_bg.has_method("boost_scroll_speed"):
		space_bg.boost_scroll_speed(scroll_boost_multiplier, animation_duration * 2.0)
	
	# Create first problem label and generate question
	create_new_problem_label()
	generate_new_question()

func go_to_game_over():
	"""Transition from PLAY to GAME_OVER state"""
	current_state = GameState.GAME_OVER
	
	# Clean up any remaining problem labels
	cleanup_problem_labels()
	
	# GameOver teleports to above screen, then animates down to center
	game_over_node.position = menu_above_screen
	var tween = create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_EXPO)
	tween.tween_property(game_over_node, "position", menu_on_screen, animation_duration)

func return_to_menu():
	"""Transition from GAME_OVER to MENU state"""
	current_state = GameState.MENU
	
	# MainMenu teleports to above screen, then animates down to center
	main_menu_node.position = menu_above_screen
	var menu_tween = create_tween()
	menu_tween.set_ease(Tween.EASE_OUT)
	menu_tween.set_trans(Tween.TRANS_EXPO)
	menu_tween.tween_property(main_menu_node, "position", menu_on_screen, animation_duration)
	
	# At the same time, GameOver moves down to below screen
	var gameover_tween = create_tween()
	gameover_tween.set_ease(Tween.EASE_OUT)
	gameover_tween.set_trans(Tween.TRANS_EXPO)
	gameover_tween.tween_property(game_over_node, "position", menu_below_screen, animation_duration)

func connect_game_over_buttons():
	"""Connect all game over buttons to their respective functions"""
	# Connect continue button
	var continue_button = game_over_node.get_node("ContinueButton")
	if continue_button:
		continue_button.pressed.connect(_on_continue_button_pressed)

func _on_continue_button_pressed():
	"""Handle continue button press - only respond during GAME_OVER state"""
	if current_state != GameState.GAME_OVER:
		return
	
	return_to_menu()

func cleanup_problem_labels():
	"""Remove any remaining problem labels from the scene"""
	for child in get_children():
		if child is Label and child != current_problem_label:
			child.queue_free()
	current_problem_label = null
