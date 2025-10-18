extends Control

# Main coordinator - orchestrates all managers for the game

func _ready():
	# Initialize all managers in dependency order
	SaveManager.initialize()
	QuestionManager.initialize()
	ScoreManager.initialize()
	
	# Initialize managers that need references to this node
	DisplayManager.initialize(self)
	InputManager.initialize(self)
	UIManager.initialize(self)
	StateManager.initialize(self)
	LevelManager.initialize(self)
	PlaycademyManager.initialize()
	
	# Start music now that volumes are set
	AudioManager.start_music()
	
	# Create dynamic level buttons
	LevelManager.create_level_buttons()
	
	# Update menu display after buttons are created
	LevelManager.update_menu_stars()
	LevelManager.update_level_availability()
	UIManager.update_drill_mode_high_score_display()
	
	# Connect menu buttons
	connect_menu_buttons()
	connect_game_over_buttons()

func _input(event):
	# Delegate input handling to InputManager
	StateManager.user_answer = InputManager.handle_input_event(event, StateManager.user_answer, StateManager.answer_submitted, StateManager.current_state)
	
	# Handle immediate backspace press detection
	InputManager.handle_backspace_just_pressed(StateManager.current_state)
	
	# Handle submit (only during PLAY or DRILL_PLAY state)
	if Input.is_action_just_pressed("Submit") and (StateManager.current_state == GameConfig.GameState.PLAY or StateManager.current_state == GameConfig.GameState.DRILL_PLAY):
		submit_answer()

func _process(delta):
	# Process UI animations
	UIManager.process_animations(delta, StateManager.current_state, StateManager.is_drill_mode)
	
	# Only process game logic during PLAY or DRILL_PLAY state
	if StateManager.current_state == GameConfig.GameState.PLAY or StateManager.current_state == GameConfig.GameState.DRILL_PLAY:
		# Handle timer logic with grace period (but not during transition delays)
		if not ScoreManager.timer_started and not StateManager.in_transition_delay:
			ScoreManager.update_grace_period(delta)
		
		# Update timer based on mode
		if ScoreManager.timer_active:
			if StateManager.is_drill_mode:
				var time_ran_out = ScoreManager.update_drill_timer(delta)
				if time_ran_out:
					StateManager.go_to_drill_mode_game_over()
					return
			else:
				ScoreManager.update_normal_timer(delta)
		
		# Update blink timer
		DisplayManager.update_blink_timer(delta)
		
		# Handle backspace
		StateManager.user_answer = InputManager.process_backspace(delta, StateManager.user_answer, StateManager.answer_submitted)
		
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
	
	if QuestionManager.is_fraction_display_type(QuestionManager.current_question.get("type", "")):
		# For fraction questions, compare strings directly
		player_answer_value = StateManager.user_answer
		is_correct = (StateManager.user_answer == QuestionManager.current_question.result)
	else:
		# For integer questions, compare as integers
		player_answer_value = int(StateManager.user_answer)
		is_correct = (player_answer_value == QuestionManager.current_question.result)
	
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
	if not is_correct:
		delay_to_use = GameConfig.transition_delay_incorrect  # Longer delay for incorrect answers
	
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
	
	# If incorrect and require_submit_after_incorrect is true, wait for player to press Submit to continue
	if not is_correct and GameConfig.require_submit_after_incorrect:
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
	
	# Animate current problem off screen
	animate_problem_off_screen(is_correct)
	
	# Increment problems completed
	StateManager.problems_completed += 1
	
	# Animate progress line after incrementing
	if not StateManager.is_drill_mode:
		animate_progress_line()
	
	# Check if we've completed the required number of problems (only for normal mode)
	var level_config = GameConfig.level_configs.get(StateManager.current_level_number, GameConfig.level_configs[1])
	if not StateManager.is_drill_mode and StateManager.problems_completed >= level_config.problems:
		# Hide play UI labels when play state ends
		if UIManager.timer_label:
			UIManager.timer_label.visible = false
		if UIManager.accuracy_label:
			UIManager.accuracy_label.visible = false
		
		# Wait for the problem to finish animating off screen before transitioning
		await get_tree().create_timer(GameConfig.animation_duration).timeout
		StateManager.go_to_game_over()
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
		DisplayManager.answer_fraction_node = null
		
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
		tween.tween_property(old_label, "position", GameConfig.off_screen_top, GameConfig.animation_duration)
		tween.tween_callback(old_label.queue_free)

func animate_progress_line():
	"""Animate the progress line for normal mode levels"""
	var level_config = GameConfig.level_configs.get(StateManager.current_level_number, GameConfig.level_configs[1])
	
	if UIManager.progress_line and DisplayManager.play_node:
		var play_width = DisplayManager.play_node.size.x
		var progress_increment = play_width / level_config.problems
		var new_x_position = progress_increment * StateManager.problems_completed
		
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

func connect_game_over_buttons():
	"""Connect all game over buttons to their respective functions"""
	# Connect continue button
	if UIManager.continue_button:
		UIManager.continue_button.pressed.connect(StateManager._on_continue_button_pressed)
		UIManager.connect_button_sounds(UIManager.continue_button)
