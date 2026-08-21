class_name ArenaAudioDirector
extends Node

@onready var _music_player: AudioStreamPlayer = get_node("MusicPlayer") as AudioStreamPlayer
@onready var _ambience_player: AudioStreamPlayer = get_node("AmbiencePlayer") as AudioStreamPlayer


func _ready() -> void:
	_music_player.stream = SyntheticAudio.create_music_loop()
	_ambience_player.stream = SyntheticAudio.create_ambience()
	_music_player.play()
	_ambience_player.play()
