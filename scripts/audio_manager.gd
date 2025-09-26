extends Node

# Preloaded sound resources
var tick_sound = preload("res://assets/sounds/Tick.wav")
var correct_sound = preload("res://assets/sounds/Correct.wav")
var incorrect_sound = preload("res://assets/sounds/Incorrect.wav")
var get_sound = preload("res://assets/sounds/Get.wav")
var close_sound = preload("res://assets/sounds/Close.wav")

# Preloaded music resources
var background_music = preload("res://assets/music/Split.wav")

# AudioStreamPlayer for SFX and Music
var sfx_player: AudioStreamPlayer
var music_player: AudioStreamPlayer

func _ready():
	# Create AudioStreamPlayer for SFX
	sfx_player = AudioStreamPlayer.new()
	sfx_player.bus = "SFX"  # Use the SFX audio bus
	add_child(sfx_player)
	
	# Create AudioStreamPlayer for Music
	music_player = AudioStreamPlayer.new()
	music_player.bus = "Music"  # Use the Music audio bus
	music_player.stream = background_music
	add_child(music_player)
	
	# Start playing the music and connect to finished signal for looping
	if background_music:
		music_player.play()
		music_player.finished.connect(_on_music_finished)

# Play tick sound when user inputs/backspaces characters
func play_tick():
	if tick_sound:
		sfx_player.stream = tick_sound
		sfx_player.play()

# Play correct sound when user submits correct answer
func play_correct():
	if correct_sound:
		sfx_player.stream = correct_sound
		sfx_player.play()

# Play incorrect sound when user submits incorrect answer
func play_incorrect():
	if incorrect_sound:
		sfx_player.stream = incorrect_sound
		sfx_player.play()

# Play get sound when player earns a star
func play_get():
	if get_sound:
		sfx_player.stream = get_sound
		sfx_player.play()

# Play close sound when player doesn't earn a star
func play_close():
	if close_sound:
		sfx_player.stream = close_sound
		sfx_player.play()

# Callback function to restart music when it finishes (for looping)
func _on_music_finished():
	if music_player and background_music:
		music_player.play()
