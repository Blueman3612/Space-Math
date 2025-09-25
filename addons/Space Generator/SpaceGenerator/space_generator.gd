class_name SpaceGenerator
extends Node

@export var layers : Array[TextureRect]
@export var layer_container : Control


enum LayerTypes {STAR_LAYER, NEBULA_LAYER}
const STAR_LAYER_RESOURCE : Resource = \
		preload("res://addons/Space Generator/GeneratorLayers/StarLayer/star_layer.tscn")
const NEBULA_LAYER_RESOURCE : Resource = \
		preload("res://addons/Space Generator/GeneratorLayers/NebulaLayer/nebula_layer.tscn")
# PlanetLayer removed - not needed for cosmic_kale preset

@export var nebula_layers : Array[NebulaLayer]
@export var star_layers : Array[StarLayer]
# planet_layers removed - not needed

@export var export_resolution : Vector2i = Vector2i(360, 240)

enum ExportTypes {PNG, PRESET}

# ui_manager removed - no UI needed


func _ready() -> void:
	# export var doesn't work on web export for this one variable
	# I don't know why
	# This catches it, which will do for now 
	#if layer_container == null: layer_container = $Layers

	generate_space(export_resolution)
	
	# UI removed for performance


# Input handling removed - no UI to hide


func generate_space(new_size : Vector2i) -> void:
	# this should work for resetting resolution, I think?
	export_resolution = new_size

	for layer : NebulaLayer in nebula_layers:
		layer.build_nebula(Vector2i(new_size))

	for layer : StarLayer in star_layers:
		if layer.max_stars == 0 or layer.ratio.size() == 0:
			layer.generate_stars\
					(256, [.65, .2, .15], new_size)
		else:
			layer.generate_stars\
					(layer.max_stars, layer.ratio.duplicate(), new_size)

	# Planet layers removed


func generate_pngs() -> void:
	for layer : TextureRect in layers:
		var _new_image : Image = layer.texture.get_image()


func add_layer(layer_type : LayerTypes) -> void:
	var new_layer : GeneratorLayer
	var layer_title : String
	match layer_type:
		LayerTypes.STAR_LAYER:
			new_layer = STAR_LAYER_RESOURCE.instantiate()
			layer_container.add_child(new_layer)
			var ratio : Array[float] = [.65, .2, .15]
			new_layer.generate_stars(192, ratio, export_resolution)
			layer_title = "Star Layer"
			new_layer.title = layer_title
			star_layers.append(new_layer)
		LayerTypes.NEBULA_LAYER:
			new_layer = NEBULA_LAYER_RESOURCE.instantiate()
			layer_container.add_child(new_layer)
			new_layer.build_nebula(export_resolution)
			layer_title = "Nebula Layer"
			new_layer.title = layer_title
			nebula_layers.append(new_layer)
		# Planet layer case removed

	# UI manager removed - just append layer
	layers.append(new_layer)


func duplicate_layer(source_layer : GeneratorLayer) -> void:
	if source_layer is StarLayer:
		duplicate_star_layer(source_layer)
		return
	elif source_layer is NebulaLayer:
		duplicate_nebula_layer(source_layer)
		return
	# Planet layer duplication removed
	push_error("Error: no method defined to duplicate provided layer")


func duplicate_star_layer(source_layer : StarLayer) -> void:
	var new_layer : StarLayer = STAR_LAYER_RESOURCE.instantiate()
	layer_container.add_child(new_layer)

	new_layer.generate_stars\
			(source_layer.max_stars, source_layer.ratio, export_resolution)
	new_layer.title = "%s Copy" % source_layer.title
	new_layer.flicker_rate = source_layer.flicker_rate
	new_layer.flicker_depth = source_layer.flicker_depth
	new_layer.speed = source_layer.speed

	# UI manager removed
	layers.append(new_layer)


func duplicate_nebula_layer(source_layer : NebulaLayer) -> void:
	var new_layer : NebulaLayer = NEBULA_LAYER_RESOURCE.instantiate()
	layer_container.add_child(new_layer)

	new_layer.set_palette(source_layer.palette)
	new_layer.set_threshold(source_layer.threshold)
	new_layer.set_density(source_layer.density)
	new_layer.set_alpha(source_layer.alpha)
	new_layer.set_dither_enabled(source_layer.dither_enabled)
	new_layer.set_modulation_enabled(source_layer.modulation_enabled)
	new_layer.set_modulation_color(source_layer.modulation_color)
	new_layer.set_modulation_intensity(source_layer.modulation_intensity)
	new_layer.set_modulation_alpha_intensity\
			(source_layer.modulation_alpha_intensity)
	new_layer.set_modulation_density(source_layer.modulation_density)
	new_layer.set_modulation_steps(source_layer.modulation_steps)
	new_layer.set_oscillate(source_layer.oscillate)
	new_layer.set_oscillation_intensity(source_layer.oscillation_intensity)
	new_layer.set_oscillation_rate(source_layer.oscillation_rate)
	new_layer.set_oscillation_offset(source_layer.oscillation_offset)
	new_layer.title = "%s Copy" % source_layer.title
	new_layer.resolution = source_layer.resolution
	new_layer.speed = source_layer.speed

	new_layer.build_nebula(export_resolution)
	new_layer.noise_texture.noise.seed = source_layer.noise_texture.noise.seed

	# UI manager removed
	layers.append(new_layer)
	nebula_layers.append(new_layer)


# duplicate_planet_layer removed - not needed


func reorder_layer(layer : GeneratorLayer, direction : int) -> void:
	layer_container.move_child(layer, layer.get_index() + direction)


func load_preset(preset_data : Dictionary) -> void:
	for layer : Node in layer_container.get_children():
		layer.queue_free()

	layers.clear()
	star_layers.clear()
	nebula_layers.clear()
	# planet_layers and ui_manager removed

	var parsed_preset_data : Dictionary =\
			PresetUtiltity.decode_preset(preset_data)
	var new_layers : Array[GeneratorLayer] = parsed_preset_data["new_layers"]

	var ordered_new_layers : Array[GeneratorLayer] = []
	for i : int in new_layers.size(): ordered_new_layers.append(null)
	for layer: GeneratorLayer in new_layers:
		ordered_new_layers[layer.index] = layer

	for layer : GeneratorLayer in ordered_new_layers:
		layers.append(layer)
		layer_container.add_child(layer)
		if layer is StarLayer:
			# UI manager removed
			layer.generate_stars\
					(layer.max_stars, layer.ratio.duplicate(),
					export_resolution)
			star_layers.append(layer)
		elif layer is NebulaLayer:
			# UI manager removed
			layer.build_nebula(export_resolution)
			nebula_layers.append(layer)
		# Planet layer support removed

	# UI manager preset updates removed


# upload_preset removed - no JavaScript utility or UI


# export functions removed - no JavaScript utility needed


# export_as_png removed - no JavaScript utility


# export_as_packed_scene removed


# export_as_preset removed - no JavaScript utility or UI
