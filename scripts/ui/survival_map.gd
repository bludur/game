class_name SurvivalMap
extends Control

var _player: MagePlayer
var _world_state: WorldState
var _poi_catalog: RegionPoiCatalog


func _ready() -> void:
	visibility_changed.connect(_sync_processing)
	_sync_processing()


func bind(player: MagePlayer, world_state: WorldState, poi_catalog: RegionPoiCatalog = null) -> void:
	_player = player
	_world_state = world_state
	_poi_catalog = poi_catalog
	queue_redraw()


func _process(_delta: float) -> void:
	queue_redraw()


func _sync_processing() -> void:
	set_process(is_visible_in_tree())
	if is_visible_in_tree():
		queue_redraw()


func _draw() -> void:
	var map_rect: Rect2 = Rect2(Vector2(18, 18), size - Vector2(36, 36))
	draw_rect(map_rect, Color(0.035, 0.045, 0.055, 0.96), true)
	draw_rect(map_rect, Color(0.42, 0.22, 0.58, 0.9), false, 3.0)
	_draw_discovery_fog(map_rect)
	if _poi_catalog != null:
		for poi: RegionPoiData in _poi_catalog.points:
			if not _is_poi_discovered(poi.poi_id):
				continue
			var point: Vector2 = _world_to_map(
				Vector2(poi.world_position.x, poi.world_position.z), map_rect
			)
			draw_circle(point, 5.0, poi.map_color)
			draw_string(
				ThemeDB.fallback_font,
				point + Vector2(8, 4),
				_poi_name(poi),
				HORIZONTAL_ALIGNMENT_LEFT,
				-1,
				13,
				Color(0.88, 0.84, 0.94)
			)
	if is_instance_valid(_player):
		var player_point: Vector2 = _world_to_map(Vector2(_player.global_position.x, _player.global_position.z), map_rect)
		draw_circle(player_point, 7.0, Color(1, 0.88, 0.28))
		draw_circle(player_point, 10.0, Color(1, 0.88, 0.28, 0.5), false, 2.0)
	if _world_state != null and _world_state.has_progression_flag(&"matriarch_defeated"):
		draw_string(ThemeDB.fallback_font, map_rect.position + Vector2(12, 24), tr("MAP_GROVE_CLEANSED"), HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(0.3, 1, 0.72))


func _world_to_map(world: Vector2, map_rect: Rect2) -> Vector2:
	var normalized: Vector2 = Vector2(
		clampf((world.x + 96.0) / 192.0, 0.0, 1.0),
		clampf((world.y + 96.0) / 192.0, 0.0, 1.0)
	)
	return map_rect.position + Vector2(normalized.x * map_rect.size.x, normalized.y * map_rect.size.y)


func _draw_discovery_fog(map_rect: Rect2) -> void:
	const CELL_COUNT: int = 16
	var cell_size: Vector2 = map_rect.size / float(CELL_COUNT)
	for y: int in CELL_COUNT:
		for x: int in CELL_COUNT:
			var normalized: Vector2 = (Vector2(x, y) + Vector2(0.5, 0.5)) / float(CELL_COUNT)
			var world_point: Vector2 = normalized * 192.0 - Vector2(96.0, 96.0)
			if _is_world_point_revealed(world_point):
				continue
			draw_rect(
				Rect2(map_rect.position + Vector2(x, y) * cell_size, cell_size + Vector2.ONE),
				Color(0.006, 0.008, 0.016, 0.92),
				true
			)


func _is_world_point_revealed(world_point: Vector2) -> bool:
	if is_instance_valid(_player):
		var player_point: Vector2 = Vector2(_player.global_position.x, _player.global_position.z)
		if player_point.distance_squared_to(world_point) <= 12.0 * 12.0:
			return true
	if _poi_catalog == null:
		return false
	for poi: RegionPoiData in _poi_catalog.points:
		if not _is_poi_discovered(poi.poi_id):
			continue
		var poi_point: Vector2 = Vector2(poi.world_position.x, poi.world_position.z)
		var reveal_radius: float = poi.discovery_radius * 1.45
		if poi_point.distance_squared_to(world_point) <= reveal_radius * reveal_radius:
			return true
	return false


func _is_poi_discovered(poi_id: StringName) -> bool:
	return _world_state != null \
		and _world_state.has_progression_flag(RegionDiscovery._flag_for(poi_id))


func _poi_name(poi: RegionPoiData) -> String:
	var key: String = "MAP_POI_%s" % String(poi.poi_id).to_upper()
	var translated: String = tr(key)
	return poi.display_name if translated == key else translated
