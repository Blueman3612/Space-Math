extends Control

# Padding to add to the widest label when sizing the divisor
var divisor_padding = 64.0

# X offset for labels to account for shadows
var label_x_offset = 8.0

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
