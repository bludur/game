class_name ArenaAudioDirector
extends Node

@onready var _music_player: AudioStreamPlayer = get_node("MusicPlayer") as AudioStreamPlayer
@onready var _ambience_player: AudioStreamPlayer = get_node("AmbiencePlayer") as AudioStreamPlayer


func _ready() -> void:
	_music_player.stream = SyntheticAudio.create_music_loop()
	_ambience_player.stream = SyntheticAudio.create_ambience()
	_music_player.play()
	_ambience_player.play()
	call_deferred("_bind_boss_encounter")


func _bind_boss_encounter() -> void:
	var encounter: BossEncounter = get_tree().get_first_node_in_group(&"boss_encounter") as BossEncounter
	if not is_instance_valid(encounter):
		return
	encounter.boss_spawned.connect(_on_boss_spawned)
	encounter.boss_defeated.connect(_on_boss_defeated)


func _on_boss_spawned(_boss: ArenaWarden) -> void:
	_music_player.pitch_scale = 1.12
	_music_player.volume_db = 2.0


func _on_boss_defeated() -> void:
	_music_player.pitch_scale = 1.0
	_music_player.volume_db = 0.0
