extends Node

# State manager - handles game state transitions and screen animations

# Node references
var main_menu_node: Control  # Reference to the MainMenu node
var game_over_node: Control  # Reference to the GameOver node
var play_node: Control  # Reference to the Play node

# Game state variables
var current_state = GameConfig.GameState.MENU
var current_pack_name = ""  # Current level pack being played (legacy)
var current_pack_level_index = 0  # Current level index within pack (0-based) (legacy)
var current_level_number = 0  # Current level number (1-9) (legacy)
var current_level_data = {}  # Current grade-based level data
var current_level_config = {}  # Current level config (star thresholds, problems count)
var problems_completed = 0  # Number of problems completed in current level
var user_answer = ""
var answer_submitted = false  # Track if current problem has been submitted
var in_transition_delay = false  # Whether we're currently in a transition delay
var waiting_for_continue_after_incorrect = false  # Whether we're waiting for player to press Submit to continue after incorrect answer
var is_drill_mode = false  # Whether we're currently in drill mode
var is_grade_level = false  # Whether we're playing a grade-based level
var is_assessment_mode = false  # Whether we're currently in assessment mode
var is_showing_assessment_primer = false  # Whether we're showing the assessment primer screen
var assessment_primer_label: Label = null  # Reference to the AssessmentPrimer label

func initialize(main_node: Control):
	"""Initialize state manager with references to needed nodes"""
	main_menu_node = main_node.get_node("MainMenu")
	game_over_node = main_node.get_node("GameOver")
	play_node = main_node.get_node("Play")
	assessment_primer_label = play_node.get_node_or_null("AssessmentPrimer")

func start_play_state(pack_name: String, pack_level_index: int):
	"""Transition from MENU to PLAY state"""
	current_state = GameConfig.GameState.PLAY
	is_drill_mode = false
	problems_completed = 0
	current_pack_name = pack_name
	current_pack_level_index = pack_level_index
	
	# Get the track ID from the pack configuration (legacy)
	var pack_config = GameConfig.legacy_level_packs[pack_name]
	QuestionManager.current_track = pack_config.levels[pack_level_index]
	
	# Calculate current_level_number for level_configs lookup (still needed for star requirements)
	var global_level_num = LevelManager.get_global_level_number(pack_name, pack_level_index)
	current_level_number = global_level_num
	
	# Reset scores
	ScoreManager.reset_for_new_level()
	
	# Reset input state
	InputManager.reset_for_new_question()
	
	# Reset answer state
	user_answer = ""
	answer_submitted = false
	in_transition_delay = false
	waiting_for_continue_after_incorrect = false
	
	# First animate menu down off screen (downward)
	var tween = main_menu_node.create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_EXPO)
	tween.tween_property(main_menu_node, "position", GameConfig.menu_below_screen, GameConfig.animation_duration)
	
	# After the downward animation completes, teleport to above screen
	tween.tween_callback(func(): main_menu_node.position = GameConfig.menu_above_screen)
	
	# Play node flies in from above
	play_node.position = GameConfig.menu_above_screen
	var play_tween = play_node.create_tween()
	play_tween.set_ease(Tween.EASE_OUT)
	play_tween.set_trans(Tween.TRANS_EXPO)
	play_tween.tween_property(play_node, "position", GameConfig.menu_on_screen, GameConfig.animation_duration)
	
	# Trigger scroll speed boost effect
	var space_bg = play_node.get_parent().get_node("BackgroundLayer/SpaceBackground")
	if space_bg and space_bg.has_method("boost_scroll_speed"):
		space_bg.boost_scroll_speed(GameConfig.scroll_boost_multiplier, GameConfig.animation_duration * 2.0)
	
	# Set UI visibility for normal mode
	UIManager.update_normal_mode_ui_visibility()
	
	# Initialize progress line
	UIManager.initialize_progress_line()
	
	# Initialize weighted question system for this track
	QuestionManager.initialize_question_weights_for_track(QuestionManager.current_track)
	
	# Start TimeBack session tracking
	PlaycademyManager.start_session_tracking(pack_name, pack_level_index)
	
	# Generate question first, then create the problem display
	QuestionManager.generate_new_question()
	DisplayManager.create_new_problem_label()

func start_drill_mode():
	"""Transition from MENU to DRILL_PLAY state"""
	current_state = GameConfig.GameState.DRILL_PLAY
	is_drill_mode = true
	problems_completed = 0
	
	# Reset scores
	ScoreManager.reset_for_drill_mode()
	
	# Reset input state
	InputManager.reset_for_new_question()
	
	# Reset answer state
	user_answer = ""
	answer_submitted = false
	in_transition_delay = false
	waiting_for_continue_after_incorrect = false
	
	# First animate menu down off screen (downward)
	var tween = main_menu_node.create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_EXPO)
	tween.tween_property(main_menu_node, "position", GameConfig.menu_below_screen, GameConfig.animation_duration)
	
	# After the downward animation completes, teleport to above screen
	tween.tween_callback(func(): main_menu_node.position = GameConfig.menu_above_screen)
	
	# Play node flies in from above
	play_node.position = GameConfig.menu_above_screen
	var play_tween = play_node.create_tween()
	play_tween.set_ease(Tween.EASE_OUT)
	play_tween.set_trans(Tween.TRANS_EXPO)
	play_tween.tween_property(play_node, "position", GameConfig.menu_on_screen, GameConfig.animation_duration)
	
	# Trigger scroll speed boost effect
	var space_bg = play_node.get_parent().get_node("BackgroundLayer/SpaceBackground")
	if space_bg and space_bg.has_method("boost_scroll_speed"):
		space_bg.boost_scroll_speed(GameConfig.scroll_boost_multiplier, GameConfig.animation_duration * 2.0)
	
	# Set UI visibility for drill mode
	UIManager.update_drill_mode_ui_visibility()
	
	# Initialize weighted question system for all tracks
	QuestionManager.initialize_question_weights_for_all_tracks()
	
	# Start TimeBack session tracking for drill mode
	PlaycademyManager.start_session_tracking("Drill Mode", 0)
	
	# Generate question first, then create the problem display
	QuestionManager.generate_new_question()
	DisplayManager.create_new_problem_label()

func go_to_game_over():
	"""Transition from PLAY to GAME_OVER state"""
	current_state = GameConfig.GameState.GAME_OVER
	
	# Stop the timer (should already be stopped, but ensure it)
	ScoreManager.timer_active = false
	
	# Get stars the player ALREADY had before this session (for XP star gate) (legacy)
	var pack_config = GameConfig.legacy_level_packs[current_pack_name]
	var level_track = pack_config.levels[current_pack_level_index]
	var track_id = str(level_track) if typeof(level_track) == TYPE_STRING else "TRACK" + str(level_track)
	var previous_stars = 0
	if SaveManager.save_data.packs.has(current_pack_name):
		var pack_data = SaveManager.save_data.packs[current_pack_name]
		if pack_data.has("levels") and pack_data.levels.has(track_id):
			previous_stars = pack_data.levels[track_id].highest_stars
	
	# Calculate and save level performance data
	var stars_earned = ScoreManager.evaluate_stars(current_level_number).size()
	SaveManager.update_level_data(current_pack_name, current_pack_level_index, ScoreManager.correct_answers, ScoreManager.current_level_time, stars_earned)
	
	# End session tracking and award XP through TimeBack (using PREVIOUS stars for star gate)
	if PlaycademyManager:
		PlaycademyManager.end_session_and_award_xp(current_pack_name, current_pack_level_index, current_level_number, QuestionManager.current_track, previous_stars)
	
	# Update GameOver labels with player performance
	UIManager.update_game_over_labels(current_level_number)
	
	# Update star requirement labels to show actual level requirements
	UIManager.update_star_requirement_labels(current_level_number)
	
	# Set normal mode game over UI visibility
	UIManager.update_normal_mode_game_over_ui_visibility()
	
	# Initialize star states (make all stars invisible, continue button invisible)
	UIManager.initialize_star_states()
	
	# Clean up any remaining problem labels (including prompt since level is ending)
	DisplayManager.cleanup_all_labels()
	
	# Play node flies down off screen
	var play_tween = play_node.create_tween()
	play_tween.set_ease(Tween.EASE_OUT)
	play_tween.set_trans(Tween.TRANS_EXPO)
	play_tween.tween_property(play_node, "position", GameConfig.menu_below_screen, GameConfig.animation_duration)
	
	# GameOver teleports to above screen, then animates down to center
	game_over_node.position = GameConfig.menu_above_screen
	var tween = game_over_node.create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_EXPO)
	tween.tween_property(game_over_node, "position", GameConfig.menu_on_screen, GameConfig.animation_duration)
	
	# Start star animation sequence after GameOver animation completes
	tween.tween_callback(UIManager.start_star_animation_sequence.bind(current_level_number))

func go_to_drill_mode_game_over():
	"""Transition from DRILL_PLAY to GAME_OVER state"""
	current_state = GameConfig.GameState.GAME_OVER
	
	# Stop the timer
	ScoreManager.timer_active = false
	
	# Update drill mode high score if needed (this may trigger celebration)
	var is_new_high_score = SaveManager.update_drill_mode_high_score(ScoreManager.drill_score)
	
	# Update GameOver labels with drill mode performance
	UIManager.update_drill_mode_game_over_labels()
	
	# End session tracking and award XP through TimeBack
	if PlaycademyManager:
		PlaycademyManager.end_drill_session_and_award_xp()
	
	# Set drill mode game over UI visibility
	UIManager.update_drill_mode_game_over_ui_visibility()
	
	# Trigger high score celebration if new high score
	if is_new_high_score:
		UIManager.start_high_score_celebration()
	
	# Clean up any remaining problem labels (including prompt since level is ending)
	DisplayManager.cleanup_all_labels()
	
	# Play node flies down off screen
	var play_tween = play_node.create_tween()
	play_tween.set_ease(Tween.EASE_OUT)
	play_tween.set_trans(Tween.TRANS_EXPO)
	play_tween.tween_property(play_node, "position", GameConfig.menu_below_screen, GameConfig.animation_duration)
	
	# GameOver teleports to above screen, then animates down to center
	game_over_node.position = GameConfig.menu_above_screen
	var tween = game_over_node.create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_EXPO)
	tween.tween_property(game_over_node, "position", GameConfig.menu_on_screen, GameConfig.animation_duration)
	
	# Show continue button immediately for drill mode (no star animation)
	UIManager.show_continue_button()
	
	# Attempt to submit score to Playcademy (non-blocking)
	if PlaycademyManager:
		PlaycademyManager.attempt_playcademy_auto_submit()

func return_to_menu():
	"""Transition from GAME_OVER to MENU state"""
	current_state = GameConfig.GameState.MENU
	var was_assessment = is_assessment_mode  # Remember if we just completed assessment
	is_drill_mode = false  # Reset drill mode flag
	is_grade_level = false  # Reset grade level flag
	is_assessment_mode = false  # Reset assessment mode flag
	is_showing_assessment_primer = false  # Reset assessment primer flag
	current_level_data = {}  # Clear level data
	current_level_config = {}  # Clear level config
	
	# If we just completed the assessment, create level buttons for the first time
	if was_assessment and SaveManager.is_assessment_completed():
		# Player just completed assessment - create level buttons and show normal menu
		LevelManager.create_level_buttons()
	
	# Update menu display with new save data
	LevelManager.update_grade_display()  # Update visibility of PlayButton/navigation
	LevelManager.update_menu_stars()
	LevelManager.update_level_availability()
	UIManager.update_drill_mode_high_score_display()
	
	# Fetch and log Timeback XP data for testing
	PlaycademyManager.fetch_and_log_xp()
	
	# MainMenu teleports to above screen, then animates down to center
	main_menu_node.position = GameConfig.menu_above_screen
	var menu_tween = main_menu_node.create_tween()
	menu_tween.set_ease(Tween.EASE_OUT)
	menu_tween.set_trans(Tween.TRANS_EXPO)
	menu_tween.tween_property(main_menu_node, "position", GameConfig.menu_on_screen, GameConfig.animation_duration)
	
	# At the same time, GameOver moves down to below screen
	var gameover_tween = game_over_node.create_tween()
	gameover_tween.set_ease(Tween.EASE_OUT)
	gameover_tween.set_trans(Tween.TRANS_EXPO)
	gameover_tween.tween_property(game_over_node, "position", GameConfig.menu_below_screen, GameConfig.animation_duration)

func _on_level_button_pressed(pack_name: String, pack_level_index: int):
	"""Handle level button press - only respond during MENU state (LEGACY)"""
	if current_state != GameConfig.GameState.MENU:
		return
	
	start_play_state(pack_name, pack_level_index)

func _on_grade_level_button_pressed(level_data: Dictionary):
	"""Handle grade-based level button press - only respond during MENU state"""
	if current_state != GameConfig.GameState.MENU:
		return
	
	start_grade_level_play_state(level_data)

func start_grade_level_play_state(level_data: Dictionary):
	"""Transition from MENU to PLAY state for grade-based levels"""
	current_state = GameConfig.GameState.PLAY
	is_drill_mode = false
	is_grade_level = true
	problems_completed = 0
	current_level_data = level_data
	
	# Store mastery_count directly in level_config for easy access
	current_level_config = {"mastery_count": level_data.mastery_count}
	
	# Set up the dynamic question generation config
	var generation_config = level_data.config.duplicate()
	generation_config["name"] = level_data.name
	QuestionManager.set_level_generation_config(generation_config)
	
	# Reset scores
	ScoreManager.reset_for_new_level()
	
	# Reset input state
	InputManager.reset_for_new_question()
	
	# Reset answer state
	user_answer = ""
	answer_submitted = false
	in_transition_delay = false
	waiting_for_continue_after_incorrect = false
	
	# First animate menu down off screen (downward)
	var tween = main_menu_node.create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_EXPO)
	tween.tween_property(main_menu_node, "position", GameConfig.menu_below_screen, GameConfig.animation_duration)
	
	# After the downward animation completes, teleport to above screen
	tween.tween_callback(func(): main_menu_node.position = GameConfig.menu_above_screen)
	
	# Play node flies in from above
	play_node.position = GameConfig.menu_above_screen
	var play_tween = play_node.create_tween()
	play_tween.set_ease(Tween.EASE_OUT)
	play_tween.set_trans(Tween.TRANS_EXPO)
	play_tween.tween_property(play_node, "position", GameConfig.menu_on_screen, GameConfig.animation_duration)
	
	# Trigger scroll speed boost effect
	var space_bg = play_node.get_parent().get_node("BackgroundLayer/SpaceBackground")
	if space_bg and space_bg.has_method("boost_scroll_speed"):
		space_bg.boost_scroll_speed(GameConfig.scroll_boost_multiplier, GameConfig.animation_duration * 2.0)
	
	# Set UI visibility for normal mode
	UIManager.update_normal_mode_ui_visibility()
	
	# Initialize progress line and new timer/accuracy lines
	UIManager.initialize_progress_line()
	UIManager.initialize_timer_line()
	UIManager.initialize_accuracy_line()
	
	# Start TimeBack session tracking with level data
	PlaycademyManager.start_grade_level_session_tracking(level_data)
	
	# Generate question first, then create the problem display
	QuestionManager.generate_new_question()
	DisplayManager.create_new_problem_label()

func go_to_grade_level_game_over():
	"""Transition from PLAY to GAME_OVER state for grade-based levels"""
	current_state = GameConfig.GameState.GAME_OVER
	
	# Stop the timer (should already be stopped, but ensure it)
	ScoreManager.timer_active = false
	
	# Get mastery_count from level config
	var mastery_count = current_level_config.mastery_count
	
	# Get stars the player ALREADY had before this session (for XP calculation)
	var level_id = current_level_data.id
	var previous_stars = SaveManager.get_grade_level_stars(level_id)
	
	# Calculate stars earned using the new mastery-based system
	var stars_earned_array = ScoreManager.evaluate_stars_for_mastery_count(mastery_count)
	var stars_earned = stars_earned_array.size()
	
	# Save level performance data
	SaveManager.update_grade_level_data(level_id, ScoreManager.correct_answers, ScoreManager.current_level_time, stars_earned)
	
	# End session tracking and award XP through TimeBack (using PREVIOUS stars for multiplier)
	var xp_result = {}
	if PlaycademyManager:
		xp_result = PlaycademyManager.end_grade_level_session_and_award_xp(current_level_data, previous_stars, stars_earned)
	
	# Update GameOver labels with player performance
	UIManager.update_game_over_labels_for_mastery(mastery_count)
	
	# Update XP earned label
	var xp_earned = xp_result.get("final_xp", 0.0) if xp_result else 0.0
	UIManager.update_xp_earned_label(xp_earned)
	
	# Update star requirement labels to show requirements based on mastery_count
	UIManager.update_star_requirement_labels_for_mastery(mastery_count)
	
	# Set normal mode game over UI visibility
	UIManager.update_normal_mode_game_over_ui_visibility()
	
	# Initialize star states (make all stars invisible, continue button invisible)
	UIManager.initialize_star_states()
	
	# Clean up any remaining problem labels (including prompt since level is ending)
	DisplayManager.cleanup_all_labels()
	
	# Clear the dynamic generation config
	QuestionManager.current_level_config = null
	
	# Play node flies down off screen
	var play_tween = play_node.create_tween()
	play_tween.set_ease(Tween.EASE_OUT)
	play_tween.set_trans(Tween.TRANS_EXPO)
	play_tween.tween_property(play_node, "position", GameConfig.menu_below_screen, GameConfig.animation_duration)
	
	# GameOver teleports to above screen, then animates down to center
	game_over_node.position = GameConfig.menu_above_screen
	var tween = game_over_node.create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_EXPO)
	tween.tween_property(game_over_node, "position", GameConfig.menu_on_screen, GameConfig.animation_duration)
	
	# Start star animation sequence after GameOver animation completes
	tween.tween_callback(UIManager.start_star_animation_sequence_for_mastery.bind(mastery_count))

func _on_exit_button_pressed():
	"""Handle exit button press"""
	# Use PlaycademySdk.runtime.exit() when available, otherwise fall back to quit
	if PlaycademySdk and PlaycademySdk.is_ready():
		PlaycademySdk.runtime.exit()
	else:
		# Fallback to normal quit for non-Playcademy environments
		get_tree().quit() 
	
	get_tree().quit()

func _on_reset_data_button_pressed():
	"""Handle reset data button press - wipe all save data and reset menu UI"""
	if current_state != GameConfig.GameState.MENU:
		return
	
	SaveManager.reset_all_data()
	
	# Update menu display with reset data
	LevelManager.update_menu_stars()
	LevelManager.update_level_availability()

func _on_unlock_all_button_pressed():
	"""Handle unlock all button press - unlock current grade with 3 stars and advance to next (DEV ONLY)"""
	if current_state != GameConfig.GameState.MENU:
		return
	
	SaveManager.unlock_all_levels()
	
	# Recreate level buttons for the new grade (if changed)
	LevelManager.create_level_buttons()
	
	# Update menu display with unlocked levels
	LevelManager.update_menu_stars()
	LevelManager.update_level_availability()
	LevelManager.update_grade_display()
	UIManager.update_drill_mode_high_score_display()

func _on_drill_mode_button_pressed():
	"""Handle drill mode button press - start drill mode"""
	if current_state != GameConfig.GameState.MENU:
		return
	
	start_drill_mode()

func _on_drill_mode_button_hover_enter():
	"""Handle drill mode button hover enter - show unlock requirements if disabled"""
	var drill_mode_button = main_menu_node.get_node("DrillModeButton")
	if drill_mode_button and drill_mode_button.disabled:
		var unlock_requirements = drill_mode_button.get_node("UnlockRequirements")
		if unlock_requirements:
			unlock_requirements.visible = true

func _on_drill_mode_button_hover_exit():
	"""Handle drill mode button hover exit - hide unlock requirements"""
	var drill_mode_button = main_menu_node.get_node("DrillModeButton")
	if drill_mode_button:
		var unlock_requirements = drill_mode_button.get_node("UnlockRequirements")
		if unlock_requirements:
			unlock_requirements.visible = false

func _on_continue_button_pressed():
	"""Handle continue button press - only respond during GAME_OVER state"""
	if current_state != GameConfig.GameState.GAME_OVER:
		return
	
	return_to_menu()

# ============================================
# Assessment Mode Functions
# ============================================

func _on_play_button_pressed():
	"""Handle PlayButton press for new players - only respond during MENU state"""
	if current_state != GameConfig.GameState.MENU:
		return
	
	start_assessment_primer()

func start_assessment_primer():
	"""Transition from MENU to PLAY state showing AssessmentPrimer screen"""
	current_state = GameConfig.GameState.PLAY
	is_drill_mode = false
	is_grade_level = false
	is_assessment_mode = true
	is_showing_assessment_primer = true
	problems_completed = 0
	
	# First animate menu down off screen (downward)
	var tween = main_menu_node.create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_EXPO)
	tween.tween_property(main_menu_node, "position", GameConfig.menu_below_screen, GameConfig.animation_duration)
	
	# After the downward animation completes, teleport to above screen
	tween.tween_callback(func(): main_menu_node.position = GameConfig.menu_above_screen)
	
	# Play node flies in from above
	play_node.position = GameConfig.menu_above_screen
	var play_tween = play_node.create_tween()
	play_tween.set_ease(Tween.EASE_OUT)
	play_tween.set_trans(Tween.TRANS_EXPO)
	play_tween.tween_property(play_node, "position", GameConfig.menu_on_screen, GameConfig.animation_duration)
	
	# Show AssessmentPrimer label
	if assessment_primer_label:
		assessment_primer_label.visible = true
	
	# Hide all play UI elements (assessment primer is a clean screen)
	UIManager.update_assessment_mode_ui_visibility()
	
	# Hide ControlGuide during primer
	var control_guide = play_node.get_node_or_null("ControlGuide")
	if control_guide:
		control_guide.visible = false

func dismiss_assessment_primer():
	"""Dismiss the AssessmentPrimer and start the actual assessment"""
	if not is_showing_assessment_primer:
		return
	
	is_showing_assessment_primer = false
	
	# Animate AssessmentPrimer flying off screen downward (same as problem fly-off animation)
	if assessment_primer_label:
		var tween = assessment_primer_label.create_tween()
		tween.set_ease(Tween.EASE_OUT)
		tween.set_trans(Tween.TRANS_EXPO)
		# Fly down off screen (same pattern as animate_problem_off_screen)
		var target_y = GameConfig.off_screen_top.y  # Below screen (Y = 1276)
		tween.tween_property(assessment_primer_label, "position:y", target_y, GameConfig.animation_duration)
		tween.tween_callback(func():
			assessment_primer_label.visible = false
			assessment_primer_label.position.y = 0  # Reset position for next time
		)
	
	# Now actually start the assessment
	start_assessment_mode()

func start_assessment_mode():
	"""Start the actual assessment after AssessmentPrimer is dismissed"""
	current_state = GameConfig.GameState.ASSESSMENT_PLAY
	
	# Show ControlGuide again (was hidden during primer)
	var control_guide = play_node.get_node_or_null("ControlGuide")
	if control_guide:
		control_guide.visible = true
	
	# Reset scores for assessment
	ScoreManager.reset_for_assessment()
	
	# Initialize first eligible standard (checking prerequisites)
	if not ScoreManager.initialize_first_assessment_standard():
		# No eligible standards - immediately complete
		print("[StateManager] Assessment has no eligible standards!")
		complete_assessment()
		return
	
	# Reset input state
	InputManager.reset_for_new_question()
	
	# Reset answer state
	user_answer = ""
	answer_submitted = false
	in_transition_delay = false
	waiting_for_continue_after_incorrect = false
	
	# Enable assessment mode in question manager
	QuestionManager.set_assessment_mode(true)
	
	# Trigger scroll speed boost effect
	var space_bg = play_node.get_parent().get_node("BackgroundLayer/SpaceBackground")
	if space_bg and space_bg.has_method("boost_scroll_speed"):
		space_bg.boost_scroll_speed(GameConfig.scroll_boost_multiplier, GameConfig.animation_duration * 2.0)
	
	# Start TimeBack session tracking for assessment mode
	PlaycademyManager.start_assessment_session_tracking()
	
	# Generate first question from first standard
	_generate_next_assessment_question()
	DisplayManager.create_new_problem_label()

func _generate_next_assessment_question():
	"""Generate the next question for assessment mode based on current standard"""
	var standard = ScoreManager.get_current_assessment_standard()
	if standard.is_empty():
		print("[Assessment] No more standards - assessment complete!")
		return
	
	# Generate a question using the assessment-specific generation
	var config = standard.config.duplicate()
	config["name"] = standard.name
	QuestionManager.current_question = QuestionManager.generate_assessment_question(standard)

func process_assessment_answer(is_correct: bool, time_taken_raw: float):
	"""Process an answer in assessment mode
	time_taken_raw is the raw time; we subtract transition_delay here
	"""
	# Subtract transition delay from time (time only counts after animation)
	var time_taken = max(0.0, time_taken_raw - GameConfig.transition_delay)
	
	# Process the answer and check if we should advance
	var result = ScoreManager.process_assessment_answer(is_correct, time_taken)
	
	if result.should_advance:
		# Move to next standard (pass early_exit flag)
		var has_more = ScoreManager.advance_to_next_standard(result.get("early_exit", false))
		if not has_more:
			# Assessment complete!
			go_to_assessment_game_over()
			return
		
		# Clear used questions for new standard
		QuestionManager.used_questions_this_level.clear()
	
	# Generate next question (either same standard or new standard)
	if not ScoreManager.is_assessment_complete():
		_generate_next_assessment_question()

func complete_assessment():
	"""Called when all assessment questions are completed - transitions to game over"""
	go_to_assessment_game_over()

func go_to_assessment_game_over():
	"""Transition from ASSESSMENT_PLAY to GAME_OVER state"""
	current_state = GameConfig.GameState.GAME_OVER
	
	# Get final results
	var final_results = ScoreManager.get_assessment_final_results()
	
	# Save assessment results to KV storage
	SaveManager.save_assessment_results(final_results)
	
	# End session tracking and award XP through TimeBack (simple 1 XP per minute)
	if PlaycademyManager:
		PlaycademyManager.end_assessment_session_and_award_xp()
	
	# Disable assessment mode in question manager
	QuestionManager.set_assessment_mode(false)
	QuestionManager.current_level_config = null
	
	# Update GameOver labels for assessment mode (minimal display)
	UIManager.update_assessment_game_over_ui()
	
	# Initialize star states for assessment (5 stars, one per grade)
	UIManager.initialize_assessment_star_states()
	
	# Clean up any remaining problem labels (including prompt since assessment is ending)
	DisplayManager.cleanup_all_labels()
	
	# Play node flies down off screen
	var play_tween = play_node.create_tween()
	play_tween.set_ease(Tween.EASE_OUT)
	play_tween.set_trans(Tween.TRANS_EXPO)
	play_tween.tween_property(play_node, "position", GameConfig.menu_below_screen, GameConfig.animation_duration)
	
	# GameOver teleports to above screen, then animates down to center
	game_over_node.position = GameConfig.menu_above_screen
	var tween = game_over_node.create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_EXPO)
	tween.tween_property(game_over_node, "position", GameConfig.menu_on_screen, GameConfig.animation_duration)
	
	# Start assessment 5-star animation sequence (one star per grade with Grade labels)
	tween.tween_callback(UIManager.start_assessment_star_animation_sequence)
