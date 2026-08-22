extends GutTest

const POI_CATALOG: RegionPoiCatalog = preload("res://resources/survival/regions/ashen_grove_pois.tres")
const PLAYER_SCENE: PackedScene = preload("res://scenes/characters/player/player.tscn")


func test_ashen_grove_catalog_has_twelve_unique_authored_landmarks() -> void:
	assert_true(POI_CATALOG.is_valid_catalog())
	assert_eq(POI_CATALOG.points.size(), 12)
	var kinds: Dictionary[int, bool] = {}
	var moods: Dictionary[int, bool] = {}
	for poi: RegionPoiData in POI_CATALOG.points:
		assert_true(absf(poi.world_position.x) <= 90.0)
		assert_true(absf(poi.world_position.z) <= 90.0)
		assert_false(poi.loot_hint.is_empty())
		kinds[poi.kind] = true
		moods[poi.audio_mood] = true
	assert_eq(kinds.size(), 12)
	assert_eq(moods.size(), 5)


func test_discovery_uses_stable_flags_and_survives_world_state_round_trip() -> void:
	var player: MagePlayer = PLAYER_SCENE.instantiate() as MagePlayer
	add_child_autofree(player)
	var world_state: WorldState = WorldState.new()
	add_child_autofree(world_state)
	var discovery: RegionDiscovery = RegionDiscovery.new()
	add_child_autofree(discovery)
	var target: RegionPoiData = POI_CATALOG.get_poi(&"dead_moonwell")
	player.global_position = target.world_position
	discovery.bind(player, world_state, POI_CATALOG)
	discovery._physics_process(1.0)
	assert_true(discovery.is_discovered(target.poi_id))
	var snapshot: Dictionary = world_state.serialize_state()
	var restored: WorldState = WorldState.new()
	add_child_autofree(restored)
	restored.apply_state(snapshot)
	assert_true(restored.has_progression_flag(RegionDiscovery._flag_for(target.poi_id)))


func test_weather_states_have_distinct_particle_profiles() -> void:
	var director: WeatherDirector = WeatherDirector.new()
	add_child_autofree(director)
	director.force_weather(WeatherDirector.Weather.ASH_RAIN)
	assert_true((director.get_node("AshRain") as GPUParticles3D).emitting)
	assert_false((director.get_node("CorruptionMist") as GPUParticles3D).emitting)
	director.force_weather(WeatherDirector.Weather.CORRUPTION_FOG)
	assert_false((director.get_node("AshRain") as GPUParticles3D).emitting)
	assert_true((director.get_node("CorruptionMist") as GPUParticles3D).emitting)
	director.force_weather(WeatherDirector.Weather.CLEAR_WITCH_NIGHT)
	assert_false((director.get_node("AshRain") as GPUParticles3D).emitting)
	assert_false((director.get_node("CorruptionMist") as GPUParticles3D).emitting)


func test_region_audio_moods_use_cached_looping_streams() -> void:
	var streams: Array[AudioStreamWAV] = []
	for mood: int in RegionPoiData.AudioMood.size():
		var stream: AudioStreamWAV = SyntheticAudio.create_region_ambience(mood)
		assert_not_null(stream)
		assert_eq(stream.loop_mode, AudioStreamWAV.LOOP_FORWARD)
		assert_eq(SyntheticAudio.create_region_ambience(mood), stream)
		streams.append(stream)
	assert_ne(streams[0], streams[1])
