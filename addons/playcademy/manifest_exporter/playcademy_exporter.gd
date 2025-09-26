@tool
class_name PlaycademyManifestExporter
extends EditorExportPlugin

var _folder_target := ""
var _manifest_bytes: PackedByteArray
var _skip_zip_due_to_dirty_dir := false # New flag to control zipping

func _get_name():
	return "PlaycademyManifestExporter"

func _supports_platform(platform):
	if platform is EditorExportPlatformWeb:
		return true
	return false

## Helper function to get normalized Godot version
func _get_normalized_godot_version(is_debug: bool) -> String:
	var engine_version_info = Engine.get_version_info()
	var godot_version_string = "unknown"
	
	if engine_version_info.has("string"):
		var raw_version = engine_version_info["string"]
		var parenthesis_index = raw_version.find("(")
		if parenthesis_index != -1:
			godot_version_string = raw_version.substr(0, parenthesis_index).strip_edges()
		else:
			godot_version_string = raw_version
	else:
		if is_debug:
			print("PLAYCADEMY-PLUGIN: Could not determine Godot version string.")
	
	return godot_version_string

## Called once per export
func _export_begin(_features: PackedStringArray,
				   is_debug: bool,
				   output_path: String,
				   _flags: int) -> void:

	_skip_zip_due_to_dirty_dir = false # Reset flag at the start of each export

	if output_path.get_extension() == "zip":
		if is_debug:
			print("PLAYCADEMY-PLUGIN: Manifest file generation will be skipped for initial ZIP export.")
		_folder_target = ""
		return

	var base_output_dir = output_path.get_base_dir()
	if base_output_dir.is_empty() or not base_output_dir.is_absolute_path():
		# If base_output_dir is empty (e.g. export to root "index.html") or relative (e.g. "test")
		# Prepend "res://" to make it a project-relative path before globalizing.
		# If it was empty, it becomes "res://.", if it was "test", it becomes "res://test"
		if base_output_dir.is_empty():
			base_output_dir = "." # Treat as project root
		_folder_target = ProjectSettings.globalize_path("res://" + base_output_dir.trim_prefix("./").trim_prefix("res://"))
	else:
		# output_path.get_base_dir() was already an absolute system path
		_folder_target = base_output_dir

	# If, after all that, _folder_target somehow resolved to just res:// (e.g. from res://.)
	# ensure it points to the actual globalized project root directory for file system operations.
	if _folder_target == ProjectSettings.globalize_path("res://") : 
		_folder_target = ProjectSettings.globalize_path("res://.")

	_folder_target = _folder_target.simplify_path()

	if _folder_target.is_empty(): # Should not happen with above logic, but as a fallback
		_folder_target = ProjectSettings.globalize_path("res://.") 
		print("PLAYCADEMY-PLUGIN: Warning - _folder_target was empty, defaulted to project root.")

	if is_debug and _skip_zip_due_to_dirty_dir:
		print("PLAYCADEMY-PLUGIN: Final absolute export folder target for manifest: %s" % _folder_target)

	# --- BEGIN SAFETY CHECK FOR EXPORT PATH ---
	if DirAccess.dir_exists_absolute(_folder_target):
		var dir_handle = DirAccess.open(_folder_target)
		var pre_existing_content_found := false
		if dir_handle:
			dir_handle.list_dir_begin()
			var item_name = dir_handle.get_next()
			while item_name != "":
				if item_name != "." and item_name != "..":
					pre_existing_content_found = true
					break
				item_name = dir_handle.get_next()
			dir_handle.list_dir_end()

		if pre_existing_content_found: 
			print("PLAYCADEMY-PLUGIN: WARNING - NON-EMPTY EXPORT DIRECTORY DETECTED")
			print("PLAYCADEMY-PLUGIN: Your selected export path is currently set to:")
			print("PLAYCADEMY-PLUGIN: %s" % _folder_target)
			print("PLAYCADEMY-PLUGIN: This directory contains EXISTING FILES/FOLDERS.")
			print("PLAYCADEMY-PLUGIN: The Playcademy Manifest Exporter plugin cannot guarantee the fidelity of your export.")
			print("PLAYCADEMY-PLUGIN: Please manually review and zip the contents of your export before uploading to the PlayCademy platform.")
			_skip_zip_due_to_dirty_dir = true
	# --- END SAFETY CHECK ---
	
	var godot_version_string = _get_normalized_godot_version(is_debug)
	
	# Determine entry point relative to the _folder_target if possible, or just the file name
	var entry_point_file = output_path.get_file()
	
	var manifest := {
		"version": "1",
		"bootMode": "iframe",
		"entryPoint": entry_point_file, 
		"styles": [],
		"platform": "godot@%s" % godot_version_string,
		"createdAt": Time.get_datetime_string_from_system(true, true)
	}

	_manifest_bytes = JSON.stringify(manifest, "\t").to_utf8_buffer()
	
# Recursive zipping helper function
# counter is an array with one int element [0] to pass by reference
func _zip_directory_recursive(packer: ZIPPacker, local_current_dir: String, zip_path_prefix: String, counter: Array) -> bool:
	var dir = DirAccess.open(local_current_dir)
	if not dir:
		push_error("PLAYCADEMY-PLUGIN: ZIP: Failed to open directory: %s" % local_current_dir)
		return false

	dir.list_dir_begin()
	var item_name = dir.get_next()
	var success = true

	while item_name != "":
		if item_name == "." or item_name == "..":
			item_name = dir.get_next()
			continue

		var local_item_path = local_current_dir.path_join(item_name)
		var zip_item_path = zip_path_prefix.path_join(item_name)

		if dir.current_is_dir():
			var dir_err = packer.start_file(zip_item_path + "/") # Add trailing slash for directories
			if dir_err != OK:
				push_error("PLAYCADEMY-PLUGIN: ZIP: Failed to start directory %s in ZIP. Error: %s" % [zip_item_path, dir_err])
				success = false
				break # Stop processing this directory on error
			dir_err = packer.close_file() # Close directory entry
			if dir_err != OK:
				push_error("PLAYCADEMY-PLUGIN: ZIP: Failed to close directory %s in ZIP. Error: %s" % [zip_item_path, dir_err])
				success = false
				break
			# Recurse
			if not _zip_directory_recursive(packer, local_item_path, zip_item_path, counter):
				success = false
				break
		else: # It's a file
			var file_to_add = FileAccess.open(local_item_path, FileAccess.READ)
			if not file_to_add:
				push_error("PLAYCADEMY-PLUGIN: ZIP: Failed to open file for zipping: %s" % local_item_path)
				success = false
				break
			
			var start_err = packer.start_file(zip_item_path)
			if start_err != OK:
				push_error("PLAYCADEMY-PLUGIN: ZIP: Failed to start file %s in ZIP. Error: %s" % [zip_item_path, start_err])
				file_to_add.close()
				success = false
				break

			const CHUNK_SIZE = 4096
			while not file_to_add.eof_reached():
				var chunk = file_to_add.get_buffer(CHUNK_SIZE)
				var write_err = packer.write_file(chunk)
				if write_err != OK:
					push_error("PLAYCADEMY-PLUGIN: ZIP: Failed to write chunk to %s in ZIP. Error: %s" % [zip_item_path, write_err])
					success = false
					break # Stop writing this file
			
			var close_file_err = packer.close_file()
			if close_file_err != OK:
				push_error("PLAYCADEMY-PLUGIN: ZIP: Failed to close file %s in ZIP. Error: %s" % [zip_item_path, close_file_err])
				success = false
			# Break from while loop if writing or closing file failed
			if not success: break

			if success: # Only increment if all operations for this file succeeded
				counter[0] += 1
			
			file_to_add.close()
			
			if not success: break # Stop processing directory if a file op failed

		item_name = dir.get_next()
	
	dir.list_dir_end()
	return success

func _export_end() -> void:
	if _folder_target.is_empty():
		_skip_zip_due_to_dirty_dir = false
		return

	var manifest_path := _folder_target.path_join("playcademy.manifest.json")
	var file := FileAccess.open(manifest_path, FileAccess.WRITE)
	if file is FileAccess:
		file.store_buffer(_manifest_bytes)
		file.close()
	else:
		push_error("PLAYCADEMY-PLUGIN: could not write %s" % manifest_path)
		_skip_zip_due_to_dirty_dir = false
		return 

	if _skip_zip_due_to_dirty_dir:
		_skip_zip_due_to_dirty_dir = false
		return

	var export_dir_name = _folder_target.get_file() 
	var parent_dir_path = _folder_target.get_base_dir()

	if export_dir_name.is_empty() or export_dir_name == ".":
		export_dir_name = ProjectSettings.get_setting("application/config/name", "godot_export")
		if parent_dir_path.is_empty() or parent_dir_path == _folder_target:
			print("PLAYCADEMY-PLUGIN: Warning - Cannot reliably determine parent directory for zipping project root. Skipping auto-zip.")
			return
	
	var zip_file_name = export_dir_name + "_playcademy" + ".zip"
	var zip_file_path = parent_dir_path.path_join(zip_file_name)

	var packer = ZIPPacker.new()
	var err = packer.open(zip_file_path, ZIPPacker.APPEND_CREATE)
	if err != OK:
		push_error("PLAYCADEMY-PLUGIN: Could not create/open ZIP file with ZIPPacker at %s. Error code: %s" % [zip_file_path, err])
		return

	var files_added_counter_array = [0] # Use array as a hacky pass-by-reference for int
	
	var overall_success = _zip_directory_recursive(packer, _folder_target, export_dir_name, files_added_counter_array)

	var close_err = packer.close()
	if close_err != OK:
		push_error("PLAYCADEMY-PLUGIN: Failed to finalize/close ZIP file %s via ZIPPacker. Error: %s" % [zip_file_path, close_err])
		overall_success = false

	if overall_success:
		print("PLAYCADEMY-PLUGIN: Successfully created ZIP file: %s" % zip_file_path)
		var remove_err = DirAccess.remove_absolute(manifest_path)
		if remove_err != OK:
			push_error("PLAYCADEMY-PLUGIN: Failed to delete manifest file: %s. Error: %s" % [manifest_path, remove_err])
	else:
		print("PLAYCADEMY-PLUGIN: ZIP creation process encountered errors for %s." % zip_file_path)

	_skip_zip_due_to_dirty_dir = false
