@tool
@icon("res://addons/playcademy/manifest_exporter/icon.svg")
extends EditorPlugin

var exporter: PlaycademyManifestExporter = null

const PLUGIN_NAME := "Playcademy Manifest Exporter"
const PLUGIN_ICON := preload("res://addons/playcademy/manifest_exporter/icon.svg")

func _get_plugin_icon():
	return PLUGIN_ICON

func _get_plugin_name():
	return PLUGIN_NAME

func _enter_tree() -> void:
	exporter = PlaycademyManifestExporter.new()
	add_export_plugin(exporter)

func _exit_tree() -> void:
	remove_export_plugin(exporter)
	exporter = null
