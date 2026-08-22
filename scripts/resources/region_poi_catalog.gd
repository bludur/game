class_name RegionPoiCatalog
extends Resource

@export var points: Array[RegionPoiData] = []


func get_poi(poi_id: StringName) -> RegionPoiData:
	for poi: RegionPoiData in points:
		if poi != null and poi.poi_id == poi_id:
			return poi
	return null


func is_valid_catalog() -> bool:
	var ids: Dictionary[StringName, bool] = {}
	for poi: RegionPoiData in points:
		if poi == null or not poi.is_valid_definition() or ids.has(poi.poi_id):
			return false
		ids[poi.poi_id] = true
	return not points.is_empty()
