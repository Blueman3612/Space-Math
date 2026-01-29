extends Node

# Display manager - handles all problem display, fraction creation, and visual updates

# Node references
var play_node: Control  # Reference to the Play node
var current_problem_label: Label
var label_settings_resource: LabelSettings  # Default/current label settings (GravityBold128)
var label_settings_array: Array = []  # Array of loaded LabelSettings in order of preference (largest to smallest)
var current_problem_label_settings: LabelSettings  # Label settings selected for the current problem

# Current problem display nodes
var current_problem_nodes = []  # Array of nodes (fractions, labels) for the current problem display
var answer_fraction_node = null  # Reference to the fraction node used for answer input
var answer_fraction_base_x = 0.0  # Base X position of answer fraction (before width adjustments)
var answer_fraction_initial_width = 0.0  # Initial divisor width of answer fraction
var correct_answer_nodes = []  # Array of nodes showing the correct answer for incorrect fraction problems

# Multiple choice question nodes
var multiple_choice_buttons = []  # Array of button nodes for multiple choice answers
var multiple_choice_answered = false  # Track if a multiple choice question has been answered
var multiple_choice_correct_index = -1  # Index of the correct answer button

# Number line question nodes
var current_number_line = null  # Reference to the current NumberLine node
var number_line_fraction_label = null  # Reference to the fraction label above the number line

# Prompt label (shown at top of screen for each question)
var current_prompt_label = null  # Reference to the current prompt label
var prompt_label_settings: LabelSettings = null  # Label settings for prompt

# Blink state
var blink_timer = 0.0
var underscore_visible = true

func initialize(main_node: Control):
	"""Initialize display manager with references to needed nodes"""
	play_node = main_node.get_node("Play")
	label_settings_resource = load("res://assets/label settings/GravityBold128.tres")
	
	# Load all label settings in order of preference (largest to smallest)
	label_settings_array.clear()
	for path in GameConfig.problem_label_settings_order:
		var settings = load(path)
		if settings:
			label_settings_array.append(settings)
	
	# Default current problem label settings to the first (largest)
	if label_settings_array.size() > 0:
		current_problem_label_settings = label_settings_array[0]
	else:
		current_problem_label_settings = label_settings_resource
	
	# Load prompt label settings
	prompt_label_settings = load(GameConfig.prompt_label_settings_path)

func update_blink_timer(delta: float):
	"""Update the underscore blink timer"""
	blink_timer += delta
	if blink_timer >= GameConfig.blink_interval:
		blink_timer = 0.0
		underscore_visible = not underscore_visible

func update_problem_display(user_answer: String, answer_submitted: bool, is_fraction_input: bool, is_mixed_fraction_input: bool, editing_numerator: bool):
	"""Update the problem display based on current question type"""
	# Handle multi-input problems differently
	var q_type = QuestionManager.current_question.get("type", "") if QuestionManager.current_question else ""
	if QuestionManager.current_question and QuestionManager.is_multi_input_display_type(q_type):
		update_multi_input_display(answer_submitted)
		return
	
	# Handle fraction-type problems (including conversions) differently
	if QuestionManager.current_question and (QuestionManager.is_fraction_display_type(q_type) or QuestionManager.is_fraction_conversion_display_type(q_type)):
		update_fraction_problem_display(user_answer, answer_submitted, is_fraction_input, is_mixed_fraction_input, editing_numerator)
	elif current_problem_label and QuestionManager.current_question:
		# For equivalence problems, the question already includes "=" and the partial right side
		# For standard problems, we append " = "
		var base_text: String
		if QuestionManager.is_equivalence_display_type(q_type):
			base_text = QuestionManager.current_question.question
		else:
			base_text = QuestionManager.current_question.question + " = "
		var display_text = base_text + user_answer

		# Add blinking underscore only if not submitted
		if not answer_submitted and underscore_visible:
			display_text += "_"

		current_problem_label.text = display_text

func update_fraction_problem_display(user_answer: String, answer_submitted: bool, is_fraction_input: bool, is_mixed_fraction_input: bool, editing_numerator: bool):
	"""Update the display for fraction-type problems"""
	# Handle locked input mode for equivalence problems
	if answer_fraction_node and answer_fraction_node.is_locked_input_mode:
		# In locked mode, just update the editable field
		if answer_fraction_node.locked_to_numerator:
			# User is editing numerator, denominator is locked
			answer_fraction_node.numerator_label.text = user_answer if user_answer != "" else ""
		else:
			# User is editing denominator, numerator is locked
			answer_fraction_node.denominator_label.text = user_answer if user_answer != "" else ""
		
		# Update underscore and layout
		answer_fraction_node.set_fraction_text(
			answer_fraction_node.numerator_label.text, 
			answer_fraction_node.denominator_label.text, 
			true
		)
		answer_fraction_node.update_underscore(underscore_visible and not answer_submitted)
		
		# Dynamically adjust position based on width change
		var width_diff = answer_fraction_node.current_divisor_width - answer_fraction_initial_width
		var new_x = answer_fraction_base_x + (width_diff / 2.0)  # Shift right as it expands
		answer_fraction_node.position.x = new_x
		return
	
	if is_mixed_fraction_input and answer_fraction_node:
		# In mixed fraction mode - use the fraction node to display answer
		var parts = user_answer.split(" ")
		if parts.size() == 2:
			var whole = parts[0]
			var fraction_parts = parts[1].split("/")
			if fraction_parts.size() == 2:
				var numerator = fraction_parts[0]
				var denominator = fraction_parts[1]
				answer_fraction_node.set_mixed_fraction_text(whole, numerator, denominator, editing_numerator, not editing_numerator)
				answer_fraction_node.update_underscore(underscore_visible and not answer_submitted)
				
				# Dynamically adjust position based on total width change (including whole number)
				var width_diff = answer_fraction_node.current_total_width - answer_fraction_initial_width
				var new_x = answer_fraction_base_x + (width_diff / 2.0)  # Shift right as it expands
				answer_fraction_node.position.x = new_x
		
		# Hide the regular label
		if current_problem_label:
			current_problem_label.visible = false
	elif is_fraction_input and answer_fraction_node:
		# In regular fraction mode - use the fraction node to display answer
		var parts = user_answer.split("/")
		if parts.size() == 2:
			var numerator = parts[0]
			var denominator = parts[1]
			answer_fraction_node.set_fraction_text(numerator, denominator, true)
			answer_fraction_node.update_underscore(underscore_visible and not answer_submitted)
			
			# Dynamically adjust position based on divisor width change
			var width_diff = answer_fraction_node.current_divisor_width - answer_fraction_initial_width
			var new_x = answer_fraction_base_x + (width_diff / 2.0)  # Shift right as it expands
			answer_fraction_node.position.x = new_x
		
		# Hide the regular label
		if current_problem_label:
			current_problem_label.visible = false
	else:
		# Not in fraction mode yet - use regular label to show answer with underscore
		if current_problem_label:
			var display_text = user_answer
			
			# Add blinking underscore only if not submitted
			if not answer_submitted and underscore_visible:
				display_text += "_"
			
			current_problem_label.text = display_text
			current_problem_label.visible = true

func create_prompt_label():
	"""Create a prompt label at the top of the screen for the current question"""
	# Skip if label settings not loaded
	if not prompt_label_settings:
		return
	
	# Get prompt text from level config, default to "SOLVE"
	var prompt_text = GameConfig.default_prompt_text
	
	# Check if StateManager level config has a custom prompt (for grade levels)
	if StateManager.current_level_config and StateManager.current_level_config.has("prompt"):
		prompt_text = StateManager.current_level_config.prompt
	# Check if QuestionManager level config has a custom prompt (for assessment mode)
	elif QuestionManager.current_level_config and QuestionManager.current_level_config.has("prompt"):
		prompt_text = QuestionManager.current_level_config.prompt
	# Also check the current question for a prompt override
	elif QuestionManager.current_question and QuestionManager.current_question.has("prompt"):
		prompt_text = QuestionManager.current_question.prompt
	
	# Create the prompt label
	var prompt = Label.new()
	prompt.label_settings = prompt_label_settings
	prompt.text = prompt_text
	prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	prompt.autowrap_mode = TextServer.AUTOWRAP_OFF
	prompt.self_modulate = Color(0, 0, 1)  # Blue color, doesn't change with feedback
	
	# Set initial position at configured Y, with approximate X centering
	# The text will be properly centered once the label calculates its size
	prompt.position = GameConfig.prompt_label_position
	
	# Add to play node
	play_node.add_child(prompt)
	
	# Now that it's in the tree, we can get the actual size and center it
	# The label's size should be calculated after being added to tree
	if prompt.size.x > 0:
		prompt.position.x = GameConfig.prompt_label_position.x - prompt.size.x / 2
	
	# Track for cleanup
	current_prompt_label = prompt
	current_problem_nodes.append(prompt)

func create_new_problem_label():
	"""Create a new problem label for the current question"""
	# Check if this is a number line problem
	if QuestionManager.current_question and QuestionManager.is_number_line_display_type(QuestionManager.current_question.get("type", "")):
		create_number_line_problem()
		# Start timing this question immediately for number line problems
		ScoreManager.start_question_timing()
		return
	
	# Check if this is a multiple choice problem (includes 2-choice and 3-choice)
	if QuestionManager.current_question and QuestionManager.is_multiple_choice_display_type(QuestionManager.current_question.get("type", "")):
		create_multiple_choice_problem()
		# Start timing this question immediately for multiple choice problems
		ScoreManager.start_question_timing()
		return
	
	# Check if this is a multi-input problem (e.g., equivalence_mult_factoring)
	if QuestionManager.current_question and QuestionManager.is_multi_input_display_type(QuestionManager.current_question.get("type", "")):
		create_multi_input_problem()
		# Start timing this question immediately for multi-input problems
		ScoreManager.start_question_timing()
		return
	
	# Check if this is a fraction conversion problem (mixed to improper or improper to mixed)
	if QuestionManager.current_question and QuestionManager.is_fraction_conversion_display_type(QuestionManager.current_question.get("type", "")):
		create_fraction_conversion_problem()
		# Start timing this question immediately for conversion problems
		ScoreManager.start_question_timing()
		return
	
	# Check if this is a fraction-type problem
	if QuestionManager.current_question and QuestionManager.is_fraction_display_type(QuestionManager.current_question.get("type", "")):
		# Check if this is an equivalence problem
		var problem_type = QuestionManager.current_question.get("type", "")
		if problem_type == "Equivalence (4.NF.A)":
			create_equivalence_problem()
		else:
			create_fraction_problem()
		# Start timing this question immediately for fraction problems
		ScoreManager.start_question_timing()
		return
	
	# Create new label for normal (non-fraction) problems
	# First, select the best label settings based on problem width
	current_problem_label_settings = select_label_settings_for_problem()
	
	var new_label = Label.new()
	new_label.label_settings = current_problem_label_settings
	new_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	new_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	new_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	new_label.self_modulate = Color(1, 1, 1)  # Reset to white color
	new_label.z_index = -1  # Render behind UI elements
	
	# Calculate the centered X position based on full expression width
	var target_x = calculate_centered_problem_x(new_label)
	var target_y = GameConfig.primary_position.y
	var target_position = Vector2(target_x, target_y)
	
	# Set initial position off-screen at bottom, with the same X as target
	new_label.position = Vector2(target_x, GameConfig.off_screen_bottom.y)
	
	# Add to Play node so it renders behind Play UI elements
	play_node.add_child(new_label)
	
	# Set as current problem label IMMEDIATELY
	current_problem_label = new_label
	
	# Track for cleanup (so it gets animated off-screen when answered)
	current_problem_nodes.append(new_label)
	
	# Animate to center position (fire and forget)
	var tween = create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_EXPO)
	tween.tween_property(new_label, "position", target_position, GameConfig.animation_duration)
	
	# Start timing this question when animation completes
	tween.tween_callback(ScoreManager.start_question_timing)
	
	# Create prompt label at the end (after other nodes are created)
	create_prompt_label()

func select_label_settings_for_problem() -> LabelSettings:
	"""Select the best label settings for the current problem based on width constraints.
	Tries each size from largest to smallest until one fits within screen bounds."""
	if not QuestionManager.current_question or label_settings_array.size() == 0:
		return label_settings_resource
	
	# Build the maximum width string: question + max possible answer
	# Use "0" repeated max_answer_chars times as the worst-case answer width
	var max_answer = ""
	for _i in range(GameConfig.max_answer_chars):
		max_answer += "0"
	
	var question_text = QuestionManager.current_question.question
	var q_type = QuestionManager.current_question.get("type", "")
	var full_expression: String
	if QuestionManager.is_equivalence_display_type(q_type):
		full_expression = question_text + max_answer
	else:
		full_expression = question_text + " = " + max_answer
	
	# Calculate maximum allowed width (screen width minus padding on both sides)
	var max_width = 1920.0 - (GameConfig.problem_edge_padding * 2)
	
	# Create a temporary label for measuring
	var temp_label = Label.new()
	add_child(temp_label)  # Must be in tree to measure
	
	var selected_settings = label_settings_array[label_settings_array.size() - 1]  # Default to smallest
	
	# Try each label settings in order (largest to smallest)
	for settings in label_settings_array:
		temp_label.label_settings = settings
		temp_label.text = full_expression
		temp_label.reset_size()
		var width = temp_label.get_minimum_size().x
		
		if width <= max_width:
			selected_settings = settings
			break
	
	# Clean up temp label
	temp_label.queue_free()
	
	return selected_settings

func calculate_centered_problem_x(label: Label) -> float:
	"""Calculate the X position to center a problem based on its full expression width (including answer)"""
	if not QuestionManager.current_question:
		return GameConfig.primary_position.x
	
	# Build the full expression: "question = answer"
	# For equivalence problems, question already includes "=" and partial right side
	var question_text = QuestionManager.current_question.question
	var answer_text = str(QuestionManager.current_question.result)
	var q_type = QuestionManager.current_question.get("type", "")
	var full_expression: String
	if QuestionManager.is_equivalence_display_type(q_type):
		full_expression = question_text + answer_text
	else:
		full_expression = question_text + " = " + answer_text
	
	# Temporarily set the label text to measure width
	var original_text = label.text
	label.text = full_expression
	label.reset_size()
	var full_width = label.get_minimum_size().x
	label.text = original_text
	
	# Calculate X position to center the full expression horizontally
	# Screen center is 960 (1920 / 2)
	var screen_center_x = 960.0
	var centered_x = screen_center_x - (full_width / 2.0)
	
	return centered_x

func create_fraction(fraction_position: Vector2, numerator: int = 1, denominator: int = 1, parent: Node = null) -> Control:
	"""Create a fraction instance at the given position with the specified numerator and denominator"""
	# Load the fraction scene
	var fraction_scene = load("res://scenes/fraction.tscn")
	var fraction_instance = fraction_scene.instantiate()
	
	# Set the position
	fraction_instance.position = fraction_position
	
	# Add to the specified parent, or to self if no parent specified
	if parent == null:
		add_child(fraction_instance)
	else:
		parent.add_child(fraction_instance)
	
	# Set the fraction values (this will trigger automatic resizing)
	fraction_instance.set_fraction(numerator, denominator)
	
	# Make sure it's visible and has default white color
	fraction_instance.visible = true
	fraction_instance.modulate = Color(1, 1, 1)
	
	# Return the instance for further manipulation if needed
	return fraction_instance

func parse_mixed_fraction_from_string(frac_str: String) -> Array:
	"""Parse a mixed fraction string like '4 1/6' into [whole, numerator, denominator]
	Or parse a regular fraction like '1/6' into [0, numerator, denominator]"""
	var parts = frac_str.strip_edges().split(" ")
	
	if parts.size() == 2:
		# Mixed fraction: "4 1/6"
		var whole = int(parts[0])
		var frac_parts = parts[1].split("/")
		if frac_parts.size() == 2:
			return [whole, int(frac_parts[0]), int(frac_parts[1])]
	elif parts.size() == 1:
		# Could be a regular fraction "1/6" or whole number "4"
		if parts[0].contains("/"):
			var frac_parts = parts[0].split("/")
			if frac_parts.size() == 2:
				return [0, int(frac_parts[0]), int(frac_parts[1])]
		else:
			# Just a whole number
			return [int(parts[0]), 0, 1]
	
	# Default fallback
	return [0, 0, 1]

func create_multi_input_problem():
	"""Create a multi-input problem display (e.g., a × b = c × ___ × ___)"""
	if not QuestionManager.current_question or not QuestionManager.is_multi_input_display_type(QuestionManager.current_question.get("type", "")):
		return
	
	# Clean up any existing problem nodes
	cleanup_problem_labels()
	
	# Select the best label settings for this problem
	current_problem_label_settings = select_label_settings_for_multi_input_problem()
	
	# Create new label for the problem
	var new_label = Label.new()
	new_label.label_settings = current_problem_label_settings
	new_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	new_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	new_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	new_label.self_modulate = Color(1, 1, 1)  # Reset to white color
	new_label.z_index = -1  # Render behind UI elements
	
	# Set initial text immediately so underscore is visible from the start
	var operands = QuestionManager.current_question.get("operands", [0, 0])
	var given_factor = QuestionManager.current_question.get("given_factor", 0)
	new_label.text = str(operands[0]) + " x " + str(operands[1]) + " = " + str(given_factor) + " x _ x _"
	
	# Calculate the centered X position based on full expression width
	var target_x = calculate_centered_multi_input_x(new_label)
	var target_y = GameConfig.primary_position.y
	var target_position = Vector2(target_x, target_y)
	
	# Set initial position off-screen at bottom, with the same X as target
	new_label.position = Vector2(target_x, GameConfig.off_screen_bottom.y)
	
	# Add to Play node so it renders behind Play UI elements
	play_node.add_child(new_label)
	
	# Set as current problem label IMMEDIATELY
	current_problem_label = new_label
	current_problem_nodes.append(new_label)
	
	# Animate to center position (fire and forget)
	var tween = create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_EXPO)
	tween.tween_property(new_label, "position", target_position, GameConfig.animation_duration)
	
	# Start timing this question when animation completes
	tween.tween_callback(ScoreManager.start_question_timing)
	
	# Create prompt label at the end (after nodes are added to current_problem_nodes)
	create_prompt_label()

func select_label_settings_for_multi_input_problem() -> LabelSettings:
	"""Select the best label settings for multi-input problems based on width constraints."""
	if not QuestionManager.current_question or label_settings_array.size() == 0:
		return label_settings_resource
	
	# Build the maximum width string: use the full expression with max_answer_chars for each slot
	var max_answer = ""
	for _i in range(GameConfig.max_answer_chars):
		max_answer += "0"
	
	# Get the expression and replace the blanks with max_answer
	var operands = QuestionManager.current_question.get("operands", [0, 0])
	var given_factor = QuestionManager.current_question.get("given_factor", 0)
	var full_expression = str(operands[0]) + " x " + str(operands[1]) + " = " + str(given_factor) + " x " + max_answer + " x " + max_answer
	
	# Calculate maximum allowed width (screen width minus padding on both sides)
	var max_width = 1920.0 - (GameConfig.problem_edge_padding * 2)
	
	# Create a temporary label for measuring
	var temp_label = Label.new()
	add_child(temp_label)  # Must be in tree to measure
	
	var selected_settings = label_settings_array[label_settings_array.size() - 1]  # Default to smallest
	
	# Try each label settings in order (largest to smallest)
	for settings in label_settings_array:
		temp_label.label_settings = settings
		temp_label.text = full_expression
		temp_label.reset_size()
		var width = temp_label.get_minimum_size().x
		
		if width <= max_width:
			selected_settings = settings
			break
	
	# Clean up temp label
	temp_label.queue_free()
	
	return selected_settings

func calculate_centered_multi_input_x(label: Label) -> float:
	"""Calculate the X position to center a multi-input problem based on its full expression width"""
	if not QuestionManager.current_question:
		return GameConfig.primary_position.x
	
	# Build the full expression with the expected answers
	var operands = QuestionManager.current_question.get("operands", [0, 0])
	var given_factor = QuestionManager.current_question.get("given_factor", 0)
	var expected_answers = QuestionManager.current_question.get("expected_answers", [0, 0])
	var full_expression = str(operands[0]) + " x " + str(operands[1]) + " = " + str(given_factor) + " x " + str(expected_answers[0]) + " x " + str(expected_answers[1])
	
	# Temporarily set the label text to measure width
	var original_text = label.text
	label.text = full_expression
	label.reset_size()
	var full_width = label.get_minimum_size().x
	label.text = original_text
	
	# Calculate X position to center the full expression horizontally
	# Screen center is 960 (1920 / 2)
	var screen_center_x = 960.0
	var centered_x = screen_center_x - (full_width / 2.0)
	
	return centered_x

func update_multi_input_display(answer_submitted: bool):
	"""Update the display for multi-input problems"""
	if not current_problem_label or not QuestionManager.current_question:
		return
	
	var operands = QuestionManager.current_question.get("operands", [0, 0])
	var given_factor = QuestionManager.current_question.get("given_factor", 0)
	
	# Get the current input values from InputManager
	var slot0_value = InputManager.multi_input_values[0]
	var slot1_value = InputManager.multi_input_values[1]
	var current_slot = InputManager.current_input_slot
	
	# Build the display string
	# Format: "a x b = c x [slot0] x [slot1]"
	var display_text = str(operands[0]) + " x " + str(operands[1]) + " = " + str(given_factor) + " x "
	
	# First slot - always maintain consistent width to prevent layout shifting
	display_text += slot0_value
	if current_slot == 0 and not answer_submitted:
		# Active slot: show blinking underscore or space to maintain width
		if underscore_visible:
			display_text += "_"
		else:
			display_text += " "
	elif slot0_value == "":
		display_text += "_"  # Static underscore placeholder when empty and not active
	
	display_text += " x "
	
	# Second slot - always maintain consistent width to prevent layout shifting
	display_text += slot1_value
	if current_slot == 1 and not answer_submitted:
		# Active slot: show blinking underscore or space to maintain width
		if underscore_visible:
			display_text += "_"
		else:
			display_text += " "
	elif slot1_value == "":
		display_text += "_"  # Static underscore placeholder when empty and not active
	
	current_problem_label.text = display_text

func create_fraction_problem():
	"""Create a fraction-type problem display with fractions, operator, equals sign, and answer area"""
	if not QuestionManager.current_question or not QuestionManager.is_fraction_display_type(QuestionManager.current_question.get("type", "")):
		return
	
	# Clean up any existing problem nodes
	cleanup_problem_labels()
	
	# Parse operands from the question
	# For mixed fraction problems, operands may not be in array format, so parse from expression
	var operand1_data = null
	var operand2_data = null
	
	# First check if operands array exists and has valid data
	var has_valid_operands = (QuestionManager.current_question.has("operands") and 
							   QuestionManager.current_question.operands != null and 
							   QuestionManager.current_question.operands.size() >= 2 and
							   QuestionManager.current_question.operands[0] != null)
	
	if has_valid_operands:
		var operand1 = QuestionManager.current_question.operands[0]
		var operand2 = QuestionManager.current_question.operands[1]
		
		# Handle each operand individually (could be array or number)
		if typeof(operand1) == TYPE_ARRAY and operand1.size() >= 2:
			# Fraction format [num, denom]
			operand1_data = [0, int(operand1[0]), int(operand1[1])]
		elif typeof(operand1) == TYPE_FLOAT or typeof(operand1) == TYPE_INT:
			# Whole number - display as numerator with denominator 1 (will show as "6/1")
			operand1_data = [0, int(operand1), 1]
		
		if typeof(operand2) == TYPE_ARRAY and operand2.size() >= 2:
			# Fraction format [num, denom]
			operand2_data = [0, int(operand2[0]), int(operand2[1])]
		elif typeof(operand2) == TYPE_FLOAT or typeof(operand2) == TYPE_INT:
			# Whole number - display as numerator with denominator 1 (will show as "6/1")
			operand2_data = [0, int(operand2), 1]
	
	# If we don't have valid operands, parse from expression (for mixed fractions)
	if operand1_data == null or operand2_data == null:
		var expr = QuestionManager.current_question.get("expression", "")
		if expr != "":
			var expr_parts = expr.split(" = ")[0].split(" ")
			# Find operator position
			var operator_idx = -1
			for i in range(expr_parts.size()):
				if expr_parts[i] == QuestionManager.current_question.operator:
					operator_idx = i
					break
			
			if operator_idx > 0:
				# Parse operand1 (everything before operator)
				var operand1_str = ""
				for i in range(operator_idx):
					if operand1_str != "":
						operand1_str += " "
					operand1_str += expr_parts[i]
				operand1_data = parse_mixed_fraction_from_string(operand1_str)
				
				# Parse operand2 (everything after operator)
				var operand2_str = ""
				for i in range(operator_idx + 1, expr_parts.size()):
					if operand2_str != "":
						operand2_str += " "
					operand2_str += expr_parts[i]
				operand2_data = parse_mixed_fraction_from_string(operand2_str)
	
	if operand1_data == null or operand2_data == null:
		print("Error: Could not parse fraction operands")
		return
	
	# Calculate horizontal positions for the final layout
	# Start with offset from primary position to center the whole expression
	var base_x = GameConfig.primary_position.x + GameConfig.fraction_problem_x_offset
	var target_y = GameConfig.primary_position.y
	var start_y = GameConfig.off_screen_bottom.y  # Start off-screen at bottom
	
	# Create fractions temporarily to measure their widths
	# operand_data format: [whole, numerator, denominator]
	var fraction1 = create_fraction(Vector2(0, 0), operand1_data[1], operand1_data[2], play_node)
	if operand1_data[0] > 0:
		fraction1.set_mixed_fraction(operand1_data[0], operand1_data[1], operand1_data[2])
	
	var fraction2 = create_fraction(Vector2(0, 0), operand2_data[1], operand2_data[2], play_node)
	if operand2_data[0] > 0:
		fraction2.set_mixed_fraction(operand2_data[0], operand2_data[1], operand2_data[2])
	
	# Get the actual widths of the fractions (use total width for mixed fractions)
	var fraction1_width = fraction1.current_total_width if fraction1.is_mixed_fraction else fraction1.current_divisor_width
	var fraction2_width = fraction2.current_total_width if fraction2.is_mixed_fraction else fraction2.current_divisor_width
	var fraction1_half_width = fraction1_width / 2.0
	var fraction2_half_width = fraction2_width / 2.0
	
	# Position the equals sign at a fixed location relative to base_x
	# This ensures the equals sign is always in the same position
	var equals_x = base_x + 672.0  # Fixed position for equals sign (adjust as needed)
	
	# Work backwards from equals sign to position fraction2
	# Each fraction takes up: fraction_element_spacing + its half width on each side
	var fraction2_x = equals_x - GameConfig.fraction_element_spacing - fraction2_half_width
	
	# Position operator between fraction2 and fraction1
	var operator_x = fraction2_x - fraction2_half_width - GameConfig.fraction_element_spacing
	
	# Position fraction1
	var fraction1_x = operator_x - GameConfig.fraction_element_spacing - fraction1_half_width
	
	# Position answer area after equals sign
	var answer_x = equals_x + GameConfig.fraction_element_spacing + GameConfig.fraction_answer_offset
	var answer_number_x = answer_x + GameConfig.fraction_answer_number_offset  # Position for non-fractionalized answer
	
	# Check if problem extends too far left and adjust if necessary
	var leftmost_x = fraction1_x - fraction1_half_width
	if leftmost_x < GameConfig.fraction_problem_min_x:
		var x_offset = GameConfig.fraction_problem_min_x - leftmost_x
		# Shift all x positions rightward
		fraction1_x += x_offset
		operator_x += x_offset
		fraction2_x += x_offset
		equals_x += x_offset
		answer_x += x_offset
		answer_number_x += x_offset
	
	# Now position all the fractions at their calculated positions (off-screen initially)
	fraction1.position = Vector2(fraction1_x, start_y) + GameConfig.fraction_offset
	fraction2.position = Vector2(fraction2_x, start_y) + GameConfig.fraction_offset
	fraction1.z_index = -1  # Render behind UI elements
	fraction2.z_index = -1  # Render behind UI elements
	current_problem_nodes.append(fraction1)
	current_problem_nodes.append(fraction2)
	
	# Create operator label (+, -, etc.) - child of first fraction so it moves with it
	var operator_label = Label.new()
	operator_label.label_settings = label_settings_resource
	operator_label.text = QuestionManager.get_display_operator(QuestionManager.current_question.operator)
	operator_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	operator_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	operator_label.self_modulate = Color(1, 1, 1)
	operator_label.z_index = -1  # Render behind UI elements
	# Position relative to fraction1
	var op_offset = GameConfig.operator_offset
	# Apply simple operator offset for multiplication/division operators (both unicode and ASCII)
	var op_text = QuestionManager.current_question.operator
	if op_text == "×" or op_text == "÷" or op_text == "x" or op_text == "/":
		op_offset += GameConfig.simple_operator_offset
	operator_label.position = Vector2(operator_x - fraction1_x, 0) + op_offset - GameConfig.fraction_offset
	fraction1.add_child(operator_label)
	current_problem_nodes.append(operator_label)
	
	# Create equals label - child of second fraction so it moves with it
	var equals_label = Label.new()
	equals_label.label_settings = label_settings_resource
	equals_label.text = "="
	equals_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	equals_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	equals_label.self_modulate = Color(1, 1, 1)
	equals_label.z_index = -1  # Render behind UI elements
	# Position relative to fraction2
	equals_label.position = Vector2(equals_x - fraction2_x, 0) + GameConfig.operator_offset - GameConfig.fraction_offset
	fraction2.add_child(equals_label)
	current_problem_nodes.append(equals_label)
	
	# Create answer label (will show underscore or typed number before fraction mode)
	current_problem_label = Label.new()
	current_problem_label.label_settings = label_settings_resource
	current_problem_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	current_problem_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	current_problem_label.position = Vector2(answer_number_x, start_y) + GameConfig.operator_offset  # Use number position
	current_problem_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	current_problem_label.self_modulate = Color(1, 1, 1)
	current_problem_label.z_index = -1  # Render behind UI elements
	play_node.add_child(current_problem_label)
	current_problem_nodes.append(current_problem_label)
	
	# Calculate target positions
	var fraction1_target = Vector2(fraction1_x, target_y) + GameConfig.fraction_offset
	var fraction2_target = Vector2(fraction2_x, target_y) + GameConfig.fraction_offset
	var answer_target = Vector2(answer_number_x, target_y) + GameConfig.operator_offset  # Use number position
	
	# Animate all elements to their target positions
	# Note: operator_label and equals_label are children of fractions, so they move automatically
	var tween = create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_EXPO)
	tween.set_parallel(true)  # Animate all elements simultaneously
	tween.tween_property(fraction1, "position", fraction1_target, GameConfig.animation_duration)
	tween.tween_property(fraction2, "position", fraction2_target, GameConfig.animation_duration)
	tween.tween_property(current_problem_label, "position", answer_target, GameConfig.animation_duration)
	
	# Exit parallel mode before adding callback so it runs AFTER animations complete
	tween.set_parallel(false)
	
	# Start timing this question when animation completes
	tween.tween_callback(ScoreManager.start_question_timing)
	
	# Create prompt label at the end (after nodes are added to current_problem_nodes)
	create_prompt_label()
	
	# Note: answer_fraction_node will be created when user presses Divide

func create_equivalence_problem():
	"""Create an equivalence problem display (e.g., 6/11 = 24/44) with one field locked for user input"""
	if not QuestionManager.current_question or QuestionManager.current_question.get("type", "") != "Equivalence (4.NF.A)":
		return
	
	# Clean up any existing problem nodes
	cleanup_problem_labels()
	
	# Parse the expression to get both fractions (e.g., "6/11 = 24/44")
	var expr = QuestionManager.current_question.get("expression", "")
	if expr == "":
		print("Error: No expression for equivalence problem")
		return
	
	var parts = expr.split(" = ")
	if parts.size() != 2:
		print("Error: Invalid equivalence expression format")
		return
	
	# Parse left fraction (complete)
	var left_fraction_data = parse_mixed_fraction_from_string(parts[0])
	# Parse right fraction (will have one field editable)
	var right_fraction_data = parse_mixed_fraction_from_string(parts[1])
	
	# Randomly decide which field the user needs to fill in (50/50 chance)
	var rng = RandomNumberGenerator.new()
	rng.randomize()
	var edit_numerator = (rng.randi() % 2 == 0)
	
	# Store the correct answer for validation
	if edit_numerator:
		QuestionManager.current_question.result = str(right_fraction_data[1])  # numerator
	else:
		QuestionManager.current_question.result = str(right_fraction_data[2])  # denominator
	
	# Calculate horizontal positions
	var target_y = GameConfig.primary_position.y
	var start_y = GameConfig.off_screen_bottom.y
	
	# Create left fraction (complete, non-editable)
	var left_fraction = create_fraction(Vector2(0, 0), left_fraction_data[1], left_fraction_data[2], play_node)
	
	# Create right fraction (one field locked, one editable)
	var right_fraction = create_fraction(Vector2(0, 0), right_fraction_data[1], right_fraction_data[2], play_node)
	
	# Get actual widths
	var left_fraction_width = left_fraction.current_divisor_width
	var right_fraction_width = right_fraction.current_divisor_width
	var left_fraction_half_width = left_fraction_width / 2.0
	var right_fraction_half_width = right_fraction_width / 2.0
	
	# Measure equals sign width to center it properly
	var temp_equals = Label.new()
	temp_equals.label_settings = label_settings_resource
	temp_equals.text = "="
	temp_equals.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	play_node.add_child(temp_equals)
	temp_equals.reset_size()
	var equals_width = temp_equals.get_minimum_size().x
	temp_equals.queue_free()
	
	# Position equals sign so its CENTER is at the horizontal center of the screen (960 = 1920 / 2)
	# Offset by half the equals sign width to the left
	var equals_x = 960.0 - (equals_width / 2.0)
	
	# Work backwards from equals sign to position right fraction
	var right_fraction_x = equals_x + GameConfig.fraction_element_spacing + right_fraction_half_width
	
	# Position left fraction to the left of equals sign
	var left_fraction_x = equals_x - GameConfig.fraction_element_spacing - left_fraction_half_width
	
	# Check if problem extends too far left and adjust if necessary
	var leftmost_x = left_fraction_x - left_fraction_half_width
	if leftmost_x < GameConfig.fraction_problem_min_x:
		var x_offset = GameConfig.fraction_problem_min_x - leftmost_x
		left_fraction_x += x_offset
		equals_x += x_offset
		right_fraction_x += x_offset
	
	# Position fractions (off-screen initially)
	left_fraction.position = Vector2(left_fraction_x, start_y) + GameConfig.fraction_offset
	right_fraction.position = Vector2(right_fraction_x, start_y) + GameConfig.fraction_offset
	left_fraction.z_index = -1
	right_fraction.z_index = -1
	current_problem_nodes.append(left_fraction)
	current_problem_nodes.append(right_fraction)
	
	# Set up right fraction in locked input mode
	right_fraction.set_locked_input_mode(edit_numerator, str(right_fraction_data[1]), str(right_fraction_data[2]))
	answer_fraction_node = right_fraction  # Store reference for input handling
	
	# Store initial position and width for dynamic positioning (though locked mode doesn't need it as much)
	answer_fraction_base_x = right_fraction.position.x
	answer_fraction_initial_width = right_fraction.current_divisor_width
	
	# Create equals label - child of left fraction so it moves with it
	var equals_label = Label.new()
	equals_label.label_settings = label_settings_resource
	equals_label.text = "="
	equals_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	equals_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	equals_label.self_modulate = Color(1, 1, 1)
	equals_label.z_index = -1
	# Position relative to left_fraction
	equals_label.position = Vector2(equals_x - left_fraction_x, 0) + GameConfig.operator_offset - GameConfig.fraction_offset
	left_fraction.add_child(equals_label)
	current_problem_nodes.append(equals_label)
	
	# Calculate target positions
	var left_fraction_target = Vector2(left_fraction_x, target_y) + GameConfig.fraction_offset
	var right_fraction_target = Vector2(right_fraction_x, target_y) + GameConfig.fraction_offset
	
	# Animate both fractions to their target positions
	var tween = create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_EXPO)
	tween.set_parallel(true)
	tween.tween_property(left_fraction, "position", left_fraction_target, GameConfig.animation_duration)
	tween.tween_property(right_fraction, "position", right_fraction_target, GameConfig.animation_duration)
	
	# Exit parallel mode before adding callback
	tween.set_parallel(false)
	
	# Start timing this question when animation completes
	tween.tween_callback(ScoreManager.start_question_timing)
	
	# Create prompt label at the end (after nodes are added to current_problem_nodes)
	create_prompt_label()

func create_fraction_conversion_problem():
	"""Create a fraction conversion problem display (mixed to improper or improper to mixed)"""
	if not QuestionManager.current_question or not QuestionManager.is_fraction_conversion_display_type(QuestionManager.current_question.get("type", "")):
		return
	
	# Clean up any existing problem nodes
	cleanup_problem_labels()
	
	var problem_type = QuestionManager.current_question.get("type", "")
	var operands = QuestionManager.current_question.get("operands", [])
	
	if operands.size() < 1:
		print("Error: Conversion problem requires at least 1 operand")
		return
	
	var operand = operands[0]
	
	# Calculate positions
	var base_x = GameConfig.primary_position.x + GameConfig.fraction_problem_x_offset
	var target_y = GameConfig.primary_position.y
	var start_y = GameConfig.off_screen_bottom.y
	
	# Create the source fraction/mixed number
	var source_fraction: Node
	
	if problem_type == "mixed_to_improper":
		# Display mixed number
		source_fraction = create_fraction(Vector2(0, 0), operand.numerator, operand.denominator, play_node)
		source_fraction.set_mixed_fraction(operand.whole, operand.numerator, operand.denominator)
	else:  # improper_to_mixed
		# Display improper fraction
		source_fraction = create_fraction(Vector2(0, 0), operand.numerator, operand.denominator, play_node)
	
	# Get width of source fraction
	var source_width = source_fraction.current_total_width if source_fraction.is_mixed_fraction else source_fraction.current_divisor_width
	var source_half_width = source_width / 2.0
	
	# Position source fraction
	var source_x = base_x + 200.0  # Position to the left
	
	# Position equals sign
	var equals_x = source_x + source_half_width + GameConfig.fraction_element_spacing + 48.0
	
	# Position answer area
	var answer_x = equals_x + GameConfig.fraction_element_spacing + GameConfig.fraction_answer_offset
	var answer_number_x = answer_x + GameConfig.fraction_answer_number_offset
	
	# Position source fraction (off-screen initially)
	source_fraction.position = Vector2(source_x, start_y) + GameConfig.fraction_offset
	source_fraction.z_index = -1
	current_problem_nodes.append(source_fraction)
	
	# Create equals label - child of source fraction so it moves with it
	var equals_label = Label.new()
	equals_label.label_settings = label_settings_resource
	equals_label.text = "="
	equals_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	equals_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	equals_label.self_modulate = Color(1, 1, 1)
	equals_label.z_index = -1
	equals_label.position = Vector2(equals_x - source_x, 0) + GameConfig.operator_offset - GameConfig.fraction_offset
	source_fraction.add_child(equals_label)
	current_problem_nodes.append(equals_label)
	
	# Create answer label (will show underscore or typed number before fraction mode)
	current_problem_label = Label.new()
	current_problem_label.label_settings = label_settings_resource
	current_problem_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	current_problem_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	current_problem_label.position = Vector2(answer_number_x, start_y) + GameConfig.operator_offset
	current_problem_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	current_problem_label.self_modulate = Color(1, 1, 1)
	current_problem_label.z_index = -1
	play_node.add_child(current_problem_label)
	current_problem_nodes.append(current_problem_label)
	
	# Calculate target positions
	var source_target = Vector2(source_x, target_y) + GameConfig.fraction_offset
	var answer_target = Vector2(answer_number_x, target_y) + GameConfig.operator_offset
	
	# Animate all elements to their target positions
	var tween = create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_EXPO)
	tween.set_parallel(true)
	tween.tween_property(source_fraction, "position", source_target, GameConfig.animation_duration)
	tween.tween_property(current_problem_label, "position", answer_target, GameConfig.animation_duration)
	
	# Exit parallel mode before adding callback
	tween.set_parallel(false)

	# Start timing this question when animation completes
	tween.tween_callback(ScoreManager.start_question_timing)
	
	# Create prompt label at the end (after nodes are added to current_problem_nodes)
	create_prompt_label()

func create_number_line_problem():
	"""Create a number line problem display with fraction label above"""
	if not QuestionManager.current_question or not QuestionManager.is_number_line_display_type(QuestionManager.current_question.get("type", "")):
		return
	
	# Clean up any existing problem nodes
	cleanup_problem_labels()
	
	# Get question data
	var operands = QuestionManager.current_question.get("operands", [])
	if operands.size() < 1:
		print("Error: Number line problem requires at least 1 operand")
		return
	
	var operand = operands[0]
	var numerator = operand.numerator
	var denominator = operand.denominator
	var whole_number = operand.get("whole", 0)  # For mixed numbers
	var correct_pip = QuestionManager.current_question.get("correct_pip", 0)
	var correct_value = QuestionManager.current_question.get("correct_value", 0.0)
	var total_pips = QuestionManager.current_question.get("total_pips", 9)
	var lower_limit = QuestionManager.current_question.get("lower_limit", 0)
	var upper_limit = QuestionManager.current_question.get("upper_limit", 1)
	var frame_idx = QuestionManager.current_question.get("frame", 0)
	var control_mode = QuestionManager.current_question.get("control_mode", "pip_to_pip")
	
	# Calculate positions (with y offset to make room for prompt label)
	var y_offset = GameConfig.number_line_y_offset
	var final_position = GameConfig.number_line_final_position + Vector2(0, y_offset)
	var fraction_position = GameConfig.number_line_fraction_position + Vector2(0, y_offset)
	var start_offset = 1080.0  # Start 1080 pixels above final position
	
	var number_line_start_y = final_position.y - start_offset
	var fraction_start_y = fraction_position.y - start_offset
	
	# Load and instantiate the number line scene
	var number_line_scene = load("res://scenes/number_line.tscn")
	var number_line_instance = number_line_scene.instantiate()
	
	# Set initial position (off-screen above)
	number_line_instance.position = Vector2(final_position.x, number_line_start_y)
	number_line_instance.z_index = -1
	
	# Add to play node
	play_node.add_child(number_line_instance)
	
	# Initialize the number line with configuration
	number_line_instance.initialize({
		"total_pips": total_pips,
		"lower_limit": lower_limit,
		"upper_limit": upper_limit,
		"frame": frame_idx,
		"control_mode": control_mode
	})
	
	# Set correct answer based on control mode
	if control_mode == "continuous":
		number_line_instance.set_correct_value(correct_value)
	else:
		number_line_instance.set_correct_pip(correct_pip)
	
	# Store reference
	current_number_line = number_line_instance
	current_problem_nodes.append(number_line_instance)
	
	# Create fraction label above the number line
	var fraction_node = create_fraction(Vector2(fraction_position.x, fraction_start_y), numerator, denominator, play_node)
	
	# Set as mixed fraction if there's a whole number component
	if whole_number > 0:
		fraction_node.set_mixed_fraction(whole_number, numerator, denominator)
	
	fraction_node.z_index = -1
	number_line_fraction_label = fraction_node
	current_problem_nodes.append(fraction_node)
	
	# Animate both elements to their final positions
	var tween = create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_EXPO)
	tween.set_parallel(true)
	
	# Animate number line
	tween.tween_property(number_line_instance, "position", final_position, GameConfig.animation_duration)
	
	# Animate fraction label
	tween.tween_property(fraction_node, "position", fraction_position, GameConfig.animation_duration)
	
	tween.set_parallel(false)
	
	# Start timing when animation completes
	tween.tween_callback(ScoreManager.start_question_timing)
	
	# Create prompt label at the end (after nodes are added to current_problem_nodes)
	create_prompt_label()

func show_number_line_correct_feedback():
	"""Show correct feedback for number line question"""
	if current_number_line:
		current_number_line.show_correct_feedback()
	if number_line_fraction_label:
		number_line_fraction_label.modulate = GameConfig.color_correct

func show_number_line_incorrect_feedback():
	"""Show incorrect feedback for number line question"""
	if current_number_line:
		current_number_line.show_incorrect_feedback()
	if number_line_fraction_label:
		number_line_fraction_label.modulate = GameConfig.color_incorrect

func create_multiple_choice_problem():
	"""Create a multiple choice problem display (handles all comparison question types)"""
	if not QuestionManager.current_question or not QuestionManager.is_multiple_choice_display_type(QuestionManager.current_question.get("type", "")):
		return
	
	# Clean up any existing problem nodes
	cleanup_problem_labels()
	
	# Reset multiple choice state
	multiple_choice_buttons.clear()
	multiple_choice_answered = false
	multiple_choice_correct_index = -1
	
	var question_type = QuestionManager.current_question.get("type", "")
	var correct_answer = QuestionManager.current_question.result
	
	# Get answer choices (dynamically sized based on question type)
	var answer_choices = QuestionManager.get_multiple_choice_answers(QuestionManager.current_question)
	
	# Find correct answer index
	for i in range(answer_choices.size()):
		if answer_choices[i] == correct_answer:
			multiple_choice_correct_index = i
			break
	
	# Calculate screen center and positions
	var center_x = 960.0
	var center_y = 540.0
	var target_y_prompt = center_y + GameConfig.multiple_choice_prompt_y_offset
	var target_y_answers = center_y + GameConfig.multiple_choice_answers_y_offset
	var common_start_y = GameConfig.off_screen_bottom.y
	var prompt_delta_y = target_y_prompt - common_start_y
	var answers_delta_y = target_y_answers - common_start_y
	var start_y_prompt = common_start_y
	var start_y_answers = common_start_y + (answers_delta_y - prompt_delta_y)
	
	# Variables for the operand display nodes
	var left_node: Node
	var right_node: Node
	var left_width: float
	var right_width: float
	var is_fraction_display = false  # Whether left/right are fraction nodes
	
	# Check what type of operand display we need
	if question_type == "expression_comparison_20":
		# Expression comparison - use labels with expression text (e.g., "19 + 1")
		var operands = QuestionManager.current_question.get("operands", [])
		if operands.size() < 2:
			print("Error: Expression comparison requires 2 operands")
			return
		
		var expr1 = operands[0]
		var expr2 = operands[1]
		
		left_node = Label.new()
		left_node.label_settings = label_settings_resource
		left_node.text = str(expr1.a) + " " + expr1.op + " " + str(expr1.b)
		left_node.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		left_node.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		play_node.add_child(left_node)
		left_node.reset_size()
		left_width = left_node.get_minimum_size().x
		
		right_node = Label.new()
		right_node.label_settings = label_settings_resource
		right_node.text = str(expr2.a) + " " + expr2.op + " " + str(expr2.b)
		right_node.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		right_node.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		play_node.add_child(right_node)
		right_node.reset_size()
		right_width = right_node.get_minimum_size().x
		
	elif question_type == "decimal_comparison":
		# Decimal comparison - use labels with decimal operands
		var operands = QuestionManager.current_question.get("operands", [])
		if operands.size() < 2:
			print("Error: Decimal comparison requires 2 operands")
			return
		
		left_node = Label.new()
		left_node.label_settings = label_settings_resource
		left_node.text = str(operands[0])
		left_node.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		left_node.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		play_node.add_child(left_node)
		left_node.reset_size()
		left_width = left_node.get_minimum_size().x
		
		right_node = Label.new()
		right_node.label_settings = label_settings_resource
		right_node.text = str(operands[1])
		right_node.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		right_node.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		play_node.add_child(right_node)
		right_node.reset_size()
		right_width = right_node.get_minimum_size().x
		
	elif question_type == "fraction_comparison":
		# New fraction comparison - use operands array with dict format
		var operands = QuestionManager.current_question.get("operands", [])
		if operands.size() < 2:
			print("Error: Fraction comparison requires 2 operands")
			return
		
		var left_data = operands[0]
		var right_data = operands[1]
		
		left_node = create_fraction(Vector2(0, 0), left_data.numerator, left_data.denominator, play_node)
		right_node = create_fraction(Vector2(0, 0), right_data.numerator, right_data.denominator, play_node)
		
		left_width = left_node.current_divisor_width
		right_width = right_node.current_divisor_width
		is_fraction_display = true
		
	else:
		# Legacy fraction comparison - parse from expression string
		var expr = QuestionManager.current_question.get("expression", "")
		if expr == "":
			print("Error: No expression for multiple choice problem")
			return
		
		var prompt_expr = expr.split(" = ")[0]
		var parts = prompt_expr.split(" ? ")
		if parts.size() != 2:
			print("Error: Invalid multiple choice expression format")
			return
		
		var left_fraction_data = parse_mixed_fraction_from_string(parts[0])
		var right_fraction_data = parse_mixed_fraction_from_string(parts[1])
		
		left_node = create_fraction(Vector2(0, 0), left_fraction_data[1], left_fraction_data[2], play_node)
		right_node = create_fraction(Vector2(0, 0), right_fraction_data[1], right_fraction_data[2], play_node)
		
		left_width = left_node.current_divisor_width
		right_width = right_node.current_divisor_width
		is_fraction_display = true
	
	# Create "?" label first so we can measure its actual size
	var question_mark_label = Label.new()
	question_mark_label.label_settings = label_settings_resource
	question_mark_label.text = "?"
	question_mark_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	question_mark_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	question_mark_label.self_modulate = Color(0.75, 0.75, 0.75)
	question_mark_label.z_index = -1
	play_node.add_child(question_mark_label)
	question_mark_label.reset_size()
	var question_mark_width = question_mark_label.size.x
	
	# Calculate expression layout - center the "?" with equal spacing on both sides
	# Question mark is centered at center_x
	var question_mark_x = center_x + GameConfig.multiple_choice_prompt_x_offset
	
	# Calculate "?" position (left edge, so center is at question_mark_x)
	var qmark_left_edge = question_mark_x - (question_mark_width / 2.0)
	var qmark_right_edge = question_mark_x + (question_mark_width / 2.0)
	
	# Left operand: right edge should be at qmark_left_edge - spacing
	var left_right_edge = qmark_left_edge - GameConfig.multiple_choice_element_spacing
	var left_left_edge = left_right_edge - left_width
	
	# Right operand: left edge should be at qmark_right_edge + spacing  
	var right_left_edge = qmark_right_edge + GameConfig.multiple_choice_element_spacing
	
	# Position operand nodes (off-screen initially)
	if is_fraction_display:
		# For fractions, position is the center
		# Only use y component of fraction_offset since we've calculated correct x positions
		var left_center = left_left_edge + (left_width / 2.0)
		var right_center = right_left_edge + (right_width / 2.0)
		left_node.position = Vector2(left_center, start_y_prompt + GameConfig.fraction_offset.y)
		right_node.position = Vector2(right_center, start_y_prompt + GameConfig.fraction_offset.y)
	else:
		# For labels, position is the left edge
		left_node.position = Vector2(left_left_edge, start_y_prompt - 64)
		right_node.position = Vector2(right_left_edge, start_y_prompt - 64)
	
	left_node.z_index = -1
	right_node.z_index = -1
	current_problem_nodes.append(left_node)
	current_problem_nodes.append(right_node)
	
	# Position "?" label
	if is_fraction_display:
		# Position relative to left fraction for fraction display
		# Only subtract y component of fraction_offset since we're not using x
		var left_center = left_left_edge + (left_width / 2.0)
		question_mark_label.position = Vector2(qmark_left_edge - left_center, 0) + GameConfig.operator_offset - Vector2(0, GameConfig.fraction_offset.y)
		question_mark_label.get_parent().remove_child(question_mark_label)
		left_node.add_child(question_mark_label)
	else:
		# Position at calculated left edge
		question_mark_label.position = Vector2(qmark_left_edge, start_y_prompt - 64)
	current_problem_nodes.append(question_mark_label)
	
	# Create answer buttons
	var button_scene = load("res://scenes/answer_button.tscn")
	var total_buttons_width = 0.0
	var button_instances = []
	
	for i in range(answer_choices.size()):
		var button_instance = button_scene.instantiate()
		button_instance.visible = false
		play_node.add_child(button_instance)
		
		var answer_label = button_instance.get_node("Answer")
		answer_label.text = answer_choices[i]
		
		var key_label = button_instance.get_node("Key")
		if i < GameConfig.multiple_choice_keybind_labels.size():
			key_label.text = GameConfig.multiple_choice_keybind_labels[i]
		
		button_instance.reset_size()
		var button_width = max(button_instance.size.x, GameConfig.multiple_choice_button_min_size.x)
		var button_height = max(button_instance.size.y, GameConfig.multiple_choice_button_min_size.y)
		button_instance.custom_minimum_size = Vector2(button_width, button_height)
		answer_label.offset_right = answer_label.offset_left + button_width
		answer_label.offset_bottom = button_height
		
		total_buttons_width += button_width
		button_instances.append(button_instance)
	
	total_buttons_width += GameConfig.multiple_choice_button_spacing * (answer_choices.size() - 1)
	var buttons_start_x = center_x - (total_buttons_width / 2.0) + GameConfig.multiple_choice_button_x_offset
	var current_x = buttons_start_x
	
	for i in range(button_instances.size()):
		var button_instance = button_instances[i]
		var button_width = button_instance.custom_minimum_size.x
		button_instance.position = Vector2(current_x, start_y_answers)
		button_instance.visible = true
		button_instance.z_index = -1
		
		var answer_index = i
		button_instance.pressed.connect(_on_multiple_choice_answer_selected.bind(answer_index))
		
		multiple_choice_buttons.append(button_instance)
		current_problem_nodes.append(button_instance)
		current_x += button_width + GameConfig.multiple_choice_button_spacing
	
	# Calculate target positions
	var left_target: Vector2
	var right_target: Vector2
	var qmark_target: Vector2
	
	if is_fraction_display:
		# Only use y component of fraction_offset since we've calculated correct x positions
		var left_center = left_left_edge + (left_width / 2.0)
		var right_center = right_left_edge + (right_width / 2.0)
		left_target = Vector2(left_center, target_y_prompt + GameConfig.fraction_offset.y)
		right_target = Vector2(right_center, target_y_prompt + GameConfig.fraction_offset.y)
	else:
		left_target = Vector2(left_left_edge, target_y_prompt - 64)
		right_target = Vector2(right_left_edge, target_y_prompt - 64)
		qmark_target = Vector2(qmark_left_edge, target_y_prompt - 64)
	
	# Animate all elements
	var tween = create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_EXPO)
	tween.set_parallel(true)
	
	tween.tween_property(left_node, "position", left_target, GameConfig.animation_duration)
	tween.tween_property(right_node, "position", right_target, GameConfig.animation_duration)
	
	if not is_fraction_display:
		tween.tween_property(question_mark_label, "position", qmark_target, GameConfig.animation_duration)
	
	# Animate buttons
	current_x = buttons_start_x
	for button_instance in button_instances:
		var button_target = Vector2(current_x, target_y_answers)
		tween.tween_property(button_instance, "position", button_target, GameConfig.animation_duration)
		current_x += button_instance.custom_minimum_size.x + GameConfig.multiple_choice_button_spacing
	
	tween.set_parallel(false)
	tween.tween_callback(ScoreManager.start_question_timing)
	
	# Create prompt label at the end (after nodes are added to current_problem_nodes)
	create_prompt_label()

func _on_multiple_choice_answer_selected(answer_index: int):
	"""Handle multiple choice answer button press"""
	# Ignore if already answered
	if multiple_choice_answered:
		return
	
	multiple_choice_answered = true
	
	# Mark as submitted to prevent further input (mirrors normal question flow)
	StateManager.answer_submitted = true
	
	# Check if answer is correct
	var is_correct = (answer_index == multiple_choice_correct_index)
	
	# Get the clicked button
	var clicked_button = multiple_choice_buttons[answer_index]
	
	# Calculate time taken for this question
	var question_time = 0.0
	if ScoreManager.current_question_start_time > 0:
		question_time = (Time.get_ticks_msec() / 1000.0) - ScoreManager.current_question_start_time
	
	# Get player answer value
	var answer_choices = QuestionManager.get_multiple_choice_answers(QuestionManager.current_question)
	var player_answer = answer_choices[answer_index]
	
	# Save question data
	if QuestionManager.current_question:
		SaveManager.save_question_data(QuestionManager.current_question, player_answer, question_time)
	
	# Track correct answers and drill mode scoring
	if StateManager.is_drill_mode:
		ScoreManager.drill_total_answered += 1
	
	# Declare timer state variables at function level to avoid scope warnings
	var timer_was_active = ScoreManager.timer_active
	var should_start_timer = false
	
	var points_earned = 0
	if is_correct:
		points_earned = ScoreManager.process_correct_answer(StateManager.is_drill_mode, QuestionManager.current_question)
		if StateManager.is_drill_mode and points_earned > 0:
			# Trigger score animations
			UIManager.create_flying_score_label(points_earned)
			UIManager.animate_drill_score_scale()
	else:
		ScoreManager.process_incorrect_answer(StateManager.is_drill_mode)
	
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
		print("[Assessment] Multiple choice answer submitted: ", "correct" if is_correct else "incorrect")
	else:
		# Color the buttons
		if is_correct:
			# Color clicked button green
			clicked_button.modulate = GameConfig.color_correct
		else:
			# Color clicked button red
			clicked_button.modulate = GameConfig.color_incorrect
			# Color correct button dark green
			var correct_button = multiple_choice_buttons[multiple_choice_correct_index]
			correct_button.modulate = GameConfig.color_correct_feedback
		
		# Play sounds and show feedback (mirrors normal question flow)
		if is_correct:
			AudioManager.play_correct()
			UIManager.show_feedback_flash(GameConfig.color_correct)
		else:
			AudioManager.play_incorrect()
			UIManager.show_feedback_flash(GameConfig.color_incorrect)
			
			# Pause TimeBack activity timer while showing correct answer (instructional moment)
			PlaycademyManager.pause_timeback_activity()
	
	# Wait for the full transition delay (timer remains paused during this time)
	if delay_to_use > 0.0:
		await get_tree().create_timer(delay_to_use).timeout
	
	# Clear transition delay flag
	StateManager.in_transition_delay = false
	
	# If incorrect and require_submit_after_incorrect is true, wait for player to press Submit to continue
	if not is_correct and GameConfig.require_submit_after_incorrect and not StateManager.is_assessment_mode:
		StateManager.waiting_for_continue_after_incorrect = true
		# Store timer state for later restoration (mirrors normal question flow)
		StateManager.set_meta("timer_was_active", timer_was_active)
		StateManager.set_meta("should_start_timer", should_start_timer)
		return  # Wait for player to press Submit to continue
	
	# Continue immediately if correct or if require_submit_after_incorrect is false
	continue_after_multiple_choice_incorrect(is_correct, timer_was_active, should_start_timer)

func continue_after_multiple_choice_incorrect(is_correct: bool, timer_was_active: bool, should_start_timer: bool):
	"""Continue after multiple choice answer (called after delay and potentially after user presses Submit)"""
	# Resume TimeBack activity timer if it was paused (only after incorrect answers)
	if not is_correct:
		PlaycademyManager.resume_timeback_activity()
	
	# Trigger scroll speed boost effect after transition delay
	var space_bg = play_node.get_parent().get_node("BackgroundLayer/SpaceBackground")
	if space_bg and space_bg.has_method("boost_scroll_speed"):
		space_bg.boost_scroll_speed(GameConfig.scroll_boost_multiplier, GameConfig.animation_duration * 2.0)
	
	# Increment problems completed
	StateManager.problems_completed += 1
	
	# Animate progress line (only for non-drill mode, based on correct answers towards mastery_count)
	if not StateManager.is_drill_mode:
		if UIManager.progress_line and play_node:
			var max_value: int
			if StateManager.is_grade_level and StateManager.current_level_config:
				max_value = StateManager.current_level_config.mastery_count
			else:
				max_value = 20  # Fallback
			
			var play_width = play_node.size.x
			var progress = min(ScoreManager.correct_answers, max_value)
			var progress_increment = play_width / float(max_value)
			var new_x_position = progress_increment * progress
			
			# Animate progress line
			var progress_tween = create_tween()
			progress_tween.set_ease(Tween.EASE_OUT)
			progress_tween.set_trans(Tween.TRANS_EXPO)
			progress_tween.tween_method(UIManager.update_progress_line_point, UIManager.progress_line.get_point_position(1).x, new_x_position, GameConfig.animation_duration)
	
	# Handle assessment mode separately (has its own flow)
	if StateManager.is_assessment_mode:
		# Get the question time from when the answer was selected
		var question_time = 0.0
		if ScoreManager.current_question_start_time > 0:
			question_time = (Time.get_ticks_msec() / 1000.0) - ScoreManager.current_question_start_time
		
		# Subtract transition delay from time
		var adjusted_time = max(0.0, question_time - GameConfig.transition_delay)
		var result = ScoreManager.process_assessment_answer(is_correct, adjusted_time)
		
		if result.should_advance:
			# Check if assessment is complete or moving to next standard
			var has_more = ScoreManager.advance_to_next_standard()
			if not has_more:
				# Assessment complete!
				UIManager.hide_play_ui_for_level_complete()
				
				# Animate current problem off screen
				var complete_tween = create_tween()
				complete_tween.set_ease(Tween.EASE_OUT)
				complete_tween.set_trans(Tween.TRANS_EXPO)
				complete_tween.set_parallel(true)
				for node in current_problem_nodes:
					if node and node.get_parent() == play_node:
						var target_pos = node.position + Vector2(0, 1400)
						complete_tween.tween_property(node, "position", target_pos, GameConfig.animation_duration)
				complete_tween.set_parallel(false)
				complete_tween.tween_callback(StateManager.complete_assessment)
				return
			
			# Moving to next standard - clear used questions
			QuestionManager.used_questions_this_level.clear()
		
		# Store references to the nodes we're animating out
		var nodes_to_animate = current_problem_nodes.duplicate()
		
		# Clear current_problem_nodes immediately
		current_problem_nodes.clear()
		multiple_choice_buttons.clear()
		multiple_choice_answered = false
		multiple_choice_correct_index = -1
		
		# Reset state for new question
		StateManager.user_answer = ""
		StateManager.answer_submitted = false
		InputManager.reset_for_new_question()
		
		# Generate next assessment question
		StateManager._generate_next_assessment_question()
		create_new_problem_label()
		
		# Animate old problem off screen
		var tween = create_tween()
		tween.set_ease(Tween.EASE_OUT)
		tween.set_trans(Tween.TRANS_EXPO)
		tween.set_parallel(true)
		for node in nodes_to_animate:
			if node and node.get_parent() == play_node:
				var target_pos = node.position + Vector2(0, 1400)
				tween.tween_property(node, "position", target_pos, GameConfig.animation_duration)
		tween.set_parallel(false)
		tween.tween_callback(func():
			for node in nodes_to_animate:
				if node:
					node.queue_free()
		)
		return
	
	# Check if level is complete
	var level_complete = false
	if StateManager.is_drill_mode:
		# In drill mode, never end - just continue to next question
		level_complete = false
	elif StateManager.is_grade_level and StateManager.current_level_config:
		# Check for mastery completion (correct answers >= mastery_count with >= 85% accuracy)
		level_complete = ScoreManager.check_mastery_complete(StateManager.current_level_config.mastery_count)
	else:
		level_complete = false  # Legacy levels not using this code path
	
	# Schedule next question or game over
	if level_complete:
		# Hide all play UI elements when level completes
		UIManager.hide_play_ui_for_level_complete()
		
		# Animate current problem off screen DOWN
		var tween = create_tween()
		tween.set_ease(Tween.EASE_OUT)
		tween.set_trans(Tween.TRANS_EXPO)
		tween.set_parallel(true)
		for node in current_problem_nodes:
			if node and node.get_parent() == play_node:
				var target_pos = node.position + Vector2(0, 1400)
				tween.tween_property(node, "position", target_pos, GameConfig.animation_duration)
		tween.set_parallel(false)
		# Use appropriate game over function based on level type
		if StateManager.is_grade_level:
			tween.tween_callback(StateManager.go_to_grade_level_game_over)
		else:
			tween.tween_callback(StateManager.go_to_game_over)
	else:
		# Resume timer after transition delay or start it if grace period completed during transition
		if timer_was_active or should_start_timer:
			ScoreManager.timer_active = true
			# If timer should start now, mark it as started and record start time
			if should_start_timer and not ScoreManager.timer_started:
				ScoreManager.timer_started = true
				ScoreManager.level_start_time = Time.get_time_dict_from_system()["hour"] * 3600 + Time.get_time_dict_from_system()["minute"] * 60 + Time.get_time_dict_from_system()["second"]
		
		# Store references to the nodes we're animating out
		var nodes_to_animate = current_problem_nodes.duplicate()
		
		# Clear current_problem_nodes immediately so new problem can populate it
		current_problem_nodes.clear()
		multiple_choice_buttons.clear()
		multiple_choice_answered = false
		multiple_choice_correct_index = -1
		
		# Reset state for new question
		StateManager.user_answer = ""
		StateManager.answer_submitted = false
		InputManager.reset_for_new_question()
		
		# Generate new question immediately (starts flying in while old one flies out)
		QuestionManager.generate_new_question()
		create_new_problem_label()
		
		# Animate old problem off screen DOWN
		var tween = create_tween()
		tween.set_ease(Tween.EASE_OUT)
		tween.set_trans(Tween.TRANS_EXPO)
		tween.set_parallel(true)
		for node in nodes_to_animate:
			if node and node.get_parent() == play_node:
				var target_pos = node.position + Vector2(0, 1400)
				tween.tween_property(node, "position", target_pos, GameConfig.animation_duration)
		
		# Clean up old nodes when animation completes
		tween.set_parallel(false)
		tween.tween_callback(func():
			for node in nodes_to_animate:
				if node:
					node.queue_free()
		)

func create_answer_fraction():
	"""Create just the answer fraction visual when user presses Divide"""
	if answer_fraction_node:
		return  # Already exists
	
	# Use the position of the current_problem_label (the answer label) but apply fraction_offset
	var base_pos = current_problem_label.position if current_problem_label else GameConfig.primary_position
	# Subtract operator_offset and add fraction_offset to align with other fractions
	# Also subtract the number offset since we want the fraction at the normal fraction position
	var answer_pos = base_pos - GameConfig.operator_offset + GameConfig.fraction_offset - Vector2(GameConfig.fraction_answer_number_offset, 0)
	
	# Create the answer fraction at the aligned position
	answer_fraction_node = create_fraction(answer_pos, 0, 1, play_node)
	answer_fraction_node.set_input_mode(true)
	answer_fraction_node.z_index = -1  # Render behind UI elements
	current_problem_nodes.append(answer_fraction_node)
	
	# Store initial position and width for dynamic positioning
	answer_fraction_base_x = answer_pos.x
	answer_fraction_initial_width = answer_fraction_node.current_divisor_width
	
	# Hide the label since we're now using the fraction node
	if current_problem_label:
		current_problem_label.visible = false

func create_answer_mixed_fraction(user_answer: String):
	"""Create the answer mixed fraction visual when user presses Fraction"""
	if answer_fraction_node:
		return  # Already exists
	
	# Use the position of the current_problem_label (the answer label) but apply fraction_offset
	var base_pos = current_problem_label.position if current_problem_label else GameConfig.primary_position
	# Subtract operator_offset and add fraction_offset to align with other fractions
	# Also subtract the number offset since we want the fraction at the normal fraction position
	var answer_pos = base_pos - GameConfig.operator_offset + GameConfig.fraction_offset - Vector2(GameConfig.fraction_answer_number_offset, 0)
	
	# Parse the whole number from user_answer
	var parts = user_answer.split(" ")
	var whole_num = 0
	if parts.size() >= 1:
		whole_num = int(parts[0])
	
	# Create the answer mixed fraction at the aligned position
	answer_fraction_node = create_fraction(answer_pos, 0, 1, play_node)
	answer_fraction_node.set_input_mode(true)
	answer_fraction_node.set_mixed_fraction(whole_num, 0, 1)
	answer_fraction_node.editing_numerator = true
	answer_fraction_node.z_index = -1  # Render behind UI elements
	current_problem_nodes.append(answer_fraction_node)
	
	# Get the baseline width (a fraction with just "0/1")
	var temp_fraction = create_fraction(Vector2(0, 0), 0, 1, play_node)
	var baseline_width = temp_fraction.current_divisor_width
	temp_fraction.queue_free()
	
	# Calculate the whole number label width to determine proper offset
	# The whole number label was created in set_mixed_fraction
	var whole_number_width = 0.0
	if answer_fraction_node.whole_number_label:
		whole_number_width = answer_fraction_node.whole_number_label.get_minimum_size().x
	
	# Calculate how much wider the mixed fraction is compared to baseline
	var width_diff = answer_fraction_node.current_total_width - baseline_width
	
	# Shift rightward by: half the total width difference + base offset + whole number compensation
	# The whole number compensation accounts for the fact that larger whole numbers push everything further left
	var dynamic_offset = (width_diff / 2.0) + GameConfig.fraction_mixed_answer_extra_offset + (whole_number_width * 0.5)
	answer_pos.x += dynamic_offset
	answer_fraction_node.position = answer_pos
	
	# Store initial position and width for dynamic positioning (using total width for mixed fractions)
	answer_fraction_base_x = answer_pos.x
	answer_fraction_initial_width = answer_fraction_node.current_total_width
	
	# Hide the label since we're now using the fraction node
	if current_problem_label:
		current_problem_label.visible = false

func create_incorrect_answer_label():
	"""Create and animate a label showing the correct answer when user is incorrect"""
	if not QuestionManager.current_question:
		return
	
	# Check if this is a fraction problem (including conversion) - handle differently
	var q_type = QuestionManager.current_question.get("type", "")
	if QuestionManager.is_fraction_display_type(q_type) or QuestionManager.is_fraction_conversion_display_type(q_type):
		create_incorrect_fraction_answer()
		return
	
	# Regular problem - use the old method
	if not current_problem_label:
		return
	
	# Create new label as child of current problem label
	var incorrect_label = Label.new()
	incorrect_label.label_settings = current_problem_label_settings  # Use same size as the problem
	incorrect_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	incorrect_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	incorrect_label.position = Vector2(0, 0)  # Start at (0, 0) relative to parent
	incorrect_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	incorrect_label.text = QuestionManager.current_question.expression  # Set to the expression
	incorrect_label.self_modulate = Color(0, 0.5, 0)  # Dark green color
	incorrect_label.z_index = -1  # Render behind UI elements
	
	# Add as child to current problem label
	current_problem_label.add_child(incorrect_label)
	
	# Animate the label moving down over incorrect_label_animation_time
	var tween = create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_EXPO)
	tween.tween_property(incorrect_label, "position", Vector2(0, GameConfig.incorrect_label_move_distance), GameConfig.incorrect_label_animation_time)
	
	# The label will be cleaned up when the parent problem label is removed

func create_incorrect_fraction_answer():
	"""Create and animate fraction elements showing the correct answer for fraction problems"""
	var q_type = QuestionManager.current_question.get("type", "") if QuestionManager.current_question else ""
	if not QuestionManager.current_question or not (QuestionManager.is_fraction_display_type(q_type) or QuestionManager.is_fraction_conversion_display_type(q_type)):
		return
	
	# Clear any existing correct answer nodes
	for node in correct_answer_nodes:
		if node:
			node.queue_free()
	correct_answer_nodes.clear()
	
	# Handle equivalence problems specially
	if QuestionManager.current_question.get("type", "") == "Equivalence (4.NF.A)":
		create_incorrect_equivalence_answer()
		return
	
	# Parse the correct answer from the result (e.g., "10/9", "2 1/2", or "1")
	var result_data = parse_mixed_fraction_from_string(QuestionManager.current_question.result)
	# result_data format: [whole, numerator, denominator]
	var is_mixed_result = result_data[0] > 0
	var is_fraction_result = result_data[1] > 0  # Has a fraction part
	
	# Create correct answer elements in dark green, positioned at the same locations as current problem
	
	# Parse operands the same way as create_fraction_problem
	var operand1_data = null
	var operand2_data = null
	
	# Check if operands exist and are valid
	var has_valid_operands = (QuestionManager.current_question.has("operands") and 
							   QuestionManager.current_question.operands != null and 
							   QuestionManager.current_question.operands.size() >= 2 and
							   QuestionManager.current_question.operands[0] != null)
	
	if has_valid_operands:
		var operand1 = QuestionManager.current_question.operands[0]
		var operand2 = QuestionManager.current_question.operands[1]
		
		# Handle each operand individually (could be array or number)
		if typeof(operand1) == TYPE_ARRAY and operand1.size() >= 2:
			# Fraction format [num, denom]
			operand1_data = [0, int(operand1[0]), int(operand1[1])]
		elif typeof(operand1) == TYPE_FLOAT or typeof(operand1) == TYPE_INT:
			# Whole number - display as numerator with denominator 1 (will show as "6/1")
			operand1_data = [0, int(operand1), 1]
		
		if typeof(operand2) == TYPE_ARRAY and operand2.size() >= 2:
			# Fraction format [num, denom]
			operand2_data = [0, int(operand2[0]), int(operand2[1])]
		elif typeof(operand2) == TYPE_FLOAT or typeof(operand2) == TYPE_INT:
			# Whole number - display as numerator with denominator 1 (will show as "6/1")
			operand2_data = [0, int(operand2), 1]
	
	# If we don't have valid operands, parse from expression (for mixed fractions)
	if operand1_data == null or operand2_data == null:
		var expr = QuestionManager.current_question.get("expression", "")
		if expr != "":
			var expr_parts = expr.split(" = ")[0].split(" ")
			# Find operator position
			var operator_idx = -1
			for i in range(expr_parts.size()):
				if expr_parts[i] == QuestionManager.current_question.operator:
					operator_idx = i
					break
			
			if operator_idx > 0:
				# Parse operand1 (everything before operator)
				var operand1_str = ""
				for i in range(operator_idx):
					if operand1_str != "":
						operand1_str += " "
					operand1_str += expr_parts[i]
				operand1_data = parse_mixed_fraction_from_string(operand1_str)
				
				# Parse operand2 (everything after operator)
				var operand2_str = ""
				for i in range(operator_idx + 1, expr_parts.size()):
					if operand2_str != "":
						operand2_str += " "
					operand2_str += expr_parts[i]
				operand2_data = parse_mixed_fraction_from_string(operand2_str)
	
	if operand1_data == null or operand2_data == null:
		return
	
	# Calculate the same positions as the original problem
	var base_x = GameConfig.primary_position.x + GameConfig.fraction_problem_x_offset
	var target_y = GameConfig.primary_position.y
	
	# Create fractions to measure their widths
	var fraction1 = create_fraction(Vector2(0, 0), operand1_data[1], operand1_data[2], play_node)
	if operand1_data[0] > 0:
		fraction1.set_mixed_fraction(operand1_data[0], operand1_data[1], operand1_data[2])
	
	var fraction2 = create_fraction(Vector2(0, 0), operand2_data[1], operand2_data[2], play_node)
	if operand2_data[0] > 0:
		fraction2.set_mixed_fraction(operand2_data[0], operand2_data[1], operand2_data[2])
	
	# Create answer fraction/mixed fraction if result has a fraction part
	var answer_fraction = null
	if is_fraction_result:
		answer_fraction = create_fraction(Vector2(0, 0), result_data[1], result_data[2], play_node)
		if is_mixed_result:
			answer_fraction.set_mixed_fraction(result_data[0], result_data[1], result_data[2])
	
	# Get the actual widths of the fractions (use total width for mixed fractions)
	var fraction1_width = fraction1.current_total_width if fraction1.is_mixed_fraction else fraction1.current_divisor_width
	var fraction2_width = fraction2.current_total_width if fraction2.is_mixed_fraction else fraction2.current_divisor_width
	var fraction1_half_width = fraction1_width / 2.0
	var fraction2_half_width = fraction2_width / 2.0
	
	# Position the equals sign at a fixed location (same as in create_fraction_problem)
	var equals_x = base_x + 672.0
	
	# Work backwards from equals sign to position fraction2
	# Each fraction takes up: fraction_element_spacing + its half width on each side
	var fraction2_x = equals_x - GameConfig.fraction_element_spacing - fraction2_half_width
	
	# Position operator between fraction2 and fraction1
	var operator_x = fraction2_x - fraction2_half_width - GameConfig.fraction_element_spacing
	
	# Position fraction1
	var fraction1_x = operator_x - GameConfig.fraction_element_spacing - fraction1_half_width
	
	# Position answer area after equals sign
	var answer_x = equals_x + GameConfig.fraction_element_spacing + GameConfig.fraction_answer_offset
	var answer_number_x = answer_x + GameConfig.fraction_answer_number_offset
	
	# Check if problem extends too far left and adjust if necessary
	var leftmost_x = fraction1_x - fraction1_half_width
	if leftmost_x < GameConfig.fraction_problem_min_x:
		var x_offset = GameConfig.fraction_problem_min_x - leftmost_x
		# Shift all x positions rightward
		fraction1_x += x_offset
		operator_x += x_offset
		fraction2_x += x_offset
		equals_x += x_offset
		answer_x += x_offset
		answer_number_x += x_offset
	
	# Position all the fractions
	fraction1.position = Vector2(fraction1_x, target_y) + GameConfig.fraction_offset
	fraction2.position = Vector2(fraction2_x, target_y) + GameConfig.fraction_offset
	
	# Apply dark green color and z_index
	fraction1.modulate = Color(0, 0.5, 0)
	fraction2.modulate = Color(0, 0.5, 0)
	fraction1.z_index = -1  # Render behind UI elements
	fraction2.z_index = -1  # Render behind UI elements
	
	correct_answer_nodes.append(fraction1)
	correct_answer_nodes.append(fraction2)
	
	# Create either answer fraction/mixed fraction or answer label depending on result type
	if is_fraction_result:
		# Apply dynamic X positioning to answer fraction based on width (divisor or total for mixed)
		# Get baseline width by creating a temporary 0/1 fraction
		var temp_fraction = create_fraction(Vector2(0, 0), 0, 1, play_node)
		var baseline_width = temp_fraction.current_divisor_width
		temp_fraction.queue_free()
		
		# Calculate width difference and adjust position (shift right as it expands)
		var answer_width = answer_fraction.current_total_width if answer_fraction.is_mixed_fraction else answer_fraction.current_divisor_width
		var width_diff = answer_width - baseline_width
		
		# Position is already calculated correctly from the problem layout, no extra offset needed
		answer_fraction.position = Vector2(answer_x + (width_diff / 2.0), target_y) + GameConfig.fraction_offset
		answer_fraction.modulate = Color(0, 0.5, 0)
		answer_fraction.z_index = -1  # Render behind UI elements
		correct_answer_nodes.append(answer_fraction)
	else:
		# Create a label for the whole number answer (or parse result string directly)
		var answer_label = Label.new()
		answer_label.label_settings = label_settings_resource
		answer_label.text = QuestionManager.current_question.result
		answer_label.position = Vector2(answer_number_x, target_y) + GameConfig.operator_offset
		answer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		answer_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		answer_label.self_modulate = Color(0, 0.5, 0)  # Dark green
		answer_label.z_index = -1  # Render behind UI elements
		play_node.add_child(answer_label)
		correct_answer_nodes.append(answer_label)
	
	# Create operator label as child of fraction1
	var operator_label = Label.new()
	operator_label.label_settings = label_settings_resource
	operator_label.text = QuestionManager.get_display_operator(QuestionManager.current_question.operator)
	# Apply simple operator offset for multiplication/division operators (both unicode and ASCII)
	var op_offset = GameConfig.operator_offset
	var op_text = QuestionManager.current_question.operator
	if op_text == "×" or op_text == "÷" or op_text == "x" or op_text == "/":
		op_offset += GameConfig.simple_operator_offset
	operator_label.position = Vector2(operator_x - fraction1_x, 0) + op_offset - GameConfig.fraction_offset
	operator_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	operator_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	operator_label.z_index = -1  # Render behind UI elements
	# Don't set self_modulate - inherit dark green from parent fraction
	fraction1.add_child(operator_label)
	correct_answer_nodes.append(operator_label)
	
	# Create equals label as child of fraction2
	var equals_label = Label.new()
	equals_label.label_settings = label_settings_resource
	equals_label.text = "="
	equals_label.position = Vector2(equals_x - fraction2_x, 0) + GameConfig.operator_offset - GameConfig.fraction_offset
	equals_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	equals_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	equals_label.z_index = -1  # Render behind UI elements
	# Don't set self_modulate - inherit dark green from parent fraction
	fraction2.add_child(equals_label)
	correct_answer_nodes.append(equals_label)
	
	# Create parallel tweens for animating everything
	var correct_tween = create_tween()
	var incorrect_tween = create_tween()
	
	correct_tween.set_ease(Tween.EASE_OUT)
	correct_tween.set_trans(Tween.TRANS_EXPO)
	correct_tween.set_parallel(true)
	
	incorrect_tween.set_ease(Tween.EASE_OUT)
	incorrect_tween.set_trans(Tween.TRANS_EXPO)
	incorrect_tween.set_parallel(true)
	
	# Animate correct answer elements DOWN
	# Note: Skip child nodes (operators/equals) since they move with their parents
	for node in correct_answer_nodes:
		if node and node.get_parent() == play_node:  # Only animate top-level nodes
			var target_pos = node.position + Vector2(0, GameConfig.incorrect_label_move_distance_fractions)
			correct_tween.tween_property(node, "position", target_pos, GameConfig.incorrect_label_animation_time)
	
	# Animate incorrect problem nodes UP
	# Note: Skip child nodes (operators/equals) since they move with their parents
	for node in current_problem_nodes:
		if node and node.get_parent() == play_node:  # Only animate top-level nodes
			var target_pos = node.position - Vector2(0, GameConfig.incorrect_label_move_distance_fractions)
			incorrect_tween.tween_property(node, "position", target_pos, GameConfig.incorrect_label_animation_time)
	
	# Correct answer nodes will be animated off screen and cleaned up by submit_answer()

func create_incorrect_equivalence_answer():
	"""Create and animate the correct answer for equivalence problems"""
	if not QuestionManager.current_question:
		return
	
	# Parse the expression to get both fractions (e.g., "4/8 = 32/30")
	var expr = QuestionManager.current_question.get("expression", "")
	if expr == "":
		return
	
	var parts = expr.split(" = ")
	if parts.size() != 2:
		return
	
	# Parse left fraction
	var left_fraction_data = parse_mixed_fraction_from_string(parts[0])
	# Parse right fraction (the complete correct answer)
	var right_fraction_data = parse_mixed_fraction_from_string(parts[1])
	
	# Calculate positions (same as create_equivalence_problem)
	var target_y = GameConfig.primary_position.y
	
	# Create left fraction (complete, non-editable)
	var left_fraction = create_fraction(Vector2(0, 0), left_fraction_data[1], left_fraction_data[2], play_node)
	# Create right fraction (complete correct answer)
	var right_fraction = create_fraction(Vector2(0, 0), right_fraction_data[1], right_fraction_data[2], play_node)
	
	# Get actual widths
	var left_fraction_width = left_fraction.current_divisor_width
	var right_fraction_width = right_fraction.current_divisor_width
	var left_fraction_half_width = left_fraction_width / 2.0
	var right_fraction_half_width = right_fraction_width / 2.0
	
	# Measure equals sign width to center it properly
	var temp_equals = Label.new()
	temp_equals.label_settings = label_settings_resource
	temp_equals.text = "="
	temp_equals.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	play_node.add_child(temp_equals)
	temp_equals.reset_size()
	var equals_width = temp_equals.get_minimum_size().x
	temp_equals.queue_free()
	
	# Position equals sign so its CENTER is at the horizontal center of the screen (960 = 1920 / 2)
	# Offset by half the equals sign width to the left
	var equals_x = 960.0 - (equals_width / 2.0)
	
	# Work backwards from equals sign to position right fraction
	var right_fraction_x = equals_x + GameConfig.fraction_element_spacing + right_fraction_half_width
	
	# Position left fraction to the left of equals sign
	var left_fraction_x = equals_x - GameConfig.fraction_element_spacing - left_fraction_half_width
	
	# Check if problem extends too far left and adjust if necessary
	var leftmost_x = left_fraction_x - left_fraction_half_width
	if leftmost_x < GameConfig.fraction_problem_min_x:
		var x_offset = GameConfig.fraction_problem_min_x - leftmost_x
		left_fraction_x += x_offset
		equals_x += x_offset
		right_fraction_x += x_offset
	
	# Position fractions at target positions
	left_fraction.position = Vector2(left_fraction_x, target_y) + GameConfig.fraction_offset
	right_fraction.position = Vector2(right_fraction_x, target_y) + GameConfig.fraction_offset
	
	# Apply dark green color and z_index
	left_fraction.modulate = Color(0, 0.5, 0)
	right_fraction.modulate = Color(0, 0.5, 0)
	left_fraction.z_index = -1
	right_fraction.z_index = -1
	
	correct_answer_nodes.append(left_fraction)
	correct_answer_nodes.append(right_fraction)
	
	# Create equals label - child of left fraction so it moves with it
	var equals_label = Label.new()
	equals_label.label_settings = label_settings_resource
	equals_label.text = "="
	equals_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	equals_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	equals_label.z_index = -1
	# Position relative to left_fraction
	equals_label.position = Vector2(equals_x - left_fraction_x, 0) + GameConfig.operator_offset - GameConfig.fraction_offset
	left_fraction.add_child(equals_label)
	correct_answer_nodes.append(equals_label)
	
	# Create parallel tweens for animating everything
	var correct_tween = create_tween()
	var incorrect_tween = create_tween()
	
	correct_tween.set_ease(Tween.EASE_OUT)
	correct_tween.set_trans(Tween.TRANS_EXPO)
	correct_tween.set_parallel(true)
	
	incorrect_tween.set_ease(Tween.EASE_OUT)
	incorrect_tween.set_trans(Tween.TRANS_EXPO)
	incorrect_tween.set_parallel(true)
	
	# Animate correct answer elements DOWN
	for node in correct_answer_nodes:
		if node and node.get_parent() == play_node:  # Only animate top-level nodes
			var target_pos = node.position + Vector2(0, GameConfig.incorrect_label_move_distance_fractions)
			correct_tween.tween_property(node, "position", target_pos, GameConfig.incorrect_label_animation_time)
	
	# Animate incorrect problem nodes UP
	for node in current_problem_nodes:
		if node and node.get_parent() == play_node:  # Only animate top-level nodes
			var target_pos = node.position - Vector2(0, GameConfig.incorrect_label_move_distance_fractions)
			incorrect_tween.tween_property(node, "position", target_pos, GameConfig.incorrect_label_animation_time)

func create_incorrect_multi_input_label():
	"""Create and animate a label showing the correct answer for multi-input problems"""
	if not QuestionManager.current_question or not current_problem_label:
		return
	
	# Get the correct answer data
	var operands = QuestionManager.current_question.get("operands", [0, 0])
	var given_factor = QuestionManager.current_question.get("given_factor", 0)
	var expected_answers = QuestionManager.current_question.get("expected_answers", [0, 0])
	
	# Build the full correct expression
	var correct_text = str(operands[0]) + " x " + str(operands[1]) + " = " + str(given_factor) + " x " + str(expected_answers[0]) + " x " + str(expected_answers[1])
	
	# Create new label as child of current problem label
	var incorrect_label = Label.new()
	incorrect_label.label_settings = current_problem_label_settings  # Use same size as the problem
	incorrect_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	incorrect_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	incorrect_label.position = Vector2(0, 0)  # Start at (0, 0) relative to parent
	incorrect_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	incorrect_label.text = correct_text
	incorrect_label.self_modulate = Color(0, 0.5, 0)  # Dark green color
	incorrect_label.z_index = -1  # Render behind UI elements
	
	# Add as child to current problem label
	current_problem_label.add_child(incorrect_label)
	
	# Animate the label moving down over incorrect_label_animation_time
	var tween = create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_EXPO)
	tween.tween_property(incorrect_label, "position", Vector2(0, GameConfig.incorrect_label_move_distance), GameConfig.incorrect_label_animation_time)
	
	# The label will be cleaned up when the parent problem label is removed

func cleanup_problem_labels():
	"""Remove any remaining problem labels from the Play node"""
	# Clean up nodes tracked in current_problem_nodes
	# Note: We don't iterate and queue_free here because nodes being animated
	# off-screen are handled by the animation callback in animate_problem_off_screen.
	# We just clear our tracking arrays so new nodes can be added.
	current_problem_nodes.clear()

	current_problem_label = null
	current_prompt_label = null
	answer_fraction_node = null

	# Reset multiple choice state
	multiple_choice_buttons.clear()
	multiple_choice_answered = false
	multiple_choice_correct_index = -1
	
	# Reset number line state
	current_number_line = null
	number_line_fraction_label = null

func color_problem_nodes(feedback_color: Color):
	"""Color all problem nodes with the given feedback color"""
	for node in current_problem_nodes:
		if node:
			# Skip the prompt label - it stays blue
			if node == current_prompt_label:
				continue
			# Use modulate for fractions (Control nodes), self_modulate for labels
			if node is Control and not node is Label:
				node.modulate = feedback_color
			else:
				node.self_modulate = feedback_color
	
	# Also color the regular problem label if it exists
	if current_problem_label:
		current_problem_label.self_modulate = feedback_color
