extends Node

# UI manager - handles all UI updates, animations, labels, and visual feedback

# Node references
var play_node: Control
var game_over_node: Control
var main_menu_node: Control
var timer_label: Label
var accuracy_label: Label
var progress_line: Line2D
var timer_line: Line2D  # New timer line for countdown visualization
var accuracy_line: Line2D  # New accuracy line for accuracy visualization
var drill_timer_label: Label
var drill_score_label: Label
var player_correct_label: Label  # Renamed from player_time_label - shows correct/total
var player_accuracy_label: Label  # Now shows percentage
var cqpm_label: Label
var drill_mode_score_label: Label
var xp_earned_label: Label
var xp_earned_title: Label
var continue_button: Button
var feedback_color_rect: ColorRect
var title_sprite: Sprite2D
var high_score_text_label: Label

# Star node references
var star1_node: Control
var star2_node: Control
var star3_node: Control
var star1_sprite: Sprite2D
var star2_sprite: Sprite2D
var star3_sprite: Sprite2D
var star1_correct_label: Label  # Renamed from accuracy - shows correct count required
var star1_accuracy_label: Label  # Renamed from time - shows accuracy percentage required
var star2_correct_label: Label
var star2_accuracy_label: Label
var star3_correct_label: Label
var star3_accuracy_label: Label

# Volume sliders
var sfx_slider: HSlider
var music_slider: HSlider

# Animation state
var title_base_position: Vector2
var title_animation_time = 0.0
var drill_score_base_position: Vector2
var drill_score_animation_time = 0.0
var is_celebrating_high_score = false
var high_score_flicker_time = 0.0

func initialize(main_node: Control):
	"""Initialize UI manager with references to all UI nodes"""
	play_node = main_node.get_node("Play")
	game_over_node = main_node.get_node("GameOver")
	main_menu_node = main_node.get_node("MainMenu")
	feedback_color_rect = main_node.get_node("FeedbackColor")
	title_sprite = main_menu_node.get_node("Title")
	
	# Get references to play UI elements
	timer_label = play_node.get_node("Timer")
	accuracy_label = play_node.get_node("Accuracy")
	progress_line = play_node.get_node("ProgressLine")
	timer_line = play_node.get_node("TimerLine")
	accuracy_line = play_node.get_node("AccuracyLine")
	drill_timer_label = play_node.get_node("DrillTimer")
	drill_score_label = play_node.get_node("DrillScore")
	
	# Get references to game over labels (using new node names)
	player_correct_label = game_over_node.get_node("PlayerCorrect")
	player_accuracy_label = game_over_node.get_node("PlayerAccuracy")
	continue_button = game_over_node.get_node("ContinueButton")
	cqpm_label = game_over_node.get_node("CQPM")
	drill_mode_score_label = game_over_node.get_node("DrillModeScore")
	xp_earned_label = game_over_node.get_node("XPEarned")
	xp_earned_title = game_over_node.get_node("XPEarnedTitle")
	high_score_text_label = game_over_node.get_node("HighScoreText")
	
	# Get references to star nodes
	star1_node = game_over_node.get_node("Star1")
	star2_node = game_over_node.get_node("Star2")
	star3_node = game_over_node.get_node("Star3")
	
	star1_sprite = star1_node.get_node("Sprite")
	star2_sprite = star2_node.get_node("Sprite")
	star3_sprite = star3_node.get_node("Sprite")
	
	# Star requirement labels (Correct = number required, Accuracy = percentage required)
	star1_correct_label = star1_node.get_node("Correct")
	star1_accuracy_label = star1_node.get_node("Accuracy")
	star2_correct_label = star2_node.get_node("Correct")
	star2_accuracy_label = star2_node.get_node("Accuracy")
	star3_correct_label = star3_node.get_node("Correct")
	star3_accuracy_label = star3_node.get_node("Accuracy")
	
	# Get references to volume sliders
	sfx_slider = main_menu_node.get_node("VolumeControls/SFXIcon/SFXSlider")
	music_slider = main_menu_node.get_node("VolumeControls/MusicIcon/MusicSlider")
	
	# Store the original position of the title for animation
	if title_sprite:
		title_base_position = title_sprite.position
	
	# Store the original position of the drill score label for animation
	if drill_mode_score_label:
		drill_score_base_position = drill_mode_score_label.position
	
	# Initially hide the high score text
	if high_score_text_label:
		high_score_text_label.visible = false
	
	# Set version label
	var version_label = main_menu_node.get_node("VersionLabel")
	if version_label:
		version_label.text = ProjectSettings.get_setting("application/config/version")
	
	# Connect volume sliders
	connect_volume_sliders()

func process_animations(delta: float, current_state: int, is_drill_mode: bool):
	"""Process all ongoing UI animations"""
	# Animate title during MENU state
	if current_state == GameConfig.GameState.MENU and title_sprite:
		title_animation_time += delta * GameConfig.title_bounce_speed
		var bounce_offset = sin(title_animation_time) * GameConfig.title_bounce_distance
		title_sprite.position = title_base_position + Vector2(0, bounce_offset)
	
	# Animate drill mode score during GAME_OVER state (only if drill mode)
	if current_state == GameConfig.GameState.GAME_OVER and is_drill_mode and drill_mode_score_label and drill_mode_score_label.visible:
		drill_score_animation_time += delta * GameConfig.drill_score_bounce_speed
		var drill_bounce_offset = sin(drill_score_animation_time) * GameConfig.drill_score_bounce_distance
		drill_mode_score_label.position = drill_score_base_position + Vector2(0, drill_bounce_offset)
	
	# Animate high score text color gradient during celebration
	if is_celebrating_high_score and high_score_text_label and high_score_text_label.visible:
		high_score_flicker_time += delta * GameConfig.high_score_flicker_speed
		var flicker_value = sin(high_score_flicker_time)
		# Convert sin wave (-1 to 1) to interpolation value (0 to 1)
		var lerp_value = (flicker_value + 1.0) / 2.0
		# Smooth gradient between blue (0, 0, 1) and turquoise (0, 1, 1)
		var blue_color = Color(0, 0, 1, 1)
		var turquoise_color = Color(0, 1, 1, 1)
		high_score_text_label.self_modulate = blue_color.lerp(turquoise_color, lerp_value)

func update_play_ui(delta: float, is_drill_mode: bool, _current_level_number: int):
	"""Update the Timer and Accuracy labels during gameplay"""
	if is_drill_mode:
		# Update drill mode UI
		if drill_timer_label:
			var display_time = ScoreManager.drill_timer_remaining
			if not ScoreManager.timer_started:
				display_time = GameConfig.drill_mode_duration  # Show full time during grace period
			
			var minutes = int(display_time / 60)
			var seconds = int(display_time) % 60
			var hundredths = int((display_time - int(display_time)) * 100)
			
			var time_string = "%d:%02d.%02d" % [minutes, seconds, hundredths]
			drill_timer_label.text = time_string
		
		if drill_score_label:
			# Smoothly animate score towards target
			if ScoreManager.drill_score_display_value < ScoreManager.drill_score_target_value:
				var animation_speed = (ScoreManager.drill_score_target_value - ScoreManager.drill_score_display_value) * delta * 8.0
				ScoreManager.drill_score_display_value = min(ScoreManager.drill_score_display_value + animation_speed, ScoreManager.drill_score_target_value)
			drill_score_label.text = str(int(ScoreManager.drill_score_display_value))
	else:
		# Update normal mode UI with countdown timer
		if not timer_label or not accuracy_label:
			return
		
		# Update timer display (mm:ss.ss format) - countdown timer
		var display_time = ScoreManager.level_timer_remaining
		if not ScoreManager.timer_started:
			display_time = GameConfig.level_timer_duration  # Show full time during initial grace period
		
		var minutes = int(display_time / 60)
		var seconds = int(display_time) % 60
		var hundredths = int((display_time - int(display_time)) * 100)
		
		var time_string = "%d:%02d.%02d" % [minutes, seconds, hundredths]
		timer_label.text = time_string
		
		# Update accuracy display (correct/total format)
		var accuracy_string = "%d/%d" % [ScoreManager.correct_answers, ScoreManager.total_answers]
		accuracy_label.text = accuracy_string
		
		# Update timer line (fills from left, decreases as time runs out)
		if timer_line and play_node:
			var play_width = play_node.size.x
			var timer_progress = ScoreManager.level_timer_remaining / GameConfig.level_timer_duration
			var timer_x = play_width * timer_progress
			if timer_line.get_point_count() >= 2:
				timer_line.set_point_position(1, Vector2(timer_x, 0))
		
		# Update accuracy line with color based on current accuracy
		update_accuracy_line()

func update_accuracy_line():
	"""Update the accuracy line position and color based on current accuracy"""
	if not accuracy_line or not play_node:
		return
	
	var accuracy = ScoreManager.get_current_accuracy()
	var play_width = play_node.size.x
	
	# Update line position
	var accuracy_x = play_width * accuracy
	if accuracy_line.get_point_count() >= 2:
		# Animate the accuracy line with ease out
		var current_x = accuracy_line.get_point_position(1).x
		if abs(current_x - accuracy_x) > 1.0:  # Only animate if there's significant change
			var tween = create_tween()
			tween.set_ease(Tween.EASE_OUT)
			tween.set_trans(Tween.TRANS_EXPO)
			tween.tween_method(update_accuracy_line_point, current_x, accuracy_x, GameConfig.animation_duration)
		else:
			accuracy_line.set_point_position(1, Vector2(accuracy_x, 0))
	
	# Update line color based on star thresholds
	if accuracy >= GameConfig.star3_accuracy_threshold:
		accuracy_line.default_color = GameConfig.accuracy_color_3star
	elif accuracy >= GameConfig.star2_accuracy_threshold:
		accuracy_line.default_color = GameConfig.accuracy_color_2star
	elif accuracy >= GameConfig.star1_accuracy_threshold:
		accuracy_line.default_color = GameConfig.accuracy_color_1star
	else:
		accuracy_line.default_color = GameConfig.accuracy_color_0star

func update_accuracy_line_point(x_position: float):
	"""Update the x position of point 1 in the accuracy line"""
	if accuracy_line and accuracy_line.get_point_count() >= 2:
		accuracy_line.set_point_position(1, Vector2(x_position, 0))

func update_game_over_labels_for_mastery(_mastery_count: int):
	"""Update the GameOver labels with player's final performance using the new scoring system"""
	if not player_correct_label or not player_accuracy_label:
		return
	
	# Update player correct display (correct/total format)
	var correct_string = "%d/%d" % [ScoreManager.correct_answers, ScoreManager.total_answers]
	player_correct_label.text = correct_string
	
	# Update player accuracy display (percentage, rounded down)
	var accuracy_percent = ScoreManager.get_current_accuracy_percent()
	player_accuracy_label.text = "%d%%" % accuracy_percent
	
	# Update CQPM display
	if cqpm_label:
		var cqpm = ScoreManager.calculate_cqpm(ScoreManager.correct_answers, ScoreManager.current_level_time)
		cqpm_label.text = "%.2f" % cqpm

func update_star_requirement_labels_for_mastery(mastery_count: int):
	"""Update the star requirement labels to show requirements based on mastery_count"""
	var requirements = ScoreManager.get_star_requirements(mastery_count)
	
	# Update Star 1 requirements
	if star1_correct_label:
		star1_correct_label.text = str(requirements.star1.correct)
	if star1_accuracy_label:
		star1_accuracy_label.text = "%d%%" % int(requirements.star1.accuracy * 100)
	
	# Update Star 2 requirements
	if star2_correct_label:
		star2_correct_label.text = str(requirements.star2.correct)
	if star2_accuracy_label:
		star2_accuracy_label.text = "%d%%" % int(requirements.star2.accuracy * 100)
	
	# Update Star 3 requirements
	if star3_correct_label:
		star3_correct_label.text = str(requirements.star3.correct)
	if star3_accuracy_label:
		star3_accuracy_label.text = "%d%%" % int(requirements.star3.accuracy * 100)

# ============================================
# Legacy Functions (for backwards compatibility with pack-based levels)
# ============================================

func update_game_over_labels(_current_level_number: int):
	"""Legacy function - redirects to mastery-based labels with default mastery count"""
	update_game_over_labels_for_mastery(20)  # Default fallback

func update_star_requirement_labels(_current_level_number: int):
	"""Legacy function - redirects to mastery-based labels with default mastery count"""
	update_star_requirement_labels_for_mastery(20)  # Default fallback

func start_star_animation_sequence(_current_level_number: int):
	"""Legacy function - redirects to mastery-based star animation"""
	start_star_animation_sequence_for_mastery(20)  # Default fallback

func initialize_star_states():
	"""Initialize all stars to invisible state and hide continue button"""
	# Make all star nodes invisible
	star1_node.visible = false
	star2_node.visible = false
	star3_node.visible = false
	
	# Hide continue button
	continue_button.visible = false
	
	# Reset all star sprite scales and frames
	star1_sprite.scale = Vector2.ZERO
	star2_sprite.scale = Vector2.ZERO
	star3_sprite.scale = Vector2.ZERO
	
	# Set all star labels to transparent
	star1_correct_label.self_modulate.a = 0.0
	star1_accuracy_label.self_modulate.a = 0.0
	star2_correct_label.self_modulate.a = 0.0
	star2_accuracy_label.self_modulate.a = 0.0
	star3_correct_label.self_modulate.a = 0.0
	star3_accuracy_label.self_modulate.a = 0.0

func start_star_animation_sequence_for_mastery(mastery_count: int):
	"""Start the sequential star animation using mastery-based star evaluation"""
	await get_tree().create_timer(GameConfig.animation_duration / 2.0).timeout
	
	# Evaluate which stars were earned using the new system
	var stars_earned = ScoreManager.evaluate_stars_for_mastery_count(mastery_count)
	var requirements = ScoreManager.get_star_requirements(mastery_count)
	
	# Animate stars in sequence
	animate_star_for_mastery(1, 1 in stars_earned, requirements)
	await get_tree().create_timer(GameConfig.star_delay).timeout
	
	animate_star_for_mastery(2, 2 in stars_earned, requirements)
	await get_tree().create_timer(GameConfig.star_delay).timeout
	
	animate_star_for_mastery(3, 3 in stars_earned, requirements)
	# Show continue button when Star 3 starts animating
	continue_button.visible = true

func animate_star_for_mastery(star_num: int, earned: bool, requirements: Dictionary):
	"""Animate a single star using mastery-based requirements"""
	var star_node_ref: Control
	var star_sprite_ref: Sprite2D
	var star_correct_label_ref: Label
	var star_accuracy_label_ref: Label
	
	# Get references for the specific star
	match star_num:
		1:
			star_node_ref = star1_node
			star_sprite_ref = star1_sprite
			star_correct_label_ref = star1_correct_label
			star_accuracy_label_ref = star1_accuracy_label
		2:
			star_node_ref = star2_node
			star_sprite_ref = star2_sprite
			star_correct_label_ref = star2_correct_label
			star_accuracy_label_ref = star2_accuracy_label
		3:
			star_node_ref = star3_node
			star_sprite_ref = star3_sprite
			star_correct_label_ref = star3_correct_label
			star_accuracy_label_ref = star3_accuracy_label
		_:
			return
	
	# Make star visible
	star_node_ref.visible = true
	
	# Set sprite frame based on earned status
	star_sprite_ref.frame = 1 if earned else 0
	
	# Create sprite animation tween
	var sprite_tween = star_sprite_ref.create_tween()
	sprite_tween.set_ease(Tween.EASE_OUT)
	sprite_tween.set_trans(Tween.TRANS_EXPO)
	
	if earned:
		# Earned star animation: 0 -> 16 -> 8
		sprite_tween.tween_property(star_sprite_ref, "scale", Vector2(GameConfig.star_max_scale, GameConfig.star_max_scale), GameConfig.star_expand_time)
		sprite_tween.tween_property(star_sprite_ref, "scale", Vector2(GameConfig.star_final_scale, GameConfig.star_final_scale), GameConfig.star_shrink_time)
		# Play get sound
		AudioManager.play_get()
	else:
		# Unearned star animation: 0 -> 8
		sprite_tween.tween_property(star_sprite_ref, "scale", Vector2(GameConfig.star_final_scale, GameConfig.star_final_scale), GameConfig.star_shrink_time)
		# Play close sound
		AudioManager.play_close()
	
	# Animate labels (correct count and accuracy percentage)
	animate_star_labels_for_mastery(star_num, star_correct_label_ref, star_accuracy_label_ref, requirements)

func animate_star_labels_for_mastery(star_num: int, correct_label: Label, accuracy_label_ref: Label, requirements: Dictionary):
	"""Animate the correct count and accuracy labels for a star using mastery-based requirements"""
	# Get requirements for this star
	var star_req
	match star_num:
		1: star_req = requirements.star1
		2: star_req = requirements.star2
		3: star_req = requirements.star3
		_: return
	
	# Check if individual requirements were met
	var correct_met = ScoreManager.correct_answers >= star_req.correct
	var accuracy_met = ScoreManager.get_current_accuracy() >= star_req.accuracy
	
	# Set colors based on whether requirements were met
	if correct_met:
		correct_label.self_modulate = Color(0, 0.5, 0, 0)  # Half green, start transparent
	else:
		correct_label.self_modulate = Color(0.5, 0, 0, 0)  # Half red, start transparent
	
	if accuracy_met:
		accuracy_label_ref.self_modulate = Color(0, 0.5, 0, 0)  # Half green, start transparent
	else:
		accuracy_label_ref.self_modulate = Color(0.5, 0, 0, 0)  # Half red, start transparent
	
	# Create fade-in animations
	var correct_tween = correct_label.create_tween()
	correct_tween.set_ease(Tween.EASE_OUT)
	correct_tween.set_trans(Tween.TRANS_EXPO)
	correct_tween.tween_property(correct_label, "self_modulate:a", 1.0, GameConfig.label_fade_time)
	
	var accuracy_tween = accuracy_label_ref.create_tween()
	accuracy_tween.set_ease(Tween.EASE_OUT)
	accuracy_tween.set_trans(Tween.TRANS_EXPO)
	accuracy_tween.tween_property(accuracy_label_ref, "self_modulate:a", 1.0, GameConfig.label_fade_time)

func show_feedback_flash(flash_color: Color):
	"""Show a colored flash overlay that fades in then out with smooth timing"""
	if not feedback_color_rect:
		return
	
	# Start with the color at 0 alpha (invisible)
	feedback_color_rect.modulate = Color(flash_color.r, flash_color.g, flash_color.b, 0.0)
	
	# Create tween for the two-phase animation
	var tween = feedback_color_rect.create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_EXPO)
	
	# Phase 1: Fade in from 0 to feedback_max_alpha over transition_delay
	tween.tween_property(feedback_color_rect, "modulate:a", GameConfig.feedback_max_alpha, GameConfig.transition_delay)
	
	# Phase 2: Fade out from feedback_max_alpha to 0 over animation_duration * 2
	tween.tween_property(feedback_color_rect, "modulate:a", 0.0, GameConfig.animation_duration * 2.0)

func update_progress_line_point(x_position: float):
	"""Update the x position of point 1 in the progress line"""
	if progress_line and progress_line.get_point_count() >= 2:
		progress_line.set_point_position(1, Vector2(x_position, 0))

func initialize_progress_line():
	"""Initialize the progress line for a new level"""
	if progress_line:
		progress_line.clear_points()
		progress_line.add_point(Vector2(0, 0))  # Point 0 at (0, 0)
		progress_line.add_point(Vector2(0, 0))  # Point 1 starts at (0, 0)

func initialize_timer_line():
	"""Initialize the timer line for a new level (starts full)"""
	if timer_line and play_node:
		timer_line.clear_points()
		timer_line.add_point(Vector2(0, 0))  # Point 0 at (0, 0)
		timer_line.add_point(Vector2(play_node.size.x, 0))  # Point 1 starts at full width

func initialize_accuracy_line():
	"""Initialize the accuracy line for a new level (starts empty, fills on first correct answer)"""
	if accuracy_line and play_node:
		accuracy_line.clear_points()
		accuracy_line.add_point(Vector2(0, 0))  # Point 0 at (0, 0)
		accuracy_line.add_point(Vector2(0, 0))  # Point 1 starts at 0 (empty)
		accuracy_line.default_color = GameConfig.accuracy_color_3star  # Start green

func update_drill_mode_ui_visibility():
	"""Set UI visibility for drill mode"""
	if timer_label:
		timer_label.visible = false
	if accuracy_label:
		accuracy_label.visible = false
	if progress_line:
		progress_line.visible = false
	if timer_line:
		timer_line.visible = false
	if accuracy_line:
		accuracy_line.visible = false
	if drill_timer_label:
		drill_timer_label.visible = true
	if drill_score_label:
		drill_score_label.visible = true

func update_normal_mode_ui_visibility():
	"""Set UI visibility for normal mode"""
	if timer_label:
		timer_label.visible = true
	if accuracy_label:
		accuracy_label.visible = true
	if progress_line:
		progress_line.visible = true
	if timer_line:
		timer_line.visible = true
	if accuracy_line:
		accuracy_line.visible = true
	if drill_timer_label:
		drill_timer_label.visible = false
	if drill_score_label:
		drill_score_label.visible = false

func hide_play_ui_for_level_complete():
	"""Hide all play UI elements when level is completed"""
	if timer_label:
		timer_label.visible = false
	if accuracy_label:
		accuracy_label.visible = false
	if progress_line:
		progress_line.visible = false
	if timer_line:
		timer_line.visible = false
	if accuracy_line:
		accuracy_line.visible = false

func update_xp_earned_label(xp_amount: float):
	"""Update the XP earned label with the amount of XP earned"""
	if xp_earned_label:
		xp_earned_label.text = "%.2f" % xp_amount

func update_drill_mode_game_over_labels():
	"""Update GameOver labels for drill mode"""
	# Update LevelComplete text
	var level_complete_label = game_over_node.get_node("LevelComplete")
	if level_complete_label:
		level_complete_label.text = "YOUR SCORE"
	
	# Update drill mode score display
	if drill_mode_score_label:
		drill_mode_score_label.text = str(int(ScoreManager.drill_score))
	
	# Update CQPM display for drill mode
	if cqpm_label:
		# Calculate drill mode CQPM: correct answers divided by total drill time
		# Subtract time spent on the last unanswered question (if any)
		var drill_time_used = GameConfig.drill_mode_duration
		if ScoreManager.current_question_start_time > 0:
			# Subtract time spent on current unanswered question
			var time_on_current_question = (Time.get_ticks_msec() / 1000.0) - ScoreManager.current_question_start_time
			drill_time_used -= time_on_current_question
		
		var cqpm = ScoreManager.calculate_cqpm(ScoreManager.correct_answers, drill_time_used)
		cqpm_label.text = "%.2f" % cqpm

func update_drill_mode_game_over_ui_visibility():
	"""Set UI visibility for drill mode game over screen"""
	# Make only specific nodes visible for drill mode
	var level_complete_label = game_over_node.get_node("LevelComplete")
	if level_complete_label:
		level_complete_label.visible = true
	
	if continue_button:
		continue_button.visible = true
	
	var cqpm_title = game_over_node.get_node("CQPMTitle")
	if cqpm_title:
		cqpm_title.visible = true
	
	if cqpm_label:
		cqpm_label.visible = true
	
	var cqpm_tooltip = game_over_node.get_node("CQPMTooltip")
	if cqpm_tooltip:
		cqpm_tooltip.visible = true
	
	if drill_mode_score_label:
		drill_mode_score_label.visible = true
	
	# Hide XP earned labels in drill mode
	if xp_earned_title:
		xp_earned_title.visible = false
	if xp_earned_label:
		xp_earned_label.visible = false
	
	# HighScoreText visibility is handled by the celebration system, not here
	
	# Hide all other nodes
	var nodes_to_hide = ["CorrectTitle", "AccuracyTitle", "You", "PlayerCorrect", "PlayerAccuracy", "Star1", "Star2", "Star3"]
	for node_name in nodes_to_hide:
		var node = game_over_node.get_node(node_name)
		if node:
			node.visible = false

func update_normal_mode_game_over_ui_visibility():
	"""Set UI visibility for normal mode game over screen"""
	# Make all nodes visible except DrillModeScore
	var level_complete_label = game_over_node.get_node("LevelComplete")
	if level_complete_label:
		level_complete_label.text = "LEVEL COMPLETE"  # Reset to normal text
		level_complete_label.visible = true
	
	var nodes_to_show = ["CorrectTitle", "AccuracyTitle", "You", "PlayerCorrect", "PlayerAccuracy", "Star1", "Star2", "Star3", "CQPMTitle", "CQPMTooltip"]
	for node_name in nodes_to_show:
		var node = game_over_node.get_node(node_name)
		if node:
			node.visible = true
	
	if cqpm_label:
		cqpm_label.visible = true
	
	# Show XP earned elements
	if xp_earned_title:
		xp_earned_title.visible = true
	if xp_earned_label:
		xp_earned_label.visible = true
	
	# Hide drill mode elements
	if drill_mode_score_label:
		drill_mode_score_label.visible = false
	
	# Always hide high score text in normal mode
	if high_score_text_label:
		high_score_text_label.visible = false

func start_high_score_celebration():
	"""Start the high score celebration animation"""
	if not high_score_text_label:
		return
	
	# Wait for animation_duration before showing the celebration
	await get_tree().create_timer(GameConfig.animation_duration).timeout
	
	# Make the label visible and start celebration
	high_score_text_label.visible = true
	is_celebrating_high_score = true
	high_score_flicker_time = 0.0
	
	# Set pivot to center for scaling animation
	high_score_text_label.pivot_offset = high_score_text_label.size / 2.0
	
	# Play the Get sound effect
	AudioManager.play_get()
	
	# Create the pop animation
	var pop_tween = high_score_text_label.create_tween()
	pop_tween.set_ease(Tween.EASE_OUT)
	pop_tween.set_trans(Tween.TRANS_EXPO)
	
	# Phase 1: Expand to large scale
	pop_tween.tween_property(high_score_text_label, "scale", Vector2(GameConfig.high_score_pop_scale, GameConfig.high_score_pop_scale), GameConfig.high_score_expand_duration)
	
	# Phase 2: Shrink back to normal
	pop_tween.tween_property(high_score_text_label, "scale", Vector2(1.0, 1.0), GameConfig.high_score_shrink_duration)

func update_drill_mode_high_score_display():
	"""Update the drill mode high score display in the main menu"""
	var high_score_label = main_menu_node.get_node("DrillModeButton/HighScore")
	if high_score_label:
		var high_score = SaveManager.get_drill_mode_high_score()
		high_score_label.text = str(int(high_score))  # Ensure integer display

func show_continue_button():
	"""Show the continue button"""
	if continue_button:
		continue_button.visible = true


func create_flying_score_label(points_earned: int):
	"""Create a flying score label that moves down and fades out simultaneously"""
	if not drill_score_label or not play_node:
		return
	
	# Create new flying score label
	var flying_label = Label.new()
	var label_settings_gb64 = load("res://assets/label settings/GravityBold64.tres")
	flying_label.label_settings = label_settings_gb64
	flying_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	flying_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	flying_label.text = "+" + str(points_earned)
	flying_label.self_modulate = Color(1, 0, 1, 1)  # Fuchsia color
	flying_label.position = drill_score_label.position  # Start at drill score position (top-left aligned)
	
	# Add to play node
	play_node.add_child(flying_label)
	
	# Create parallel animations
	var move_tween = flying_label.create_tween()
	var fade_tween = flying_label.create_tween()
	
	move_tween.set_ease(Tween.EASE_OUT)
	move_tween.set_trans(Tween.TRANS_EXPO)
	fade_tween.set_ease(Tween.EASE_OUT)
	fade_tween.set_trans(Tween.TRANS_EXPO)
	
	# Move down and fade out simultaneously over the same duration
	var target_position = flying_label.position + Vector2(0, GameConfig.flying_score_move_distance)
	move_tween.tween_property(flying_label, "position", target_position, GameConfig.flying_score_move_duration)
	fade_tween.tween_property(flying_label, "self_modulate:a", 0.0, GameConfig.flying_score_move_duration)
	
	# Clean up after animation completes
	fade_tween.tween_callback(flying_label.queue_free)

func animate_drill_score_scale():
	"""Animate the drill score label scaling up and back down"""
	if not drill_score_label:
		return
	
	# Create scale animation tween
	var scale_tween = drill_score_label.create_tween()
	scale_tween.set_ease(Tween.EASE_OUT)
	scale_tween.set_trans(Tween.TRANS_EXPO)
	
	# Phase 1: Expand to larger scale
	scale_tween.tween_property(drill_score_label, "scale", Vector2(GameConfig.drill_score_expand_scale, GameConfig.drill_score_expand_scale), GameConfig.drill_score_expand_duration)
	
	# Phase 2: Shrink back to normal
	scale_tween.tween_property(drill_score_label, "scale", Vector2(1.0, 1.0), GameConfig.drill_score_shrink_duration)

func connect_button_sounds(button: Button):
	"""Connect hover and click sound effects to a button"""
	if button:
		# Connect hover sound (mouse_entered signal)
		button.mouse_entered.connect(_on_button_hover)
		# Connect click sound - this will be called before the button's pressed signal
		button.button_down.connect(_on_button_click)

func _on_button_hover():
	"""Play hover sound when mouse enters any button"""
	AudioManager.play_blip()

func _on_button_click():
	"""Play click sound when any button is pressed down"""
	AudioManager.play_select()

func connect_volume_sliders():
	"""Connect volume sliders and initialize their values from local settings"""
	if sfx_slider:
		# Set slider range (0.0 to 1.0)
		sfx_slider.min_value = 0.0
		sfx_slider.max_value = 1.0
		sfx_slider.step = 0.01
		
		# Load saved volume from local settings
		var sfx_volume = SaveManager.local_settings.get("sfx_volume", GameConfig.default_sfx_volume)
		sfx_slider.value = sfx_volume
		
		# Apply the volume immediately
		SaveManager.set_sfx_volume(sfx_volume)
		
		# Connect signal
		sfx_slider.value_changed.connect(_on_sfx_volume_changed)
	
	if music_slider:
		# Set slider range (0.0 to 1.0)
		music_slider.min_value = 0.0
		music_slider.max_value = 1.0
		music_slider.step = 0.01
		
		# Load saved volume from local settings
		var music_volume = SaveManager.local_settings.get("music_volume", GameConfig.default_music_volume)
		music_slider.value = music_volume
		
		# Apply the volume immediately
		SaveManager.set_music_volume(music_volume)
		
		# Connect signal
		music_slider.value_changed.connect(_on_music_volume_changed)

func update_volume_sliders_from_local_settings():
	"""Update volume sliders to match values from loaded local settings"""
	if sfx_slider:
		var sfx_volume = SaveManager.local_settings.get("sfx_volume", GameConfig.default_sfx_volume)
		sfx_slider.value = sfx_volume
		print("[UIManager] Updated SFX slider to: ", sfx_volume)
	
	if music_slider:
		var music_volume = SaveManager.local_settings.get("music_volume", GameConfig.default_music_volume)
		music_slider.value = music_volume
		print("[UIManager] Updated Music slider to: ", music_volume)

func _on_sfx_volume_changed(value: float):
	"""Handle SFX volume slider change (saved locally, not to KV)"""
	SaveManager.set_sfx_volume(value)
	SaveManager.local_settings.sfx_volume = value
	SaveManager.save_local_settings()

func _on_music_volume_changed(value: float):
	"""Handle Music volume slider change (saved locally, not to KV)"""
	SaveManager.set_music_volume(value)
	SaveManager.local_settings.music_volume = value
	SaveManager.save_local_settings()

# ============================================
# Assessment Mode UI Functions
# ============================================

func update_assessment_mode_ui_visibility():
	"""Set UI visibility for assessment mode (minimal UI - no timer, no accuracy)"""
	if timer_label:
		timer_label.visible = false
	if accuracy_label:
		accuracy_label.visible = false
	if progress_line:
		progress_line.visible = false
	if timer_line:
		timer_line.visible = false
	if accuracy_line:
		accuracy_line.visible = false
	if drill_timer_label:
		drill_timer_label.visible = false
	if drill_score_label:
		drill_score_label.visible = false

func update_assessment_game_over_ui():
	"""Update GameOver UI for assessment mode completion"""
	# Update LevelComplete text (keep it as "LEVEL COMPLETE" per requirements)
	var level_complete_label = game_over_node.get_node("LevelComplete")
	if level_complete_label:
		level_complete_label.text = "LEVEL COMPLETE"
		level_complete_label.visible = true
	
	# Hide most game over elements for assessment mode (minimal display)
	var nodes_to_hide = ["CorrectTitle", "AccuracyTitle", "You", "PlayerCorrect", "PlayerAccuracy", 
						  "CQPMTitle", "CQPMTooltip", "DrillModeScore", "HighScoreText",
						  "XPEarnedTitle", "XPEarned"]
	for node_name in nodes_to_hide:
		var node = game_over_node.get_node_or_null(node_name)
		if node:
			node.visible = false
	
	if cqpm_label:
		cqpm_label.visible = false
	
	# Hide continue button initially (will be shown after star animation)
	if continue_button:
		continue_button.visible = false

func initialize_assessment_star_states():
	"""Initialize stars for assessment mode (all will be earned)"""
	# Make all star nodes visible but empty (will animate to earned)
	star1_node.visible = false
	star2_node.visible = false
	star3_node.visible = false
	
	# Reset all star sprite scales and frames
	star1_sprite.scale = Vector2.ZERO
	star2_sprite.scale = Vector2.ZERO
	star3_sprite.scale = Vector2.ZERO
	
	# Hide all labels for assessment mode (no requirements to show)
	star1_correct_label.visible = false
	star1_accuracy_label.visible = false
	star2_correct_label.visible = false
	star2_accuracy_label.visible = false
	star3_correct_label.visible = false
	star3_accuracy_label.visible = false

func start_assessment_star_animation_sequence():
	"""Start the star animation sequence for assessment mode (always 3 stars, sprite only)"""
	await get_tree().create_timer(GameConfig.animation_duration / 2.0).timeout
	
	# Animate all 3 stars in sequence (all earned, no labels)
	animate_assessment_star(1)
	await get_tree().create_timer(GameConfig.star_delay).timeout
	
	animate_assessment_star(2)
	await get_tree().create_timer(GameConfig.star_delay).timeout
	
	animate_assessment_star(3)
	# Show continue button when Star 3 starts animating
	continue_button.visible = true

func animate_assessment_star(star_num: int):
	"""Animate a single star for assessment mode (always earned, no labels)"""
	var star_node_ref: Control
	var star_sprite_ref: Sprite2D
	
	# Get references for the specific star
	match star_num:
		1:
			star_node_ref = star1_node
			star_sprite_ref = star1_sprite
		2:
			star_node_ref = star2_node
			star_sprite_ref = star2_sprite
		3:
			star_node_ref = star3_node
			star_sprite_ref = star3_sprite
		_:
			return
	
	# Make star visible
	star_node_ref.visible = true
	
	# Set sprite frame to earned
	star_sprite_ref.frame = 1
	
	# Create sprite animation tween (earned animation: 0 -> max_scale -> final_scale)
	var sprite_tween = star_sprite_ref.create_tween()
	sprite_tween.set_ease(Tween.EASE_OUT)
	sprite_tween.set_trans(Tween.TRANS_EXPO)
	
	sprite_tween.tween_property(star_sprite_ref, "scale", Vector2(GameConfig.star_max_scale, GameConfig.star_max_scale), GameConfig.star_expand_time)
	sprite_tween.tween_property(star_sprite_ref, "scale", Vector2(GameConfig.star_final_scale, GameConfig.star_final_scale), GameConfig.star_shrink_time)
	
	# Play get sound
	AudioManager.play_get()
