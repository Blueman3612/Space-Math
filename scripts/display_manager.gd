extends Node

# Display manager - handles all problem display, fraction creation, and visual updates

# Node references
var play_node: Control  # Reference to the Play node
var current_problem_label: Label
var label_settings_resource: LabelSettings

# Current problem display nodes
var current_problem_nodes = []  # Array of nodes (fractions, labels) for the current problem display
var answer_fraction_node = null  # Reference to the fraction node used for answer input
var answer_fraction_base_x = 0.0  # Base X position of answer fraction (before width adjustments)
var answer_fraction_initial_width = 0.0  # Initial divisor width of answer fraction
var correct_answer_nodes = []  # Array of nodes showing the correct answer for incorrect fraction problems

# Blink state
var blink_timer = 0.0
var underscore_visible = true

func initialize(main_node: Control):
	"""Initialize display manager with references to needed nodes"""
	play_node = main_node.get_node("Play")
	label_settings_resource = load("res://assets/label settings/GravityBold128.tres")

func update_blink_timer(delta: float):
	"""Update the underscore blink timer"""
	blink_timer += delta
	if blink_timer >= GameConfig.blink_interval:
		blink_timer = 0.0
		underscore_visible = not underscore_visible

func update_problem_display(user_answer: String, answer_submitted: bool, is_fraction_input: bool, is_mixed_fraction_input: bool, editing_numerator: bool):
	"""Update the problem display based on current question type"""
	# Handle fraction-type problems differently
	if QuestionManager.current_question and QuestionManager.is_fraction_display_type(QuestionManager.current_question.get("type", "")):
		update_fraction_problem_display(user_answer, answer_submitted, is_fraction_input, is_mixed_fraction_input, editing_numerator)
	elif current_problem_label and QuestionManager.current_question:
		var base_text = QuestionManager.current_question.question + " = "
		var display_text = base_text + user_answer
		
		# Add blinking underscore only if not submitted
		if not answer_submitted and underscore_visible:
			display_text += "_"
		
		current_problem_label.text = display_text

func update_fraction_problem_display(user_answer: String, answer_submitted: bool, is_fraction_input: bool, is_mixed_fraction_input: bool, editing_numerator: bool):
	"""Update the display for fraction-type problems"""
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

func create_new_problem_label():
	"""Create a new problem label for the current question"""
	# Check if this is a fraction-type problem
	if QuestionManager.current_question and QuestionManager.is_fraction_display_type(QuestionManager.current_question.get("type", "")):
		create_fraction_problem()
		# Start timing this question immediately for fraction problems
		ScoreManager.start_question_timing()
		return
	
	# Create new label for normal (non-fraction) problems
	var new_label = Label.new()
	new_label.label_settings = label_settings_resource
	new_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	new_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	new_label.position = GameConfig.off_screen_bottom
	new_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	new_label.self_modulate = Color(1, 1, 1)  # Reset to white color
	new_label.z_index = -1  # Render behind UI elements
	
	# Add to Play node so it renders behind Play UI elements
	play_node.add_child(new_label)
	
	# Set as current problem label IMMEDIATELY
	current_problem_label = new_label
	
	# Animate to center position (fire and forget)
	var tween = create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_EXPO)
	tween.tween_property(new_label, "position", GameConfig.primary_position, GameConfig.animation_duration)
	
	# Start timing this question when animation completes
	tween.tween_callback(ScoreManager.start_question_timing)

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
	# Apply simple operator offset for converted unicode operators
	if QuestionManager.current_question.operator == "×" or QuestionManager.current_question.operator == "÷":
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
	
	# Note: answer_fraction_node will be created when user presses Divide

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
	
	# Check if this is a fraction problem - handle differently
	if QuestionManager.is_fraction_display_type(QuestionManager.current_question.get("type", "")):
		create_incorrect_fraction_answer()
		return
	
	# Regular problem - use the old method
	if not current_problem_label:
		return
	
	# Create new label as child of current problem label
	var incorrect_label = Label.new()
	incorrect_label.label_settings = label_settings_resource  # Uses GravityBold128
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
	if not QuestionManager.current_question or not QuestionManager.is_fraction_display_type(QuestionManager.current_question.get("type", "")):
		return
	
	# Clear any existing correct answer nodes
	for node in correct_answer_nodes:
		if node:
			node.queue_free()
	correct_answer_nodes.clear()
	
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
	# Apply simple operator offset for converted unicode operators
	var op_offset = GameConfig.operator_offset
	if QuestionManager.current_question.operator == "×" or QuestionManager.current_question.operator == "÷":
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

func cleanup_problem_labels():
	"""Remove any remaining problem labels from the Play node"""
	# Clean up fraction problem nodes
	for node in current_problem_nodes:
		if node:
			node.queue_free()
	current_problem_nodes.clear()
	
	# Clean up regular problem labels
	if play_node:
		for child in play_node.get_children():
			# Only remove dynamically created labels, not the static UI elements
			if (child is Label and 
				child != UIManager.timer_label and 
				child != UIManager.accuracy_label and 
				child != UIManager.drill_timer_label and 
				child != UIManager.drill_score_label):
				child.queue_free()
	
	current_problem_label = null
	answer_fraction_node = null

func color_problem_nodes(feedback_color: Color):
	"""Color all problem nodes with the given feedback color"""
	for node in current_problem_nodes:
		if node:
			# Use modulate for fractions (Control nodes), self_modulate for labels
			if node is Control and not node is Label:
				node.modulate = feedback_color
			else:
				node.self_modulate = feedback_color
	
	# Also color the regular problem label if it exists
	if current_problem_label:
		current_problem_label.self_modulate = feedback_color

