extends Node

# Score and evaluation manager - handles star evaluation, CQPM, drill mode scoring

# Timer and accuracy tracking variables (these will be accessed by UIManager)
var level_start_time = 0.0  # Time when the level started
var current_level_time = 0.0  # Current elapsed time for the level (counts up for drill, down for normal)
var level_timer_remaining = 0.0  # Time remaining in level countdown timer
var timer_active = false  # Whether the timer is currently running
var grace_period_timer = 0.0  # Timer for the grace period
var timer_started = false  # Whether the timer has started (past grace period)
var correct_answers = 0  # Number of correct answers in current level
var total_answers = 0  # Total questions answered in current level (correct + incorrect)
var current_question_start_time = 0.0  # Track when current question timing started

# Drill mode variables
var drill_score = 0  # Current drill mode score
var drill_streak = 0  # Current correct answer streak in drill mode
var drill_total_answered = 0  # Total questions answered in drill mode (correct + incorrect)
var drill_timer_remaining = 0.0  # Time remaining in drill mode
var drill_score_display_value = 0.0  # Current displayed score value for smooth animation
var drill_score_target_value = 0  # Target score value for smooth animation

# Assessment mode variables
var assessment_current_standard_index = 0  # Index into ASSESSMENT_STANDARDS array
var assessment_current_standard_correct = 0  # Correct answers for current standard
var assessment_current_standard_total = 0  # Total answers for current standard
var assessment_current_standard_times = []  # Time for each question in current standard (excluding transition delay)
var assessment_all_results = {}  # Dictionary mapping standard_id to {average_time, accuracy, cqpm}

func initialize():
	"""Initialize the score manager"""
	pass

func start_question_timing():
	"""Start timing the current question"""
	current_question_start_time = Time.get_ticks_msec() / 1000.0  # Convert to seconds with millisecond precision

func calculate_cqpm(correct_answers_in_level, time_in_seconds):
	"""Calculate Correct Questions Per Minute"""
	if time_in_seconds <= 0:
		return 0.0
	return (float(correct_answers_in_level) / time_in_seconds) * 60.0

func evaluate_stars_for_mastery_count(mastery_count: int) -> Array:
	"""Evaluate which stars the player has earned based on mastery_count.
	This uses the new scoring system with correct count thresholds and accuracy percentages."""
	var stars_earned = []
	
	# Calculate current accuracy percentage
	var accuracy = 0.0
	if total_answers > 0:
		accuracy = float(correct_answers) / float(total_answers)
	
	# Calculate star thresholds based on mastery_count
	var star1_correct = int(ceil(mastery_count * GameConfig.star1_correct_percent))
	var star2_correct = int(ceil(mastery_count * GameConfig.star2_correct_percent))
	var star3_correct = int(ceil(mastery_count * GameConfig.star3_correct_percent))
	
	# Check Star 1: correct answers >= 50% of mastery_count AND accuracy >= 55%
	if correct_answers >= star1_correct and accuracy >= GameConfig.star1_accuracy_threshold:
		stars_earned.append(1)
	
	# Check Star 2: correct answers >= 75% of mastery_count AND accuracy >= 70%
	if correct_answers >= star2_correct and accuracy >= GameConfig.star2_accuracy_threshold:
		stars_earned.append(2)
	
	# Check Star 3: correct answers >= 100% of mastery_count AND accuracy >= 85%
	if correct_answers >= star3_correct and accuracy >= GameConfig.star3_accuracy_threshold:
		stars_earned.append(3)
	
	return stars_earned

func check_mastery_complete(mastery_count: int) -> bool:
	"""Check if the player has achieved mastery (reached mastery_count correct with >= 85% accuracy)"""
	if correct_answers < mastery_count:
		return false
	
	# Check if accuracy is >= 85%
	if total_answers == 0:
		return false
	
	var accuracy = float(correct_answers) / float(total_answers)
	return accuracy >= GameConfig.mastery_accuracy_threshold

func get_star_requirements(mastery_count: int) -> Dictionary:
	"""Get the star requirements based on mastery_count"""
	return {
		"star1": {
			"correct": int(ceil(mastery_count * GameConfig.star1_correct_percent)),
			"accuracy": GameConfig.star1_accuracy_threshold
		},
		"star2": {
			"correct": int(ceil(mastery_count * GameConfig.star2_correct_percent)),
			"accuracy": GameConfig.star2_accuracy_threshold
		},
		"star3": {
			"correct": int(ceil(mastery_count * GameConfig.star3_correct_percent)),
			"accuracy": GameConfig.star3_accuracy_threshold
		}
	}

func get_current_accuracy() -> float:
	"""Get current accuracy as a decimal (0.0 to 1.0)"""
	if total_answers == 0:
		return 1.0  # Default to 100% when no answers yet
	return float(correct_answers) / float(total_answers)

func get_current_accuracy_percent() -> int:
	"""Get current accuracy as an integer percentage (0 to 100), rounded down"""
	return int(get_current_accuracy() * 100.0)

# ============================================
# Legacy Functions (for backwards compatibility with pack-based levels)
# ============================================

func evaluate_stars(_current_level_number: int) -> Array:
	"""Legacy function - uses default mastery count for evaluation"""
	return evaluate_stars_for_mastery_count(20)  # Default fallback

func calculate_question_difficulty(question_data):
	"""Calculate the difficulty of a question based on its track"""
	# Find which track this question belongs to
	for level in QuestionManager.math_facts.levels:
		for fact in level.facts:
			# Check if both fact and question_data have comparable operands
			var has_fact_operands = fact.has("operands") and fact.operands != null and fact.operands.size() >= 2
			var has_question_operands = question_data.has("operands") and question_data.operands != null and question_data.operands.size() >= 2
			
			var operands_match = false
			if has_fact_operands and has_question_operands:
				# For fraction questions, operands are arrays, so we need to compare differently
				if typeof(fact.operands[0]) == TYPE_ARRAY and typeof(question_data.operands[0]) == TYPE_ARRAY:
					# Fraction question - compare arrays
					operands_match = (fact.operands[0] == question_data.operands[0] and 
									  fact.operands[1] == question_data.operands[1])
				else:
					# Regular question - compare numbers
					operands_match = (fact.operands[0] == question_data.operands[0] and 
									  fact.operands[1] == question_data.operands[1])
			elif not has_fact_operands and not has_question_operands:
				# Both use expression format - compare expressions
				if fact.has("expression") and question_data.has("expression"):
					operands_match = (fact.expression == question_data.expression)
			
			if operands_match and fact.operator == question_data.operator:
				# Get the track ID (could be "TRACK12" or "FRAC-07")
				var track_id = level.id
				
				# Find global index across all level packs (legacy)
				var global_index = 0
				for pack_name in GameConfig.legacy_level_pack_order:
					var pack_config = GameConfig.legacy_level_packs[pack_name]
					for track_entry in pack_config.levels:
						# Handle both numeric and string track IDs
						var matches = false
						if typeof(track_entry) == TYPE_STRING:
							matches = (track_entry == track_id)
						else:
							# Numeric track, need to compare with "TRACK#" format
							matches = (track_id == "TRACK" + str(track_entry))
						
						if matches:
							return (global_index + 1) * 2  # (index + 1) * 2
						
						global_index += 1
				
				# If not found, return default difficulty
				return 2
	# Default difficulty if track not found
	return 2

func reset_for_new_level():
	"""Reset score tracking for a new level"""
	level_start_time = 0.0
	current_level_time = 0.0
	level_timer_remaining = GameConfig.level_timer_duration
	timer_active = false
	timer_started = false
	grace_period_timer = 0.0
	correct_answers = 0
	total_answers = 0
	current_question_start_time = 0.0

func reset_for_drill_mode():
	"""Reset score tracking for drill mode"""
	reset_for_new_level()
	drill_score = 0
	drill_streak = 0
	drill_total_answered = 0
	drill_timer_remaining = GameConfig.drill_mode_duration
	drill_score_display_value = 0.0
	drill_score_target_value = 0

func process_correct_answer(is_drill_mode: bool, current_question):
	"""Process a correct answer and update scores"""
	correct_answers += 1
	total_answers += 1
	if is_drill_mode:
		drill_streak += 1
		# Calculate drill mode score: difficulty + streak
		var difficulty = calculate_question_difficulty(current_question)
		var points_earned = difficulty + drill_streak
		drill_score += points_earned
		drill_score_target_value = drill_score
		print("Drill mode: +", points_earned, " points (", difficulty, " difficulty + ", drill_streak, " streak)")
		return points_earned
	return 0

func process_incorrect_answer(is_drill_mode: bool):
	"""Process an incorrect answer"""
	total_answers += 1
	if is_drill_mode:
		drill_streak = 0  # Reset streak on incorrect answer

func update_drill_timer(delta: float):
	"""Update drill mode timer and return true if time ran out"""
	if timer_active:
		drill_timer_remaining -= delta
		current_level_time += delta  # Also track elapsed time for CQPM calculation
		if drill_timer_remaining <= 0.0:
			drill_timer_remaining = 0.0
			return true
	return false

func update_normal_timer(delta: float) -> bool:
	"""Update normal mode countdown timer. Returns true if time ran out."""
	if timer_active:
		current_level_time += delta  # Track total elapsed time for XP calculation
		level_timer_remaining -= delta
		if level_timer_remaining <= 0.0:
			level_timer_remaining = 0.0
			return true
	return false

func update_grace_period(delta: float):
	"""Update grace period timer and return true if grace period ended"""
	if not timer_started:
		if not timer_active:
			grace_period_timer += delta
			if grace_period_timer >= GameConfig.timer_grace_period:
				timer_active = true
				timer_started = true
				level_start_time = Time.get_time_dict_from_system()["hour"] * 3600 + Time.get_time_dict_from_system()["minute"] * 60 + Time.get_time_dict_from_system()["second"]
				return true
	return false

# ============================================
# Assessment Mode Functions
# ============================================

func reset_for_assessment():
	"""Reset score tracking for assessment mode"""
	reset_for_new_level()
	assessment_current_standard_index = 0
	assessment_current_standard_correct = 0
	assessment_current_standard_total = 0
	assessment_current_standard_times = []
	assessment_all_results = {}

func reset_for_assessment_standard():
	"""Reset tracking for a new standard within assessment"""
	assessment_current_standard_correct = 0
	assessment_current_standard_total = 0
	assessment_current_standard_times = []
	current_question_start_time = 0.0

func get_current_assessment_standard() -> Dictionary:
	"""Get the current assessment standard data"""
	if assessment_current_standard_index >= GameConfig.ASSESSMENT_STANDARDS.size():
		return {}
	return GameConfig.ASSESSMENT_STANDARDS[assessment_current_standard_index]

func get_questions_for_standard(standard: Dictionary) -> int:
	"""Calculate the number of questions for a standard based on target_cqpm.
	Formula: questions = round(target_cqpm * target_seconds / 60)
	Minimum of 1 question.
	"""
	var target_cqpm = standard.get("target_cqpm", 10.0)
	var target_seconds = GameConfig.assessment_target_seconds_per_standard
	var questions = round(target_cqpm * target_seconds / 60.0)
	return max(1, int(questions))

func process_assessment_answer(is_correct: bool, time_taken: float):
	"""Process an answer in assessment mode
	time_taken should already have transition_delay subtracted
	Returns a dictionary with {should_advance: bool, assessment_complete: bool}
	"""
	assessment_current_standard_total += 1
	if is_correct:
		assessment_current_standard_correct += 1
	assessment_current_standard_times.append(time_taken)
	
	var standard = get_current_assessment_standard()
	if standard.is_empty():
		return {"should_advance": false, "assessment_complete": true}
	
	# Calculate dynamic question count for this standard
	var max_questions = get_questions_for_standard(standard)
	
	# Advance to next standard when max questions reached
	if assessment_current_standard_total >= max_questions:
		return {"should_advance": true, "assessment_complete": false}
	
	return {"should_advance": false, "assessment_complete": false}

func finalize_current_standard():
	"""Finalize results for the current standard before moving to next"""
	var standard = get_current_assessment_standard()
	if standard.is_empty():
		return
	
	var avg_time = _calculate_average_time()
	var accuracy = 0.0
	if assessment_current_standard_total > 0:
		accuracy = float(assessment_current_standard_correct) / float(assessment_current_standard_total)
	var cqpm = _calculate_cqpm_from_avg_time(avg_time, assessment_current_standard_correct)
	
	assessment_all_results[standard.id] = {
		"average_time": avg_time,
		"accuracy": accuracy,
		"cqpm": cqpm,
		"correct": assessment_current_standard_correct,
		"total": assessment_current_standard_total
	}
	
	print("[Assessment] Standard '%s' complete: %.1f CQPM, %.0f%% accuracy (%d/%d)" % [
		standard.name, cqpm, accuracy * 100, assessment_current_standard_correct, assessment_current_standard_total
	])

func advance_to_next_standard() -> bool:
	"""Move to the next assessment standard. Returns true if there are more standards, false if complete."""
	finalize_current_standard()
	assessment_current_standard_index += 1
	
	if assessment_current_standard_index >= GameConfig.ASSESSMENT_STANDARDS.size():
		print("[Assessment] All standards complete!")
		return false
	
	reset_for_assessment_standard()
	return true

func is_assessment_complete() -> bool:
	"""Check if all assessment standards have been completed"""
	return assessment_current_standard_index >= GameConfig.ASSESSMENT_STANDARDS.size()

func get_assessment_final_results() -> Dictionary:
	"""Get the final results dictionary for saving"""
	return {
		"timestamp": Time.get_unix_time_from_system(),
		"standards": assessment_all_results.duplicate(true)
	}

func _calculate_average_time() -> float:
	"""Calculate average time per question for current standard"""
	if assessment_current_standard_times.is_empty():
		return 0.0
	var total = 0.0
	for t in assessment_current_standard_times:
		total += t
	return total / assessment_current_standard_times.size()

func _calculate_cqpm_from_avg_time(avg_time: float, num_correct: int) -> float:
	"""Calculate CQPM from average time per question"""
	if avg_time <= 0.0 or num_correct <= 0:
		return 0.0
	# CQPM = 60 / avg_time_per_question (for 100% accuracy)
	# Since we're tracking per-question time, CQPM = 60 / avg_time
	return 60.0 / avg_time
