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
	current_session_pack = "Grade" + str(GameConfig.current_grade)
	current_session_level = 0
	
	# Start TimeBack activity tracking with proper level info
	if PlaycademySdk and PlaycademySdk.is_ready() and PlaycademySdk.timeback:
		var activity_metadata = {
			"activityId": level_data.id,
			"activityName": level_data.name,
			"grade": GameConfig.current_grade,
			"subject": "FastMath"
		}
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
	"""End session tracking for grade-based levels and calculate XP to award using the new simplified system.
	XP = (base_time_xp + new_star_bonus) × previous_star_multiplier
	- base_time_xp: 0.5 XP per minute of active play (excluding idle time)
	- new_star_bonus: +0.25 for 1st star, +0.25 for 2nd star, +0.5 for 3rd star (only for newly earned stars)
	- previous_star_multiplier: x1.0 (0 stars), x0.75 (1 star), x0.5 (2 stars), x0.25 (3 stars)
	- No XP is awarded if player didn't earn at least 1 star this playthrough"""
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
	
	# Get performance stats for logging
	var correct_answers = ScoreManager.correct_answers
	var total_answers = ScoreManager.total_answers
	var game_time = ScoreManager.current_level_time
	var cqpm = 0.0
	if game_time > 0:
		cqpm = (float(correct_answers) / game_time) * 60.0
	
	# Calculate base XP from time spent (0.5 XP per minute, rounded to nearest hundredth)
	var base_time_xp = snapped(active_minutes * GameConfig.timeback_base_xp_per_minute, 0.01)
	
	# Calculate star bonus for newly earned stars
	var new_star_bonus = 0.0
	if new_stars >= 1 and previous_stars < 1:
		new_star_bonus += GameConfig.timeback_star1_bonus
	if new_stars >= 2 and previous_stars < 2:
		new_star_bonus += GameConfig.timeback_star2_bonus
	if new_stars >= 3 and previous_stars < 3:
		new_star_bonus += GameConfig.timeback_star3_bonus
	
	# Get multiplier based on previously earned stars
	var previous_star_multiplier = GameConfig.timeback_previous_star_multipliers.get(previous_stars, 1.0)
	
	# Calculate final XP: (base + bonus) × multiplier
	# NO XP if player didn't earn at least 1 star this playthrough
	var final_xp = 0.0
	var calculated_xp = 0.0
	var xp_top_up = 0.0
	if new_stars >= 1:
		calculated_xp = snapped((base_time_xp + new_star_bonus) * previous_star_multiplier, 0.01)
		final_xp = calculated_xp
	
	# Apply minimum XP guarantee for mastery (3 stars)
	# If player masters the level and their cumulative XP would still be below minimum, top up to reach it
	var previous_xp_earned = SaveManager.get_grade_level_xp_earned(level_data.id)
	var mastery_min_xp = GameConfig.timeback_mastery_min_xp
	if new_stars >= 3:
		var projected_total = previous_xp_earned + calculated_xp
		if projected_total < mastery_min_xp:
			xp_top_up = mastery_min_xp - projected_total
			final_xp = calculated_xp + xp_top_up
	
	# Build detailed breakdown
	var details = {
		"total_duration": total_duration,
		"idle_time": total_idle_time,
		"active_time": active_time,
		"active_minutes": active_minutes,
		"game_time": game_time,
		"correct_answers": correct_answers,
		"total_answers": total_answers,
		"cqpm": cqpm,
		"base_time_xp": base_time_xp,
		"new_star_bonus": new_star_bonus,
		"previous_stars": previous_stars,
		"new_stars": new_stars,
		"previous_star_multiplier": previous_star_multiplier,
		"calculated_xp": calculated_xp,
		"previous_xp_earned": previous_xp_earned,
		"mastery_min_xp": mastery_min_xp,
		"xp_top_up": xp_top_up,
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
	print("TIME METRICS:")
	print("  Total session duration: %.1fs (%.2f minutes)" % [total_duration, total_duration / 60.0])
	print("  Idle time subtracted:   %.1fs (%.2f minutes)" % [total_idle_time, total_idle_time / 60.0])
	print("  Active time counted:    %.1fs (%.2f minutes)" % [active_time, active_minutes])
	print("  Game timer (in-game):   %.1fs (%.2f minutes)" % [game_time, game_time / 60.0])
	print("")
	print("PERFORMANCE METRICS:")
	print("  Correct answers: %d / %d" % [correct_answers, total_answers])
	print("  CQPM (%.0f / %.1fs × 60): %.2f" % [correct_answers, game_time, cqpm])
	print("")
	print("XP CALCULATION:")
	print("  Base time XP (%.2f min × %.1f XP/min) = %.2f" % [active_minutes, GameConfig.timeback_base_xp_per_minute, base_time_xp])
	print("  New star bonus: +%.2f" % new_star_bonus)
	print("  Previous star multiplier (%d stars): %.2fx" % [previous_stars, previous_star_multiplier])
	if new_stars >= 1:
		print("  Calculated XP ((%.2f + %.2f) × %.2fx) = %.2f XP" % [base_time_xp, new_star_bonus, previous_star_multiplier, calculated_xp])
	else:
		print("  Calculated XP: 0 (no stars earned this playthrough)")
	print("")
	print("MASTERY XP GUARANTEE (min %.1f XP):" % mastery_min_xp)
	print("  Previous XP earned for this level: %.2f" % previous_xp_earned)
	if new_stars >= 3:
		var projected_total = previous_xp_earned + calculated_xp
		print("  Projected total (%.2f + %.2f) = %.2f" % [previous_xp_earned, calculated_xp, projected_total])
		if xp_top_up > 0:
			print("  Top-up to reach minimum %.1f XP: +%.2f" % [mastery_min_xp, xp_top_up])
		else:
			print("  Already at or above %.1f XP minimum, no top-up needed" % mastery_min_xp)
	else:
		print("  Mastery (3 stars) not achieved, minimum XP guarantee does not apply")
	print("  Final XP awarded this session: %.2f" % final_xp)
	print("  New cumulative XP for level: %.2f" % (previous_xp_earned + final_xp))
	print("=".repeat(60) + "\n")
	
	# Only award if session meets minimum duration and player earned at least 1 star
	if total_duration >= GameConfig.timeback_min_session_duration and new_stars >= 1:
		award_grade_level_timeback_xp(int(round(final_xp)), details, level_data.mastery_count)
		# Update cumulative XP earned for this level in KV storage
		SaveManager.add_grade_level_xp_earned(level_data.id, final_xp)
	elif new_stars < 1:
		print("[TimeBack] ⚠ No stars earned this playthrough, no XP awarded")
	else:
		print("[TimeBack] ⚠ Session too short (%.1fs < %.1fs minimum), no XP awarded" % [total_duration, GameConfig.timeback_min_session_duration])
	
	return details

func award_grade_level_timeback_xp(xp: int, details: Dictionary, _mastery_count: int):
	"""Award XP through Playcademy TimeBack API for grade-based levels"""
	if not PlaycademySdk or not PlaycademySdk.is_ready() or not PlaycademySdk.timeback:
		print("[TimeBack] SDK not ready, cannot award XP")
		return
	
	# Calculate newly earned stars (additive mastery units)
	# e.g., if player got 3 stars but already had 2, masteredUnits = 1
	var previous_stars = details.get("previous_stars", 0)
	var new_stars = details.get("new_stars", 0)
	var mastered_units = max(0, new_stars - previous_stars)
	
	# Prepare score data with manual XP override
	var score_data = {
		"correctQuestions": details.correct_answers,
		"totalQuestions": details.total_answers,
		"xpAwarded": xp
	}
	
	# Only include masteredUnits if new stars were earned
	if mastered_units > 0:
		score_data["masteredUnits"] = mastered_units
		print("[TimeBack] New stars earned: %d (was %d, now %d)" % [mastered_units, previous_stars, new_stars])
	
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
	
	PlaycademySdk.timeback.end_activity(score_data)
