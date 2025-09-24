extends Control

# Real Space Generator with cosmic_kale preset - using core SpaceGenerator class
@export var background_resolution: Vector2i = Vector2i(720, 480)  # Lower resolution for better performance
@export var base_scroll_speed: float = 1.0  # Base scroll speed multiplier
var current_scroll_speed: float = 1.0  # Current active scroll speed
var scroll_tween: Tween  # Tween for smooth scroll speed transitions

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
	
	# Initialize current scroll speed to base speed
	current_scroll_speed = base_scroll_speed
	
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
	
	# Randomize seeds for variety
	randomize_preset_seeds(preset_data)
	
	# Wait a frame to let the scene tree settle
	await get_tree().process_frame
	
	# Load the preset
	if space_generator and space_generator.has_method("load_preset"):
		space_generator.load_preset(preset_data)
	
	# Apply the scroll speed multiplier to the loaded layers
	await get_tree().process_frame  # Wait for layers to be fully initialized
	apply_scroll_speed()
	
	print("Space background loaded!")

func randomize_preset_seeds(preset_data: Dictionary):
	# Randomize seeds for all layers to create variety
	var rng = RandomNumberGenerator.new()
	rng.randomize()
	
	print("🎲 Randomizing space background seeds for variety...")
	
	# Go through all layers and randomize their seeds
	for key in preset_data.keys():
		if key.begins_with("NebulaLayer") or key.begins_with("StarLayer"):
			var layer_data = preset_data[key]
			
			# Randomize nebula seeds (main noise pattern)
			if layer_data.has("seed"):
				var old_seed = layer_data["seed"]
				layer_data["seed"] = rng.randi()
				print("  %s: seed %d → %d" % [key, old_seed, layer_data["seed"]])
			
			# Randomize modulation seeds (secondary noise for nebula layers)
			if layer_data.has("modulation_seed"):
				var old_mod_seed = layer_data["modulation_seed"]
				layer_data["modulation_seed"] = rng.randi()
				print("  %s: modulation_seed %d → %d" % [key, old_mod_seed, layer_data["modulation_seed"]])
	
	print("✨ Seed randomization complete!")

func set_base_scroll_speed(new_base_speed: float):
	# Update the base scroll speed multiplier
	base_scroll_speed = new_base_speed
	current_scroll_speed = new_base_speed
	apply_scroll_speed()

func boost_scroll_speed(multiplier: float, duration: float):
	# Instantly boost scroll speed, then smoothly return to base over duration
	var target_speed = base_scroll_speed * multiplier
	current_scroll_speed = target_speed
	apply_scroll_speed()
	
	# Create tween to smoothly return to base speed
	if scroll_tween:
		scroll_tween.kill()
	
	scroll_tween = create_tween()
	scroll_tween.set_ease(Tween.EASE_OUT)
	scroll_tween.set_trans(Tween.TRANS_EXPO)
	scroll_tween.tween_method(update_scroll_speed, target_speed, base_scroll_speed, duration)

func update_scroll_speed(speed: float):
	# Called by tween to update scroll speed smoothly
	current_scroll_speed = speed
	apply_scroll_speed()

func apply_scroll_speed():
	# Apply the current scroll speed multiplier to all layers using their original preset speeds
	if space_generator:
		for layer in space_generator.layers:
			if layer.has_method("set_speed"):
				# Get the original speed from the cosmic_kale preset and multiply by current multiplier
				var original_speed = get_original_layer_speed(layer.title)
				var final_speed = original_speed * current_scroll_speed
				layer.set_speed(final_speed)

func get_original_layer_speed(layer_title: String) -> float:
	# Return the original speeds from the cosmic_kale preset
	match layer_title:
		"Background Nebula":
			return 11.5
		"Foreground Nebula": 
			return 29.2
		"Star Layer A", "Star Layer B":
			return 6.0
		_:
			return 6.0  # Default speed

func regenerate():
	# Regenerate the space background with new random seeds
	print("Regenerating space background with new seeds...")
	
	# Reload and randomize the preset
	var preset_file = FileAccess.open("res://addons/Space Generator/Presets/cosmic_kale.json", FileAccess.READ)
	if preset_file:
		var preset_json_string = preset_file.get_as_text()
		preset_file.close()
		
		var json = JSON.new()
		var parse_result = json.parse(preset_json_string)
		if parse_result == OK:
			var preset_data = json.data
			randomize_preset_seeds(preset_data)
			
			if space_generator and space_generator.has_method("load_preset"):
				space_generator.load_preset(preset_data)
		else:
			print("Error parsing preset during regeneration")
	else:
		# Fallback: just regenerate with current settings
		if space_generator and space_generator.has_method("generate_space"):
			space_generator.generate_space(background_resolution)
