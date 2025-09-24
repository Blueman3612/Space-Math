extends Control

# Real Space Generator with cosmic_kale preset - using core SpaceGenerator class
@export var background_resolution: Vector2i = Vector2i(720, 480)  # Lower resolution for better performance

# Preload all required classes
const SpaceGeneratorClass = preload("res://addons/Space Generator/SpaceGenerator/space_generator.gd")
const PresetUtiltityClass = preload("res://addons/Space Generator/Utilities/preset_utility.gd")
const TypeConversionUtilityClass = preload("res://addons/Space Generator/Utilities/type_conversion_utility.gd")
const GeneratorLayerClass = preload("res://addons/Space Generator/GeneratorLayers/generator_layer.gd")
const NebulaLayerClass = preload("res://addons/Space Generator/GeneratorLayers/NebulaLayer/nebula_layer.gd")
const StarLayerClass = preload("res://addons/Space Generator/GeneratorLayers/StarLayer/star_layer.gd")

var space_generator: Node
var layer_container: Control

func _ready():
	# Set up the control to fill the screen
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	
	# Load the Space Generator with fixed paths
	setup_space_generator()

func setup_space_generator():
	print("Loading space background...")
	
	# Test if we can create the SpaceGenerator instance
	print("Creating SpaceGenerator instance...")
	space_generator = SpaceGeneratorClass.new()
	if not space_generator:
		print("ERROR: Could not create SpaceGenerator instance")
		return
	
	print("Adding SpaceGenerator to scene tree...")
	add_child(space_generator)
	
	# Create layer container
	print("Creating layer container...")
	layer_container = Control.new()
	layer_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	space_generator.add_child(layer_container)
	space_generator.layer_container = layer_container
	
	# Set resolution
	space_generator.export_resolution = background_resolution
	print("SpaceGenerator setup complete, loading preset...")
	
	# Load and apply the cosmic kale preset asynchronously
	load_cosmic_kale_preset_async()

func load_cosmic_kale_preset_async():
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
	
	# Wait a frame to let the scene tree settle
	await get_tree().process_frame
	
	# Load the preset
	if space_generator and space_generator.has_method("load_preset"):
		space_generator.load_preset(preset_data)
	
	print("Space background loaded!")

func set_scroll_speed(new_speed: float):
	# Update layer speeds if needed
	pass

func regenerate():
	# Regenerate the space background
	if space_generator and space_generator.has_method("generate_space"):
		space_generator.generate_space(background_resolution)
