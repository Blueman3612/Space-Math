extends Node

# Game configuration constants - centralized for easy tuning

# ============================================
# Game State
# ============================================
enum GameState { MENU, PLAY, DRILL_PLAY, GAME_OVER }

# ============================================
# Animation & Timing
# ============================================
var blink_interval = 0.5  # Time for underscore blink cycle (fade in/out)
var animation_duration = 0.5  # Duration for label animations in seconds
var transition_delay = 0.1  # Delay before generating new question
var transition_delay_incorrect = 1.5  # Delay for incorrect answers (1.5 seconds)
var incorrect_label_animation_time = 0.25  # Time for incorrect label animation
var incorrect_label_move_distance = 192.0  # Distance to move incorrect label down
var incorrect_label_move_distance_fractions = 256.0  # Distance to move incorrect label down for fractions
var backspace_hold_time = 0.15  # Time to hold backspace before it repeats
var timer_grace_period = 0.5  # Grace period before timer starts in seconds

# ============================================
# Input
# ============================================
var max_answer_chars = 4  # Maximum characters for answer input
var require_submit_after_incorrect = true  # Whether player must press Submit to continue after incorrect answer delay

# ============================================
# Visual Effects
# ============================================
var scroll_boost_multiplier = 80.0  # How much to boost background scroll speed on submission
var feedback_max_alpha = 0.1  # Maximum alpha for feedback color overlay

# ============================================
# Feedback Colors
# ============================================
var color_correct = Color(0, 1, 0)  # Bright green for correct answers
var color_incorrect = Color(1, 0, 0)  # Red for incorrect answers
var color_correct_feedback = Color(0, 0.5, 0)  # Dark green for correct answer display

# ============================================
# Fraction Problem Layout
# ============================================
var fraction_element_spacing = 112.0  # Spacing between fractions and operators
var fraction_answer_offset = 88.0  # Horizontal offset for answer positioning (fraction mode)
var fraction_answer_number_offset = -40.0  # Additional leftward offset for non-fractionalized answers
var fraction_mixed_answer_extra_offset = 4.0  # Additional rightward offset for mixed fraction answers to prevent overlap
var fraction_offset = Vector2(48, 64.0)  # Position offset for fraction elements (x, y)
var operator_offset = Vector2(0, 0.0)  # Position offset for operators and equals sign (x, y)
var unicode_operator_offset = Vector2(10, -30)  # Additional offset for unicode operators (× and ÷) to center them properly
var simple_operator_offset = Vector2(-12, 0)  # Additional offset for simple character operators (x and /) when converted from unicode
var fraction_problem_x_offset = -64.0  # Horizontal offset from primary_position for the entire fraction problem
var fraction_problem_min_x = 32.0  # Minimum x position for fraction problems to prevent going off-screen

# ============================================
# Multiple Choice Question Layout
# ============================================
var multiple_choice_prompt_y_offset = -320.0  # Vertical offset from center for prompt display
var multiple_choice_prompt_x_offset = -48.0  # Horizontal offset for prompt (fractions and question mark)
var multiple_choice_answers_y_offset = 0.0  # Vertical offset from center for answer buttons
var multiple_choice_button_spacing = 64.0  # Horizontal spacing between answer buttons
var multiple_choice_button_min_size = Vector2(320, 320)  # Minimum size for answer buttons
var multiple_choice_button_x_offset = -16.0  # Horizontal offset for answer buttons
var multiple_choice_element_spacing = 80.0  # Spacing between fractions and question mark in multiple choice
var multiple_choice_keybind_labels = ["Q", "W", "E", "R", "T"]  # Keybind labels for answer buttons

# ============================================
# Star Animation
# ============================================
var star_delay = 0.4  # Delay between each star animation in seconds
var star_expand_time = 0.2  # Time for star to expand to max scale
var star_shrink_time = 0.5  # Time for star to shrink to final scale
var star_max_scale = 32.0  # Maximum scale during star animation
var star_final_scale = 8.0  # Final scale for earned stars
var label_fade_time = 0.5  # Time for star labels to fade in

# ============================================
# Title Animation
# ============================================
var title_bounce_speed = 2.0  # Speed of the sin wave animation
var title_bounce_distance = 16.0  # Distance of the bounce in pixels

# ============================================
# Drill Mode
# ============================================
var drill_mode_duration = 60.0  # Duration for drill mode in seconds (1 minute)
var drill_score_bounce_speed = 3.0  # Speed of the sin wave animation for drill score
var drill_score_bounce_distance = 16.0  # Distance of the bounce in pixels for drill score
var flying_score_move_distance = 320.0  # Distance flying score labels move down in pixels
var flying_score_move_duration = 2.0  # Duration for flying score movement animation
var flying_score_fade_duration = 0.5  # Duration for flying score fade out animation
var drill_score_expand_scale = 2.0  # Scale factor for drill score expansion
var drill_score_expand_duration = 0.1  # Duration for drill score expansion
var drill_score_shrink_duration = 0.9  # Duration for drill score shrink back to normal

# ============================================
# High Score Celebration
# ============================================
var high_score_pop_scale = 8.0  # Scale factor for high score text pop effect
var high_score_expand_duration = 0.1  # Duration for high score text expansion
var high_score_shrink_duration = 0.25  # Duration for high score text shrink back to normal
var high_score_flicker_speed = 12.0  # Speed of color flickering between blue and turquoise

# ============================================
# Control Guide
# ============================================
var control_guide_max_x = 1896.0  # Maximum x position for the right side of the rightmost control node
var control_guide_padding = 32.0  # Space between control nodes
var control_guide_animation_duration = 0  # Duration for control slide animations
enum ControlGuideType { DIVIDE, TAB, ENTER, ENTER2 }
const CONTROL_GUIDE_ORDER = [ControlGuideType.ENTER, ControlGuideType.TAB, ControlGuideType.DIVIDE, ControlGuideType.ENTER2]

# ============================================
# Audio Settings
# ============================================
var default_sfx_volume = 0.85  # Default SFX volume (85%)
var default_music_volume = 0.5  # Default music volume (50%)

# ============================================
# Menu Positioning
# ============================================
const menu_above_screen = Vector2(0, -1144)
const menu_below_screen = Vector2(0, 1144)
const menu_on_screen = Vector2(0, 0)

# ============================================
# Problem Positioning
# ============================================
var primary_position = Vector2(480, 476)  # Main problem position
var off_screen_top = Vector2(480, 1276)   # Off-screen top position
var off_screen_bottom = Vector2(480, -324) # Off-screen bottom position

# ============================================
# Level Button Layout
# ============================================
var level_button_start_position = Vector2(-960, -32)  # Starting position for first button (top-left of screen)
var level_button_spacing = Vector2(208, 256)  # Horizontal and vertical spacing between buttons
var level_button_size = Vector2(192, 192)  # Size of each level button
var minimum_padding = 64  # Minimum padding on left and right edges of screen
var max_row_width = 1792  # Maximum width for a row (1920 - 2*minimum_padding)

# ============================================
# Level Pack Outline
# ============================================
var pack_outline_offset = Vector2(-48, -48)  # Offset from top-left of first button in pack
var pack_outline_base_width = 160.0  # Base width for ShapeHorizontal (for 1 button)
var pack_outline_height = 32.0  # Height of ShapeHorizontal
var pack_outline_vertical_height = 128.0  # Height of ShapeVertical

# ============================================
# Level Configuration (per-level star requirements)
# ============================================
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
	10: {"problems": 20, "star1": {"accuracy": 12, "time": 150.0}, "star2": {"accuracy": 14, "time": 120.0}, "star3": {"accuracy": 16, "time": 90.0}},
	11: {"problems": 20, "star1": {"accuracy": 12, "time": 180.0}, "star2": {"accuracy": 14, "time": 150.0}, "star3": {"accuracy": 16, "time": 120.0}},
	12: {"problems": 20, "star1": {"accuracy": 12, "time": 210.0}, "star2": {"accuracy": 14, "time": 180.0}, "star3": {"accuracy": 16, "time": 150.0}},
	13: {"problems": 20, "star1": {"accuracy": 12, "time": 120.0}, "star2": {"accuracy": 14, "time": 100.0}, "star3": {"accuracy": 16, "time": 80.0}}
}

# ============================================
# Level Packs
# ============================================
const level_pack_order = ["Addition", "Subtraction", "Multiplication", "Division", "Fractions"]

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
		"levels": ["4.NF.A.1", "4.NF.A.2", "4.NF.B", "5.NF.A", "5.NF.B"],
		"theme_color": Color(0, 0.75, 0)
	}
}

# ============================================
# Problem Type Display Formats
# ============================================
const PROBLEM_DISPLAY_FORMATS = {
	"Equivalence (4.NF.A)": "fraction",
	"Like-denominator addition/subtraction": "fraction",
	"Mixed numbers (like denominators)": "fraction",
	"Multiply fraction by whole number": "fraction",
	"Add unlike denominators": "fraction",
	"Subtract unlike denominators": "fraction",
	"Multiply fraction by fraction": "fraction",
	"Division with unit fractions": "fraction",
	"Compare unlike denominators (4.NF.A)": "multiple_choice"
}

# ============================================
# TimeBack / XP System Configuration
# ============================================
var timeback_base_xp_per_minute = 1.0  # Base XP: 1 minute = 1 XP
var timeback_idle_threshold = 10.0  # Seconds of no input before considered idle
var timeback_min_session_duration = 5.0  # Minimum seconds for a session to count
var timeback_max_multiplier = 4.0  # Cap on CQPM multiplier
var timeback_min_multiplier = 0.1  # Floor for CQPM multiplier (for very poor performance)

# Star-based XP gating (discourages farming easy/mastered levels)
# Applied as final multiplier to normal level XP (not drill mode)
var timeback_star_multipliers = {
	0: 1.0,   # 0 stars = 100% XP (still learning)
	1: 1.0,   # 1 star = 100% XP (still learning)
	2: 0.75,  # 2 stars = 75% XP (getting good)
	3: 0.25   # 3 stars = 25% XP (mastered, move on)
}

# CQPM multiplier scales per individual level
# Format: {level_number: [[cqpm_threshold, multiplier], ...]}
# Thresholds are checked in descending order; first match wins
var timeback_level_multipliers = {
	1: [[60.0, 4.0], [45.0, 2.0], [30.0, 1.0], [15.0, 0.5], [10.0, 0.25], [0.0, 0.1]],  # Addition Level 1
	2: [[60.0, 4.0], [45.0, 2.0], [30.0, 1.0], [15.0, 0.5], [10.0, 0.25], [0.0, 0.1]],  # Addition Level 2
	3: [[60.0, 4.0], [45.0, 2.0], [30.0, 1.0], [15.0, 0.5], [10.0, 0.25], [0.0, 0.1]],  # Addition Level 3
	4: [[60.0, 4.0], [45.0, 2.0], [30.0, 1.0], [15.0, 0.5], [10.0, 0.25], [0.0, 0.1]],   # Subtraction Level 1
	5: [[60.0, 4.0], [45.0, 2.0], [30.0, 1.0], [15.0, 0.5], [10.0, 0.25], [0.0, 0.1]],   # Subtraction Level 2
	6: [[55.0, 4.0], [40.0, 2.0], [25.0, 1.0], [15.0, 0.5], [10.0, 0.25], [0.0, 0.1]],   # Multiplication Level 1
	7: [[50.0, 4.0], [40.0, 2.0], [25.0, 1.0], [15.0, 0.5], [10.0, 0.25], [0.0, 0.1]],   # Multiplication Level 2
	8: [[50.0, 4.0], [40.0, 2.0], [25.0, 1.0], [15.0, 0.5], [10.0, 0.25], [0.0, 0.1]],    # Division Level 1
	9: [[20.0, 4.0], [15.0, 2.0], [10.0, 1.0], [8.0, 0.5], [5.0, 0.25], [0.0, 0.1]],     # Fractions Level 1 (Equivalence)
	10: [[20.0, 4.0], [15.0, 2.0], [10.0, 1.0], [8.0, 0.5], [5.0, 0.25], [0.0, 0.1]],     # Fractions Level 2 (Compare)
	11: [[15.0, 4.0], [12.0, 2.0], [10.0, 1.0], [8.0, 0.5], [5.0, 0.25], [0.0, 0.1]],     # Fractions Level 3
	12: [[12.0, 4.0], [10.0, 2.0], [8.0, 1.0], [5.0, 0.5], [3.0, 0.25], [0.0, 0.1]],     # Fractions Level 4
	13: [[12.0, 4.0], [10.0, 2.0], [8.0, 1.0], [5.0, 0.5], [3.0, 0.25], [0.0, 0.1]]      # Fractions Level 5
}

# Drill mode CQPM multiplier scale
# Uses average difficulty across all included packs
var timeback_drill_mode_multipliers = [
	[60.0, 3.0],   # 25+ CQPM = 3x multiplier
	[50.0, 2.0],   # 18+ CQPM = 2.5x multiplier
	[40.0, 1.5],   # 12+ CQPM = 2x multiplier
	[30.0, 1.0],    # 8+ CQPM = 1.5x multiplier
	[20.0, 0.5],    # 5+ CQPM = 1.2x multiplier
	[10.0, 0.25],    # 2+ CQPM = 1x multiplier (baseline)
	[0.0, 0.1]     # < 2 CQPM = 0.5x multiplier
]
