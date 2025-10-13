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
	"""Connect Playcademy Scores API signals if available"""
	if Engine.has_singleton("PlaycademySdk") or (typeof(PlaycademySdk) != TYPE_NIL):
		if PlaycademySdk and PlaycademySdk.scores:
			if not PlaycademySdk.scores.submit_succeeded.is_connected(_on_pc_submit_succeeded):
				PlaycademySdk.scores.submit_succeeded.connect(_on_pc_submit_succeeded)
			if not PlaycademySdk.scores.submit_failed.is_connected(_on_pc_submit_failed):
				PlaycademySdk.scores.submit_failed.connect(_on_pc_submit_failed)

func _on_pc_submit_succeeded(_score_data):
	"""Handle successful Playcademy score submission"""
	print("Playcademy score submitted successfully: ", _score_data)

func _on_pc_submit_failed(error_message):
	"""Handle failed Playcademy score submission"""
	print("Playcademy score submit failed: ", error_message)

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
	"""Start tracking a new session"""
	session_start_timestamp = Time.get_unix_time_from_system()
	last_input_timestamp = session_start_timestamp
	total_idle_time = 0.0
	is_session_active = true
	current_session_pack = pack_name
	current_session_level = level_index
	print("[TimeBack] Session started: ", pack_name, " Level ", level_index + 1, " at timestamp ", session_start_timestamp)

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
	
	# Calculate XP
	var base_xp = active_minutes * GameConfig.timeback_base_xp_per_minute
	var final_xp = int(base_xp * cqpm_multiplier)
	
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
	print("")
	print("XP CALCULATION:")
	print("  Base XP (%.2f min × %.1f XP/min) = %.2f" % [active_minutes, GameConfig.timeback_base_xp_per_minute, base_xp])
	print("  Final XP (%.2f × %.2fx multiplier) = %d XP" % [base_xp, cqpm_multiplier, final_xp])
	print("=".repeat(60) + "\n")
	
	# Only award if session meets minimum duration
	if total_duration >= GameConfig.timeback_min_session_duration:
		award_timeback_xp(final_xp, details, pack_name, pack_level_index, current_track, stars_earned)
	else:
		print("[TimeBack] ⚠ Session too short (%.1fs < %.1fs minimum), no XP awarded" % [total_duration, GameConfig.timeback_min_session_duration])
	
	return details

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
	var final_xp = int(base_xp * cqpm_multiplier)
	
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

func award_timeback_xp(xp: int, details: Dictionary, pack_name: String, pack_level_index: int, current_track, stars_earned: int):
	"""Award XP through Playcademy TimeBack API"""
	if not PlaycademySdk or not PlaycademySdk.is_ready() or not PlaycademySdk.timeback:
		print("[TimeBack] SDK not ready, cannot award XP")
		return
	
	# Get level configuration
	var level_number = details.level_number
	var level_config = GameConfig.level_configs.get(level_number, GameConfig.level_configs[1])
	var total_questions = level_config.problems
	
	# Get activity name
	var activity_name = pack_name + " - Level " + str(pack_level_index + 1)
	var question_data = QuestionManager.get_math_question(current_track)
	if question_data and question_data.has("title"):
		activity_name = question_data.title
	
	# Prepare progress data
	var progress_data = {
		"score": int((float(details.correct_answers) / float(total_questions)) * 100),
		"totalQuestions": total_questions,
		"correctQuestions": details.correct_answers,
		"xpEarned": xp,
		"activityId": "level-" + pack_name + "-" + str(pack_level_index),
		"activityName": activity_name,
		"stars": stars_earned,
		"timeSeconds": int(details.active_time),
		# Additional metadata for analytics
		"metadata": {
			"cqpm": details.cqpm,
			"cqpm_multiplier": details.cqpm_multiplier,
			"total_duration": details.total_duration,
			"idle_time": details.idle_time,
			"active_time": details.active_time,
			"game_time": details.game_time,
			"level_number": level_number
		}
	}
	
	print("[TimeBack] ✓ Recording progress with %d XP to Playcademy..." % xp)
	PlaycademySdk.timeback.record_progress(progress_data)

func award_drill_mode_timeback_xp(xp: int, details: Dictionary):
	"""Award XP through Playcademy TimeBack API for drill mode"""
	if not PlaycademySdk or not PlaycademySdk.is_ready() or not PlaycademySdk.timeback:
		print("[TimeBack] SDK not ready, cannot award XP")
		return
	
	# Prepare progress data
	var progress_data = {
		"score": details.drill_score,
		"totalQuestions": details.total_answered,
		"correctQuestions": details.correct_answers,
		"xpEarned": xp,
		"activityId": "drill-mode",
		"activityName": "Drill Mode",
		"timeSeconds": int(details.active_time),
		"mode": "drill",
		# Additional metadata for analytics
		"metadata": {
			"cqpm": details.cqpm,
			"cqpm_multiplier": details.cqpm_multiplier,
			"total_duration": details.total_duration,
			"idle_time": details.idle_time,
			"active_time": details.active_time,
			"game_time": details.game_time
		}
	}
	
	print("[TimeBack] ✓ Recording drill mode progress with %d XP to Playcademy..." % xp)
	PlaycademySdk.timeback.record_progress(progress_data)
