extends Node

# State manager - handles game state transitions and screen animations

# Node references
var main_menu_node: Control  # Reference to the MainMenu node
var game_over_node: Control  # Reference to the GameOver node
var play_node: Control  # Reference to the Play node

# Game state variables
var current_state = GameConfig.GameState.MENU
var current_pack_name = ""  # Current level pack being played
var current_pack_level_index = 0  # Current level index within pack (0-based)
var current_level_number = 0  # Current level number (1-9)
var problems_completed = 0  # Number of problems completed in current level
var user_answer = ""
var answer_submitted = false  # Track if current problem has been submitted
var in_transition_delay = false  # Whether we're currently in a transition delay
var waiting_for_continue_after_incorrect = false  # Whether we're waiting for player to press Submit to continue after incorrect answer
var is_drill_mode = false  # Whether we're currently in drill mode

func initialize(main_node: Control):
	"""Initialize state manager with references to needed nodes"""
	main_menu_node = main_node.get_node("MainMenu")
	game_over_node = main_node.get_node("GameOver")
	play_node = main_node.get_node("Play")

func start_play_state(pack_name: String, pack_level_index: int):
	"""Transition from MENU to PLAY state"""
	current_state = GameConfig.GameState.PLAY
	is_drill_mode = false
	problems_completed = 0
	current_pack_name = pack_name
	current_pack_level_index = pack_level_index
	
	# Get the track ID from the pack configuration
	var pack_config = GameConfig.level_packs[pack_name]
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
	
	# Generate question first, then create the problem display
	QuestionManager.generate_new_question()
	DisplayManager.create_new_problem_label()

func go_to_game_over():
	"""Transition from PLAY to GAME_OVER state"""
	current_state = GameConfig.GameState.GAME_OVER
	
	# Stop the timer (should already be stopped, but ensure it)
	ScoreManager.timer_active = false
	
	# Calculate and save level performance data
	var stars_earned = ScoreManager.evaluate_stars(current_level_number).size()
	SaveManager.update_level_data(current_pack_name, current_pack_level_index, ScoreManager.correct_answers, ScoreManager.current_level_time, stars_earned)
	
	# Record progress to Playcademy TimeBack (1 minute = 1 XP)
	if PlaycademyManager:
		PlaycademyManager.record_level_progress(current_pack_name, current_pack_level_index, current_level_number, QuestionManager.current_track, stars_earned)
	
	# Update GameOver labels with player performance
	UIManager.update_game_over_labels(current_level_number)
	
	# Update star requirement labels to show actual level requirements
	UIManager.update_star_requirement_labels(current_level_number)
	
	# Set normal mode game over UI visibility
	UIManager.update_normal_mode_game_over_ui_visibility()
	
	# Initialize star states (make all stars invisible, continue button invisible)
	UIManager.initialize_star_states()
	
	# Clean up any remaining problem labels
	DisplayManager.cleanup_problem_labels()
	
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
	
	# Record drill mode progress to Playcademy TimeBack
	if PlaycademyManager:
		PlaycademyManager.record_drill_mode_progress()
	
	# Set drill mode game over UI visibility
	UIManager.update_drill_mode_game_over_ui_visibility()
	
	# Trigger high score celebration if new high score
	if is_new_high_score:
		UIManager.start_high_score_celebration()
	
	# Clean up any remaining problem labels
	DisplayManager.cleanup_problem_labels()
	
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
	is_drill_mode = false  # Reset drill mode flag
	
	# Update menu display with new save data
	LevelManager.update_menu_stars()
	LevelManager.update_level_availability()
	UIManager.update_drill_mode_high_score_display()
	
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
	"""Handle level button press - only respond during MENU state"""
	if current_state != GameConfig.GameState.MENU:
		return
	
	start_play_state(pack_name, pack_level_index)

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
	"""Handle unlock all button press - unlock all levels with 3 stars (DEV ONLY)"""
	if current_state != GameConfig.GameState.MENU:
		return
	
	SaveManager.unlock_all_levels()
	
	# Update menu display with unlocked levels
	LevelManager.update_menu_stars()
	LevelManager.update_level_availability()
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

