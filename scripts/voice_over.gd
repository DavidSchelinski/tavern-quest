extends Node

## Voice-over manager.
##
## Audio files are expected at:
##   res://assets/audio/voice/{locale}/{key}.ogg
##
## Example:
##   res://assets/audio/voice/de/BARTENDER_GREETING.ogg
##   res://assets/audio/voice/en/BARTENDER_GREETING.ogg
##
## Usage:
##   VoiceOver.play("BARTENDER_GREETING")              # one-shot, creates temp player
##   VoiceOver.play("BARTENDER_GREETING", my_player)   # uses existing AudioStreamPlayer
##   var p = VoiceOver.get_voice_path("BARTENDER_GREETING")

const VO_BASE_PATH := "res://assets/audio/voice/"


## Play a voice line. If no AudioStreamPlayer is given, a temporary one is created.
func play(key: String, player: AudioStreamPlayer = null) -> void:
	var stream := _load_stream(key)
	if stream == null:
		return
	if player == null:
		player = AudioStreamPlayer.new()
		add_child(player)
		player.finished.connect(player.queue_free)
	player.stream = stream
	player.play()


## Play a positional voice line in 3D space.
func play_3d(key: String, player: AudioStreamPlayer3D) -> void:
	var stream := _load_stream(key)
	if stream == null:
		return
	player.stream = stream
	player.play()


## Returns the expected file path for a voice key in the given locale.
func get_voice_path(key: String, locale: String = "") -> String:
	if locale.is_empty():
		locale = TranslationServer.get_locale()
	return VO_BASE_PATH + locale + "/" + key + ".ogg"


## Check if a voice file exists for the given key.
func has_voice(key: String, locale: String = "") -> bool:
	return ResourceLoader.exists(get_voice_path(key, locale))


func _load_stream(key: String) -> AudioStream:
	var locale := TranslationServer.get_locale()
	var path := get_voice_path(key, locale)
	if ResourceLoader.exists(path):
		return load(path) as AudioStream
	# Fallback to default locale
	var fallback := get_voice_path(key, "de")
	if ResourceLoader.exists(fallback):
		return load(fallback) as AudioStream
	return null
