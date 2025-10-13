extends Node

# Playcademy manager - handles all Playcademy SDK integration

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

func record_level_progress(pack_name: String, pack_level_index: int, current_level_number: int, current_track, stars_earned: int):
	"""Record level progress to Playcademy TimeBack (1 minute = 1 XP)"""
	if PlaycademySdk and PlaycademySdk.is_ready() and PlaycademySdk.timeback:
		var level_config = GameConfig.level_configs.get(current_level_number, GameConfig.level_configs[1])
		var total_questions = level_config.problems
		
		# Get activity name from track data
		var activity_name = pack_name + " - Level " + str(pack_level_index + 1)
		var question_data = QuestionManager.get_math_question(current_track)
		if question_data and question_data.has("title"):
			activity_name = question_data.title
		
		# Calculate XP: 1 minute = 1 XP
		var xp_earned = int(ScoreManager.current_level_time / 60.0)
		
		var progress_data = {
			"score": int((float(ScoreManager.correct_answers) / float(total_questions)) * 100),
			"totalQuestions": total_questions,
			"correctQuestions": ScoreManager.correct_answers,
			"xpEarned": xp_earned,
			"activityId": "level-" + pack_name + "-" + str(pack_level_index),
			"activityName": activity_name,
			"stars": stars_earned,
			"timeSeconds": int(ScoreManager.current_level_time)
		}
		
		print("[Playcademy] Recording progress: ", progress_data)
		PlaycademySdk.timeback.record_progress(progress_data)

func record_drill_mode_progress():
	"""Record drill mode progress to Playcademy TimeBack (1 minute = 1 XP)"""
	if PlaycademySdk and PlaycademySdk.is_ready() and PlaycademySdk.timeback:
		# Calculate XP: 1 minute = 1 XP
		var xp_earned = int(ScoreManager.current_level_time / 60.0)
		
		var progress_data = {
			"score": ScoreManager.drill_score,
			"totalQuestions": ScoreManager.drill_total_answered,
			"correctQuestions": ScoreManager.correct_answers,
			"xpEarned": xp_earned,
			"activityId": "drill-mode",
			"activityName": "Drill Mode",
			"timeSeconds": int(ScoreManager.current_level_time),
			"mode": "drill"
		}
		
		print("[Playcademy] Recording drill mode progress: ", progress_data)
		PlaycademySdk.timeback.record_progress(progress_data)

