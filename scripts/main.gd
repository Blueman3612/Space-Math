extends Control

# Main coordinator - orchestrates all managers for the game

func _ready():
	# Show loading screen while data loads from KV storage
	var loading = get_node("Loading")
	var main_menu = get_node("MainMenu")
	if loading:
		loading.visible = true
	if main_menu:
		main_menu.visible = false
	
	# Initialize all managers in dependency order
	QuestionManager.initialize()
	ScoreManager.initialize()
	
	# Initialize managers that need references to this node
	DisplayManager.initialize(self)
	InputManager.initialize(self)
	UIManager.initialize(self)
	StateManager.initialize(self)
	LevelManager.initialize(self)
	PlaycademyManager.initialize()
	
	# Connect to SaveManager signal before initializing (since it loads async from KV storage)
	SaveManager.save_data_loaded.connect(_on_save_data_loaded)
	SaveManager.initialize()

func _on_save_data_loaded(success: bool):
	"""Called when save data has been loaded from KV storage"""
	if not success:
		print("[Main] Warning: Save data failed to load from KV storage, using defaults")
	
	# Apply loaded volumes from local settings (not KV)
	var sfx_volume = SaveManager.local_settings.get("sfx_volume", GameConfig.default_sfx_volume)
	var music_volume = SaveManager.local_settings.get("music_volume", GameConfig.default_music_volume)
	SaveManager.set_sfx_volume(sfx_volume)
	SaveManager.set_music_volume(music_volume)
	print("[Main] Applied volumes from local settings - SFX: ", sfx_volume, " Music: ", music_volume)
	
	# Update volume sliders to match loaded values
	UIManager.update_volume_sliders_from_local_settings()
	
	# Now that save data is loaded, start music with correct volumes
	AudioManager.start_music()
	
	# Initialize with assessment check (sets starting grade based on completion)
	LevelManager.initialize_with_assessment_check()
	
	# Create dynamic level buttons
	LevelManager.create_level_buttons()
	
	# Update menu display after buttons are created (requires save data)
	LevelManager.update_menu_stars()
	LevelManager.update_level_availability()
	UIManager.update_drill_mode_high_score_display()
	
	# Connect menu buttons
	connect_menu_buttons()
	connect_game_over_buttons()
	
	# Hide loading screen and show main menu now that everything is ready
	var loading = get_node("Loading")
	var main_menu = get_node("MainMenu")
	if main_menu:
		main_menu.visible = true
	if loading:
		# Fade out the loading screen
		var tween = create_tween()
		tween.tween_property(loading, "modulate:a", 0.0, GameConfig.loading_fade_duration).set_ease(GameConfig.loading_fade_ease)
		tween.tween_callback(func(): loading.visible = false)
	
	print("[Main] Game initialization complete!")

func _input(event):
	# Hide cursor on keyboard input, show on mouse movement
	if event is InputEventKey and event.pressed:
		Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)
	elif event is InputEventMouseMotion:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	
	# Delegate input handling to InputManager
	StateManager.user_answer = InputManager.handle_input_event(event, StateManager.user_answer, StateManager.answer_submitted, StateManager.current_state)
	
	# Handle immediate backspace press detection
	InputManager.handle_backspace_just_pressed(StateManager.current_state)
	
	# Handle submit (during PLAY, DRILL_PLAY, or ASSESSMENT_PLAY state)
	if Input.is_action_just_pressed("Submit") and (StateManager.current_state == GameConfig.GameState.PLAY or StateManager.current_state == GameConfig.GameState.DRILL_PLAY or StateManager.current_state == GameConfig.GameState.ASSESSMENT_PLAY):
		submit_answer()

func _process(delta):
	# Process UI animations
	UIManager.process_animations(delta, StateManager.current_state, StateManager.is_drill_mode)
	
	# Only process game logic during PLAY, DRILL_PLAY, or ASSESSMENT_PLAY state
	if StateManager.current_state == GameConfig.GameState.PLAY or StateManager.current_state == GameConfig.GameState.DRILL_PLAY or StateManager.current_state == GameConfig.GameState.ASSESSMENT_PLAY:
		# Handle timer logic with grace period (but not during transition delays or assessment mode)
		if not ScoreManager.timer_started and not StateManager.in_transition_delay and not StateManager.is_assessment_mode:
			ScoreManager.update_grace_period(delta)
		
		# Update timer based on mode (skip for assessment mode - no timer)
		if ScoreManager.timer_active and not StateManager.is_assessment_mode:
			if StateManager.is_drill_mode:
				var time_ran_out = ScoreManager.update_drill_timer(delta)
				if time_ran_out:
					StateManager.go_to_drill_mode_game_over()
					return
			else:
				# Normal mode: countdown timer - check if time ran out
				var time_ran_out = ScoreManager.update_normal_timer(delta)
				if time_ran_out and StateManager.is_grade_level:
					# Hide play UI elements immediately
					UIManager.hide_play_ui_for_level_complete()
					# Timer ran out - go to game over (player may get stars based on performance)
					StateManager.go_to_grade_level_game_over()
					return
		
		# Update blink timer
		DisplayManager.update_blink_timer(delta)
		
		# Handle backspace
		StateManager.user_answer = InputManager.process_backspace(delta, StateManager.user_answer, StateManager.answer_submitted)
		
		# Handle number line input (Left/Right)
		InputManager.process_number_line_input(delta, StateManager.answer_submitted)
		
		# Update problem display
		DisplayManager.update_problem_display(StateManager.user_answer, StateManager.answer_submitted, InputManager.is_fraction_input, InputManager.is_mixed_fraction_input, InputManager.editing_numerator)
		
		# Update UI labels
		UIManager.update_play_ui(delta, StateManager.is_drill_mode, StateManager.current_level_number)
		
		# Update control guide visibility and positions
		InputManager.update_control_guide_visibility(StateManager.user_answer, StateManager.answer_submitted)

func submit_answer():
	# Declare timer state variables at function level to avoid scope warnings
	var timer_was_active: bool
	var should_start_timer: bool
	
	# Handle continuing after incorrect answer
	if StateManager.waiting_for_continue_after_incorrect:
		StateManager.waiting_for_continue_after_incorrect = false
		AudioManager.play_select()  # Play select sound when continuing
		
		# Check if this was a multiple choice question
		if DisplayManager.multiple_choice_answered:
			# Retrieve stored timer state
			timer_was_active = StateManager.get_meta("timer_was_active", false)
			should_start_timer = StateManager.get_meta("should_start_timer", false)
			# For multiple choice, we need to pass is_correct=false since we only wait after incorrect
			DisplayManager.continue_after_multiple_choice_incorrect(false, timer_was_active, should_start_timer)
		else:
			continue_after_incorrect()
		return
	
	# Handle number line questions differently - they always have a selection
	var question_type = QuestionManager.current_question.get("type", "") if QuestionManager.current_question else ""
	if QuestionManager.is_number_line_display_type(question_type):
		if StateManager.answer_submitted:
			return  # Already submitted
		submit_number_line_answer()
		return
	
	# Handle multi-input questions (e.g., equivalence_mult_factoring)
	if QuestionManager.is_multi_input_display_type(question_type):
		if StateManager.answer_submitted:
			return  # Already submitted
		# Check if we should submit or just move to next slot
		if not InputManager.handle_multi_input_submit():
			return  # Moved to next slot, don't submit yet
		# Both slots filled - proceed with submission
		submit_multi_input_answer()
		return
	
	if StateManager.user_answer == "" or StateManager.user_answer == "-" or StateManager.answer_submitted:
		return  # Don't submit empty answers, just minus sign, or already submitted
	
	# Don't submit mixed fractions with empty numerator or denominator
	if InputManager.is_mixed_fraction_input:
		var parts = StateManager.user_answer.split(" ")
		if parts.size() != 2:
			return
		var fraction_parts = parts[1].split("/")
		if fraction_parts.size() != 2:
			return
		
		# Transition from numerator to denominator if still editing numerator
		if InputManager.editing_numerator:
			InputManager.editing_numerator = false
			AudioManager.play_tick()
			return
		
		# Don't submit if numerator or denominator is empty
		if fraction_parts[0] == "" or fraction_parts[1] == "":
			return
	
	# Don't submit regular fractions with empty denominator
	if InputManager.is_fraction_input and not InputManager.is_mixed_fraction_input:
		var parts = StateManager.user_answer.split("/")
		if parts.size() != 2 or parts[1] == "":
			return
	
	print("Submitting answer: ", StateManager.user_answer)
	
	# Mark as submitted to prevent further input
	StateManager.answer_submitted = true
	
	# Calculate time taken for this question
	var question_time = 0.0
	if ScoreManager.current_question_start_time > 0:
		question_time = (Time.get_ticks_msec() / 1000.0) - ScoreManager.current_question_start_time
	
	# Check if answer is correct
	var is_correct = false
	var player_answer_value = null  # Can be int or string depending on question type
	
	# question_type already declared earlier in function for number line check
	if QuestionManager.is_fraction_display_type(question_type) or QuestionManager.is_fraction_conversion_display_type(question_type):
		# For fraction questions (including conversion), compare both string equality and numeric equivalence
		player_answer_value = StateManager.user_answer
		var correct_answer = QuestionManager.current_question.result
		# Accept exact match OR equivalent fraction value
		is_correct = (StateManager.user_answer == correct_answer) or fractions_are_equivalent(StateManager.user_answer, correct_answer)
	elif "." in StateManager.user_answer or (QuestionManager.current_question.result is float):
		# For decimal questions, normalize and compare as floats
		player_answer_value = normalize_decimal_answer(StateManager.user_answer)
		var correct_value = QuestionManager.current_question.result
		if correct_value is String:
			correct_value = float(correct_value)
		is_correct = is_close_float(player_answer_value, correct_value)
	else:
		# For integer questions, compare as integers
		player_answer_value = int(StateManager.user_answer)
		is_correct = (player_answer_value == QuestionManager.current_question.result)
	
	# DEV MODE: Accept "0" as always correct when running in editor
	if not is_correct and OS.has_feature("editor"):
		if StateManager.user_answer == "0" or StateManager.user_answer == "0/0":
			is_correct = true
			print("[DEV] Accepted '0' as correct answer")
	
	# Save question data
	if QuestionManager.current_question:
		SaveManager.save_question_data(QuestionManager.current_question, player_answer_value, question_time)
	
	# Track correct answers and drill mode scoring
	if StateManager.is_drill_mode:
		ScoreManager.drill_total_answered += 1
	
	var points_earned = 0
	if is_correct:
		points_earned = ScoreManager.process_correct_answer(StateManager.is_drill_mode, QuestionManager.current_question)
		if StateManager.is_drill_mode and points_earned > 0:
			# Trigger score animations
			UIManager.create_flying_score_label(points_earned)
			UIManager.animate_drill_score_scale()
	else:
		ScoreManager.process_incorrect_answer(StateManager.is_drill_mode)
	
	# Pause timer during transition and store its previous state
	timer_was_active = ScoreManager.timer_active
	should_start_timer = false
	
	# Check if we're in grace period and should start timer after transition
	if not ScoreManager.timer_started and ScoreManager.grace_period_timer >= GameConfig.timer_grace_period:
		should_start_timer = true
	
	# Set transition delay flag and pause timer
	StateManager.in_transition_delay = true
	ScoreManager.timer_active = false
	
	# Determine which delay to use based on correctness
	var delay_to_use = GameConfig.transition_delay  # Default delay for correct answers
	if not is_correct and not StateManager.is_assessment_mode:
		delay_to_use = GameConfig.transition_delay_incorrect  # Longer delay for incorrect answers (not in assessment)
	
	# Assessment mode: no feedback, just play Select sound
	if StateManager.is_assessment_mode:
		AudioManager.play_select()
		print("[Assessment] Answer submitted: ", "correct" if is_correct else "incorrect")
	else:
		# Set color based on correctness, play sound, and show feedback overlay
		var feedback_color = Color(0, 1, 0) if is_correct else Color(1, 0, 0)
		
		# Color all problem nodes
		DisplayManager.color_problem_nodes(feedback_color)
		
		# Play sounds and show feedback
		if is_correct:
			AudioManager.play_correct()
			UIManager.show_feedback_flash(Color(0, 1, 0))
			print("✓ Correct! Answer was ", QuestionManager.current_question.result)
		else:
			AudioManager.play_incorrect()
			UIManager.show_feedback_flash(Color(1, 0, 0))
			print("✗ Incorrect. Answer was ", QuestionManager.current_question.result, ", you entered ", player_answer_value)
			
			# Create animated label showing correct answer for incorrect responses
			DisplayManager.create_incorrect_answer_label()
			
			# Pause TimeBack activity timer while showing correct answer (instructional moment)
			PlaycademyManager.pause_timeback_activity()
	
	# Wait for the full transition delay (timer remains paused during this time)
	if delay_to_use > 0.0:
		await get_tree().create_timer(delay_to_use).timeout
	
	# Clear transition delay flag
	StateManager.in_transition_delay = false
	
	# Store question time for assessment processing (before branching)
	StateManager.set_meta("last_question_time", question_time)
	StateManager.set_meta("last_answer_correct", is_correct)
	
	# If incorrect and require_submit_after_incorrect is true, wait for player to press Submit to continue
	if not is_correct and GameConfig.require_submit_after_incorrect and not StateManager.is_assessment_mode:
		StateManager.waiting_for_continue_after_incorrect = true
		# Store timer state for later restoration
		StateManager.set_meta("timer_was_active", timer_was_active)
		StateManager.set_meta("should_start_timer", should_start_timer)
		return  # Wait for player to press Submit to continue
	
	# Continue immediately if correct or if require_submit_after_incorrect is false
	continue_after_incorrect_internal(is_correct, timer_was_active, should_start_timer)

func submit_multi_input_answer():
	"""Handle answer submission for multi-input questions (e.g., equivalence_mult_factoring)"""
	# Mark as submitted to prevent further input
	StateManager.answer_submitted = true
	
	# Get the player's answers
	var answers = InputManager.get_multi_input_answers()
	var answer1 = answers[0]
	var answer2 = answers[1]
	
	# Get question data for validation
	var operands = QuestionManager.current_question.get("operands", [0, 0])
	var given_factor = QuestionManager.current_question.get("given_factor", 0)
	var expected_product = operands[0] * operands[1]  # a × b
	
	# Validate: c × ans1 × ans2 should equal a × b
	var player_product = given_factor * answer1 * answer2
	var is_correct = (player_product == expected_product)
	
	# DEV MODE: Accept both answers as 0 as always correct when running in editor
	if not is_correct and OS.has_feature("editor"):
		if answer1 == 0 and answer2 == 0:
			is_correct = true
			print("[DEV] Accepted '0, 0' as correct answer")
	
	var player_answer_str = str(answer1) + ", " + str(answer2)
	print("Submitting multi-input answer: ", player_answer_str)
	
	# Calculate time taken for this question
	var question_time = 0.0
	if ScoreManager.current_question_start_time > 0:
		question_time = (Time.get_ticks_msec() / 1000.0) - ScoreManager.current_question_start_time
	
	# Save question data
	if QuestionManager.current_question:
		SaveManager.save_question_data(QuestionManager.current_question, player_answer_str, question_time)
	
	# Track correct answers and drill mode scoring
	if StateManager.is_drill_mode:
		ScoreManager.drill_total_answered += 1
	
	var points_earned = 0
	if is_correct:
		points_earned = ScoreManager.process_correct_answer(StateManager.is_drill_mode, QuestionManager.current_question)
		if StateManager.is_drill_mode and points_earned > 0:
			# Trigger score animations
			UIManager.create_flying_score_label(points_earned)
			UIManager.animate_drill_score_scale()
	else:
		ScoreManager.process_incorrect_answer(StateManager.is_drill_mode)
	
	# Pause timer during transition and store its previous state
	var timer_was_active = ScoreManager.timer_active
	var should_start_timer = false
	
	# Check if we're in grace period and should start timer after transition
	if not ScoreManager.timer_started and ScoreManager.grace_period_timer >= GameConfig.timer_grace_period:
		should_start_timer = true
	
	# Set transition delay flag and pause timer
	StateManager.in_transition_delay = true
	ScoreManager.timer_active = false
	
	# Determine which delay to use based on correctness
	var delay_to_use = GameConfig.transition_delay  # Default delay for correct answers
	if not is_correct and not StateManager.is_assessment_mode:
		delay_to_use = GameConfig.transition_delay_incorrect  # Longer delay for incorrect answers (not in assessment)
	
	# Assessment mode: no feedback, just play Select sound
	if StateManager.is_assessment_mode:
		AudioManager.play_select()
		print("[Assessment] Multi-input answer submitted: ", "correct" if is_correct else "incorrect")
	else:
		# Set color based on correctness
		var feedback_color = Color(0, 1, 0) if is_correct else Color(1, 0, 0)
		
		# Color all problem nodes
		DisplayManager.color_problem_nodes(feedback_color)
		
		# Play sounds and show feedback
		if is_correct:
			AudioManager.play_correct()
			UIManager.show_feedback_flash(Color(0, 1, 0))
			print("✓ Correct! Player answered: ", player_answer_str)
		else:
			AudioManager.play_incorrect()
			UIManager.show_feedback_flash(Color(1, 0, 0))
			var expected = QuestionManager.current_question.get("expected_answers", [0, 0])
			print("✗ Incorrect. Expected: ", expected[0], " and ", expected[1], ", you entered: ", player_answer_str)
			
			# Create animated label showing correct answer
			DisplayManager.create_incorrect_multi_input_label()
			
			# Pause TimeBack activity timer while showing correct answer (instructional moment)
			PlaycademyManager.pause_timeback_activity()
	
	# Wait for the full transition delay (timer remains paused during this time)
	if delay_to_use > 0.0:
		await get_tree().create_timer(delay_to_use).timeout
	
	# Clear transition delay flag
	StateManager.in_transition_delay = false
	
	# Store question time for assessment processing (before branching)
	StateManager.set_meta("last_question_time", question_time)
	StateManager.set_meta("last_answer_correct", is_correct)
	
	# If incorrect and require_submit_after_incorrect is true, wait for player to press Submit to continue
	if not is_correct and GameConfig.require_submit_after_incorrect and not StateManager.is_assessment_mode:
		StateManager.waiting_for_continue_after_incorrect = true
		# Store timer state for later restoration
		StateManager.set_meta("timer_was_active", timer_was_active)
		StateManager.set_meta("should_start_timer", should_start_timer)
		return  # Wait for player to press Submit to continue
	
	# Continue immediately if correct or if require_submit_after_incorrect is false
	continue_after_incorrect_internal(is_correct, timer_was_active, should_start_timer)

func submit_number_line_answer():
	"""Handle answer submission for number line questions"""
	if not DisplayManager.current_number_line:
		return
	
	# Mark as submitted to prevent further input
	StateManager.answer_submitted = true
	
	# Get the player's answer from the number line
	var player_answer_value = DisplayManager.current_number_line.get_selected_fraction_string()
	var is_correct = DisplayManager.current_number_line.is_correct()
	
	# DEV MODE: Accept middle/default position as always correct
	if not is_correct and OS.has_feature("editor"):
		var nl = DisplayManager.current_number_line
		var middle_pip = nl.total_pips / 2
		if nl.control_mode == "pip_to_pip" and nl.selected_pip == middle_pip:
			is_correct = true
			print("[DEV] Accepted middle pip as correct answer")
		elif nl.control_mode == "continuous" and abs(nl.pointer_x) <= 10:
			# Middle position in continuous mode is x = 0
			is_correct = true
			print("[DEV] Accepted middle position as correct answer")
	
	print("Submitting number line answer: ", player_answer_value)
	
	# Calculate time taken for this question
	var question_time = 0.0
	if ScoreManager.current_question_start_time > 0:
		question_time = (Time.get_ticks_msec() / 1000.0) - ScoreManager.current_question_start_time
	
	# Save question data
	if QuestionManager.current_question:
		SaveManager.save_question_data(QuestionManager.current_question, player_answer_value, question_time)
	
	# Track correct answers and drill mode scoring
	if StateManager.is_drill_mode:
		ScoreManager.drill_total_answered += 1
	
	var points_earned = 0
	if is_correct:
		points_earned = ScoreManager.process_correct_answer(StateManager.is_drill_mode, QuestionManager.current_question)
		if StateManager.is_drill_mode and points_earned > 0:
			# Trigger score animations
			UIManager.create_flying_score_label(points_earned)
			UIManager.animate_drill_score_scale()
	else:
		ScoreManager.process_incorrect_answer(StateManager.is_drill_mode)
	
	# Pause timer during transition and store its previous state
	var timer_was_active = ScoreManager.timer_active
	var should_start_timer = false
	
	# Check if we're in grace period and should start timer after transition
	if not ScoreManager.timer_started and ScoreManager.grace_period_timer >= GameConfig.timer_grace_period:
		should_start_timer = true
	
	# Set transition delay flag and pause timer
	StateManager.in_transition_delay = true
	ScoreManager.timer_active = false
	
	# Determine which delay to use based on correctness
	var delay_to_use = GameConfig.transition_delay  # Default delay for correct answers
	if not is_correct and not StateManager.is_assessment_mode:
		delay_to_use = GameConfig.transition_delay_incorrect  # Longer delay for incorrect answers (not in assessment)
	
	# Assessment mode: no feedback, just play Select sound
	if StateManager.is_assessment_mode:
		AudioManager.play_select()
		print("[Assessment] Number line answer submitted: ", "correct" if is_correct else "incorrect")
	else:
		# Show feedback on number line and fraction label
		if is_correct:
			DisplayManager.show_number_line_correct_feedback()
			AudioManager.play_correct()
			UIManager.show_feedback_flash(Color(0, 1, 0))
			print("✓ Correct! Answer was ", QuestionManager.current_question.result)
		else:
			DisplayManager.show_number_line_incorrect_feedback()
			AudioManager.play_incorrect()
			UIManager.show_feedback_flash(Color(1, 0, 0))
			print("✗ Incorrect. Correct answer was ", QuestionManager.current_question.result, ", you selected ", player_answer_value)
			
			# Pause TimeBack activity timer while showing correct answer (instructional moment)
			PlaycademyManager.pause_timeback_activity()
	
	# Wait for the full transition delay (timer remains paused during this time)
	if delay_to_use > 0.0:
		await get_tree().create_timer(delay_to_use).timeout
	
	# Clear transition delay flag
	StateManager.in_transition_delay = false
	
	# Store question time for assessment processing (before branching)
	StateManager.set_meta("last_question_time", question_time)
	StateManager.set_meta("last_answer_correct", is_correct)
	
	# If incorrect and require_submit_after_incorrect is true, wait for player to press Submit to continue
	if not is_correct and GameConfig.require_submit_after_incorrect and not StateManager.is_assessment_mode:
		StateManager.waiting_for_continue_after_incorrect = true
		# Store timer state for later restoration
		StateManager.set_meta("timer_was_active", timer_was_active)
		StateManager.set_meta("should_start_timer", should_start_timer)
		return  # Wait for player to press Submit to continue
	
	# Continue immediately if correct or if require_submit_after_incorrect is false
	continue_after_incorrect_internal(is_correct, timer_was_active, should_start_timer)

func continue_after_incorrect():
	"""Called when player presses Submit to continue after incorrect answer"""
	# Retrieve stored timer state
	var timer_was_active = StateManager.get_meta("timer_was_active", false)
	var should_start_timer = StateManager.get_meta("should_start_timer", false)
	
	# Note: is_correct is always false when this is called (only called after incorrect answers)
	continue_after_incorrect_internal(false, timer_was_active, should_start_timer)

func continue_after_incorrect_internal(is_correct: bool, timer_was_active: bool, should_start_timer: bool):
	"""Internal function to handle the continuation logic after incorrect answer delay"""
	# Resume TimeBack activity timer if it was paused (only after incorrect answers)
	if not is_correct:
		PlaycademyManager.resume_timeback_activity()
	
	# Trigger scroll speed boost effect after transition delay
	var space_bg = get_node("BackgroundLayer/SpaceBackground")
	if space_bg and space_bg.has_method("boost_scroll_speed"):
		space_bg.boost_scroll_speed(GameConfig.scroll_boost_multiplier, GameConfig.animation_duration * 2.0)
	
	# Check level completion BEFORE animating to know if we should include prompt in animation
	var level_complete = false
	var assessment_complete = false
	
	if StateManager.is_assessment_mode:
		# Pre-check if this answer will complete the assessment
		var last_question_time = StateManager.get_meta("last_question_time", 0.0)
		var last_answer_correct = StateManager.get_meta("last_answer_correct", false)
		var adjusted_time = max(0.0, last_question_time - GameConfig.transition_delay)
		var result = ScoreManager.peek_assessment_answer(last_answer_correct, adjusted_time)
		if result.should_advance:
			assessment_complete = not ScoreManager.has_more_standards_after_current()
	elif StateManager.is_grade_level and StateManager.current_level_config:
		var mastery_count = StateManager.current_level_config.mastery_count
		level_complete = ScoreManager.check_mastery_complete(mastery_count)
	
	# Include prompt in animation if this is the last question
	if level_complete or assessment_complete:
		DisplayManager.include_prompt_in_animation()
	
	# Animate current problem off screen
	animate_problem_off_screen(is_correct)
	
	# Increment problems completed
	StateManager.problems_completed += 1
	
	# Animate progress line after incrementing (based on mastery_count for grade levels)
	if not StateManager.is_drill_mode:
		animate_progress_line()
	
	# Handle assessment mode completion
	if StateManager.is_assessment_mode:
		# Assessment mode: process answer and check if we should move to next standard or finish
		# Get stored question time (with transition_delay already subtracted in process_assessment_answer)
		var last_question_time = StateManager.get_meta("last_question_time", 0.0)
		var last_answer_correct = StateManager.get_meta("last_answer_correct", false)
		# Subtract transition delay from time (time only counts after animation)
		var adjusted_time = max(0.0, last_question_time - GameConfig.transition_delay)
		var result = ScoreManager.process_assessment_answer(last_answer_correct, adjusted_time)
		
		if result.should_advance:
			# Check if assessment is complete or moving to next standard
			var has_more = ScoreManager.advance_to_next_standard()
			if not has_more:
				# Assessment complete!
				UIManager.hide_play_ui_for_level_complete()
				await get_tree().create_timer(GameConfig.animation_duration).timeout
				StateManager.complete_assessment()
				return
			
			# Moving to next standard - clear used questions
			QuestionManager.used_questions_this_level.clear()
		
		# Continue playing - generate next question (either same or new standard)
		StateManager.user_answer = ""
		StateManager.answer_submitted = false
		InputManager.reset_for_new_question()
		StateManager._generate_next_assessment_question()
		DisplayManager.create_new_problem_label()
		return
	elif StateManager.is_grade_level and StateManager.current_level_config:
		var mastery_count = StateManager.current_level_config.mastery_count
		# Check if player has achieved mastery (correct answers >= mastery_count with >= 85% accuracy)
		level_complete = ScoreManager.check_mastery_complete(mastery_count)
	
	if level_complete and not StateManager.is_assessment_mode:
		# Hide all play UI elements when level completes
		UIManager.hide_play_ui_for_level_complete()
		
		# Wait for the problem to finish animating off screen before transitioning
		await get_tree().create_timer(GameConfig.animation_duration).timeout
		
		# Go to game over - player achieved mastery (automatic 3 stars)
		StateManager.go_to_grade_level_game_over()
	else:
		# Resume timer after transition delay or start it if grace period completed during transition
		if timer_was_active or should_start_timer:
			ScoreManager.timer_active = true
			# If timer should start now, mark it as started and record start time
			if should_start_timer and not ScoreManager.timer_started:
				ScoreManager.timer_started = true
				ScoreManager.level_start_time = Time.get_time_dict_from_system()["hour"] * 3600 + Time.get_time_dict_from_system()["minute"] * 60 + Time.get_time_dict_from_system()["second"]
		
		# Create new problem - continue playing
		StateManager.user_answer = ""
		StateManager.answer_submitted = false
		InputManager.reset_for_new_question()
		QuestionManager.generate_new_question()
		DisplayManager.create_new_problem_label()

func animate_problem_off_screen(is_correct: bool):
	"""Animate current problem nodes off screen"""
	if not DisplayManager.current_problem_nodes.is_empty():
		# Store references to the nodes we're animating out
		var nodes_to_animate = DisplayManager.current_problem_nodes.duplicate()
		
		# Determine if we need extra offset for fraction problems
		var extra_offset = 0.0
		if QuestionManager.current_question and QuestionManager.is_fraction_display_type(QuestionManager.current_question.get("type", "")) and not is_correct:
			extra_offset = GameConfig.incorrect_label_move_distance_fractions
		
		# Also store correct answer nodes if they exist (for incorrect fraction problems)
		var correct_nodes_to_animate = DisplayManager.correct_answer_nodes.duplicate()
		
		# Clear current_problem_nodes and correct_answer_nodes immediately so new problem can populate it
		DisplayManager.current_problem_nodes.clear()
		DisplayManager.correct_answer_nodes.clear()
		DisplayManager.current_problem_label = null
		# Note: current_prompt_label is NOT cleared here - it persists across questions
		DisplayManager.answer_fraction_node = null
		DisplayManager.current_number_line = null
		DisplayManager.number_line_fraction_label = null
		
		# Animate all problem nodes off-screen
		var tween = create_tween()
		tween.set_ease(Tween.EASE_OUT)
		tween.set_trans(Tween.TRANS_EXPO)
		tween.set_parallel(true)  # Animate all simultaneously
		
		# Calculate final off-screen position
		var final_offscreen_y = GameConfig.off_screen_top.y
		
		# For incorrect fraction problems, need extra clearance and maintain vertical separation
		if extra_offset > 0:
			# Make it go farther off screen to ensure both displays are hidden
			final_offscreen_y = GameConfig.off_screen_top.y * 1.5 - extra_offset
			
			# Animate incorrect problem nodes
			for node in nodes_to_animate:
				if node and node.get_parent() == DisplayManager.play_node:
					var target_pos = Vector2(node.position.x, final_offscreen_y - extra_offset)
					tween.tween_property(node, "position", target_pos, GameConfig.animation_duration)
			
			# Animate correct answer nodes
			for node in correct_nodes_to_animate:
				if node:
					var target_pos = Vector2(node.position.x, final_offscreen_y + extra_offset)
					tween.tween_property(node, "position", target_pos, GameConfig.animation_duration)
		else:
			# For correct answers or non-fraction problems, just animate to regular off-screen position
			for node in nodes_to_animate:
				if node and node.get_parent() == DisplayManager.play_node:
					var target_pos = Vector2(node.position.x, final_offscreen_y)
					tween.tween_property(node, "position", target_pos, GameConfig.animation_duration)
		
		# Exit parallel mode before adding callback so it runs AFTER animations complete
		tween.set_parallel(false)
		
		# Clean up all nodes after animation completes
		tween.tween_callback(func():
			for node in nodes_to_animate:
				if node:
					node.queue_free()
			for node in correct_nodes_to_animate:
				if node:
					node.queue_free()
		)
	elif DisplayManager.current_problem_label:
		# Fallback for regular label problems
		var old_label = DisplayManager.current_problem_label
		var tween = create_tween()
		tween.set_ease(Tween.EASE_OUT)
		tween.set_trans(Tween.TRANS_EXPO)
		# Preserve X position, only change Y to move off-screen
		var target_pos = Vector2(old_label.position.x, GameConfig.off_screen_top.y)
		tween.tween_property(old_label, "position", target_pos, GameConfig.animation_duration)
		tween.tween_callback(old_label.queue_free)

func animate_progress_line():
	"""Animate the progress line for normal mode levels based on correct answers towards mastery_count"""
	if not UIManager.progress_line or not DisplayManager.play_node:
		return
	
	# Get mastery_count for grade levels
	var max_value: int
	if StateManager.is_grade_level and StateManager.current_level_config:
		max_value = StateManager.current_level_config.mastery_count
	else:
		# Fallback for legacy levels
		max_value = 20
	
	var play_width = DisplayManager.play_node.size.x
	# Progress is based on correct_answers towards mastery_count
	var progress = min(ScoreManager.correct_answers, max_value)
	var progress_increment = play_width / float(max_value)
	var new_x_position = progress_increment * progress
	
	# Animate point 1 to the new x position
	var tween = create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_EXPO)
	tween.tween_method(UIManager.update_progress_line_point, UIManager.progress_line.get_point_position(1).x, new_x_position, GameConfig.animation_duration)

func connect_menu_buttons():
	"""Connect all menu buttons to their respective functions"""
	# Connect exit button
	var exit_button = StateManager.main_menu_node.get_node("ExitButton")
	if exit_button:
		exit_button.pressed.connect(StateManager._on_exit_button_pressed)
		UIManager.connect_button_sounds(exit_button)
	
	# Connect reset data button
	var reset_data_button = StateManager.main_menu_node.get_node("ResetDataButton")
	if reset_data_button:
		reset_data_button.pressed.connect(StateManager._on_reset_data_button_pressed)
		UIManager.connect_button_sounds(reset_data_button)
		# Hide in non-editor builds (only show when running in Godot editor)
		reset_data_button.visible = OS.has_feature("editor")
	
	# Connect unlock all button
	var unlock_all_button = StateManager.main_menu_node.get_node("UnlockAllButton")
	if unlock_all_button:
		unlock_all_button.pressed.connect(StateManager._on_unlock_all_button_pressed)
		UIManager.connect_button_sounds(unlock_all_button)
		# Hide in non-editor builds (only show when running in Godot editor)
		unlock_all_button.visible = OS.has_feature("editor")
	
	# Connect drill mode button
	var drill_mode_button = StateManager.main_menu_node.get_node("DrillModeButton")
	if drill_mode_button:
		drill_mode_button.pressed.connect(StateManager._on_drill_mode_button_pressed)
		drill_mode_button.mouse_entered.connect(StateManager._on_drill_mode_button_hover_enter)
		drill_mode_button.mouse_exited.connect(StateManager._on_drill_mode_button_hover_exit)
		UIManager.connect_button_sounds(drill_mode_button)
		
		# Initially hide unlock requirements
		var unlock_requirements = drill_mode_button.get_node("UnlockRequirements")
		if unlock_requirements:
			unlock_requirements.visible = false
	
	# Connect grade navigation buttons
	var left_button = StateManager.main_menu_node.get_node("LeftButton")
	if left_button:
		left_button.pressed.connect(LevelManager.switch_to_previous_grade)
		UIManager.connect_button_sounds(left_button)
	
	var right_button = StateManager.main_menu_node.get_node("RightButton")
	if right_button:
		right_button.pressed.connect(LevelManager.switch_to_next_grade)
		UIManager.connect_button_sounds(right_button)

func connect_game_over_buttons():
	"""Connect all game over buttons to their respective functions"""
	# Connect continue button
	if UIManager.continue_button:
		UIManager.continue_button.pressed.connect(StateManager._on_continue_button_pressed)
		UIManager.connect_button_sounds(UIManager.continue_button)

# ============================================
# Decimal Answer Helpers
# ============================================

func normalize_decimal_answer(answer: String) -> float:
	"""Normalize a decimal answer string to a float.
	Handles: leading zeros (.5 → 0.5), trailing decimals (5. → 5), etc."""
	if answer == "" or answer == "." or answer == "-" or answer == "-.":
		return 0.0
	
	var normalized = answer
	
	# Handle leading decimal (.5 → 0.5)
	if normalized.begins_with("."):
		normalized = "0" + normalized
	elif normalized.begins_with("-."):
		normalized = "-0" + normalized.substr(1)
	
	# Handle trailing decimal (5. → 5)
	if normalized.ends_with("."):
		normalized = normalized.substr(0, normalized.length() - 1)
	
	return float(normalized)

func is_close_float(a: float, b: float, epsilon: float = 0.001) -> bool:
	"""Compare two floats with a small epsilon for floating point errors"""
	return abs(a - b) < epsilon

func fractions_are_equivalent(fraction1: String, fraction2: String) -> bool:
	"""Check if two fraction strings represent the same value.
	Handles: mixed numbers (2 1/2), improper fractions (5/2), simple fractions (1/2), whole numbers (3)"""
	var value1 = fraction_string_to_float(fraction1)
	var value2 = fraction_string_to_float(fraction2)
	return is_close_float(value1, value2)

func fraction_string_to_float(fraction_str: String) -> float:
	"""Convert a fraction string to a float value.
	Handles: mixed numbers (2 1/2), improper fractions (5/2), simple fractions (1/2), whole numbers (3)"""
	fraction_str = fraction_str.strip_edges()
	
	if fraction_str == "":
		return 0.0
	
	# Check if it's a mixed number (contains space and slash)
	if " " in fraction_str and "/" in fraction_str:
		var parts = fraction_str.split(" ")
		if parts.size() >= 2:
			var whole = float(parts[0])
			var frac_part = parts[1]
			if "/" in frac_part:
				var frac_parts = frac_part.split("/")
				if frac_parts.size() == 2:
					var numer = float(frac_parts[0])
					var denom = float(frac_parts[1])
					if denom != 0:
						if whole >= 0:
							return whole + (numer / denom)
						else:
							return whole - (numer / denom)
		return 0.0
	
	# Check if it's a simple fraction (contains slash but no space)
	if "/" in fraction_str:
		var parts = fraction_str.split("/")
		if parts.size() == 2:
			var numer = float(parts[0])
			var denom = float(parts[1])
			if denom != 0:
				return numer / denom
		return 0.0
	
	# Otherwise it's a whole number
	return float(fraction_str)
