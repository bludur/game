class_name ArenaAudioDirector
extends Node

@onready var _music_player: AudioStreamPlayer = get_node("MusicPlayer") as AudioStreamPlayer
@onready var _ambience_player: AudioStreamPlayer = get_node("AmbiencePlayer") as AudioStreamPlayer
@onready var _result_player: AudioStreamPlayer = get_node("ResultPlayer") as AudioStreamPlayer


func _ready() -> void:
	_music_player.stream = SyntheticAudio.create_music_loop()
	_ambience_player.stream = SyntheticAudio.create_ambience()
	_music_player.play()
	_ambience_player.play()
	call_deferred("_bind_boss_encounter")
	call_deferred("_bind_run_director")


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


func _bind_run_director() -> void:
	var director: RunDirector = get_tree().get_first_node_in_group(&"run_director") as RunDirector
	if not is_instance_valid(director):
		return
	director.victory_reached.connect(_on_victory)
	director.defeat_reached.connect(_on_defeat)
	director.run_restarted.connect(_on_run_restarted)


func _on_victory() -> void:
	_music_player.pitch_scale = 1.04
	_music_player.volume_db = -2.0
	_result_player.stream = SyntheticAudio.create_victory()
	_result_player.play()


func _on_defeat() -> void:
	_music_player.pitch_scale = 0.86
	_music_player.volume_db = -5.0
	_result_player.stream = SyntheticAudio.create_defeat_result()
	_result_player.play()


func _on_run_restarted() -> void:
	_music_player.pitch_scale = 1.0
	_music_player.volume_db = 0.0


func _exit_tree() -> void:
	for player: AudioStreamPlayer in [_music_player, _ambience_player, _result_player]:
		if is_instance_valid(player):
			player.stop()
			player.stream = null
