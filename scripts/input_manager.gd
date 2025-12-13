extends Node

# Input manager - handles all user input, fraction input modes, and control guide visibility

# Fraction input state variables
var is_fraction_input = false  # Whether the user's answer is currently in fraction format
var is_mixed_fraction_input = false  # Whether the user's answer is a mixed fraction
var editing_numerator = true  # For mixed fractions: whether we're editing numerator (true) or denominator (false)

# Multi-input state variables (for problems with multiple answer slots)
var is_multi_input = false  # Whether this is a multi-input problem
var current_input_slot = 0  # Which input slot is currently active (0 or 1)
var multi_input_values = ["", ""]  # Values for each input slot

# Backspace state
var backspace_timer = 0.0  # Timer for backspace hold functionality
var backspace_held = false  # Track if backspace is being held
var backspace_just_pressed = false  # Track if backspace was just pressed this frame

# Left/Right input state (for number line questions)
var left_timer = 0.0  # Timer for left hold functionality
var left_held = false  # Track if left is being held
var left_just_pressed = false  # Track if left was just pressed this frame
var right_timer = 0.0  # Timer for right hold functionality
var right_held = false  # Track if right is being held
var right_just_pressed = false  # Track if right was just pressed this frame

# Control guide node references
var control_guide_enter: Control  # Reference to the Enter control node
var control_guide_tab: Control  # Reference to the Tab control node
var control_guide_divide: Control  # Reference to the Divide control node
var control_guide_enter2: Control  # Reference to the Enter2 control node (for continuing after incorrect answers)

func initialize(main_node: Control):
	"""Initialize input manager with references to needed nodes"""
	var play_node = main_node.get_node("Play")
	control_guide_enter = play_node.get_node("ControlGuide/Enter")
	control_guide_tab = play_node.get_node("ControlGuide/Tab")
	control_guide_divide = play_node.get_node("ControlGuide/Divide")
	control_guide_enter2 = play_node.get_node("ControlGuide/Enter2")
	
	# Initially hide Enter2 (only shown when waiting for continue after incorrect answer)
	control_guide_enter2.visible = false

func reset_for_new_question():
	"""Reset input state for a new question"""
	is_fraction_input = false
	is_mixed_fraction_input = false
	editing_numerator = true
	
	# Reset multi-input state
	is_multi_input = false
	current_input_slot = 0
	multi_input_values = ["", ""]
	
	# Reset Left/Right state for number line questions
	left_just_pressed = false
	right_just_pressed = false
	left_held = false
	right_held = false
	left_timer = 0.0
	right_timer = 0.0

func handle_input_event(event: InputEvent, user_answer: String, answer_submitted: bool, current_state: int) -> String:
	"""Handle input events and return the modified user_answer"""
	# Record input for TimeBack tracking
	if (current_state == GameConfig.GameState.PLAY or current_state == GameConfig.GameState.DRILL_PLAY):
		PlaycademyManager.record_player_input()
	
	# Handle number line input (Left/Right)
	if (current_state == GameConfig.GameState.PLAY or current_state == GameConfig.GameState.DRILL_PLAY):
		var is_number_line_question = QuestionManager.current_question and QuestionManager.is_number_line_display_type(QuestionManager.current_question.get("type", ""))
		if is_number_line_question and not answer_submitted:
			if event is InputEventKey and event.pressed and not event.echo:
				if Input.is_action_just_pressed("Left"):
					left_just_pressed = true
				elif Input.is_action_just_pressed("Right"):
					right_just_pressed = true
			# Return early for number line - don't process other inputs (except Submit which is handled in main.gd)
			return user_answer
	
	# Handle multiple choice input (AnswerOne through AnswerFive)
	if (current_state == GameConfig.GameState.PLAY or current_state == GameConfig.GameState.DRILL_PLAY):
		var is_choice_question = QuestionManager.current_question and QuestionManager.is_multiple_choice_display_type(QuestionManager.current_question.get("type", ""))
		if is_choice_question:
			if event is InputEventKey and event.pressed and not event.echo:
				var answer_actions = ["AnswerOne", "AnswerTwo", "AnswerThree", "AnswerFour", "AnswerFive"]
				for i in range(answer_actions.size()):
					if Input.is_action_just_pressed(answer_actions[i]):
						# Trigger the multiple choice answer selection
						if i < DisplayManager.multiple_choice_buttons.size():
							DisplayManager._on_multiple_choice_answer_selected(i)
						break
				# Return early for multiple choice - don't process other inputs
				return user_answer
	
	# Handle multi-input problems (e.g., equivalence_mult_factoring)
	if (current_state == GameConfig.GameState.PLAY or current_state == GameConfig.GameState.DRILL_PLAY):
		var is_multi_input_question = QuestionManager.current_question and QuestionManager.is_multi_input_display_type(QuestionManager.current_question.get("type", ""))
		if is_multi_input_question and not answer_submitted:
			# Initialize multi-input mode if not already
			if not is_multi_input:
				is_multi_input = true
				current_input_slot = 0
				multi_input_values = ["", ""]
			
			if event is InputEventKey and event.pressed and not event.echo:
				# Check each digit input action
				var digit_actions = ["Zero", "One", "Two", "Three", "Four", "Five", "Six", "Seven", "Eight", "Nine"]
				for digit_idx in range(digit_actions.size()):
					if Input.is_action_just_pressed(digit_actions[digit_idx]):
						var digit = str(digit_idx)
						
						# Add digit to current slot if within limit
						if multi_input_values[current_input_slot].length() < GameConfig.max_answer_chars:
							multi_input_values[current_input_slot] += digit
							AudioManager.play_tick()
						break
			
			# Return the combined answer string for display purposes
			# Format: "slot0|slot1" with current slot marker
			return _get_multi_input_display_string()
	
	# Handle number input and negative sign (only during PLAY or DRILL_PLAY state and if not submitted)
	if (current_state == GameConfig.GameState.PLAY or current_state == GameConfig.GameState.DRILL_PLAY) and not answer_submitted:
		# Only process key events
		if event is InputEventKey and event.pressed and not event.echo:
			# Check each digit input action
			var digit_actions = ["Zero", "One", "Two", "Three", "Four", "Five", "Six", "Seven", "Eight", "Nine"]
			for i in range(digit_actions.size()):
				if Input.is_action_just_pressed(digit_actions[i]):
					var digit = str(i)
					
					# Handle locked input mode for equivalence problems
					if DisplayManager.answer_fraction_node and DisplayManager.answer_fraction_node.is_locked_input_mode:
						var effective_length = user_answer.length()
						if effective_length < GameConfig.max_answer_chars:
							user_answer += digit
							AudioManager.play_tick()
					elif is_mixed_fraction_input:
						# Mixed fraction input mode
						var parts = user_answer.split(" ")
						if parts.size() == 2:
							var fraction_parts = parts[1].split("/")
							if fraction_parts.size() == 2:
								if editing_numerator:
									# Add to numerator
									var numer = fraction_parts[0]
									var effective_length = numer.length()
									if effective_length < GameConfig.max_answer_chars:
										user_answer = parts[0] + " " + numer + digit + "/" + fraction_parts[1]
										AudioManager.play_tick()
								else:
									# Add to denominator
									var denom = fraction_parts[1]
									var effective_length = denom.length()
									if effective_length < GameConfig.max_answer_chars:
										user_answer = parts[0] + " " + fraction_parts[0] + "/" + denom + digit
										AudioManager.play_tick()
					elif is_fraction_input:
						# Regular fraction input mode - add to denominator
						var parts = user_answer.split("/")
						if parts.size() == 2:
							var denom = parts[1]
							var effective_length = denom.length()
							if effective_length < GameConfig.max_answer_chars:
								user_answer = parts[0] + "/" + denom + digit
								AudioManager.play_tick()
					else:
						# Normal input mode
						var effective_length = user_answer.length()
						if user_answer.begins_with("-"):
							effective_length -= 1  # Don't count negative sign toward limit
						if "." in user_answer:
							effective_length -= 1  # Don't count decimal point toward limit
						if effective_length < GameConfig.max_answer_chars:
							user_answer += digit
							AudioManager.play_tick()  # Play tick sound on digit input
					break
			
			# Handle negative sign (only at the beginning and only if not fraction input)
			if Input.is_action_just_pressed("Negative") and user_answer == "" and not is_fraction_input:
				user_answer = "-"
				AudioManager.play_tick()  # Play tick sound on minus input
			
			# Handle decimal point input (only one allowed, not in fraction mode)
			if Input.is_action_just_pressed("Decimal") and not is_fraction_input and not is_mixed_fraction_input:
				# Only allow if no decimal point exists yet
				if not "." in user_answer:
					user_answer += "."
					AudioManager.play_tick()
			
			# Handle Fraction key - create mixed fraction (only for fraction-type questions, and NOT in locked mode)
			var question_type = QuestionManager.current_question.get("type", "") if QuestionManager.current_question else ""
			var is_fraction_type = QuestionManager.is_fraction_display_type(question_type) or QuestionManager.is_fraction_conversion_display_type(question_type)
			if Input.is_action_just_pressed("Fraction") and QuestionManager.current_question and is_fraction_type:
				# Disable in locked input mode
				if DisplayManager.answer_fraction_node and DisplayManager.answer_fraction_node.is_locked_input_mode:
					pass  # Do nothing in locked mode
				elif is_mixed_fraction_input:
					# Already in mixed fraction mode - transition from numerator to denominator
					if editing_numerator:
						# Only allow transition if numerator is not empty
						var parts = user_answer.split(" ")
						if parts.size() == 2:
							var fraction_parts = parts[1].split("/")
							if fraction_parts.size() == 2 and fraction_parts[0] != "" and fraction_parts[0] != "-":
								editing_numerator = false
								AudioManager.play_tick()
				elif not is_fraction_input and user_answer != "" and user_answer != "-":
					# Convert current answer to whole number of mixed fraction
					is_fraction_input = true
					is_mixed_fraction_input = true
					editing_numerator = true
					user_answer = user_answer + " /"  # Format: "2 /"
					AudioManager.play_tick()
					# Create answer fraction visual if needed
					if DisplayManager.answer_fraction_node == null:
						DisplayManager.create_answer_mixed_fraction(user_answer)
			
			# Handle Divide key - convert to fraction input or transition to denominator (only for fraction-type questions, and NOT in locked mode)
			if Input.is_action_just_pressed("Divide") and QuestionManager.current_question and is_fraction_type:
				# Disable in locked input mode
				if DisplayManager.answer_fraction_node and DisplayManager.answer_fraction_node.is_locked_input_mode:
					pass  # Do nothing in locked mode
				elif is_mixed_fraction_input:
					# In mixed fraction mode - transition from numerator to denominator
					if editing_numerator:
						# Only allow transition if numerator is not empty
						var parts = user_answer.split(" ")
						if parts.size() == 2:
							var fraction_parts = parts[1].split("/")
							if fraction_parts.size() == 2 and fraction_parts[0] != "" and fraction_parts[0] != "-":
								editing_numerator = false
								AudioManager.play_tick()
				elif not is_fraction_input and user_answer != "" and user_answer != "-":
					# Convert current answer to numerator of regular fraction
					is_fraction_input = true
					user_answer = user_answer + "/"
					AudioManager.play_tick()
					# Create answer fraction visual if needed
					if DisplayManager.answer_fraction_node == null:
						DisplayManager.create_answer_fraction()
	
	return user_answer

func handle_backspace_just_pressed(current_state: int) -> bool:
	"""Check if backspace was just pressed. Returns true if backspace should be processed."""
	if Input.is_action_just_pressed("Backspace") and (current_state == GameConfig.GameState.PLAY or current_state == GameConfig.GameState.DRILL_PLAY):
		backspace_just_pressed = true
		return true
	return false

func process_backspace(delta: float, user_answer: String, answer_submitted: bool) -> String:
	"""Process backspace logic and return the modified user_answer"""
	# Handle multi-input backspace separately
	if is_multi_input:
		if backspace_just_pressed and not answer_submitted:
			handle_multi_input_backspace()
			backspace_just_pressed = false
			backspace_timer = 0.0
		
		# Handle backspace hold functionality for multi-input
		if Input.is_action_pressed("Backspace") and not answer_submitted:
			if not backspace_held:
				backspace_timer += delta
				if backspace_timer >= GameConfig.backspace_hold_time:
					backspace_held = true
					backspace_timer = 0.0
			else:
				# Repeat backspace every 0.05 seconds while held
				backspace_timer += delta
				if backspace_timer >= 0.05:
					backspace_timer = 0.0
					handle_multi_input_backspace()
		else:
			# Reset hold state when backspace is released
			backspace_held = false
			backspace_timer = 0.0
		
		return _get_multi_input_display_string()
	
	# Handle backspace - immediate response for single press, hold for repeat
	if backspace_just_pressed and not answer_submitted:
		# Immediate backspace on first press
		user_answer = process_single_backspace(user_answer)
		backspace_just_pressed = false
		backspace_timer = 0.0
	
	# Handle backspace hold functionality
	if Input.is_action_pressed("Backspace") and not answer_submitted:
		if not backspace_held:
			backspace_timer += delta
			if backspace_timer >= GameConfig.backspace_hold_time:
				backspace_held = true
				backspace_timer = 0.0
		else:
			# Repeat backspace every 0.05 seconds while held
			backspace_timer += delta
			if backspace_timer >= 0.05:
				backspace_timer = 0.0
				user_answer = process_single_backspace(user_answer)
	else:
		# Reset hold state when backspace is released
		backspace_held = false
		backspace_timer = 0.0
	
	return user_answer

func process_number_line_input(delta: float, answer_submitted: bool):
	"""Process Left/Right input for number line questions"""
	if answer_submitted or not DisplayManager.current_number_line:
		# Reset state when not applicable
		left_just_pressed = false
		right_just_pressed = false
		left_held = false
		right_held = false
		left_timer = 0.0
		right_timer = 0.0
		return
	
	var number_line = DisplayManager.current_number_line
	var control_mode = number_line.control_mode
	
	# Check if Shift is held (for continuous mode pip snapping)
	var shift_held = Input.is_key_pressed(KEY_SHIFT)
	
	if control_mode == "continuous":
		# Continuous movement mode
		var left_pressed = Input.is_action_pressed("Left")
		var right_pressed = Input.is_action_pressed("Right")
		
		if shift_held:
			# Shift held: snap to pip mode (one-shot on press)
			if left_just_pressed:
				# Move to previous pip
				var current_pip = number_line.get_nearest_pip_index(number_line.pointer_x)
				if current_pip > 0:
					number_line.pointer_x = number_line.get_pip_x_position(current_pip - 1)
					number_line._update_pointer_position_immediate()
					number_line._update_control_visibility()
					AudioManager.play_tick()
				left_just_pressed = false
			
			if right_just_pressed:
				# Move to next pip
				var current_pip = number_line.get_nearest_pip_index(number_line.pointer_x)
				if current_pip < number_line.total_pips - 1:
					number_line.pointer_x = number_line.get_pip_x_position(current_pip + 1)
					number_line._update_pointer_position_immediate()
					number_line._update_control_visibility()
					AudioManager.play_tick()
				right_just_pressed = false
			
			# Stop continuous movement when shift is held
			number_line.stop_continuous_movement()
		else:
			# No shift: smooth continuous movement
			left_just_pressed = false
			right_just_pressed = false
			
			if left_pressed and not right_pressed:
				number_line.move_continuous(-1, delta)
				number_line._update_control_visibility()
			elif right_pressed and not left_pressed:
				number_line.move_continuous(1, delta)
				number_line._update_control_visibility()
			else:
				# Neither held or both held - stop movement
				number_line.stop_continuous_movement()
	else:
		# Pip-to-pip mode (original behavior)
		# Handle Left input
		if left_just_pressed:
			# Immediate move on first press
			number_line.move_left()
			left_just_pressed = false
			left_timer = 0.0
		
		# Handle Left hold functionality
		if Input.is_action_pressed("Left"):
			if not left_held:
				left_timer += delta
				if left_timer >= GameConfig.number_line_left_right_hold_time:
					left_held = true
					left_timer = 0.0
			else:
				# Repeat while held
				left_timer += delta
				if left_timer >= GameConfig.number_line_left_right_repeat_interval:
					left_timer = 0.0
					number_line.move_left()
		else:
			# Reset hold state when left is released
			left_held = false
			left_timer = 0.0
		
		# Handle Right input
		if right_just_pressed:
			# Immediate move on first press
			number_line.move_right()
			right_just_pressed = false
			right_timer = 0.0
		
		# Handle Right hold functionality
		if Input.is_action_pressed("Right"):
			if not right_held:
				right_timer += delta
				if right_timer >= GameConfig.number_line_left_right_hold_time:
					right_held = true
					right_timer = 0.0
			else:
				# Repeat while held
				right_timer += delta
				if right_timer >= GameConfig.number_line_left_right_repeat_interval:
					right_timer = 0.0
					number_line.move_right()
		else:
			# Reset hold state when right is released
			right_held = false
			right_timer = 0.0

func process_single_backspace(user_answer: String) -> String:
	"""Process a single backspace press and return the modified user_answer"""
	if user_answer.length() > 0:
		# Handle locked input mode - just delete characters, don't remove the fraction
		if DisplayManager.answer_fraction_node and DisplayManager.answer_fraction_node.is_locked_input_mode:
			user_answer = user_answer.substr(0, user_answer.length() - 1)
			AudioManager.play_tick()
		elif is_mixed_fraction_input:
			# Mixed fraction backspace logic
			var parts = user_answer.split(" ")
			if parts.size() == 2:
				var fraction_parts = parts[1].split("/")
				if fraction_parts.size() == 2:
					if editing_numerator:
						# Backspacing in numerator
						var numer = fraction_parts[0]
						if numer == "":
							# Numerator empty - exit mixed fraction mode
							is_fraction_input = false
							is_mixed_fraction_input = false
							editing_numerator = true
							user_answer = parts[0]  # Return to just the whole number
							AudioManager.play_tick()
							# Clean up answer fraction visual
							if DisplayManager.answer_fraction_node:
								DisplayManager.answer_fraction_node.queue_free()
								var idx = DisplayManager.current_problem_nodes.find(DisplayManager.answer_fraction_node)
								if idx != -1:
									DisplayManager.current_problem_nodes.remove_at(idx)
								DisplayManager.answer_fraction_node = null
							# Show the regular label again
							if DisplayManager.current_problem_label:
								DisplayManager.current_problem_label.visible = true
						else:
							# Remove last digit from numerator
							user_answer = parts[0] + " " + numer.substr(0, numer.length() - 1) + "/" + fraction_parts[1]
							AudioManager.play_tick()
					else:
						# Backspacing in denominator
						var denom = fraction_parts[1]
						if denom == "":
							# Denominator empty - move back to numerator
							editing_numerator = true
							AudioManager.play_tick()
						else:
							# Remove last digit from denominator
							user_answer = parts[0] + " " + fraction_parts[0] + "/" + denom.substr(0, denom.length() - 1)
							AudioManager.play_tick()
		else:
			# Regular fraction or normal backspace logic
			# Check if we need to exit fraction mode BEFORE backspacing
			# (if denominator is already empty, indicated by ending with "/")
			var should_exit_fraction = is_fraction_input and user_answer.ends_with("/")
			
			user_answer = user_answer.substr(0, user_answer.length() - 1)
			AudioManager.play_tick()
			
			# Exit fraction mode if denominator was already empty
			if should_exit_fraction:
				is_fraction_input = false
				# Clean up answer fraction visual
				if DisplayManager.answer_fraction_node:
					DisplayManager.answer_fraction_node.queue_free()
					# Remove from current_problem_nodes array
					var idx = DisplayManager.current_problem_nodes.find(DisplayManager.answer_fraction_node)
					if idx != -1:
						DisplayManager.current_problem_nodes.remove_at(idx)
					DisplayManager.answer_fraction_node = null
				# Show the regular label again
				if DisplayManager.current_problem_label:
					DisplayManager.current_problem_label.visible = true
	
	return user_answer

func _get_multi_input_display_string() -> String:
	"""Get the display string for multi-input problems.
	Format: 'value0|value1|slot_index' where slot_index indicates current active slot"""
	return multi_input_values[0] + "|" + multi_input_values[1] + "|" + str(current_input_slot)

func handle_multi_input_submit() -> bool:
	"""Handle Submit action for multi-input problems.
	Returns true if final answer should be submitted, false if just moving to next slot."""
	if not is_multi_input:
		return true  # Not a multi-input problem, proceed normally
	
	if current_input_slot == 0:
		# In first slot - check if it has input
		if multi_input_values[0] != "":
			# Move to second slot
			current_input_slot = 1
			AudioManager.play_tick()
			return false  # Don't submit yet
		else:
			# First slot empty - ignore submit
			return false
	else:
		# In second slot - check if both slots have input
		if multi_input_values[0] != "" and multi_input_values[1] != "":
			return true  # Submit the final answer
		else:
			# Second slot empty - ignore submit
			return false

func handle_multi_input_backspace() -> bool:
	"""Handle Backspace action for multi-input problems.
	Returns true if backspace was handled, false otherwise."""
	if not is_multi_input:
		return false  # Not a multi-input problem
	
	if current_input_slot == 1:
		# In second slot
		if multi_input_values[1] == "":
			# Second slot is empty - go back to first slot
			current_input_slot = 0
			AudioManager.play_tick()
			return true
		else:
			# Remove last character from second slot
			multi_input_values[1] = multi_input_values[1].substr(0, multi_input_values[1].length() - 1)
			AudioManager.play_tick()
			return true
	else:
		# In first slot
		if multi_input_values[0] != "":
			# Remove last character from first slot
			multi_input_values[0] = multi_input_values[0].substr(0, multi_input_values[0].length() - 1)
			AudioManager.play_tick()
			return true
		# First slot already empty - do nothing
		return true

func get_multi_input_answers() -> Array:
	"""Get the two input values as integers for validation"""
	if not is_multi_input:
		return []
	
	var answers = []
	for i in range(2):
		if multi_input_values[i] != "":
			answers.append(int(multi_input_values[i]))
		else:
			answers.append(0)
	return answers

func update_control_guide_visibility(user_answer: String, answer_submitted: bool):
	"""Update visibility and positions of control guide nodes based on game state"""
	if not control_guide_enter or not control_guide_tab or not control_guide_divide or not control_guide_enter2:
		return
	
	# Declare current_x at function level to avoid scope warnings
	var current_x: float
	
	# Check if waiting for continue after incorrect (takes priority over everything)
	if StateManager.waiting_for_continue_after_incorrect:
		control_guide_enter.visible = false
		control_guide_tab.visible = false
		control_guide_divide.visible = false
		control_guide_enter2.visible = true
		
		# Position Enter2 (already positioned by the regular control guide logic below, but ensure it's visible)
		current_x = GameConfig.control_guide_max_x
		var control_width = control_guide_enter2.size.x
		var target_x = current_x - control_width
		var target_position = Vector2(target_x, control_guide_enter2.position.y)
		
		if control_guide_enter2.position.distance_to(target_position) > 0.1:
			var tween = control_guide_enter2.create_tween()
			tween.set_ease(Tween.EASE_OUT)
			tween.set_trans(Tween.TRANS_EXPO)
			tween.tween_property(control_guide_enter2, "position", target_position, GameConfig.control_guide_animation_duration)
		return
	
	# Handle multi-input question controls
	var is_multi_input_question = QuestionManager.current_question and QuestionManager.is_multi_input_display_type(QuestionManager.current_question.get("type", ""))
	if is_multi_input_question:
		control_guide_tab.visible = false
		control_guide_divide.visible = false
		control_guide_enter2.visible = false
		
		# Show Enter when:
		# - In slot 0 with input (to move to slot 1)
		# - In slot 1 with both slots having input (to submit)
		var show_enter_multi = false
		if not answer_submitted:
			if current_input_slot == 0 and multi_input_values[0] != "":
				show_enter_multi = true
			elif current_input_slot == 1 and multi_input_values[0] != "" and multi_input_values[1] != "":
				show_enter_multi = true
		
		control_guide_enter.visible = show_enter_multi
		
		# Position Enter control if visible
		if show_enter_multi:
			current_x = GameConfig.control_guide_max_x
			var control_width_enter = control_guide_enter.size.x
			var target_x_enter = current_x - control_width_enter
			var target_position_enter = Vector2(target_x_enter, control_guide_enter.position.y)
			
			if control_guide_enter.position.distance_to(target_position_enter) > 0.1:
				var tween = control_guide_enter.create_tween()
				tween.set_ease(Tween.EASE_OUT)
				tween.set_trans(Tween.TRANS_EXPO)
				tween.tween_property(control_guide_enter, "position", target_position_enter, GameConfig.control_guide_animation_duration)
		return
	
	# Hide all controls for multiple choice questions (when not waiting for continue)
	var is_choice_question = QuestionManager.current_question and QuestionManager.is_multiple_choice_display_type(QuestionManager.current_question.get("type", ""))
	if is_choice_question:
		control_guide_enter.visible = false
		control_guide_tab.visible = false
		control_guide_divide.visible = false
		control_guide_enter2.visible = false
		return
	
	# Check if this is a number line question (Tab/Divide won't be shown since they're only for fraction input)
	var is_number_line_question = QuestionManager.current_question and QuestionManager.is_number_line_display_type(QuestionManager.current_question.get("type", ""))
	
	var frac_type = QuestionManager.current_question.get("type", "") if QuestionManager.current_question else ""
	var is_fraction_problem = QuestionManager.current_question and (QuestionManager.is_fraction_display_type(frac_type) or QuestionManager.is_fraction_conversion_display_type(frac_type))
	var has_valid_input = user_answer != "" and user_answer != "-"
	
	# Determine visibility for each control
	var show_enter = true
	var show_tab = false
	var show_divide = false
	var show_enter2 = false
	
	# Enter2 visibility: only show when waiting for continue after incorrect
	if StateManager.waiting_for_continue_after_incorrect:
		show_enter2 = true
		# Hide all other controls when Enter2 is shown
		show_enter = false
		show_tab = false
		show_divide = false
	else:
		# Enter visibility: hide if answer is empty/invalid or already submitted
		# Exception: number line questions always have a valid selection
		if is_number_line_question:
			# Number line questions always have a valid answer (selected pip)
			show_enter = not answer_submitted
		elif user_answer == "" or user_answer == "-" or answer_submitted:
			show_enter = false
		
		# Check for locked input mode (equivalence problems)
		if DisplayManager.answer_fraction_node and DisplayManager.answer_fraction_node.is_locked_input_mode:
			# In locked mode, allow submit if user has entered something
			if user_answer == "":
				show_enter = false
		# Check for incomplete fraction input
		elif is_mixed_fraction_input:
			var parts = user_answer.split(" ")
			if parts.size() != 2:
				show_enter = false
			else:
				var fraction_parts = parts[1].split("/")
				if fraction_parts.size() != 2:
					show_enter = false
				elif editing_numerator:
					# Still editing numerator, can't submit yet
					show_enter = false
				elif fraction_parts[0] == "" or fraction_parts[1] == "":
					# Empty numerator or denominator
					show_enter = false
		elif is_fraction_input and not is_mixed_fraction_input:
			var parts = user_answer.split("/")
			if parts.size() != 2 or parts[1] == "":
				show_enter = false
		
		# Tab (Fraction key) visibility: only for fraction problems with valid input, not already in any fraction mode, and NOT in locked mode
		if is_fraction_problem and has_valid_input and not answer_submitted:
			# Only show if not in fraction mode yet AND not in locked mode
			var is_locked = DisplayManager.answer_fraction_node and DisplayManager.answer_fraction_node.is_locked_input_mode
			show_tab = not is_fraction_input and not is_mixed_fraction_input and not is_locked
		
		# Divide visibility: only for fraction problems with valid input, not already in any fraction mode, and NOT in locked mode
		if is_fraction_problem and has_valid_input and not answer_submitted:
			# Only show if not in fraction mode yet AND not in locked mode
			var is_locked = DisplayManager.answer_fraction_node and DisplayManager.answer_fraction_node.is_locked_input_mode
			show_divide = not is_fraction_input and not is_mixed_fraction_input and not is_locked
	
	# Update visibility
	control_guide_enter.visible = show_enter
	control_guide_tab.visible = show_tab
	control_guide_divide.visible = show_divide
	control_guide_enter2.visible = show_enter2
	
	# Calculate positions from right to left using the constant ordering
	var visible_controls = []
	for control_type in GameConfig.CONTROL_GUIDE_ORDER:
		match control_type:
			GameConfig.ControlGuideType.DIVIDE:
				if show_divide:
					visible_controls.append(control_guide_divide)
			GameConfig.ControlGuideType.TAB:
				if show_tab:
					visible_controls.append(control_guide_tab)
			GameConfig.ControlGuideType.ENTER:
				if show_enter:
					visible_controls.append(control_guide_enter)
			GameConfig.ControlGuideType.ENTER2:
				if show_enter2:
					visible_controls.append(control_guide_enter2)
	
	# Position controls from right to left, clamping the RIGHT side of the rightmost control to control_guide_max_x
	current_x = GameConfig.control_guide_max_x
	for i in range(visible_controls.size()):
		var control = visible_controls[i]
		var control_width = control.size.x
		
		# Calculate the left position (current_x is the right edge)
		var target_x = current_x - control_width
		var target_position = Vector2(target_x, control.position.y)
		
		# Animate to target position if different
		if control.position.distance_to(target_position) > 0.1:
			var tween = control.create_tween()
			tween.set_ease(Tween.EASE_OUT)
			tween.set_trans(Tween.TRANS_EXPO)
			tween.tween_property(control, "position", target_position, GameConfig.control_guide_animation_duration)
		
		# Move current_x left for next control (subtract width + padding)
		current_x = target_x - GameConfig.control_guide_padding
