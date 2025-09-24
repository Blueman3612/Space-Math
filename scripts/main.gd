extends Node2D

# Math facts data and RNG
var math_facts = {}
var rng = RandomNumberGenerator.new()

# Game configuration variables
var blink_interval = 0.5  # Time for underscore blink cycle (fade in/out)
var max_answer_chars = 4  # Maximum characters for answer input
var movement_smoothing = 0.1  # Exponential smoothing factor (10% per frame)
var transition_delay = 0.0  # Delay before generating new question

# Position variables
var primary_position = Vector2(416, 476)  # Main problem position
var off_screen_top = Vector2(416, -324)   # Off-screen top position
var off_screen_bottom = Vector2(416, 1276) # Off-screen bottom position

# Game state variables
var current_problem_label: Label
var current_question = null  # Store current question data
var user_answer = ""
var blink_timer = 0.0
var underscore_visible = true
var moving_labels = []  # Array to track labels in transition
var label_settings_resource: LabelSettings

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
			print("Math facts loaded successfully! Found ", math_facts.size(), " top-level keys")
			if math_facts.has("grades"):
				print("Grades found: ", math_facts.grades.keys())
		else:
			print("Error parsing JSON: ", json.get_error_message())
	else:
		print("Could not open math-facts.json")
	
	# Initialize random number generator
	rng.randomize()
	
	# Load label settings resource
	label_settings_resource = load("res://assets/label settings/GravityBold128.tres")
	
	# Set up initial problem
	setup_initial_problem()

func _input(event):
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_R:
			# Regenerate space background
			var space_bg = get_node("BackgroundLayer/SpaceBackground")
			if space_bg and space_bg.has_method("regenerate"):
				space_bg.regenerate()
		
		# Handle number input and negative sign
		if event.keycode >= KEY_0 and event.keycode <= KEY_9:
			var digit = str(event.keycode - KEY_0)
			var effective_length = user_answer.length()
			if user_answer.begins_with("-"):
				effective_length -= 1  # Don't count negative sign toward limit
			if effective_length < max_answer_chars:
				user_answer += digit
		
		# Handle negative sign (only at the beginning)
		elif event.keycode == KEY_MINUS and user_answer == "":
			user_answer = "-"
		
		# Handle keypad numbers
		elif event.keycode >= KEY_KP_0 and event.keycode <= KEY_KP_9:
			var digit = str(event.keycode - KEY_KP_0)
			var effective_length = user_answer.length()
			if user_answer.begins_with("-"):
				effective_length -= 1  # Don't count negative sign toward limit
			if effective_length < max_answer_chars:
				user_answer += digit
	
	# Handle backspace
	if Input.is_action_just_pressed("Backspace"):
		if user_answer.length() > 0:
			user_answer = user_answer.substr(0, user_answer.length() - 1)
	
	# Handle submit
	if Input.is_action_just_pressed("Submit"):
		submit_answer()

func _process(delta):
	# Update blink timer
	blink_timer += delta
	if blink_timer >= blink_interval:
		blink_timer = 0.0
		underscore_visible = not underscore_visible
	
	# Update problem display
	update_problem_display()
	
	# Update moving labels
	update_moving_labels(delta)

func setup_initial_problem():
	# Get the existing Problem label and set it up as current
	current_problem_label = get_node("Problem")
	if current_problem_label:
		current_problem_label.position = primary_position
		current_problem_label.label_settings = label_settings_resource
		# Only generate question if math facts are loaded
		if not math_facts.is_empty():
			generate_new_question()
		else:
			print("Math facts not loaded, cannot generate question")

func generate_new_question():
	user_answer = ""
	# Store current question for answer checking later
	# Get a random track between 5-12 (same as original logic)
	var random_track = rng.randi_range(5, 12)
	current_question = get_math_question(random_track)
	if not current_question:
		print("Failed to generate question for track ", random_track)

func update_problem_display():
	if current_problem_label and current_question:
		var base_text = current_question.question + " = "
		var display_text = base_text + user_answer
		
		# Add blinking underscore (simple on/off)
		if underscore_visible:
			display_text += "_"
		
		current_problem_label.text = display_text

func submit_answer():
	if user_answer == "":
		return  # Don't submit empty answers
	
	# Move current label up and off screen
	if current_problem_label:
		moving_labels.append({
			"label": current_problem_label,
			"target_position": off_screen_top,
			"is_moving_up": true
		})
	
	# Create new label at bottom off-screen position
	create_new_problem_label()
	
	# Generate new question after delay
	if transition_delay > 0.0:
		await get_tree().create_timer(transition_delay).timeout
	generate_new_question()

func create_new_problem_label():
	# Create new label
	var new_label = Label.new()
	new_label.label_settings = label_settings_resource
	new_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	new_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	new_label.position = off_screen_bottom
	new_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	
	# Add to scene
	add_child(new_label)
	
	# Set as current problem label
	current_problem_label = new_label
	
	# Add to moving labels array to animate to primary position
	moving_labels.append({
		"label": new_label,
		"target_position": primary_position,
		"is_moving_up": false
	})

func update_moving_labels(delta):
	var labels_to_remove = []
	
	for i in range(moving_labels.size()):
		var moving_label = moving_labels[i]
		var label = moving_label.label
		var target = moving_label.target_position
		
		if not is_instance_valid(label):
			labels_to_remove.append(i)
			continue
		
		# Exponential smoothing movement
		var current_pos = label.position
		var distance = target - current_pos
		var movement = distance * movement_smoothing
		label.position += movement
		
		# Check if label reached target (within small threshold)
		if distance.length() < 5.0:
			label.position = target
			
			# If this label was moving up (finished problem), remove it
			if moving_label.is_moving_up:
				label.queue_free()
			
			labels_to_remove.append(i)
	
	# Remove completed movements (in reverse order to maintain indices)
	for i in range(labels_to_remove.size() - 1, -1, -1):
		moving_labels.remove_at(labels_to_remove[i])

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
		print("Looking for track: ", track_key)
		for grade_key in math_facts.grades:
			var grade_data = math_facts.grades[grade_key]
			if grade_data.has("tracks") and grade_data.tracks.has(track_key):
				questions = grade_data.tracks[track_key].facts
				question_title = grade_data.tracks[track_key].title
				question_grade = grade_data.name
				print("Found track ", track_key, " in grade ", grade_key, " with ", questions.size(), " questions")
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
		print("No questions found after filtering")
		return null
	
	print("Selecting from ", questions.size(), " available questions")
	
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
