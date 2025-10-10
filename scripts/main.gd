extends Control

# Game state enum
enum GameState { MENU, PLAY, DRILL_PLAY, GAME_OVER }

# Math facts data and RNG
var math_facts = {}
var rng = RandomNumberGenerator.new()

# Game configuration variables
var blink_interval = 0.5  # Time for underscore blink cycle (fade in/out)
var max_answer_chars = 4  # Maximum characters for answer input
var animation_duration = 0.5  # Duration for label animations in seconds
var transition_delay = 0.1  # Delay before generating new question
var transition_delay_incorrect = 1.5  # Delay for incorrect answers (1.5 seconds)
var incorrect_label_animation_time = 0.25  # Time for incorrect label animation
var incorrect_label_move_distance = 192.0  # Distance to move incorrect label down
var incorrect_label_move_distance_fractions = 256.0  # Distance to move incorrect label down for fractions
var backspace_hold_time = 0.15  # Time to hold backspace before it repeats
var scroll_boost_multiplier = 80.0  # How much to boost background scroll speed on submission
var feedback_max_alpha = 0.1  # Maximum alpha for feedback color overlay
var timer_grace_period = 0.5  # Grace period before timer starts in seconds
var drill_mode_duration = 60.0  # Duration for drill mode in seconds (1 minute)

# Fraction problem layout variables
var fraction_element_spacing = 112.0  # Spacing between fractions and operators
var fraction_answer_offset = 88.0  # Horizontal offset for answer positioning (fraction mode)
var fraction_answer_number_offset = -40.0  # Additional leftward offset for non-fractionalized answers
var fraction_mixed_answer_extra_offset = 4.0  # Additional rightward offset for mixed fraction answers to prevent overlap
var fraction_offset = Vector2(48, 64.0)  # Position offset for fraction elements (x, y)
var operator_offset = Vector2(0, 0.0)  # Position offset for operators and equals sign (x, y)
var unicode_operator_offset = Vector2(10, -30)  # Additional offset for unicode operators (× and ÷) to center them properly
var simple_operator_offset = Vector2(-12, 0)  # Additional offset for simple character operators (x and /) when converted from unicode
var fraction_problem_x_offset = -64.0  # Horizontal offset from primary_position for the entire fraction problem

# Star animation variables
var star_delay = 0.4  # Delay between each star animation in seconds
var star_expand_time = 0.2  # Time for star to expand to max scale
var star_shrink_time = 0.5  # Time for star to shrink to final scale
var star_max_scale = 32.0  # Maximum scale during star animation
var star_final_scale = 8.0  # Final scale for earned stars
var label_fade_time = 0.5  # Time for star labels to fade in

# Per-level configuration (level number -> config dict)
var level_configs = {
	1: {"problems": 40, "star1": {"accuracy": 25, "time": 120.0}, "star2": {"accuracy": 30, "time": 100.0}, "star3": {"accuracy": 35, "time": 80.0}},
	2: {"problems": 40, "star1": {"accuracy": 25, "time": 120.0}, "star2": {"accuracy": 30, "time": 100.0}, "star3": {"accuracy": 35, "time": 80.0}},
	3: {"problems": 40, "star1": {"accuracy": 25, "time": 120.0}, "star2": {"accuracy": 30, "time": 100.0}, "star3": {"accuracy": 35, "time": 80.0}},
	4: {"problems": 40, "star1": {"accuracy": 25, "time": 120.0}, "star2": {"accuracy": 30, "time": 100.0}, "star3": {"accuracy": 35, "time": 80.0}},
	5: {"problems": 40, "star1": {"accuracy": 25, "time": 120.0}, "star2": {"accuracy": 30, "time": 100.0}, "star3": {"accuracy": 35, "time": 80.0}},
	6: {"problems": 40, "star1": {"accuracy": 25, "time": 120.0}, "star2": {"accuracy": 30, "time": 100.0}, "star3": {"accuracy": 35, "time": 80.0}},
	7: {"problems": 40, "star1": {"accuracy": 25, "time": 120.0}, "star2": {"accuracy": 30, "time": 100.0}, "star3": {"accuracy": 35, "time": 80.0}},
	8: {"problems": 40, "star1": {"accuracy": 25, "time": 120.0}, "star2": {"accuracy": 30, "time": 100.0}, "star3": {"accuracy": 35, "time": 80.0}},
	9: {"problems": 20, "star1": {"accuracy": 12, "time": 120.0}, "star2": {"accuracy": 14, "time": 100.0}, "star3": {"accuracy": 16, "time": 80.0}},
	10: {"problems": 20, "star1": {"accuracy": 12, "time": 180.0}, "star2": {"accuracy": 14, "time": 150.0}, "star3": {"accuracy": 16, "time": 120.0}},
	11: {"problems": 20, "star1": {"accuracy": 12, "time": 210.0}, "star2": {"accuracy": 14, "time": 180.0}, "star3": {"accuracy": 16, "time": 150.0}}
}

# Title animation variables
var title_bounce_speed = 2.0  # Speed of the sin wave animation
var title_bounce_distance = 16.0  # Distance of the bounce in pixels

# Drill mode score animation variables
var drill_score_bounce_speed = 3.0  # Speed of the sin wave animation for drill score
var drill_score_bounce_distance = 16.0  # Distance of the bounce in pixels for drill score

# Drill mode score enhancement variables
var flying_score_move_distance = 320.0  # Distance flying score labels move down in pixels
var flying_score_move_duration = 2.0  # Duration for flying score movement animation
var flying_score_fade_duration = 0.5  # Duration for flying score fade out animation
var drill_score_expand_scale = 2.0  # Scale factor for drill score expansion
var drill_score_expand_duration = 0.1  # Duration for drill score expansion
var drill_score_shrink_duration = 0.9  # Duration for drill score shrink back to normal

# Control guide variables
var control_guide_max_x = 1896.0  # Maximum x position for the right side of the rightmost control node
var control_guide_padding = 32.0  # Space between control nodes
var control_guide_animation_duration = 0  # Duration for control slide animations

# Audio settings
var default_sfx_volume = 0.85  # Default SFX volume (85%)
var default_music_volume = 0.5  # Default music volume (50%)
var sfx_slider: HSlider  # Reference to SFX volume slider
var music_slider: HSlider  # Reference to Music volume slider

# High score celebration variables
var high_score_pop_scale = 8.0  # Scale factor for high score text pop effect
var high_score_expand_duration = 0.1  # Duration for high score text expansion
var high_score_shrink_duration = 0.25  # Duration for high score text shrink back to normal
var high_score_flicker_speed = 12.0  # Speed of color flickering between blue and turquoise

# Menu position constants
const menu_above_screen = Vector2(0, -1144)
const menu_below_screen = Vector2(0, 1144)
const menu_on_screen = Vector2(0, 0)

# Fraction problem positioning constants
const fraction_problem_min_x = 32.0  # Minimum x position for fraction problems to prevent going off-screen

# Control guide ordering constants (left to right ordering: Enter > Tab > Divide)
enum ControlGuideType { DIVIDE, TAB, ENTER }
const CONTROL_GUIDE_ORDER = [ControlGuideType.ENTER, ControlGuideType.TAB, ControlGuideType.DIVIDE]

# Level pack configuration (ordered list of packs)
const level_pack_order = ["Addition", "Subtraction", "Multiplication", "Division", "Fractions"]

# Level pack definitions (pack name -> config dict)
const level_packs = {
	"Addition": {
		"levels": [12, 9, 6],
		"theme_color": Color(0, 0.5, 1)
	},
	"Subtraction": {
		"levels": [10, 8],
		"theme_color": Color(1, 0.25, 0.25)
	},
	"Multiplication": {
		"levels": [11, 7],
		"theme_color": Color(1, 0.75, 0.25)
	},
	"Division": {
		"levels": [5],
		"theme_color": Color(1, 0.5, 1)
	},
	"Fractions": {
		"levels": ["4.NF.B", "5.NF.A", "5.NF.B"],
		"theme_color": Color(0, 0.75, 0)
	}
}

# Problem type display format mapping
# Maps problem types to their display format ("fraction" or "standard")
const PROBLEM_DISPLAY_FORMATS = {
	"Like-denominator addition/subtraction": "fraction",
	"Mixed numbers (like denominators)": "fraction",
	"Multiply fraction by whole number": "fraction",
	"Add unlike denominators": "fraction",
	"Subtract unlike denominators": "fraction",
	"Multiply fraction by fraction": "fraction",
	"Division with unit fractions": "fraction"
}

# Level button creation configuration
var level_button_start_position = Vector2(-960, -32)  # Starting position for first button (top-left of screen)
var level_button_spacing = Vector2(208, 256)  # Horizontal and vertical spacing between buttons
var level_button_size = Vector2(192, 192)  # Size of each level button
var minimum_padding = 64  # Minimum padding on left and right edges of screen
var max_row_width = 1792  # Maximum width for a row (1920 - 2*minimum_padding)

# Level pack outline configuration
var pack_outline_offset = Vector2(-48, -48)  # Offset from top-left of first button in pack
var pack_outline_base_width = 160.0  # Base width for ShapeHorizontal (for 1 button)
var pack_outline_height = 32.0  # Height of ShapeHorizontal
var pack_outline_vertical_height = 128.0  # Height of ShapeVertical

# Position variables
var primary_position = Vector2(480, 476)  # Main problem position
var off_screen_top = Vector2(480, 1276)   # Off-screen top position
var off_screen_bottom = Vector2(480, -324) # Off-screen bottom position

# Game state variables
var current_state = GameState.MENU
var current_problem_label: Label
var current_question = null  # Store current question data
var current_track = 0  # Current track being played
var current_pack_name = ""  # Current level pack being played
var current_pack_level_index = 0  # Current level index within pack (0-based)
var problems_completed = 0  # Number of problems completed in current level
var user_answer = ""
var blink_timer = 0.0
var underscore_visible = true
var label_settings_resource: LabelSettings
var answer_submitted = false  # Track if current problem has been submitted
var backspace_timer = 0.0  # Timer for backspace hold functionality
var backspace_held = false  # Track if backspace is being held
var backspace_just_pressed = false  # Track if backspace was just pressed this frame

# Fraction input state variables
var is_fraction_input = false  # Whether the user's answer is currently in fraction format
var is_mixed_fraction_input = false  # Whether the user's answer is a mixed fraction
var editing_numerator = true  # For mixed fractions: whether we're editing numerator (true) or denominator (false)
var current_level_number = 0  # Current level number (1-9)
var current_problem_nodes = []  # Array of nodes (fractions, labels) for the current problem display
var answer_fraction_node = null  # Reference to the fraction node used for answer input
var answer_fraction_base_x = 0.0  # Base X position of answer fraction (before width adjustments)
var answer_fraction_initial_width = 0.0  # Initial divisor width of answer fraction
var correct_answer_nodes = []  # Array of nodes showing the correct answer for incorrect fraction problems
var feedback_color_rect: ColorRect  # Reference to the feedback color overlay
var main_menu_node: Control  # Reference to the MainMenu node
var game_over_node: Control  # Reference to the GameOver node
var play_node: Control  # Reference to the Play node
var title_sprite: Sprite2D  # Reference to the Title sprite
var title_base_position: Vector2  # Store the original position of the title
var title_animation_time = 0.0  # Track time for sin wave animation
var drill_score_base_position: Vector2  # Store the original position of the drill score label
var drill_score_animation_time = 0.0  # Track time for drill score sin wave animation
var high_score_text_label: Label  # Reference to the HighScoreText label
var is_celebrating_high_score = false  # Whether we're currently celebrating a new high score
var high_score_flicker_time = 0.0  # Track time for color flickering animation

# Dynamic level button references
var level_buttons = []  # Array to store dynamically created level buttons (each entry: {button: Button, pack_name: String, pack_level_index: int, global_number: int})
var level_pack_outlines = []  # Array to store dynamically created pack outline nodes
var label_settings_64: LabelSettings  # Label settings for button numbers
var star_icon_texture: Texture2D  # Texture for star icons

# Save system variables
var save_data = {}
var save_file_path = "user://save_data.json"
var current_question_start_time = 0.0  # Track when current question timing started
var cqpm_label: Label  # Reference to CQPM label in GameOver

# Weighted question system variables
var question_weights = {}  # Dictionary mapping question keys to their weights
var unavailable_questions = []  # List of question keys that can't be selected this level
var available_questions = []  # List of all questions available for current track

# Timer and accuracy tracking
var level_start_time = 0.0  # Time when the level started
var current_level_time = 0.0  # Current elapsed time for the level
var timer_active = false  # Whether the timer is currently running
var grace_period_timer = 0.0  # Timer for the grace period
var timer_started = false  # Whether the timer has started (past grace period)
var in_transition_delay = false  # Whether we're currently in a transition delay
var correct_answers = 0  # Number of correct answers in current level
var timer_label: Label  # Reference to the Timer label
var accuracy_label: Label  # Reference to the Accuracy label
var player_time_label: Label  # Reference to the PlayerTime label in GameOver
var player_accuracy_label: Label  # Reference to the PlayerAccuracy label in GameOver
var continue_button: Button  # Reference to the ContinueButton
var progress_line: Line2D  # Reference to the ProgressLine

# Star node references
var star1_node: Control
var star2_node: Control
var star3_node: Control
var star1_sprite: Sprite2D
var star2_sprite: Sprite2D
var star3_sprite: Sprite2D
var star1_accuracy_label: Label
var star1_time_label: Label
var star2_accuracy_label: Label
var star2_time_label: Label
var star3_accuracy_label: Label
var star3_time_label: Label

# Drill mode variables
var is_drill_mode = false  # Whether we're currently in drill mode
var drill_timer_remaining = 0.0  # Time remaining in drill mode
var drill_score = 0  # Current drill mode score
var drill_streak = 0  # Current correct answer streak in drill mode
var drill_total_answered = 0  # Total questions answered in drill mode (correct + incorrect)
var drill_score_display_value = 0.0  # Current displayed score value for smooth animation
var drill_score_target_value = 0  # Target score value for smooth animation
var drill_timer_label: Label  # Reference to the DrillTimer label
var drill_score_label: Label  # Reference to the DrillScore label
var drill_mode_score_label: Label  # Reference to the DrillModeScore label in GameOver
var drill_accuracy_label: Label  # Reference to the DrillAccuracy label in GameOver

# Control guide node references
var control_guide_enter: Control  # Reference to the Enter control node
var control_guide_tab: Control  # Reference to the Tab control node
var control_guide_divide: Control  # Reference to the Divide control node

func _ready():
	# Load and parse the math facts JSON
	var file = FileAccess.open("res://tools/all_problems.json", FileAccess.READ)
	if file:
		var json_string = file.get_as_text()
		file.close()
		
		var json = JSON.new()
		var parse_result = json.parse(json_string)
		if parse_result == OK:
			math_facts = json.data
		# Math facts loaded successfully
		else:
			print("Error parsing JSON: ", json.get_error_message())
	else:
		print("Could not open all_problems.json")
	
	# Initialize random number generator
	rng.randomize()
	
	# Load label settings resource
	label_settings_resource = load("res://assets/label settings/GravityBold128.tres")
	label_settings_64 = load("res://assets/label settings/GravityBold64.tres")
	star_icon_texture = load("res://assets/sprites/Star Icon.png")
	
	# Get reference to feedback color overlay, main menu, game over, and play
	feedback_color_rect = get_node("FeedbackColor")
	main_menu_node = get_node("MainMenu")
	game_over_node = get_node("GameOver")
	play_node = get_node("Play")
	title_sprite = main_menu_node.get_node("Title")
	
	# Get references to timer and accuracy labels
	timer_label = play_node.get_node("Timer")
	accuracy_label = play_node.get_node("Accuracy")
	progress_line = play_node.get_node("ProgressLine")
	drill_timer_label = play_node.get_node("DrillTimer")
	drill_score_label = play_node.get_node("DrillScore")
	
	
	# Get references to game over labels
	player_time_label = game_over_node.get_node("PlayerTime")
	player_accuracy_label = game_over_node.get_node("PlayerAccuracy")
	continue_button = game_over_node.get_node("ContinueButton")
	cqpm_label = game_over_node.get_node("CQPM")
	drill_mode_score_label = game_over_node.get_node("DrillModeScore")
	drill_accuracy_label = game_over_node.get_node("DrillAccuracy")
	high_score_text_label = game_over_node.get_node("HighScoreText")
	
	# Get reference to version label and set it to project version
	var version_label = main_menu_node.get_node("VersionLabel")
	if version_label:
		version_label.text = ProjectSettings.get_setting("application/config/version")
	
	# Get references to star nodes and their components
	star1_node = game_over_node.get_node("Star1")
	star2_node = game_over_node.get_node("Star2")
	star3_node = game_over_node.get_node("Star3")
	
	star1_sprite = star1_node.get_node("Sprite")
	star2_sprite = star2_node.get_node("Sprite")
	star3_sprite = star3_node.get_node("Sprite")
	
	star1_accuracy_label = star1_node.get_node("Accuracy")
	star1_time_label = star1_node.get_node("Time")
	star2_accuracy_label = star2_node.get_node("Accuracy")
	star2_time_label = star2_node.get_node("Time")
	star3_accuracy_label = star3_node.get_node("Accuracy")
	star3_time_label = star3_node.get_node("Time")
	
	# Get references to volume sliders
	sfx_slider = main_menu_node.get_node("VolumeControls/SFXIcon/SFXSlider")
	music_slider = main_menu_node.get_node("VolumeControls/MusicIcon/MusicSlider")
	
	# Get references to control guide nodes
	control_guide_enter = play_node.get_node("ControlGuide/Enter")
	control_guide_tab = play_node.get_node("ControlGuide/Tab")
	control_guide_divide = play_node.get_node("ControlGuide/Divide")
	
	# Store the original position of the title for animation
	if title_sprite:
		title_base_position = title_sprite.position
	
	# Store the original position of the drill score label for animation
	if drill_mode_score_label:
		drill_score_base_position = drill_mode_score_label.position
	
	# Initially hide the high score text
	if high_score_text_label:
		high_score_text_label.visible = false
	
	# Initialize save system
	initialize_save_system()
	
	# Connect and initialize volume sliders (must be done before starting music)
	connect_volume_sliders()
	
	# Start music now that volumes are set
	AudioManager.start_music()
	
	# Create dynamic level buttons
	create_level_buttons()
	
	# Connect Playcademy Scores API signals if available
	connect_playcademy_signals()
	
	# Connect menu buttons
	connect_menu_buttons()
	connect_game_over_buttons()

func _input(event):
	# Handle number input and negative sign (only during PLAY or DRILL_PLAY state and if not submitted)
	if (current_state == GameState.PLAY or current_state == GameState.DRILL_PLAY) and not answer_submitted:
		# Only process key events
		if event is InputEventKey and event.pressed and not event.echo:
			# Check each digit input action
			var digit_actions = ["Zero", "One", "Two", "Three", "Four", "Five", "Six", "Seven", "Eight", "Nine"]
			for i in range(digit_actions.size()):
				if Input.is_action_just_pressed(digit_actions[i]):
					var digit = str(i)
					
					if is_mixed_fraction_input:
						# Mixed fraction input mode
						var parts = user_answer.split(" ")
						if parts.size() == 2:
							var fraction_parts = parts[1].split("/")
							if fraction_parts.size() == 2:
								if editing_numerator:
									# Add to numerator
									var numer = fraction_parts[0]
									var effective_length = numer.length()
									if effective_length < max_answer_chars:
										user_answer = parts[0] + " " + numer + digit + "/" + fraction_parts[1]
										AudioManager.play_tick()
								else:
									# Add to denominator
									var denom = fraction_parts[1]
									var effective_length = denom.length()
									if effective_length < max_answer_chars:
										user_answer = parts[0] + " " + fraction_parts[0] + "/" + denom + digit
										AudioManager.play_tick()
					elif is_fraction_input:
						# Regular fraction input mode - add to denominator
						var parts = user_answer.split("/")
						if parts.size() == 2:
							var denom = parts[1]
							var effective_length = denom.length()
							if effective_length < max_answer_chars:
								user_answer = parts[0] + "/" + denom + digit
								AudioManager.play_tick()
					else:
						# Normal input mode
						var effective_length = user_answer.length()
						if user_answer.begins_with("-"):
							effective_length -= 1  # Don't count negative sign toward limit
						if effective_length < max_answer_chars:
							user_answer += digit
							AudioManager.play_tick()  # Play tick sound on digit input
					break
			
			# Handle negative sign (only at the beginning and only if not fraction input)
			if Input.is_action_just_pressed("Negative") and user_answer == "" and not is_fraction_input:
				user_answer = "-"
				AudioManager.play_tick()  # Play tick sound on minus input
			
			# Handle Fraction key - create mixed fraction (only for fraction-type questions)
			if Input.is_action_just_pressed("Fraction") and current_question and is_fraction_display_type(current_question.get("type", "")):
				if is_mixed_fraction_input:
					# Already in mixed fraction mode - transition from numerator to denominator
					if editing_numerator:
						# Only allow transition if numerator is not empty
						var parts = user_answer.split(" ")
						if parts.size() == 2:
							var fraction_parts = parts[1].split("/")
							if fraction_parts.size() == 2 and fraction_parts[0] != "" and fraction_parts[0] != "-":
								editing_numerator = false
								AudioManager.play_tick()
				elif not is_fraction_input and user_answer != "" and user_answer != "-":
					# Convert current answer to whole number of mixed fraction
					is_fraction_input = true
					is_mixed_fraction_input = true
					editing_numerator = true
					user_answer = user_answer + " /"  # Format: "2 /"
					AudioManager.play_tick()
					# Create answer fraction visual if needed
					if answer_fraction_node == null:
						create_answer_mixed_fraction()
			
			# Handle Divide key - convert to fraction input or transition to denominator (only for fraction-type questions)
			if Input.is_action_just_pressed("Divide") and current_question and is_fraction_display_type(current_question.get("type", "")):
				if is_mixed_fraction_input:
					# In mixed fraction mode - transition from numerator to denominator
					if editing_numerator:
						# Only allow transition if numerator is not empty
						var parts = user_answer.split(" ")
						if parts.size() == 2:
							var fraction_parts = parts[1].split("/")
							if fraction_parts.size() == 2 and fraction_parts[0] != "" and fraction_parts[0] != "-":
								editing_numerator = false
								AudioManager.play_tick()
				elif not is_fraction_input and user_answer != "" and user_answer != "-":
					# Convert current answer to numerator of regular fraction
					is_fraction_input = true
					user_answer = user_answer + "/"
					AudioManager.play_tick()
					# Create answer fraction visual if needed
					if answer_fraction_node == null:
						create_answer_fraction()
	
	# Handle immediate backspace press detection (only during PLAY or DRILL_PLAY state)
	if Input.is_action_just_pressed("Backspace") and (current_state == GameState.PLAY or current_state == GameState.DRILL_PLAY) and not answer_submitted:
		backspace_just_pressed = true
	
	# Handle submit (only during PLAY or DRILL_PLAY state)
	if Input.is_action_just_pressed("Submit") and (current_state == GameState.PLAY or current_state == GameState.DRILL_PLAY):
		submit_answer()

func _process(delta):
	# Animate title during MENU state
	if current_state == GameState.MENU and title_sprite:
		title_animation_time += delta * title_bounce_speed
		var bounce_offset = sin(title_animation_time) * title_bounce_distance
		title_sprite.position = title_base_position + Vector2(0, bounce_offset)
	
	# Animate drill mode score during GAME_OVER state (only if drill mode)
	if current_state == GameState.GAME_OVER and is_drill_mode and drill_mode_score_label and drill_mode_score_label.visible:
		drill_score_animation_time += delta * drill_score_bounce_speed
		var drill_bounce_offset = sin(drill_score_animation_time) * drill_score_bounce_distance
		drill_mode_score_label.position = drill_score_base_position + Vector2(0, drill_bounce_offset)
	
	# Animate high score text color gradient during celebration
	if is_celebrating_high_score and high_score_text_label and high_score_text_label.visible:
		high_score_flicker_time += delta * high_score_flicker_speed
		var flicker_value = sin(high_score_flicker_time)
		# Convert sin wave (-1 to 1) to interpolation value (0 to 1)
		var lerp_value = (flicker_value + 1.0) / 2.0
		# Smooth gradient between blue (0, 0, 1) and turquoise (0, 1, 1)
		var blue_color = Color(0, 0, 1, 1)
		var turquoise_color = Color(0, 1, 1, 1)
		high_score_text_label.self_modulate = blue_color.lerp(turquoise_color, lerp_value)
	
	# Only process game logic during PLAY or DRILL_PLAY state
	if current_state == GameState.PLAY or current_state == GameState.DRILL_PLAY:
		# Handle timer logic with grace period (but not during transition delays)
		if not timer_started and not in_transition_delay:
			# During grace period, timer hasn't started yet
			if not timer_active:
				grace_period_timer += delta
				if grace_period_timer >= timer_grace_period:
					timer_active = true
					timer_started = true
					level_start_time = Time.get_time_dict_from_system()["hour"] * 3600 + Time.get_time_dict_from_system()["minute"] * 60 + Time.get_time_dict_from_system()["second"]
		
		# Update timer only if active (whether during grace period or after)
		if timer_active:
			if is_drill_mode:
				# Drill mode: countdown timer and elapsed time tracking
				drill_timer_remaining -= delta
				current_level_time += delta  # Also track elapsed time for CQPM calculation
				if drill_timer_remaining <= 0.0:
					drill_timer_remaining = 0.0
					# Timer hit 0, end drill mode immediately
					go_to_drill_mode_game_over()
					return
			else:
				# Normal mode: count up timer
				current_level_time += delta
		
		# Update blink timer
		blink_timer += delta
		if blink_timer >= blink_interval:
			blink_timer = 0.0
			underscore_visible = not underscore_visible
		
		# Handle backspace - immediate response for single press, hold for repeat
		if backspace_just_pressed and not answer_submitted:
			# Immediate backspace on first press
			if user_answer.length() > 0:
				if is_mixed_fraction_input:
					# Mixed fraction backspace logic
					var parts = user_answer.split(" ")
					if parts.size() == 2:
						var fraction_parts = parts[1].split("/")
						if fraction_parts.size() == 2:
							if editing_numerator:
								# Backspacing in numerator
								var numer = fraction_parts[0]
								if numer == "":
									# Numerator empty - exit mixed fraction mode
									is_fraction_input = false
									is_mixed_fraction_input = false
									editing_numerator = true
									user_answer = parts[0]  # Return to just the whole number
									AudioManager.play_tick()
									# Clean up answer fraction visual
									if answer_fraction_node:
										answer_fraction_node.queue_free()
										var idx = current_problem_nodes.find(answer_fraction_node)
										if idx != -1:
											current_problem_nodes.remove_at(idx)
										answer_fraction_node = null
									# Show the regular label again
									if current_problem_label:
										current_problem_label.visible = true
								else:
									# Remove last digit from numerator
									user_answer = parts[0] + " " + numer.substr(0, numer.length() - 1) + "/" + fraction_parts[1]
									AudioManager.play_tick()
							else:
								# Backspacing in denominator
								var denom = fraction_parts[1]
								if denom == "":
									# Denominator empty - move back to numerator
									editing_numerator = true
									AudioManager.play_tick()
								else:
									# Remove last digit from denominator
									user_answer = parts[0] + " " + fraction_parts[0] + "/" + denom.substr(0, denom.length() - 1)
									AudioManager.play_tick()
				else:
					# Regular fraction or normal backspace logic
					# Check if we need to exit fraction mode BEFORE backspacing
					# (if denominator is already empty, indicated by ending with "/")
					var should_exit_fraction = is_fraction_input and user_answer.ends_with("/")
					
					user_answer = user_answer.substr(0, user_answer.length() - 1)
					AudioManager.play_tick()
					
					# Exit fraction mode if denominator was already empty
					if should_exit_fraction:
						is_fraction_input = false
						# Clean up answer fraction visual
						if answer_fraction_node:
							answer_fraction_node.queue_free()
							# Remove from current_problem_nodes array
							var idx = current_problem_nodes.find(answer_fraction_node)
							if idx != -1:
								current_problem_nodes.remove_at(idx)
							answer_fraction_node = null
						# Show the regular label again
						if current_problem_label:
							current_problem_label.visible = true
			backspace_just_pressed = false
			backspace_timer = 0.0
		
		# Handle backspace hold functionality
		if Input.is_action_pressed("Backspace") and not answer_submitted:
			if not backspace_held:
				backspace_timer += delta
				if backspace_timer >= backspace_hold_time:
					backspace_held = true
					backspace_timer = 0.0
			else:
				# Repeat backspace every 0.05 seconds while held
				backspace_timer += delta
				if backspace_timer >= 0.05:
					backspace_timer = 0.0
					if user_answer.length() > 0:
						if is_mixed_fraction_input:
							# Mixed fraction backspace logic (same as above)
							var parts = user_answer.split(" ")
							if parts.size() == 2:
								var fraction_parts = parts[1].split("/")
								if fraction_parts.size() == 2:
									if editing_numerator:
										var numer = fraction_parts[0]
										if numer == "":
											is_fraction_input = false
											is_mixed_fraction_input = false
											editing_numerator = true
											user_answer = parts[0]
											AudioManager.play_tick()
											if answer_fraction_node:
												answer_fraction_node.queue_free()
												var idx = current_problem_nodes.find(answer_fraction_node)
												if idx != -1:
													current_problem_nodes.remove_at(idx)
												answer_fraction_node = null
											if current_problem_label:
												current_problem_label.visible = true
										else:
											user_answer = parts[0] + " " + numer.substr(0, numer.length() - 1) + "/" + fraction_parts[1]
											AudioManager.play_tick()
									else:
										var denom = fraction_parts[1]
										if denom == "":
											editing_numerator = true
											AudioManager.play_tick()
										else:
											user_answer = parts[0] + " " + fraction_parts[0] + "/" + denom.substr(0, denom.length() - 1)
											AudioManager.play_tick()
						else:
							# Regular fraction or normal backspace logic
							# Check if we need to exit fraction mode BEFORE backspacing
							# (if denominator is already empty, indicated by ending with "/")
							var should_exit_fraction = is_fraction_input and user_answer.ends_with("/")
							
							user_answer = user_answer.substr(0, user_answer.length() - 1)
							AudioManager.play_tick()
							
							# Exit fraction mode if denominator was already empty
							if should_exit_fraction:
								is_fraction_input = false
								# Clean up answer fraction visual
								if answer_fraction_node:
									answer_fraction_node.queue_free()
									# Remove from current_problem_nodes array
									var idx = current_problem_nodes.find(answer_fraction_node)
									if idx != -1:
										current_problem_nodes.remove_at(idx)
									answer_fraction_node = null
								# Show the regular label again
								if current_problem_label:
									current_problem_label.visible = true
		else:
			# Reset hold state when backspace is released
			backspace_held = false
			backspace_timer = 0.0
		
		# Update problem display
		update_problem_display()
		
		# Update UI labels
		update_play_ui(delta)
		
		# Update control guide visibility and positions
		update_control_guide_visibility()

func is_fraction_display_type(question_type: String) -> bool:
	"""Check if a question type should be displayed in fraction format"""
	return PROBLEM_DISPLAY_FORMATS.get(question_type, "") == "fraction"

func get_display_operator(operator: String) -> String:
	"""Convert unicode operators to simple characters for display"""
	match operator:
		"×": return "x"
		"÷": return "/"
		_: return operator

func generate_new_question():
	user_answer = ""
	answer_submitted = false  # Reset submission state for new question
	is_fraction_input = false  # Reset fraction input mode
	is_mixed_fraction_input = false  # Reset mixed fraction input mode
	editing_numerator = true  # Reset to editing numerator
	answer_fraction_node = null  # Will be created by problem display if needed
	correct_answer_nodes.clear()  # Clear any lingering correct answer nodes
	
	# Store current question for answer checking later
	# Use the weighted system if we have weights initialized, otherwise fall back to old system
	if not question_weights.is_empty():
		current_question = get_weighted_random_question()
	else:
		# Fallback to old system for non-track modes
		current_question = get_math_question(current_track)
	
	if not current_question:
		print("Failed to generate question for track ", current_track)

func update_problem_display():
	# Handle fraction-type problems differently
	if current_question and is_fraction_display_type(current_question.get("type", "")):
		update_fraction_problem_display()
	elif current_problem_label and current_question:
		var base_text = current_question.question + " = "
		var display_text = base_text + user_answer
		
		# Add blinking underscore only if not submitted
		if not answer_submitted and underscore_visible:
			display_text += "_"
		
		current_problem_label.text = display_text

func update_fraction_problem_display():
	"""Update the display for fraction-type problems"""
	if is_mixed_fraction_input and answer_fraction_node:
		# In mixed fraction mode - use the fraction node to display answer
		var parts = user_answer.split(" ")
		if parts.size() == 2:
			var whole = parts[0]
			var fraction_parts = parts[1].split("/")
			if fraction_parts.size() == 2:
				var numerator = fraction_parts[0]
				var denominator = fraction_parts[1]
				answer_fraction_node.set_mixed_fraction_text(whole, numerator, denominator, editing_numerator, not editing_numerator)
				answer_fraction_node.update_underscore(underscore_visible and not answer_submitted)
				
				# Dynamically adjust position based on total width change (including whole number)
				var width_diff = answer_fraction_node.current_total_width - answer_fraction_initial_width
				var new_x = answer_fraction_base_x + (width_diff / 2.0)  # Shift right as it expands
				answer_fraction_node.position.x = new_x
		
		# Hide the regular label
		if current_problem_label:
			current_problem_label.visible = false
	elif is_fraction_input and answer_fraction_node:
		# In regular fraction mode - use the fraction node to display answer
		var parts = user_answer.split("/")
		if parts.size() == 2:
			var numerator = parts[0]
			var denominator = parts[1]
			answer_fraction_node.set_fraction_text(numerator, denominator, true)
			answer_fraction_node.update_underscore(underscore_visible and not answer_submitted)
			
			# Dynamically adjust position based on divisor width change
			var width_diff = answer_fraction_node.current_divisor_width - answer_fraction_initial_width
			var new_x = answer_fraction_base_x + (width_diff / 2.0)  # Shift right as it expands
			answer_fraction_node.position.x = new_x
		
		# Hide the regular label
		if current_problem_label:
			current_problem_label.visible = false
	else:
		# Not in fraction mode yet - use regular label to show answer with underscore
		if current_problem_label:
			var display_text = user_answer
			
			# Add blinking underscore only if not submitted
			if not answer_submitted and underscore_visible:
				display_text += "_"
			
			current_problem_label.text = display_text
			current_problem_label.visible = true

func submit_answer():
	if user_answer == "" or user_answer == "-" or answer_submitted:
		return  # Don't submit empty answers, just minus sign, or already submitted
	
	# Don't submit mixed fractions with empty numerator or denominator
	if is_mixed_fraction_input:
		var parts = user_answer.split(" ")
		if parts.size() != 2:
			return
		var fraction_parts = parts[1].split("/")
		if fraction_parts.size() != 2:
			return
		
		# Transition from numerator to denominator if still editing numerator
		if editing_numerator:
			editing_numerator = false
			AudioManager.play_tick()
			return
		
		# Don't submit if numerator or denominator is empty
		if fraction_parts[0] == "" or fraction_parts[1] == "":
			return
	
	# Don't submit regular fractions with empty denominator
	if is_fraction_input and not is_mixed_fraction_input:
		var parts = user_answer.split("/")
		if parts.size() != 2 or parts[1] == "":
			return
	
	print("Submitting answer: ", user_answer)
	
	# Mark as submitted to prevent further input
	answer_submitted = true
	
	# Calculate time taken for this question
	var question_time = 0.0
	if current_question_start_time > 0:
		question_time = (Time.get_ticks_msec() / 1000.0) - current_question_start_time
	
	# Check if answer is correct
	var is_correct = false
	var player_answer_value = null  # Can be int or string depending on question type
	
	if is_fraction_display_type(current_question.get("type", "")):
		# For fraction questions, compare strings directly
		player_answer_value = user_answer
		is_correct = (user_answer == current_question.result)
	else:
		# For integer questions, compare as integers
		player_answer_value = int(user_answer)
		is_correct = (player_answer_value == current_question.result)
	
	# Save question data
	if current_question:
		save_question_data(current_question, player_answer_value, question_time)
	
	# Track correct answers and drill mode scoring
	if is_drill_mode:
		drill_total_answered += 1  # Track total questions answered in drill mode
	
	if is_correct:
		correct_answers += 1
		if is_drill_mode:
			drill_streak += 1
			# Calculate drill mode score: difficulty + streak
			var difficulty = calculate_question_difficulty(current_question)
			var points_earned = difficulty + drill_streak
			drill_score += points_earned
			drill_score_target_value = drill_score
			print("Drill mode: +", points_earned, " points (", difficulty, " difficulty + ", drill_streak, " streak)")
			
			# Trigger score animations
			create_flying_score_label(points_earned)
			animate_drill_score_scale()
	else:
		if is_drill_mode:
			drill_streak = 0  # Reset streak on incorrect answer
	
	# Pause timer during transition and store its previous state
	var timer_was_active = timer_active
	var should_start_timer = false
	
	# Check if we're in grace period and should start timer after transition
	if not timer_started and grace_period_timer >= timer_grace_period:
		should_start_timer = true
	
	# Set transition delay flag and pause timer
	in_transition_delay = true
	timer_active = false
	
	# Determine which delay to use based on correctness
	var delay_to_use = transition_delay  # Default delay for correct answers
	if not is_correct:
		delay_to_use = transition_delay_incorrect  # Longer delay for incorrect answers
	
	# Set color based on correctness, play sound, and show feedback overlay
	var feedback_color = Color(0, 1, 0) if is_correct else Color(1, 0, 0)
	
	# Color all problem nodes (fractions, operators, equals, labels)
	for node in current_problem_nodes:
		if node:
			# Use modulate for fractions (Control nodes), self_modulate for labels
			if node is Control and not node is Label:
				node.modulate = feedback_color
			else:
				node.self_modulate = feedback_color
	
	# Also color the regular problem label if it exists
	if current_problem_label:
		current_problem_label.self_modulate = feedback_color
	
	# Play sounds and show feedback
	if is_correct:
		AudioManager.play_correct()  # Play correct sound
		show_feedback_flash(Color(0, 1, 0))  # Green feedback flash
		print("✓ Correct! Answer was ", current_question.result)
	else:
		AudioManager.play_incorrect()  # Play incorrect sound
		show_feedback_flash(Color(1, 0, 0))  # Red feedback flash
		print("✗ Incorrect. Answer was ", current_question.result, ", you entered ", player_answer_value)
		
		# Create animated label showing correct answer for incorrect responses
		create_incorrect_answer_label()
	
	# Wait for the full transition delay (timer remains paused during this time)
	if delay_to_use > 0.0:
		await get_tree().create_timer(delay_to_use).timeout
	
	# Clear transition delay flag
	in_transition_delay = false
	
	# Trigger scroll speed boost effect after transition delay
	var space_bg = get_node("BackgroundLayer/SpaceBackground")
	if space_bg and space_bg.has_method("boost_scroll_speed"):
		space_bg.boost_scroll_speed(scroll_boost_multiplier, animation_duration * 2.0)
	
	# Move current problem nodes up and off screen (fire and forget)
	if not current_problem_nodes.is_empty():
		# Store references to the nodes we're animating out
		var nodes_to_animate = current_problem_nodes.duplicate()
		
		# Determine if we need extra offset for fraction problems
		var extra_offset = 0.0
		if current_question and is_fraction_display_type(current_question.get("type", "")) and not is_correct:
			extra_offset = incorrect_label_move_distance_fractions
		
		# Also store correct answer nodes if they exist (for incorrect fraction problems)
		var correct_nodes_to_animate = correct_answer_nodes.duplicate()
		
		# Clear current_problem_nodes and correct_answer_nodes immediately so new problem can populate it
		current_problem_nodes.clear()
		correct_answer_nodes.clear()
		current_problem_label = null
		answer_fraction_node = null
		
		# Animate all problem nodes off-screen
		var tween = create_tween()
		tween.set_ease(Tween.EASE_OUT)
		tween.set_trans(Tween.TRANS_EXPO)
		tween.set_parallel(true)  # Animate all simultaneously
		
		# Calculate final off-screen position
		var final_offscreen_y = off_screen_top.y
		
		# For incorrect fraction problems, need extra clearance and maintain vertical separation
		if extra_offset > 0:
			# Make it go farther off screen to ensure both displays are hidden
			final_offscreen_y = off_screen_top.y * 1.5 - extra_offset
			
			# Animate incorrect problem nodes (currently at original_y - extra_offset)
			# They go to the higher (more negative) off-screen position
			# Note: Only animate top-level nodes; children move with their parents
			for node in nodes_to_animate:
				if node and node.get_parent() == play_node:
					var target_pos = Vector2(node.position.x, final_offscreen_y - extra_offset)
					tween.tween_property(node, "position", target_pos, animation_duration)
			
			# Animate correct answer nodes (currently at original_y + extra_offset)
			# They go to a lower off-screen position, maintaining the 2*extra_offset gap
			for node in correct_nodes_to_animate:
				if node:
					var target_pos = Vector2(node.position.x, final_offscreen_y + extra_offset)
					tween.tween_property(node, "position", target_pos, animation_duration)
		else:
			# For correct answers or non-fraction problems, just animate to regular off-screen position
			# Note: Only animate top-level nodes; children move with their parents
			for node in nodes_to_animate:
				if node and node.get_parent() == play_node:
					var target_pos = Vector2(node.position.x, final_offscreen_y)
					tween.tween_property(node, "position", target_pos, animation_duration)
		
		# Exit parallel mode before adding callback so it runs AFTER animations complete
		tween.set_parallel(false)
		
		# Clean up all nodes after animation completes
		tween.tween_callback(func():
			for node in nodes_to_animate:
				if node:
					node.queue_free()
			for node in correct_nodes_to_animate:
				if node:
					node.queue_free()
		)
	elif current_problem_label:
		# Fallback for regular label problems
		var old_label = current_problem_label
		var tween = create_tween()
		tween.set_ease(Tween.EASE_OUT)
		tween.set_trans(Tween.TRANS_EXPO)
		tween.tween_property(old_label, "position", off_screen_top, animation_duration)
		tween.tween_callback(old_label.queue_free)
	
	# Increment problems completed
	problems_completed += 1
	
	# Animate progress line after incrementing
	var level_config = level_configs.get(current_level_number, level_configs[1])
	
	if progress_line and play_node:
		var play_width = play_node.size.x
		var progress_increment = play_width / level_config.problems
		var new_x_position = progress_increment * problems_completed
		
		# Animate point 1 to the new x position
		var tween = create_tween()
		tween.set_ease(Tween.EASE_OUT)
		tween.set_trans(Tween.TRANS_EXPO)
		tween.tween_method(update_progress_line_point, progress_line.get_point_position(1).x, new_x_position, animation_duration)
	
	# Check if we've completed the required number of problems (only for normal mode)
	if not is_drill_mode and problems_completed >= level_config.problems:
		# Timer is already stopped above, keep it stopped for game over
		
		# Hide play UI labels when play state ends
		if timer_label:
			timer_label.visible = false
		if accuracy_label:
			accuracy_label.visible = false
		
		# Wait for the same transition delay used above, then go to game over
		await get_tree().create_timer(delay_to_use).timeout
		go_to_game_over()
	else:
		# Resume timer after transition delay or start it if grace period completed during transition
		if timer_was_active or should_start_timer:
			timer_active = true
			# If timer should start now, mark it as started and record start time
			if should_start_timer and not timer_started:
				timer_started = true
				level_start_time = Time.get_time_dict_from_system()["hour"] * 3600 + Time.get_time_dict_from_system()["minute"] * 60 + Time.get_time_dict_from_system()["second"]
		
		# Create new problem - continue playing
		generate_new_question()
		create_new_problem_label()

func create_new_problem_label():
	# Check if this is a fraction-type problem
	if current_question and is_fraction_display_type(current_question.get("type", "")):
		create_fraction_problem()
		# Start timing this question immediately for fraction problems
		start_question_timing()
		return
	
	# Create new label for normal (non-fraction) problems
	var new_label = Label.new()
	new_label.label_settings = label_settings_resource
	new_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	new_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	new_label.position = off_screen_bottom
	new_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	new_label.self_modulate = Color(1, 1, 1)  # Reset to white color
	new_label.z_index = -1  # Render behind UI elements
	
	# Add to Play node so it renders behind Play UI elements
	play_node.add_child(new_label)
	
	# Set as current problem label IMMEDIATELY
	current_problem_label = new_label
	
	# Animate to center position (fire and forget)
	var tween = create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_EXPO)
	tween.tween_property(new_label, "position", primary_position, animation_duration)
	
	# Start timing this question when animation completes
	tween.tween_callback(start_question_timing)


func get_math_question(track = null, grade = null, operator = null, no_zeroes = false):
	if not math_facts.has("levels"):
		return null
	
	var questions = []
	var question_title = ""
	var question_grade = ""
	
	# Priority: track > grade > operator
	if track != null:
		# Find questions from specific track
		var track_key = str(track) if typeof(track) == TYPE_STRING else "TRACK" + str(track)
		for level in math_facts.levels:
			if level.id == track_key:
				questions = level.facts
				question_title = level.title
				question_grade = ""  # No grade info in all_problems.json
				break
		
		# If track not found, pick random existing track
		if questions.is_empty():
			if not math_facts.levels.is_empty():
				var random_level = math_facts.levels[rng.randi() % math_facts.levels.size()]
				questions = random_level.facts
				question_title = random_level.title
				question_grade = ""
	
	elif grade != null:
		# Handle grade selection - collect all questions from all levels (since no grade grouping)
		question_grade = "Grade " + str(grade)
		
		# If operator is also specified, try to find questions with that operator
		if operator != null:
			var operator_str = get_operator_string(operator)
			var matching_questions = []
			var matching_title = ""
			
			for level in math_facts.levels:
				for fact in level.facts:
					if fact.operator == operator_str:
						matching_questions.append(fact)
						if matching_title == "":
							matching_title = level.title
			
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
			# Get all questions from all levels
			for level in math_facts.levels:
				questions.append_array(level.facts)
				if question_title == "":
					question_title = question_grade
	
	elif operator != null:
		# Get all questions with specific operator
		var operator_str = get_operator_string(operator)
		for level in math_facts.levels:
			for fact in level.facts:
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
		return null
	
	var random_question = questions[rng.randi() % questions.size()]
	
	# Generate question text
	var question_text = ""
	
	# Check if this is a fraction-type question (operands are arrays of arrays)
	if random_question.has("type") and is_fraction_display_type(random_question.get("type", "")):
		# For fraction questions, use the expression as the question text
		if random_question.has("expression") and random_question.expression != "" and not random_question.expression.contains("["):
			# Expression exists and doesn't contain malformed array notation
			question_text = random_question.expression.split(" = ")[0]
		else:
			# Fallback: construct from operands if expression doesn't exist
			if random_question.has("operands") and random_question.operands.size() >= 2:
				var op1 = random_question.operands[0]
				var op2 = random_question.operands[1]
				var op1_str = ""
				var op2_str = ""
				
				# Format operand 1
				if typeof(op1) == TYPE_ARRAY and op1.size() >= 2:
					op1_str = str(int(op1[0])) + "/" + str(int(op1[1]))
				else:
					op1_str = str(int(op1) if typeof(op1) == TYPE_FLOAT else op1)
				
				# Format operand 2
				if typeof(op2) == TYPE_ARRAY and op2.size() >= 2:
					op2_str = str(int(op2[0])) + "/" + str(int(op2[1]))
				else:
					op2_str = str(int(op2) if typeof(op2) == TYPE_FLOAT else op2)
				
				question_text = op1_str + " " + random_question.operator + " " + op2_str
	else:
		# For regular questions, format integers without decimals
		# Check if operands exist and are numeric (not arrays) before converting
		if random_question.has("operands") and random_question.operands != null and random_question.operands.size() >= 2:
			var operand1 = random_question.operands[0]
			var operand2 = random_question.operands[1]
			if typeof(operand1) == TYPE_FLOAT and operand1 == int(operand1):
				operand1 = int(operand1)
			if typeof(operand2) == TYPE_FLOAT and operand2 == int(operand2):
				operand2 = int(operand2)
			question_text = str(operand1) + " " + random_question.operator + " " + str(operand2)
		else:
			# No operands - use expression if available
			question_text = random_question.get("expression", "").split(" = ")[0] if random_question.has("expression") else ""
	
	return {
		"operands": random_question.get("operands", []),
		"operator": random_question.operator,
		"result": random_question.result,
		"expression": random_question.get("expression", ""),
		"question": question_text,
		"title": question_title,
		"grade": question_grade,
		"type": random_question.get("type", "")  # Include type if it exists in the question data (default to empty string)
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
	var questions = []
	
	# Collect all questions with the operator from all levels
	for level in math_facts.levels:
		for fact in level.facts:
			if fact.operator == operator_str:
				questions.append(fact)
	
	return {
		"questions": questions,
		"grade_name": "Grade " + str(target_grade)
	}

func create_incorrect_answer_label():
	"""Create and animate a label showing the correct answer when user is incorrect"""
	if not current_question:
		return
	
	# Check if this is a fraction problem - handle differently
	if is_fraction_display_type(current_question.get("type", "")):
		create_incorrect_fraction_answer()
		return
	
	# Regular problem - use the old method
	if not current_problem_label:
		return
	
	# Create new label as child of current problem label
	var incorrect_label = Label.new()
	incorrect_label.label_settings = label_settings_resource  # Uses GravityBold128
	incorrect_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	incorrect_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	incorrect_label.position = Vector2(0, 0)  # Start at (0, 0) relative to parent
	incorrect_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	incorrect_label.text = current_question.expression  # Set to the expression
	incorrect_label.self_modulate = Color(0, 0.5, 0)  # Dark green color
	incorrect_label.z_index = -1  # Render behind UI elements
	
	# Add as child to current problem label
	current_problem_label.add_child(incorrect_label)
	
	# Animate the label moving down over incorrect_label_animation_time
	var tween = create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_EXPO)
	tween.tween_property(incorrect_label, "position", Vector2(0, incorrect_label_move_distance), incorrect_label_animation_time)
	
	# The label will be cleaned up when the parent problem label is removed

func create_incorrect_fraction_answer():
	"""Create and animate fraction elements showing the correct answer for fraction problems"""
	if not current_question or not is_fraction_display_type(current_question.get("type", "")):
		return
	
	# Clear any existing correct answer nodes
	for node in correct_answer_nodes:
		if node:
			node.queue_free()
	correct_answer_nodes.clear()
	
	# Parse the correct answer from the result (e.g., "10/9", "2 1/2", or "1")
	var result_data = parse_mixed_fraction_from_string(current_question.result)
	# result_data format: [whole, numerator, denominator]
	var is_mixed_result = result_data[0] > 0
	var is_fraction_result = result_data[1] > 0  # Has a fraction part
	
	# Create correct answer elements in dark green, positioned at the same locations as current problem
	
	# Parse operands the same way as create_fraction_problem
	var operand1_data = null
	var operand2_data = null
	
	# Check if operands exist and are valid
	var has_valid_operands = (current_question.has("operands") and 
							   current_question.operands != null and 
							   current_question.operands.size() >= 2 and
							   current_question.operands[0] != null)
	
	if has_valid_operands:
		var operand1 = current_question.operands[0]
		var operand2 = current_question.operands[1]
		
		# Handle each operand individually (could be array or number)
		if typeof(operand1) == TYPE_ARRAY and operand1.size() >= 2:
			# Fraction format [num, denom]
			operand1_data = [0, int(operand1[0]), int(operand1[1])]
		elif typeof(operand1) == TYPE_FLOAT or typeof(operand1) == TYPE_INT:
			# Whole number - display as numerator with denominator 1 (will show as "6/1")
			operand1_data = [0, int(operand1), 1]
		
		if typeof(operand2) == TYPE_ARRAY and operand2.size() >= 2:
			# Fraction format [num, denom]
			operand2_data = [0, int(operand2[0]), int(operand2[1])]
		elif typeof(operand2) == TYPE_FLOAT or typeof(operand2) == TYPE_INT:
			# Whole number - display as numerator with denominator 1 (will show as "6/1")
			operand2_data = [0, int(operand2), 1]
	
	# If we don't have valid operands, parse from expression (for mixed fractions)
	if operand1_data == null or operand2_data == null:
		var expr = current_question.get("expression", "")
		if expr != "":
			var expr_parts = expr.split(" = ")[0].split(" ")
			# Find operator position
			var operator_idx = -1
			for i in range(expr_parts.size()):
				if expr_parts[i] == current_question.operator:
					operator_idx = i
					break
			
			if operator_idx > 0:
				# Parse operand1 (everything before operator)
				var operand1_str = ""
				for i in range(operator_idx):
					if operand1_str != "":
						operand1_str += " "
					operand1_str += expr_parts[i]
				operand1_data = parse_mixed_fraction_from_string(operand1_str)
				
				# Parse operand2 (everything after operator)
				var operand2_str = ""
				for i in range(operator_idx + 1, expr_parts.size()):
					if operand2_str != "":
						operand2_str += " "
					operand2_str += expr_parts[i]
				operand2_data = parse_mixed_fraction_from_string(operand2_str)
	
	if operand1_data == null or operand2_data == null:
		return
	
	# Calculate the same positions as the original problem
	var base_x = primary_position.x + fraction_problem_x_offset
	var target_y = primary_position.y
	
	# Create fractions to measure their widths
	var fraction1 = create_fraction(Vector2(0, 0), operand1_data[1], operand1_data[2], play_node)
	if operand1_data[0] > 0:
		fraction1.set_mixed_fraction(operand1_data[0], operand1_data[1], operand1_data[2])
	
	var fraction2 = create_fraction(Vector2(0, 0), operand2_data[1], operand2_data[2], play_node)
	if operand2_data[0] > 0:
		fraction2.set_mixed_fraction(operand2_data[0], operand2_data[1], operand2_data[2])
	
	# Create answer fraction/mixed fraction if result has a fraction part
	var answer_fraction = null
	if is_fraction_result:
		answer_fraction = create_fraction(Vector2(0, 0), result_data[1], result_data[2], play_node)
		if is_mixed_result:
			answer_fraction.set_mixed_fraction(result_data[0], result_data[1], result_data[2])
	
	# Get the actual widths of the fractions (use total width for mixed fractions)
	var fraction1_width = fraction1.current_total_width if fraction1.is_mixed_fraction else fraction1.current_divisor_width
	var fraction2_width = fraction2.current_total_width if fraction2.is_mixed_fraction else fraction2.current_divisor_width
	var fraction1_half_width = fraction1_width / 2.0
	var fraction2_half_width = fraction2_width / 2.0
	
	# Position the equals sign at a fixed location (same as in create_fraction_problem)
	var equals_x = base_x + 672.0
	
	# Work backwards from equals sign to position fraction2
	# Each fraction takes up: fraction_element_spacing + its half width on each side
	var fraction2_x = equals_x - fraction_element_spacing - fraction2_half_width
	
	# Position operator between fraction2 and fraction1
	var operator_x = fraction2_x - fraction2_half_width - fraction_element_spacing
	
	# Position fraction1
	var fraction1_x = operator_x - fraction_element_spacing - fraction1_half_width
	
	# Position answer area after equals sign
	var answer_x = equals_x + fraction_element_spacing + fraction_answer_offset
	var answer_number_x = answer_x + fraction_answer_number_offset
	
	# Check if problem extends too far left and adjust if necessary
	var leftmost_x = fraction1_x - fraction1_half_width
	if leftmost_x < fraction_problem_min_x:
		var x_offset = fraction_problem_min_x - leftmost_x
		# Shift all x positions rightward
		fraction1_x += x_offset
		operator_x += x_offset
		fraction2_x += x_offset
		equals_x += x_offset
		answer_x += x_offset
		answer_number_x += x_offset
	
	# Position all the fractions
	fraction1.position = Vector2(fraction1_x, target_y) + fraction_offset
	fraction2.position = Vector2(fraction2_x, target_y) + fraction_offset
	
	# Apply dark green color and z_index
	fraction1.modulate = Color(0, 0.5, 0)
	fraction2.modulate = Color(0, 0.5, 0)
	fraction1.z_index = -1  # Render behind UI elements
	fraction2.z_index = -1  # Render behind UI elements
	
	correct_answer_nodes.append(fraction1)
	correct_answer_nodes.append(fraction2)
	
	# Create either answer fraction/mixed fraction or answer label depending on result type
	if is_fraction_result:
		# Apply dynamic X positioning to answer fraction based on width (divisor or total for mixed)
		# Get baseline width by creating a temporary 0/1 fraction
		var temp_fraction = create_fraction(Vector2(0, 0), 0, 1, play_node)
		var baseline_width = temp_fraction.current_divisor_width
		temp_fraction.queue_free()
		
		# Calculate width difference and adjust position (shift right as it expands)
		var answer_width = answer_fraction.current_total_width if answer_fraction.is_mixed_fraction else answer_fraction.current_divisor_width
		var width_diff = answer_width - baseline_width
		
		# Position is already calculated correctly from the problem layout, no extra offset needed
		answer_fraction.position = Vector2(answer_x + (width_diff / 2.0), target_y) + fraction_offset
		answer_fraction.modulate = Color(0, 0.5, 0)
		answer_fraction.z_index = -1  # Render behind UI elements
		correct_answer_nodes.append(answer_fraction)
	else:
		# Create a label for the whole number answer (or parse result string directly)
		var answer_label = Label.new()
		answer_label.label_settings = label_settings_resource
		answer_label.text = current_question.result
		answer_label.position = Vector2(answer_number_x, target_y) + operator_offset
		answer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		answer_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		answer_label.self_modulate = Color(0, 0.5, 0)  # Dark green
		answer_label.z_index = -1  # Render behind UI elements
		play_node.add_child(answer_label)
		correct_answer_nodes.append(answer_label)
	
	# Create operator label as child of fraction1
	var operator_label = Label.new()
	operator_label.label_settings = label_settings_resource
	operator_label.text = get_display_operator(current_question.operator)
	# Apply simple operator offset for converted unicode operators
	var op_offset = operator_offset
	if current_question.operator == "×" or current_question.operator == "÷":
		op_offset += simple_operator_offset
	operator_label.position = Vector2(operator_x - fraction1_x, 0) + op_offset - fraction_offset
	operator_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	operator_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	operator_label.z_index = -1  # Render behind UI elements
	# Don't set self_modulate - inherit dark green from parent fraction
	fraction1.add_child(operator_label)
	correct_answer_nodes.append(operator_label)
	
	# Create equals label as child of fraction2
	var equals_label = Label.new()
	equals_label.label_settings = label_settings_resource
	equals_label.text = "="
	equals_label.position = Vector2(equals_x - fraction2_x, 0) + operator_offset - fraction_offset
	equals_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	equals_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	equals_label.z_index = -1  # Render behind UI elements
	# Don't set self_modulate - inherit dark green from parent fraction
	fraction2.add_child(equals_label)
	correct_answer_nodes.append(equals_label)
	
	# Create parallel tweens for animating everything
	var correct_tween = create_tween()
	var incorrect_tween = create_tween()
	
	correct_tween.set_ease(Tween.EASE_OUT)
	correct_tween.set_trans(Tween.TRANS_EXPO)
	correct_tween.set_parallel(true)
	
	incorrect_tween.set_ease(Tween.EASE_OUT)
	incorrect_tween.set_trans(Tween.TRANS_EXPO)
	incorrect_tween.set_parallel(true)
	
	# Animate correct answer elements DOWN
	# Note: Skip child nodes (operators/equals) since they move with their parents
	for node in correct_answer_nodes:
		if node and node.get_parent() == play_node:  # Only animate top-level nodes
			var target_pos = node.position + Vector2(0, incorrect_label_move_distance_fractions)
			correct_tween.tween_property(node, "position", target_pos, incorrect_label_animation_time)
	
	# Animate incorrect problem nodes UP
	# Note: Skip child nodes (operators/equals) since they move with their parents
	for node in current_problem_nodes:
		if node and node.get_parent() == play_node:  # Only animate top-level nodes
			var target_pos = node.position - Vector2(0, incorrect_label_move_distance_fractions)
			incorrect_tween.tween_property(node, "position", target_pos, incorrect_label_animation_time)
	
	# Correct answer nodes will be animated off screen and cleaned up by submit_answer()

func update_progress_line_point(x_position: float):
	"""Update the x position of point 1 in the progress line"""
	if progress_line and progress_line.get_point_count() >= 2:
		progress_line.set_point_position(1, Vector2(x_position, 0))

func show_feedback_flash(flash_color: Color):
	"""Show a colored flash overlay that fades in then out with smooth timing"""
	if not feedback_color_rect:
		return
	
	# Start with the color at 0 alpha (invisible)
	feedback_color_rect.modulate = Color(flash_color.r, flash_color.g, flash_color.b, 0.0)
	
	# Create tween for the two-phase animation
	var tween = create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_EXPO)
	
	# Phase 1: Fade in from 0 to feedback_max_alpha over transition_delay
	tween.tween_property(feedback_color_rect, "modulate:a", feedback_max_alpha, transition_delay)
	
	# Phase 2: Fade out from feedback_max_alpha to 0 over animation_duration * 2
	tween.tween_property(feedback_color_rect, "modulate:a", 0.0, animation_duration * 2.0)

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

func create_level_buttons():
	"""Dynamically create level buttons with level pack outlines"""
	var global_button_number = 1
	var current_row_buttons = []  # Track buttons in current row for centering
	var current_row_outlines = []  # Track outlines in current row for centering
	var current_x = level_button_start_position.x
	var current_y = level_button_start_position.y
	var current_row_start_x = current_x
	
	# Iterate through each pack in order
	for pack_name in level_pack_order:
		var pack_config = level_packs[pack_name]
		var pack_levels = pack_config.levels
		var theme_color = pack_config.theme_color
		
		var pack_first_button_in_row = true  # Track if this is the first button of the pack in this row
		var pack_buttons_in_row = []  # Track buttons of this pack in current row
		var outline_start_x = 0.0  # Track where outline should start
		
		# Iterate through each level in the pack
		for level_index in range(pack_levels.size()):
			var track_id = pack_levels[level_index]
			
			# Check if this button is the first in a new pack segment on this row
			if pack_first_button_in_row:
				# Add extra spacing if not the first pack on the row
				if current_row_buttons.size() > 0:
					current_x += abs(pack_outline_offset.x)
				outline_start_x = current_x
			
			# Calculate button right edge
			var button_right_edge = current_x + level_button_size.x
			
			# Check if we need to wrap to a new row
			if button_right_edge > level_button_start_position.x + max_row_width:
				# Finalize and center current row
				finalize_and_center_row(current_row_buttons, current_row_outlines, current_row_start_x)
				
				# Start new row
				current_x = level_button_start_position.x
				current_y += level_button_spacing.y
				current_row_start_x = current_x
				current_row_buttons.clear()
				current_row_outlines.clear()
				
				# Create new outline for continuation of pack on new row
				if pack_buttons_in_row.size() > 0:
					# Finalize previous row's pack outline
					create_pack_outline(pack_name, pack_buttons_in_row, outline_start_x, current_row_outlines, theme_color)
					pack_buttons_in_row.clear()
				
				# Reset for new row
				pack_first_button_in_row = true
				outline_start_x = current_x
			
			# Create button at current position
			var button_position = Vector2(current_x, current_y)
			var button = create_single_button(global_button_number, pack_name, level_index, track_id, button_position, theme_color)
			
			# Track button
			current_row_buttons.append(button)
			pack_buttons_in_row.append(button)
			level_buttons.append({
				"button": button,
				"pack_name": pack_name,
				"pack_level_index": level_index,
				"global_number": global_button_number
			})
			
			# Move to next button position
			current_x += level_button_spacing.x
			global_button_number += 1
			pack_first_button_in_row = false
		
		# Create outline for this pack segment (or final segment if wrapped)
		if pack_buttons_in_row.size() > 0:
			create_pack_outline(pack_name, pack_buttons_in_row, outline_start_x, current_row_outlines, theme_color)
			pack_buttons_in_row.clear()
	
	# Finalize and center the last row
	if current_row_buttons.size() > 0:
		finalize_and_center_row(current_row_buttons, current_row_outlines, current_row_start_x)
	
	# Update stars based on save data
	update_menu_stars()
	update_level_availability()

func create_single_button(global_number: int, pack_name: String, pack_level_index: int, track_id, button_position: Vector2, theme_color: Color) -> Button:
	"""Create a single level button"""
	var button = Button.new()
	button.name = "LevelButton_" + pack_name + "_" + str(pack_level_index)
	button.custom_minimum_size = level_button_size
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.self_modulate = theme_color
	
	# Set anchors and position (center anchored)
	button.anchor_left = 0.5
	button.anchor_top = 0.5
	button.anchor_right = 0.5
	button.anchor_bottom = 0.5
	button.offset_left = button_position.x
	button.offset_top = button_position.y
	button.offset_right = button_position.x + level_button_size.x
	button.offset_bottom = button_position.y + level_button_size.y
	button.grow_horizontal = Control.GROW_DIRECTION_BOTH
	button.grow_vertical = Control.GROW_DIRECTION_BOTH
	
	# Get tooltip from track data
	var question_data = get_math_question(track_id)
	if question_data and question_data.has("title"):
		button.tooltip_text = question_data.title
	
	# Create Contents control
	var contents = Control.new()
	contents.name = "Contents"
	contents.set_anchors_preset(Control.PRESET_FULL_RECT)
	contents.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(contents)
	
	# Create Number label
	var number_label = Label.new()
	number_label.name = "Number"
	number_label.text = str(global_number)
	number_label.label_settings = label_settings_64
	number_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	number_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	number_label.position = Vector2(4, -32)
	number_label.size = Vector2(192, 192)
	contents.add_child(number_label)
	
	# Create star sprites
	var star_positions = [Vector2(44, 136), Vector2(96, 144), Vector2(148, 136)]
	for i in range(3):
		var star = Sprite2D.new()
		star.name = "Star" + str(i + 1)
		star.texture = star_icon_texture
		star.hframes = 2
		star.frame = 0  # Start with unearned star
		star.scale = Vector2(2, 2)
		star.position = star_positions[i]
		contents.add_child(star)
	
	# Add button to main menu
	main_menu_node.add_child(button)
	
	# Connect button press and sounds
	button.pressed.connect(_on_level_button_pressed.bind(pack_name, pack_level_index))
	connect_button_sounds(button)
	
	return button

func create_pack_outline(pack_name: String, pack_buttons: Array, start_x: float, row_outlines: Array, theme_color: Color):
	"""Create a level pack outline for a segment of buttons"""
	if pack_buttons.size() == 0:
		return
	
	# Calculate outline width based on number of buttons
	var num_buttons = pack_buttons.size()
	var outline_width = pack_outline_base_width + (num_buttons - 1) * level_button_spacing.x
	
	# Get position from first button in segment
	var first_button = pack_buttons[0]
	var outline_x = start_x + pack_outline_offset.x
	var outline_y = first_button.offset_top + pack_outline_offset.y
	
	# Create outline container
	var outline_container = Control.new()
	outline_container.name = "LevelPackOutline_" + pack_name
	outline_container.anchor_left = 0.5
	outline_container.anchor_top = 0.5
	outline_container.anchor_right = 0.5
	outline_container.anchor_bottom = 0.5
	outline_container.offset_left = outline_x
	outline_container.offset_top = outline_y
	outline_container.offset_right = outline_x + 40
	outline_container.offset_bottom = outline_y + 40
	outline_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	# Create ShapeHorizontal
	var shape_horizontal = ColorRect.new()
	shape_horizontal.name = "ShapeHorizontal"
	shape_horizontal.position = Vector2(0, 0)
	shape_horizontal.size = Vector2(outline_width, pack_outline_height)
	shape_horizontal.color = theme_color
	outline_container.add_child(shape_horizontal)
	
	# Create TailHorizontal
	var tail_horizontal = Sprite2D.new()
	tail_horizontal.name = "TailHorizontal"
	var triangle_texture = load("res://assets/sprites/Triangle.png")
	tail_horizontal.texture = triangle_texture
	tail_horizontal.self_modulate = theme_color
	tail_horizontal.position = Vector2(outline_width + 32, pack_outline_height / 2.0)
	tail_horizontal.scale = Vector2(2, 1)
	outline_container.add_child(tail_horizontal)
	
	# Create ShapeVertical
	var shape_vertical = ColorRect.new()
	shape_vertical.name = "ShapeVertical"
	shape_vertical.position = Vector2(0, pack_outline_height)
	shape_vertical.size = Vector2(pack_outline_height, pack_outline_vertical_height)
	shape_vertical.color = theme_color
	outline_container.add_child(shape_vertical)
	
	# Create TailVertical
	var tail_vertical = Sprite2D.new()
	tail_vertical.name = "TailVertical"
	tail_vertical.texture = triangle_texture
	tail_vertical.self_modulate = theme_color
	tail_vertical.position = Vector2(pack_outline_height / 2.0, pack_outline_height + pack_outline_vertical_height + 32)
	tail_vertical.rotation = 4.712389  # -90 degrees in radians
	tail_vertical.scale = Vector2(-2, 1)
	outline_container.add_child(tail_vertical)
	
	# Create Label
	var label_settings_24 = load("res://assets/label settings/GravityBold24Plain.tres")
	var label = Label.new()
	label.name = "Label"
	label.position = Vector2(4, 4)
	label.size = Vector2(outline_width - 8, pack_outline_height - 8)
	label.text = pack_name
	label.label_settings = label_settings_24
	outline_container.add_child(label)
	
	# Add to main menu and track
	main_menu_node.add_child(outline_container)
	level_pack_outlines.append(outline_container)
	row_outlines.append(outline_container)

func finalize_and_center_row(row_buttons: Array, row_outlines: Array, _row_start_x: float):
	"""Center all buttons and outlines in a row by calculating equal padding"""
	if row_buttons.size() == 0:
		return
	
	# Calculate actual row width used (including outlines)
	var first_button = row_buttons[0]
	var last_button = row_buttons[row_buttons.size() - 1]
	
	# The leftmost point is the outline (which extends left of the first button)
	var row_left = first_button.offset_left + pack_outline_offset.x
	var row_right = last_button.offset_right
	var row_width = row_right - row_left
	
	# Calculate where the leftmost point should be to center the row
	# Available width is max_row_width (1792), centered within the screen
	# Screen is 1920 wide, buttons are center-anchored (anchor at 960)
	# Left boundary (in center-relative coords) = minimum_padding - 960 = 64 - 960 = -896
	var left_boundary = minimum_padding - 960.0  # Convert to center-relative coordinates
	var total_padding = max_row_width - row_width
	var padding_each_side = total_padding / 2.0
	
	# Target position for leftmost point
	var target_left = left_boundary + padding_each_side
	
	# Calculate offset needed to move current leftmost point to target
	var center_offset = target_left - row_left
	
	# Apply offset to all buttons in row
	for button in row_buttons:
		button.offset_left += center_offset
		button.offset_right += center_offset
	
	# Apply offset to all outlines in row
	for outline in row_outlines:
		outline.offset_left += center_offset
		outline.offset_right += center_offset

func connect_menu_buttons():
	"""Connect all menu buttons to their respective functions"""
	# Note: Level buttons are now created and connected dynamically in create_level_buttons()
	
	# Connect exit button
	var exit_button = main_menu_node.get_node("ExitButton")
	if exit_button:
		exit_button.pressed.connect(_on_exit_button_pressed)
		connect_button_sounds(exit_button)
	
	# Connect reset data button
	var reset_data_button = main_menu_node.get_node("ResetDataButton")
	if reset_data_button:
		reset_data_button.pressed.connect(_on_reset_data_button_pressed)
		connect_button_sounds(reset_data_button)
		# Hide in non-editor builds (only show when running in Godot editor)
		reset_data_button.visible = OS.has_feature("editor")
	
	# Connect unlock all button
	var unlock_all_button = main_menu_node.get_node("UnlockAllButton")
	if unlock_all_button:
		unlock_all_button.pressed.connect(_on_unlock_all_button_pressed)
		connect_button_sounds(unlock_all_button)
		# Hide in non-editor builds (only show when running in Godot editor)
		unlock_all_button.visible = OS.has_feature("editor")
	
	# Connect drill mode button
	var drill_mode_button = main_menu_node.get_node("DrillModeButton")
	if drill_mode_button:
		drill_mode_button.pressed.connect(_on_drill_mode_button_pressed)
		drill_mode_button.mouse_entered.connect(_on_drill_mode_button_hover_enter)
		drill_mode_button.mouse_exited.connect(_on_drill_mode_button_hover_exit)
		connect_button_sounds(drill_mode_button)
		
		# Initially hide unlock requirements
		var unlock_requirements = drill_mode_button.get_node("UnlockRequirements")
		if unlock_requirements:
			unlock_requirements.visible = false

func _on_level_button_pressed(pack_name: String, pack_level_index: int):
	"""Handle level button press - only respond during MENU state"""
	if current_state != GameState.MENU:
		return
	
	# Set the pack and level based on the button pressed
	current_pack_name = pack_name
	current_pack_level_index = pack_level_index
	
	# Get the track ID from the pack configuration
	var pack_config = level_packs[pack_name]
	current_track = pack_config.levels[pack_level_index]
	
	# Calculate current_level_number for level_configs lookup (still needed for star requirements)
	# We need to find which level this is globally for the level_configs dictionary
	var global_level_num = get_global_level_number(pack_name, pack_level_index)
	current_level_number = global_level_num
	
	start_play_state()

func get_global_level_number(pack_name: String, pack_level_index: int) -> int:
	"""Get the global level number (1-11) for a pack and index"""
	var global_num = 1
	for pack in level_pack_order:
		var pack_config = level_packs[pack]
		if pack == pack_name:
			return global_num + pack_level_index
		else:
			global_num += pack_config.levels.size()
	return 1  # Fallback

func _on_exit_button_pressed():
	# Use PlaycademySdk.runtime.exit() when available, otherwise fall back to quit
	if PlaycademySdk and PlaycademySdk.is_ready():
		PlaycademySdk.runtime.exit()
	else:
		# Fallback to normal quit for non-Playcademy environments
		get_tree().quit() 
	
	get_tree().quit()

func _on_reset_data_button_pressed():
	"""Handle reset data button press - wipe all save data and reset menu UI"""
	if current_state != GameState.MENU:
		return
	
	print("Resetting all save data...")
	
	# Reset save data to default
	save_data = get_default_save_data()
	save_save_data()
	
	# Update menu display with reset data
	update_menu_stars()
	update_level_availability()
	
	print("Save data reset complete!")

func _on_unlock_all_button_pressed():
	"""Handle unlock all button press - unlock all levels with 3 stars (DEV ONLY)"""
	if current_state != GameState.MENU:
		return
	
	print("Unlocking all levels...")
	
	# Set all levels across all packs to have 3 stars and reasonable completion values
	var global_level_num = 1
	for pack_name in level_pack_order:
		var pack_config = level_packs[pack_name]
		
		# Ensure pack exists in save data
		if not save_data.packs.has(pack_name):
			save_data.packs[pack_name] = {"levels": {}}
		
		# Unlock each level in the pack
		for level_index in range(pack_config.levels.size()):
			var level_key = str(level_index)
			var level_config = level_configs.get(global_level_num, level_configs[1])
			
			# Set each level to have 3 stars and max values
			save_data.packs[pack_name].levels[level_key] = {
				"highest_stars": 3,
				"best_accuracy": level_config.problems,  # Perfect accuracy
				"best_time": level_config.star3.time,  # Best time for 3 stars
				"best_cqpm": calculate_cqpm(level_config.problems, level_config.star3.time)
			}
			
			global_level_num += 1
	
	save_save_data()
	
	# Update menu display with unlocked levels
	update_menu_stars()
	update_level_availability()
	update_drill_mode_high_score_display()
	
	print("All levels unlocked!")

func _on_drill_mode_button_pressed():
	"""Handle drill mode button press - start drill mode"""
	if current_state != GameState.MENU:
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

func start_drill_mode():
	"""Transition from MENU to DRILL_PLAY state"""
	current_state = GameState.DRILL_PLAY
	is_drill_mode = true
	problems_completed = 0
	correct_answers = 0
	drill_score = 0
	drill_streak = 0
	drill_total_answered = 0
	drill_score_display_value = 0.0
	drill_score_target_value = 0
	drill_timer_remaining = drill_mode_duration
	
	# Reset celebration state and hide high score text
	is_celebrating_high_score = false
	high_score_flicker_time = 0.0
	if high_score_text_label:
		high_score_text_label.visible = false
	
	# Clean up any existing problem labels before starting
	cleanup_problem_labels()
	
	# Reset answer state
	user_answer = ""
	answer_submitted = false
	
	# Initialize timer variables
	level_start_time = 0.0
	current_level_time = 0.0
	timer_active = false
	timer_started = false
	in_transition_delay = false
	grace_period_timer = 0.0
	
	# First animate menu down off screen (downward)
	var tween = create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_EXPO)
	tween.tween_property(main_menu_node, "position", menu_below_screen, animation_duration)
	
	# After the downward animation completes, teleport to above screen
	tween.tween_callback(func(): main_menu_node.position = menu_above_screen)
	
	# Play node flies in from above
	play_node.position = menu_above_screen
	var play_tween = create_tween()
	play_tween.set_ease(Tween.EASE_OUT)
	play_tween.set_trans(Tween.TRANS_EXPO)
	play_tween.tween_property(play_node, "position", menu_on_screen, animation_duration)
	
	# Trigger scroll speed boost effect
	var space_bg = get_node("BackgroundLayer/SpaceBackground")
	if space_bg and space_bg.has_method("boost_scroll_speed"):
		space_bg.boost_scroll_speed(scroll_boost_multiplier, animation_duration * 2.0)
	
	# Set UI visibility for drill mode
	update_drill_mode_ui_visibility()
	
	# Initialize weighted question system for all tracks
	initialize_question_weights_for_all_tracks()
	
	# Generate question first, then create the problem display
	generate_new_question()
	create_new_problem_label()

func start_play_state():
	"""Transition from MENU to PLAY state"""
	current_state = GameState.PLAY
	is_drill_mode = false
	problems_completed = 0
	correct_answers = 0
	
	# Reset celebration state and hide high score text
	is_celebrating_high_score = false
	high_score_flicker_time = 0.0
	if high_score_text_label:
		high_score_text_label.visible = false
	
	# Clean up any existing problem labels before starting
	cleanup_problem_labels()
	
	# Reset answer state
	user_answer = ""
	answer_submitted = false
	
	# Initialize timer variables
	level_start_time = 0.0
	current_level_time = 0.0
	timer_active = false
	timer_started = false
	in_transition_delay = false
	grace_period_timer = 0.0
	
	# First animate menu down off screen (downward)
	var tween = create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_EXPO)
	tween.tween_property(main_menu_node, "position", menu_below_screen, animation_duration)
	
	# After the downward animation completes, teleport to above screen
	tween.tween_callback(func(): main_menu_node.position = menu_above_screen)
	
	# Play node flies in from above
	play_node.position = menu_above_screen
	var play_tween = create_tween()
	play_tween.set_ease(Tween.EASE_OUT)
	play_tween.set_trans(Tween.TRANS_EXPO)
	play_tween.tween_property(play_node, "position", menu_on_screen, animation_duration)
	
	# Trigger scroll speed boost effect
	var space_bg = get_node("BackgroundLayer/SpaceBackground")
	if space_bg and space_bg.has_method("boost_scroll_speed"):
		space_bg.boost_scroll_speed(scroll_boost_multiplier, animation_duration * 2.0)
	
	# Show play UI labels for normal mode
	if timer_label:
		timer_label.visible = true
	if accuracy_label:
		accuracy_label.visible = true
	
	# Set UI visibility for normal mode
	update_normal_mode_ui_visibility()
	
	# Initialize progress line
	if progress_line:
		progress_line.clear_points()
		progress_line.add_point(Vector2(0, 0))  # Point 0 at (0, 0)
		progress_line.add_point(Vector2(0, 0))  # Point 1 starts at (0, 0)
	
	# Initialize weighted question system for this track
	initialize_question_weights_for_track(current_track)
	
	# Generate question first, then create the problem display
	generate_new_question()
	create_new_problem_label()

func go_to_game_over():
	"""Transition from PLAY to GAME_OVER state"""
	current_state = GameState.GAME_OVER
	
	# Stop the timer (should already be stopped, but ensure it)
	timer_active = false
	
	# Always hide high score text for normal levels
	if high_score_text_label:
		high_score_text_label.visible = false
	
	# Calculate and save level performance data
	var stars_earned = evaluate_stars().size()
	update_level_data(current_pack_name, current_pack_level_index, correct_answers, current_level_time, stars_earned)
	
	# Record progress to Playcademy TimeBack (1 minute = 1 XP)
	if PlaycademySdk and PlaycademySdk.is_ready() and PlaycademySdk.timeback:
		var level_config = level_configs.get(current_level_number, level_configs[1])
		var total_questions = level_config.problems
		
		# Get activity name from track data
		var activity_name = current_pack_name + " - Level " + str(current_pack_level_index + 1)
		var question_data = get_math_question(current_track)
		if question_data and question_data.has("title"):
			activity_name = question_data.title
		
		# Calculate XP: 1 minute = 1 XP
		var xp_earned = int(current_level_time / 60.0)
		
		var progress_data = {
			"score": int((float(correct_answers) / float(total_questions)) * 100),
			"totalQuestions": total_questions,
			"correctQuestions": correct_answers,
			"xpEarned": xp_earned,
			"activityId": "level-" + current_pack_name + "-" + str(current_pack_level_index),
			"activityName": activity_name,
			"stars": stars_earned,
			"timeSeconds": int(current_level_time)
		}
		
		print("[Playcademy] Recording progress: ", progress_data)
		PlaycademySdk.timeback.record_progress(progress_data)
	
	# Update GameOver labels with player performance
	update_game_over_labels()
	
	# Update star requirement labels to show actual level requirements
	update_star_requirement_labels()
	
	# Set normal mode game over UI visibility
	update_normal_mode_game_over_ui_visibility()
	
	# Initialize star states (make all stars invisible, continue button invisible)
	initialize_star_states()
	
	# Clean up any remaining problem labels
	cleanup_problem_labels()
	
	# Play node flies down off screen
	var play_tween = create_tween()
	play_tween.set_ease(Tween.EASE_OUT)
	play_tween.set_trans(Tween.TRANS_EXPO)
	play_tween.tween_property(play_node, "position", menu_below_screen, animation_duration)
	
	# GameOver teleports to above screen, then animates down to center
	game_over_node.position = menu_above_screen
	var tween = create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_EXPO)
	tween.tween_property(game_over_node, "position", menu_on_screen, animation_duration)
	
	# Start star animation sequence after GameOver animation completes
	tween.tween_callback(start_star_animation_sequence)

func return_to_menu():
	"""Transition from GAME_OVER to MENU state"""
	current_state = GameState.MENU
	is_drill_mode = false  # Reset drill mode flag
	drill_score_animation_time = 0.0  # Reset drill score animation
	is_celebrating_high_score = false  # Reset high score celebration
	high_score_flicker_time = 0.0  # Reset flicker animation
	
	# Update menu display with new save data
	update_menu_stars()
	update_level_availability()
	update_drill_mode_high_score_display()
	
	# MainMenu teleports to above screen, then animates down to center
	main_menu_node.position = menu_above_screen
	var menu_tween = create_tween()
	menu_tween.set_ease(Tween.EASE_OUT)
	menu_tween.set_trans(Tween.TRANS_EXPO)
	menu_tween.tween_property(main_menu_node, "position", menu_on_screen, animation_duration)
	
	# At the same time, GameOver moves down to below screen
	var gameover_tween = create_tween()
	gameover_tween.set_ease(Tween.EASE_OUT)
	gameover_tween.set_trans(Tween.TRANS_EXPO)
	gameover_tween.tween_property(game_over_node, "position", menu_below_screen, animation_duration)

func connect_game_over_buttons():
	"""Connect all game over buttons to their respective functions"""
	# Connect continue button
	continue_button = game_over_node.get_node("ContinueButton")
	if continue_button:
		continue_button.pressed.connect(_on_continue_button_pressed)
		connect_button_sounds(continue_button)

func _on_continue_button_pressed():
	"""Handle continue button press - only respond during GAME_OVER state"""
	if current_state != GameState.GAME_OVER:
		return
	
	return_to_menu()

func update_control_guide_visibility():
	"""Update visibility and positions of control guide nodes based on game state"""
	if not control_guide_enter or not control_guide_tab or not control_guide_divide:
		return
	
	# Only update during PLAY or DRILL_PLAY states
	if current_state != GameState.PLAY and current_state != GameState.DRILL_PLAY:
		return
	
	var is_fraction_problem = current_question and is_fraction_display_type(current_question.get("type", ""))
	var has_valid_input = user_answer != "" and user_answer != "-"
	
	# Determine visibility for each control
	var show_enter = true
	var show_tab = false
	var show_divide = false
	
	# Enter visibility: hide if answer is empty/invalid or already submitted
	if user_answer == "" or user_answer == "-" or answer_submitted:
		show_enter = false
	
	# Check for incomplete fraction input
	if is_mixed_fraction_input:
		var parts = user_answer.split(" ")
		if parts.size() != 2:
			show_enter = false
		else:
			var fraction_parts = parts[1].split("/")
			if fraction_parts.size() != 2:
				show_enter = false
			elif editing_numerator:
				# Still editing numerator, can't submit yet
				show_enter = false
			elif fraction_parts[0] == "" or fraction_parts[1] == "":
				# Empty numerator or denominator
				show_enter = false
	elif is_fraction_input and not is_mixed_fraction_input:
		var parts = user_answer.split("/")
		if parts.size() != 2 or parts[1] == "":
			show_enter = false
	
	# Tab (Fraction key) visibility: only for fraction problems with valid input, not already in any fraction mode
	if is_fraction_problem and has_valid_input and not answer_submitted:
		# Only show if not in fraction mode yet (don't show when already in fraction mode, even if editing numerator)
		show_tab = not is_fraction_input and not is_mixed_fraction_input
	
	# Divide visibility: only for fraction problems with valid input, not already in any fraction mode
	if is_fraction_problem and has_valid_input and not answer_submitted:
		# Only show if not in fraction mode yet (don't show when already in fraction mode, even if editing numerator)
		show_divide = not is_fraction_input and not is_mixed_fraction_input
	
	# Update visibility
	control_guide_enter.visible = show_enter
	control_guide_tab.visible = show_tab
	control_guide_divide.visible = show_divide
	
	# Calculate positions from right to left using the constant ordering
	var visible_controls = []
	for control_type in CONTROL_GUIDE_ORDER:
		match control_type:
			ControlGuideType.DIVIDE:
				if show_divide:
					visible_controls.append(control_guide_divide)
			ControlGuideType.TAB:
				if show_tab:
					visible_controls.append(control_guide_tab)
			ControlGuideType.ENTER:
				if show_enter:
					visible_controls.append(control_guide_enter)
	
	# Position controls from right to left, clamping the RIGHT side of the rightmost control to control_guide_max_x
	var current_x = control_guide_max_x
	for i in range(visible_controls.size()):
		var control = visible_controls[i]
		var control_width = control.size.x
		
		# Calculate the left position (current_x is the right edge)
		var target_x = current_x - control_width
		var target_position = Vector2(target_x, control.position.y)
		
		# Animate to target position if different
		if control.position.distance_to(target_position) > 0.1:
			var tween = create_tween()
			tween.set_ease(Tween.EASE_OUT)
			tween.set_trans(Tween.TRANS_EXPO)
			tween.tween_property(control, "position", target_position, control_guide_animation_duration)
		
		# Move current_x left for next control (subtract width + padding)
		current_x = target_x - control_guide_padding

func update_play_ui(delta: float):
	"""Update the Timer and Accuracy labels during gameplay"""
	if is_drill_mode:
		# Update drill mode UI
		if drill_timer_label:
			var display_time = drill_timer_remaining
			if not timer_started:
				display_time = drill_mode_duration  # Show full time during grace period
			
			var minutes = int(display_time / 60)
			var seconds = int(display_time) % 60
			var hundredths = int((display_time - int(display_time)) * 100)
			
			var time_string = "%d:%02d.%02d" % [minutes, seconds, hundredths]
			drill_timer_label.text = time_string
		
		if drill_score_label:
			# Smoothly animate score towards target
			if drill_score_display_value < drill_score_target_value:
				var animation_speed = (drill_score_target_value - drill_score_display_value) * delta * 8.0  # Adjust speed as needed
				drill_score_display_value = min(drill_score_display_value + animation_speed, drill_score_target_value)
			drill_score_label.text = str(int(drill_score_display_value))
	else:
		# Update normal mode UI
		if not timer_label or not accuracy_label:
			return
		
		# Update timer display (mm:ss.ss format)
		var display_time = current_level_time
		if not timer_started:
			display_time = 0.0  # Show 0:00.00 only during initial grace period
		
		var minutes = int(display_time / 60)
		var seconds = int(display_time) % 60
		var hundredths = int((display_time - int(display_time)) * 100)
		
		var time_string = "%d:%02d.%02d" % [minutes, seconds, hundredths]
		timer_label.text = time_string
		
		# Update accuracy display (correct/total format)
		var level_config = level_configs.get(current_level_number, level_configs[1])
		var accuracy_string = "%d/%d" % [correct_answers, level_config.problems]
		accuracy_label.text = accuracy_string

func update_game_over_labels():
	"""Update the GameOver labels with player's final performance"""
	if not player_time_label or not player_accuracy_label:
		return
	
	# Update player time display (mm:ss.ss format - same as in-game timer)
	var minutes = int(current_level_time / 60)
	var seconds = int(current_level_time) % 60
	var hundredths = int((current_level_time - int(current_level_time)) * 100)
	var time_string = "%d:%02d.%02d" % [minutes, seconds, hundredths]
	player_time_label.text = time_string
	
	# Update player accuracy display (correct/total format)
	var level_config = level_configs.get(current_level_number, level_configs[1])
	var accuracy_string = "%d/%d" % [correct_answers, level_config.problems]
	player_accuracy_label.text = accuracy_string
	
	# Update CQPM display
	if cqpm_label:
		var cqpm = calculate_cqpm(correct_answers, current_level_time)
		cqpm_label.text = "%.2f" % cqpm

func update_star_requirement_labels():
	"""Update the star requirement labels to show actual level requirements"""
	var level_config = level_configs.get(current_level_number, level_configs[1])
	
	# Helper function to format time as mm:ss
	var format_time = func(time_seconds: float) -> String:
		var minutes = int(time_seconds / 60)
		var seconds = int(time_seconds) % 60
		return "%2d:%02d" % [minutes, seconds]
	
	# Update Star 1 requirements
	if star1_accuracy_label:
		star1_accuracy_label.text = "%d/%d" % [level_config.star1.accuracy, level_config.problems]
	if star1_time_label:
		star1_time_label.text = format_time.call(level_config.star1.time)
	
	# Update Star 2 requirements
	if star2_accuracy_label:
		star2_accuracy_label.text = "%d/%d" % [level_config.star2.accuracy, level_config.problems]
	if star2_time_label:
		star2_time_label.text = format_time.call(level_config.star2.time)
	
	# Update Star 3 requirements
	if star3_accuracy_label:
		star3_accuracy_label.text = "%d/%d" % [level_config.star3.accuracy, level_config.problems]
	if star3_time_label:
		star3_time_label.text = format_time.call(level_config.star3.time)

func evaluate_stars():
	"""Evaluate which stars the player has earned"""
	var stars_earned = []
	var level_config = level_configs.get(current_level_number, level_configs[1])
	
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

func check_star_requirement(star_num: int, requirement_type: String) -> bool:
	"""Check if a specific requirement for a star has been met"""
	var level_config = level_configs.get(current_level_number, level_configs[1])
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
	star1_accuracy_label.self_modulate.a = 0.0
	star1_time_label.self_modulate.a = 0.0
	star2_accuracy_label.self_modulate.a = 0.0
	star2_time_label.self_modulate.a = 0.0
	star3_accuracy_label.self_modulate.a = 0.0
	star3_time_label.self_modulate.a = 0.0

func start_star_animation_sequence():
	"""Start the sequential star animation after half animation_duration delay"""
	await get_tree().create_timer(animation_duration / 2.0).timeout
	
	# Evaluate which stars were earned
	var stars_earned = evaluate_stars()
	
	# Animate stars in sequence
	animate_star(1, 1 in stars_earned)
	await get_tree().create_timer(star_delay).timeout
	
	animate_star(2, 2 in stars_earned)
	await get_tree().create_timer(star_delay).timeout
	
	animate_star(3, 3 in stars_earned)
	# Show continue button when Star 3 starts animating
	continue_button.visible = true

func animate_star(star_num: int, earned: bool):
	"""Animate a single star based on whether it was earned"""
	var star_node: Control
	var star_sprite: Sprite2D
	var star_accuracy_label: Label
	var star_time_label: Label
	
	# Get references for the specific star
	match star_num:
		1:
			star_node = star1_node
			star_sprite = star1_sprite
			star_accuracy_label = star1_accuracy_label
			star_time_label = star1_time_label
		2:
			star_node = star2_node
			star_sprite = star2_sprite
			star_accuracy_label = star2_accuracy_label
			star_time_label = star2_time_label
		3:
			star_node = star3_node
			star_sprite = star3_sprite
			star_accuracy_label = star3_accuracy_label
			star_time_label = star3_time_label
		_:
			return
	
	# Make star visible
	star_node.visible = true
	
	# Set sprite frame based on earned status
	star_sprite.frame = 1 if earned else 0
	
	# Create sprite animation tween
	var sprite_tween = create_tween()
	sprite_tween.set_ease(Tween.EASE_OUT)
	sprite_tween.set_trans(Tween.TRANS_EXPO)
	
	if earned:
		# Earned star animation: 0 -> 16 -> 8
		sprite_tween.tween_property(star_sprite, "scale", Vector2(star_max_scale, star_max_scale), star_expand_time)
		sprite_tween.tween_property(star_sprite, "scale", Vector2(star_final_scale, star_final_scale), star_shrink_time)
		# Play get sound
		AudioManager.play_get()
	else:
		# Unearned star animation: 0 -> 8
		sprite_tween.tween_property(star_sprite, "scale", Vector2(star_final_scale, star_final_scale), star_shrink_time)
		# Play close sound
		AudioManager.play_close()
	
	# Animate labels (accuracy and time)
	animate_star_labels(star_num, star_accuracy_label, star_time_label)

func animate_star_labels(star_num: int, star_accuracy_label: Label, time_label: Label):
	"""Animate the accuracy and time labels for a star"""
	# Check if individual requirements were met
	var accuracy_met = check_star_requirement(star_num, "accuracy")
	var time_met = check_star_requirement(star_num, "time")
	
	# Set colors based on whether requirements were met
	if accuracy_met:
		star_accuracy_label.self_modulate = Color(0, 0.5, 0, 0)  # Half green, start transparent
	else:
		star_accuracy_label.self_modulate = Color(0.5, 0, 0, 0)  # Half red, start transparent
	
	if time_met:
		time_label.self_modulate = Color(0, 0.5, 0, 0)  # Half green, start transparent
	else:
		time_label.self_modulate = Color(0.5, 0, 0, 0)  # Half red, start transparent
	
	# Create fade-in animations
	var accuracy_tween = create_tween()
	accuracy_tween.set_ease(Tween.EASE_OUT)
	accuracy_tween.set_trans(Tween.TRANS_EXPO)
	accuracy_tween.tween_property(star_accuracy_label, "self_modulate:a", 1.0, label_fade_time)
	
	var time_tween = create_tween()
	time_tween.set_ease(Tween.EASE_OUT)
	time_tween.set_trans(Tween.TRANS_EXPO)
	time_tween.tween_property(time_label, "self_modulate:a", 1.0, label_fade_time)

func cleanup_problem_labels():
	"""Remove any remaining problem labels from the Play node"""
	# Clean up fraction problem nodes
	for node in current_problem_nodes:
		if node:
			node.queue_free()
	current_problem_nodes.clear()
	
	# Clean up regular problem labels
	if play_node:
		for child in play_node.get_children():
			# Only remove dynamically created labels, not the static UI elements
			if (child is Label and 
				child != timer_label and 
				child != accuracy_label and 
				child != drill_timer_label and 
				child != drill_score_label):
				child.queue_free()
	
	current_problem_label = null
	answer_fraction_node = null

# Save System Functions

func start_question_timing():
	"""Start timing the current question"""
	current_question_start_time = Time.get_ticks_msec() / 1000.0  # Convert to seconds with millisecond precision

func initialize_save_system():
	"""Initialize the save system and load existing save data"""
	load_save_data()
	update_drill_mode_high_score_display()
	# Note: update_menu_stars() and update_level_availability() are now called after create_level_buttons()

func connect_volume_sliders():
	"""Connect volume sliders and initialize their values from save data"""
	if sfx_slider:
		# Set slider range (0.0 to 1.0)
		sfx_slider.min_value = 0.0
		sfx_slider.max_value = 1.0
		sfx_slider.step = 0.01
		
		# Load saved volume or use default
		var sfx_volume = save_data.get("sfx_volume", default_sfx_volume)
		sfx_slider.value = sfx_volume
		
		# Apply the volume immediately
		set_sfx_volume(sfx_volume)
		
		# Connect signal
		sfx_slider.value_changed.connect(_on_sfx_volume_changed)
	
	if music_slider:
		# Set slider range (0.0 to 1.0)
		music_slider.min_value = 0.0
		music_slider.max_value = 1.0
		music_slider.step = 0.01
		
		# Load saved volume or use default
		var music_volume = save_data.get("music_volume", default_music_volume)
		music_slider.value = music_volume
		
		# Apply the volume immediately
		set_music_volume(music_volume)
		
		# Connect signal
		music_slider.value_changed.connect(_on_music_volume_changed)

func _on_sfx_volume_changed(value: float):
	"""Handle SFX volume slider change"""
	set_sfx_volume(value)
	save_data.sfx_volume = value
	save_save_data()

func _on_music_volume_changed(value: float):
	"""Handle Music volume slider change"""
	set_music_volume(value)
	save_data.music_volume = value
	save_save_data()

func volume_to_db(volume: float) -> float:
	"""Convert volume (0.0-1.0) to decibels (-48 to 0) using moderately exponential scale"""
	if volume <= 0.0:
		return -80.0  # Effectively muted
	# Use a square root curve: -48 * (1 - sqrt(volume))
	# This creates a balanced exponential curve
	# At 25%: -24dB, At 50%: -14dB, At 75%: -7dB, At 100%: 0dB
	var db = -48.0 * (1.0 - sqrt(volume))
	return db

func set_sfx_volume(volume: float):
	"""Set SFX bus volume"""
	var bus_idx = AudioServer.get_bus_index("SFX")
	if bus_idx >= 0:
		if volume <= 0.0:
			# Mute the bus when slider is at minimum
			AudioServer.set_bus_mute(bus_idx, true)
		else:
			# Unmute and set volume
			AudioServer.set_bus_mute(bus_idx, false)
			var db = volume_to_db(volume)
			AudioServer.set_bus_volume_db(bus_idx, db)

func set_music_volume(volume: float):
	"""Set Music bus volume"""
	var bus_idx = AudioServer.get_bus_index("Music")
	if bus_idx >= 0:
		if volume <= 0.0:
			# Mute the bus when slider is at minimum
			AudioServer.set_bus_mute(bus_idx, true)
		else:
			# Unmute and set volume
			AudioServer.set_bus_mute(bus_idx, false)
			var db = volume_to_db(volume)
			AudioServer.set_bus_volume_db(bus_idx, db)

func get_default_save_data():
	"""Return the default save data structure"""
	var default_data = {
		"version": ProjectSettings.get_setting("application/config/version"),
		"save_structure": "pack_based",  # Identifier for new save structure
		"packs": {},
		"questions": {},
		"sfx_volume": default_sfx_volume,
		"music_volume": default_music_volume
	}
	
	# Initialize level data for all packs
	for pack_name in level_pack_order:
		var pack_config = level_packs[pack_name]
		default_data.packs[pack_name] = {
			"levels": {}
		}
		
		# Initialize each level in the pack
		for level_index in range(pack_config.levels.size()):
			default_data.packs[pack_name].levels[str(level_index)] = {
				"highest_stars": 0,
				"best_accuracy": 0,
				"best_time": 999999.0,
				"best_cqpm": 0.0
			}
	
	return default_data

func load_save_data():
	"""Load save data from file or create default if none exists"""
	if FileAccess.file_exists(save_file_path):
		var file = FileAccess.open(save_file_path, FileAccess.READ)
		if file:
			var json_string = file.get_as_text()
			file.close()
			
			var json = JSON.new()
			var parse_result = json.parse(json_string)
			if parse_result == OK:
				save_data = json.data
				# Run migration if needed
				migrate_save_data()
			else:
				print("Error parsing save data JSON: ", json.get_error_message())
				save_data = get_default_save_data()
		else:
			print("Could not open save file")
			save_data = get_default_save_data()
	else:
		print("No save file found, creating default save data")
		save_data = get_default_save_data()
		save_save_data()

func save_save_data():
	"""Save current save data to file"""
	var file = FileAccess.open(save_file_path, FileAccess.WRITE)
	if file:
		var json_string = JSON.stringify(save_data, "\t")
		file.store_string(json_string)
		file.close()
	else:
		print("Could not save data to file")

func migrate_save_data():
	"""Handle save data migration for version changes"""
	var current_version = ProjectSettings.get_setting("application/config/version")
	var save_version = save_data.get("version", "0.0")
	var save_structure = save_data.get("save_structure", "legacy")
	
	# Check if this is an old save structure - wipe if not pack_based
	if save_structure != "pack_based":
		print("Old save structure detected - wiping all save data for pack-based system")
		save_data = get_default_save_data()
		save_save_data()
		return
	
	# Version migration for pack-based saves
	if save_version != current_version:
		print("Migrating save data from version ", save_version, " to ", current_version)
		
		# Ensure all required fields exist
		if not save_data.has("packs"):
			save_data.packs = {}
		if not save_data.has("questions"):
			save_data.questions = {}
		if not save_data.has("sfx_volume"):
			save_data.sfx_volume = default_sfx_volume
		if not save_data.has("music_volume"):
			save_data.music_volume = default_music_volume
		
		# Ensure all packs and levels have data
		for pack_name in level_pack_order:
			var pack_config = level_packs[pack_name]
			if not save_data.packs.has(pack_name):
				save_data.packs[pack_name] = {"levels": {}}
			
			var pack_data = save_data.packs[pack_name]
			if not pack_data.has("levels"):
				pack_data.levels = {}
			
			# Ensure all levels in pack have data
			for level_index in range(pack_config.levels.size()):
				var level_key = str(level_index)
				if not pack_data.levels.has(level_key):
					pack_data.levels[level_key] = {
						"highest_stars": 0,
						"best_accuracy": 0,
						"best_time": 999999.0,
						"best_cqpm": 0.0
					}
				else:
					# Ensure all fields exist for existing levels
					var level_data = pack_data.levels[level_key]
					if not level_data.has("best_cqpm"):
						level_data.best_cqpm = 0.0
		
		# Update version
		save_data.version = current_version
		save_save_data()

func get_question_key(question_data):
	"""Generate a unique key for a question based on its operands and operator"""
	# Handle fraction questions (operands are arrays) vs regular questions (operands are numbers)
	var op1_str = ""
	var op2_str = ""
	
	# Check if operands exist and are accessible
	if not question_data.has("operands") or question_data.operands == null or question_data.operands.size() < 2:
		# Parse operands from expression (for mixed fraction problems)
		if question_data.has("expression") and question_data.expression != "":
			var expr = question_data.expression.split(" = ")[0]
			var expr_parts = expr.split(" ")
			var operator_idx = -1
			for i in range(expr_parts.size()):
				if expr_parts[i] == question_data.operator:
					operator_idx = i
					break
			
			if operator_idx > 0:
				# Parse operand1
				var operand1_str = ""
				for i in range(operator_idx):
					if operand1_str != "":
						operand1_str += " "
					operand1_str += expr_parts[i]
				op1_str = operand1_str
				
				# Parse operand2
				var operand2_str = ""
				for i in range(operator_idx + 1, expr_parts.size()):
					if operand2_str != "":
						operand2_str += " "
					operand2_str += expr_parts[i]
				op2_str = operand2_str
			else:
				# Fallback - use expression as-is
				op1_str = question_data.get("expression", "unknown")
				op2_str = ""
		else:
			# No expression available - use placeholder
			op1_str = "unknown"
			op2_str = "unknown"
	else:
		# Handle operands individually (could be arrays, numbers, or mixed)
		var operand1 = question_data.operands[0]
		var operand2 = question_data.operands[1]
		
		# Format operand 1
		if typeof(operand1) == TYPE_ARRAY and operand1.size() >= 2:
			# Fraction - format as "num/denom", converting floats to ints
			var num1 = operand1[0]
			var denom1 = operand1[1]
			if typeof(num1) == TYPE_FLOAT:
				num1 = int(num1)
			if typeof(denom1) == TYPE_FLOAT:
				denom1 = int(denom1)
			op1_str = str(num1) + "/" + str(denom1)
		else:
			# Whole number - convert float to int if it's a whole number
			if typeof(operand1) == TYPE_FLOAT:
				op1_str = str(int(operand1))
			else:
				op1_str = str(operand1)
		
		# Format operand 2
		if typeof(operand2) == TYPE_ARRAY and operand2.size() >= 2:
			# Fraction - format as "num/denom", converting floats to ints
			var num2 = operand2[0]
			var denom2 = operand2[1]
			if typeof(num2) == TYPE_FLOAT:
				num2 = int(num2)
			if typeof(denom2) == TYPE_FLOAT:
				denom2 = int(denom2)
			op2_str = str(num2) + "/" + str(denom2)
		else:
			# Whole number - convert float to int if it's a whole number
			if typeof(operand2) == TYPE_FLOAT:
				op2_str = str(int(operand2))
			else:
				op2_str = str(operand2)
	
	return op1_str + "_" + question_data.operator + "_" + op2_str

func save_question_data(question_data, player_answer, time_taken):
	"""Save data for a completed question"""
	var question_key = get_question_key(question_data)
	
	if not save_data.questions.has(question_key):
		save_data.questions[question_key] = []
	
	var question_record = {
		"operands": question_data.get("operands", []),
		"operator": question_data.operator,
		"result": question_data.result,
		"player_answer": player_answer,
		"time_taken": time_taken,
		"timestamp": Time.get_unix_time_from_system()
	}
	
	# Add to the beginning of the array
	save_data.questions[question_key].push_front(question_record)
	
	# Keep only the last 5 answers
	if save_data.questions[question_key].size() > 5:
		save_data.questions[question_key] = save_data.questions[question_key].slice(0, 5)
	
	save_save_data()

func update_level_data(pack_name: String, pack_level_index: int, accuracy: int, time_taken: float, stars_earned: int):
	"""Update the saved data for a level using pack-based structure"""
	# Ensure pack exists
	if not save_data.packs.has(pack_name):
		save_data.packs[pack_name] = {"levels": {}}
	
	var pack_data = save_data.packs[pack_name]
	if not pack_data.has("levels"):
		pack_data.levels = {}
	
	# Ensure level exists
	var level_key = str(pack_level_index)
	if not pack_data.levels.has(level_key):
		pack_data.levels[level_key] = {
			"highest_stars": 0,
			"best_accuracy": 0,
			"best_time": 999999.0,
			"best_cqpm": 0.0
		}
	
	var level_data = pack_data.levels[level_key]
	var updated = false
	
	# Update highest stars
	if stars_earned > level_data.highest_stars:
		level_data.highest_stars = stars_earned
		updated = true
	
	# Update best accuracy
	if accuracy > level_data.best_accuracy:
		level_data.best_accuracy = accuracy
		updated = true
	
	# Update best time
	if time_taken < level_data.best_time:
		level_data.best_time = time_taken
		updated = true
	
	# Calculate and update CQPM (Correct Questions Per Minute)
	var cqpm = 0.0
	if time_taken > 0:
		cqpm = (float(accuracy) / time_taken) * 60.0
	
	if cqpm > level_data.best_cqpm:
		level_data.best_cqpm = cqpm
		updated = true
	
	if updated:
		save_save_data()

func calculate_cqpm(correct_answers_in_level, time_in_seconds):
	"""Calculate Correct Questions Per Minute"""
	if time_in_seconds <= 0:
		return 0.0
	return (float(correct_answers_in_level) / time_in_seconds) * 60.0

func calculate_question_weight(question_data):
	"""Calculate the weight for a single question based on historical data"""
	var question_key = get_question_key(question_data)
	var base_weight = 1.0
	var weight_details = []
	
	# Get historical data for this question
	var question_history = []
	if save_data.questions.has(question_key):
		question_history = save_data.questions[question_key]
	
	var total_answers = question_history.size()
	var incorrect_count = 0
	
	# Count incorrect answers
	for answer_record in question_history:
		if answer_record.player_answer != answer_record.result:
			incorrect_count += 1
	
	# Add weight based on amount of data
	var data_bonus = 0.0
	match total_answers:
		0: data_bonus = 32.0
		1: data_bonus = 8.0
		2: data_bonus = 4.0
		3: data_bonus = 2.0
		4: data_bonus = 1.0
		_: data_bonus = 0.0  # 5 or more answers
	
	if data_bonus > 0:
		weight_details.append("Data bonus (%d answers): +%.1f" % [total_answers, data_bonus])
	
	# Add weight based on incorrect answer count
	var incorrect_bonus = 0.0
	match incorrect_count:
		5: incorrect_bonus = 32.0
		4: incorrect_bonus = 24.0
		3: incorrect_bonus = 16.0
		2: incorrect_bonus = 8.0
		1: incorrect_bonus = 4.0
		_: incorrect_bonus = 0.0
	
	if incorrect_bonus > 0:
		weight_details.append("Incorrect count bonus (%d incorrect): +%.1f" % [incorrect_count, incorrect_bonus])
	
	# Add weight based on individual answer times
	var time_penalty = 0.0
	for answer_record in question_history:
		var is_correct = (answer_record.player_answer == answer_record.result)
		var base_multiplier = 0.5 if is_correct else 2.0
		var time_taken = answer_record.get("time_taken", 0.0)
		var penalty = base_multiplier * time_taken
		time_penalty += penalty
	
	if time_penalty > 0:
		weight_details.append("Time penalties: +%.3f (from individual answers)" % time_penalty)
	
	var final_weight = base_weight + data_bonus + incorrect_bonus + time_penalty
	
	return {
		"weight": final_weight,
		"details": weight_details
	}

func initialize_question_weights_for_track(track):
	"""Initialize question weights for all questions available in the given track"""
	# Clear previous data
	question_weights.clear()
	unavailable_questions.clear()
	available_questions.clear()
	
	# Get all questions for this track (similar logic to get_math_question)
	if not math_facts.has("levels"):
		print("No math facts data available")
		return
	
	# Handle both string track IDs (like "FRAC-07") and numeric track IDs
	var track_key = str(track) if typeof(track) == TYPE_STRING else "TRACK" + str(track)
	var questions = []
	
	# Find questions from specific track
	for level in math_facts.levels:
		if level.id == track_key:
			questions = level.facts
			break
	
	# If track not found, pick random existing track (fallback)
	if questions.is_empty():
		if not math_facts.levels.is_empty():
			var random_level = math_facts.levels[rng.randi() % math_facts.levels.size()]
			questions = random_level.facts
	
	print("=== Question Weight Calculations for Track ", track, " ===")
	
	# Calculate weights for all questions
	for question in questions:
		var question_key = get_question_key(question)
		available_questions.append(question_key)
		
		var weight_result = calculate_question_weight(question)
		question_weights[question_key] = weight_result.weight
		
		# Format question display
		var question_text = ""
		if not question.has("operands") or question.operands == null or question.operands.size() < 2:
			# Mixed fraction or expression-based question
			question_text = question.expression if question.has("expression") else ""
		elif typeof(question.operands[0]) == TYPE_ARRAY:
			# Regular fraction question
			question_text = question.expression if question.has("expression") else ""
		else:
			# Regular question with numeric operands
			var operand1 = question.operands[0]
			var operand2 = question.operands[1]
			if typeof(operand1) == TYPE_FLOAT and operand1 == int(operand1):
				operand1 = int(operand1)
			if typeof(operand2) == TYPE_FLOAT and operand2 == int(operand2):
				operand2 = int(operand2)
			question_text = str(operand1) + " " + question.operator + " " + str(operand2) + " = " + str(question.result)
		
		print("Question: ", question_text)
		print("- Base weight: 1.0")
		for detail in weight_result.details:
			print("- ", detail)
		print("- Final weight: %.3f" % weight_result.weight)
		print("")
	
	print("Total questions available: ", available_questions.size())
	print("==========================================")
	print("")

func get_weighted_random_question():
	"""Select a random question using weighted selection, avoiding unavailable questions"""
	# Filter out unavailable questions
	var selectable_questions = []
	var selectable_weights = []
	
	for question_key in available_questions:
		if question_key not in unavailable_questions:
			selectable_questions.append(question_key)
			selectable_weights.append(question_weights[question_key])
	
	# If no questions available, reset unavailable list and try again
	if selectable_questions.is_empty():
		print("No more available questions, resetting unavailable list")
		unavailable_questions.clear()
		for question_key in available_questions:
			selectable_questions.append(question_key)
			selectable_weights.append(question_weights[question_key])
	
	if selectable_questions.is_empty():
		print("Error: No questions available at all")
		return null
	
	# Calculate total weight
	var total_weight = 0.0
	for weight in selectable_weights:
		total_weight += weight
	
	# Generate random number between 0 and total_weight
	var random_value = rng.randf() * total_weight
	
	# Find the selected question
	var cumulative_weight = 0.0
	for i in range(selectable_questions.size()):
		cumulative_weight += selectable_weights[i]
		if random_value <= cumulative_weight:
			var selected_key = selectable_questions[i]
			var selected_weight = selectable_weights[i]
			
			# Add to unavailable list
			unavailable_questions.append(selected_key)
			
			# Find the actual question data from math_facts
			var selected_question = find_question_by_key(selected_key)
			if selected_question:
				# Console output for question selection
				var question_text = ""
				var display_text = ""
				
				# Check if operands exist and determine question type
				if not selected_question.has("operands") or selected_question.operands == null or selected_question.operands.size() < 2:
					# Mixed fraction or expression-based question
					question_text = selected_question.expression if selected_question.has("expression") else ""
					display_text = question_text.split(" = ")[0] if question_text else ""
				elif typeof(selected_question.operands[0]) == TYPE_ARRAY or typeof(selected_question.operands[1]) == TYPE_ARRAY:
					# Regular fraction question - use expression, or construct from operands if needed
					if selected_question.has("expression") and selected_question.expression != "" and not selected_question.expression.contains("["):
						# Expression exists and doesn't contain malformed array notation
						question_text = selected_question.expression
						display_text = question_text.split(" = ")[0]
					else:
						# Fallback: construct from operands
						var op1 = selected_question.operands[0]
						var op2 = selected_question.operands[1]
						var op1_str = ""
						var op2_str = ""
						
						# Format operand 1
						if typeof(op1) == TYPE_ARRAY and op1.size() >= 2:
							op1_str = str(int(op1[0])) + "/" + str(int(op1[1]))
						else:
							op1_str = str(int(op1) if typeof(op1) == TYPE_FLOAT else op1)
						
						# Format operand 2
						if typeof(op2) == TYPE_ARRAY and op2.size() >= 2:
							op2_str = str(int(op2[0])) + "/" + str(int(op2[1]))
						else:
							op2_str = str(int(op2) if typeof(op2) == TYPE_FLOAT else op2)
						
						display_text = op1_str + " " + selected_question.operator + " " + op2_str
						question_text = display_text + " = " + str(selected_question.result)
				else:
					# Regular question with numeric operands - format integers
					var operand1 = selected_question.operands[0]
					var operand2 = selected_question.operands[1]
					if typeof(operand1) == TYPE_FLOAT and operand1 == int(operand1):
						operand1 = int(operand1)
					if typeof(operand2) == TYPE_FLOAT and operand2 == int(operand2):
						operand2 = int(operand2)
					question_text = str(operand1) + " " + selected_question.operator + " " + str(operand2) + " = " + str(selected_question.result)
					display_text = str(operand1) + " " + selected_question.operator + " " + str(operand2)
				
				print("Selected question: ", question_text, " (weight: %.3f)" % selected_weight)
				
				return {
					"operands": selected_question.get("operands", []),
					"operator": selected_question.operator,
					"result": selected_question.result,
					"expression": selected_question.get("expression", ""),
					"question": display_text,
					"title": "",  # Will be filled by caller if needed
					"grade": "",  # Will be filled by caller if needed
					"type": selected_question.get("type", "")  # Include type if it exists (default to empty string)
				}
			else:
				print("Error: Could not find question data for key: ", selected_key)
				return null
	
	# Fallback (should never reach here)
	print("Error: Weighted selection failed")
	return null

func find_question_by_key(question_key):
	"""Find a question in math_facts by its key"""
	var parts = question_key.split("_")
	if parts.size() != 3:
		return null
	
	var operator = parts[1]
	
	# Check what types of operands we have
	var op1_is_fraction = parts[0].contains("/")
	var op2_is_fraction = parts[2].contains("/")
	
	# Search through all levels
	for level in math_facts.levels:
		for question in level.facts:
			if question.operator != operator:
				continue
			
			var operands_match = false
			
			# Check if question has operands array or uses expression format
			if not question.has("operands") or typeof(question.operands) != TYPE_ARRAY or question.operands.size() < 2:
				# Mixed fraction or expression-based question - match by reconstructing key from expression
				if question.has("expression") and question.expression != "":
					var reconstructed_key = get_question_key(question)
					if reconstructed_key == question_key:
						return question
				continue
			
			# Handle mixed operand types (whole number and fraction)
			var q_op1 = question.operands[0]
			var q_op2 = question.operands[1]
			var q_op1_is_array = typeof(q_op1) == TYPE_ARRAY
			var q_op2_is_array = typeof(q_op2) == TYPE_ARRAY
			
			# Check operand 1
			var op1_match = false
			if op1_is_fraction:
				# Key has fraction format
				var op1_parts = parts[0].split("/")
				if op1_parts.size() == 2 and q_op1_is_array and q_op1.size() >= 2:
					op1_match = (q_op1[0] == float(op1_parts[0]) and q_op1[1] == float(op1_parts[1]))
			else:
				# Key has whole number format
				var operand1 = float(parts[0])
				if not q_op1_is_array:
					op1_match = (q_op1 == operand1)
			
			# Check operand 2
			var op2_match = false
			if op2_is_fraction:
				# Key has fraction format
				var op2_parts = parts[2].split("/")
				if op2_parts.size() == 2 and q_op2_is_array and q_op2.size() >= 2:
					op2_match = (q_op2[0] == float(op2_parts[0]) and q_op2[1] == float(op2_parts[1]))
			else:
				# Key has whole number format
				var operand2 = float(parts[2])
				if not q_op2_is_array:
					op2_match = (q_op2 == operand2)
			
			operands_match = (op1_match and op2_match)
			
			if operands_match:
				return question
	
	return null

func update_menu_stars():
	"""Update the star display on menu level buttons based on save data"""
	for button_data in level_buttons:
		var button = button_data.button
		var pack_name = button_data.pack_name
		var pack_level_index = button_data.pack_level_index
		
		# Get save data for this level
		var stars_earned = 0
		if save_data.packs.has(pack_name):
			var pack_data = save_data.packs[pack_name]
			if pack_data.has("levels"):
				var level_key = str(pack_level_index)
				if pack_data.levels.has(level_key):
					stars_earned = pack_data.levels[level_key].highest_stars
		
		# Update star sprites
		var contents = button.get_node("Contents")
		if contents:
			for star_num in range(1, 4):
				var star_sprite = contents.get_node("Star" + str(star_num))
				if star_sprite:
					star_sprite.frame = 1 if star_num <= stars_earned else 0

func calculate_question_difficulty(question_data):
	"""Calculate the difficulty of a question based on its track"""
	# Find which track this question belongs to
	for level in math_facts.levels:
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
				for pack_name in level_pack_order:
					var pack_config = level_packs[pack_name]
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

func update_drill_mode_ui_visibility():
	"""Set UI visibility for drill mode"""
	if timer_label:
		timer_label.visible = false
	if accuracy_label:
		accuracy_label.visible = false
	if progress_line:
		progress_line.visible = false
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
	if drill_timer_label:
		drill_timer_label.visible = false
	if drill_score_label:
		drill_score_label.visible = false

func initialize_question_weights_for_all_tracks():
	"""Initialize question weights for all questions from all tracks in all level packs"""
	# Clear previous data
	question_weights.clear()
	unavailable_questions.clear()
	available_questions.clear()
	
	print("=== Question Weight Calculations for Drill Mode (First 4 Packs, Standard Problems Only) ===")
	
	# Get questions from only the first 4 level packs (excluding Fractions)
	var drill_mode_packs = ["Addition", "Subtraction", "Multiplication", "Division"]
	
	for pack_name in drill_mode_packs:
		var pack_config = level_packs[pack_name]
		for track in pack_config.levels:
			var track_key = str(track) if typeof(track) == TYPE_STRING else "TRACK" + str(track)
			var questions = []
			
			# Find questions from this track
			for level in math_facts.levels:
				if level.id == track_key:
					questions = level.facts
					break
			
			print("Processing Track ", track, " from pack ", pack_name, " (", questions.size(), " questions)")
			
			# Calculate weights for standard (non-fraction) questions in this track
			var standard_count = 0
			for question in questions:
				# Skip fraction-type questions
				var question_type = question.get("type", "")
				if is_fraction_display_type(question_type):
					continue
				
				standard_count += 1
				var question_key = get_question_key(question)
				available_questions.append(question_key)
				
				var weight_result = calculate_question_weight(question)
				question_weights[question_key] = weight_result.weight
				
				# Format question display for debug
				var question_text = ""
				if not question.has("operands") or question.operands == null or question.operands.size() < 2:
					# Mixed fraction or expression-based question
					question_text = question.expression if question.has("expression") else ""
				elif typeof(question.operands[0]) == TYPE_ARRAY:
					# Regular fraction question
					question_text = question.expression if question.has("expression") else ""
				else:
					# Regular question with numeric operands
					var operand1 = question.operands[0]
					var operand2 = question.operands[1]
					if typeof(operand1) == TYPE_FLOAT and operand1 == int(operand1):
						operand1 = int(operand1)
					if typeof(operand2) == TYPE_FLOAT and operand2 == int(operand2):
						operand2 = int(operand2)
					question_text = str(operand1) + " " + question.operator + " " + str(operand2) + " = " + str(question.result)
				
				print("  Question: ", question_text, " (weight: %.3f)" % weight_result.weight)
			
			print("  Standard questions in this track: ", standard_count)
	
	print("Total questions available for drill mode: ", available_questions.size())
	print("==========================================")

func go_to_drill_mode_game_over():
	"""Transition from DRILL_PLAY to GAME_OVER state"""
	current_state = GameState.GAME_OVER
	
	# Stop the timer
	timer_active = false
	
	# Initially hide high score text (will be shown by celebration if new high score)
	if high_score_text_label:
		high_score_text_label.visible = false
	
	# Update drill mode high score if needed (this may trigger celebration)
	update_drill_mode_high_score()
	
	# Update GameOver labels with drill mode performance
	update_drill_mode_game_over_labels()
	
	# Record drill mode progress to Playcademy TimeBack (1 minute = 1 XP)
	if PlaycademySdk and PlaycademySdk.is_ready() and PlaycademySdk.timeback:
		# Calculate XP: 1 minute = 1 XP
		var xp_earned = int(current_level_time / 60.0)
		
		var progress_data = {
			"score": drill_score,
			"totalQuestions": drill_total_answered,
			"correctQuestions": correct_answers,
			"xpEarned": xp_earned,
			"activityId": "drill-mode",
			"activityName": "Drill Mode",
			"timeSeconds": int(current_level_time),
			"mode": "drill"
		}
		
		print("[Playcademy] Recording drill mode progress: ", progress_data)
		PlaycademySdk.timeback.record_progress(progress_data)
	
	# Set drill mode game over UI visibility
	update_drill_mode_game_over_ui_visibility()
	
	# Clean up any remaining problem labels
	cleanup_problem_labels()
	
	# Play node flies down off screen
	var play_tween = create_tween()
	play_tween.set_ease(Tween.EASE_OUT)
	play_tween.set_trans(Tween.TRANS_EXPO)
	play_tween.tween_property(play_node, "position", menu_below_screen, animation_duration)
	
	# GameOver teleports to above screen, then animates down to center
	game_over_node.position = menu_above_screen
	var tween = create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_EXPO)
	tween.tween_property(game_over_node, "position", menu_on_screen, animation_duration)
	
	# Show continue button immediately for drill mode (no star animation)
	continue_button.visible = true

func update_drill_mode_high_score():
	"""Update drill mode high score in save data and trigger celebration if new high score"""
	if not save_data.has("drill_mode"):
		save_data.drill_mode = {"high_score": 0}
	
	var is_new_high_score = drill_score > save_data.drill_mode.high_score
	
	if is_new_high_score:
		save_data.drill_mode.high_score = drill_score
		save_save_data()
		print("New drill mode high score: ", drill_score)
		
		# Trigger high score celebration
		start_high_score_celebration()
	
	# Always attempt to submit score to Playcademy (not just on new high scores)
	attempt_playcademy_auto_submit()
	
	return is_new_high_score

func start_high_score_celebration():
	"""Start the high score celebration animation"""
	if not high_score_text_label:
		return
	
	# Wait for animation_duration before showing the celebration
	await get_tree().create_timer(animation_duration).timeout
	
	# Make the label visible and start celebration
	high_score_text_label.visible = true
	is_celebrating_high_score = true
	high_score_flicker_time = 0.0
	
	# Set pivot to center for scaling animation
	high_score_text_label.pivot_offset = high_score_text_label.size / 2.0
	
	# Play the Get sound effect
	AudioManager.play_get()
	
	# Create the pop animation
	var pop_tween = create_tween()
	pop_tween.set_ease(Tween.EASE_OUT)
	pop_tween.set_trans(Tween.TRANS_EXPO)
	
	# Phase 1: Expand to large scale
	pop_tween.tween_property(high_score_text_label, "scale", Vector2(high_score_pop_scale, high_score_pop_scale), high_score_expand_duration)
	
	# Phase 2: Shrink back to normal
	pop_tween.tween_property(high_score_text_label, "scale", Vector2(1.0, 1.0), high_score_shrink_duration)

func update_drill_mode_game_over_labels():
	"""Update GameOver labels for drill mode"""
	# Update LevelComplete text
	var level_complete_label = game_over_node.get_node("LevelComplete")
	if level_complete_label:
		level_complete_label.text = "YOUR SCORE"
	
	# Update drill mode score display
	if drill_mode_score_label:
		drill_mode_score_label.text = str(int(drill_score))
	
	# Update drill mode accuracy display
	if drill_accuracy_label:
		var accuracy_string = "%d/%d" % [correct_answers, drill_total_answered]
		drill_accuracy_label.text = accuracy_string
	
	# Update CQPM display for drill mode
	if cqpm_label:
		# Calculate drill mode CQPM: correct answers divided by total drill time
		# Subtract time spent on the last unanswered question (if any)
		var drill_time_used = drill_mode_duration
		if current_question_start_time > 0:
			# Subtract time spent on current unanswered question
			var time_on_current_question = (Time.get_ticks_msec() / 1000.0) - current_question_start_time
			drill_time_used -= time_on_current_question
		
		var cqpm = calculate_cqpm(correct_answers, drill_time_used)
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
	
	var drill_accuracy_title = game_over_node.get_node("DrillAccuracyTitle")
	if drill_accuracy_title:
		drill_accuracy_title.visible = true
	
	if drill_accuracy_label:
		drill_accuracy_label.visible = true
	
	# HighScoreText visibility is handled by the celebration system, not here
	
	# Hide all other nodes
	var nodes_to_hide = ["CorrectTitle", "TimeTitle", "You", "PlayerAccuracy", "PlayerTime", "Star1", "Star2", "Star3"]
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
	
	var nodes_to_show = ["CorrectTitle", "TimeTitle", "You", "PlayerAccuracy", "PlayerTime", "Star1", "Star2", "Star3", "CQPMTitle", "CQPMTooltip"]
	for node_name in nodes_to_show:
		var node = game_over_node.get_node(node_name)
		if node:
			node.visible = true
	
	if cqpm_label:
		cqpm_label.visible = true
	
	# Hide drill mode elements
	if drill_mode_score_label:
		drill_mode_score_label.visible = false
	
	var drill_accuracy_title = game_over_node.get_node("DrillAccuracyTitle")
	if drill_accuracy_title:
		drill_accuracy_title.visible = false
	
	if drill_accuracy_label:
		drill_accuracy_label.visible = false
	
	# Always hide high score text in normal mode
	if high_score_text_label:
		high_score_text_label.visible = false

func update_drill_mode_high_score_display():
	"""Update the drill mode high score display in the main menu"""
	var high_score_label = main_menu_node.get_node("DrillModeButton/HighScore")
	if high_score_label:
		var high_score = 0
		if save_data.has("drill_mode") and save_data.drill_mode.has("high_score"):
			high_score = save_data.drill_mode.high_score
		high_score_label.text = str(int(high_score))  # Ensure integer display

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
	var move_tween = create_tween()
	var fade_tween = create_tween()
	
	move_tween.set_ease(Tween.EASE_OUT)
	move_tween.set_trans(Tween.TRANS_EXPO)
	fade_tween.set_ease(Tween.EASE_OUT)
	fade_tween.set_trans(Tween.TRANS_EXPO)
	
	# Move down and fade out simultaneously over the same duration
	var target_position = flying_label.position + Vector2(0, flying_score_move_distance)
	move_tween.tween_property(flying_label, "position", target_position, flying_score_move_duration)
	fade_tween.tween_property(flying_label, "self_modulate:a", 0.0, flying_score_move_duration)
	
	# Clean up after animation completes
	fade_tween.tween_callback(flying_label.queue_free)

func animate_drill_score_scale():
	"""Animate the drill score label scaling up and back down"""
	if not drill_score_label:
		return
	
	# Create scale animation tween
	var scale_tween = create_tween()
	scale_tween.set_ease(Tween.EASE_OUT)
	scale_tween.set_trans(Tween.TRANS_EXPO)
	
	# Phase 1: Expand to larger scale
	scale_tween.tween_property(drill_score_label, "scale", Vector2(drill_score_expand_scale, drill_score_expand_scale), drill_score_expand_duration)
	
	# Phase 2: Shrink back to normal
	scale_tween.tween_property(drill_score_label, "scale", Vector2(1.0, 1.0), drill_score_shrink_duration)

func update_level_availability():
	"""Update level button availability based on pack-based progression"""
	for button_data in level_buttons:
		var button = button_data.button
		var pack_name = button_data.pack_name
		var pack_level_index = button_data.pack_level_index
		
		var should_be_available = true
		
		# First level of each pack is always available
		if pack_level_index > 0:
			# Check if previous level in this pack has at least 1 star
			var prev_level_key = str(pack_level_index - 1)
			if save_data.packs.has(pack_name) and save_data.packs[pack_name].has("levels"):
				if save_data.packs[pack_name].levels.has(prev_level_key):
					var prev_stars = save_data.packs[pack_name].levels[prev_level_key].highest_stars
					should_be_available = prev_stars > 0
				else:
					should_be_available = false
			else:
				should_be_available = false
		
		# Set button state
		button.disabled = not should_be_available
		
		# Update visual state
		var contents = button.get_node("Contents")
		if contents:
			if should_be_available:
				contents.modulate = Color(1, 1, 1, 1)  # Fully opaque
			else:
				contents.modulate = Color(1, 1, 1, 0.5)  # Half transparent
	
	# Update drill mode button availability
	update_drill_mode_availability()

func update_drill_mode_availability():
	"""Update drill mode button availability based on level completion across all packs"""
	var drill_mode_button = main_menu_node.get_node("DrillModeButton")
	if not drill_mode_button:
		return
	
	# Check if all levels across all packs have at least 1 star
	var all_levels_completed = true
	for pack_name in level_pack_order:
		var pack_config = level_packs[pack_name]
		if not save_data.packs.has(pack_name):
			all_levels_completed = false
			break
		
		var pack_data = save_data.packs[pack_name]
		if not pack_data.has("levels"):
			all_levels_completed = false
			break
		
		# Check each level in the pack
		for level_index in range(pack_config.levels.size()):
			var level_key = str(level_index)
			if not pack_data.levels.has(level_key):
				all_levels_completed = false
				break
			var stars = pack_data.levels[level_key].highest_stars
			if stars < 1:
				all_levels_completed = false
				break
		
		if not all_levels_completed:
			break
	
	# Set button state
	drill_mode_button.disabled = not all_levels_completed
	
	# Update visual state
	if all_levels_completed:
		drill_mode_button.modulate = Color(1, 1, 1, 1)  # Fully opaque
	else:
		drill_mode_button.modulate = Color(1, 1, 1, 0.5)  # Half transparent
	
	# Hide unlock requirements when drill mode becomes available
	var unlock_requirements = drill_mode_button.get_node("UnlockRequirements")
	if unlock_requirements:
		if all_levels_completed:
			unlock_requirements.visible = false

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
	if drill_score <= 0:
		return
	
	if (typeof(PlaycademySdk) != TYPE_NIL) and PlaycademySdk and PlaycademySdk.is_ready() and PlaycademySdk.scores:
		# Submit without blocking; ignore result (signals still wired for logging)
		print("Submitting drill mode score to Playcademy: ", drill_score)
		PlaycademySdk.scores.submit(drill_score, {})

func create_fraction(fraction_position: Vector2, numerator: int = 1, denominator: int = 1, parent: Node = null) -> Control:
	"""Create a fraction instance at the given position with the specified numerator and denominator"""
	# Load the fraction scene
	var fraction_scene = load("res://scenes/fraction.tscn")
	var fraction_instance = fraction_scene.instantiate()
	
	# Set the position
	fraction_instance.position = fraction_position
	
	# Add to the specified parent, or to self if no parent specified
	if parent == null:
		add_child(fraction_instance)
	else:
		parent.add_child(fraction_instance)
	
	# Set the fraction values (this will trigger automatic resizing)
	fraction_instance.set_fraction(numerator, denominator)
	
	# Make sure it's visible and has default white color
	fraction_instance.visible = true
	fraction_instance.modulate = Color(1, 1, 1)
	
	# Return the instance for further manipulation if needed
	return fraction_instance

func parse_mixed_fraction_from_string(frac_str: String) -> Array:
	"""Parse a mixed fraction string like '4 1/6' into [whole, numerator, denominator]
	Or parse a regular fraction like '1/6' into [0, numerator, denominator]"""
	var parts = frac_str.strip_edges().split(" ")
	
	if parts.size() == 2:
		# Mixed fraction: "4 1/6"
		var whole = int(parts[0])
		var frac_parts = parts[1].split("/")
		if frac_parts.size() == 2:
			return [whole, int(frac_parts[0]), int(frac_parts[1])]
	elif parts.size() == 1:
		# Could be a regular fraction "1/6" or whole number "4"
		if parts[0].contains("/"):
			var frac_parts = parts[0].split("/")
			if frac_parts.size() == 2:
				return [0, int(frac_parts[0]), int(frac_parts[1])]
		else:
			# Just a whole number
			return [int(parts[0]), 0, 1]
	
	# Default fallback
	return [0, 0, 1]

func create_fraction_problem():
	"""Create a fraction-type problem display with fractions, operator, equals sign, and answer area"""
	if not current_question or not is_fraction_display_type(current_question.get("type", "")):
		return
	
	# Clean up any existing problem nodes
	cleanup_problem_labels()
	
	# Parse operands from the question
	# For mixed fraction problems, operands may not be in array format, so parse from expression
	var operand1_data = null
	var operand2_data = null
	
	# First check if operands array exists and has valid data
	var has_valid_operands = (current_question.has("operands") and 
							   current_question.operands != null and 
							   current_question.operands.size() >= 2 and
							   current_question.operands[0] != null)
	
	if has_valid_operands:
		var operand1 = current_question.operands[0]
		var operand2 = current_question.operands[1]
		
		# Handle each operand individually (could be array or number)
		if typeof(operand1) == TYPE_ARRAY and operand1.size() >= 2:
			# Fraction format [num, denom]
			operand1_data = [0, int(operand1[0]), int(operand1[1])]
		elif typeof(operand1) == TYPE_FLOAT or typeof(operand1) == TYPE_INT:
			# Whole number - display as numerator with denominator 1 (will show as "6/1")
			operand1_data = [0, int(operand1), 1]
		
		if typeof(operand2) == TYPE_ARRAY and operand2.size() >= 2:
			# Fraction format [num, denom]
			operand2_data = [0, int(operand2[0]), int(operand2[1])]
		elif typeof(operand2) == TYPE_FLOAT or typeof(operand2) == TYPE_INT:
			# Whole number - display as numerator with denominator 1 (will show as "6/1")
			operand2_data = [0, int(operand2), 1]
	
	# If we don't have valid operands, parse from expression (for mixed fractions)
	if operand1_data == null or operand2_data == null:
		var expr = current_question.get("expression", "")
		if expr != "":
			var expr_parts = expr.split(" = ")[0].split(" ")
			# Find operator position
			var operator_idx = -1
			for i in range(expr_parts.size()):
				if expr_parts[i] == current_question.operator:
					operator_idx = i
					break
			
			if operator_idx > 0:
				# Parse operand1 (everything before operator)
				var operand1_str = ""
				for i in range(operator_idx):
					if operand1_str != "":
						operand1_str += " "
					operand1_str += expr_parts[i]
				operand1_data = parse_mixed_fraction_from_string(operand1_str)
				
				# Parse operand2 (everything after operator)
				var operand2_str = ""
				for i in range(operator_idx + 1, expr_parts.size()):
					if operand2_str != "":
						operand2_str += " "
					operand2_str += expr_parts[i]
				operand2_data = parse_mixed_fraction_from_string(operand2_str)
	
	if operand1_data == null or operand2_data == null:
		print("Error: Could not parse fraction operands")
		return
	
	# Calculate horizontal positions for the final layout
	# Start with offset from primary position to center the whole expression
	var base_x = primary_position.x + fraction_problem_x_offset
	var target_y = primary_position.y
	var start_y = off_screen_bottom.y  # Start off-screen at bottom
	
	# Create fractions temporarily to measure their widths
	# operand_data format: [whole, numerator, denominator]
	var fraction1 = create_fraction(Vector2(0, 0), operand1_data[1], operand1_data[2], play_node)
	if operand1_data[0] > 0:
		fraction1.set_mixed_fraction(operand1_data[0], operand1_data[1], operand1_data[2])
	
	var fraction2 = create_fraction(Vector2(0, 0), operand2_data[1], operand2_data[2], play_node)
	if operand2_data[0] > 0:
		fraction2.set_mixed_fraction(operand2_data[0], operand2_data[1], operand2_data[2])
	
	# Get the actual widths of the fractions (use total width for mixed fractions)
	var fraction1_width = fraction1.current_total_width if fraction1.is_mixed_fraction else fraction1.current_divisor_width
	var fraction2_width = fraction2.current_total_width if fraction2.is_mixed_fraction else fraction2.current_divisor_width
	var fraction1_half_width = fraction1_width / 2.0
	var fraction2_half_width = fraction2_width / 2.0
	
	# Position the equals sign at a fixed location relative to base_x
	# This ensures the equals sign is always in the same position
	var equals_x = base_x + 672.0  # Fixed position for equals sign (adjust as needed)
	
	# Work backwards from equals sign to position fraction2
	# Each fraction takes up: fraction_element_spacing + its half width on each side
	var fraction2_x = equals_x - fraction_element_spacing - fraction2_half_width
	
	# Position operator between fraction2 and fraction1
	var operator_x = fraction2_x - fraction2_half_width - fraction_element_spacing
	
	# Position fraction1
	var fraction1_x = operator_x - fraction_element_spacing - fraction1_half_width
	
	# Position answer area after equals sign
	var answer_x = equals_x + fraction_element_spacing + fraction_answer_offset
	var answer_number_x = answer_x + fraction_answer_number_offset  # Position for non-fractionalized answer
	
	# Check if problem extends too far left and adjust if necessary
	var leftmost_x = fraction1_x - fraction1_half_width
	if leftmost_x < fraction_problem_min_x:
		var x_offset = fraction_problem_min_x - leftmost_x
		# Shift all x positions rightward
		fraction1_x += x_offset
		operator_x += x_offset
		fraction2_x += x_offset
		equals_x += x_offset
		answer_x += x_offset
		answer_number_x += x_offset
	
	# Now position all the fractions at their calculated positions (off-screen initially)
	fraction1.position = Vector2(fraction1_x, start_y) + fraction_offset
	fraction2.position = Vector2(fraction2_x, start_y) + fraction_offset
	fraction1.z_index = -1  # Render behind UI elements
	fraction2.z_index = -1  # Render behind UI elements
	current_problem_nodes.append(fraction1)
	current_problem_nodes.append(fraction2)
	
	# Create operator label (+, -, etc.) - child of first fraction so it moves with it
	var operator_label = Label.new()
	operator_label.label_settings = label_settings_resource
	operator_label.text = get_display_operator(current_question.operator)
	operator_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	operator_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	operator_label.self_modulate = Color(1, 1, 1)
	operator_label.z_index = -1  # Render behind UI elements
	# Position relative to fraction1
	var op_offset = operator_offset
	# Apply simple operator offset for converted unicode operators
	if current_question.operator == "×" or current_question.operator == "÷":
		op_offset += simple_operator_offset
	operator_label.position = Vector2(operator_x - fraction1_x, 0) + op_offset - fraction_offset
	fraction1.add_child(operator_label)
	current_problem_nodes.append(operator_label)
	
	# Create equals label - child of second fraction so it moves with it
	var equals_label = Label.new()
	equals_label.label_settings = label_settings_resource
	equals_label.text = "="
	equals_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	equals_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	equals_label.self_modulate = Color(1, 1, 1)
	equals_label.z_index = -1  # Render behind UI elements
	# Position relative to fraction2
	equals_label.position = Vector2(equals_x - fraction2_x, 0) + operator_offset - fraction_offset
	fraction2.add_child(equals_label)
	current_problem_nodes.append(equals_label)
	
	# Create answer label (will show underscore or typed number before fraction mode)
	current_problem_label = Label.new()
	current_problem_label.label_settings = label_settings_resource
	current_problem_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	current_problem_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	current_problem_label.position = Vector2(answer_number_x, start_y) + operator_offset  # Use number position
	current_problem_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	current_problem_label.self_modulate = Color(1, 1, 1)
	current_problem_label.z_index = -1  # Render behind UI elements
	play_node.add_child(current_problem_label)
	current_problem_nodes.append(current_problem_label)
	
	# Calculate target positions
	var fraction1_target = Vector2(fraction1_x, target_y) + fraction_offset
	var fraction2_target = Vector2(fraction2_x, target_y) + fraction_offset
	var answer_target = Vector2(answer_number_x, target_y) + operator_offset  # Use number position
	
	# Animate all elements to their target positions
	# Note: operator_label and equals_label are children of fractions, so they move automatically
	var tween = create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_EXPO)
	tween.set_parallel(true)  # Animate all elements simultaneously
	tween.tween_property(fraction1, "position", fraction1_target, animation_duration)
	tween.tween_property(fraction2, "position", fraction2_target, animation_duration)
	tween.tween_property(current_problem_label, "position", answer_target, animation_duration)
	
	# Exit parallel mode before adding callback so it runs AFTER animations complete
	tween.set_parallel(false)
	
	# Start timing this question when animation completes
	tween.tween_callback(start_question_timing)
	
	# Note: answer_fraction_node will be created when user presses Divide

func create_answer_fraction():
	"""Create just the answer fraction visual when user presses Divide"""
	if answer_fraction_node:
		return  # Already exists
	
	# Use the position of the current_problem_label (the answer label) but apply fraction_offset
	var base_pos = current_problem_label.position if current_problem_label else primary_position
	# Subtract operator_offset and add fraction_offset to align with other fractions
	# Also subtract the number offset since we want the fraction at the normal fraction position
	var answer_pos = base_pos - operator_offset + fraction_offset - Vector2(fraction_answer_number_offset, 0)
	
	# Create the answer fraction at the aligned position
	answer_fraction_node = create_fraction(answer_pos, 0, 1, play_node)
	answer_fraction_node.set_input_mode(true)
	answer_fraction_node.z_index = -1  # Render behind UI elements
	current_problem_nodes.append(answer_fraction_node)
	
	# Store initial position and width for dynamic positioning
	answer_fraction_base_x = answer_pos.x
	answer_fraction_initial_width = answer_fraction_node.current_divisor_width
	
	# Hide the label since we're now using the fraction node
	if current_problem_label:
		current_problem_label.visible = false

func create_answer_mixed_fraction():
	"""Create the answer mixed fraction visual when user presses Fraction"""
	if answer_fraction_node:
		return  # Already exists
	
	# Use the position of the current_problem_label (the answer label) but apply fraction_offset
	var base_pos = current_problem_label.position if current_problem_label else primary_position
	# Subtract operator_offset and add fraction_offset to align with other fractions
	# Also subtract the number offset since we want the fraction at the normal fraction position
	var answer_pos = base_pos - operator_offset + fraction_offset - Vector2(fraction_answer_number_offset, 0)
	
	# Parse the whole number from user_answer
	var parts = user_answer.split(" ")
	var whole_num = 0
	if parts.size() >= 1:
		whole_num = int(parts[0])
	
	# Create the answer mixed fraction at the aligned position
	answer_fraction_node = create_fraction(answer_pos, 0, 1, play_node)
	answer_fraction_node.set_input_mode(true)
	answer_fraction_node.set_mixed_fraction(whole_num, 0, 1)
	answer_fraction_node.editing_numerator = true
	answer_fraction_node.z_index = -1  # Render behind UI elements
	current_problem_nodes.append(answer_fraction_node)
	
	# Get the baseline width (a fraction with just "0/1")
	var temp_fraction = create_fraction(Vector2(0, 0), 0, 1, play_node)
	var baseline_width = temp_fraction.current_divisor_width
	temp_fraction.queue_free()
	
	# Calculate the whole number label width to determine proper offset
	# The whole number label was created in set_mixed_fraction
	var whole_number_width = 0.0
	if answer_fraction_node.whole_number_label:
		whole_number_width = answer_fraction_node.whole_number_label.get_minimum_size().x
	
	# Calculate how much wider the mixed fraction is compared to baseline
	var width_diff = answer_fraction_node.current_total_width - baseline_width
	
	# Shift rightward by: half the total width difference + base offset + whole number compensation
	# The whole number compensation accounts for the fact that larger whole numbers push everything further left
	var dynamic_offset = (width_diff / 2.0) + fraction_mixed_answer_extra_offset + (whole_number_width * 0.5)
	answer_pos.x += dynamic_offset
	answer_fraction_node.position = answer_pos
	
	# Store initial position and width for dynamic positioning (using total width for mixed fractions)
	answer_fraction_base_x = answer_pos.x
	answer_fraction_initial_width = answer_fraction_node.current_total_width
	
	# Hide the label since we're now using the fraction node
	if current_problem_label:
		current_problem_label.visible = false
