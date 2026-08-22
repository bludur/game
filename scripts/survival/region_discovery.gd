class_name RegionDiscovery
extends Node

signal poi_discovered(poi: RegionPoiData)

@export_range(0.1, 1.0, 0.05) var check_interval: float = 0.25

var _player: MagePlayer
var _world_state: WorldState
var _catalog: RegionPoiCatalog
var _remaining: float = 0.0


func bind(player: MagePlayer, world_state: WorldState, catalog: RegionPoiCatalog) -> void:
	_player = player
	_world_state = world_state
	_catalog = catalog
	set_physics_process(is_instance_valid(_player) and _world_state != null and _catalog != null)


func _physics_process(delta: float) -> void:
	_remaining -= delta
	if _remaining > 0.0 or not is_instance_valid(_player):
		return
	_remaining = check_interval
	for poi: RegionPoiData in _catalog.points:
		if poi == null or is_discovered(poi.poi_id):
			continue
		var offset: Vector3 = _player.global_position - poi.world_position
		offset.y = 0.0
		if offset.length_squared() <= poi.discovery_radius * poi.discovery_radius:
			_world_state.set_progression_flag(_flag_for(poi.poi_id))
			poi_discovered.emit(poi)


func is_discovered(poi_id: StringName) -> bool:
	return _world_state != null and _world_state.has_progression_flag(_flag_for(poi_id))


static func _flag_for(poi_id: StringName) -> StringName:
	return StringName("poi_%s_discovered" % String(poi_id))
