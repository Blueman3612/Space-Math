extends Node

# Input manager - handles all user input, fraction input modes, and control guide visibility

# Fraction input state variables
var is_fraction_input = false  # Whether the user's answer is currently in fraction format
var is_mixed_fraction_input = false  # Whether the user's answer is a mixed fraction
var editing_numerator = true  # For mixed fractions: whether we're editing numerator (true) or denominator (false)

# Backspace state
var backspace_timer = 0.0  # Timer for backspace hold functionality
var backspace_held = false  # Track if backspace is being held
var backspace_just_pressed = false  # Track if backspace was just pressed this frame

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

func handle_input_event(event: InputEvent, user_answer: String, answer_submitted: bool, current_state: int) -> String:
	"""Handle input events and return the modified user_answer"""
	# Record input for TimeBack tracking
	if (current_state == GameConfig.GameState.PLAY or current_state == GameConfig.GameState.DRILL_PLAY):
		PlaycademyManager.record_player_input()
	
	# Handle multiple choice input (AnswerOne through AnswerFive)
	if (current_state == GameConfig.GameState.PLAY or current_state == GameConfig.GameState.DRILL_PLAY):
		if QuestionManager.current_question and QuestionManager.is_multiple_choice_display_type(QuestionManager.current_question.get("type", "")):
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
						if effective_length < GameConfig.max_answer_chars:
							user_answer += digit
							AudioManager.play_tick()  # Play tick sound on digit input
					break
			
			# Handle negative sign (only at the beginning and only if not fraction input)
			if Input.is_action_just_pressed("Negative") and user_answer == "" and not is_fraction_input:
				user_answer = "-"
				AudioManager.play_tick()  # Play tick sound on minus input
			
			# Handle Fraction key - create mixed fraction (only for fraction-type questions, and NOT in locked mode)
			if Input.is_action_just_pressed("Fraction") and QuestionManager.current_question and QuestionManager.is_fraction_display_type(QuestionManager.current_question.get("type", "")):
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
			if Input.is_action_just_pressed("Divide") and QuestionManager.current_question and QuestionManager.is_fraction_display_type(QuestionManager.current_question.get("type", "")):
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

func update_control_guide_visibility(user_answer: String, answer_submitted: bool):
	"""Update visibility and positions of control guide nodes based on game state"""
	if not control_guide_enter or not control_guide_tab or not control_guide_divide or not control_guide_enter2:
		return
	
	# Check if waiting for continue after incorrect (takes priority over everything)
	if StateManager.waiting_for_continue_after_incorrect:
		control_guide_enter.visible = false
		control_guide_tab.visible = false
		control_guide_divide.visible = false
		control_guide_enter2.visible = true
		
		# Position Enter2 (already positioned by the regular control guide logic below, but ensure it's visible)
		var visible_controls = [control_guide_enter2]
		var current_x = GameConfig.control_guide_max_x
		var control_width = control_guide_enter2.size.x
		var target_x = current_x - control_width
		var target_position = Vector2(target_x, control_guide_enter2.position.y)
		
		if control_guide_enter2.position.distance_to(target_position) > 0.1:
			var tween = control_guide_enter2.create_tween()
			tween.set_ease(Tween.EASE_OUT)
			tween.set_trans(Tween.TRANS_EXPO)
			tween.tween_property(control_guide_enter2, "position", target_position, GameConfig.control_guide_animation_duration)
		return
	
	# Hide all controls for multiple choice questions (when not waiting for continue)
	var is_multiple_choice = QuestionManager.current_question and QuestionManager.is_multiple_choice_display_type(QuestionManager.current_question.get("type", ""))
	if is_multiple_choice:
		control_guide_enter.visible = false
		control_guide_tab.visible = false
		control_guide_divide.visible = false
		control_guide_enter2.visible = false
		return
	
	var is_fraction_problem = QuestionManager.current_question and QuestionManager.is_fraction_display_type(QuestionManager.current_question.get("type", ""))
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
		if user_answer == "" or user_answer == "-" or answer_submitted:
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
	var current_x = GameConfig.control_guide_max_x
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

