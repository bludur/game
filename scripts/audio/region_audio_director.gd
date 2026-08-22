class_name RegionAudioDirector
extends Node

var current_mood: RegionPoiData.AudioMood = RegionPoiData.AudioMood.WILDS
var _player: MagePlayer
var _catalog: RegionPoiCatalog
var _players: Array[AudioStreamPlayer] = []
var _active_index: int = 0
var _check_remaining: float = 0.0
var _crossfade: Tween


func _ready() -> void:
	for index: int in 2:
		var player: AudioStreamPlayer = AudioStreamPlayer.new()
		player.name = "RegionAmbience%d" % index
		player.bus = &"Ambience"
		player.volume_db = -32.0
		add_child(player)
		_players.append(player)
	set_process(false)


func bind(player: MagePlayer, catalog: RegionPoiCatalog) -> void:
	_player = player
	_catalog = catalog
	set_process(is_instance_valid(_player) and _catalog != null)
	_play_mood(RegionPoiData.AudioMood.WILDS, true)


func _process(delta: float) -> void:
	_check_remaining -= delta
	if _check_remaining > 0.0 or not is_instance_valid(_player):
		return
	_check_remaining = 0.35
	var next_mood: RegionPoiData.AudioMood = RegionPoiData.AudioMood.WILDS
	var nearest_distance_squared: float = INF
	for poi: RegionPoiData in _catalog.points:
		var offset: Vector3 = _player.global_position - poi.world_position
		offset.y = 0.0
		var distance_squared: float = offset.length_squared()
		if distance_squared <= poi.audio_radius * poi.audio_radius \
				and distance_squared < nearest_distance_squared:
			nearest_distance_squared = distance_squared
			next_mood = poi.audio_mood
	if next_mood != current_mood:
		_play_mood(next_mood)


func _play_mood(mood: RegionPoiData.AudioMood, immediate: bool = false) -> void:
	current_mood = mood
	var incoming_index: int = 1 - _active_index
	var outgoing: AudioStreamPlayer = _players[_active_index]
	var incoming: AudioStreamPlayer = _players[incoming_index]
	incoming.stream = SyntheticAudio.create_region_ambience(int(mood))
	incoming.volume_db = -32.0
	incoming.play()
	if _crossfade != null:
		_crossfade.kill()
	if immediate:
		outgoing.stop()
		incoming.volume_db = -14.0
		_active_index = incoming_index
		return
	_crossfade = create_tween().set_parallel(true)
	_crossfade.tween_property(outgoing, "volume_db", -32.0, 1.2)
	_crossfade.tween_property(incoming, "volume_db", -14.0, 1.2)
	_crossfade.chain().tween_callback(outgoing.stop)
	_active_index = incoming_index


func _exit_tree() -> void:
	if _crossfade != null:
		_crossfade.kill()
	for player: AudioStreamPlayer in _players:
		player.stop()
		player.stream = null
