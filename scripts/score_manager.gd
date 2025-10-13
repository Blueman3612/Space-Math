extends Node

# Score and evaluation manager - handles star evaluation, CQPM, drill mode scoring

# Timer and accuracy tracking variables (these will be accessed by UIManager)
var level_start_time = 0.0  # Time when the level started
var current_level_time = 0.0  # Current elapsed time for the level
var timer_active = false  # Whether the timer is currently running
var grace_period_timer = 0.0  # Timer for the grace period
var timer_started = false  # Whether the timer has started (past grace period)
var correct_answers = 0  # Number of correct answers in current level
var current_question_start_time = 0.0  # Track when current question timing started

# Drill mode variables
var drill_score = 0  # Current drill mode score
var drill_streak = 0  # Current correct answer streak in drill mode
var drill_total_answered = 0  # Total questions answered in drill mode (correct + incorrect)
var drill_timer_remaining = 0.0  # Time remaining in drill mode
var drill_score_display_value = 0.0  # Current displayed score value for smooth animation
var drill_score_target_value = 0  # Target score value for smooth animation

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

func evaluate_stars(current_level_number: int):
	"""Evaluate which stars the player has earned"""
	var stars_earned = []
	var level_config = GameConfig.level_configs.get(current_level_number, GameConfig.level_configs[1])
	
	# Check Star 1
	if correct_answers >= level_config.star1.accuracy and current_level_time <= level_config.star1.time:
		stars_earned.append(1)
	
	# Check Star 2
	if correct_answers >= level_config.star2.accuracy and current_level_time <= level_config.star2.time:
		stars_earned.append(2)
	
	# Check Star 3
	if correct_answers >= level_config.star3.accuracy and current_level_time <= level_config.star3.time:
		stars_earned.append(3)
	
	return stars_earned

func check_star_requirement(star_num: int, requirement_type: String, current_level_number: int) -> bool:
	"""Check if a specific requirement for a star has been met"""
	var level_config = GameConfig.level_configs.get(current_level_number, GameConfig.level_configs[1])
	var requirements
	match star_num:
		1: requirements = level_config.star1
		2: requirements = level_config.star2
		3: requirements = level_config.star3
		_: return false
	
	match requirement_type:
		"accuracy": return correct_answers >= requirements.accuracy
		"time": return current_level_time <= requirements.time
		_: return false

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
				
				# Find global index across all level packs
				var global_index = 0
				for pack_name in GameConfig.level_pack_order:
					var pack_config = GameConfig.level_packs[pack_name]
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
	timer_active = false
	timer_started = false
	grace_period_timer = 0.0
	correct_answers = 0
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

func update_normal_timer(delta: float):
	"""Update normal mode timer"""
	if timer_active:
		current_level_time += delta

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

