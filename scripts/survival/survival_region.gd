class_name SurvivalRegion
extends Node3D

@export var region_data: RegionData
@export var poi_catalog: RegionPoiCatalog


func get_region_id() -> StringName:
	return region_data.region_id if region_data != null else &"unknown"


func get_spawn_position() -> Vector3:
	return region_data.spawn_position if region_data != null else Vector3.ZERO


func get_persistent_resources() -> Array[ResourceNode]:
	var result: Array[ResourceNode] = []
	var resources: Node = get_node_or_null("Resources")
	if resources == null:
		return result
	for child: Node in resources.get_children():
		if child is ResourceNode:
			result.append(child as ResourceNode)
	return result


func get_pois() -> Array[RegionPoiData]:
	return poi_catalog.points if poi_catalog != null else []


func get_poi_position(poi_id: StringName) -> Vector3:
	var poi: RegionPoiData = poi_catalog.get_poi(poi_id) if poi_catalog != null else null
	return poi.world_position if poi != null else Vector3.ZERO


func get_hearths() -> Array[WitchfireHearth]:
	var result: Array[WitchfireHearth] = []
	for child: Node in find_children("*", "WitchfireHearth", true, false):
		if child is WitchfireHearth:
			result.append(child as WitchfireHearth)
	return result


func set_crypt_unsealed(_unsealed: bool) -> void:
	pass
