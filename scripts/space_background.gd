extends Control

# Real Space Generator with cosmic_kale preset - paths fixed!
@export var background_resolution: Vector2i = Vector2i(1920, 1080)

var space_generator_scene: Node

func _ready():
	# Set up the control to fill the screen
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	
	# Load the Space Generator with fixed paths
	setup_space_generator()

func setup_space_generator():
	# Load the cosmic kale preset JSON
	var preset_file = FileAccess.open("res://addons/Space Generator/Presets/cosmic_kale.json", FileAccess.READ)
	if not preset_file:
		print("Could not load cosmic_kale.json preset")
		return
	
	var preset_json_string = preset_file.get_as_text()
	preset_file.close()
	
	var json = JSON.new()
	var parse_result = json.parse(preset_json_string)
	if parse_result != OK:
		print("Error parsing cosmic_kale.json: ", json.get_error_message())
		return
	
	var preset_data = json.data
	
	# Load the Space Generator scene with fixed paths
	var generator_scene = load("res://addons/Space Generator/SpaceGenerator/space_generator.tscn")
	if generator_scene:
		space_generator_scene = generator_scene.instantiate()
		add_child(space_generator_scene)
		
		# Hide the UI
		var ui_manager = space_generator_scene.get_node("UIManager")
		if ui_manager:
			ui_manager.visible = false
		
		# Load the preset
		if space_generator_scene.has_method("load_preset"):
			space_generator_scene.load_preset(preset_data)
		
		# Set resolution
		space_generator_scene.export_resolution = background_resolution
		if space_generator_scene.has_method("generate_space"):
			space_generator_scene.generate_space(background_resolution)
	else:
		print("Could not load space_generator.tscn")

func set_scroll_speed(new_speed: float):
	# Update layer speeds if needed
	pass

func regenerate():
	# Regenerate the space background
	if space_generator_scene and space_generator_scene.has_method("generate_space"):
		space_generator_scene.generate_space(background_resolution)
