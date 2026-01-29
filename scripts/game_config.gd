extends Node

# Game configuration constants - centralized for easy tuning

# ============================================
# Game State
# ============================================
enum GameState { MENU, PLAY, DRILL_PLAY, ASSESSMENT_PLAY, GAME_OVER }

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
var loading_fade_duration = 0.2  # Duration for loading screen fade out
var loading_fade_ease = Tween.EASE_OUT  # Easing type for loading screen fade
var page_transition_duration = 0.25  # Duration for page slide transitions
var page_transition_ease = Tween.EASE_OUT  # Easing type for page transitions
var page_width = 1920.0  # Width offset between pages

# ============================================
# Input
# ============================================
var max_answer_chars = 4  # Maximum characters for answer input

# ============================================
# Problem Display Sizing
# ============================================
var problem_edge_padding = 32.0  # Minimum padding on each side of the screen for problems
var problem_label_settings_order = [
	"res://assets/label settings/GravityBold128.tres",
	"res://assets/label settings/GravityBold96.tres",
	"res://assets/label settings/GravityBold64.tres",
	"res://assets/label settings/GravityBold48.tres",
	"res://assets/label settings/GravityBold32.tres"
]
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
var multiple_choice_prompt_y_offset = -256.0  # Vertical offset from center for prompt display
var multiple_choice_prompt_x_offset = 0.0  # Horizontal offset for prompt (fractions and question mark)
var multiple_choice_answers_y_offset = 64.0  # Vertical offset from center for answer buttons
var multiple_choice_button_spacing = 64.0  # Horizontal spacing between answer buttons
var multiple_choice_button_min_size = Vector2(256, 256)  # Minimum size for answer buttons
var multiple_choice_button_x_offset = 0.0  # Horizontal offset for answer buttons
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
# Level Timer and Mastery Configuration
# ============================================
var level_timer_duration = 120.0  # 2 minutes countdown timer for each level
var mastery_accuracy_threshold = 0.85  # 85% accuracy required to achieve mastery

# Star requirements (percentage of mastery_count for correct answers, accuracy percentage)
var star1_correct_percent = 0.50  # 50% of mastery_count
var star1_accuracy_threshold = 0.55  # 55% accuracy
var star2_correct_percent = 0.75  # 75% of mastery_count
var star2_accuracy_threshold = 0.70  # 70% accuracy
var star3_correct_percent = 1.0  # 100% of mastery_count
var star3_accuracy_threshold = 0.85  # 85% accuracy

# Accuracy line colors (based on star threshold proximity)
var accuracy_color_3star = Color(0, 1, 0)  # Green for >= 85%
var accuracy_color_2star = Color(1, 1, 0)  # Yellow for >= 70%
var accuracy_color_1star = Color(1, 0.5, 0)  # Orange for >= 55%
var accuracy_color_0star = Color(1, 0, 0)  # Red for < 55%

# Level unlock requirements
var stars_required_to_unlock_next_level = 3  # Stars needed on a level to unlock the next level in the pack

# ============================================
# Legacy Level Packs (kept for reference, no longer loaded)
# ============================================
const legacy_level_pack_order = ["Addition", "Subtraction", "Multiplication", "Division", "Fractions"]

const legacy_level_packs = {
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
# Grade-Based Level System
# ============================================
# Current grade being displayed (1-indexed)
var current_grade = 1
# Current page within the grade (1-indexed, for grades that overflow to multiple screens)
var current_grade_page = 1
# Maximum rows per grade screen before pagination kicks in
var max_rows_per_screen = 2

# Available grades
const GRADES = [1, 2, 3, 4, 5]

# Theme colors for categories
const CATEGORY_COLORS = {
	"Addition": Color(0, 0.5, 1),
	"Subtraction": Color(1, 0.25, 0.25),
	"Add./Sub.": Color(0, 0.75, 0.5),
	"Equivalence": Color(0.6, 0.4, 0.8),
	"2-Digit Numbers": Color(1, 0.5, 0),
	"3-Digit Numbers": Color(0.75, 0.25, 0.75),
	"Multiplication": Color(1, 0.75, 0.25),
	"Division": Color(1, 0.5, 1),
	"Mul./Div.": Color(0.8, 0.4, 0),
	"Decimals": Color(0.4, 0.8, 0.9),
	"Fractions": Color(0, 0.7, 0.3)
}

# Grade definitions with categories and levels
# Each level has: name, mastery_count (for star calculation), and generation config
const GRADE_LEVELS = {
	1: {
		"categories": [
			{
				"name": "Addition",
				"levels": [
					{"id": "grade1_addition_sums_to_6", "name": "Sums to 6", "mastery_count": 40, "config": {"operators": ["+"], "sum_max": 6}},
					{"id": "grade1_addition_sums_to_12", "name": "Sums to 12", "mastery_count": 26, "config": {"operators": ["+"], "sum_max": 12}},
					{"id": "grade1_addition_sums_to_20", "name": "Sums to 20", "mastery_count": 22, "config": {"operators": ["+"], "sum_max": 20}}
				]
			},
			{
				"name": "Subtraction",
				"levels": [
					{"id": "grade1_subtraction_0_5", "name": "Subtraction 0-5", "mastery_count": 40, "config": {"operators": ["-"], "range_max": 5}},
					{"id": "grade1_subtraction_0_9", "name": "Subtraction 0-9", "mastery_count": 40, "config": {"operators": ["-"], "range_max": 9}},
					{"id": "grade1_subtraction_0_12", "name": "Subtraction 0-12", "mastery_count": 39, "config": {"operators": ["-"], "range_max": 12}},
					{"id": "grade1_subtraction_0_15", "name": "Subtraction 0-15", "mastery_count": 37, "config": {"operators": ["-"], "range_max": 15}},
					{"id": "grade1_subtraction_0_20", "name": "Subtraction 0-20", "mastery_count": 33, "config": {"operators": ["-"], "range_max": 20}}
				]
			},
			{
				"name": "Add./Sub.",
				"levels": [
					{"id": "grade1_fact_families_0_5", "name": "Add/Subtract 0-5", "mastery_count": 40, "config": {"operators": ["+", "-"], "sum_max": 5, "range_max": 5}},
					{"id": "grade1_fact_families_0_9", "name": "Add/Subtract 0-9", "mastery_count": 40, "config": {"operators": ["+", "-"], "sum_max": 9, "range_max": 9}},
					{"id": "grade1_fact_families_0_20", "name": "Add/Subtract 0-20", "mastery_count": 28, "config": {"operators": ["+", "-"], "sum_max": 20, "range_max": 20}}
				]
			}
		]
	},
	2: {
		"categories": [
			{
				"name": "Addition",
				"levels": [
					{"id": "grade2_addition_sums_to_20", "name": "Sums to 20", "mastery_count": 22, "config": {"operators": ["+"], "sum_max": 20}}
				]
			},
			{
				"name": "Subtraction",
				"levels": [
					{"id": "grade2_subtraction_0_9", "name": "Subtraction 0-9", "mastery_count": 40, "config": {"operators": ["-"], "range_max": 9}},
					{"id": "grade2_subtraction_0_12", "name": "Subtraction 0-12", "mastery_count": 39, "config": {"operators": ["-"], "range_max": 12}},
					{"id": "grade2_subtraction_0_15", "name": "Subtraction 0-15", "mastery_count": 37, "config": {"operators": ["-"], "range_max": 15}},
					{"id": "grade2_subtraction_0_20", "name": "Subtraction 0-20", "mastery_count": 33, "config": {"operators": ["-"], "range_max": 20}}
				]
			},
		{
			"name": "Add./Sub.",
			"levels": [
				{"id": "grade2_expression_comparison_20", "name": "Compare Sums and Differences to 20", "mastery_count": 13, "config": {"type": "expression_comparison_20"}},
				{"id": "grade2_fact_families_0_20", "name": "Add/Subtract 0-20", "mastery_count": 33, "config": {"operators": ["+", "-"], "sum_max": 20, "range_max": 20}}
			]
		},
		{
			"name": "2-Digit Numbers",
				"levels": [
					{"id": "grade2_2digit_add_no_regroup", "name": "Add 2-Digit without Regrouping", "mastery_count": 16, "config": {"operators": ["+"], "digit_count": 2, "requires_regrouping": false, "max_answer": 100}},
					{"id": "grade2_2digit_sub_no_regroup", "name": "Subtract 2-Digit without Regrouping", "mastery_count": 20, "config": {"operators": ["-"], "digit_count": 2, "requires_regrouping": false, "max_answer": 100}},
					{"id": "grade2_2digit_add_regroup", "name": "Add 2-Digit with Regrouping", "mastery_count": 10, "config": {"operators": ["+"], "digit_count": 2, "requires_regrouping": true, "max_answer": 100}},
					{"id": "grade2_2digit_sub_regroup", "name": "Subtract 2-Digit with Regrouping", "mastery_count": 10, "config": {"operators": ["-"], "digit_count": 2, "requires_regrouping": true, "max_answer": 100}}
				]
			},
		{
			"name": "Equivalence",
			"levels": [
				{"id": "grade2_equivalence_associative", "name": "Create Equivalent Add & Sub Problems, Associative Property", "mastery_count": 40, "config": {"type": "equivalence_associative"}},
				{"id": "grade2_equivalence_place_value", "name": "Create Equivalent Add & Sub Problems, Place Value", "mastery_count": 40, "config": {"type": "equivalence_place_value"}}
			]
		},
			{
				"name": "3-Digit Numbers",
				"levels": [
					{"id": "grade2_3digit_add", "name": "Add 3-Digit Numbers", "mastery_count": 9, "config": {"operators": ["+"], "digit_count": 3, "max_answer": 1000}},
					{"id": "grade2_3digit_sub", "name": "Subtract 3-Digit Numbers", "mastery_count": 10, "config": {"operators": ["-"], "digit_count": 3, "max_answer": 1000}}
				]
			}
		]
	},
	3: {
		"categories": [
			{
				"name": "Add./Sub.",
				"levels": [
					{"id": "grade3_add_sub_sums_to_20", "name": "Sums to 20", "mastery_count": 33, "config": {"operators": ["+"], "sum_max": 20, "range_max": 20}},
					{"id": "grade3_subtraction_0_9", "name": "Subtraction 0-9", "mastery_count": 60, "config": {"operators": ["-"], "range_max": 9}},
					{"id": "grade3_add_sub_0_9", "name": "Add/Subtract 0-9", "mastery_count": 60, "config": {"operators": ["+", "-"], "sum_max": 9, "range_max": 9}},
					{"id": "grade3_add_sub_0_20", "name": "Add/Subtract 0-20", "mastery_count": 42, "config": {"operators": ["+", "-"], "sum_max": 20, "range_max": 20}}
				]
			},
			{
				"name": "3-Digit Numbers",
				"levels": [
					{"id": "grade3_3digit_add", "name": "Add 3-Digit Numbers", "mastery_count": 14, "config": {"operators": ["+"], "digit_count": 3, "max_answer": 1998}},
					{"id": "grade3_3digit_sub", "name": "Subtract 3-Digit Numbers", "mastery_count": 15, "config": {"operators": ["-"], "digit_count": 3, "max_answer": 1000}},
					{"id": "grade3_3digit_add_sub", "name": "Add/Subtract 3-Digit Numbers", "mastery_count": 16, "config": {"operators": ["+", "-"], "digit_count": 3, "max_answer": 1998}}
				]
			},
			{
				"name": "Multiplication",
				"levels": [
					{"id": "grade3_multiply_0_9", "name": "Multiply 0-9", "mastery_count": 39, "config": {"operators": ["x"], "factor_min": 0, "factor_max": 9}},
					{"id": "grade3_multiply_5_9", "name": "Multiply 5-9", "mastery_count": 30, "config": {"operators": ["x"], "factor_min": 5, "factor_max": 9}},
					{"id": "grade3_multiply_0_12", "name": "Multiply 0-12", "mastery_count": 35, "config": {"operators": ["x"], "factor_min": 0, "factor_max": 12}},
					{"id": "grade3_multiply_multi_no_regroup", "name": "Multiply 1-Digit by 2-3-Digit without Regrouping", "mastery_count": 19, "config": {"operators": ["x"], "multi_digit": true, "requires_regrouping": false}},
					{"id": "grade3_multiply_multi_regroup", "name": "Multiply 1-Digit by 2-3-Digit with Regrouping", "mastery_count": 18, "config": {"operators": ["x"], "multi_digit": true, "requires_regrouping": true}}
				]
			},
			{
				"name": "Division",
				"levels": [
					{"id": "grade3_divide_0_5", "name": "Divide 0-5", "mastery_count": 60, "config": {"operators": ["/"], "divisor_min": 1, "divisor_max": 5}},
					{"id": "grade3_divide_0_9", "name": "Divide 0-9", "mastery_count": 60, "config": {"operators": ["/"], "divisor_min": 1, "divisor_max": 9}},
					{"id": "grade3_divide_5_9", "name": "Divide 5-9", "mastery_count": 60, "config": {"operators": ["/"], "divisor_min": 5, "divisor_max": 9}},
					{"id": "grade3_divide_0_12", "name": "Divide 0-12", "mastery_count": 48, "config": {"operators": ["/"], "divisor_min": 1, "divisor_max": 12}},
					{"id": "grade3_divide_multi", "name": "Divide 2-3-Digit by 1-Digit", "mastery_count": 9, "config": {"operators": ["/"], "multi_digit": true}}
				]
			},
			{
				"name": "Mul./Div.",
				"levels": [
					{"id": "grade3_multiply_divide_0_9", "name": "Multiply/Divide 0-9", "mastery_count": 51, "config": {"operators": ["x", "/"], "factor_min": 1, "factor_max": 9, "divisor_min": 1, "divisor_max": 9}}
				]
			},
			{
				"name": "Fractions",
				"levels": [
					{"id": "grade3_number_line_fractions", "name": "Place Fractions on Number Line (den. 2, 4, 8)", "mastery_count": 20, "config": {"type": "number_line_fractions", "denominators": [2, 4, 8], "total_pips": 9, "frame": 0, "control_mode": "pip_to_pip", "lower_limit": 0, "upper_limit": 1}}
				]
			}
		]
	},
	4: {
		"categories": [
			{
				"name": "Addition",
				"levels": [
					{"id": "grade4_addition_sums_to_20", "name": "Sums to 20", "mastery_count": 44, "config": {"operators": ["+"], "sum_max": 20}},
					{"id": "grade4_3digit_add", "name": "Add 3-Digit Numbers", "mastery_count": 19, "config": {"operators": ["+"], "digit_count": 3, "max_answer": 1998}}
				]
			},
			{
				"name": "Subtraction",
				"levels": [
					{"id": "grade4_subtraction_0_9", "name": "Subtraction 0-9", "mastery_count": 80, "config": {"operators": ["-"], "range_max": 9}},
					{"id": "grade4_3digit_sub", "name": "Subtract 3-Digit Numbers", "mastery_count": 20, "config": {"operators": ["-"], "digit_count": 3, "max_answer": 1000}}
				]
			},
			{
				"name": "Multiplication",
				"levels": [
					{"id": "grade4_multiply_0_12", "name": "Multiplication 0-12", "mastery_count": 46, "config": {"operators": ["x"], "factor_min": 0, "factor_max": 12}},
					{"id": "grade4_multiply_1digit_by_multidigit", "name": "1-Digit Multiply by 2-3 Digit", "mastery_count": 25, "config": {"operators": ["x"], "multi_digit": true}},
					{"id": "grade4_multiply_2digit_no_regroup", "name": "2-Digit Multiply by 2-Digit without Regrouping", "mastery_count": 11, "config": {"operators": ["x"], "two_digit_by_two_digit": true, "requires_regrouping": false}},
					{"id": "grade4_multiply_2digit_regroup", "name": "2-Digit Multiply by 2-Digit with Regrouping", "mastery_count": 9, "config": {"operators": ["x"], "two_digit_by_two_digit": true, "requires_regrouping": true}},
					{"id": "grade4_equivalence_mult_factoring", "name": "Create Equivalent Multiplication Problems by Factoring", "mastery_count": 22, "config": {"type": "equivalence_mult_factoring"}}
				]
			},
			{
				"name": "Division",
				"levels": [
					{"id": "grade4_divide_0_12", "name": "Division 0-12", "mastery_count": 64, "config": {"operators": ["/"], "divisor_min": 1, "divisor_max": 12}},
					{"id": "grade4_divide_multidigit", "name": "Divide 2-3-Digit by 1-Digit", "mastery_count": 12, "config": {"operators": ["/"], "multi_digit": true}}
				]
			},
			{
				"name": "Mul./Div.",
				"levels": [
					{"id": "grade4_multiply_divide_0_12", "name": "Multiplication/Division 0-12", "mastery_count": 56, "config": {"operators": ["x", "/"], "factor_min": 0, "factor_max": 12, "divisor_min": 1, "divisor_max": 12}}
				]
			},
			{
				"name": "Decimals",
				"levels": [
					{"id": "grade4_decimal_comparison", "name": "Quantity Comparison of Decimals to Hundredths", "mastery_count": 80, "config": {"type": "decimal_comparison"}},
					{"id": "grade4_decimal_add_sub", "name": "Add and Subtract Decimals to the Hundredths", "mastery_count": 15, "config": {"type": "decimal_add_sub", "operators": ["+", "-"]}}
				]
			},
			{
				"name": "Fractions",
				"levels": [
					{"id": "grade4_number_line_fractions", "name": "Place Fractions on Number Line (den. 2, 3, 4, 5, 6, 8, 10)", "mastery_count": 20, "config": {"type": "number_line_fractions_extended", "denominators": [2, 3, 4, 5, 6, 8, 10], "total_pips": 13, "frame": 1, "control_mode": "continuous", "lower_limit": 0, "upper_limit": 3}},
					{"id": "grade4_fraction_comparison", "name": "Quantity Comparison of Fractions with Unlike Denominators", "mastery_count": 20, "config": {"type": "fraction_comparison"}},
					{"id": "grade4_mixed_numbers", "name": "Add/Subtract Mixed Numbers with Like Denominators", "mastery_count": 19, "config": {"type": "mixed_numbers_like_denom", "operators": ["+", "-"]}}
				]
			}
		]
	},
	5: {
		"categories": [
			{
				"name": "Addition",
				"levels": [
					{"id": "grade5_addition_sums_to_20", "name": "Sums to 20", "mastery_count": 44, "config": {"operators": ["+"], "sum_max": 20}},
					{"id": "grade5_3digit_add", "name": "Add 3-Digit Numbers", "mastery_count": 19, "config": {"operators": ["+"], "digit_count": 3, "max_answer": 1998}}
				]
			},
			{
				"name": "Subtraction",
				"levels": [
					{"id": "grade5_subtraction_0_9", "name": "Subtraction 0-9", "mastery_count": 80, "config": {"operators": ["-"], "range_max": 9}},
					{"id": "grade5_3digit_sub", "name": "Subtract 3-Digit Numbers", "mastery_count": 20, "config": {"operators": ["-"], "digit_count": 3, "max_answer": 1000}}
				]
			},
			{
				"name": "Decimals",
				"levels": [
					{"id": "grade5_decimal_add_sub", "name": "Add/Subtract Decimals to the Hundredths", "mastery_count": 15, "config": {"type": "decimal_add_sub", "operators": ["+", "-"]}},
					{"id": "grade5_decimal_multiply_divide", "name": "Multiply/Divide Decimals", "mastery_count": 11, "config": {"type": "decimal_multiply_divide", "operators": ["x", "/"]}}
				]
			},
			{
				"name": "Multiplication",
				"levels": [
					{"id": "grade5_multiply_0_12", "name": "Multiplication 0-12", "mastery_count": 46, "config": {"operators": ["x"], "factor_min": 0, "factor_max": 12}},
					{"id": "grade5_multiply_2digit", "name": "2-Digit Multiply by 2-Digit", "mastery_count": 10, "config": {"operators": ["x"], "two_digit_by_two_digit": true}}
				]
			},
			{
				"name": "Division",
				"levels": [
					{"id": "grade5_divide_0_12", "name": "Division 0-12", "mastery_count": 46, "config": {"operators": ["/"], "divisor_min": 1, "divisor_max": 12}}
				]
			},
			{
				"name": "Mul./Div.",
				"levels": [
					{"id": "grade5_multiply_divide_0_12", "name": "Fact Families: Multiplication/Division 0-12", "mastery_count": 56, "config": {"operators": ["x", "/"], "factor_min": 0, "factor_max": 12, "divisor_min": 1, "divisor_max": 12}}
				]
			},
			{
				"name": "Fractions",
				"levels": [
					{"id": "grade5_fractions_unlike_denom", "name": "Add/Subtract Fractions with Unlike Denominators", "mastery_count": 6, "config": {"type": "fractions_unlike_denom", "operators": ["+", "-"]}},
					{"id": "grade5_mixed_to_improper", "name": "Convert Mixed Numbers to Improper Fractions", "mastery_count": 24, "config": {"type": "mixed_to_improper"}},
					{"id": "grade5_improper_to_mixed", "name": "Convert Improper Fractions to Mixed Numbers", "mastery_count": 23, "config": {"type": "improper_to_mixed"}},
					{"id": "grade5_mixed_numbers", "name": "Add/Subtract Mixed Numbers with Like Denominators", "mastery_count": 19, "config": {"type": "mixed_numbers_like_denom", "operators": ["+", "-"]}},
					{"id": "grade5_multiply_divide_fractions", "name": "Multiply/Divide Proper and Improper Fractions", "mastery_count": 11, "config": {"type": "multiply_divide_fractions", "operators": ["x", "/"]}}
				]
			}
		]
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
	"Compare unlike denominators (4.NF.A)": "multiple_choice",
	# Number line types
	"number_line_fractions": "number_line",
	"number_line_fractions_extended": "number_line",
	# Grade 2 types
	"expression_comparison_20": "multiple_choice",
	"equivalence_associative": "equivalence",
	"equivalence_place_value": "equivalence",
	# Grade 4 types
	"decimal_comparison": "multiple_choice",
	"fraction_comparison": "multiple_choice",
	"decimal_add_sub": "standard",
	"mixed_numbers_like_denom": "fraction",
	# Grade 5 types
	"decimal_multiply_divide": "standard",
	"fractions_unlike_denom": "fraction",
	"mixed_to_improper": "fraction_conversion",
	"improper_to_mixed": "fraction_conversion",
	"multiply_divide_fractions": "fraction",
	# Multi-input types
	"equivalence_mult_factoring": "multi_input"
}

# ============================================
# Number Line Question Configuration
# ============================================
var number_line_final_position = Vector2(960, 640)  # Final position of number line on screen
var number_line_fraction_position = Vector2(960, 288)  # Position of fraction label above number line
var number_line_pip_left_x = -856.0  # X position of leftmost pip (relative to number line)
var number_line_pip_right_x = 856.0  # X position of rightmost pip (relative to number line)
var number_line_pointer_move_duration = 0.25  # Duration for pointer movement animation
var number_line_pointer_y = 128.0  # Y position of pointer relative to number line
var number_line_feedback_delay = 0.25  # Delay before feedback pointer animates to correct position
var number_line_left_right_hold_time = 0.15  # Time to hold Left/Right before it repeats
var number_line_left_right_repeat_interval = 0.1  # Interval between repeats when holding Left/Right

# Continuous movement mode configuration (for extended number line questions)
var number_line_continuous_speed = 320.0  # Base movement speed in pixels per second
var number_line_continuous_max_speed = 1200.0  # Maximum movement speed after acceleration
var number_line_continuous_acceleration = 2400.0  # Acceleration in pixels per second squared
var number_line_answer_tolerance = 80.0  # Pixel tolerance for correct answer in continuous mode

# ============================================
# TimeBack / XP System Configuration
# ============================================
var timeback_base_xp_per_minute = 0.5  # Base XP: 0.5 XP per minute of active play
var timeback_idle_threshold = 10.0  # Seconds of no input before considered idle
var timeback_min_session_duration = 5.0  # Minimum seconds for a session to count

# XP bonus for newly earned stars (only awarded for stars not previously earned)
var timeback_star1_bonus = 0.25  # +0.25 XP for earning first star
var timeback_star2_bonus = 0.25  # +0.25 XP for earning second star
var timeback_star3_bonus = 0.5   # +0.5 XP for earning third star

# Minimum XP guarantee for mastery (3 stars)
# If a player masters a level and their cumulative XP for that level is still below this,
# they will receive a top-up to reach this minimum
var timeback_mastery_min_xp = 2.0

# XP multiplier based on previously earned stars (discourages farming)
# Applied to (base_time_xp + new_star_bonus)
var timeback_previous_star_multipliers = {
	0: 1.0,   # 0 stars previously = 100% XP
	1: 0.75,  # 1 star previously = 75% XP
	2: 0.5,   # 2 stars previously = 50% XP
	3: 0.25   # 3 stars previously = 25% XP
}

# Drill mode CQPM multiplier scale (kept for drill mode only)
var timeback_drill_mode_multipliers = [
	[60.0, 3.0],   # 60+ CQPM = 3x multiplier
	[50.0, 2.0],   # 50+ CQPM = 2x multiplier
	[40.0, 1.5],   # 40+ CQPM = 1.5x multiplier
	[30.0, 1.0],   # 30+ CQPM = 1x multiplier
	[20.0, 0.5],   # 20+ CQPM = 0.5x multiplier
	[10.0, 0.25],  # 10+ CQPM = 0.25x multiplier
	[0.0, 0.1]     # < 10 CQPM = 0.1x multiplier
]

# ============================================
# Assessment Mode Configuration
# ============================================
var assessment_target_seconds_per_standard = 15.0  # Target time per standard for a mastered student (seconds)
var assessment_theme_color = Color(0.6, 0.2, 0.8)  # Purple theme for assessment

# Assessment standards - tested in order of complexity
# Each standard has:
#   - id: Unique identifier for the standard
#   - name: Display name
#   - target_cqpm: Expected CQPM for mastery (mastery_count / 2). Used to calculate questions per standard.
#   - is_multiple_choice: Whether this is a multiple choice question type
#   - config: Generation config for the assessment (may differ from regular levels for range isolation)
const ASSESSMENT_STANDARDS = [
	# === Grade 1-2: Basic Addition ===
	{
		"id": "assess_sums_to_6",
		"name": "Sums to 6",
		"target_cqpm": 20.0,  # mastery_count 40 / 2
		"is_multiple_choice": false,
		"config": {"operators": ["+"], "sum_min": 0, "sum_max": 6}
	},
	{
		"id": "assess_sums_to_12",
		"name": "Sums to 12",
		"target_cqpm": 13.0,  # mastery_count 26 / 2
		"is_multiple_choice": false,
		"config": {"operators": ["+"], "sum_min": 7, "sum_max": 12}
	},
	{
		"id": "assess_sums_to_20",
		"name": "Sums to 20",
		"target_cqpm": 11.0,  # mastery_count 22 / 2
		"is_multiple_choice": false,
		"config": {"operators": ["+"], "sum_min": 13, "sum_max": 20}
	},
	
	# === Grade 1-2: Basic Subtraction ===
	{
		"id": "assess_subtraction_0_5",
		"name": "Subtraction 0-5",
		"target_cqpm": 20.0,  # mastery_count 40 / 2
		"is_multiple_choice": false,
		"config": {"operators": ["-"], "range_min": 0, "range_max": 5}
	},
	{
		"id": "assess_subtraction_6_9",
		"name": "Subtraction 0-9",
		"target_cqpm": 20.0,  # mastery_count 40 / 2
		"is_multiple_choice": false,
		"config": {"operators": ["-"], "range_min": 6, "range_max": 9}
	},
	{
		"id": "assess_subtraction_10_12",
		"name": "Subtraction 0-12",
		"target_cqpm": 19.5,  # mastery_count 39 / 2
		"is_multiple_choice": false,
		"config": {"operators": ["-"], "range_min": 10, "range_max": 12}
	},
	{
		"id": "assess_subtraction_13_15",
		"name": "Subtraction 0-15",
		"target_cqpm": 18.5,  # mastery_count 37 / 2
		"is_multiple_choice": false,
		"config": {"operators": ["-"], "range_min": 13, "range_max": 15}
	},
	{
		"id": "assess_subtraction_16_20",
		"name": "Subtraction 0-20",
		"target_cqpm": 16.5,  # mastery_count 33 / 2
		"is_multiple_choice": false,
		"config": {"operators": ["-"], "range_min": 16, "range_max": 20}
	},
	
	# === Grade 2: Expression Comparison & 2-Digit Operations ===
	{
		"id": "assess_expression_comparison_20",
		"name": "Compare Sums and Differences to 20",
		"target_cqpm": 6.5,  # mastery_count 13 / 2
		"is_multiple_choice": true,
		"config": {"type": "expression_comparison_20"}
	},
	{
		"id": "assess_2digit_add_no_regroup",
		"name": "Add 2-Digit without Regrouping",
		"target_cqpm": 8.0,  # mastery_count 16 / 2
		"is_multiple_choice": false,
		"config": {"operators": ["+"], "digit_count": 2, "requires_regrouping": false, "max_answer": 100}
	},
	{
		"id": "assess_2digit_sub_no_regroup",
		"name": "Subtract 2-Digit without Regrouping",
		"target_cqpm": 10.0,  # mastery_count 20 / 2
		"is_multiple_choice": false,
		"config": {"operators": ["-"], "digit_count": 2, "requires_regrouping": false, "max_answer": 100}
	},
	{
		"id": "assess_2digit_add_regroup",
		"name": "Add 2-Digit with Regrouping",
		"target_cqpm": 5.0,  # mastery_count 10 / 2
		"is_multiple_choice": false,
		"config": {"operators": ["+"], "digit_count": 2, "requires_regrouping": true, "max_answer": 100}
	},
	{
		"id": "assess_2digit_sub_regroup",
		"name": "Subtract 2-Digit with Regrouping",
		"target_cqpm": 5.0,  # mastery_count 10 / 2
		"is_multiple_choice": false,
		"config": {"operators": ["-"], "digit_count": 2, "requires_regrouping": true, "max_answer": 100}
	},
	
	# === Grade 2: Equivalence ===
	{
		"id": "assess_equivalence_associative",
		"name": "Create Equivalent Add & Sub Problems, Associative Property",
		"target_cqpm": 20.0,  # mastery_count 40 / 2
		"is_multiple_choice": false,
		"config": {"type": "equivalence_associative"}
	},
	{
		"id": "assess_equivalence_place_value",
		"name": "Create Equivalent Add & Sub Problems, Place Value",
		"target_cqpm": 20.0,  # mastery_count 40 / 2
		"is_multiple_choice": false,
		"config": {"type": "equivalence_place_value"}
	},
	
	# === Grade 2-3: 3-Digit Operations ===
	{
		"id": "assess_3digit_add",
		"name": "Add 3-Digit Numbers",
		"target_cqpm": 4.5,  # mastery_count 9 / 2
		"is_multiple_choice": false,
		"config": {"operators": ["+"], "digit_count": 3, "max_answer": 1998}
	},
	{
		"id": "assess_3digit_sub",
		"name": "Subtract 3-Digit Numbers",
		"target_cqpm": 5.0,  # mastery_count 10 / 2
		"is_multiple_choice": false,
		"config": {"operators": ["-"], "digit_count": 3, "max_answer": 1000}
	},
	
	# === Grade 3: Basic Multiplication ===
	{
		"id": "assess_multiply_0_4",
		"name": "Multiply 0-9",
		"target_cqpm": 19.5,  # mastery_count 39 / 2 (from Multiply 0-9)
		"is_multiple_choice": false,
		"config": {"operators": ["x"], "factor_min": 0, "factor_max": 4}
	},
	{
		"id": "assess_multiply_5_8",
		"name": "Multiply 5-9",
		"target_cqpm": 15.0,  # mastery_count 30 / 2
		"is_multiple_choice": false,
		"config": {"operators": ["x"], "factor_min": 5, "factor_max": 8}
	},
	{
		"id": "assess_multiply_9_12",
		"name": "Multiply 0-12",
		"target_cqpm": 17.5,  # mastery_count 35 / 2
		"is_multiple_choice": false,
		"config": {"operators": ["x"], "factor_min": 9, "factor_max": 12}
	},
	{
		"id": "assess_multiply_multi_no_regroup",
		"name": "Multiply 1-Digit by 2-3-Digit without Regrouping",
		"target_cqpm": 9.5,  # mastery_count 19 / 2
		"is_multiple_choice": false,
		"config": {"operators": ["x"], "multi_digit": true, "requires_regrouping": false}
	},
	{
		"id": "assess_multiply_multi_regroup",
		"name": "Multiply 1-Digit by 2-3-Digit with Regrouping",
		"target_cqpm": 9.0,  # mastery_count 18 / 2
		"is_multiple_choice": false,
		"config": {"operators": ["x"], "multi_digit": true, "requires_regrouping": true}
	},
	
	# === Grade 3: Basic Division ===
	{
		"id": "assess_divide_1_4",
		"name": "Divide 0-5",
		"target_cqpm": 30.0,  # mastery_count 60 / 2
		"is_multiple_choice": false,
		"config": {"operators": ["/"], "divisor_min": 1, "divisor_max": 4}
	},
	{
		"id": "assess_divide_5_8",
		"name": "Divide 5-9",
		"target_cqpm": 30.0,  # mastery_count 60 / 2
		"is_multiple_choice": false,
		"config": {"operators": ["/"], "divisor_min": 5, "divisor_max": 8}
	},
	{
		"id": "assess_divide_9_12",
		"name": "Divide 0-12",
		"target_cqpm": 24.0,  # mastery_count 48 / 2
		"is_multiple_choice": false,
		"config": {"operators": ["/"], "divisor_min": 9, "divisor_max": 12}
	},
	{
		"id": "assess_divide_multi",
		"name": "Divide 2-3-Digit by 1-Digit",
		"target_cqpm": 4.5,  # mastery_count 9 / 2
		"is_multiple_choice": false,
		"config": {"operators": ["/"], "multi_digit": true}
	},
	
	# === Grade 3: Fractions Introduction ===
	{
		"id": "assess_number_line_fractions_basic",
		"name": "Place Fractions on Number Line (den. 2, 4, 8)",
		"target_cqpm": 10.0,  # mastery_count 20 / 2
		"is_multiple_choice": false,
		"config": {"type": "number_line_fractions", "denominators": [2, 4, 8], "total_pips": 9, "frame": 0, "control_mode": "pip_to_pip", "lower_limit": 0, "upper_limit": 1}
	},
	
	# === Grade 4: Advanced Multiplication ===
	{
		"id": "assess_multiply_2digit_no_regroup",
		"name": "2-Digit Multiply by 2-Digit without Regrouping",
		"target_cqpm": 5.5,  # mastery_count 11 / 2
		"is_multiple_choice": false,
		"config": {"operators": ["x"], "two_digit_by_two_digit": true, "requires_regrouping": false}
	},
	{
		"id": "assess_multiply_2digit_regroup",
		"name": "2-Digit Multiply by 2-Digit with Regrouping",
		"target_cqpm": 4.5,  # mastery_count 9 / 2
		"is_multiple_choice": false,
		"config": {"operators": ["x"], "two_digit_by_two_digit": true, "requires_regrouping": true}
	},
	{
		"id": "assess_equivalence_mult_factoring",
		"name": "Create Equivalent Multiplication Problems by Factoring",
		"target_cqpm": 11.0,  # mastery_count 22 / 2
		"is_multiple_choice": false,
		"config": {"type": "equivalence_mult_factoring"}
	},
	
	# === Grade 4: Decimals ===
	{
		"id": "assess_decimal_comparison",
		"name": "Quantity Comparison of Decimals to Hundredths",
		"target_cqpm": 40.0,  # mastery_count 80 / 2
		"is_multiple_choice": true,
		"config": {"type": "decimal_comparison"}
	},
	{
		"id": "assess_decimal_add_sub",
		"name": "Add and Subtract Decimals to the Hundredths",
		"target_cqpm": 7.5,  # mastery_count 15 / 2
		"is_multiple_choice": false,
		"config": {"type": "decimal_add_sub", "operators": ["+", "-"]}
	},
	
	# === Grade 4: Advanced Fractions ===
	{
		"id": "assess_number_line_fractions_extended",
		"name": "Place Fractions on Number Line (den. 2, 3, 4, 5, 6, 8, 10)",
		"target_cqpm": 10.0,  # mastery_count 20 / 2
		"is_multiple_choice": false,
		"config": {"type": "number_line_fractions_extended", "denominators": [2, 3, 4, 5, 6, 8, 10], "total_pips": 13, "frame": 1, "control_mode": "continuous", "lower_limit": 0, "upper_limit": 3}
	},
	{
		"id": "assess_fraction_comparison",
		"name": "Quantity Comparison of Fractions with Unlike Denominators",
		"target_cqpm": 10.0,  # mastery_count 20 / 2
		"is_multiple_choice": true,
		"config": {"type": "fraction_comparison"}
	},
	{
		"id": "assess_mixed_numbers_like_denom",
		"name": "Add/Subtract Mixed Numbers with Like Denominators",
		"target_cqpm": 9.5,  # mastery_count 19 / 2
		"is_multiple_choice": false,
		"config": {"type": "mixed_numbers_like_denom", "operators": ["+", "-"]}
	},
	
	# === Grade 5: Advanced Decimals ===
	{
		"id": "assess_decimal_multiply_divide",
		"name": "Multiply/Divide Decimals",
		"target_cqpm": 5.5,  # mastery_count 11 / 2
		"is_multiple_choice": false,
		"config": {"type": "decimal_multiply_divide", "operators": ["x", "/"]}
	},
	
	# === Grade 5: Advanced Fractions ===
	{
		"id": "assess_fractions_unlike_denom",
		"name": "Add/Subtract Fractions with Unlike Denominators",
		"target_cqpm": 3.0,  # mastery_count 6 / 2
		"is_multiple_choice": false,
		"config": {"type": "fractions_unlike_denom", "operators": ["+", "-"]}
	},
	{
		"id": "assess_mixed_to_improper",
		"name": "Convert Mixed Numbers to Improper Fractions",
		"target_cqpm": 12.0,  # mastery_count 24 / 2
		"is_multiple_choice": false,
		"config": {"type": "mixed_to_improper"}
	},
	{
		"id": "assess_improper_to_mixed",
		"name": "Convert Improper Fractions to Mixed Numbers",
		"target_cqpm": 11.5,  # mastery_count 23 / 2
		"is_multiple_choice": false,
		"config": {"type": "improper_to_mixed"}
	},
	{
		"id": "assess_multiply_divide_fractions",
		"name": "Multiply/Divide Proper and Improper Fractions",
		"target_cqpm": 5.5,  # mastery_count 11 / 2
		"is_multiple_choice": false,
		"config": {"type": "multiply_divide_fractions", "operators": ["x", "/"]}
	}
]
