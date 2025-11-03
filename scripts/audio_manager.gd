extends Node

# Preloaded sound resources
var tick_sound = preload("res://assets/sounds/Tick.wav")
var correct_sound = preload("res://assets/sounds/Correct.wav")
var incorrect_sound = preload("res://assets/sounds/Incorrect.wav")
var get_sound = preload("res://assets/sounds/Get.wav")
var close_sound = preload("res://assets/sounds/Close.wav")
var blip_sound = preload("res://assets/sounds/Blip.wav")
var select_sound = preload("res://assets/sounds/Select.wav")

# Preloaded music resources
var background_music = preload("res://assets/music/Split.ogg")

# AudioStreamPlayer pool for SFX and Music
var sfx_player_pool: Array[AudioStreamPlayer] = []
var music_player: AudioStreamPlayer
var max_sfx_players = 8  # Maximum number of simultaneous sound effects

func _ready():
	# Create pool of AudioStreamPlayer instances for SFX
	for i in range(max_sfx_players):
		var player = AudioStreamPlayer.new()
		player.bus = "SFX"  # Use the SFX audio bus
		add_child(player)
		sfx_player_pool.append(player)
	
	# Create AudioStreamPlayer for Music
	music_player = AudioStreamPlayer.new()
	music_player.bus = "Music"  # Use the Music audio bus
	music_player.stream = background_music
	add_child(music_player)
	
	# Connect to finished signal for looping
	if background_music:
		music_player.finished.connect(_on_music_finished)
	
	# Note: Music will be started by main.gd after volume settings are loaded

func start_music():
	"""Start playing the background music (called after volume is initialized)"""
	if background_music and music_player and not music_player.playing:
		music_player.play()

# Get an available AudioStreamPlayer from the pool
func get_available_sfx_player() -> AudioStreamPlayer:
	# First, try to find a player that's not currently playing
	for player in sfx_player_pool:
		if not player.playing:
			return player
	
	# If all players are busy, return the first one (it will be interrupted)
	# This provides a fallback in case we exceed max_sfx_players simultaneous sounds
	return sfx_player_pool[0]

# Play tick sound when user inputs/backspaces characters
func play_tick():
	if tick_sound:
		var player = get_available_sfx_player()
		player.stream = tick_sound
		player.play()

# Play correct sound when user submits correct answer
func play_correct():
	if correct_sound:
		var player = get_available_sfx_player()
		player.stream = correct_sound
		player.play()

# Play incorrect sound when user submits incorrect answer
func play_incorrect():
	if incorrect_sound:
		var player = get_available_sfx_player()
		player.stream = incorrect_sound
		player.play()

# Play get sound when player earns a star
func play_get():
	if get_sound:
		var player = get_available_sfx_player()
		player.stream = get_sound
		player.play()

# Play close sound when player doesn't earn a star
func play_close():
	if close_sound:
		var player = get_available_sfx_player()
		player.stream = close_sound
		player.play()

# Play blip sound when button is hovered
func play_blip():
	if blip_sound:
		var player = get_available_sfx_player()
		player.stream = blip_sound
		player.play()

# Play select sound when button is clicked
func play_select():
	if select_sound:
		var player = get_available_sfx_player()
		player.stream = select_sound
		player.play()

# Callback function to restart music when it finishes (for looping)
func _on_music_finished():
	if music_player and background_music:
		music_player.play()
