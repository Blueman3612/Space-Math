extends Node

# Save system manager - handles all save/load operations and data persistence
# Game progress stored in KV storage (cloud), volumes stored locally (per-machine)

# Signals for async operations
signal save_data_loaded(success: bool)
signal save_data_saved(success: bool)
signal save_data_cleared(success: bool)

# Save system variables
var save_data = {}  # Game progress data (stored in KV)
var local_settings = {}  # Local settings like volumes (stored in local file)
var is_initialized = false
var is_loading = false
var pending_save = false
var has_unsaved_changes = false  # Track if KV data needs saving

# Local file paths
var local_settings_path = "user://local_settings.json"

func initialize():
	"""Initialize the save system and load data from KV storage and local file"""
	# Load local settings first (volumes, etc.)
	load_local_settings()
	
	if not PlaycademySdk:
		printerr("[SaveManager] PlaycademySdk not available!")
		save_data = get_default_save_data()
		is_initialized = true
		emit_signal("save_data_loaded", false)
		return
	
	# Connect to backend signals
	if PlaycademySdk.backend:
		PlaycademySdk.backend.request_succeeded.connect(_on_backend_request_succeeded)
		PlaycademySdk.backend.request_failed.connect(_on_backend_request_failed)
	
	# Load game progress from KV storage
	load_save_data()

func get_default_save_data():
	"""Return the default game progress data (stored in KV)"""
	var default_data = {
		"version": ProjectSettings.get_setting("application/config/version"),
		"save_structure": "pack_based",
		"packs": {},
		"questions": {}
	}
	
	# Initialize level data for all packs
	for pack_name in GameConfig.level_pack_order:
		var pack_config = GameConfig.level_packs[pack_name]
		default_data.packs[pack_name] = {
			"levels": {}
		}
		
		# Initialize each level in the pack using track ID as key
		for level_track in pack_config.levels:
			# Convert to string track ID (e.g., "4.NF.A.1" or "TRACK12")
			var track_id = str(level_track) if typeof(level_track) == TYPE_STRING else "TRACK" + str(level_track)
			default_data.packs[pack_name].levels[track_id] = {
				"highest_stars": 0,
				"best_accuracy": 0,
				"best_time": 999999.0,
				"best_cqpm": 0.0
			}
	
	return default_data

func get_default_local_settings():
	"""Return default local settings (volumes, stored locally per-machine)"""
	return {
		"sfx_volume": GameConfig.default_sfx_volume,
		"music_volume": GameConfig.default_music_volume
	}

func load_local_settings():
	"""Load local settings from file (volumes, etc.)"""
	if FileAccess.file_exists(local_settings_path):
		var file = FileAccess.open(local_settings_path, FileAccess.READ)
		if file:
			var json_string = file.get_as_text()
			file.close()
			
			var json = JSON.new()
			var parse_result = json.parse(json_string)
			if parse_result == OK:
				local_settings = json.data
				print("[SaveManager] Local settings loaded from file")
			else:
				print("[SaveManager] Error parsing local settings, using defaults")
				local_settings = get_default_local_settings()
		else:
			local_settings = get_default_local_settings()
	else:
		print("[SaveManager] No local settings file found, using defaults")
		local_settings = get_default_local_settings()
		save_local_settings()

func save_local_settings():
	"""Save local settings to file (immediate save, not queued)"""
	var file = FileAccess.open(local_settings_path, FileAccess.WRITE)
	if file:
		var json_string = JSON.stringify(local_settings, "\t")
		file.store_string(json_string)
		file.close()
		print("[SaveManager] Local settings saved to file")
	else:
		printerr("[SaveManager] Could not save local settings to file")

func load_save_data():
	"""Load save data from KV storage via backend API"""
	if is_loading:
		print("[SaveManager] Already loading save data...")
		return
	
	is_loading = true
	print("[SaveManager] Loading save data from KV storage...")
	
	if PlaycademySdk and PlaycademySdk.backend:
		PlaycademySdk.backend.request("/save", "GET")
	else:
		printerr("[SaveManager] Backend not available, using default save data")
		save_data = get_default_save_data()
		is_initialized = true
		is_loading = false
		emit_signal("save_data_loaded", false)

func save_save_data():
	"""Save game progress to KV storage (only if there are changes)"""
	if not is_initialized:
		print("[SaveManager] Cannot save - not initialized yet")
		pending_save = true
		return
	
	if is_loading:
		print("[SaveManager] Cannot save while loading")
		pending_save = true
		return
	
	if not has_unsaved_changes:
		print("[SaveManager] No unsaved changes, skipping KV save")
		return
	
	print("[SaveManager] Saving game progress to KV storage...")
	
	if PlaycademySdk and PlaycademySdk.backend:
		PlaycademySdk.backend.request("/save", "POST", save_data)
	else:
		printerr("[SaveManager] Backend not available, cannot save data")
		emit_signal("save_data_saved", false)

func _on_backend_request_succeeded(response):
	"""Handle successful backend API responses"""
	if not response or typeof(response) != TYPE_DICTIONARY:
		printerr("[SaveManager] Invalid response from backend")
		return
	
	var success = response.get("success", false)
	
	# Check if this was a load request (has data field)
	if response.has("data"):
		is_loading = false
		if success and response.data != null:
			print("[SaveManager] Save data loaded successfully from KV storage")
			save_data = response.data
			migrate_save_data()
			is_initialized = true
			emit_signal("save_data_loaded", true)
			
			# If there was a pending save, do it now
			if pending_save:
				pending_save = false
				save_save_data()
		else:
			print("[SaveManager] No save data found in KV storage, using defaults")
			save_data = get_default_save_data()
			is_initialized = true
			emit_signal("save_data_loaded", true)
			# Save the default data to KV storage
			save_save_data()
	
	# Check if this was a save request
	elif response.has("message") and "stored" in response.message.to_lower():
		print("[SaveManager] Game progress saved successfully to KV storage")
		has_unsaved_changes = false  # Clear dirty flag
		emit_signal("save_data_saved", true)
	
	# Check if this was a delete request
	elif response.has("message") and "cleared" in response.message.to_lower():
		print("[SaveManager] Save data cleared successfully from KV storage")
		emit_signal("save_data_cleared", true)

func _on_backend_request_failed(error_message: String):
	"""Handle failed backend API responses"""
	printerr("[SaveManager] Backend request failed: ", error_message)
	
	if is_loading:
		is_loading = false
		# If we couldn't load, use default data
		print("[SaveManager] Failed to load from KV storage, using default save data")
		save_data = get_default_save_data()
		is_initialized = true
		emit_signal("save_data_loaded", false)
	else:
		# Save failed
		emit_signal("save_data_saved", false)

func migrate_save_data():
	"""Handle save data migration for version changes"""
	var current_version = ProjectSettings.get_setting("application/config/version")
	var save_version = save_data.get("version", "0.0")
	var save_structure = save_data.get("save_structure", "legacy")
	
	# Check if this is an old save structure - wipe if not pack_based
	if save_structure != "pack_based":
		print("Old save structure detected - wiping all save data for pack-based system")
		save_data = get_default_save_data()
		has_unsaved_changes = true
		return
	
	# Version migration for pack-based saves
	if save_version != current_version:
		print("Migrating save data from version ", save_version, " to ", current_version)
		
		# Ensure all required fields exist
		if not save_data.has("packs"):
			save_data.packs = {}
		if not save_data.has("questions"):
			save_data.questions = {}
		
		# Remove old volume fields if they exist (now in local_settings)
		if save_data.has("sfx_volume"):
			save_data.erase("sfx_volume")
		if save_data.has("music_volume"):
			save_data.erase("music_volume")
		
		# Ensure all packs and levels have data
		for pack_name in GameConfig.level_pack_order:
			var pack_config = GameConfig.level_packs[pack_name]
			if not save_data.packs.has(pack_name):
				save_data.packs[pack_name] = {"levels": {}}
			
			var pack_data = save_data.packs[pack_name]
			if not pack_data.has("levels"):
				pack_data.levels = {}
			
			# Ensure all levels in pack have data using track ID as key
			for level_track in pack_config.levels:
				# Convert to string track ID (e.g., "4.NF.A.1" or "TRACK12")
				var track_id = str(level_track) if typeof(level_track) == TYPE_STRING else "TRACK" + str(level_track)
				if not pack_data.levels.has(track_id):
					pack_data.levels[track_id] = {
						"highest_stars": 0,
						"best_accuracy": 0,
						"best_time": 999999.0,
						"best_cqpm": 0.0
					}
				else:
					# Ensure all fields exist for existing levels
					var level_data = pack_data.levels[track_id]
					if not level_data.has("best_cqpm"):
						level_data.best_cqpm = 0.0
		
		# Update version
		save_data.version = current_version
		has_unsaved_changes = true

func save_question_data(question_data, player_answer, time_taken):
	"""Save data for a completed question (marks dirty, saved on level complete)"""
	var question_key = QuestionManager.get_question_key(question_data)
	
	if not save_data.questions.has(question_key):
		save_data.questions[question_key] = []
	
	var question_record = {
		"operands": question_data.get("operands", []),
		"operator": question_data.operator,
		"result": question_data.result,
		"player_answer": player_answer,
		"time_taken": time_taken,
		"timestamp": Time.get_unix_time_from_system()
	}
	
	# Add to the beginning of the array
	save_data.questions[question_key].push_front(question_record)
	
	# Keep only the last 5 answers
	if save_data.questions[question_key].size() > 5:
		save_data.questions[question_key] = save_data.questions[question_key].slice(0, 5)
	
	# Mark dirty but don't save yet (will save on level complete)
	has_unsaved_changes = true

func update_level_data(pack_name: String, pack_level_index: int, accuracy: int, time_taken: float, stars_earned: int):
	"""Update the saved data for a level using pack-based structure with track ID as key"""
	# Ensure pack exists
	if not save_data.packs.has(pack_name):
		save_data.packs[pack_name] = {"levels": {}}
	
	var pack_data = save_data.packs[pack_name]
	if not pack_data.has("levels"):
		pack_data.levels = {}
	
	# Get the track ID for this level
	var pack_config = GameConfig.level_packs[pack_name]
	var level_track = pack_config.levels[pack_level_index]
	var track_id = str(level_track) if typeof(level_track) == TYPE_STRING else "TRACK" + str(level_track)
	
	# Ensure level exists
	if not pack_data.levels.has(track_id):
		pack_data.levels[track_id] = {
			"highest_stars": 0,
			"best_accuracy": 0,
			"best_time": 999999.0,
			"best_cqpm": 0.0
		}
	
	var level_data = pack_data.levels[track_id]
	var updated = false
	
	# Update highest stars
	if stars_earned > level_data.highest_stars:
		level_data.highest_stars = stars_earned
		updated = true
	
	# Update best accuracy
	if accuracy > level_data.best_accuracy:
		level_data.best_accuracy = accuracy
		updated = true
	
	# Update best time
	if time_taken < level_data.best_time:
		level_data.best_time = time_taken
		updated = true
	
	# Calculate and update CQPM (Correct Questions Per Minute)
	var cqpm = 0.0
	if time_taken > 0:
		cqpm = (float(accuracy) / time_taken) * 60.0
	
	if cqpm > level_data.best_cqpm:
		level_data.best_cqpm = cqpm
		updated = true
	
	if updated:
		has_unsaved_changes = true
		# Save immediately on level complete (this is a good save point)
		save_save_data()

func update_drill_mode_high_score(drill_score: int) -> bool:
	"""Update drill mode high score in save data and return true if new high score"""
	if not save_data.has("drill_mode"):
		save_data.drill_mode = {"high_score": 0}
	
	var is_new_high_score = drill_score > save_data.drill_mode.high_score
	
	if is_new_high_score:
		save_data.drill_mode.high_score = drill_score
		has_unsaved_changes = true
		# Save immediately on drill mode complete (this is a good save point)
		save_save_data()
		print("New drill mode high score: ", drill_score)
	
	return is_new_high_score

func get_drill_mode_high_score() -> int:
	"""Get the current drill mode high score"""
	if save_data.has("drill_mode") and save_data.drill_mode.has("high_score"):
		return save_data.drill_mode.high_score
	return 0

func reset_all_data():
	"""Wipe all save data and reset to defaults"""
	print("Resetting all save data...")
	save_data = get_default_save_data()
	
	# Delete from KV storage and save new defaults
	if PlaycademySdk and PlaycademySdk.backend:
		PlaycademySdk.backend.request("/save", "DELETE")
		# After deletion, save the default data
		await get_tree().create_timer(0.5).timeout  # Small delay to ensure delete completes
		save_save_data()
	else:
		save_save_data()
	
	print("Save data reset complete!")

func unlock_all_levels():
	"""Unlock all levels with 3 stars (DEV ONLY)"""
	print("Unlocking all levels...")
	
	# Set all levels across all packs to have 3 stars and reasonable completion values
	var global_level_num = 1
	for pack_name in GameConfig.level_pack_order:
		var pack_config = GameConfig.level_packs[pack_name]
		
		# Ensure pack exists in save data
		if not save_data.packs.has(pack_name):
			save_data.packs[pack_name] = {"levels": {}}
		
		# Unlock each level in the pack using track ID as key
		for level_track in pack_config.levels:
			# Convert to string track ID (e.g., "4.NF.A.1" or "TRACK12")
			var track_id = str(level_track) if typeof(level_track) == TYPE_STRING else "TRACK" + str(level_track)
			var level_config = GameConfig.level_configs.get(global_level_num, GameConfig.level_configs[1])
			
			# Set each level to have 3 stars and max values
			save_data.packs[pack_name].levels[track_id] = {
				"highest_stars": 3,
				"best_accuracy": level_config.problems,  # Perfect accuracy
				"best_time": level_config.star3.time,  # Best time for 3 stars
				"best_cqpm": ScoreManager.calculate_cqpm(level_config.problems, level_config.star3.time)
			}
			
			global_level_num += 1
	
	save_save_data()
	print("All levels unlocked!")

func volume_to_db(volume: float) -> float:
	"""Convert volume (0.0-1.0) to decibels (-48 to 0) using moderately exponential scale"""
	if volume <= 0.0:
		return -80.0  # Effectively muted
	# Use a square root curve: -48 * (1 - sqrt(volume))
	# This creates a balanced exponential curve
	# At 25%: -24dB, At 50%: -14dB, At 75%: -7dB, At 100%: 0dB
	var db = -48.0 * (1.0 - sqrt(volume))
	return db

func set_sfx_volume(volume: float):
	"""Set SFX bus volume"""
	var bus_idx = AudioServer.get_bus_index("SFX")
	if bus_idx >= 0:
		if volume <= 0.0:
			# Mute the bus when slider is at minimum
			AudioServer.set_bus_mute(bus_idx, true)
		else:
			# Unmute and set volume
			AudioServer.set_bus_mute(bus_idx, false)
			var db = volume_to_db(volume)
			AudioServer.set_bus_volume_db(bus_idx, db)

func set_music_volume(volume: float):
	"""Set Music bus volume"""
	var bus_idx = AudioServer.get_bus_index("Music")
	if bus_idx >= 0:
		if volume <= 0.0:
			# Mute the bus when slider is at minimum
			AudioServer.set_bus_mute(bus_idx, true)
		else:
			# Unmute and set volume
			AudioServer.set_bus_mute(bus_idx, false)
			var db = volume_to_db(volume)
			AudioServer.set_bus_volume_db(bus_idx, db)

