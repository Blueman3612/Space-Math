extends Control

# Padding to add to the widest label when sizing the divisor
var divisor_padding = 64.0

# X offset for labels to account for shadows
var label_x_offset = 8.0

# Input mode variables
var is_input_mode = false  # Whether this fraction is used for user input
var show_underscore = false  # Whether to show blinking underscore in denominator

# Node references
@onready var numerator_label: Label = $Numerator
@onready var denominator_label: Label = $Denominator
@onready var divisor_line: Line2D = $Divisor
@onready var border_line: Line2D = $Divisor/Border
@onready var shadow_line: Line2D = $Divisor/Shadow

func set_fraction(numerator: int = 1, denominator: int = 1):
	"""Set the numerator and denominator, then resize the divisor lines"""
	# Set the label text
	numerator_label.text = str(numerator)
	denominator_label.text = str(denominator)
	
	# Force labels to update their minimum size
	numerator_label.reset_size()
	denominator_label.reset_size()
	
	# Measure the width of both labels
	var numerator_width = numerator_label.get_minimum_size().x
	var denominator_width = denominator_label.get_minimum_size().x
	
	# Center the numerator label horizontally around x=0 with offset
	var numerator_half_width = numerator_width / 2.0
	numerator_label.offset_left = -numerator_half_width + label_x_offset
	numerator_label.offset_right = numerator_half_width + label_x_offset
	
	# Center the denominator label horizontally around x=0 with offset
	var denominator_half_width = denominator_width / 2.0
	denominator_label.offset_left = -denominator_half_width + label_x_offset
	denominator_label.offset_right = denominator_half_width + label_x_offset
	
	# Find the widest label
	var max_width = max(numerator_width, denominator_width)
	
	# Calculate divisor size (max width + padding)
	var divisor_size = max_width + divisor_padding
	var half_size = divisor_size / 2.0
	
	# Update Divisor line points
	divisor_line.set_point_position(0, Vector2(-half_size, 0))
	divisor_line.set_point_position(1, Vector2(half_size, 0))
	
	# Update Border line points (32 pixels larger)
	var border_half_size = half_size + 16.0  # 16 on each side = 32 total
	border_line.set_point_position(0, Vector2(-border_half_size, 0))
	border_line.set_point_position(1, Vector2(border_half_size, 0))
	
	# Update Shadow line points (same size as Divisor)
	shadow_line.set_point_position(0, Vector2(-half_size, 0))
	shadow_line.set_point_position(1, Vector2(half_size, 0))

func set_fraction_text(numerator_text: String, denominator_text: String, add_underscore: bool = false):
	"""Set fraction text with strings (for input mode), optionally adding underscore to denominator"""
	# Set the label text temporarily WITHOUT underscore for measurement
	numerator_label.text = numerator_text if numerator_text != "" else "0"
	denominator_label.text = denominator_text if denominator_text != "" else " "
	
	# Force labels to update their minimum size
	numerator_label.reset_size()
	denominator_label.reset_size()
	
	# Measure the width of both labels (WITHOUT underscore for base measurement)
	var numerator_width = numerator_label.get_minimum_size().x
	var denominator_width_base = denominator_label.get_minimum_size().x
	
	# NOW add the underscore to the display (after measurement)
	var underscore_shift = 0.0
	if add_underscore:
		if show_underscore:
			denominator_label.text = (denominator_text if denominator_text != "" else "") + "_"
			# Measure width WITH underscore
			denominator_label.reset_size()
			var denominator_width_with_underscore = denominator_label.get_minimum_size().x
			# Calculate how much to shift RIGHT so the number stays in place and underscore grows to the right
			underscore_shift = (denominator_width_with_underscore - denominator_width_base) / 2.0
		else:
			# Underscore not visible - show text without underscore (or empty if no text)
			denominator_label.text = denominator_text if denominator_text != "" else " "
	else:
		# Not in input mode - show static underscore if empty
		denominator_label.text = denominator_text if denominator_text != "" else "_"
	
	# Use base width for divisor calculations
	var denominator_width = denominator_width_base
	
	# Center the numerator label horizontally around x=0 with offset
	var numerator_half_width = numerator_width / 2.0
	numerator_label.offset_left = -numerator_half_width + label_x_offset
	numerator_label.offset_right = numerator_half_width + label_x_offset
	
	# Center the denominator label horizontally around x=0 with offset, plus underscore shift
	var denominator_half_width = denominator_width / 2.0
	denominator_label.offset_left = -denominator_half_width + label_x_offset + underscore_shift
	denominator_label.offset_right = denominator_half_width + label_x_offset + underscore_shift
	
	# Find the widest label
	var max_width = max(numerator_width, denominator_width)
	
	# Calculate divisor size (max width + padding)
	var divisor_size = max_width + divisor_padding
	var half_size = divisor_size / 2.0
	
	# Update Divisor line points
	divisor_line.set_point_position(0, Vector2(-half_size, 0))
	divisor_line.set_point_position(1, Vector2(half_size, 0))
	
	# Update Border line points (32 pixels larger)
	var border_half_size = half_size + 16.0  # 16 on each side = 32 total
	border_line.set_point_position(0, Vector2(-border_half_size, 0))
	border_line.set_point_position(1, Vector2(border_half_size, 0))
	
	# Update Shadow line points (same size as Divisor)
	shadow_line.set_point_position(0, Vector2(-half_size, 0))
	shadow_line.set_point_position(1, Vector2(half_size, 0))

func set_input_mode(enabled: bool):
	"""Enable or disable input mode for this fraction"""
	is_input_mode = enabled

func update_underscore(visible: bool):
	"""Update whether the underscore should be visible (for blinking effect)"""
	show_underscore = visible
