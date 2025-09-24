extends Node2D

var math_facts = {}
var rng = RandomNumberGenerator.new()

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
		else:
			print("Error parsing JSON: ", json.get_error_message())
	else:
		print("Could not open math-facts.json")
	
	# Initialize random number generator
	rng.randomize()
	
	# Display initial random question
	update_question_display()

func _input(event):
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_SPACE:
			update_question_display()

func update_question_display():
	# Get a random track between 5-12
	var random_track = rng.randi_range(5, 12)
	var question = get_math_question(random_track)
	
	if question:
		var label = get_node("QuestionLabel")
		if label:
			label.text = "Track: %d\nGrade: %s\nTitle: %s\nQuestion: %s\nExpression: %s\nOperands: %s\nOperator: %s\nResult: %d" % [
				random_track,
				question.grade,
				question.title,
				question.question,
				question.expression,
				str(question.operands),
				question.operator,
				question.result
			]

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
