extends Node

# Preloaded sound resources
var tick_sound = preload("res://assets/sounds/Tick.wav")
var correct_sound = preload("res://assets/sounds/Correct.wav")
var incorrect_sound = preload("res://assets/sounds/Incorrect.wav")

# AudioStreamPlayer for SFX
var sfx_player: AudioStreamPlayer

func _ready():
	# Create AudioStreamPlayer for SFX
	sfx_player = AudioStreamPlayer.new()
	sfx_player.bus = "SFX"  # Use the SFX audio bus
	add_child(sfx_player)

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
