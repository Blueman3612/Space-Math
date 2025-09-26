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
var problems_per_level = 40  # Number of problems to complete before returning to menu
var timer_grace_period = 0.5  # Grace period before timer starts in seconds

# Star animation variables
var star_delay = 0.4  # Delay between each star animation in seconds
var star_expand_time = 0.2  # Time for star to expand to max scale
var star_shrink_time = 0.5  # Time for star to shrink to final scale
var star_max_scale = 32.0  # Maximum scale during star animation
var star_final_scale = 8.0  # Final scale for earned stars
var label_fade_time = 0.5  # Time for star labels to fade in

# Star requirements (accuracy, time in seconds)
var star1_requirements = {"accuracy": 25, "time": 150.0}  # 2:30
var star2_requirements = {"accuracy": 30, "time": 120.0}  # 2:00
var star3_requirements = {"accuracy": 35, "time": 90.0}   # 1:30

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
var play_node: Control  # Reference to the Play node
var title_sprite: Sprite2D  # Reference to the Title sprite
var title_base_position: Vector2  # Store the original position of the title
var title_animation_time = 0.0  # Track time for sin wave animation

# Timer and accuracy tracking
var level_start_time = 0.0  # Time when the level started
var current_level_time = 0.0  # Current elapsed time for the level
var timer_active = false  # Whether the timer is currently running
var grace_period_timer = 0.0  # Timer for the grace period
var correct_answers = 0  # Number of correct answers in current level
var timer_label: Label  # Reference to the Timer label
var accuracy_label: Label  # Reference to the Accuracy label
var player_time_label: Label  # Reference to the PlayerTime label in GameOver
var player_accuracy_label: Label  # Reference to the PlayerAccuracy label in GameOver
var continue_button: Button  # Reference to the ContinueButton

# Star node references
var star1_node: Control
var star2_node: Control
var star3_node: Control
var star1_sprite: Sprite2D
var star2_sprite: Sprite2D
var star3_sprite: Sprite2D
var star1_accuracy_label: Label
var star1_time_label: Label
var star2_accuracy_label: Label
var star2_time_label: Label
var star3_accuracy_label: Label
var star3_time_label: Label

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
	
	# Get reference to feedback color overlay, main menu, game over, and play
	feedback_color_rect = get_node("FeedbackColor")
	main_menu_node = get_node("MainMenu")
	game_over_node = get_node("GameOver")
	play_node = get_node("Play")
	title_sprite = main_menu_node.get_node("Title")
	
	# Get references to timer and accuracy labels
	timer_label = play_node.get_node("Timer")
	accuracy_label = play_node.get_node("Accuracy")
	
	# Get references to game over labels
	player_time_label = game_over_node.get_node("PlayerTime")
	player_accuracy_label = game_over_node.get_node("PlayerAccuracy")
	continue_button = game_over_node.get_node("ContinueButton")
	
	# Get references to star nodes and their components
	star1_node = game_over_node.get_node("Star1")
	star2_node = game_over_node.get_node("Star2")
	star3_node = game_over_node.get_node("Star3")
	
	star1_sprite = star1_node.get_node("Sprite")
	star2_sprite = star2_node.get_node("Sprite")
	star3_sprite = star3_node.get_node("Sprite")
	
	star1_accuracy_label = star1_node.get_node("Accuracy")
	star1_time_label = star1_node.get_node("Time")
	star2_accuracy_label = star2_node.get_node("Accuracy")
	star2_time_label = star2_node.get_node("Time")
	star3_accuracy_label = star3_node.get_node("Accuracy")
	star3_time_label = star3_node.get_node("Time")
	
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
		# Handle timer logic with grace period
		if not timer_active:
			grace_period_timer += delta
			if grace_period_timer >= timer_grace_period:
				timer_active = true
				level_start_time = Time.get_time_dict_from_system()["hour"] * 3600 + Time.get_time_dict_from_system()["minute"] * 60 + Time.get_time_dict_from_system()["second"]
		else:
			# Update timer only if active using delta time for precision
			current_level_time += delta
		
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
		
		# Update UI labels
		update_play_ui()

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
	
	# Track correct answers
	if is_correct:
		correct_answers += 1
	
	# Pause timer during transition
	var timer_was_active = timer_active
	timer_active = false
	
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
		# Stop timer immediately when last question is answered
		timer_active = false
		
		# Hide play UI labels when play state ends
		if timer_label:
			timer_label.visible = false
		if accuracy_label:
			accuracy_label.visible = false
		
		# Wait for the transition delay, then go to game over
		await get_tree().create_timer(transition_delay).timeout
		go_to_game_over()
	else:
		# Resume timer after transition delay (if it was active)
		if timer_was_active:
			timer_active = true
		
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

func connect_button_sounds(button: Button):
	"""Connect hover and click sound effects to a button"""
	if button:
		# Connect hover sound (mouse_entered signal)
		button.mouse_entered.connect(_on_button_hover)
		# Connect click sound - this will be called before the button's pressed signal
		button.button_down.connect(_on_button_click)

func _on_button_hover():
	"""Play hover sound when mouse enters any button"""
	AudioManager.play_blip()

func _on_button_click():
	"""Play click sound when any button is pressed down"""
	AudioManager.play_select()

func connect_menu_buttons():
	"""Connect all menu buttons to their respective functions"""
	# Connect level buttons (1-8)
	for i in range(1, 9):
		var button_name = "LevelButton" + str(i)
		var level_button = main_menu_node.get_node(button_name)
		if level_button:
			level_button.pressed.connect(_on_level_button_pressed.bind(i))
			connect_button_sounds(level_button)
	
	# Connect exit button
	var exit_button = main_menu_node.get_node("ExitButton")
	if exit_button:
		exit_button.pressed.connect(_on_exit_button_pressed)
		connect_button_sounds(exit_button)

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
	correct_answers = 0
	
	# Initialize timer variables
	level_start_time = 0.0
	current_level_time = 0.0
	timer_active = false
	grace_period_timer = 0.0
	
	# First animate menu down off screen (downward)
	var tween = create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_EXPO)
	tween.tween_property(main_menu_node, "position", menu_below_screen, animation_duration)
	
	# After the downward animation completes, teleport to above screen
	tween.tween_callback(func(): main_menu_node.position = menu_above_screen)
	
	# Play node flies in from above
	play_node.position = menu_above_screen
	var play_tween = create_tween()
	play_tween.set_ease(Tween.EASE_OUT)
	play_tween.set_trans(Tween.TRANS_EXPO)
	play_tween.tween_property(play_node, "position", menu_on_screen, animation_duration)
	
	# Trigger scroll speed boost effect
	var space_bg = get_node("BackgroundLayer/SpaceBackground")
	if space_bg and space_bg.has_method("boost_scroll_speed"):
		space_bg.boost_scroll_speed(scroll_boost_multiplier, animation_duration * 2.0)
	
	# Show play UI labels
	if timer_label:
		timer_label.visible = true
	if accuracy_label:
		accuracy_label.visible = true
	
	# Create first problem label and generate question
	create_new_problem_label()
	generate_new_question()

func go_to_game_over():
	"""Transition from PLAY to GAME_OVER state"""
	current_state = GameState.GAME_OVER
	
	# Stop the timer (should already be stopped, but ensure it)
	timer_active = false
	
	# Update GameOver labels with player performance
	update_game_over_labels()
	
	# Initialize star states (make all stars invisible, continue button invisible)
	initialize_star_states()
	
	# Clean up any remaining problem labels
	cleanup_problem_labels()
	
	# Play node flies down off screen
	var play_tween = create_tween()
	play_tween.set_ease(Tween.EASE_OUT)
	play_tween.set_trans(Tween.TRANS_EXPO)
	play_tween.tween_property(play_node, "position", menu_below_screen, animation_duration)
	
	# GameOver teleports to above screen, then animates down to center
	game_over_node.position = menu_above_screen
	var tween = create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_EXPO)
	tween.tween_property(game_over_node, "position", menu_on_screen, animation_duration)
	
	# Start star animation sequence after GameOver animation completes
	tween.tween_callback(start_star_animation_sequence)

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
		connect_button_sounds(continue_button)

func _on_continue_button_pressed():
	"""Handle continue button press - only respond during GAME_OVER state"""
	if current_state != GameState.GAME_OVER:
		return
	
	return_to_menu()

func update_play_ui():
	"""Update the Timer and Accuracy labels during gameplay"""
	if not timer_label or not accuracy_label:
		return
	
	# Update timer display (mm:ss.ss format)
	var display_time = current_level_time
	if not timer_active:
		display_time = 0.0  # Show 0:00.00 during grace period
	
	var minutes = int(display_time / 60)
	var seconds = int(display_time) % 60
	var hundredths = int((display_time - int(display_time)) * 100)
	
	var time_string = "%d:%02d.%02d" % [minutes, seconds, hundredths]
	timer_label.text = time_string
	
	# Update accuracy display (correct/total format)
	var accuracy_string = "%d/%d" % [correct_answers, problems_per_level]
	accuracy_label.text = accuracy_string

func update_game_over_labels():
	"""Update the GameOver labels with player's final performance"""
	if not player_time_label or not player_accuracy_label:
		return
	
	# Update player time display (mm:ss.ss format - same as in-game timer)
	var minutes = int(current_level_time / 60)
	var seconds = int(current_level_time) % 60
	var hundredths = int((current_level_time - int(current_level_time)) * 100)
	var time_string = "%d:%02d.%02d" % [minutes, seconds, hundredths]
	player_time_label.text = time_string
	
	# Update player accuracy display (correct/total format)
	var accuracy_string = "%d/%d" % [correct_answers, problems_per_level]
	player_accuracy_label.text = accuracy_string

func evaluate_stars():
	"""Evaluate which stars the player has earned"""
	var stars_earned = []
	
	# Check Star 1
	if correct_answers >= star1_requirements.accuracy and current_level_time <= star1_requirements.time:
		stars_earned.append(1)
	
	# Check Star 2
	if correct_answers >= star2_requirements.accuracy and current_level_time <= star2_requirements.time:
		stars_earned.append(2)
	
	# Check Star 3
	if correct_answers >= star3_requirements.accuracy and current_level_time <= star3_requirements.time:
		stars_earned.append(3)
	
	return stars_earned

func check_star_requirement(star_num: int, requirement_type: String) -> bool:
	"""Check if a specific requirement for a star has been met"""
	var requirements
	match star_num:
		1: requirements = star1_requirements
		2: requirements = star2_requirements
		3: requirements = star3_requirements
		_: return false
	
	match requirement_type:
		"accuracy": return correct_answers >= requirements.accuracy
		"time": return current_level_time <= requirements.time
		_: return false

func initialize_star_states():
	"""Initialize all stars to invisible state and hide continue button"""
	# Make all star nodes invisible
	star1_node.visible = false
	star2_node.visible = false
	star3_node.visible = false
	
	# Hide continue button
	continue_button.visible = false
	
	# Reset all star sprite scales and frames
	star1_sprite.scale = Vector2.ZERO
	star2_sprite.scale = Vector2.ZERO
	star3_sprite.scale = Vector2.ZERO
	
	# Set all star labels to transparent
	star1_accuracy_label.self_modulate.a = 0.0
	star1_time_label.self_modulate.a = 0.0
	star2_accuracy_label.self_modulate.a = 0.0
	star2_time_label.self_modulate.a = 0.0
	star3_accuracy_label.self_modulate.a = 0.0
	star3_time_label.self_modulate.a = 0.0

func start_star_animation_sequence():
	"""Start the sequential star animation after half animation_duration delay"""
	await get_tree().create_timer(animation_duration / 2.0).timeout
	
	# Evaluate which stars were earned
	var stars_earned = evaluate_stars()
	
	# Animate stars in sequence
	animate_star(1, 1 in stars_earned)
	await get_tree().create_timer(star_delay).timeout
	
	animate_star(2, 2 in stars_earned)
	await get_tree().create_timer(star_delay).timeout
	
	animate_star(3, 3 in stars_earned)
	# Show continue button when Star 3 starts animating
	continue_button.visible = true

func animate_star(star_num: int, earned: bool):
	"""Animate a single star based on whether it was earned"""
	var star_node: Control
	var star_sprite: Sprite2D
	var accuracy_label: Label
	var time_label: Label
	
	# Get references for the specific star
	match star_num:
		1:
			star_node = star1_node
			star_sprite = star1_sprite
			accuracy_label = star1_accuracy_label
			time_label = star1_time_label
		2:
			star_node = star2_node
			star_sprite = star2_sprite
			accuracy_label = star2_accuracy_label
			time_label = star2_time_label
		3:
			star_node = star3_node
			star_sprite = star3_sprite
			accuracy_label = star3_accuracy_label
			time_label = star3_time_label
		_:
			return
	
	# Make star visible
	star_node.visible = true
	
	# Set sprite frame based on earned status
	star_sprite.frame = 1 if earned else 0
	
	# Create sprite animation tween
	var sprite_tween = create_tween()
	sprite_tween.set_ease(Tween.EASE_OUT)
	sprite_tween.set_trans(Tween.TRANS_EXPO)
	
	if earned:
		# Earned star animation: 0 -> 16 -> 8
		sprite_tween.tween_property(star_sprite, "scale", Vector2(star_max_scale, star_max_scale), star_expand_time)
		sprite_tween.tween_property(star_sprite, "scale", Vector2(star_final_scale, star_final_scale), star_shrink_time)
		# Play get sound
		AudioManager.play_get()
	else:
		# Unearned star animation: 0 -> 8
		sprite_tween.tween_property(star_sprite, "scale", Vector2(star_final_scale, star_final_scale), star_shrink_time)
		# Play close sound
		AudioManager.play_close()
	
	# Animate labels (accuracy and time)
	animate_star_labels(star_num, accuracy_label, time_label)

func animate_star_labels(star_num: int, accuracy_label: Label, time_label: Label):
	"""Animate the accuracy and time labels for a star"""
	# Check if individual requirements were met
	var accuracy_met = check_star_requirement(star_num, "accuracy")
	var time_met = check_star_requirement(star_num, "time")
	
	# Set colors based on whether requirements were met
	if accuracy_met:
		accuracy_label.self_modulate = Color(0, 0.5, 0, 0)  # Half green, start transparent
	else:
		accuracy_label.self_modulate = Color(0.5, 0, 0, 0)  # Half red, start transparent
	
	if time_met:
		time_label.self_modulate = Color(0, 0.5, 0, 0)  # Half green, start transparent
	else:
		time_label.self_modulate = Color(0.5, 0, 0, 0)  # Half red, start transparent
	
	# Create fade-in animations
	var accuracy_tween = create_tween()
	accuracy_tween.set_ease(Tween.EASE_OUT)
	accuracy_tween.set_trans(Tween.TRANS_EXPO)
	accuracy_tween.tween_property(accuracy_label, "self_modulate:a", 1.0, label_fade_time)
	
	var time_tween = create_tween()
	time_tween.set_ease(Tween.EASE_OUT)
	time_tween.set_trans(Tween.TRANS_EXPO)
	time_tween.tween_property(time_label, "self_modulate:a", 1.0, label_fade_time)

func cleanup_problem_labels():
	"""Remove any remaining problem labels from the scene"""
	for child in get_children():
		if child is Label and child != current_problem_label:
			child.queue_free()
	current_problem_label = null
