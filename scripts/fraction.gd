extends Control

# Padding to add to the widest label when sizing the divisor
var divisor_padding = 48.0

# X offset for labels to account for shadows
var label_x_offset = 8.0

# Mixed fraction spacing
var whole_number_spacing = 40.0  # Spacing between whole number and fraction

# Input mode variables
var is_input_mode = false  # Whether this fraction is used for user input
var show_underscore = false  # Whether to show blinking underscore in denominator
var is_mixed_fraction = false  # Whether this is a mixed fraction (has whole number)
var editing_numerator = false  # For mixed fractions: whether we're editing numerator (vs denominator)
var is_locked_input_mode = false  # Whether this fraction is locked to only one field (equivalence problems)
var locked_to_numerator = false  # For locked mode: whether user can only edit numerator (vs denominator)

# Layout tracking
var current_divisor_width = 0.0  # Current width of the divisor line (for dynamic positioning)
var current_total_width = 0.0  # Total width including whole number (if mixed fraction)

# Node references
@onready var numerator_label: Label = $Numerator
@onready var denominator_label: Label = $Denominator
@onready var divisor_line: Line2D = $Divisor
@onready var border_line: Line2D = $Divisor/Border
@onready var shadow_line: Line2D = $Divisor/Shadow
var whole_number_label: Label = null  # Created dynamically for mixed fractions

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
	current_divisor_width = divisor_size  # Store for external tracking
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
	"""Set fraction text with strings (for input mode), optionally adding underscore to the appropriate field"""
	# Determine which field gets the underscore in locked mode
	var underscore_in_numerator = is_locked_input_mode and locked_to_numerator
	var underscore_in_denominator = is_locked_input_mode and not locked_to_numerator
	
	# Set the label text temporarily WITHOUT underscore for measurement
	numerator_label.text = numerator_text if numerator_text != "" else ("0" if not underscore_in_numerator else " ")
	denominator_label.text = denominator_text if denominator_text != "" else ("0" if not underscore_in_denominator else " ")
	
	# Force labels to update their minimum size
	numerator_label.reset_size()
	denominator_label.reset_size()
	
	# Measure the width of both labels (WITHOUT underscore for base measurement)
	var numerator_width_base = numerator_label.get_minimum_size().x
	var denominator_width_base = denominator_label.get_minimum_size().x
	
	# NOW add the underscore to the display (after measurement)
	var numerator_underscore_shift = 0.0
	var denominator_underscore_shift = 0.0
	
	if add_underscore and underscore_in_numerator:
		# Underscore goes in numerator (locked mode)
		if show_underscore:
			numerator_label.text = (numerator_text if numerator_text != "" else "") + "_"
			numerator_label.reset_size()
			var numerator_width_with_underscore = numerator_label.get_minimum_size().x
			numerator_underscore_shift = (numerator_width_with_underscore - numerator_width_base) / 2.0
		else:
			numerator_label.text = numerator_text if numerator_text != "" else " "
		# Denominator stays as-is
		denominator_label.text = denominator_text if denominator_text != "" else "0"
	elif add_underscore and (underscore_in_denominator or not is_locked_input_mode):
		# Underscore goes in denominator (regular mode or locked denominator editing)
		if show_underscore:
			denominator_label.text = (denominator_text if denominator_text != "" else "") + "_"
			denominator_label.reset_size()
			var denominator_width_with_underscore = denominator_label.get_minimum_size().x
			denominator_underscore_shift = (denominator_width_with_underscore - denominator_width_base) / 2.0
		else:
			denominator_label.text = denominator_text if denominator_text != "" else " "
		# Numerator stays as-is
		numerator_label.text = numerator_text if numerator_text != "" else "0"
	else:
		# Not in input mode - show static underscore if empty
		numerator_label.text = numerator_text if numerator_text != "" else "0"
		denominator_label.text = denominator_text if denominator_text != "" else "_"
	
	# Use base widths for divisor calculations
	var numerator_width = numerator_width_base
	var denominator_width = denominator_width_base
	
	# Center the numerator label horizontally around x=0 with offset, plus underscore shift
	var numerator_half_width = numerator_width / 2.0
	numerator_label.offset_left = -numerator_half_width + label_x_offset + numerator_underscore_shift
	numerator_label.offset_right = numerator_half_width + label_x_offset + numerator_underscore_shift
	
	# Center the denominator label horizontally around x=0 with offset, plus underscore shift
	var denominator_half_width = denominator_width / 2.0
	denominator_label.offset_left = -denominator_half_width + label_x_offset + denominator_underscore_shift
	denominator_label.offset_right = denominator_half_width + label_x_offset + denominator_underscore_shift
	
	# Check if denominator is 1 (whole number display)
	# Only hide fraction elements if NOT in input mode (to avoid hiding while user is typing "1")
	var is_whole_number = (denominator_label.text.strip_edges() == "1") and not is_input_mode
	
	# Hide divisor lines and denominator for whole numbers
	if is_whole_number:
		divisor_line.visible = false
		border_line.visible = false
		shadow_line.visible = false
		denominator_label.visible = false
		# Use numerator width as the total width
		current_divisor_width = numerator_width
		# Center the numerator at y=0 instead of above the line
		numerator_label.offset_top = -64.0
		numerator_label.offset_bottom = 64.0
	else:
		# Show all elements for normal fractions
		divisor_line.visible = true
		border_line.visible = true
		shadow_line.visible = true
		denominator_label.visible = true
		
		# Find the widest label
		var max_width = max(numerator_width, denominator_width)
		
		# Calculate divisor size (max width + padding)
		var divisor_size = max_width + divisor_padding
		current_divisor_width = divisor_size  # Store for external tracking
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

func set_locked_input_mode(lock_numerator: bool, initial_numerator: String = "", initial_denominator: String = ""):
	"""Enable locked input mode where only one field can be edited"""
	is_input_mode = true
	is_locked_input_mode = true
	locked_to_numerator = lock_numerator
	show_underscore = true  # Start with underscore visible
	
	# Set initial values - the non-editable field gets its value, the editable field starts empty
	if lock_numerator:
		# User can only edit numerator, denominator is locked
		numerator_label.text = ""
		denominator_label.text = initial_denominator if initial_denominator != "" else "1"
	else:
		# User can only edit denominator, numerator is locked
		numerator_label.text = initial_numerator if initial_numerator != "" else "1"
		denominator_label.text = ""
	
	# Update layout
	set_fraction_text(numerator_label.text, denominator_label.text, true)

func update_underscore(underscore_visible: bool):
	"""Update whether the underscore should be visible (for blinking effect)"""
	show_underscore = underscore_visible

func set_mixed_fraction(whole: int, numerator: int = 1, denominator: int = 1):
	"""Set as a mixed fraction with whole number, numerator, and denominator"""
	is_mixed_fraction = true
	
	# Create whole number label if it doesn't exist
	if whole_number_label == null:
		whole_number_label = Label.new()
		whole_number_label.label_settings = numerator_label.label_settings
		whole_number_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		whole_number_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		add_child(whole_number_label)
	
	# Set whole number text
	whole_number_label.text = str(whole)
	whole_number_label.visible = true
	
	# Set fraction part
	numerator_label.text = str(numerator)
	denominator_label.text = str(denominator)
	
	# Update layout
	_update_mixed_fraction_layout()

func set_mixed_fraction_text(whole_text: String, numerator_text: String, denominator_text: String, add_underscore_numerator: bool = false, add_underscore_denominator: bool = false):
	"""Set mixed fraction text with strings (for input mode)"""
	is_mixed_fraction = true
	
	# Create whole number label if it doesn't exist
	if whole_number_label == null:
		whole_number_label = Label.new()
		whole_number_label.label_settings = numerator_label.label_settings
		whole_number_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		whole_number_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		add_child(whole_number_label)
	
	# Set whole number text
	whole_number_label.text = whole_text if whole_text != "" else "0"
	whole_number_label.visible = true
	
	# Set numerator text (temporarily without underscore for measurement)
	numerator_label.text = numerator_text if numerator_text != "" else " "
	
	# Set denominator text (temporarily without underscore for measurement)
	denominator_label.text = denominator_text if denominator_text != "" else " "
	
	# Force labels to update their minimum size for measurement
	whole_number_label.reset_size()
	numerator_label.reset_size()
	denominator_label.reset_size()
	
	# Measure widths
	var whole_width = whole_number_label.get_minimum_size().x
	var numerator_width_base = numerator_label.get_minimum_size().x
	var denominator_width_base = denominator_label.get_minimum_size().x
	
	# Handle underscore for numerator
	var numerator_underscore_shift = 0.0
	if add_underscore_numerator and show_underscore:
		numerator_label.text = (numerator_text if numerator_text != "" else "") + "_"
		numerator_label.reset_size()
		var numerator_width_with_underscore = numerator_label.get_minimum_size().x
		numerator_underscore_shift = (numerator_width_with_underscore - numerator_width_base) / 2.0
	elif add_underscore_numerator and not show_underscore:
		numerator_label.text = numerator_text if numerator_text != "" else " "
	
	# Handle underscore for denominator
	var denominator_underscore_shift = 0.0
	if add_underscore_denominator and show_underscore:
		denominator_label.text = (denominator_text if denominator_text != "" else "") + "_"
		denominator_label.reset_size()
		var denominator_width_with_underscore = denominator_label.get_minimum_size().x
		denominator_underscore_shift = (denominator_width_with_underscore - denominator_width_base) / 2.0
	elif add_underscore_denominator and not show_underscore:
		denominator_label.text = denominator_text if denominator_text != "" else " "
	
	# Use base widths for layout calculations
	var numerator_width = numerator_width_base
	var denominator_width = denominator_width_base
	
	# Find the widest label in the fraction part
	var max_fraction_width = max(numerator_width, denominator_width)
	
	# Calculate divisor size (max width + padding)
	var divisor_size = max_fraction_width + divisor_padding
	current_divisor_width = divisor_size
	var half_size = divisor_size / 2.0
	
	# Calculate total width (whole number + spacing + fraction)
	current_total_width = whole_width + whole_number_spacing + divisor_size
	
	# Position whole number on the left
	var whole_half_width = whole_width / 2.0
	var whole_x_center = -(divisor_size / 2.0) - whole_number_spacing - whole_half_width
	whole_number_label.offset_left = whole_x_center - whole_half_width + label_x_offset
	whole_number_label.offset_right = whole_x_center + whole_half_width + label_x_offset
	
	# Center the numerator label horizontally around x=0 with offset and underscore shift
	var numerator_half_width = numerator_width / 2.0
	numerator_label.offset_left = -numerator_half_width + label_x_offset + numerator_underscore_shift
	numerator_label.offset_right = numerator_half_width + label_x_offset + numerator_underscore_shift
	
	# Center the denominator label horizontally around x=0 with offset and underscore shift
	var denominator_half_width = denominator_width / 2.0
	denominator_label.offset_left = -denominator_half_width + label_x_offset + denominator_underscore_shift
	denominator_label.offset_right = denominator_half_width + label_x_offset + denominator_underscore_shift
	
	# Update Divisor line points
	divisor_line.set_point_position(0, Vector2(-half_size, 0))
	divisor_line.set_point_position(1, Vector2(half_size, 0))
	
	# Update Border line points (32 pixels larger)
	var border_half_size = half_size + 16.0
	border_line.set_point_position(0, Vector2(-border_half_size, 0))
	border_line.set_point_position(1, Vector2(border_half_size, 0))
	
	# Update Shadow line points (same size as Divisor)
	shadow_line.set_point_position(0, Vector2(-half_size, 0))
	shadow_line.set_point_position(1, Vector2(half_size, 0))

func _update_mixed_fraction_layout():
	"""Update layout for mixed fractions"""
	# Force labels to update their minimum size
	whole_number_label.reset_size()
	numerator_label.reset_size()
	denominator_label.reset_size()
	
	# Measure widths
	var whole_width = whole_number_label.get_minimum_size().x
	var numerator_width = numerator_label.get_minimum_size().x
	var denominator_width = denominator_label.get_minimum_size().x
	
	# Find the widest label in the fraction part
	var max_fraction_width = max(numerator_width, denominator_width)
	
	# Calculate divisor size (max width + padding)
	var divisor_size = max_fraction_width + divisor_padding
	current_divisor_width = divisor_size
	var half_size = divisor_size / 2.0
	
	# Calculate total width (whole number + spacing + fraction)
	current_total_width = whole_width + whole_number_spacing + divisor_size
	var total_half_width = current_total_width / 2.0
	
	# Position whole number - center the entire mixed fraction around x=0
	var whole_half_width = whole_width / 2.0
	var whole_x_center = -total_half_width + whole_half_width
	whole_number_label.offset_left = whole_x_center - whole_half_width + label_x_offset
	whole_number_label.offset_right = whole_x_center + whole_half_width + label_x_offset
	# Center whole number vertically (span from -64 to 64 pixels around y=0)
	whole_number_label.offset_top = -64.0
	whole_number_label.offset_bottom = 64.0
	
	# Position fraction part - shifted right to account for whole number
	var fraction_x_offset = whole_width + whole_number_spacing - total_half_width + (divisor_size / 2.0)
	
	# Center the numerator label horizontally with the offset
	var numerator_half_width = numerator_width / 2.0
	numerator_label.offset_left = fraction_x_offset - numerator_half_width + label_x_offset
	numerator_label.offset_right = fraction_x_offset + numerator_half_width + label_x_offset
	
	# Center the denominator label horizontally with the offset
	var denominator_half_width = denominator_width / 2.0
	denominator_label.offset_left = fraction_x_offset - denominator_half_width + label_x_offset
	denominator_label.offset_right = fraction_x_offset + denominator_half_width + label_x_offset
	
	# Update Divisor line points - offset to match fraction position
	divisor_line.set_point_position(0, Vector2(fraction_x_offset - half_size, 0))
	divisor_line.set_point_position(1, Vector2(fraction_x_offset + half_size, 0))
	
	# Update Border line points (32 pixels larger)
	var border_half_size = half_size + 16.0
	border_line.set_point_position(0, Vector2(fraction_x_offset - border_half_size, 0))
	border_line.set_point_position(1, Vector2(fraction_x_offset + border_half_size, 0))
	
	# Update Shadow line points (same size as Divisor)
	shadow_line.set_point_position(0, Vector2(fraction_x_offset - half_size, 0))
	shadow_line.set_point_position(1, Vector2(fraction_x_offset + half_size, 0))

func clear_mixed_fraction():
	"""Clear mixed fraction mode and hide whole number label"""
	is_mixed_fraction = false
	if whole_number_label:
		whole_number_label.visible = false
	current_total_width = current_divisor_width
