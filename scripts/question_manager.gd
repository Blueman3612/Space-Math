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

func get_display_operator(operator: String) -> String:
	"""Convert unicode operators to simple characters for display"""
	match operator:
		"×": return "x"
		"÷": return "/"
		_: return operator

func generate_new_question():
	"""Generate a new question for the current track"""
	# Store current question for answer checking later
	# Use the weighted system if we have weights initialized, otherwise fall back to old system
	if not question_weights.is_empty():
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
		var pack_config = GameConfig.level_packs[pack_name]
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
