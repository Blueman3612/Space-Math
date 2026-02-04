extends Node

# Playcademy manager - handles all Playcademy SDK integration

# ============================================
# Session Tracking for TimeBack
# ============================================
var session_start_timestamp = 0.0  # Unix timestamp when session started
var session_end_timestamp = 0.0    # Unix timestamp when session ended
var last_input_timestamp = 0.0     # Unix timestamp of last player input
var total_idle_time = 0.0          # Accumulated idle time in seconds
var is_session_active = false      # Whether a session is currently being tracked
var current_session_pack = ""      # Which pack is being played
var current_session_level = -1     # Which level index in the pack

func initialize():
	"""Initialize Playcademy integration"""
	# Connect Playcademy Scores API signals if available
	connect_playcademy_signals()

func connect_playcademy_signals():
	"""Connect Playcademy Scores and TimeBack API signals if available"""
	if Engine.has_singleton("PlaycademySdk") or (typeof(PlaycademySdk) != TYPE_NIL):
		if PlaycademySdk and PlaycademySdk.scores:
			if not PlaycademySdk.scores.submit_succeeded.is_connected(_on_pc_submit_succeeded):
				PlaycademySdk.scores.submit_succeeded.connect(_on_pc_submit_succeeded)
			if not PlaycademySdk.scores.submit_failed.is_connected(_on_pc_submit_failed):
				PlaycademySdk.scores.submit_failed.connect(_on_pc_submit_failed)
		
		# Connect TimeBack signals
		if PlaycademySdk and PlaycademySdk.timeback:
			if not PlaycademySdk.timeback.end_activity_failed.is_connected(_on_timeback_end_activity_failed):
				PlaycademySdk.timeback.end_activity_failed.connect(_on_timeback_end_activity_failed)
			if not PlaycademySdk.timeback.pause_activity_failed.is_connected(_on_timeback_pause_activity_failed):
				PlaycademySdk.timeback.pause_activity_failed.connect(_on_timeback_pause_activity_failed)
			if not PlaycademySdk.timeback.resume_activity_failed.is_connected(_on_timeback_resume_activity_failed):
				PlaycademySdk.timeback.resume_activity_failed.connect(_on_timeback_resume_activity_failed)

func _on_pc_submit_succeeded(_score_data):
	"""Handle successful Playcademy score submission"""
	print("Playcademy score submitted successfully: ", _score_data)

func _on_pc_submit_failed(error_message):
	"""Handle failed Playcademy score submission"""
	print("Playcademy score submit failed: ", error_message)

func _on_timeback_end_activity_failed(error_message):
	"""Handle failed TimeBack activity end"""
	printerr("[TimeBack] Failed to end activity: ", error_message)

func _on_timeback_pause_activity_failed(error_message):
	"""Handle failed TimeBack activity pause"""
	printerr("[TimeBack] Failed to pause activity: ", error_message)

func _on_timeback_resume_activity_failed(error_message):
	"""Handle failed TimeBack activity resume"""
	printerr("[TimeBack] Failed to resume activity: ", error_message)

func attempt_playcademy_auto_submit():
	"""Attempt automatic Playcademy score submission for drill mode"""
	if ScoreManager.drill_score <= 0:
		return
	
	if (typeof(PlaycademySdk) != TYPE_NIL) and PlaycademySdk and PlaycademySdk.is_ready() and PlaycademySdk.scores:
		# Submit without blocking; ignore result (signals still wired for logging)
		print("Submitting drill mode score to Playcademy: ", ScoreManager.drill_score)
		PlaycademySdk.scores.submit(ScoreManager.drill_score, {})

# ============================================
# Session Tracking Functions
# ============================================

func start_session_tracking(pack_name: String, level_index: int):
	"""Start tracking a new session (legacy pack-based levels)"""
	session_start_timestamp = Time.get_unix_time_from_system()
	last_input_timestamp = session_start_timestamp
	total_idle_time = 0.0
	is_session_active = true
	current_session_pack = pack_name
	current_session_level = level_index
	
	# Start TimeBack activity tracking
	if PlaycademySdk and PlaycademySdk.is_ready() and PlaycademySdk.timeback:
		var activity_id = "level-" + pack_name + "-" + str(level_index) if pack_name != "Drill Mode" else "drill-mode"
		var activity_name = pack_name + " - Level " + str(level_index + 1) if pack_name != "Drill Mode" else "Drill Mode"
		var activity_metadata = {
			"activityId": activity_id,
			"activityName": activity_name,
			"grade": GameConfig.current_grade if GameConfig.current_grade > 0 else 3,
			"subject": "FastMath"
		}
		PlaycademySdk.timeback.start_activity(activity_metadata)

func start_grade_level_session_tracking(level_data: Dictionary):
	"""Start tracking a new session for grade-based levels"""
	session_start_timestamp = Time.get_unix_time_from_system()
	last_input_timestamp = session_start_timestamp
	total_idle_time = 0.0
	is_session_active = true
	
	# Extract the grade from the level_id (e.g., "grade1_addition_sums_to_6" -> 1)
	# This is more reliable than using GameConfig.current_grade which could be stale
	var level_grade = _extract_grade_from_level_id(level_data.id)
	
	current_session_pack = "Grade" + str(level_grade)
	current_session_level = 0
	
	# Start TimeBack activity tracking with proper level info
	if PlaycademySdk and PlaycademySdk.is_ready() and PlaycademySdk.timeback:
		var activity_metadata = {
			"activityId": level_data.id,
			"activityName": level_data.name,
			"grade": level_grade,
			"subject": "FastMath"
		}
		print("[TimeBack] Starting activity with metadata: ", activity_metadata)
		PlaycademySdk.timeback.start_activity(activity_metadata)

func record_player_input():
	"""Called whenever player provides input (keypress, button, etc.)"""
	if not is_session_active:
		return
	
	var current_time = Time.get_unix_time_from_system()
	var time_since_last_input = current_time - last_input_timestamp
	
	# If time since last input exceeds idle threshold, count it as idle time
	if time_since_last_input > GameConfig.timeback_idle_threshold:
		var idle_duration = time_since_last_input - GameConfig.timeback_idle_threshold
		total_idle_time += idle_duration
		print("[TimeBack] Idle period detected: %.1fs (total idle: %.1fs)" % [idle_duration, total_idle_time])
	
	last_input_timestamp = current_time

func pause_timeback_activity():
	"""Pause TimeBack activity timer during instructional moments (showing correct answer, feedback, etc.)"""
	if PlaycademySdk and PlaycademySdk.is_ready() and PlaycademySdk.timeback:
		PlaycademySdk.timeback.pause_activity()

func resume_timeback_activity():
	"""Resume TimeBack activity timer when player continues playing"""
	if PlaycademySdk and PlaycademySdk.is_ready() and PlaycademySdk.timeback:
		PlaycademySdk.timeback.resume_activity()

func end_session_and_award_xp(pack_name: String, pack_level_index: int, current_level_number: int, current_track, stars_earned: int) -> Dictionary:
	"""End session tracking and calculate XP to award"""
	if not is_session_active:
		return {"xp_awarded": 0, "details": "No active session"}
	
	session_end_timestamp = Time.get_unix_time_from_system()
	is_session_active = false
	
	# Calculate total session duration (wall clock time)
	var total_duration = session_end_timestamp - session_start_timestamp
	
	# Check for final idle period (from last input to session end)
	var time_since_last_input = session_end_timestamp - last_input_timestamp
	if time_since_last_input > GameConfig.timeback_idle_threshold:
		var final_idle = time_since_last_input - GameConfig.timeback_idle_threshold
		total_idle_time += final_idle
		print("[TimeBack] Final idle period: %.1fs" % final_idle)
	
	# Calculate active time (total - idle)
	var active_time = max(0.0, total_duration - total_idle_time)
	var active_minutes = active_time / 60.0
	
	# Calculate CQPM using in-game timer (not wall clock)
	var correct_answers = ScoreManager.correct_answers
	var game_time = ScoreManager.current_level_time  # Use actual gameplay timer
	var cqpm = 0.0
	if game_time > 0:
		cqpm = (float(correct_answers) / game_time) * 60.0
	
	# Get CQPM multiplier for this level
	var cqpm_multiplier = get_cqpm_multiplier_for_level(current_level_number, cqpm)
	
	# Get star-based multiplier (discourages farming mastered levels)
	var star_multiplier = GameConfig.timeback_star_multipliers.get(stars_earned, 1.0)
	
	# Calculate XP with both CQPM and star multipliers
	var base_xp = active_minutes * GameConfig.timeback_base_xp_per_minute
	var xp_before_star_gate = base_xp * cqpm_multiplier
	var final_xp = round(xp_before_star_gate * star_multiplier)
	
	# Build detailed breakdown
	var details = {
		"total_duration": total_duration,
		"idle_time": total_idle_time,
		"active_time": active_time,
		"active_minutes": active_minutes,
		"game_time": game_time,
		"correct_answers": correct_answers,
		"cqpm": cqpm,
		"cqpm_multiplier": cqpm_multiplier,
		"star_multiplier": star_multiplier,
		"xp_before_star_gate": xp_before_star_gate,
		"base_xp": base_xp,
		"final_xp": final_xp,
		"stars_earned": stars_earned,
		"level_number": current_level_number,
		"pack_name": pack_name
	}
	
	# Print detailed metrics
	print("\n" + "=".repeat(60))
	print("[TimeBack] LEVEL COMPLETION METRICS")
	print("=".repeat(60))
	print("Level: %s - Level %d (Global Level %d)" % [pack_name, pack_level_index + 1, current_level_number])
	print("Stars Earned: %d" % stars_earned)
	print("")
	print("TIME METRICS:")
	print("  Total session duration: %.1fs (%.2f minutes)" % [total_duration, total_duration / 60.0])
	print("  Idle time subtracted:   %.1fs (%.2f minutes)" % [total_idle_time, total_idle_time / 60.0])
	print("  Active time counted:    %.1fs (%.2f minutes) [for XP base]" % [active_time, active_minutes])
	print("  Game timer (in-game):   %.1fs (%.2f minutes) [for CQPM]" % [game_time, game_time / 60.0])
	print("")
	print("PERFORMANCE METRICS:")
	print("  Correct answers: %d" % correct_answers)
	print("  CQPM (%.0f / %.1fs × 60): %.2f" % [correct_answers, game_time, cqpm])
	print("  CQPM Multiplier for Level %d: %.2fx" % [current_level_number, cqpm_multiplier])
	print("  Already Earned Star Multiplier (%d stars): %.2fx" % [stars_earned, star_multiplier])
	print("")
	print("XP CALCULATION:")
	print("  Base XP (%.2f min × %.1f XP/min) = %.2f" % [active_minutes, GameConfig.timeback_base_xp_per_minute, base_xp])
	print("  After CQPM (%.2f × %.2fx) = %.2f" % [base_xp, cqpm_multiplier, xp_before_star_gate])
	print("  After Star Gate (%.2f × %.2fx) = %d XP" % [xp_before_star_gate, star_multiplier, final_xp])
	print("=".repeat(60) + "\n")
	
	# Only award if session meets minimum duration
	if total_duration >= GameConfig.timeback_min_session_duration:
		award_timeback_xp(final_xp, details, pack_name, pack_level_index, current_track, stars_earned)
	else:
		print("[TimeBack] ⚠ Session too short (%.1fs < %.1fs minimum), no XP awarded" % [total_duration, GameConfig.timeback_min_session_duration])
	
	return details

func end_grade_level_session_and_award_xp(level_data: Dictionary, previous_stars: int, new_stars: int) -> Dictionary:
	"""End session tracking for grade-based levels and calculate XP using simplified formula.
	XP = 2 × (correct_answers / mastery_count)
	- If accuracy < 80%: 0 XP (and 0 stars)
	- If 100% accuracy + new star earned: XP × 1.25"""
	if not is_session_active:
		return {"xp_awarded": 0, "details": "No active session"}
	
	session_end_timestamp = Time.get_unix_time_from_system()
	is_session_active = false
	
	# Calculate total session duration (wall clock time)
	var total_duration = session_end_timestamp - session_start_timestamp
	
	# Get performance stats
	var correct_answers = ScoreManager.correct_answers
	var total_answers = ScoreManager.total_answers
	var mastery_count = level_data.mastery_count
	var accuracy = 0.0
	if total_answers > 0:
		accuracy = float(correct_answers) / float(total_answers)
	
	# Calculate base XP: 2 × (correct_answers / mastery_count)
	var progress_ratio = float(correct_answers) / float(mastery_count)
	var base_xp = 2.0 * progress_ratio
	
	# Apply accuracy threshold - if accuracy < 80%, no XP
	var final_xp = 0.0
	var perfect_bonus_applied = false
	if accuracy >= GameConfig.star1_accuracy_threshold:  # 80%
		final_xp = base_xp
		
		# Apply perfect accuracy bonus if 100% accuracy AND earned at least 1 new star
		var earned_new_star = new_stars > previous_stars
		if accuracy >= 1.0 and earned_new_star:
			final_xp = base_xp * GameConfig.perfect_accuracy_xp_multiplier
			perfect_bonus_applied = true
	
	# Round to nearest hundredth
	final_xp = snapped(final_xp, 0.01)
	
	# Build detailed breakdown
	var details = {
		"total_duration": total_duration,
		"correct_answers": correct_answers,
		"total_answers": total_answers,
		"mastery_count": mastery_count,
		"accuracy": accuracy,
		"progress_ratio": progress_ratio,
		"base_xp": base_xp,
		"perfect_bonus_applied": perfect_bonus_applied,
		"previous_stars": previous_stars,
		"new_stars": new_stars,
		"final_xp": final_xp,
		"level_id": level_data.id,
		"level_name": level_data.name
	}
	
	# Print detailed metrics
	print("\n" + "=".repeat(60))
	print("[TimeBack] GRADE LEVEL COMPLETION METRICS")
	print("=".repeat(60))
	print("Level: %s (ID: %s)" % [level_data.name, level_data.id])
	print("Stars: %d previously, %d earned this session" % [previous_stars, new_stars])
	print("")
	print("PERFORMANCE METRICS:")
	print("  Correct answers: %d / %d (answered)" % [correct_answers, total_answers])
	print("  Mastery count: %d" % mastery_count)
	print("  Progress: %.0f%% of mastery count" % (progress_ratio * 100))
	print("  Accuracy: %.0f%%" % (accuracy * 100))
	print("")
	print("XP CALCULATION:")
	print("  Base XP = 2 × (%d / %d) = %.2f" % [correct_answers, mastery_count, base_xp])
	if accuracy < GameConfig.star1_accuracy_threshold:
		print("  Accuracy below 80%% threshold - 0 XP awarded")
	elif perfect_bonus_applied:
		print("  Perfect accuracy (100%%) + new star → %.2f × %.2f = %.2f XP" % [base_xp, GameConfig.perfect_accuracy_xp_multiplier, final_xp])
	else:
		print("  Final XP: %.2f" % final_xp)
	print("=".repeat(60) + "\n")
	
	# Only award if session meets minimum duration
	if total_duration >= GameConfig.timeback_min_session_duration:
		award_grade_level_timeback_xp(int(round(final_xp)), details, mastery_count)
	else:
		print("[TimeBack] ⚠ Session too short (%.1fs < %.1fs minimum), no XP awarded" % [total_duration, GameConfig.timeback_min_session_duration])
	
	return details

func award_grade_level_timeback_xp(xp: int, details: Dictionary, _mastery_count: int):
	"""Award XP through Playcademy TimeBack API for grade-based levels"""
	if not PlaycademySdk or not PlaycademySdk.is_ready() or not PlaycademySdk.timeback:
		print("[TimeBack] SDK not ready, cannot award XP")
		return
	
	# Prepare score data
	var score_data = {
		"correctQuestions": details.correct_answers,
		"totalQuestions": details.total_answers,
		"xpAwarded": xp
	}
	
	print("[TimeBack] Ending grade level activity with score_data: ", score_data)
	PlaycademySdk.timeback.end_activity(score_data)

func end_drill_session_and_award_xp() -> Dictionary:
	"""End drill mode session tracking and calculate XP to award"""
	if not is_session_active:
		return {"xp_awarded": 0, "details": "No active session"}
	
	session_end_timestamp = Time.get_unix_time_from_system()
	is_session_active = false
	
	# Calculate total session duration (wall clock time)
	var total_duration = session_end_timestamp - session_start_timestamp
	
	# Check for final idle period (from last input to session end)
	var time_since_last_input = session_end_timestamp - last_input_timestamp
	if time_since_last_input > GameConfig.timeback_idle_threshold:
		var final_idle = time_since_last_input - GameConfig.timeback_idle_threshold
		total_idle_time += final_idle
		print("[TimeBack] Final idle period: %.1fs" % final_idle)
	
	# Calculate active time (total - idle)
	var active_time = max(0.0, total_duration - total_idle_time)
	var active_minutes = active_time / 60.0
	
	# Calculate CQPM for drill mode using in-game timer (not wall clock)
	var correct_answers = ScoreManager.correct_answers
	var game_time = ScoreManager.current_level_time  # Use actual gameplay timer
	var cqpm = 0.0
	if game_time > 0:
		cqpm = (float(correct_answers) / game_time) * 60.0
	
	# Get CQPM multiplier for drill mode
	var cqpm_multiplier = get_cqpm_multiplier_for_drill_mode(cqpm)
	
	# Calculate XP
	var base_xp = active_minutes * GameConfig.timeback_base_xp_per_minute
	var final_xp = round(base_xp * cqpm_multiplier)
	
	# Build detailed breakdown
	var details = {
		"total_duration": total_duration,
		"idle_time": total_idle_time,
		"active_time": active_time,
		"active_minutes": active_minutes,
		"game_time": game_time,
		"correct_answers": correct_answers,
		"total_answered": ScoreManager.drill_total_answered,
		"drill_score": ScoreManager.drill_score,
		"cqpm": cqpm,
		"cqpm_multiplier": cqpm_multiplier,
		"base_xp": base_xp,
		"final_xp": final_xp
	}
	
	# Print detailed metrics
	print("\n" + "=".repeat(60))
	print("[TimeBack] DRILL MODE COMPLETION METRICS")
	print("=".repeat(60))
	print("Drill Score: %d" % ScoreManager.drill_score)
	print("Questions Answered: %d (Correct: %d)" % [ScoreManager.drill_total_answered, correct_answers])
	print("")
	print("TIME METRICS:")
	print("  Total session duration: %.1fs (%.2f minutes)" % [total_duration, total_duration / 60.0])
	print("  Idle time subtracted:   %.1fs (%.2f minutes)" % [total_idle_time, total_idle_time / 60.0])
	print("  Active time counted:    %.1fs (%.2f minutes) [for XP base]" % [active_time, active_minutes])
	print("  Game timer (in-game):   %.1fs (%.2f minutes) [for CQPM]" % [game_time, game_time / 60.0])
	print("")
	print("PERFORMANCE METRICS:")
	print("  Correct answers: %d" % correct_answers)
	print("  CQPM (%.0f / %.1fs × 60): %.2f" % [correct_answers, game_time, cqpm])
	print("  CQPM Multiplier for Drill Mode: %.2fx" % cqpm_multiplier)
	print("")
	print("XP CALCULATION:")
	print("  Base XP (%.2f min × %.1f XP/min) = %.2f" % [active_minutes, GameConfig.timeback_base_xp_per_minute, base_xp])
	print("  Final XP (%.2f × %.2fx multiplier) = %d XP" % [base_xp, cqpm_multiplier, final_xp])
	print("=".repeat(60) + "\n")
	
	# Only award if session meets minimum duration
	if total_duration >= GameConfig.timeback_min_session_duration:
		award_drill_mode_timeback_xp(final_xp, details)
	else:
		print("[TimeBack] ⚠ Session too short (%.1fs < %.1fs minimum), no XP awarded" % [total_duration, GameConfig.timeback_min_session_duration])
	
	return details

func get_cqpm_multiplier_for_level(level_number: int, cqpm: float) -> float:
	"""Get the appropriate CQPM multiplier based on level and performance"""
	var multiplier = 1.0
	
	# Check if there's a level-specific multiplier scale
	if GameConfig.timeback_level_multipliers.has(level_number):
		var scale = GameConfig.timeback_level_multipliers[level_number]
		multiplier = calculate_multiplier_from_scale(scale, cqpm)
	else:
		# Fallback: simple linear scale if level not configured
		print("[TimeBack] Warning: No multiplier scale for level %d, using fallback" % level_number)
		if cqpm >= 20.0:
			multiplier = 2.0
		elif cqpm >= 10.0:
			multiplier = 1.5
		elif cqpm >= 5.0:
			multiplier = 1.0
		else:
			multiplier = 0.5
	
	# Clamp to configured min/max
	return clamp(multiplier, GameConfig.timeback_min_multiplier, GameConfig.timeback_max_multiplier)

func get_cqpm_multiplier_for_drill_mode(cqpm: float) -> float:
	"""Get the appropriate CQPM multiplier for drill mode"""
	var scale = GameConfig.timeback_drill_mode_multipliers
	var multiplier = calculate_multiplier_from_scale(scale, cqpm)
	
	# Clamp to configured min/max
	return clamp(multiplier, GameConfig.timeback_min_multiplier, GameConfig.timeback_max_multiplier)

func calculate_multiplier_from_scale(scale: Array, cqpm: float) -> float:
	"""Calculate multiplier from a scale array of [threshold, multiplier] pairs"""
	# Scale should be sorted from highest to lowest threshold
	for entry in scale:
		if cqpm >= entry[0]:
			return entry[1]
	return 1.0  # Fallback

func _extract_grade_from_level_id(level_id: String) -> int:
	"""Extract the grade number from a level ID (e.g., 'grade1_addition_sums_to_6' -> 1)
	Returns 3 as a fallback if parsing fails (middle of elementary school range)"""
	# Level IDs follow the pattern: gradeX_category_level_name
	if level_id.begins_with("grade"):
		var after_grade = level_id.substr(5)  # Remove "grade" prefix
		var underscore_pos = after_grade.find("_")
		if underscore_pos > 0:
			var grade_str = after_grade.substr(0, underscore_pos)
			if grade_str.is_valid_int():
				var grade = int(grade_str)
				# Validate grade is within API-accepted range (-1 to 13)
				if grade >= -1 and grade <= 13:
					return grade
	
	# Fallback: try using GameConfig.current_grade if valid, otherwise default to 3
	if GameConfig.current_grade >= 1 and GameConfig.current_grade <= 13:
		return GameConfig.current_grade
	return 3  # Safe default (middle of elementary school range)

func award_timeback_xp(xp: int, details: Dictionary, _pack_name: String, _pack_level_index: int, _current_track, previous_stars: int):
	"""Award XP through Playcademy TimeBack API using the new end_activity method"""
	if not PlaycademySdk or not PlaycademySdk.is_ready() or not PlaycademySdk.timeback:
		print("[TimeBack] SDK not ready, cannot award XP")
		return
	
	# Get level configuration
	var level_number = details.level_number
	var level_config = GameConfig.level_configs.get(level_number, GameConfig.level_configs[1])
	var total_questions = level_config.problems
	
	# Calculate newly earned stars (additive mastery units)
	# The previous_stars parameter is the stars BEFORE this session
	# We need to calculate the stars earned THIS session
	var new_stars = ScoreManager.evaluate_stars(level_number).size()
	var mastered_units = max(0, new_stars - previous_stars)
	
	# Prepare score data with manual XP override
	var score_data = {
		"correctQuestions": details.correct_answers,
		"totalQuestions": total_questions,
		"xpAwarded": xp
	}
	
	# Only include masteredUnits if new stars were earned
	if mastered_units > 0:
		score_data["masteredUnits"] = mastered_units
		print("[TimeBack] New stars earned: %d (was %d, now %d)" % [mastered_units, previous_stars, new_stars])
	
	print("[TimeBack] Ending legacy level activity with score_data: ", score_data)
	PlaycademySdk.timeback.end_activity(score_data)

func award_drill_mode_timeback_xp(xp: int, details: Dictionary):
	"""Award XP through Playcademy TimeBack API for drill mode using the new end_activity method"""
	if not PlaycademySdk or not PlaycademySdk.is_ready() or not PlaycademySdk.timeback:
		print("[TimeBack] SDK not ready, cannot award XP")
		return
	
	# Prepare score data with manual XP override - only the 3 required fields
	var score_data = {
		"correctQuestions": details.correct_answers,
		"totalQuestions": details.total_answered,
		"xpAwarded": xp
	}
	
	print("[TimeBack] Ending drill mode activity with score_data: ", score_data)
	PlaycademySdk.timeback.end_activity(score_data)

# ============================================
# Assessment Mode Session Tracking
# ============================================

func start_assessment_session_tracking():
	"""Start tracking a new session for assessment mode"""
	session_start_timestamp = Time.get_unix_time_from_system()
	last_input_timestamp = session_start_timestamp
	total_idle_time = 0.0
	is_session_active = true
	current_session_pack = "Assessment"
	current_session_level = 0
	
	# Start TimeBack activity tracking for assessment
	if PlaycademySdk and PlaycademySdk.is_ready() and PlaycademySdk.timeback:
		var activity_metadata = {
			"activityId": "assessment",
			"activityName": "Skills Assessment",
			"grade": GameConfig.current_grade if GameConfig.current_grade > 0 else 3,
			"subject": "FastMath"
		}
		PlaycademySdk.timeback.start_activity(activity_metadata)

func end_assessment_session_and_award_xp() -> Dictionary:
	"""End assessment session tracking and calculate XP to award.
	Assessment uses a simple calculation: 1 XP per minute of active time.
	No performance multipliers - just flat time-based XP regardless of results."""
	if not is_session_active:
		return {"xp_awarded": 0, "details": "No active session"}
	
	session_end_timestamp = Time.get_unix_time_from_system()
	is_session_active = false
	
	# Calculate total session duration (wall clock time)
	var total_duration = session_end_timestamp - session_start_timestamp
	
	# Check for final idle period (from last input to session end)
	var time_since_last_input = session_end_timestamp - last_input_timestamp
	if time_since_last_input > GameConfig.timeback_idle_threshold:
		var final_idle = time_since_last_input - GameConfig.timeback_idle_threshold
		total_idle_time += final_idle
		print("[TimeBack] Final idle period: %.1fs" % final_idle)
	
	# Calculate active time (total - idle)
	var active_time = max(0.0, total_duration - total_idle_time)
	var active_minutes = active_time / 60.0
	
	# Simple XP calculation: 1 XP per minute of active time
	# No performance multipliers for assessment
	var xp_per_minute = 1.0
	var final_xp = round(active_minutes * xp_per_minute)
	
	# Get assessment results for logging
	var results = ScoreManager.assessment_all_results
	var standards_tested = results.size()
	var standards_mastered = 0
	for standard_id in results:
		if results[standard_id].get("mastered", false):
			standards_mastered += 1
	
	# Build detailed breakdown
	var details = {
		"total_duration": total_duration,
		"idle_time": total_idle_time,
		"active_time": active_time,
		"active_minutes": active_minutes,
		"xp_per_minute": xp_per_minute,
		"final_xp": final_xp,
		"standards_tested": standards_tested,
		"standards_mastered": standards_mastered
	}
	
	# Print detailed metrics
	print("\n" + "=".repeat(60))
	print("[TimeBack] ASSESSMENT COMPLETION METRICS")
	print("=".repeat(60))
	print("Standards Tested: %d" % standards_tested)
	print("Standards Mastered: %d" % standards_mastered)
	print("")
	print("TIME METRICS:")
	print("  Total session duration: %.1fs (%.2f minutes)" % [total_duration, total_duration / 60.0])
	print("  Idle time subtracted:   %.1fs (%.2f minutes)" % [total_idle_time, total_idle_time / 60.0])
	print("  Active time counted:    %.1fs (%.2f minutes)" % [active_time, active_minutes])
	print("")
	print("XP CALCULATION (Simple: 1 XP per minute):")
	print("  Active minutes: %.2f" % active_minutes)
	print("  XP per minute: %.1f" % xp_per_minute)
	print("  Final XP: %d" % final_xp)
	print("=".repeat(60) + "\n")
	
	# Only award if session meets minimum duration
	if total_duration >= GameConfig.timeback_min_session_duration:
		award_assessment_timeback_xp(int(final_xp), details)
	else:
		print("[TimeBack] ⚠ Session too short (%.1fs < %.1fs minimum), no XP awarded" % [total_duration, GameConfig.timeback_min_session_duration])
	
	return details

func award_assessment_timeback_xp(xp: int, details: Dictionary):
	"""Award XP through Playcademy TimeBack API for assessment mode"""
	if not PlaycademySdk or not PlaycademySdk.is_ready() or not PlaycademySdk.timeback:
		print("[TimeBack] SDK not ready, cannot award XP")
		return
	
	# Prepare score data - assessment doesn't track individual correct/total the same way
	# We'll use standards_tested as totalQuestions and standards_mastered as correctQuestions
	var score_data = {
		"correctQuestions": details.standards_mastered,
		"totalQuestions": details.standards_tested,
		"xpAwarded": xp
	}
	
	print("[TimeBack] Ending assessment activity with score_data: ", score_data)
	PlaycademySdk.timeback.end_activity(score_data)
