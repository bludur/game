class_name SfxPool3D
extends Node3D

@export_range(1, 16, 1) var pool_size: int = 4
@export var bus: StringName = &"SFX"
@export_range(1.0, 100.0, 1.0) var max_distance: float = 30.0

var _players: Array[AudioStreamPlayer3D] = []
var _next_player_index: int = 0


func _ready() -> void:
	for _index: int in range(pool_size):
		var player: AudioStreamPlayer3D = AudioStreamPlayer3D.new()
		player.bus = bus
		player.max_distance = max_distance
		player.unit_size = 4.0
		player.max_polyphony = 2
		add_child(player)
		_players.append(player)


func play_sfx(stream: AudioStream, volume_db: float = 0.0) -> bool:
	if stream == null or _players.is_empty():
		return false

	var selected_player: AudioStreamPlayer3D
	for player: AudioStreamPlayer3D in _players:
		if not player.playing:
			selected_player = player
			break
	if selected_player == null:
		selected_player = _players[_next_player_index]
		_next_player_index = (_next_player_index + 1) % _players.size()

	selected_player.stream = stream
	selected_player.volume_db = volume_db
	selected_player.play()
	return true


func _exit_tree() -> void:
	for player: AudioStreamPlayer3D in _players:
		if is_instance_valid(player):
			player.stop()
			player.stream = null
	_players.clear()
