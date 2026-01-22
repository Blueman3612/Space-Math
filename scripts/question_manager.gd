extends Node

# Question management - handles question generation, weighting, and selection

# Math facts data and RNG
var math_facts = {}
var rng = RandomNumberGenerator.new()

# Current question state
var current_question = null  # Store current question data
var current_track = 0  # Current track being played

# Weighted question system variables
var question_weights = {}  # Dictionary mapping question keys to their weights
var unavailable_questions = []  # List of question keys that can't be selected this level
var available_questions = []  # List of all questions available for current track

func initialize():
	"""Initialize the question manager"""
	# Load and parse the math facts JSON
	var file = FileAccess.open("res://tools/all_problems.json", FileAccess.READ)
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
		print("Could not open all_problems.json")
	
	# Initialize random number generator
	rng.randomize()

func is_fraction_display_type(question_type: String) -> bool:
	"""Check if a question type should be displayed in fraction format"""
	return GameConfig.PROBLEM_DISPLAY_FORMATS.get(question_type, "") == "fraction"

func is_multiple_choice_display_type(question_type: String) -> bool:
	"""Check if a question type should be displayed in multiple choice format"""
	return GameConfig.PROBLEM_DISPLAY_FORMATS.get(question_type, "") == "multiple_choice"

func is_fraction_conversion_display_type(question_type: String) -> bool:
	"""Check if a question type should be displayed in fraction conversion format"""
	return GameConfig.PROBLEM_DISPLAY_FORMATS.get(question_type, "") == "fraction_conversion"

func is_number_line_display_type(question_type: String) -> bool:
	"""Check if a question type should be displayed in number line format"""
	return GameConfig.PROBLEM_DISPLAY_FORMATS.get(question_type, "") == "number_line"

func is_equivalence_display_type(question_type: String) -> bool:
	"""Check if a question type should be displayed in equivalence format"""
	return GameConfig.PROBLEM_DISPLAY_FORMATS.get(question_type, "") == "equivalence"

func is_multi_input_display_type(question_type: String) -> bool:
	"""Check if a question type should be displayed in multi-input format"""
	return GameConfig.PROBLEM_DISPLAY_FORMATS.get(question_type, "") == "multi_input"

func get_multiple_choice_answers(question_data) -> Array:
	"""Generate answer choices for multiple choice questions (dynamic number of choices)"""
	var question_type = question_data.get("type", "")
	
	# For legacy 3-choice comparison questions
	if question_type == "Compare unlike denominators (4.NF.A)":
		return ["<", "=", ">"]
	
	# For 2-choice comparison questions (decimal, fraction, and expression comparison)
	if question_type == "decimal_comparison" or question_type == "fraction_comparison" or question_type == "expression_comparison_20":
		return ["<", ">"]
	
	# Default fallback (shouldn't be reached for now)
	return []

func get_display_operator(operator: String) -> String:
	"""Convert unicode operators to simple characters for display"""
	match operator:
		"×": return "x"
		"÷": return "/"
		_: return operator

func generate_new_question():
	"""Generate a new question for the current track"""
	# Store current question for answer checking later
	# Priority: dynamic generation > weighted system > fallback
	if current_level_config != null:
		# Use dynamic problem generation
		current_question = generate_dynamic_question()
	elif not question_weights.is_empty():
		# Use the weighted system if we have weights initialized
		current_question = get_weighted_random_question()
	else:
		# Fallback to old system for non-track modes
		current_question = get_math_question(current_track)
	
	if not current_question:
		print("Failed to generate question for track ", current_track)
	
	return current_question

func get_math_question(track = null, grade = null, operator = null, no_zeroes = false):
	if not math_facts.has("levels"):
		return null
	
	var questions = []
	var question_title = ""
	var question_grade = ""
	
	# Priority: track > grade > operator
	if track != null:
		# Find questions from specific track
		var track_key = str(track) if typeof(track) == TYPE_STRING else "TRACK" + str(track)
		for level in math_facts.levels:
			if level.id == track_key:
				questions = level.facts
				question_title = level.title
				question_grade = ""  # No grade info in all_problems.json
				break
		
		# If track not found, pick random existing track
		if questions.is_empty():
			if not math_facts.levels.is_empty():
				var random_level = math_facts.levels[rng.randi() % math_facts.levels.size()]
				questions = random_level.facts
				question_title = random_level.title
				question_grade = ""
	
	elif grade != null:
		# Handle grade selection - collect all questions from all levels (since no grade grouping)
		question_grade = "Grade " + str(grade)
		
		# If operator is also specified, try to find questions with that operator
		if operator != null:
			var operator_str = get_operator_string(operator)
			var matching_questions = []
			var matching_title = ""
			
			for level in math_facts.levels:
				for fact in level.facts:
					if fact.operator == operator_str:
						matching_questions.append(fact)
						if matching_title == "":
							matching_title = level.title
			
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
			# Get all questions from all levels
			for level in math_facts.levels:
				questions.append_array(level.facts)
				if question_title == "":
					question_title = question_grade
	
	elif operator != null:
		# Get all questions with specific operator
		var operator_str = get_operator_string(operator)
		for level in math_facts.levels:
			for fact in level.facts:
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
	
	# Generate question text
	var question_text = ""
	
	# Check if this is a fraction-type question (operands are arrays of arrays)
	if random_question.has("type") and is_fraction_display_type(random_question.get("type", "")):
		# For fraction questions, use the expression as the question text
		if random_question.has("expression") and random_question.expression != "" and not random_question.expression.contains("["):
			# Expression exists and doesn't contain malformed array notation
			# For equivalence problems, use full expression; for others, split by " = "
			if random_question.has("operator") and random_question.operator == "equivalent_missing":
				question_text = random_question.expression  # Keep full expression for equivalence
			else:
				question_text = random_question.expression.split(" = ")[0]
		else:
			# Fallback: construct from operands if expression doesn't exist
			if random_question.has("operands") and random_question.operands.size() >= 2:
				var op1 = random_question.operands[0]
				var op2 = random_question.operands[1]
				var op1_str = ""
				var op2_str = ""
				
				# Format operand 1
				if typeof(op1) == TYPE_ARRAY and op1.size() >= 2:
					op1_str = str(int(op1[0])) + "/" + str(int(op1[1]))
				else:
					op1_str = str(int(op1) if typeof(op1) == TYPE_FLOAT else op1)
				
				# Format operand 2
				if typeof(op2) == TYPE_ARRAY and op2.size() >= 2:
					op2_str = str(int(op2[0])) + "/" + str(int(op2[1]))
				else:
					op2_str = str(int(op2) if typeof(op2) == TYPE_FLOAT else op2)
				
				question_text = op1_str + " " + random_question.operator + " " + op2_str
	else:
		# For regular questions, format integers without decimals
		# Check if operands exist and are numeric (not arrays) before converting
		if random_question.has("operands") and random_question.operands != null and random_question.operands.size() >= 2:
			var operand1 = random_question.operands[0]
			var operand2 = random_question.operands[1]
			if typeof(operand1) == TYPE_FLOAT and operand1 == int(operand1):
				operand1 = int(operand1)
			if typeof(operand2) == TYPE_FLOAT and operand2 == int(operand2):
				operand2 = int(operand2)
			question_text = str(operand1) + " " + random_question.operator + " " + str(operand2)
		else:
			# No operands - use expression if available
			question_text = random_question.get("expression", "").split(" = ")[0] if random_question.has("expression") else ""
	
	return {
		"operands": random_question.get("operands", []),
		"operator": random_question.operator,
		"result": random_question.result,
		"expression": random_question.get("expression", ""),
		"question": question_text,
		"title": question_title,
		"grade": question_grade,
		"type": random_question.get("type", "")  # Include type if it exists in the question data (default to empty string)
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
	var questions = []
	
	# Collect all questions with the operator from all levels
	for level in math_facts.levels:
		for fact in level.facts:
			if fact.operator == operator_str:
				questions.append(fact)
	
	return {
		"questions": questions,
		"grade_name": "Grade " + str(target_grade)
	}

# ============================================
# Dynamic Problem Generation System
# ============================================
# This system generates problems on-the-fly based on parameters
# instead of loading from JSON files.

# Level generation config for current level
var current_level_config = null
var used_questions_this_level = {}  # Track used questions to avoid duplicates

func set_level_generation_config(config: Dictionary):
	"""Set the configuration for dynamic problem generation"""
	current_level_config = config
	# Clear weighted question system since we're using dynamic generation
	question_weights.clear()
	unavailable_questions.clear()
	available_questions.clear()
	# Clear used questions for the new level
	used_questions_this_level.clear()

func generate_dynamic_question() -> Dictionary:
	"""Generate a problem dynamically based on current_level_config"""
	if current_level_config == null:
		print("Error: No level generation config set")
		return {}
	
	var config = current_level_config
	
	# Check for special problem types first
	var problem_type = config.get("type", "")
	if problem_type != "":
		return _generate_special_type_question(problem_type, config)
	
	var operators = config.get("operators", ["+"])
	
	var max_attempts = 100  # Max attempts before resetting used questions
	var attempts = 0
	var selected_operator: String
	var question_data: Dictionary
	var question_key: String
	
	while attempts < max_attempts:
		selected_operator = operators[rng.randi() % operators.size()]
		question_data = _generate_question_for_operator(selected_operator, config)
		question_key = _get_dynamic_question_key(question_data)
		
		# Check if this question has been used
		if not used_questions_this_level.has(question_key):
			# Mark as used and return
			used_questions_this_level[question_key] = true
			return question_data
		
		attempts += 1
	
	# If we've exhausted attempts, reset used questions and generate one more
	print("[QuestionManager] Ran out of unique questions, resetting used questions list")
	used_questions_this_level.clear()
	
	selected_operator = operators[rng.randi() % operators.size()]
	question_data = _generate_question_for_operator(selected_operator, config)
	question_key = _get_dynamic_question_key(question_data)
	used_questions_this_level[question_key] = true
	return question_data

func _generate_special_type_question(problem_type: String, config: Dictionary) -> Dictionary:
	"""Generate a special type question (decimal/fraction comparison, mixed numbers, etc.)"""
	var max_attempts = 100
	var attempts = 0
	var question_data: Dictionary
	var question_key: String
	
	while attempts < max_attempts:
		question_data = _generate_problem_by_type(problem_type, config)
		if question_data.is_empty():
			return {}
		
		question_key = _get_dynamic_question_key(question_data)
		
		if not used_questions_this_level.has(question_key):
			used_questions_this_level[question_key] = true
			return question_data
		
		attempts += 1
	
	# Reset and try once more
	print("[QuestionManager] Ran out of unique questions for type: ", problem_type)
	used_questions_this_level.clear()
	
	question_data = _generate_problem_by_type(problem_type, config)
	question_key = _get_dynamic_question_key(question_data)
	used_questions_this_level[question_key] = true
	return question_data

func _generate_problem_by_type(problem_type: String, config: Dictionary) -> Dictionary:
	"""Dispatch to the appropriate generation function based on problem type"""
	match problem_type:
		"expression_comparison_20":
			return _generate_expression_comparison_problem(config)
		"equivalence_associative":
			return _generate_equivalence_associative_problem(config)
		"equivalence_place_value":
			return _generate_equivalence_place_value_problem(config)
		"decimal_comparison":
			return _generate_decimal_comparison_problem(config)
		"decimal_add_sub":
			return _generate_decimal_add_sub_problem(config)
		"decimal_multiply_divide":
			return _generate_decimal_multiply_divide_problem(config)
		"fraction_comparison":
			return _generate_fraction_comparison_problem(config)
		"mixed_numbers_like_denom":
			return _generate_mixed_numbers_like_denom_problem(config)
		"fractions_unlike_denom":
			return _generate_fractions_unlike_denom_problem(config)
		"mixed_to_improper":
			return _generate_mixed_to_improper_problem(config)
		"improper_to_mixed":
			return _generate_improper_to_mixed_problem(config)
		"multiply_divide_fractions":
			return _generate_multiply_divide_fractions_problem(config)
		"number_line_fractions":
			return _generate_number_line_fractions_problem(config)
		"number_line_fractions_extended":
			return _generate_number_line_fractions_extended_problem(config)
		"equivalence_mult_factoring":
			return _generate_equivalence_mult_factoring_problem(config)
		_:
			print("Error: Unknown problem type: ", problem_type)
			return {}

func _generate_question_for_operator(operator: String, config: Dictionary) -> Dictionary:
	"""Generate a question for the given operator"""
	match operator:
		"+":
			return _generate_addition_problem(config)
		"-":
			return _generate_subtraction_problem(config)
		"x":
			return _generate_multiplication_problem(config)
		"/":
			return _generate_division_problem(config)
	return {}

func _get_dynamic_question_key(question_data: Dictionary) -> String:
	"""Generate a unique key for a dynamically generated question"""
	var operands = question_data.get("operands", [0, 0])
	var operator = question_data.get("operator", "+")
	var question_type = question_data.get("type", "")
	
	# Handle special types with complex operands
	if question_type == "fraction_comparison":
		var op1 = operands[0]
		var op2 = operands[1]
		return str(op1.numerator) + "/" + str(op1.denominator) + "_" + operator + "_" + str(op2.numerator) + "/" + str(op2.denominator)
	elif question_type == "mixed_numbers_like_denom":
		var op1 = operands[0]
		var op2 = operands[1]
		return str(op1.whole) + "_" + str(op1.numerator) + "/" + str(op1.denominator) + "_" + operator + "_" + str(op2.whole) + "_" + str(op2.numerator) + "/" + str(op2.denominator)
	elif question_type == "decimal_comparison" or question_type == "decimal_add_sub" or question_type == "decimal_multiply_divide":
		# Format decimals with enough precision
		return str(snapped(operands[0], 0.01)) + "_" + operator + "_" + str(snapped(operands[1], 0.01))
	elif question_type == "fractions_unlike_denom" or question_type == "multiply_divide_fractions":
		var op1 = operands[0]
		var op2 = operands[1]
		return str(op1.numerator) + "/" + str(op1.denominator) + "_" + operator + "_" + str(op2.numerator) + "/" + str(op2.denominator)
	elif question_type == "mixed_to_improper":
		var op = operands[0]
		return "mixed_to_improper_" + str(op.whole) + "_" + str(op.numerator) + "/" + str(op.denominator)
	elif question_type == "improper_to_mixed":
		var op = operands[0]
		return "improper_to_mixed_" + str(op.numerator) + "/" + str(op.denominator)
	elif question_type == "number_line_fractions":
		var op = operands[0]
		return "number_line_" + str(op.numerator) + "/" + str(op.denominator)
	elif question_type == "number_line_fractions_extended":
		var op = operands[0]
		var whole = op.get("whole", 0)
		if whole > 0:
			return "number_line_ext_" + str(whole) + "_" + str(op.numerator) + "/" + str(op.denominator)
		else:
			return "number_line_ext_" + str(op.numerator) + "/" + str(op.denominator)
	elif question_type == "expression_comparison_20":
		# Format: expr1_op1_expr1_op2 vs expr2_op1_expr2_op2
		var expr1 = operands[0]
		var expr2 = operands[1]
		return str(expr1.a) + expr1.op + str(expr1.b) + "_vs_" + str(expr2.a) + expr2.op + str(expr2.b)
	elif question_type == "equivalence_associative":
		# Format: left_a op left_b = right_a op right_b op answer
		var left = operands[0]
		var right = operands[1]
		return str(left.a) + left.op + str(left.b) + "_eq_" + str(right.a) + right.op1 + str(right.b) + right.op2 + str(question_data.get("result", 0))
	elif question_type == "equivalence_place_value":
		# Format: a op b = a op 10 op answer
		var left = operands[0]
		var right = operands[1]
		return str(left.a) + left.op + str(left.b) + "_pv_" + str(right.a) + right.op1 + "10" + right.op2 + str(question_data.get("result", 0))
	elif question_type == "equivalence_mult_factoring":
		# Format: a_x_b_factor_c
		var given_factor = question_data.get("given_factor", 0)
		return str(operands[0]) + "_x_" + str(operands[1]) + "_factor_" + str(given_factor)

	# Standard format for regular problems
	return str(operands[0]) + "_" + operator + "_" + str(operands[1])

func _generate_addition_problem(config: Dictionary) -> Dictionary:
	"""Generate an addition problem based on config"""
	var operand1: int
	var operand2: int
	var result: int
	
	if config.has("sum_max"):
		# "Sums to X" style - generate operands where sum doesn't exceed max
		var sum_max = config.sum_max
		var min_val = config.get("min_val", 0)
		operand1 = rng.randi_range(min_val, sum_max)
		operand2 = rng.randi_range(min_val, sum_max - operand1)
		result = operand1 + operand2
	elif config.has("digit_count"):
		# Multi-digit addition
		var digit_count = config.digit_count
		var requires_regrouping = config.get("requires_regrouping", false)
		var max_answer = config.get("max_answer", 9999)
		
		if digit_count == 2:
			if requires_regrouping:
				var generated = _generate_2digit_addition_with_regrouping(max_answer)
				operand1 = generated[0]
				operand2 = generated[1]
			else:
				var generated = _generate_2digit_addition_without_regrouping(max_answer)
				operand1 = generated[0]
				operand2 = generated[1]
		elif digit_count == 3:
			var generated = _generate_3digit_addition(max_answer)
			operand1 = generated[0]
			operand2 = generated[1]
		
		result = operand1 + operand2
	else:
		# Fallback - simple addition 0-10
		operand1 = rng.randi_range(0, 10)
		operand2 = rng.randi_range(0, 10)
		result = operand1 + operand2
	
	var question_text = str(operand1) + " + " + str(operand2)
	
	return {
		"operands": [operand1, operand2],
		"operator": "+",
		"result": result,
		"expression": question_text + " = " + str(result),
		"question": question_text,
		"title": config.get("name", "Addition"),
		"grade": "",
		"type": ""
	}

func _generate_subtraction_problem(config: Dictionary) -> Dictionary:
	"""Generate a subtraction problem based on config"""
	var operand1: int
	var operand2: int
	var result: int
	
	if config.has("range_max"):
		# "Subtraction 0-X" style - first operand in range, second less than first
		var range_max = config.range_max
		var range_min = config.get("range_min", 0)
		operand1 = rng.randi_range(range_min, range_max)
		operand2 = rng.randi_range(range_min, operand1)  # Ensure no negative result
		result = operand1 - operand2
	elif config.has("digit_count"):
		# Multi-digit subtraction
		var digit_count = config.digit_count
		var requires_regrouping = config.get("requires_regrouping", false)
		var max_answer = config.get("max_answer", 9999)
		
		if digit_count == 2:
			if requires_regrouping:
				var generated = _generate_2digit_subtraction_with_regrouping(max_answer)
				operand1 = generated[0]
				operand2 = generated[1]
			else:
				var generated = _generate_2digit_subtraction_without_regrouping(max_answer)
				operand1 = generated[0]
				operand2 = generated[1]
		elif digit_count == 3:
			var generated = _generate_3digit_subtraction(max_answer)
			operand1 = generated[0]
			operand2 = generated[1]
		
		result = operand1 - operand2
	else:
		# Fallback - simple subtraction 0-10
		operand1 = rng.randi_range(0, 10)
		operand2 = rng.randi_range(0, operand1)
		result = operand1 - operand2
	
	var question_text = str(operand1) + " - " + str(operand2)
	
	return {
		"operands": [operand1, operand2],
		"operator": "-",
		"result": result,
		"expression": question_text + " = " + str(result),
		"question": question_text,
		"title": config.get("name", "Subtraction"),
		"grade": "",
		"type": ""
	}

func _generate_multiplication_problem(config: Dictionary) -> Dictionary:
	"""Generate a multiplication problem based on config"""
	var operand1: int
	var operand2: int
	var result: int
	
	if config.has("two_digit_by_two_digit"):
		# 2-digit by 2-digit multiplication
		var generated: Array
		if config.has("requires_regrouping"):
			# Explicit regrouping requirement
			if config.requires_regrouping:
				generated = _generate_2digit_by_2digit_multiplication_with_regrouping()
			else:
				generated = _generate_2digit_by_2digit_multiplication_without_regrouping()
		else:
			# No regrouping requirement - any 2-digit by 2-digit
			generated = _generate_2digit_by_2digit_multiplication_any()
		operand1 = generated[0]
		operand2 = generated[1]
		result = operand1 * operand2
	elif config.has("factor_min") and config.has("factor_max"):
		# Standard multiplication within factor range
		var factor_min = config.factor_min
		var factor_max = config.factor_max
		operand1 = rng.randi_range(factor_min, factor_max)
		operand2 = rng.randi_range(factor_min, factor_max)
		result = operand1 * operand2
	elif config.has("multi_digit"):
		# 1-digit by 2-3-digit multiplication
		var requires_regrouping = config.get("requires_regrouping", false)
		var generated = _generate_multidigit_multiplication(requires_regrouping)
		operand1 = generated[0]
		operand2 = generated[1]
		result = operand1 * operand2
	else:
		# Fallback - simple multiplication 0-10
		operand1 = rng.randi_range(0, 10)
		operand2 = rng.randi_range(0, 10)
		result = operand1 * operand2
	
	var question_text = str(operand1) + " x " + str(operand2)
	
	return {
		"operands": [operand1, operand2],
		"operator": "x",
		"result": result,
		"expression": question_text + " = " + str(result),
		"question": question_text,
		"title": config.get("name", "Multiplication"),
		"grade": "",
		"type": ""
	}

func _generate_division_problem(config: Dictionary) -> Dictionary:
	"""Generate a division problem based on config (always whole number result, no div by 0)"""
	var operand1: int  # Dividend
	var operand2: int  # Divisor
	var result: int
	
	if config.has("divisor_min") and config.has("divisor_max"):
		# Standard division within divisor range
		var divisor_min = max(1, config.divisor_min)  # Never divide by 0
		var divisor_max = config.divisor_max
		operand2 = rng.randi_range(divisor_min, divisor_max)
		# Generate a result and multiply to get dividend (ensures whole number result)
		result = rng.randi_range(divisor_min, divisor_max)
		operand1 = operand2 * result
	elif config.has("multi_digit"):
		# 2-3-digit by 1-digit division
		var generated = _generate_multidigit_division()
		operand1 = generated[0]
		operand2 = generated[1]
		result = operand1 / operand2
	else:
		# Fallback - simple division 1-10
		operand2 = rng.randi_range(1, 10)
		result = rng.randi_range(1, 10)
		operand1 = operand2 * result
	
	var question_text = str(operand1) + " / " + str(operand2)
	
	return {
		"operands": [operand1, operand2],
		"operator": "/",
		"result": result,
		"expression": question_text + " = " + str(result),
		"question": question_text,
		"title": config.get("name", "Division"),
		"grade": "",
		"type": ""
	}

# ============================================
# Multi-digit Problem Helpers
# ============================================

func _generate_2digit_addition_without_regrouping(max_answer: int = 198) -> Array:
	"""Generate 2-digit addition where no column exceeds 9 and sum doesn't exceed max_answer"""
	var operand1: int
	var operand2: int
	var attempts = 0
	
	while attempts < 100:
		# Generate digits that won't require carrying
		var tens1 = rng.randi_range(1, 8)
		var ones1 = rng.randi_range(0, 8)
		var tens2 = rng.randi_range(1, min(9 - tens1, 8))  # Ensure 2-digit and no carry
		var ones2 = rng.randi_range(0, 9 - ones1)
		
		operand1 = tens1 * 10 + ones1
		operand2 = tens2 * 10 + ones2
		
		# Check if sum is within max_answer
		if operand1 + operand2 <= max_answer:
			return [operand1, operand2]
		
		attempts += 1
	
	# Fallback: generate operands that definitely work
	operand1 = rng.randi_range(10, min(48, max_answer - 10))
	operand2 = rng.randi_range(10, max_answer - operand1)
	return [operand1, operand2]

func _generate_2digit_addition_with_regrouping(max_answer: int = 198) -> Array:
	"""Generate 2-digit addition that requires carrying in at least one column and sum doesn't exceed max_answer"""
	var operand1: int
	var operand2: int
	var attempts = 0
	
	while attempts < 100:
		var tens1 = rng.randi_range(1, 9)
		var ones1 = rng.randi_range(0, 9)
		var tens2 = rng.randi_range(1, 9)
		var ones2 = rng.randi_range(0, 9)
		
		operand1 = tens1 * 10 + ones1
		operand2 = tens2 * 10 + ones2
		
		# Check if sum is within max_answer
		if operand1 + operand2 > max_answer:
			attempts += 1
			continue
		
		# Check if regrouping is required (ones sum > 9 OR tens sum > 9)
		var ones_sum = ones1 + ones2
		var carry_from_ones = 1 if ones_sum > 9 else 0
		var tens_sum = tens1 + tens2 + carry_from_ones
		
		if ones_sum > 9 or tens_sum > 9:
			return [operand1, operand2]
		
		attempts += 1
	
	# Fallback: force regrouping in ones place while respecting max_answer
	var fallback_ones1 = rng.randi_range(5, 9)
	var fallback_ones2 = rng.randi_range(10 - fallback_ones1, 9)
	var max_tens = (max_answer - fallback_ones1 - fallback_ones2) / 20  # Divide by 20 since both operands contribute
	max_tens = max(1, min(max_tens, 4))  # Clamp to reasonable range
	operand1 = rng.randi_range(1, max_tens) * 10 + fallback_ones1
	operand2 = rng.randi_range(1, max_tens) * 10 + fallback_ones2
	return [operand1, operand2]

func _generate_2digit_subtraction_without_regrouping(max_answer: int = 99) -> Array:
	"""Generate 2-digit subtraction where no borrowing is needed and result doesn't exceed max_answer"""
	var operand1: int
	var operand2: int
	var attempts = 0
	
	while attempts < 100:
		# Top digit must be >= bottom digit in each column
		var tens1 = rng.randi_range(2, 9)
		var ones1 = rng.randi_range(1, 9)
		var tens2 = rng.randi_range(1, tens1 - 1) if tens1 > 1 else 1
		var ones2 = rng.randi_range(0, ones1)
		
		operand1 = tens1 * 10 + ones1
		operand2 = tens2 * 10 + ones2
		
		# Check if result is within max_answer
		if operand1 - operand2 <= max_answer:
			return [operand1, operand2]
		
		attempts += 1
	
	# Fallback
	operand1 = min(99, max_answer + 10)
	operand2 = operand1 - rng.randi_range(1, min(max_answer, operand1 - 10))
	return [operand1, operand2]

func _generate_2digit_subtraction_with_regrouping(max_answer: int = 99) -> Array:
	"""Generate 2-digit subtraction that requires borrowing and result doesn't exceed max_answer"""
	var operand1: int
	var operand2: int
	var attempts = 0
	
	while attempts < 100:
		var tens1 = rng.randi_range(2, 9)
		var ones1 = rng.randi_range(0, 8)
		var tens2 = rng.randi_range(1, tens1 - 1)
		var ones2 = rng.randi_range(ones1 + 1, 9)  # Force ones2 > ones1 for borrowing
		
		operand1 = tens1 * 10 + ones1
		operand2 = tens2 * 10 + ones2
		
		# Verify borrowing is needed, result is positive, and within max_answer
		if ones2 > ones1 and operand1 > operand2 and operand1 - operand2 <= max_answer:
			return [operand1, operand2]
		
		attempts += 1
	
	# Fallback - ensure result is within max_answer
	operand1 = 52
	operand2 = max(27, 52 - max_answer)
	return [operand1, operand2]

func _generate_3digit_addition(max_answer: int = 1998) -> Array:
	"""Generate 3-digit addition problem with sum not exceeding max_answer"""
	var operand1: int
	var operand2: int
	var attempts = 0
	
	while attempts < 100:
		operand1 = rng.randi_range(100, min(999, max_answer - 100))
		operand2 = rng.randi_range(100, min(999, max_answer - operand1))
		
		if operand1 + operand2 <= max_answer:
			return [operand1, operand2]
		
		attempts += 1
	
	# Fallback - ensure sum is within max_answer
	operand1 = rng.randi_range(100, min(499, max_answer / 2))
	operand2 = rng.randi_range(100, max_answer - operand1)
	return [operand1, operand2]

func _generate_3digit_subtraction(max_answer: int = 899) -> Array:
	"""Generate 3-digit subtraction problem (no negative results) with result not exceeding max_answer"""
	var operand1: int
	var operand2: int
	var attempts = 0
	
	while attempts < 100:
		operand1 = rng.randi_range(200, 999)
		# Ensure operand2 is large enough that result doesn't exceed max_answer
		var min_operand2 = max(100, operand1 - max_answer)
		operand2 = rng.randi_range(min_operand2, operand1 - 1)
		
		if operand1 - operand2 <= max_answer and operand2 >= 100:
			return [operand1, operand2]
		
		attempts += 1
	
	# Fallback - ensure result is within max_answer
	operand1 = rng.randi_range(200, 999)
	operand2 = max(100, operand1 - max_answer) + rng.randi_range(0, 50)
	if operand2 >= operand1:
		operand2 = operand1 - 1
	return [operand1, operand2]

func _generate_multidigit_multiplication(requires_regrouping: bool) -> Array:
	"""Generate 1-digit by 2-3-digit multiplication"""
	var single_digit: int
	var multi_digit: int
	
	if requires_regrouping:
		# With regrouping - allow any valid multiplication
		single_digit = rng.randi_range(2, 9)
		multi_digit = rng.randi_range(10, 999)
	else:
		# Without regrouping - each digit * single_digit must be < 10
		single_digit = rng.randi_range(2, 4)  # Limit single digit
		var num_digits = rng.randi_range(2, 3)
		
		var digits = []
		for i in range(num_digits):
			var max_digit = 9 / single_digit
			digits.append(rng.randi_range(1 if i == 0 else 0, int(max_digit)))
		
		multi_digit = 0
		for i in range(digits.size()):
			multi_digit = multi_digit * 10 + digits[i]
	
	return [single_digit, multi_digit]

func _generate_multidigit_division() -> Array:
	"""Generate 2-3-digit by 1-digit division (whole number result)"""
	var divisor = rng.randi_range(2, 9)
	var result = rng.randi_range(10, 999)  # 2-3 digit result
	var dividend = divisor * result
	
	# Ensure dividend is 2-3 digits
	while dividend < 10 or dividend > 999:
		result = rng.randi_range(10, 111)  # Smaller range to keep dividend manageable
		dividend = divisor * result
	
	return [dividend, divisor]

func _generate_2digit_by_2digit_multiplication_without_regrouping() -> Array:
	"""Generate 2-digit by 2-digit multiplication without regrouping (no carries)"""
	# For no regrouping: each partial product digit multiplication must not exceed 9
	# and adding partial products must not cause carries
	var attempts = 0
	
	while attempts < 100:
		# Generate digits that won't cause carries when multiplied
		# Keep all digits small (1-3) to avoid carries
		var tens1 = rng.randi_range(1, 3)
		var ones1 = rng.randi_range(0, 3)
		var tens2 = rng.randi_range(1, 3)
		var ones2 = rng.randi_range(0, 3)
		
		var operand1 = tens1 * 10 + ones1
		var operand2 = tens2 * 10 + ones2
		
		# Check for regrouping:
		# ones1 * ones2 <= 9 (no carry in ones place)
		# ones1 * tens2 + tens1 * ones2 <= 9 (no carry in tens place)
		# tens1 * tens2 <= 9 (no carry in hundreds place)
		var check1 = ones1 * ones2
		var check2 = ones1 * tens2 + tens1 * ones2
		var check3 = tens1 * tens2
		
		if check1 <= 9 and check2 <= 9 and check3 <= 9:
			return [operand1, operand2]
		
		attempts += 1
	
	# Fallback: guaranteed safe values
	return [11, 11]

func _generate_2digit_by_2digit_multiplication_with_regrouping() -> Array:
	"""Generate 2-digit by 2-digit multiplication with regrouping (at least one carry)"""
	var attempts = 0
	
	while attempts < 100:
		var tens1 = rng.randi_range(1, 9)
		var ones1 = rng.randi_range(0, 9)
		var tens2 = rng.randi_range(1, 9)
		var ones2 = rng.randi_range(0, 9)
		
		var operand1 = tens1 * 10 + ones1
		var operand2 = tens2 * 10 + ones2
		
		# Check for at least one carry
		var check1 = ones1 * ones2  # ones place product
		var check2 = ones1 * tens2 + tens1 * ones2  # Cross products
		var check3 = tens1 * tens2  # tens place product
		
		# At least one must exceed 9 to require regrouping
		if check1 > 9 or check2 > 9 or check3 > 9:
			return [operand1, operand2]
		
		attempts += 1
	
	# Fallback: guaranteed to require regrouping
	return [15, 15]

func _generate_2digit_by_2digit_multiplication_any() -> Array:
	"""Generate any 2-digit by 2-digit multiplication (no regrouping restrictions)"""
	var operand1 = rng.randi_range(10, 99)
	var operand2 = rng.randi_range(10, 99)
	return [operand1, operand2]

# ============================================
# Expression Comparison Problem Generation
# ============================================

func _generate_expression_comparison_problem(config: Dictionary) -> Dictionary:
	"""Generate an expression comparison problem (comparing two addition/subtraction expressions with results <= 20)"""
	# First, randomly decide which answer we want (ensures 50/50 split)
	var target_answer = "<" if rng.randi() % 2 == 0 else ">"
	
	# Generate 10 candidates that match the target answer, pick the one with the smallest difference
	var best_candidate = null
	var min_diff = 999999
	
	for _i in range(10):
		var candidate = _generate_single_expression_comparison()
		if candidate == null:
			continue
		
		# Check if this candidate matches our target answer
		var candidate_answer = "<" if candidate.expr1_result < candidate.expr2_result else ">"
		if candidate_answer != target_answer:
			continue
		
		var diff = abs(candidate.expr1_result - candidate.expr2_result)
		if diff < min_diff:
			min_diff = diff
			best_candidate = candidate
	
	# Fallback if no candidates matched target (generate until we get one)
	while best_candidate == null:
		var candidate = _generate_single_expression_comparison()
		if candidate == null:
			continue
		var candidate_answer = "<" if candidate.expr1_result < candidate.expr2_result else ">"
		if candidate_answer == target_answer:
			best_candidate = candidate
	
	var expr1_a = best_candidate.expr1_a
	var expr1_b = best_candidate.expr1_b
	var op1 = best_candidate.op1
	var expr1_result = best_candidate.expr1_result
	var expr2_a = best_candidate.expr2_a
	var expr2_b = best_candidate.expr2_b
	var op2 = best_candidate.op2
	var expr2_result = best_candidate.expr2_result
	
	var result = "<" if expr1_result < expr2_result else ">"
	
	# Format for display
	var expr1_display = str(expr1_a) + " " + op1 + " " + str(expr1_b)
	var expr2_display = str(expr2_a) + " " + op2 + " " + str(expr2_b)
	var question_text = expr1_display + " ? " + expr2_display
	
	return {
		"operands": [
			{"a": expr1_a, "b": expr1_b, "op": op1, "result": expr1_result},
			{"a": expr2_a, "b": expr2_b, "op": op2, "result": expr2_result}
		],
		"operator": "?",
		"result": result,
		"expression": question_text + " = " + result,
		"question": question_text,
		"title": config.get("name", "Compare Sums and Differences to 20"),
		"grade": "",
		"type": "expression_comparison_20"
	}

func _generate_single_expression_comparison() -> Variant:
	"""Generate a single expression comparison candidate"""
	# Operator combinations: +/+, -/-, +/-, -/+
	var op_combos = [["+", "+"], ["-", "-"], ["+", "-"], ["-", "+"]]
	var chosen_combo = op_combos[rng.randi() % op_combos.size()]
	var op1 = chosen_combo[0]
	var op2 = chosen_combo[1]
	
	var expr1_a: int
	var expr1_b: int
	var expr1_result: int
	var expr2_a: int
	var expr2_b: int
	var expr2_result: int
	
	var attempts = 0
	while attempts < 100:
		# Generate first expression
		if op1 == "+":
			# Addition: a + b <= 20
			expr1_a = rng.randi_range(0, 20)
			expr1_b = rng.randi_range(0, 20 - expr1_a)
			expr1_result = expr1_a + expr1_b
		else:
			# Subtraction: a - b >= 0, a <= 20
			expr1_a = rng.randi_range(0, 20)
			expr1_b = rng.randi_range(0, expr1_a)
			expr1_result = expr1_a - expr1_b
		
		# Generate second expression
		if op2 == "+":
			# Addition: a + b <= 20
			expr2_a = rng.randi_range(0, 20)
			expr2_b = rng.randi_range(0, 20 - expr2_a)
			expr2_result = expr2_a + expr2_b
		else:
			# Subtraction: a - b >= 0, a <= 20
			expr2_a = rng.randi_range(0, 20)
			expr2_b = rng.randi_range(0, expr2_a)
			expr2_result = expr2_a - expr2_b
		
		# Ensure results are not equal
		if expr1_result != expr2_result:
			return {
				"expr1_a": expr1_a, "expr1_b": expr1_b, "op1": op1, "expr1_result": expr1_result,
				"expr2_a": expr2_a, "expr2_b": expr2_b, "op2": op2, "expr2_result": expr2_result
			}
		
		attempts += 1
	
	return null

# ============================================
# Equivalence Problem Generation
# ============================================

func _generate_equivalence_associative_problem(config: Dictionary) -> Dictionary:
	"""Generate an equivalence problem using associative property.
	Format: a OP b = c OP d OP ___
	Where one operand is shared between sides, and the answer is always 1-4.
	
	Examples:
	- 12 + 4 = 4 + 10 + 2 (share 4, deflate 12 to 10, add 2)
	- 2 + 18 = 2 + 20 - 2 (share 2, inflate 18 to 20, subtract 2)
	- 19 - 15 = 20 - 15 - 1 (share 15, inflate 19 to 20, subtract 1)
	- 21 - 14 = 21 - 10 - 4 (share 21, deflate 14 to 10, subtract 4)
	"""
	
	# Choose main operator (+ or -)
	var main_op = "+" if rng.randi() % 2 == 0 else "-"
	
	# Generate the left side expression with result <= 20
	var left_a: int
	var left_b: int
	var left_result: int
	
	# Generate adjustment value (1-4, weighted toward 1-2)
	# Weights: 1 = 40%, 2 = 35%, 3 = 15%, 4 = 10%
	var adj_roll = rng.randi() % 100
	var adjustment: int
	if adj_roll < 40:
		adjustment = 1
	elif adj_roll < 75:
		adjustment = 2
	elif adj_roll < 90:
		adjustment = 3
	else:
		adjustment = 4
	
	# Decide whether to inflate or deflate the non-shared operand (50/50)
	var inflate = rng.randi() % 2 == 0
	
	var attempts = 0
	while attempts < 100:
		if main_op == "+":
			# Addition: a + b <= 20
			left_a = rng.randi_range(0, 20)
			left_b = rng.randi_range(0, 20 - left_a)
			left_result = left_a + left_b
		else:
			# Subtraction: a - b >= 0, result <= 20
			# For subtraction, left_a can be > 20 as long as result <= 20
			left_result = rng.randi_range(0, 20)
			left_b = rng.randi_range(0, 20)  # The subtracted amount
			left_a = left_result + left_b  # So left_a - left_b = left_result
		
		# Ensure we have valid operands
		if left_a < 0 or left_b < 0:
			attempts += 1
			continue
		
		# Decide which operand to share (50/50)
		# share_first = true means we share left_a (first operand)
		var share_first = rng.randi() % 2 == 0
		var shared: int
		var non_shared: int
		
		if share_first:
			shared = left_a
			non_shared = left_b
		else:
			shared = left_b
			non_shared = left_a
		
		# Calculate the modified non-shared operand for the right side
		var modified: int
		if inflate:
			modified = non_shared + adjustment
		else:
			modified = non_shared - adjustment
		
		# Ensure modified operand is valid (non-negative)
		if modified < 0:
			attempts += 1
			continue
		
		# Determine the final operator before the answer
		# This depends on whether we inflated or deflated:
		# - Inflate: we made the modified operand bigger, so we need to subtract to compensate
		# - Deflate: we made the modified operand smaller, so we need to add to compensate
		# BUT for subtraction when sharing the second operand, the logic is different
		var final_op: String
		if main_op == "+":
			# For addition: inflate -> subtract, deflate -> add
			final_op = "-" if inflate else "+"
		else:
			# For subtraction:
			# If sharing first (a): a - b = a - modified ± answer
			#   - If we deflate b (make modified smaller), we subtracted less, so subtract more: final_op = "-"
			#   - If we inflate b (make modified bigger), we subtracted more, so add back: final_op = "+"
			# If sharing second (b): a - b = modified - b ± answer
			#   - If we deflate a (make modified smaller), result is smaller, so add: final_op = "+"
			#   - If we inflate a (make modified bigger), result is bigger, so subtract: final_op = "-"
			if share_first:
				# Sharing first operand (a), modifying b
				final_op = "+" if inflate else "-"
			else:
				# Sharing second operand (b), modifying a
				final_op = "-" if inflate else "+"
		
		# Build the right side
		# For addition: shared always comes first (commutative, so order can swap)
		# For subtraction: shared operand maintains its position
		var right_a: int
		var right_b: int
		var right_op1 = main_op
		var right_op2 = final_op
		
		if main_op == "+":
			# Addition is commutative, shared comes first
			right_a = shared
			right_b = modified
		else:
			# Subtraction: maintain position
			if share_first:
				# Shared was first (left_a), stays first
				right_a = shared
				right_b = modified
			else:
				# Shared was second (left_b), stays second
				right_a = modified
				right_b = shared
		
		# Build display strings
		var left_display = str(left_a) + " " + main_op + " " + str(left_b)
		var right_display = str(right_a) + " " + right_op1 + " " + str(right_b) + " " + right_op2 + " "
		var question_text = left_display + " = " + right_display
		
		return {
			"operands": [
				{"a": left_a, "b": left_b, "op": main_op, "result": left_result},
				{"a": right_a, "b": right_b, "op1": right_op1, "op2": right_op2}
			],
			"operator": "=",
			"result": adjustment,
			"expression": question_text + str(adjustment),
			"question": question_text,
			"title": config.get("name", "Equivalence - Associative Property"),
			"grade": "",
			"type": "equivalence_associative"
		}
	
	# Fallback (should rarely happen)
	return {
		"operands": [
			{"a": 5, "b": 3, "op": "+", "result": 8},
			{"a": 3, "b": 6, "op1": "+", "op2": "-"}
		],
		"operator": "=",
		"result": 1,
		"expression": "5 + 3 = 3 + 6 - 1",
		"question": "5 + 3 = 3 + 6 - ",
		"title": config.get("name", "Equivalence - Associative Property"),
		"grade": "",
		"type": "equivalence_associative"
	}

func _generate_equivalence_place_value_problem(config: Dictionary) -> Dictionary:
	"""Generate an equivalence problem using place value decomposition.
	Format: a +/- b = a +/- 10 +/- c
	Where a is 30-79, b is 11-19, and c = b - 10 (always 1-9).
	
	Examples:
	- 42 + 18 = 42 + 10 + 8
	- 70 - 16 = 70 - 10 - 6
	"""
	
	# Choose main operator (+ or -)
	var main_op = "+" if rng.randi() % 2 == 0 else "-"
	
	# Generate operands
	var a = rng.randi_range(30, 79)  # First operand: 2-digit number 30-79
	var b = rng.randi_range(11, 19)  # Second operand: teen number 11-19
	var c = b - 10  # Answer: ones digit of b (1-9)
	
	# Calculate left side result for verification
	var left_result: int
	if main_op == "+":
		left_result = a + b
	else:
		left_result = a - b
	
	# Build display strings
	# Format: a +/- b = a +/- 10 +/- c
	var left_display = str(a) + " " + main_op + " " + str(b)
	var right_display = str(a) + " " + main_op + " 10 " + main_op + " "
	var question_text = left_display + " = " + right_display
	
	return {
		"operands": [
			{"a": a, "b": b, "op": main_op, "result": left_result},
			{"a": a, "b": 10, "op1": main_op, "op2": main_op}
		],
		"operator": "=",
		"result": c,
		"expression": question_text + str(c),
		"question": question_text,
		"title": config.get("name", "Equivalence - Place Value"),
		"grade": "",
		"type": "equivalence_place_value"
	}

# ============================================
# Decimal Problem Generation
# ============================================

func _generate_decimal_comparison_problem(config: Dictionary) -> Dictionary:
	"""Generate a decimal comparison problem (0.01 to 9.99)"""
	# Generate first operand
	var operand1 = _generate_decimal_operand(0.01, 9.99)
	
	# Generate 10 candidates for second operand, pick the closest to operand1
	var best_operand2 = 0.0
	var min_diff = 999999.0
	
	for _i in range(10):
		var candidate = _generate_decimal_operand(0.01, 9.99)
		# Ensure not equal
		if abs(candidate - operand1) < 0.001:
			continue
		var diff = abs(candidate - operand1)
		if diff < min_diff:
			min_diff = diff
			best_operand2 = candidate
	
	# If all 10 were equal (very unlikely), just generate a different one
	if min_diff > 999990.0:
		best_operand2 = operand1 + (0.01 if rng.randi() % 2 == 0 else -0.01)
		best_operand2 = clamp(best_operand2, 0.01, 9.99)
	
	var operand2 = best_operand2
	var result = "<" if operand1 < operand2 else ">"
	
	# Format operands for display (no trailing zeros)
	var op1_display = _format_decimal_clean(operand1)
	var op2_display = _format_decimal_clean(operand2)
	
	return {
		"operands": [operand1, operand2],
		"operator": "?",
		"result": result,
		"expression": op1_display + " ? " + op2_display + " = " + result,
		"question": op1_display + " ? " + op2_display,
		"title": config.get("name", "Decimal Comparison"),
		"grade": "",
		"type": "decimal_comparison"
	}

func _generate_decimal_add_sub_problem(config: Dictionary) -> Dictionary:
	"""Generate a decimal addition/subtraction problem (0.01 to 9.99, max answer 10)"""
	var operators = config.get("operators", ["+", "-"])
	var operator = operators[rng.randi() % operators.size()]
	
	var operand1: float
	var operand2: float
	var result: float
	var attempts = 0
	
	while attempts < 100:
		operand1 = _generate_decimal_operand(0.01, 9.99)
		operand2 = _generate_decimal_operand(0.01, 9.99)
		
		if operator == "+":
			result = operand1 + operand2
			# Ensure result doesn't exceed 10
			if result <= 10.0:
				break
		else:  # "-"
			# Ensure no negative result
			if operand1 >= operand2:
				result = operand1 - operand2
				break
			else:
				# Swap operands
				var temp = operand1
				operand1 = operand2
				operand2 = temp
				result = operand1 - operand2
				break
		
		attempts += 1
	
	# Round result to 2 decimal places
	result = snapped(result, 0.01)
	
	# Format for display (no trailing zeros)
	var op1_display = _format_decimal_clean(operand1)
	var op2_display = _format_decimal_clean(operand2)
	var result_display = _format_decimal_clean(result)
	var question_text = op1_display + " " + operator + " " + op2_display
	
	return {
		"operands": [operand1, operand2],
		"operator": operator,
		"result": result,
		"expression": question_text + " = " + result_display,
		"question": question_text,
		"title": config.get("name", "Decimal Add/Subtract"),
		"grade": "",
		"type": "decimal_add_sub"
	}

func _generate_decimal_operand(min_val: float, max_val: float) -> float:
	"""Generate a random decimal value between min and max (to hundredths)"""
	# Generate in hundredths to avoid floating point issues
	var min_hundredths = int(min_val * 100)
	var max_hundredths = int(max_val * 100)
	var value_hundredths = rng.randi_range(min_hundredths, max_hundredths)
	return value_hundredths / 100.0

func _generate_true_decimal_operand(min_val: float, max_val: float) -> float:
	"""Generate a random decimal value that is never a whole number"""
	var attempts = 0
	while attempts < 100:
		var value = _generate_decimal_operand(min_val, max_val)
		# Check if it's NOT a whole number (has a fractional part)
		if abs(value - round(value)) >= 0.001:
			return value
		attempts += 1
	# Fallback: return a guaranteed decimal
	return 0.01

func _format_decimal_for_display(value: float) -> String:
	"""Format a decimal value for display with trailing zeros (e.g., 12.50)"""
	# Use snapped to ensure proper rounding
	value = snapped(value, 0.01)
	var str_val = str(value)
	
	# Handle integers
	if not "." in str_val:
		return str_val + ".00"
	
	# Ensure we have exactly 2 decimal places
	var parts = str_val.split(".")
	if parts.size() == 2:
		while parts[1].length() < 2:
			parts[1] += "0"
		# Truncate if more than 2
		if parts[1].length() > 2:
			parts[1] = parts[1].substr(0, 2)
		return parts[0] + "." + parts[1]
	
	return str_val

func _format_decimal_clean(value: float) -> String:
	"""Format a decimal value without trailing zeros (e.g., 9.1 not 9.10, 9 not 9.00)"""
	# Use snapped to ensure proper rounding
	value = snapped(value, 0.01)
	
	# Check if it's effectively a whole number
	if abs(value - round(value)) < 0.001:
		return str(int(round(value)))
	
	# Check if it has only one decimal place
	var hundredths = int(round(value * 100)) % 10
	if hundredths == 0:
		# Only one decimal place needed
		return str(snapped(value, 0.1))
	
	# Need two decimal places
	var str_val = str(value)
	if "." in str_val:
		var parts = str_val.split(".")
		if parts.size() == 2 and parts[1].length() > 2:
			parts[1] = parts[1].substr(0, 2)
			return parts[0] + "." + parts[1]
	
	return str_val

# ============================================
# Fraction Problem Generation
# ============================================

const FRACTION_DENOMINATORS = [2, 3, 4, 5, 6, 8, 10]

func _generate_fraction_comparison_problem(config: Dictionary) -> Dictionary:
	"""Generate a fraction comparison problem with unlike denominators"""
	# Generate first fraction
	var denom1 = FRACTION_DENOMINATORS[rng.randi() % FRACTION_DENOMINATORS.size()]
	var numer1 = rng.randi_range(1, denom1 - 1)  # Proper fraction
	var frac1_value = float(numer1) / float(denom1)
	
	# Generate 10 candidates for second fraction, pick the closest
	var best_numer2 = 0
	var best_denom2 = 2
	var min_diff = 999999.0
	
	for _i in range(10):
		# Use a different denominator
		var denom2 = FRACTION_DENOMINATORS[rng.randi() % FRACTION_DENOMINATORS.size()]
		var numer2 = rng.randi_range(1, denom2 - 1)
		var frac2_value = float(numer2) / float(denom2)
		
		# Ensure fractions are not equal in value
		if abs(frac2_value - frac1_value) < 0.001:
			continue
		
		var diff = abs(frac2_value - frac1_value)
		if diff < min_diff:
			min_diff = diff
			best_numer2 = numer2
			best_denom2 = denom2
	
	# Fallback if all were equal (shouldn't happen with proper fractions)
	if min_diff > 999990.0:
		best_denom2 = FRACTION_DENOMINATORS[(FRACTION_DENOMINATORS.find(denom1) + 1) % FRACTION_DENOMINATORS.size()]
		best_numer2 = 1
	
	var frac2_value_final = float(best_numer2) / float(best_denom2)
	var result = "<" if frac1_value < frac2_value_final else ">"
	
	var op1_display = str(numer1) + "/" + str(denom1)
	var op2_display = str(best_numer2) + "/" + str(best_denom2)
	
	return {
		"operands": [{"numerator": numer1, "denominator": denom1}, {"numerator": best_numer2, "denominator": best_denom2}],
		"operator": "?",
		"result": result,
		"expression": op1_display + " ? " + op2_display + " = " + result,
		"question": op1_display + " ? " + op2_display,
		"title": config.get("name", "Fraction Comparison"),
		"grade": "",
		"type": "fraction_comparison"
	}

func _generate_mixed_numbers_like_denom_problem(config: Dictionary) -> Dictionary:
	"""Generate a mixed number addition/subtraction problem with like denominators"""
	var operators = config.get("operators", ["+", "-"])
	var operator = operators[rng.randi() % operators.size()]
	
	# Generate a common denominator
	var common_denom = FRACTION_DENOMINATORS[rng.randi() % FRACTION_DENOMINATORS.size()]
	
	var whole1: int
	var numer1: int
	var whole2: int
	var numer2: int
	var result_whole: int
	var result_numer: int
	var result_denom: int = common_denom
	var attempts = 0
	
	while attempts < 100:
		# Generate mixed numbers
		whole1 = rng.randi_range(1, 9)
		numer1 = rng.randi_range(1, common_denom - 1)
		whole2 = rng.randi_range(1, 9)
		numer2 = rng.randi_range(1, common_denom - 1)
		
		# Calculate result as improper fraction first
		var total_numer1 = whole1 * common_denom + numer1
		var total_numer2 = whole2 * common_denom + numer2
		var result_numer_total: int
		
		if operator == "+":
			result_numer_total = total_numer1 + total_numer2
		else:  # "-"
			result_numer_total = total_numer1 - total_numer2
		
		# Check constraints: result >= 0 and result <= 10
		if result_numer_total < 0:
			attempts += 1
			continue
		
		result_whole = result_numer_total / common_denom
		result_numer = result_numer_total % common_denom
		
		var result_value = float(result_whole) + float(result_numer) / float(common_denom)
		if result_value > 10.0:
			attempts += 1
			continue
		
		# Valid result found
		break
	
	# Format operands
	var op1_str = str(whole1) + " " + str(numer1) + "/" + str(common_denom)
	var op2_str = str(whole2) + " " + str(numer2) + "/" + str(common_denom)
	
	# Format result
	var result_str: String
	if result_numer == 0:
		result_str = str(result_whole)
	elif result_whole == 0:
		result_str = str(result_numer) + "/" + str(result_denom)
	else:
		result_str = str(result_whole) + " " + str(result_numer) + "/" + str(result_denom)
	
	var question_text = op1_str + " " + operator + " " + op2_str
	
	return {
		"operands": [
			{"whole": whole1, "numerator": numer1, "denominator": common_denom},
			{"whole": whole2, "numerator": numer2, "denominator": common_denom}
		],
		"operator": operator,
		"result": result_str,
		"expression": question_text + " = " + result_str,
		"question": question_text,
		"title": config.get("name", "Mixed Numbers"),
		"grade": "",
		"type": "mixed_numbers_like_denom"
	}

# ============================================
# Grade 5 Problem Generation
# ============================================

func _generate_decimal_multiply_divide_problem(config: Dictionary) -> Dictionary:
	"""Generate a decimal multiply/divide problem with one whole number operand (1-10)
	The decimal operand is always a true decimal (never a whole number), answer terminates at hundredths or earlier, answer <= 10"""
	var operators = config.get("operators", ["x", "/"])
	var operator = operators[rng.randi() % operators.size()]
	
	var decimal_operand: float
	var whole_operand: int
	var result: float
	var attempts = 0
	
	while attempts < 100:
		whole_operand = rng.randi_range(1, 10)
		
		if operator == "x":
			# For multiplication: decimal × whole
			decimal_operand = _generate_true_decimal_operand(0.01, 10.0)
			result = decimal_operand * whole_operand
			
			# Check if result <= 10 and terminates at hundredths
			if result <= 10.0:
				var result_hundredths = result * 100.0
				if abs(result_hundredths - round(result_hundredths)) < 0.0001:
					result = snapped(result, 0.01)
					break
		else:  # "/"
			# For division: generate result and whole divisor, calculate dividend
			result = _generate_decimal_operand(0.01, 10.0)
			decimal_operand = result * whole_operand
			
			# Check if dividend is within range, terminates at hundredths, and is not a whole number
			if decimal_operand >= 0.01 and decimal_operand <= 10.0:
				var op_hundredths = decimal_operand * 100.0
				if abs(op_hundredths - round(op_hundredths)) < 0.0001:
					decimal_operand = snapped(decimal_operand, 0.01)
					# Ensure decimal operand is not a whole number
					if abs(decimal_operand - round(decimal_operand)) >= 0.001:
						break
		
		attempts += 1
	
	# Format operands - decimal first, then whole number
	var operand1: float = decimal_operand
	var operand2: float = float(whole_operand)
	
	var op1_display = _format_decimal_clean(operand1)
	var op2_display = str(int(operand2))  # Display whole number without decimals
	var result_display = _format_decimal_clean(result)
	var question_text = op1_display + " " + operator + " " + op2_display
	
	return {
		"operands": [operand1, operand2],
		"operator": operator,
		"result": result,
		"expression": question_text + " = " + result_display,
		"question": question_text,
		"title": config.get("name", "Decimal Multiply/Divide"),
		"grade": "",
		"type": "decimal_multiply_divide"
	}

func _generate_fractions_unlike_denom_problem(config: Dictionary) -> Dictionary:
	"""Generate an add/subtract fractions problem with unlike denominators"""
	var operators = config.get("operators", ["+", "-"])
	var operator = operators[rng.randi() % operators.size()]
	
	var denom1: int
	var numer1: int
	var denom2: int
	var numer2: int
	var lcm_denom: int
	var adj_numer1: int
	var adj_numer2: int
	var result_numer: int
	var attempts = 0
	
	while attempts < 100:
		# Generate first proper fraction
		denom1 = FRACTION_DENOMINATORS[rng.randi() % FRACTION_DENOMINATORS.size()]
		numer1 = rng.randi_range(1, denom1 - 1)
		
		# Generate second proper fraction with unlike denominator
		denom2 = FRACTION_DENOMINATORS[rng.randi() % FRACTION_DENOMINATORS.size()]
		while denom2 == denom1:
			denom2 = FRACTION_DENOMINATORS[rng.randi() % FRACTION_DENOMINATORS.size()]
		numer2 = rng.randi_range(1, denom2 - 1)
		
		# Calculate result using common denominator
		lcm_denom = _lcm(denom1, denom2)
		adj_numer1 = numer1 * (lcm_denom / denom1)
		adj_numer2 = numer2 * (lcm_denom / denom2)
		
		if operator == "+":
			result_numer = adj_numer1 + adj_numer2
		else:  # "-"
			result_numer = adj_numer1 - adj_numer2
		
		# For subtraction, ensure no negative result
		if operator == "-" and result_numer < 0:
			attempts += 1
			continue
		
		# Valid result found
		break
	
	var result_denom = lcm_denom
	
	# Simplify the result
	var gcd_val = _gcd(abs(result_numer), result_denom)
	var simplified_numer = result_numer / gcd_val
	var simplified_denom = result_denom / gcd_val
	
	var result_str = str(simplified_numer) + "/" + str(simplified_denom)
	if simplified_numer == 0:
		result_str = "0"
	
	var op1_str = str(numer1) + "/" + str(denom1)
	var op2_str = str(numer2) + "/" + str(denom2)
	var question_text = op1_str + " " + operator + " " + op2_str
	
	return {
		"operands": [
			{"numerator": numer1, "denominator": denom1},
			{"numerator": numer2, "denominator": denom2}
		],
		"operator": operator,
		"result": result_str,
		"result_numerator": simplified_numer,
		"result_denominator": simplified_denom,
		"expression": question_text + " = " + result_str,
		"question": question_text,
		"title": config.get("name", "Fractions Unlike Denominators"),
		"grade": "",
		"type": "fractions_unlike_denom"
	}

func _generate_mixed_to_improper_problem(config: Dictionary) -> Dictionary:
	"""Generate a convert mixed number to improper fraction problem"""
	# Generate mixed number: whole 1-9, fraction with proper numerator
	var denom = FRACTION_DENOMINATORS[rng.randi() % FRACTION_DENOMINATORS.size()]
	var numer = rng.randi_range(1, denom - 1)
	var whole = rng.randi_range(1, 9)
	
	# Calculate improper fraction
	var improper_numer = whole * denom + numer
	var improper_denom = denom
	
	# The unsimplified answer
	var result_str = str(improper_numer) + "/" + str(improper_denom)
	
	# Format mixed number for display
	var mixed_str = str(whole) + " " + str(numer) + "/" + str(denom)
	
	return {
		"operands": [
			{"whole": whole, "numerator": numer, "denominator": denom}
		],
		"operator": "=",
		"result": result_str,
		"result_numerator": improper_numer,
		"result_denominator": improper_denom,
		"expression": mixed_str + " = " + result_str,
		"question": mixed_str,
		"title": config.get("name", "Mixed to Improper"),
		"grade": "",
		"type": "mixed_to_improper"
	}

func _generate_improper_to_mixed_problem(config: Dictionary) -> Dictionary:
	"""Generate a convert improper fraction to mixed number problem"""
	# Generate improper fraction: numerator > denominator, value > 1 and <= 10
	var denom = FRACTION_DENOMINATORS[rng.randi() % FRACTION_DENOMINATORS.size()]
	
	# Numerator range: from (denom + 1) to (10 * denom) for value range (1, 10]
	var min_numer = denom + 1
	var max_numer = 10 * denom
	var numer = rng.randi_range(min_numer, max_numer)
	
	# Calculate mixed number
	var whole = numer / denom
	var remainder = numer % denom
	
	# Format result
	var result_str: String
	if remainder == 0:
		result_str = str(whole)  # Just a whole number
	else:
		result_str = str(whole) + " " + str(remainder) + "/" + str(denom)
	
	# Format improper fraction for display
	var improper_str = str(numer) + "/" + str(denom)
	
	return {
		"operands": [
			{"numerator": numer, "denominator": denom}
		],
		"operator": "=",
		"result": result_str,
		"result_whole": whole,
		"result_numerator": remainder,
		"result_denominator": denom,
		"expression": improper_str + " = " + result_str,
		"question": improper_str,
		"title": config.get("name", "Improper to Mixed"),
		"grade": "",
		"type": "improper_to_mixed"
	}

func _generate_multiply_divide_fractions_problem(config: Dictionary) -> Dictionary:
	"""Generate a multiply/divide proper and improper fractions problem"""
	var operators = config.get("operators", ["x", "/"])
	var operator = operators[rng.randi() % operators.size()]
	
	# Generate two fractions between 1/10 and 10 (can be proper or improper)
	var denom1 = FRACTION_DENOMINATORS[rng.randi() % FRACTION_DENOMINATORS.size()]
	var denom2 = FRACTION_DENOMINATORS[rng.randi() % FRACTION_DENOMINATORS.size()]
	
	# Numerator range: min 1, max is 10 * denom (for value up to 10)
	# But also ensure value >= 1/10, so numerator >= denom/10
	var min_numer1 = max(1, denom1 / 10)
	var max_numer1 = 10 * denom1
	var numer1 = rng.randi_range(min_numer1, max_numer1)
	
	var min_numer2 = max(1, denom2 / 10)
	var max_numer2 = 10 * denom2
	var numer2 = rng.randi_range(min_numer2, max_numer2)
	
	# Calculate result
	var result_numer: int
	var result_denom: int
	
	if operator == "x":
		result_numer = numer1 * numer2
		result_denom = denom1 * denom2
	else:  # "/"
		# Division: flip second fraction and multiply
		result_numer = numer1 * denom2
		result_denom = denom1 * numer2
	
	# Simplify result
	var gcd_val = _gcd(abs(result_numer), abs(result_denom))
	result_numer = result_numer / gcd_val
	result_denom = result_denom / gcd_val
	
	# Format result - convert to mixed number if improper
	var result_str: String
	if result_denom == 1:
		result_str = str(result_numer)
	elif abs(result_numer) >= result_denom:
		var whole = result_numer / result_denom
		var remainder = abs(result_numer) % result_denom
		if remainder == 0:
			result_str = str(whole)
		else:
			result_str = str(whole) + " " + str(remainder) + "/" + str(result_denom)
	else:
		result_str = str(result_numer) + "/" + str(result_denom)
	
	var op1_str = str(numer1) + "/" + str(denom1)
	var op2_str = str(numer2) + "/" + str(denom2)
	var question_text = op1_str + " " + operator + " " + op2_str
	
	return {
		"operands": [
			{"numerator": numer1, "denominator": denom1},
			{"numerator": numer2, "denominator": denom2}
		],
		"operator": operator,
		"result": result_str,
		"result_numerator": result_numer,
		"result_denominator": result_denom,
		"expression": question_text + " = " + result_str,
		"question": question_text,
		"title": config.get("name", "Multiply/Divide Fractions"),
		"grade": "",
		"type": "multiply_divide_fractions"
	}

func _lcm(a: int, b: int) -> int:
	"""Calculate the least common multiple of two numbers"""
	return abs(a * b) / _gcd(a, b)

func _gcd(a: int, b: int) -> int:
	"""Calculate the greatest common divisor of two numbers"""
	while b != 0:
		var temp = b
		b = a % b
		a = temp
	return a

# ============================================
# Number Line Problem Generation
# ============================================

func _generate_number_line_fractions_problem(config: Dictionary) -> Dictionary:
	"""Generate a number line fractions problem (place fraction on number line)"""
	var denominators = config.get("denominators", [2, 4, 8])
	var total_pips = config.get("total_pips", 9)
	var lower_limit = config.get("lower_limit", 0)
	var upper_limit = config.get("upper_limit", 1)
	
	# Randomly select a denominator
	var denominator = denominators[rng.randi() % denominators.size()]
	
	# Generate a numerator between 1 and (denominator - 1) inclusive
	var numerator = rng.randi_range(1, denominator - 1)
	
	# Calculate the correct pip index
	# For a fraction n/d with (total_pips - 1) intervals from 0 to 1:
	# correct_pip = n * ((total_pips - 1) / d)
	var intervals = total_pips - 1  # 8 intervals for 9 pips
	var correct_pip = numerator * (intervals / denominator)
	
	# Build the fraction string for display and result
	var fraction_str = str(numerator) + "/" + str(denominator)
	
	return {
		"operands": [{"numerator": numerator, "denominator": denominator}],
		"operator": "=",
		"result": fraction_str,
		"correct_pip": correct_pip,
		"total_pips": total_pips,
		"lower_limit": lower_limit,
		"upper_limit": upper_limit,
		"frame": config.get("frame", 0),
		"control_mode": config.get("control_mode", "pip_to_pip"),
		"expression": fraction_str,
		"question": fraction_str,
		"title": config.get("name", "Number Line Fractions"),
		"grade": "",
		"type": "number_line_fractions"
	}

func _generate_number_line_fractions_extended_problem(config: Dictionary) -> Dictionary:
	"""Generate an extended number line fractions problem (0-3 range, mixed numbers and proper fractions)"""
	var denominators = config.get("denominators", [2, 3, 4, 5, 6, 8, 10])
	var total_pips = config.get("total_pips", 13)
	var lower_limit = config.get("lower_limit", 0)
	var upper_limit = config.get("upper_limit", 3)
	var frame_idx = config.get("frame", 1)
	var control_mode = config.get("control_mode", "continuous")
	
	# Build a pool of all valid fractions for even distribution
	# Valid fractions: proper fractions (< 1) and mixed numbers (1 <= x < 3, not integers)
	var fraction_pool = []
	
	for denom in denominators:
		# Proper fractions: 1/d, 2/d, ..., (d-1)/d
		for numer in range(1, denom):
			fraction_pool.append({"whole": 0, "numerator": numer, "denominator": denom})
		
		# Mixed numbers with whole part 1: 1 1/d, 1 2/d, ..., 1 (d-1)/d
		for numer in range(1, denom):
			fraction_pool.append({"whole": 1, "numerator": numer, "denominator": denom})
		
		# Mixed numbers with whole part 2: 2 1/d, 2 2/d, ..., 2 (d-1)/d
		for numer in range(1, denom):
			fraction_pool.append({"whole": 2, "numerator": numer, "denominator": denom})
	
	# Randomly select a fraction from the pool
	var selected = fraction_pool[rng.randi() % fraction_pool.size()]
	var whole = selected.whole
	var numerator = selected.numerator
	var denominator = selected.denominator
	
	# Calculate the decimal value for correct answer position
	var decimal_value = float(whole) + float(numerator) / float(denominator)
	
	# Build the fraction string for display and result
	var fraction_str: String
	if whole > 0:
		fraction_str = str(whole) + " " + str(numerator) + "/" + str(denominator)
	else:
		fraction_str = str(numerator) + "/" + str(denominator)
	
	return {
		"operands": [{"whole": whole, "numerator": numerator, "denominator": denominator}],
		"operator": "=",
		"result": fraction_str,
		"correct_value": decimal_value,
		"total_pips": total_pips,
		"lower_limit": lower_limit,
		"upper_limit": upper_limit,
		"frame": frame_idx,
		"control_mode": control_mode,
		"expression": fraction_str,
		"question": fraction_str,
		"title": config.get("name", "Number Line Fractions Extended"),
		"grade": "",
		"type": "number_line_fractions_extended"
	}

# ============================================
# Equivalence Multiplication Factoring Problem Generation
# ============================================

func _generate_equivalence_mult_factoring_problem(config: Dictionary) -> Dictionary:
	"""Generate an equivalence multiplication problem using factoring.
	Format: a × b = c × ___ × ___
	Where c divides exactly one of a or b, quotient is 2-10, and all numbers ≤99.
	
	Examples:
	- 17 × 24 = 4 × 6 × 17 (24/4 = 6)
	- 28 × 13 = 7 × 4 × 13 (28/7 = 4)
	- 7 × 70 = 10 × 7 × 7 (70/10 = 7)
	"""
	
	var attempts = 0
	var max_attempts = 100
	
	while attempts < max_attempts:
		# Pick a factor c from {3, 4, 5, 6, 7, 8, 9, 10}
		var c = rng.randi_range(3, 10)
		
		# Generate quotient q (2-10, must not be 1)
		var q = rng.randi_range(2, 10)
		
		# The divisible operand = c × q
		var divisible = c * q
		
		# Ensure divisible operand is ≤99
		if divisible > 99:
			attempts += 1
			continue
		
		# Generate the other operand (2-99, must NOT be divisible by c)
		var other = rng.randi_range(2, 99)
		
		# Ensure other is not divisible by c
		if other % c == 0:
			attempts += 1
			continue
		
		# Now we have: divisible × other = c × q × other
		# Randomly decide which operand is a and which is b (50/50)
		var a: int
		var b: int
		if rng.randi() % 2 == 0:
			a = divisible
			b = other
		else:
			a = other
			b = divisible
		
		# Build the question and answer data
		# The expected answers are q and other (order doesn't matter)
		# We store the product for validation: c × ans1 × ans2 should equal a × b
		var product = a * b
		
		# Format: "a x b = c x _ x"
		var question_text = str(a) + " x " + str(b) + " = " + str(c) + " x _ x"
		var expression = str(a) + " x " + str(b) + " = " + str(c) + " x " + str(q) + " x " + str(other)
		
		return {
			"operands": [a, b],
			"operator": "x",
			"result": product,  # Store product for validation
			"given_factor": c,  # The factor given in the problem
			"expected_answers": [q, other],  # For reference (order-independent)
			"expression": expression,
			"question": question_text,
			"title": config.get("name", "Equivalence Multiplication Factoring"),
			"grade": "",
			"type": "equivalence_mult_factoring"
		}
	
	# Fallback if we couldn't generate a valid problem
	# Use a guaranteed valid example: 17 × 24 = 4 × 6 × 17
	return {
		"operands": [17, 24],
		"operator": "x",
		"result": 408,
		"given_factor": 4,
		"expected_answers": [6, 17],
		"expression": "17 x 24 = 4 x 6 x 17",
		"question": "17 x 24 = 4 x _ x",
		"title": config.get("name", "Equivalence Multiplication Factoring"),
		"grade": "",
		"type": "equivalence_mult_factoring"
	}

func get_question_key(question_data):
	"""Generate a unique key for a question based on its operands and operator"""
	# Handle equivalence problems specially - they use expression as key
	if question_data.has("operator") and question_data.operator == "equivalent_missing":
		return question_data.get("expression", "unknown_equivalence")
	
	# Handle fraction questions (operands are arrays) vs regular questions (operands are numbers)
	var op1_str = ""
	var op2_str = ""
	
	# Check if operands exist and are accessible
	if not question_data.has("operands") or question_data.operands == null or question_data.operands.size() < 2:
		# Parse operands from expression (for mixed fraction problems)
		if question_data.has("expression") and question_data.expression != "":
			var expr = question_data.expression.split(" = ")[0]
			var expr_parts = expr.split(" ")
			var operator_idx = -1
			for i in range(expr_parts.size()):
				if expr_parts[i] == question_data.operator:
					operator_idx = i
					break
			
			if operator_idx > 0:
				# Parse operand1
				var operand1_str = ""
				for i in range(operator_idx):
					if operand1_str != "":
						operand1_str += " "
					operand1_str += expr_parts[i]
				op1_str = operand1_str
				
				# Parse operand2
				var operand2_str = ""
				for i in range(operator_idx + 1, expr_parts.size()):
					if operand2_str != "":
						operand2_str += " "
					operand2_str += expr_parts[i]
				op2_str = operand2_str
			else:
				# Fallback - use expression as-is
				op1_str = question_data.get("expression", "unknown")
				op2_str = ""
		else:
			# No expression available - use placeholder
			op1_str = "unknown"
			op2_str = "unknown"
	else:
		# Handle operands individually (could be arrays, numbers, or mixed)
		var operand1 = question_data.operands[0]
		var operand2 = question_data.operands[1]
		
		# Format operand 1
		if typeof(operand1) == TYPE_ARRAY and operand1.size() >= 2:
			# Fraction - format as "num/denom", converting floats to ints
			var num1 = operand1[0]
			var denom1 = operand1[1]
			if typeof(num1) == TYPE_FLOAT:
				num1 = int(num1)
			if typeof(denom1) == TYPE_FLOAT:
				denom1 = int(denom1)
			op1_str = str(num1) + "/" + str(denom1)
		else:
			# Whole number - convert float to int if it's a whole number
			if typeof(operand1) == TYPE_FLOAT:
				op1_str = str(int(operand1))
			else:
				op1_str = str(operand1)
		
		# Format operand 2
		if typeof(operand2) == TYPE_ARRAY and operand2.size() >= 2:
			# Fraction - format as "num/denom", converting floats to ints
			var num2 = operand2[0]
			var denom2 = operand2[1]
			if typeof(num2) == TYPE_FLOAT:
				num2 = int(num2)
			if typeof(denom2) == TYPE_FLOAT:
				denom2 = int(denom2)
			op2_str = str(num2) + "/" + str(denom2)
		else:
			# Whole number - convert float to int if it's a whole number
			if typeof(operand2) == TYPE_FLOAT:
				op2_str = str(int(operand2))
			else:
				op2_str = str(operand2)
	
	return op1_str + "_" + question_data.operator + "_" + op2_str

func calculate_question_weight(question_data):
	"""Calculate the weight for a single question based on historical data"""
	var question_key = get_question_key(question_data)
	var base_weight = 1.0
	var weight_details = []
	
	# Get historical data for this question
	var question_history = []
	if SaveManager.save_data.questions.has(question_key):
		question_history = SaveManager.save_data.questions[question_key]
	
	var total_answers = question_history.size()
	var incorrect_count = 0
	
	# Count incorrect answers
	for answer_record in question_history:
		# Convert both to strings for safe comparison (handles mixed types)
		var player_ans_str = str(answer_record.player_answer)
		var result_str = str(answer_record.result)
		if player_ans_str != result_str:
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
		# Convert both to strings for safe comparison (handles mixed types)
		var player_ans_str = str(answer_record.player_answer)
		var result_str = str(answer_record.result)
		var is_correct = (player_ans_str == result_str)
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
	if not math_facts.has("levels"):
		print("No math facts data available")
		return
	
	# Handle both string track IDs (like "FRAC-07") and numeric track IDs
	var track_key = str(track) if typeof(track) == TYPE_STRING else "TRACK" + str(track)
	var questions = []
	
	# Find questions from specific track
	for level in math_facts.levels:
		if level.id == track_key:
			questions = level.facts
			break
	
	# If track not found, pick random existing track (fallback)
	if questions.is_empty():
		if not math_facts.levels.is_empty():
			var random_level = math_facts.levels[rng.randi() % math_facts.levels.size()]
			questions = random_level.facts
	
	print("=== Question Weight Calculations for Track ", track, " ===")
	
	# Calculate weights for all questions
	for question in questions:
		var question_key = get_question_key(question)
		available_questions.append(question_key)
		
		var weight_result = calculate_question_weight(question)
		question_weights[question_key] = weight_result.weight
		
		# Format question display
		var question_text = ""
		if not question.has("operands") or question.operands == null or question.operands.size() < 2:
			# Mixed fraction or expression-based question
			question_text = question.expression if question.has("expression") else ""
		elif typeof(question.operands[0]) == TYPE_ARRAY:
			# Regular fraction question
			question_text = question.expression if question.has("expression") else ""
		else:
			# Regular question with numeric operands
			var operand1 = question.operands[0]
			var operand2 = question.operands[1]
			if typeof(operand1) == TYPE_FLOAT and operand1 == int(operand1):
				operand1 = int(operand1)
			if typeof(operand2) == TYPE_FLOAT and operand2 == int(operand2):
				operand2 = int(operand2)
			question_text = str(operand1) + " " + question.operator + " " + str(operand2) + " = " + str(question.result)
		
		print("Question: ", question_text)
		print("- Base weight: 1.0")
		for detail in weight_result.details:
			print("- ", detail)
		print("- Final weight: %.3f" % weight_result.weight)
		print("")
	
	print("Total questions available: ", available_questions.size())
	print("==========================================")
	print("")

func initialize_question_weights_for_all_tracks():
	"""Initialize question weights for all questions from all tracks in all level packs"""
	# Clear previous data
	question_weights.clear()
	unavailable_questions.clear()
	available_questions.clear()
	
	print("=== Question Weight Calculations for Drill Mode (First 4 Packs, Standard Problems Only) ===")
	
	# Get questions from only the first 4 level packs (excluding Fractions)
	var drill_mode_packs = ["Addition", "Subtraction", "Multiplication", "Division"]
	
	for pack_name in drill_mode_packs:
		var pack_config = GameConfig.legacy_level_packs[pack_name]
		for track in pack_config.levels:
			var track_key = str(track) if typeof(track) == TYPE_STRING else "TRACK" + str(track)
			var questions = []
			
			# Find questions from this track
			for level in math_facts.levels:
				if level.id == track_key:
					questions = level.facts
					break
			
			print("Processing Track ", track, " from pack ", pack_name, " (", questions.size(), " questions)")
			
			# Calculate weights for standard (non-fraction) questions in this track
			var standard_count = 0
			for question in questions:
				# Skip fraction-type questions
				var question_type = question.get("type", "")
				if is_fraction_display_type(question_type):
					continue
				
				standard_count += 1
				var question_key = get_question_key(question)
				available_questions.append(question_key)
				
				var weight_result = calculate_question_weight(question)
				question_weights[question_key] = weight_result.weight
				
				# Format question display for debug
				var question_text = ""
				if not question.has("operands") or question.operands == null or question.operands.size() < 2:
					# Mixed fraction or expression-based question
					question_text = question.expression if question.has("expression") else ""
				elif typeof(question.operands[0]) == TYPE_ARRAY:
					# Regular fraction question
					question_text = question.expression if question.has("expression") else ""
				else:
					# Regular question with numeric operands
					var operand1 = question.operands[0]
					var operand2 = question.operands[1]
					if typeof(operand1) == TYPE_FLOAT and operand1 == int(operand1):
						operand1 = int(operand1)
					if typeof(operand2) == TYPE_FLOAT and operand2 == int(operand2):
						operand2 = int(operand2)
					question_text = str(operand1) + " " + question.operator + " " + str(operand2) + " = " + str(question.result)
				
				print("  Question: ", question_text, " (weight: %.3f)" % weight_result.weight)
			
			print("  Standard questions in this track: ", standard_count)
	
	print("Total questions available for drill mode: ", available_questions.size())
	print("==========================================")

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
				var question_text = ""
				var display_text = ""
				
				# Check if operands exist and determine question type
				if not selected_question.has("operands") or selected_question.operands == null or selected_question.operands.size() < 2:
					# Mixed fraction, expression-based question, or equivalence problem
					question_text = selected_question.expression if selected_question.has("expression") else ""
					# For equivalence problems, use full expression; for others, split
					if selected_question.has("operator") and selected_question.operator == "equivalent_missing":
						display_text = question_text  # Keep full expression for equivalence
					else:
						display_text = question_text.split(" = ")[0] if question_text else ""
				elif typeof(selected_question.operands[0]) == TYPE_ARRAY or typeof(selected_question.operands[1]) == TYPE_ARRAY:
					# Regular fraction question - use expression, or construct from operands if needed
					if selected_question.has("expression") and selected_question.expression != "" and not selected_question.expression.contains("["):
						# Expression exists and doesn't contain malformed array notation
						question_text = selected_question.expression
						display_text = question_text.split(" = ")[0]
					else:
						# Fallback: construct from operands
						var op1 = selected_question.operands[0]
						var op2 = selected_question.operands[1]
						var op1_str = ""
						var op2_str = ""
						
						# Format operand 1
						if typeof(op1) == TYPE_ARRAY and op1.size() >= 2:
							op1_str = str(int(op1[0])) + "/" + str(int(op1[1]))
						else:
							op1_str = str(int(op1) if typeof(op1) == TYPE_FLOAT else op1)
						
						# Format operand 2
						if typeof(op2) == TYPE_ARRAY and op2.size() >= 2:
							op2_str = str(int(op2[0])) + "/" + str(int(op2[1]))
						else:
							op2_str = str(int(op2) if typeof(op2) == TYPE_FLOAT else op2)
						
						display_text = op1_str + " " + selected_question.operator + " " + op2_str
						question_text = display_text + " = " + str(selected_question.result)
				else:
					# Regular question with numeric operands - format integers
					var operand1 = selected_question.operands[0]
					var operand2 = selected_question.operands[1]
					if typeof(operand1) == TYPE_FLOAT and operand1 == int(operand1):
						operand1 = int(operand1)
					if typeof(operand2) == TYPE_FLOAT and operand2 == int(operand2):
						operand2 = int(operand2)
					question_text = str(operand1) + " " + selected_question.operator + " " + str(operand2) + " = " + str(selected_question.result)
					display_text = str(operand1) + " " + selected_question.operator + " " + str(operand2)
				
				print("Selected question: ", question_text, " (weight: %.3f)" % selected_weight)
				
				return {
					"operands": selected_question.get("operands", []),
					"operator": selected_question.operator,
					"result": selected_question.result,
					"expression": selected_question.get("expression", ""),
					"question": display_text,
					"title": "",  # Will be filled by caller if needed
					"grade": "",  # Will be filled by caller if needed
					"type": selected_question.get("type", "")  # Include type if it exists (default to empty string)
				}
			else:
				print("Error: Could not find question data for key: ", selected_key)
				return null
	
	# Fallback (should never reach here)
	print("Error: Weighted selection failed")
	return null

# ============================================
# Assessment Mode Question Generation
# ============================================

var is_assessment_mode = false  # Flag for assessment-specific generation

func set_assessment_mode(enabled: bool):
	"""Enable or disable assessment mode for range-specific generation"""
	is_assessment_mode = enabled
	if enabled:
		used_questions_this_level.clear()

func generate_assessment_question(standard_data: Dictionary) -> Dictionary:
	"""Generate a question for assessment mode using the standard's config
	This handles the special range isolation for overlapping standards
	standard_data has structure: {id, name, target_cqpm, is_multiple_choice, config: {...}}
	"""
	
	# Extract the inner config and add the name
	var inner_config = standard_data.get("config", {}).duplicate()
	inner_config["name"] = standard_data.get("name", "Assessment")
	
	# Set the config temporarily for generation
	current_level_config = inner_config
	is_assessment_mode = true
	
	# Clear used questions when starting a new standard
	used_questions_this_level.clear()
	
	var max_attempts = 100
	var attempts = 0
	var question_data: Dictionary
	var question_key: String
	
	while attempts < max_attempts:
		# Check for special problem types first
		var problem_type = current_level_config.get("type", "")
		if problem_type != "":
			question_data = _generate_special_type_question(problem_type, current_level_config)
		else:
			var operators = current_level_config.get("operators", ["+"])
			var selected_operator = operators[rng.randi() % operators.size()]
			question_data = _generate_assessment_question_for_operator(selected_operator, current_level_config)
		
		if question_data.is_empty():
			attempts += 1
			continue
		
		question_key = _get_dynamic_question_key(question_data)
		
		# Check if this question has been used
		if not used_questions_this_level.has(question_key):
			used_questions_this_level[question_key] = true
			return question_data
		
		attempts += 1
	
	# If we've exhausted attempts, reset and try once more
	print("[Assessment] Ran out of unique questions, resetting used questions list")
	used_questions_this_level.clear()
	
	var problem_type = current_level_config.get("type", "")
	if problem_type != "":
		question_data = _generate_special_type_question(problem_type, current_level_config)
	else:
		var operators = current_level_config.get("operators", ["+"])
		var selected_operator = operators[rng.randi() % operators.size()]
		question_data = _generate_assessment_question_for_operator(selected_operator, current_level_config)
	
	question_key = _get_dynamic_question_key(question_data)
	used_questions_this_level[question_key] = true
	return question_data

func _generate_assessment_question_for_operator(operator: String, config: Dictionary) -> Dictionary:
	"""Generate a question for the given operator with assessment-specific range handling"""
	match operator:
		"+":
			return _generate_assessment_addition_problem(config)
		"-":
			return _generate_assessment_subtraction_problem(config)
		"x":
			return _generate_multiplication_problem(config)  # Use existing, config has assessment ranges
		"/":
			return _generate_division_problem(config)  # Use existing, config has assessment ranges
	return {}

func _generate_assessment_addition_problem(config: Dictionary) -> Dictionary:
	"""Generate an addition problem with assessment-specific range isolation"""
	var operand1: int
	var operand2: int
	var result: int
	
	# Check for sum_min/sum_max range isolation (for overlapping standards)
	if config.has("sum_min") and config.has("sum_max"):
		var sum_min = config.sum_min
		var sum_max = config.sum_max
		var attempts = 0
		
		while attempts < 100:
			# Generate a sum in the range [sum_min, sum_max]
			result = rng.randi_range(sum_min, sum_max)
			# Generate operand1 such that operand2 is valid
			operand1 = rng.randi_range(0, result)
			operand2 = result - operand1
			
			# Both operands should be non-negative (always true with this method)
			if operand1 >= 0 and operand2 >= 0:
				break
			
			attempts += 1
	elif config.has("sum_max"):
		# Standard "Sums to X" style (no minimum constraint)
		var sum_max = config.sum_max
		operand1 = rng.randi_range(0, sum_max)
		operand2 = rng.randi_range(0, sum_max - operand1)
		result = operand1 + operand2
	elif config.has("digit_count"):
		# Multi-digit addition (defer to existing function)
		return _generate_addition_problem(config)
	else:
		# Fallback
		operand1 = rng.randi_range(0, 10)
		operand2 = rng.randi_range(0, 10)
		result = operand1 + operand2
	
	var question_text = str(operand1) + " + " + str(operand2)
	
	return {
		"operands": [operand1, operand2],
		"operator": "+",
		"result": result,
		"expression": question_text + " = " + str(result),
		"question": question_text,
		"title": config.get("name", "Addition"),
		"grade": "",
		"type": ""
	}

func _generate_assessment_subtraction_problem(config: Dictionary) -> Dictionary:
	"""Generate a subtraction problem with assessment-specific range isolation"""
	var operand1: int
	var operand2: int
	var result: int
	
	# Check for range_min/range_max isolation (for overlapping standards)
	if config.has("range_min") and config.has("range_max"):
		var range_min = config.range_min
		var range_max = config.range_max
		var attempts = 0
		
		while attempts < 100:
			# First operand must be in [range_min, range_max]
			operand1 = rng.randi_range(range_min, range_max)
			# Second operand must be <= first operand to avoid negative results
			operand2 = rng.randi_range(0, operand1)
			result = operand1 - operand2
			
			# Valid problem found
			if result >= 0:
				break
			
			attempts += 1
	elif config.has("range_max"):
		# Standard "Subtraction 0-X" style (no minimum constraint)
		return _generate_subtraction_problem(config)
	elif config.has("digit_count"):
		# Multi-digit subtraction (defer to existing function)
		return _generate_subtraction_problem(config)
	else:
		# Fallback
		operand1 = rng.randi_range(0, 10)
		operand2 = rng.randi_range(0, operand1)
		result = operand1 - operand2
	
	var question_text = str(operand1) + " - " + str(operand2)
	
	return {
		"operands": [operand1, operand2],
		"operator": "-",
		"result": result,
		"expression": question_text + " = " + str(result),
		"question": question_text,
		"title": config.get("name", "Subtraction"),
		"grade": "",
		"type": ""
	}

func find_question_by_key(question_key):
	"""Find a question in math_facts by its key"""
	# Handle equivalence problems - they use expression as key
	if question_key.contains(" = ") and not question_key.contains("_"):
		# This is an equivalence problem key (expression format)
		for level in math_facts.levels:
			for question in level.facts:
				if question.has("operator") and question.operator == "equivalent_missing":
					if question.get("expression", "") == question_key:
						return question
		return null
	
	var parts = question_key.split("_")
	if parts.size() != 3:
		return null
	
	var operator = parts[1]
	
	# Check what types of operands we have
	var op1_is_fraction = parts[0].contains("/")
	var op2_is_fraction = parts[2].contains("/")
	
	# Search through all levels
	for level in math_facts.levels:
		for question in level.facts:
			if question.operator != operator:
				continue
			
			var operands_match = false
			
			# Check if question has operands array or uses expression format
			if not question.has("operands") or typeof(question.operands) != TYPE_ARRAY or question.operands.size() < 2:
				# Mixed fraction or expression-based question - match by reconstructing key from expression
				if question.has("expression") and question.expression != "":
					var reconstructed_key = get_question_key(question)
					if reconstructed_key == question_key:
						return question
				continue
			
			# Handle mixed operand types (whole number and fraction)
			var q_op1 = question.operands[0]
			var q_op2 = question.operands[1]
			var q_op1_is_array = typeof(q_op1) == TYPE_ARRAY
			var q_op2_is_array = typeof(q_op2) == TYPE_ARRAY
			
			# Check operand 1
			var op1_match = false
			if op1_is_fraction:
				# Key has fraction format
				var op1_parts = parts[0].split("/")
				if op1_parts.size() == 2 and q_op1_is_array and q_op1.size() >= 2:
					op1_match = (q_op1[0] == float(op1_parts[0]) and q_op1[1] == float(op1_parts[1]))
			else:
				# Key has whole number format
				var operand1 = float(parts[0])
				if not q_op1_is_array:
					op1_match = (q_op1 == operand1)
			
			# Check operand 2
			var op2_match = false
			if op2_is_fraction:
				# Key has fraction format
				var op2_parts = parts[2].split("/")
				if op2_parts.size() == 2 and q_op2_is_array and q_op2.size() >= 2:
					op2_match = (q_op2[0] == float(op2_parts[0]) and q_op2[1] == float(op2_parts[1]))
			else:
				# Key has whole number format
				var operand2 = float(parts[2])
				if not q_op2_is_array:
					op2_match = (q_op2 == operand2)
			
			operands_match = (op1_match and op2_match)
			
			if operands_match:
				return question
	
	return null
