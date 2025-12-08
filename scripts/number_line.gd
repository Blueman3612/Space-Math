extends Sprite2D

# Number line question management - handles pip selection, pointer movement, and feedback

# Configuration (set by display_manager when creating the problem)
var total_pips: int = 9
var lower_limit: int = 0
var upper_limit: int = 1
var correct_pip: int = 0  # The pip index that represents the correct answer

# Current state
var selected_pip: int = 4  # Currently selected pip (center by default)
var is_animating: bool = false  # Whether pointer is currently animating
var answer_submitted: bool = false  # Whether an answer has been submitted

# Node references
@onready var pointer: Sprite2D = $Pointer
@onready var left_control: Sprite2D = $Pointer/LeftControl
@onready var right_control: Sprite2D = $Pointer/RightControl
@onready var feedback: Sprite2D = $Pointer/Feedback
@onready var lower_limit_label: Label = $LowerLimit
@onready var upper_limit_label: Label = $UpperLimit

func _ready():
	# Ensure feedback is hidden initially
	if feedback:
		feedback.visible = false
	
	# Set initial pointer position to center pip
	_update_pointer_position_immediate()
	_update_control_visibility()

func initialize(config: Dictionary):
	"""Initialize the number line with the given configuration"""
	total_pips = config.get("total_pips", 9)
	lower_limit = config.get("lower_limit", 0)
	upper_limit = config.get("upper_limit", 1)
	
	# Set the center pip as default selection
	selected_pip = total_pips / 2
	
	# Update limit labels
	if lower_limit_label:
		lower_limit_label.text = str(lower_limit)
	if upper_limit_label:
		upper_limit_label.text = str(upper_limit)
	
	# Reset state
	answer_submitted = false
	is_animating = false
	
	# Ensure feedback is hidden
	if feedback:
		feedback.visible = false
		feedback.position = Vector2.ZERO
	
	# Update pointer and controls
	_update_pointer_position_immediate()
	_update_control_visibility()

func set_correct_pip(pip_index: int):
	"""Set the correct pip for answer validation"""
	correct_pip = pip_index

func get_pip_x_position(pip_index: int) -> float:
	"""Calculate the x position for a given pip index"""
	if total_pips <= 1:
		return 0.0
	
	var left_x = GameConfig.number_line_pip_left_x
	var right_x = GameConfig.number_line_pip_right_x
	var total_distance = right_x - left_x
	var pip_spacing = total_distance / float(total_pips - 1)
	
	return left_x + (pip_index * pip_spacing)

func move_left():
	"""Move selection one pip to the left"""
	if answer_submitted or selected_pip <= 0:
		return
	
	selected_pip -= 1
	_animate_pointer_to_selected_pip()
	_update_control_visibility()
	AudioManager.play_tick()

func move_right():
	"""Move selection one pip to the right"""
	if answer_submitted or selected_pip >= total_pips - 1:
		return
	
	selected_pip += 1
	_animate_pointer_to_selected_pip()
	_update_control_visibility()
	AudioManager.play_tick()

func _animate_pointer_to_selected_pip():
	"""Animate the pointer to the currently selected pip"""
	if not pointer:
		return
	
	var target_x = get_pip_x_position(selected_pip)
	var target_position = Vector2(target_x, GameConfig.number_line_pointer_y)
	
	is_animating = true
	
	var tween = create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_EXPO)
	tween.tween_property(pointer, "position", target_position, GameConfig.number_line_pointer_move_duration)
	tween.tween_callback(func(): is_animating = false)

func _update_pointer_position_immediate():
	"""Set pointer position immediately without animation"""
	if not pointer:
		return
	
	var target_x = get_pip_x_position(selected_pip)
	pointer.position = Vector2(target_x, GameConfig.number_line_pointer_y)

func _update_control_visibility():
	"""Update visibility of left/right control indicators"""
	if answer_submitted:
		# Hide both controls after answer submission
		if left_control:
			left_control.visible = false
		if right_control:
			right_control.visible = false
		return
	
	# Show/hide based on current position
	if left_control:
		left_control.visible = selected_pip > 0
	if right_control:
		right_control.visible = selected_pip < total_pips - 1

func get_selected_fraction_string() -> String:
	"""Get the fraction string representation of the currently selected pip"""
	# Calculate what fraction this pip represents
	# With pips from 0 to (total_pips - 1), each pip represents:
	# pip_value = lower_limit + (selected_pip / (total_pips - 1)) * (upper_limit - lower_limit)
	# For 0 to 1 range with 9 pips: pip 0 = 0, pip 4 = 4/8 = 1/2, pip 8 = 1
	
	var numerator = selected_pip
	var denominator = total_pips - 1  # 8 for 9 pips
	
	# Simplify the fraction
	var gcd = _gcd(numerator, denominator)
	if gcd > 0:
		numerator = numerator / gcd
		denominator = denominator / gcd
	
	if numerator == 0:
		return "0"
	elif denominator == 1:
		return str(numerator)
	else:
		return str(numerator) + "/" + str(denominator)

func _gcd(a: int, b: int) -> int:
	"""Calculate greatest common divisor"""
	a = abs(a)
	b = abs(b)
	while b != 0:
		var temp = b
		b = a % b
		a = temp
	return a

func is_correct() -> bool:
	"""Check if the currently selected pip is correct"""
	return selected_pip == correct_pip

func show_correct_feedback():
	"""Show feedback for a correct answer"""
	answer_submitted = true
	_update_control_visibility()
	
	# Color the number line and pointer green
	self_modulate = GameConfig.color_correct
	if pointer:
		pointer.self_modulate = GameConfig.color_correct

func show_incorrect_feedback():
	"""Show feedback for an incorrect answer - pointer turns red, feedback shows correct position"""
	answer_submitted = true
	_update_control_visibility()
	
	# Color the pointer red (not the number line itself)
	if pointer:
		pointer.self_modulate = GameConfig.color_incorrect
	
	# Show the feedback pointer and animate it to the correct position immediately
	if feedback:
		feedback.visible = true
		feedback.position = Vector2.ZERO  # Start at current pointer position (relative to Pointer)
		
		# Calculate target position relative to the pointer
		var correct_x = get_pip_x_position(correct_pip)
		var current_x = get_pip_x_position(selected_pip)
		var relative_x = correct_x - current_x
		var target_position = Vector2(relative_x, 0)
		
		# Animate to correct position immediately
		var tween = create_tween()
		tween.set_ease(Tween.EASE_OUT)
		tween.set_trans(Tween.TRANS_EXPO)
		tween.tween_property(feedback, "position", target_position, GameConfig.number_line_pointer_move_duration)

func reset():
	"""Reset the number line for a new question"""
	answer_submitted = false
	is_animating = false
	selected_pip = total_pips / 2
	
	# Reset colors
	self_modulate = Color(1, 1, 1)
	if pointer:
		pointer.self_modulate = Color(1, 1, 1)
	
	# Hide feedback
	if feedback:
		feedback.visible = false
		feedback.position = Vector2.ZERO
	
	# Reset pointer position
	_update_pointer_position_immediate()
	_update_control_visibility()
