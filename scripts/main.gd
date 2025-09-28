extends Control

# Game state enum
enum GameState { MENU, PLAY, DRILL_PLAY, GAME_OVER }

# Math facts data and RNG
var math_facts = {}
var rng = RandomNumberGenerator.new()

# Game configuration variables
var blink_interval = 0.5  # Time for underscore blink cycle (fade in/out)
var max_answer_chars = 4  # Maximum characters for answer input
var animation_duration = 0.5  # Duration for label animations in seconds
var transition_delay = 0.1  # Delay before generating new question
var transition_delay_incorrect = 1.5  # Delay for incorrect answers (1.5 seconds)
var incorrect_label_animation_time = 0.25  # Time for incorrect label animation
var incorrect_label_move_distance = 192.0  # Distance to move incorrect label down
var backspace_hold_time = 0.15  # Time to hold backspace before it repeats
var scroll_boost_multiplier = 80.0  # How much to boost background scroll speed on submission
var feedback_max_alpha = 0.1  # Maximum alpha for feedback color overlay
var problems_per_level = 40  # Number of problems to complete before returning to menu
var timer_grace_period = 0.5  # Grace period before timer starts in seconds
var drill_mode_duration = 60.0  # Duration for drill mode in seconds (1 minute)

# Star animation variables
var star_delay = 0.4  # Delay between each star animation in seconds
var star_expand_time = 0.2  # Time for star to expand to max scale
var star_shrink_time = 0.5  # Time for star to shrink to final scale
var star_max_scale = 32.0  # Maximum scale during star animation
var star_final_scale = 8.0  # Final scale for earned stars
var label_fade_time = 0.5  # Time for star labels to fade in

# Star requirements (accuracy, time in seconds)
var star1_requirements = {"accuracy": 25, "time": 120.0}  # 2:00
var star2_requirements = {"accuracy": 30, "time": 100.0}  # 1:40
var star3_requirements = {"accuracy": 35, "time": 80.0}   # 1:20

# Title animation variables
var title_bounce_speed = 2.0  # Speed of the sin wave animation
var title_bounce_distance = 16.0  # Distance of the bounce in pixels

# Drill mode score animation variables
var drill_score_bounce_speed = 2.0  # Speed of the sin wave animation for drill score
var drill_score_bounce_distance = 16.0  # Distance of the bounce in pixels for drill score

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
var drill_score_base_position: Vector2  # Store the original position of the drill score label
var drill_score_animation_time = 0.0  # Track time for drill score sin wave animation

# Save system variables
var save_data = {}
var save_file_path = "user://save_data.json"
var current_question_start_time = 0.0  # Track when current question timing started
var cqpm_label: Label  # Reference to CQPM label in GameOver

# Weighted question system variables
var question_weights = {}  # Dictionary mapping question keys to their weights
var unavailable_questions = []  # List of question keys that can't be selected this level
var available_questions = []  # List of all questions available for current track

# Timer and accuracy tracking
var level_start_time = 0.0  # Time when the level started
var current_level_time = 0.0  # Current elapsed time for the level
var timer_active = false  # Whether the timer is currently running
var grace_period_timer = 0.0  # Timer for the grace period
var timer_started = false  # Whether the timer has started (past grace period)
var in_transition_delay = false  # Whether we're currently in a transition delay
var correct_answers = 0  # Number of correct answers in current level
var timer_label: Label  # Reference to the Timer label
var accuracy_label: Label  # Reference to the Accuracy label
var player_time_label: Label  # Reference to the PlayerTime label in GameOver
var player_accuracy_label: Label  # Reference to the PlayerAccuracy label in GameOver
var continue_button: Button  # Reference to the ContinueButton
var progress_line: Line2D  # Reference to the ProgressLine

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

# Drill mode variables
var is_drill_mode = false  # Whether we're currently in drill mode
var drill_timer_remaining = 0.0  # Time remaining in drill mode
var drill_score = 0  # Current drill mode score
var drill_streak = 0  # Current correct answer streak in drill mode
var drill_total_answered = 0  # Total questions answered in drill mode (correct + incorrect)
var drill_timer_label: Label  # Reference to the DrillTimer label
var drill_score_label: Label  # Reference to the DrillScore label
var drill_mode_score_label: Label  # Reference to the DrillModeScore label in GameOver
var drill_accuracy_label: Label  # Reference to the DrillAccuracy label in GameOver

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
	progress_line = play_node.get_node("ProgressLine")
	drill_timer_label = play_node.get_node("DrillTimer")
	drill_score_label = play_node.get_node("DrillScore")
	
	
	# Get references to game over labels
	player_time_label = game_over_node.get_node("PlayerTime")
	player_accuracy_label = game_over_node.get_node("PlayerAccuracy")
	continue_button = game_over_node.get_node("ContinueButton")
	cqpm_label = game_over_node.get_node("CQPM")
	drill_mode_score_label = game_over_node.get_node("DrillModeScore")
	drill_accuracy_label = game_over_node.get_node("DrillAccuracy")
	
	# Get reference to version label and set it to project version
	var version_label = main_menu_node.get_node("VersionLabel")
	if version_label:
		version_label.text = ProjectSettings.get_setting("application/config/version")
	
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
	
	# Store the original position of the drill score label for animation
	if drill_mode_score_label:
		drill_score_base_position = drill_mode_score_label.position
	
	# Initialize save system
	initialize_save_system()
	
	# Connect menu buttons
	connect_menu_buttons()
	connect_game_over_buttons()

func _input(event):
	if event is InputEventKey and event.pressed:
		# Handle number input and negative sign (only during PLAY or DRILL_PLAY state and if not submitted)
		if (current_state == GameState.PLAY or current_state == GameState.DRILL_PLAY) and not answer_submitted:
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
	
	# Handle immediate backspace press detection (only during PLAY or DRILL_PLAY state)
	if Input.is_action_just_pressed("Backspace") and (current_state == GameState.PLAY or current_state == GameState.DRILL_PLAY) and not answer_submitted:
		backspace_just_pressed = true
	
	# Handle submit (only during PLAY or DRILL_PLAY state)
	if Input.is_action_just_pressed("Submit") and (current_state == GameState.PLAY or current_state == GameState.DRILL_PLAY):
		submit_answer()

func _process(delta):
	# Animate title during MENU state
	if current_state == GameState.MENU and title_sprite:
		title_animation_time += delta * title_bounce_speed
		var bounce_offset = sin(title_animation_time) * title_bounce_distance
		title_sprite.position = title_base_position + Vector2(0, bounce_offset)
	
	# Animate drill mode score during GAME_OVER state (only if drill mode)
	if current_state == GameState.GAME_OVER and is_drill_mode and drill_mode_score_label and drill_mode_score_label.visible:
		drill_score_animation_time += delta * drill_score_bounce_speed
		var drill_bounce_offset = sin(drill_score_animation_time) * drill_score_bounce_distance
		drill_mode_score_label.position = drill_score_base_position + Vector2(0, drill_bounce_offset)
	
	# Only process game logic during PLAY or DRILL_PLAY state
	if current_state == GameState.PLAY or current_state == GameState.DRILL_PLAY:
		# Handle timer logic with grace period (but not during transition delays)
		if not timer_started and not in_transition_delay:
			# During grace period, timer hasn't started yet
			if not timer_active:
				grace_period_timer += delta
				if grace_period_timer >= timer_grace_period:
					timer_active = true
					timer_started = true
					level_start_time = Time.get_time_dict_from_system()["hour"] * 3600 + Time.get_time_dict_from_system()["minute"] * 60 + Time.get_time_dict_from_system()["second"]
		
		# Update timer only if active (whether during grace period or after)
		if timer_active:
			if is_drill_mode:
				# Drill mode: countdown timer and elapsed time tracking
				drill_timer_remaining -= delta
				current_level_time += delta  # Also track elapsed time for CQPM calculation
				if drill_timer_remaining <= 0.0:
					drill_timer_remaining = 0.0
					# Timer hit 0, end drill mode immediately
					go_to_drill_mode_game_over()
					return
			else:
				# Normal mode: count up timer
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

func generate_new_question():
	user_answer = ""
	answer_submitted = false  # Reset submission state for new question
	# Store current question for answer checking later
	# Use the weighted system if we have weights initialized, otherwise fall back to old system
	if not question_weights.is_empty():
		current_question = get_weighted_random_question()
	else:
		# Fallback to old system for non-track modes
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
	
	# Calculate time taken for this question
	var question_time = 0.0
	if current_question_start_time > 0:
		question_time = (Time.get_ticks_msec() / 1000.0) - current_question_start_time
	
	# Check if answer is correct
	var user_answer_int = int(user_answer)
	var is_correct = (user_answer_int == current_question.result)
	
	# Save question data
	if current_question:
		save_question_data(current_question, user_answer_int, question_time)
	
	# Track correct answers and drill mode scoring
	if is_drill_mode:
		drill_total_answered += 1  # Track total questions answered in drill mode
	
	if is_correct:
		correct_answers += 1
		if is_drill_mode:
			drill_streak += 1
			# Calculate drill mode score: difficulty + streak
			var difficulty = calculate_question_difficulty(current_question)
			var points_earned = difficulty + drill_streak
			drill_score += points_earned
			print("Drill mode: +", points_earned, " points (", difficulty, " difficulty + ", drill_streak, " streak)")
	else:
		if is_drill_mode:
			drill_streak = 0  # Reset streak on incorrect answer
	
	# Pause timer during transition and store its previous state
	var timer_was_active = timer_active
	var should_start_timer = false
	
	# Check if we're in grace period and should start timer after transition
	if not timer_started and grace_period_timer >= timer_grace_period:
		should_start_timer = true
	
	# Set transition delay flag and pause timer
	in_transition_delay = true
	timer_active = false
	
	# Determine which delay to use based on correctness
	var delay_to_use = transition_delay  # Default delay for correct answers
	if not is_correct:
		delay_to_use = transition_delay_incorrect  # Longer delay for incorrect answers
	
	# Set color based on correctness, play sound, and show feedback overlay
	if current_problem_label:
		if is_correct:
			current_problem_label.self_modulate = Color(0, 1, 0)  # Green for correct
			AudioManager.play_correct()  # Play correct sound
			show_feedback_flash(Color(0, 1, 0))  # Green feedback flash
			print("✓ Correct! Answer was ", current_question.result)
		else:
			current_problem_label.self_modulate = Color(1, 0, 0)  # Red for incorrect
			AudioManager.play_incorrect()  # Play incorrect sound
			show_feedback_flash(Color(1, 0, 0))  # Red feedback flash
			print("✗ Incorrect. Answer was ", current_question.result, ", you entered ", user_answer_int)
			
			# Create animated label showing correct answer for incorrect responses
			create_incorrect_answer_label()
	
	# Wait for the full transition delay (timer remains paused during this time)
	if delay_to_use > 0.0:
		await get_tree().create_timer(delay_to_use).timeout
	
	# Clear transition delay flag
	in_transition_delay = false
	
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
	
	# Animate progress line after incrementing
	if progress_line and play_node:
		var play_width = play_node.size.x
		var progress_increment = play_width / problems_per_level
		var new_x_position = progress_increment * problems_completed
		
		# Animate point 1 to the new x position
		var tween = create_tween()
		tween.set_ease(Tween.EASE_OUT)
		tween.set_trans(Tween.TRANS_EXPO)
		tween.tween_method(update_progress_line_point, progress_line.get_point_position(1).x, new_x_position, animation_duration)
	
	# Check if we've completed the required number of problems (only for normal mode)
	if not is_drill_mode and problems_completed >= problems_per_level:
		# Timer is already stopped above, keep it stopped for game over
		
		# Hide play UI labels when play state ends
		if timer_label:
			timer_label.visible = false
		if accuracy_label:
			accuracy_label.visible = false
		
		# Wait for the same transition delay used above, then go to game over
		await get_tree().create_timer(delay_to_use).timeout
		go_to_game_over()
	else:
		# Resume timer after transition delay or start it if grace period completed during transition
		if timer_was_active or should_start_timer:
			timer_active = true
			# If timer should start now, mark it as started and record start time
			if should_start_timer and not timer_started:
				timer_started = true
				level_start_time = Time.get_time_dict_from_system()["hour"] * 3600 + Time.get_time_dict_from_system()["minute"] * 60 + Time.get_time_dict_from_system()["second"]
		
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
	new_label.self_modulate = Color(1, 1, 1)  # Reset to white color
	
	# Add to Play node so it renders behind Play UI elements
	play_node.add_child(new_label)
	
	# Set as current problem label IMMEDIATELY
	current_problem_label = new_label
	
	# Animate to center position (fire and forget)
	var tween = create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_EXPO)
	tween.tween_property(new_label, "position", primary_position, animation_duration)
	
	# Start timing this question when animation completes
	tween.tween_callback(start_question_timing)


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

func create_incorrect_answer_label():
	"""Create and animate a label showing the correct answer when user is incorrect"""
	if not current_problem_label or not current_question:
		return
	
	# Create new label as child of current problem label
	var incorrect_label = Label.new()
	incorrect_label.label_settings = label_settings_resource  # Uses GravityBold128
	incorrect_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	incorrect_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	incorrect_label.position = Vector2(0, 0)  # Start at (0, 0) relative to parent
	incorrect_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	incorrect_label.text = current_question.expression  # Set to the expression
	incorrect_label.self_modulate = Color(0, 0.5, 0)  # Dark green color
	
	# Add as child to current problem label
	current_problem_label.add_child(incorrect_label)
	
	# Animate the label moving down 320 pixels over 0.25 seconds
	var tween = create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_EXPO)
	tween.tween_property(incorrect_label, "position", Vector2(0, incorrect_label_move_distance), incorrect_label_animation_time)
	
	# The label will be cleaned up when the parent problem label is removed

func update_progress_line_point(x_position: float):
	"""Update the x position of point 1 in the progress line"""
	if progress_line and progress_line.get_point_count() >= 2:
		progress_line.set_point_position(1, Vector2(x_position, 0))

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
	
	# Connect reset data button
	var reset_data_button = main_menu_node.get_node("ResetDataButton")
	if reset_data_button:
		reset_data_button.pressed.connect(_on_reset_data_button_pressed)
		connect_button_sounds(reset_data_button)
	
	# Connect drill mode button
	var drill_mode_button = main_menu_node.get_node("DrillModeButton")
	if drill_mode_button:
		drill_mode_button.pressed.connect(_on_drill_mode_button_pressed)
		connect_button_sounds(drill_mode_button)

func _on_level_button_pressed(level: int):
	"""Handle level button press - only respond during MENU state"""
	if current_state != GameState.MENU:
		return
	
	# Set the track based on the level button pressed
	current_track = track_progression[level - 1]  # Convert 1-based to 0-based index
	start_play_state()

func _on_exit_button_pressed():
	# Use PlaycademySdk.runtime.exit() when available, otherwise fall back to quit
	if PlaycademySdk and PlaycademySdk.is_ready():
		PlaycademySdk.runtime.exit()
	else:
		# Fallback to normal quit for non-Playcademy environments
		get_tree().quit() 
	
	get_tree().quit()

func _on_reset_data_button_pressed():
	"""Handle reset data button press - wipe all save data and reset menu UI"""
	if current_state != GameState.MENU:
		return
	
	print("Resetting all save data...")
	
	# Reset save data to default
	save_data = get_default_save_data()
	save_save_data()
	
	# Update menu display with reset data
	update_menu_stars()
	update_level_availability()
	
	print("Save data reset complete!")

func _on_drill_mode_button_pressed():
	"""Handle drill mode button press - start drill mode"""
	if current_state != GameState.MENU:
		return
	
	start_drill_mode()

func start_drill_mode():
	"""Transition from MENU to DRILL_PLAY state"""
	current_state = GameState.DRILL_PLAY
	is_drill_mode = true
	problems_completed = 0
	correct_answers = 0
	drill_score = 0
	drill_streak = 0
	drill_total_answered = 0
	drill_timer_remaining = drill_mode_duration
	
	# Clean up any existing problem labels before starting
	cleanup_problem_labels()
	
	# Reset answer state
	user_answer = ""
	answer_submitted = false
	
	# Initialize timer variables
	level_start_time = 0.0
	current_level_time = 0.0
	timer_active = false
	timer_started = false
	in_transition_delay = false
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
	
	# Set UI visibility for drill mode
	update_drill_mode_ui_visibility()
	
	# Initialize weighted question system for all tracks
	initialize_question_weights_for_all_tracks()
	
	# Create first problem label and generate question
	create_new_problem_label()
	generate_new_question()

func start_play_state():
	"""Transition from MENU to PLAY state"""
	current_state = GameState.PLAY
	is_drill_mode = false
	problems_completed = 0
	correct_answers = 0
	
	# Clean up any existing problem labels before starting
	cleanup_problem_labels()
	
	# Reset answer state
	user_answer = ""
	answer_submitted = false
	
	# Initialize timer variables
	level_start_time = 0.0
	current_level_time = 0.0
	timer_active = false
	timer_started = false
	in_transition_delay = false
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
	
	# Show play UI labels for normal mode
	if timer_label:
		timer_label.visible = true
	if accuracy_label:
		accuracy_label.visible = true
	
	# Set UI visibility for normal mode
	update_normal_mode_ui_visibility()
	
	# Initialize progress line
	if progress_line:
		progress_line.clear_points()
		progress_line.add_point(Vector2(0, 0))  # Point 0 at (0, 0)
		progress_line.add_point(Vector2(0, 0))  # Point 1 starts at (0, 0)
	
	# Initialize weighted question system for this track
	initialize_question_weights_for_track(current_track)
	
	# Create first problem label and generate question
	create_new_problem_label()
	generate_new_question()

func go_to_game_over():
	"""Transition from PLAY to GAME_OVER state"""
	current_state = GameState.GAME_OVER
	
	# Stop the timer (should already be stopped, but ensure it)
	timer_active = false
	
	# Calculate and save level performance data
	var stars_earned = evaluate_stars().size()
	var level_number = get_level_number_from_track(current_track)
	if level_number > 0:
		update_level_data(level_number, correct_answers, current_level_time, stars_earned)
	
	# Update GameOver labels with player performance
	update_game_over_labels()
	
	# Set normal mode game over UI visibility
	update_normal_mode_game_over_ui_visibility()
	
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
	is_drill_mode = false  # Reset drill mode flag
	drill_score_animation_time = 0.0  # Reset drill score animation
	
	# Update menu display with new save data
	update_menu_stars()
	update_level_availability()
	update_drill_mode_high_score_display()
	
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
	continue_button = game_over_node.get_node("ContinueButton")
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
	if is_drill_mode:
		# Update drill mode UI
		if drill_timer_label:
			var display_time = drill_timer_remaining
			if not timer_started:
				display_time = drill_mode_duration  # Show full time during grace period
			
			var minutes = int(display_time / 60)
			var seconds = int(display_time) % 60
			var hundredths = int((display_time - int(display_time)) * 100)
			
			var time_string = "%d:%02d.%02d" % [minutes, seconds, hundredths]
			drill_timer_label.text = time_string
		
		if drill_score_label:
			drill_score_label.text = str(int(drill_score))
	else:
		# Update normal mode UI
		if not timer_label or not accuracy_label:
			return
		
		# Update timer display (mm:ss.ss format)
		var display_time = current_level_time
		if not timer_started:
			display_time = 0.0  # Show 0:00.00 only during initial grace period
		
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
	
	# Update CQPM display
	if cqpm_label:
		var cqpm = calculate_cqpm(correct_answers, current_level_time)
		cqpm_label.text = "%.2f" % cqpm

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
	var star_accuracy_label: Label
	var star_time_label: Label
	
	# Get references for the specific star
	match star_num:
		1:
			star_node = star1_node
			star_sprite = star1_sprite
			star_accuracy_label = star1_accuracy_label
			star_time_label = star1_time_label
		2:
			star_node = star2_node
			star_sprite = star2_sprite
			star_accuracy_label = star2_accuracy_label
			star_time_label = star2_time_label
		3:
			star_node = star3_node
			star_sprite = star3_sprite
			star_accuracy_label = star3_accuracy_label
			star_time_label = star3_time_label
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
	animate_star_labels(star_num, star_accuracy_label, star_time_label)

func animate_star_labels(star_num: int, star_accuracy_label: Label, time_label: Label):
	"""Animate the accuracy and time labels for a star"""
	# Check if individual requirements were met
	var accuracy_met = check_star_requirement(star_num, "accuracy")
	var time_met = check_star_requirement(star_num, "time")
	
	# Set colors based on whether requirements were met
	if accuracy_met:
		star_accuracy_label.self_modulate = Color(0, 0.5, 0, 0)  # Half green, start transparent
	else:
		star_accuracy_label.self_modulate = Color(0.5, 0, 0, 0)  # Half red, start transparent
	
	if time_met:
		time_label.self_modulate = Color(0, 0.5, 0, 0)  # Half green, start transparent
	else:
		time_label.self_modulate = Color(0.5, 0, 0, 0)  # Half red, start transparent
	
	# Create fade-in animations
	var accuracy_tween = create_tween()
	accuracy_tween.set_ease(Tween.EASE_OUT)
	accuracy_tween.set_trans(Tween.TRANS_EXPO)
	accuracy_tween.tween_property(star_accuracy_label, "self_modulate:a", 1.0, label_fade_time)
	
	var time_tween = create_tween()
	time_tween.set_ease(Tween.EASE_OUT)
	time_tween.set_trans(Tween.TRANS_EXPO)
	time_tween.tween_property(time_label, "self_modulate:a", 1.0, label_fade_time)

func cleanup_problem_labels():
	"""Remove any remaining problem labels from the Play node"""
	if play_node:
		for child in play_node.get_children():
			# Only remove dynamically created labels, not the static UI elements
			if (child is Label and 
				child != timer_label and 
				child != accuracy_label and 
				child != drill_timer_label and 
				child != drill_score_label):
				child.queue_free()
	current_problem_label = null

# Save System Functions

func start_question_timing():
	"""Start timing the current question"""
	current_question_start_time = Time.get_ticks_msec() / 1000.0  # Convert to seconds with millisecond precision

func initialize_save_system():
	"""Initialize the save system and load existing save data"""
	load_save_data()
	update_menu_stars()
	update_level_availability()
	update_drill_mode_high_score_display()

func get_default_save_data():
	"""Return the default save data structure"""
	var default_data = {
		"version": ProjectSettings.get_setting("application/config/version"),
		"levels": {},
		"questions": {}
	}
	
	# Initialize level data for all 8 levels
	for level in range(1, 9):
		default_data.levels[str(level)] = {
			"highest_stars": 0,
			"best_accuracy": 0,
			"best_time": 999999.0,  # Very high default time
			"best_cqpm": 0.0
		}
	
	return default_data

func load_save_data():
	"""Load save data from file or create default if none exists"""
	if FileAccess.file_exists(save_file_path):
		var file = FileAccess.open(save_file_path, FileAccess.READ)
		if file:
			var json_string = file.get_as_text()
			file.close()
			
			var json = JSON.new()
			var parse_result = json.parse(json_string)
			if parse_result == OK:
				save_data = json.data
				# Run migration if needed
				migrate_save_data()
			else:
				print("Error parsing save data JSON: ", json.get_error_message())
				save_data = get_default_save_data()
		else:
			print("Could not open save file")
			save_data = get_default_save_data()
	else:
		print("No save file found, creating default save data")
		save_data = get_default_save_data()
		save_save_data()

func save_save_data():
	"""Save current save data to file"""
	var file = FileAccess.open(save_file_path, FileAccess.WRITE)
	if file:
		var json_string = JSON.stringify(save_data, "\t")
		file.store_string(json_string)
		file.close()
		print("Save data saved successfully")
	else:
		print("Could not save data to file")

func migrate_save_data():
	"""Handle save data migration for version changes"""
	var current_version = ProjectSettings.get_setting("application/config/version")
	var save_version = save_data.get("version", "0.0")
	
	if save_version != current_version:
		print("Migrating save data from version ", save_version, " to ", current_version)
		
		# Special case: Wipe all data from version 1.0 due to data structure changes
		if save_version == "1.0":
			print("Version 1.0 detected - wiping all save data due to incompatible data structure changes")
			save_data = get_default_save_data()
			save_save_data()
			return
		
		# Ensure all required fields exist
		if not save_data.has("levels"):
			save_data.levels = {}
		if not save_data.has("questions"):
			save_data.questions = {}
		
		# Ensure all 8 levels have data
		for level in range(1, 9):
			var level_key = str(level)
			if not save_data.levels.has(level_key):
				save_data.levels[level_key] = {
					"highest_stars": 0,
					"best_accuracy": 0,
					"best_time": 999999.0,
					"best_cqpm": 0.0
				}
			else:
				# Ensure all fields exist for existing levels
				var level_data = save_data.levels[level_key]
				if not level_data.has("best_cqpm"):
					level_data.best_cqpm = 0.0
		
		# Update version
		save_data.version = current_version
		save_save_data()

func get_question_key(question_data):
	"""Generate a unique key for a question based on its operands and operator"""
	return str(question_data.operands[0]) + "_" + question_data.operator + "_" + str(question_data.operands[1])

func save_question_data(question_data, player_answer, time_taken):
	"""Save data for a completed question"""
	var question_key = get_question_key(question_data)
	
	if not save_data.questions.has(question_key):
		save_data.questions[question_key] = []
	
	var question_record = {
		"operands": question_data.operands,
		"operator": question_data.operator,
		"result": question_data.result,
		"player_answer": player_answer,
		"time_taken": time_taken,
		"timestamp": Time.get_unix_time_from_system()
	}
	
	# Add to the beginning of the array
	save_data.questions[question_key].push_front(question_record)
	
	# Keep only the last 5 answers
	if save_data.questions[question_key].size() > 5:
		save_data.questions[question_key] = save_data.questions[question_key].slice(0, 5)
	
	save_save_data()

func update_level_data(level_number, accuracy, time_taken, stars_earned):
	"""Update the saved data for a level"""
	var level_key = str(level_number)
	if not save_data.levels.has(level_key):
		save_data.levels[level_key] = {
			"highest_stars": 0,
			"best_accuracy": 0,
			"best_time": 999999.0,
			"best_cqpm": 0.0
		}
	
	var level_data = save_data.levels[level_key]
	var updated = false
	
	# Update highest stars
	if stars_earned > level_data.highest_stars:
		level_data.highest_stars = stars_earned
		updated = true
	
	# Update best accuracy
	if accuracy > level_data.best_accuracy:
		level_data.best_accuracy = accuracy
		updated = true
	
	# Update best time
	if time_taken < level_data.best_time:
		level_data.best_time = time_taken
		updated = true
	
	# Calculate and update CQPM (Correct Questions Per Minute)
	var cqpm = 0.0
	if time_taken > 0:
		cqpm = (accuracy / time_taken) * 60.0
	
	if cqpm > level_data.best_cqpm:
		level_data.best_cqpm = cqpm
		updated = true
	
	if updated:
		save_save_data()

func calculate_cqpm(correct_answers_in_level, time_in_seconds):
	"""Calculate Correct Questions Per Minute"""
	if time_in_seconds <= 0:
		return 0.0
	return (float(correct_answers_in_level) / time_in_seconds) * 60.0

func calculate_question_weight(question_data):
	"""Calculate the weight for a single question based on historical data"""
	var question_key = get_question_key(question_data)
	var base_weight = 1.0
	var weight_details = []
	
	# Get historical data for this question
	var question_history = []
	if save_data.questions.has(question_key):
		question_history = save_data.questions[question_key]
	
	var total_answers = question_history.size()
	var incorrect_count = 0
	
	# Count incorrect answers
	for answer_record in question_history:
		if answer_record.player_answer != answer_record.result:
			incorrect_count += 1
	
	# Add weight based on amount of data
	var data_bonus = 0.0
	match total_answers:
		0: data_bonus = 32.0
		1: data_bonus = 8.0
		2: data_bonus = 4.0
		3: data_bonus = 2.0
		4: data_bonus = 1.0
		_: data_bonus = 0.0  # 5 or more answers
	
	if data_bonus > 0:
		weight_details.append("Data bonus (%d answers): +%.1f" % [total_answers, data_bonus])
	
	# Add weight based on incorrect answer count
	var incorrect_bonus = 0.0
	match incorrect_count:
		5: incorrect_bonus = 32.0
		4: incorrect_bonus = 24.0
		3: incorrect_bonus = 16.0
		2: incorrect_bonus = 8.0
		1: incorrect_bonus = 4.0
		_: incorrect_bonus = 0.0
	
	if incorrect_bonus > 0:
		weight_details.append("Incorrect count bonus (%d incorrect): +%.1f" % [incorrect_count, incorrect_bonus])
	
	# Add weight based on individual answer times
	var time_penalty = 0.0
	for answer_record in question_history:
		var is_correct = (answer_record.player_answer == answer_record.result)
		var base_multiplier = 0.5 if is_correct else 2.0
		var time_taken = answer_record.get("time_taken", 0.0)
		var penalty = base_multiplier * time_taken
		time_penalty += penalty
	
	if time_penalty > 0:
		weight_details.append("Time penalties: +%.3f (from individual answers)" % time_penalty)
	
	var final_weight = base_weight + data_bonus + incorrect_bonus + time_penalty
	
	return {
		"weight": final_weight,
		"details": weight_details
	}

func initialize_question_weights_for_track(track):
	"""Initialize question weights for all questions available in the given track"""
	# Clear previous data
	question_weights.clear()
	unavailable_questions.clear()
	available_questions.clear()
	
	# Get all questions for this track (similar logic to get_math_question)
	if not math_facts.has("grades"):
		print("No math facts data available")
		return
	
	var track_key = "TRACK" + str(track)
	var questions = []
	
	# Find questions from specific track
	for grade_key in math_facts.grades:
		var grade_data = math_facts.grades[grade_key]
		if grade_data.has("tracks") and grade_data.tracks.has(track_key):
			questions = grade_data.tracks[track_key].facts
			break
	
	# If track not found, pick random existing track (fallback)
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
					break
	
	print("=== Question Weight Calculations for Track ", track, " ===")
	
	# Calculate weights for all questions
	for question in questions:
		var question_key = get_question_key(question)
		available_questions.append(question_key)
		
		var weight_result = calculate_question_weight(question)
		question_weights[question_key] = weight_result.weight
		
		# Format question display
		var operand1 = int(question.operands[0]) if question.operands[0] == int(question.operands[0]) else question.operands[0]
		var operand2 = int(question.operands[1]) if question.operands[1] == int(question.operands[1]) else question.operands[1]
		var question_text = str(operand1) + " " + question.operator + " " + str(operand2) + " = " + str(question.result)
		
		print("Question: ", question_text)
		print("- Base weight: 1.0")
		for detail in weight_result.details:
			print("- ", detail)
		print("- Final weight: %.3f" % weight_result.weight)
		print("")
	
	print("Total questions available: ", available_questions.size())
	print("==========================================")
	print("")

func get_weighted_random_question():
	"""Select a random question using weighted selection, avoiding unavailable questions"""
	# Filter out unavailable questions
	var selectable_questions = []
	var selectable_weights = []
	
	for question_key in available_questions:
		if question_key not in unavailable_questions:
			selectable_questions.append(question_key)
			selectable_weights.append(question_weights[question_key])
	
	# If no questions available, reset unavailable list and try again
	if selectable_questions.is_empty():
		print("No more available questions, resetting unavailable list")
		unavailable_questions.clear()
		for question_key in available_questions:
			selectable_questions.append(question_key)
			selectable_weights.append(question_weights[question_key])
	
	if selectable_questions.is_empty():
		print("Error: No questions available at all")
		return null
	
	# Calculate total weight
	var total_weight = 0.0
	for weight in selectable_weights:
		total_weight += weight
	
	# Generate random number between 0 and total_weight
	var random_value = rng.randf() * total_weight
	
	# Find the selected question
	var cumulative_weight = 0.0
	for i in range(selectable_questions.size()):
		cumulative_weight += selectable_weights[i]
		if random_value <= cumulative_weight:
			var selected_key = selectable_questions[i]
			var selected_weight = selectable_weights[i]
			
			# Add to unavailable list
			unavailable_questions.append(selected_key)
			
			# Find the actual question data from math_facts
			var selected_question = find_question_by_key(selected_key)
			if selected_question:
				# Console output for question selection
				var operand1 = int(selected_question.operands[0]) if selected_question.operands[0] == int(selected_question.operands[0]) else selected_question.operands[0]
				var operand2 = int(selected_question.operands[1]) if selected_question.operands[1] == int(selected_question.operands[1]) else selected_question.operands[1]
				var question_text = str(operand1) + " " + selected_question.operator + " " + str(operand2) + " = " + str(selected_question.result)
				print("Selected question: ", question_text, " (weight: %.3f)" % selected_weight)
				
				# Format the question for display (without answer)
				var display_text = str(operand1) + " " + selected_question.operator + " " + str(operand2)
				
				return {
					"operands": selected_question.operands,
					"operator": selected_question.operator,
					"result": selected_question.result,
					"expression": selected_question.expression,
					"question": display_text,
					"title": "",  # Will be filled by caller if needed
					"grade": ""   # Will be filled by caller if needed
				}
			else:
				print("Error: Could not find question data for key: ", selected_key)
				return null
	
	# Fallback (should never reach here)
	print("Error: Weighted selection failed")
	return null

func find_question_by_key(question_key):
	"""Find a question in math_facts by its key"""
	var parts = question_key.split("_")
	if parts.size() != 3:
		return null
	
	var operand1 = float(parts[0])
	var operator = parts[1]
	var operand2 = float(parts[2])
	
	# Search through all grades and tracks
	for grade_key in math_facts.grades:
		var grade_data = math_facts.grades[grade_key]
		if grade_data.has("tracks"):
			for track_key in grade_data.tracks:
				var track_data = grade_data.tracks[track_key]
				for question in track_data.facts:
					if question.operands[0] == operand1 and question.operator == operator and question.operands[1] == operand2:
						return question
	
	return null

func get_level_number_from_track(track):
	"""Get the level number (1-8) from a track number using track_progression mapping"""
	for i in range(track_progression.size()):
		if track_progression[i] == track:
			return i + 1  # Convert 0-based index to 1-based level number
	return 0  # Track not found

func update_menu_stars():
	"""Update the star display on menu level buttons based on save data"""
	for level in range(1, 9):
		var level_key = str(level)
		var button_name = "LevelButton" + str(level)
		var level_button = main_menu_node.get_node(button_name)
		
		if level_button and save_data.levels.has(level_key):
			var stars_earned = save_data.levels[level_key].highest_stars
			var contents = level_button.get_node("Contents")
			
			# Update each star sprite
			for star_num in range(1, 4):
				var star_sprite = contents.get_node("Star" + str(star_num))
				if star_sprite:
					star_sprite.frame = 1 if star_num <= stars_earned else 0

func calculate_question_difficulty(question_data):
	"""Calculate the difficulty of a question based on its track"""
	# Find which track this question belongs to
	for grade_key in math_facts.grades:
		var grade_data = math_facts.grades[grade_key]
		if grade_data.has("tracks"):
			for track_key in grade_data.tracks:
				var track_data = grade_data.tracks[track_key]
				for fact in track_data.facts:
					if (fact.operands[0] == question_data.operands[0] and 
						fact.operator == question_data.operator and 
						fact.operands[1] == question_data.operands[1]):
						# Extract track number from track_key (e.g., "TRACK12" -> 12)
						var track_number = int(track_key.substr(5))  # Remove "TRACK" prefix
						# Find index in track_progression
						for i in range(track_progression.size()):
							if track_progression[i] == track_number:
								return (i + 1) * 2  # (index + 1) * 2
						# If not found in track_progression, return default difficulty
						return 2
	# Default difficulty if track not found
	return 2

func update_drill_mode_ui_visibility():
	"""Set UI visibility for drill mode"""
	if timer_label:
		timer_label.visible = false
	if accuracy_label:
		accuracy_label.visible = false
	if progress_line:
		progress_line.visible = false
	if drill_timer_label:
		drill_timer_label.visible = true
	if drill_score_label:
		drill_score_label.visible = true

func update_normal_mode_ui_visibility():
	"""Set UI visibility for normal mode"""
	if timer_label:
		timer_label.visible = true
	if accuracy_label:
		accuracy_label.visible = true
	if progress_line:
		progress_line.visible = true
	if drill_timer_label:
		drill_timer_label.visible = false
	if drill_score_label:
		drill_score_label.visible = false

func initialize_question_weights_for_all_tracks():
	"""Initialize question weights for all questions from all tracks in track_progression"""
	# Clear previous data
	question_weights.clear()
	unavailable_questions.clear()
	available_questions.clear()
	
	print("=== Question Weight Calculations for All Tracks ===")
	
	# Get questions from all tracks in track_progression
	for track in track_progression:
		var track_key = "TRACK" + str(track)
		var questions = []
		
		# Find questions from this track
		for grade_key in math_facts.grades:
			var grade_data = math_facts.grades[grade_key]
			if grade_data.has("tracks") and grade_data.tracks.has(track_key):
				questions = grade_data.tracks[track_key].facts
				break
		
		print("Processing Track ", track, " (", questions.size(), " questions)")
		
		# Calculate weights for all questions in this track
		for question in questions:
			var question_key = get_question_key(question)
			available_questions.append(question_key)
			
			var weight_result = calculate_question_weight(question)
			question_weights[question_key] = weight_result.weight
			
			# Format question display for debug
			var operand1 = int(question.operands[0]) if question.operands[0] == int(question.operands[0]) else question.operands[0]
			var operand2 = int(question.operands[1]) if question.operands[1] == int(question.operands[1]) else question.operands[1]
			var question_text = str(operand1) + " " + question.operator + " " + str(operand2) + " = " + str(question.result)
			
			print("  Question: ", question_text, " (weight: %.3f)" % weight_result.weight)
	
	print("Total questions available across all tracks: ", available_questions.size())
	print("==========================================")

func go_to_drill_mode_game_over():
	"""Transition from DRILL_PLAY to GAME_OVER state"""
	current_state = GameState.GAME_OVER
	
	# Stop the timer
	timer_active = false
	
	# Update drill mode high score if needed
	update_drill_mode_high_score()
	
	# Update GameOver labels with drill mode performance
	update_drill_mode_game_over_labels()
	
	# Set drill mode game over UI visibility
	update_drill_mode_game_over_ui_visibility()
	
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
	
	# Show continue button immediately for drill mode (no star animation)
	continue_button.visible = true

func update_drill_mode_high_score():
	"""Update drill mode high score in save data"""
	if not save_data.has("drill_mode"):
		save_data.drill_mode = {"high_score": 0}
	
	if drill_score > save_data.drill_mode.high_score:
		save_data.drill_mode.high_score = drill_score
		save_save_data()
		print("New drill mode high score: ", drill_score)

func update_drill_mode_game_over_labels():
	"""Update GameOver labels for drill mode"""
	# Update LevelComplete text
	var level_complete_label = game_over_node.get_node("LevelComplete")
	if level_complete_label:
		level_complete_label.text = "YOUR SCORE"
	
	# Update drill mode score display
	if drill_mode_score_label:
		drill_mode_score_label.text = str(int(drill_score))
	
	# Update drill mode accuracy display
	if drill_accuracy_label:
		var accuracy_string = "%d/%d" % [correct_answers, drill_total_answered]
		drill_accuracy_label.text = accuracy_string
	
	# Update CQPM display for drill mode
	if cqpm_label:
		# Calculate drill mode CQPM: correct answers divided by total drill time
		# Subtract time spent on the last unanswered question (if any)
		var drill_time_used = drill_mode_duration
		if current_question_start_time > 0:
			# Subtract time spent on current unanswered question
			var time_on_current_question = (Time.get_ticks_msec() / 1000.0) - current_question_start_time
			drill_time_used -= time_on_current_question
		
		var cqpm = calculate_cqpm(correct_answers, drill_time_used)
		cqpm_label.text = "%.2f" % cqpm

func update_drill_mode_game_over_ui_visibility():
	"""Set UI visibility for drill mode game over screen"""
	# Make only specific nodes visible for drill mode
	var level_complete_label = game_over_node.get_node("LevelComplete")
	if level_complete_label:
		level_complete_label.visible = true
	
	if continue_button:
		continue_button.visible = true
	
	var cqpm_title = game_over_node.get_node("CQPMTitle")
	if cqpm_title:
		cqpm_title.visible = true
	
	if cqpm_label:
		cqpm_label.visible = true
	
	var cqpm_tooltip = game_over_node.get_node("CQPMTooltip")
	if cqpm_tooltip:
		cqpm_tooltip.visible = true
	
	if drill_mode_score_label:
		drill_mode_score_label.visible = true
	
	var drill_accuracy_title = game_over_node.get_node("DrillAccuracyTitle")
	if drill_accuracy_title:
		drill_accuracy_title.visible = true
	
	if drill_accuracy_label:
		drill_accuracy_label.visible = true
	
	# Hide all other nodes
	var nodes_to_hide = ["CorrectTitle", "TimeTitle", "You", "PlayerAccuracy", "PlayerTime", "Star1", "Star2", "Star3"]
	for node_name in nodes_to_hide:
		var node = game_over_node.get_node(node_name)
		if node:
			node.visible = false

func update_normal_mode_game_over_ui_visibility():
	"""Set UI visibility for normal mode game over screen"""
	# Make all nodes visible except DrillModeScore
	var level_complete_label = game_over_node.get_node("LevelComplete")
	if level_complete_label:
		level_complete_label.text = "LEVEL COMPLETE"  # Reset to normal text
		level_complete_label.visible = true
	
	var nodes_to_show = ["CorrectTitle", "TimeTitle", "You", "PlayerAccuracy", "PlayerTime", "Star1", "Star2", "Star3", "CQPMTitle", "CQPMTooltip"]
	for node_name in nodes_to_show:
		var node = game_over_node.get_node(node_name)
		if node:
			node.visible = true
	
	if cqpm_label:
		cqpm_label.visible = true
	
	# Hide drill mode elements
	if drill_mode_score_label:
		drill_mode_score_label.visible = false
	
	var drill_accuracy_title = game_over_node.get_node("DrillAccuracyTitle")
	if drill_accuracy_title:
		drill_accuracy_title.visible = false
	
	if drill_accuracy_label:
		drill_accuracy_label.visible = false

func update_drill_mode_high_score_display():
	"""Update the drill mode high score display in the main menu"""
	var high_score_label = main_menu_node.get_node("DrillModeButton/HighScore")
	if high_score_label:
		var high_score = 0
		if save_data.has("drill_mode") and save_data.drill_mode.has("high_score"):
			high_score = save_data.drill_mode.high_score
		high_score_label.text = str(int(high_score))  # Ensure integer display

func update_level_availability():
	"""Update level button availability based on progression"""
	for level in range(1, 9):
		var button_name = "LevelButton" + str(level)
		var level_button = main_menu_node.get_node(button_name)
		
		if level_button:
			var should_be_available = true
			
			# Level 1 is always available
			if level > 1:
				# Check if previous level has at least 1 star
				var prev_level_key = str(level - 1)
				if save_data.levels.has(prev_level_key):
					var prev_stars = save_data.levels[prev_level_key].highest_stars
					should_be_available = prev_stars > 0
				else:
					should_be_available = false
			
			# Set button state
			level_button.disabled = not should_be_available
			
			# Update visual state
			var contents = level_button.get_node("Contents")
			if contents:
				if should_be_available:
					contents.modulate = Color(1, 1, 1, 1)  # Fully opaque
				else:
					contents.modulate = Color(1, 1, 1, 0.5)  # Half transparent
