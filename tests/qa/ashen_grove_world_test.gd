extends SceneTree

const WORLD_SCENE: PackedScene = preload("res://scenes/survival/world_session.tscn")


func _initialize() -> void:
	call_deferred("_run_checks")


func _run_checks() -> void:
	var failures: Array[String] = []
	var session: WorldSession = WORLD_SCENE.instantiate() as WorldSession
	root.add_child(session)
	for _frame: int in 5:
		await physics_frame
	var pois: Array[RegionPoiData] = session.region.get_pois()
	if pois.size() != 12 or not session.region.poi_catalog.is_valid_catalog():
		failures.append("Ashen Grove does not expose twelve valid authored POIs.")
	var landmarks: Node = session.region.get_node_or_null("Landmarks")
	for poi: RegionPoiData in pois:
		var root_name: String = "Poi_%s" % String(poi.poi_id)
		var poi_root: Node = landmarks.get_node_or_null(root_name) if landmarks != null else null
		if poi_root == null or poi_root.get_node_or_null("StoryRuneDecal") == null:
			failures.append("POI geometry or story decal is missing: %s." % poi.poi_id)
		session.player.global_position = poi.world_position + Vector3.UP * 0.2
		session.region_discovery._physics_process(1.0)
		if not session.region_discovery.is_discovered(poi.poi_id):
			failures.append("POI discovery failed: %s." % poi.poi_id)
	var verticality: StaticBody3D = session.region.get_node_or_null("AuthoredVerticality") as StaticBody3D
	if verticality == null or verticality.get_child_count() < 10:
		failures.append("Authored hills, ramps, and bridge collisions are incomplete.")
	var forest: MultiMeshInstance3D = session.region.get_node_or_null(
		"BoundaryForest/ForestInstances"
	) as MultiMeshInstance3D
	if forest == null or forest.multimesh == null or forest.multimesh.instance_count != 32:
		failures.append("Boundary forest is not batched into the expected MultiMesh.")
	var resources: Array[ResourceNode] = session.region.get_persistent_resources()
	if resources.size() != 18:
		failures.append("Expected eighteen redistributed resource nodes.")
	var near_spawn_resource: bool = false
	for resource_node: ResourceNode in resources:
		if resource_node.global_position.distance_to(session.region.get_spawn_position()) <= 25.0:
			near_spawn_resource = true
			break
	if not near_spawn_resource:
		failures.append("The first refuge still requires an empty resource run.")
	var navigation_map: RID = session.region.get_world_3d().navigation_map
	if NavigationServer3D.map_get_iteration_id(navigation_map) == 0:
		failures.append("Navigation map did not synchronize before POI validation.")
	for poi: RegionPoiData in pois:
		var path: PackedVector3Array = NavigationServer3D.map_get_path(
			navigation_map,
			session.region.get_spawn_position(),
			poi.world_position,
			true
		)
		if path.is_empty():
			failures.append("Navigation cannot reach POI: %s." % poi.poi_id)
	session.weather_director.force_weather(WeatherDirector.Weather.ASH_RAIN)
	var environment: Environment = (session.get_node("WorldEnvironment") as WorldEnvironment).environment
	if environment.fog_density > 0.0121:
		failures.append("Weather fog exceeds the authored telegraph-readability cap.")
	session.weather_director.force_weather(WeatherDirector.Weather.CORRUPTION_FOG)
	if session.weather_director.current_weather != WeatherDirector.Weather.CORRUPTION_FOG:
		failures.append("Corruption fog state did not activate.")
	print("ASHEN GROVE WORLD: pois=%d resources=%d landmarks=%d nav_map=%s" % [
		pois.size(), resources.size(), landmarks.get_child_count(), navigation_map.is_valid()
	])
	session.queue_free()
	await process_frame
	await process_frame
	await create_timer(0.2).timeout
	SyntheticAudio.release_cached_streams()
	UiTranslations.release_registered()
	if failures.is_empty():
		print("ASHEN GROVE WORLD TEST PASSED")
		quit(0)
		return
	for failure: String in failures:
		push_error(failure)
	quit(1)
