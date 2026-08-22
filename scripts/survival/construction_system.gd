class_name ConstructionSystem
extends Node3D

signal build_mode_changed(active: bool)
signal selection_changed(piece: BuildingPieceData)
signal category_changed(category: int)
signal piece_built(piece: BuildingPiece)
signal piece_removed(persistent_id: StringName)
signal placement_failed(reason: StringName)
signal functional_piece_used(piece: BuildingPiece, interactor: MagePlayer)

@export var catalog: BuildingCatalog
@export_range(0.5, 4.0, 0.5) var grid_size: float = 1.0
@export_range(2.0, 24.0, 0.5) var placement_distance: float = 14.0
@export_range(0.25, 2.0, 0.05) var snap_distance: float = 1.15

var build_mode: bool = false
var selected_index: int = 0
var active_category: int = BuildingPieceData.Category.FOUNDATIONS
var placement_reason: StringName = &"ready"
var _player: MagePlayer
var _inventory: InventoryComponent
var _world_state: WorldState
var _item_catalog: ItemCatalog
var _preview: MeshInstance3D
var _preview_material: StandardMaterial3D
var _placement_transform: Transform3D
var _placement_valid: bool = false
var _placement_support_level: int = BuildingPiece.SupportLevel.GROUNDED
var _rotation_steps: int = 0
var _next_instance_number: int = 1


func _ready() -> void:
	_preview = MeshInstance3D.new()
	_preview.name = "PlacementPreview"
	_preview.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_preview.visible = false
	_preview_material = StandardMaterial3D.new()
	_preview_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_preview_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_preview.material_override = _preview_material
	add_child(_preview)
	set_physics_process(false)


func bind(
	player: MagePlayer,
	inventory: InventoryComponent,
	world_state: WorldState,
	item_catalog: ItemCatalog = null
) -> void:
	_player = player
	_inventory = inventory
	_world_state = world_state
	_item_catalog = item_catalog
	_select_first_piece_in_category(active_category)
	_refresh_preview_mesh()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"build_mode"):
		set_build_mode(not build_mode)
		get_viewport().set_input_as_handled()


func _input(event: InputEvent) -> void:
	if not build_mode:
		return
	if event.is_action_pressed(&"interact"):
		confirm_placement()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed(&"build_repair"):
		repair_focused_piece()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed(&"build_dismantle"):
		dismantle_focused_piece()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed(&"build_category_foundations"):
		select_category(BuildingPieceData.Category.FOUNDATIONS)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed(&"build_category_walls"):
		select_category(BuildingPieceData.Category.WALLS)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed(&"build_category_roofs"):
		select_category(BuildingPieceData.Category.ROOFS)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed(&"build_category_stations"):
		select_category(BuildingPieceData.Category.STATIONS)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed(&"build_category_magic"):
		select_category(BuildingPieceData.Category.MAGIC)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed(&"camera_rotate_left"):
		_rotation_steps = wrapi(_rotation_steps + 1, 0, 4)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed(&"camera_rotate_right"):
		_rotation_steps = wrapi(_rotation_steps - 1, 0, 4)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed(&"camera_zoom_in"):
		cycle_selection(-1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed(&"camera_zoom_out"):
		cycle_selection(1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed(&"ritual"):
		set_build_mode(false)
		get_viewport().set_input_as_handled()


func _physics_process(_delta: float) -> void:
	if not build_mode or not is_instance_valid(_player):
		return
	var definition: BuildingPieceData = get_selected_piece()
	if definition == null:
		return
	var basis: Basis = Basis(Vector3.UP, float(_rotation_steps) * PI * 0.5)
	var raw_target: Vector3 = _get_camera_placement_target()
	var snap_result: Dictionary = _find_snap_target(raw_target)
	var target: Vector3
	var support_piece: BuildingPiece
	if snap_result.is_empty():
		target = Vector3(
			snappedf(raw_target.x, grid_size),
			raw_target.y,
			snappedf(raw_target.z, grid_size)
		)
	else:
		target = snap_result["position"] as Vector3 - basis * definition.snap_offset
		support_piece = snap_result["piece"] as BuildingPiece
	_placement_transform = Transform3D(basis, target)
	_preview.transform = _placement_transform
	_preview.position.y += definition.size.y * 0.5
	_placement_support_level = _resolve_support_level(target, support_piece)
	placement_reason = _get_placement_reason(definition)
	_placement_valid = placement_reason == &"ready"
	_preview_material.albedo_color = Color(0.18, 0.9, 0.55, 0.42) if _placement_valid \
		else Color(0.95, 0.16, 0.28, 0.42)


func _get_camera_placement_target() -> Vector3:
	var camera: Camera3D = get_viewport().get_camera_3d()
	if is_instance_valid(camera):
		var viewport_center: Vector2 = get_viewport().get_visible_rect().size * 0.5
		var ray_origin: Vector3 = camera.project_ray_origin(viewport_center)
		var ray_direction: Vector3 = camera.project_ray_normal(viewport_center).normalized()
		var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(
			ray_origin,
			ray_origin + ray_direction * placement_distance,
			1
		)
		query.exclude = [_player.get_rid()]
		var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
		if not hit.is_empty():
			return hit["position"] as Vector3
		var ground_intersection: Variant = Plane(Vector3.UP, 0.0).intersects_ray(ray_origin, ray_direction)
		if ground_intersection is Vector3 \
				and ray_origin.distance_to(ground_intersection as Vector3) <= placement_distance * 1.5:
			return ground_intersection as Vector3
	var forward: Vector3 = _get_placement_forward()
	return _player.global_position + forward.normalized() * minf(placement_distance, 5.0)


func _get_placement_forward() -> Vector3:
	var camera: Camera3D = get_viewport().get_camera_3d()
	if is_instance_valid(camera) and camera.projection == Camera3D.PROJECTION_PERSPECTIVE:
		var camera_forward: Vector3 = -camera.global_basis.z
		camera_forward.y = 0.0
		if camera_forward.length_squared() > 0.001:
			return camera_forward.normalized()
	return -_player.global_basis.z


func set_build_mode(active: bool) -> void:
	build_mode = active and catalog != null and not catalog.pieces.is_empty()
	_preview.visible = build_mode
	set_physics_process(build_mode)
	if is_instance_valid(_player):
		_player.set_build_mode(build_mode)
	build_mode_changed.emit(build_mode)


func select_category(category: int) -> void:
	if category < BuildingPieceData.Category.FOUNDATIONS \
			or category > BuildingPieceData.Category.MAGIC:
		return
	active_category = category
	_select_first_piece_in_category(category)
	_refresh_preview_mesh()
	category_changed.emit(active_category)
	selection_changed.emit(get_selected_piece())


func cycle_selection(direction: int) -> void:
	var indexes: Array[int] = _category_indexes(active_category)
	if indexes.is_empty():
		return
	var category_index: int = indexes.find(selected_index)
	category_index = 0 if category_index < 0 else wrapi(category_index + direction, 0, indexes.size())
	selected_index = indexes[category_index]
	_refresh_preview_mesh()
	selection_changed.emit(get_selected_piece())


func get_selected_piece() -> BuildingPieceData:
	if catalog == null or selected_index < 0 or selected_index >= catalog.pieces.size():
		return null
	return catalog.pieces[selected_index]


func get_category_pieces(category: int) -> Array[BuildingPieceData]:
	var results: Array[BuildingPieceData] = []
	if catalog == null:
		return results
	for definition: BuildingPieceData in catalog.pieces:
		if definition != null and definition.category == category:
			results.append(definition)
	return results


func confirm_placement() -> bool:
	var definition: BuildingPieceData = get_selected_piece()
	if definition == null or not _placement_valid:
		placement_failed.emit(placement_reason if definition != null else &"no_selection")
		return false
	for ingredient: ItemAmountData in definition.ingredients:
		_inventory.remove_by_id(ingredient.item.item_id, ingredient.quantity)
	var piece: BuildingPiece = BuildingPiece.new()
	var instance_id: StringName = StringName("build_%04d_%s" % [_next_instance_number, definition.piece_id])
	_next_instance_number += 1
	piece.configure(definition, instance_id, _placement_transform, _item_catalog)
	piece.support_level = _placement_support_level
	_register_piece(piece)
	piece_built.emit(piece)
	_sync_world_state()
	return true


func repair_focused_piece() -> bool:
	var piece: BuildingPiece = get_focused_piece()
	if piece == null or not piece.repair(_inventory):
		placement_failed.emit(&"repair_unavailable")
		return false
	return true


func dismantle_focused_piece() -> bool:
	var piece: BuildingPiece = get_focused_piece()
	if piece == null:
		placement_failed.emit(&"nothing_focused")
		return false
	return dismantle_piece(piece)


func get_focused_piece() -> BuildingPiece:
	var camera: Camera3D = get_viewport().get_camera_3d()
	if not is_instance_valid(camera):
		return null
	var center: Vector2 = get_viewport().get_visible_rect().size * 0.5
	var origin: Vector3 = camera.project_ray_origin(center)
	var direction: Vector3 = camera.project_ray_normal(center).normalized()
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(
		origin,
		origin + direction * placement_distance,
		1
	)
	query.exclude = [_player.get_rid()] if is_instance_valid(_player) else []
	var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
	var collider: Object = hit.get("collider") as Object
	return collider as BuildingPiece if collider is BuildingPiece else null


func dismantle_piece(piece: BuildingPiece) -> bool:
	if not is_instance_valid(piece) or piece.get_parent() != self:
		return false
	for refund: Dictionary in piece.get_refund():
		var item: ItemData = refund["item"] as ItemData
		var quantity: int = int(refund["quantity"])
		var overflow: int = _inventory.add_item(item, quantity)
		if overflow > 0:
			placement_failed.emit(&"refund_inventory_full")
	var removed_id: StringName = piece.persistent_id
	piece.queue_free()
	piece_removed.emit(removed_id)
	_sync_world_state()
	return true


func restore_buildings(states: Array) -> void:
	for child: Node in get_children():
		if child is BuildingPiece:
			child.queue_free()
	var highest_id: int = 0
	for raw_state: Variant in states:
		if raw_state is not Dictionary:
			continue
		var state: Dictionary = raw_state as Dictionary
		var definition: BuildingPieceData = catalog.get_piece(StringName(String(state.get("piece_id", ""))))
		if definition == null:
			continue
		var position_data: Dictionary = state.get("position", {}) as Dictionary
		var placement: Transform3D = Transform3D(
			Basis(Vector3.UP, float(state.get("rotation_y", 0.0))),
			Vector3(
				float(position_data.get("x", 0.0)),
				float(position_data.get("y", 0.0)),
				float(position_data.get("z", 0.0))
			)
		)
		var piece: BuildingPiece = BuildingPiece.new()
		var instance_id: StringName = StringName(String(state.get("persistent_id", "")))
		piece.configure(definition, instance_id, placement, _item_catalog)
		piece.apply_runtime_state(state)
		_register_piece(piece)
		piece_built.emit(piece)
		var id_parts: PackedStringArray = String(instance_id).split("_")
		if id_parts.size() > 1:
			highest_id = maxi(highest_id, int(id_parts[1]))
	_next_instance_number = highest_id + 1
	_sync_world_state()


func evaluate_support_level(target: Vector3, support_piece: BuildingPiece = null) -> int:
	return _resolve_support_level(target, support_piece)


func flush_world_state() -> void:
	_sync_world_state()


func _register_piece(piece: BuildingPiece) -> void:
	add_child(piece)
	piece.state_changed.connect(_on_piece_state_changed)
	piece.function_requested.connect(_on_piece_function_requested)


func _on_piece_state_changed(_piece: BuildingPiece) -> void:
	_sync_world_state()


func _on_piece_function_requested(piece: BuildingPiece, interactor: MagePlayer) -> void:
	functional_piece_used.emit(piece, interactor)


func _refresh_preview_mesh() -> void:
	var definition: BuildingPieceData = get_selected_piece()
	if definition == null or not is_instance_valid(_preview):
		return
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = definition.size
	_preview.mesh = mesh


func _find_snap_target(target: Vector3) -> Dictionary:
	var closest_distance_squared: float = snap_distance * snap_distance
	var result: Dictionary = {}
	for child: Node in get_children():
		if child is not BuildingPiece or child.is_queued_for_deletion():
			continue
		var piece: BuildingPiece = child as BuildingPiece
		for snap_point: Vector3 in piece.get_snap_points():
			var distance_squared: float = target.distance_squared_to(snap_point)
			if distance_squared <= closest_distance_squared:
				closest_distance_squared = distance_squared
				result = {"position": snap_point, "piece": piece}
	return result


func _resolve_support_level(target: Vector3, support_piece: BuildingPiece) -> int:
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(
		target + Vector3.UP * 0.35,
		target + Vector3.DOWN * 0.65,
		1
	)
	if is_instance_valid(_player):
		query.exclude = [_player.get_rid()]
	var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
	var collider: Object = hit.get("collider") as Object if not hit.is_empty() else null
	if not hit.is_empty() and collider is not BuildingPiece:
		return BuildingPiece.SupportLevel.GROUNDED
	if is_instance_valid(support_piece):
		return support_piece.support_level + 1 \
			if support_piece.support_level < BuildingPiece.SupportLevel.EXTENDED else -1
	if collider is BuildingPiece:
		var piece: BuildingPiece = collider as BuildingPiece
		return piece.support_level + 1 if piece.support_level < BuildingPiece.SupportLevel.EXTENDED else -1
	return -1


func _get_placement_reason(definition: BuildingPieceData) -> StringName:
	if not definition.can_build(_inventory):
		return &"missing_resources"
	if _placement_support_level < BuildingPiece.SupportLevel.GROUNDED \
			or _placement_support_level > BuildingPiece.SupportLevel.EXTENDED:
		return &"unsupported"
	if _intersects_world(definition, _placement_transform):
		return &"obstructed"
	return &"ready"


func _intersects_world(definition: BuildingPieceData, placement: Transform3D) -> bool:
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = definition.size * 0.92
	var query: PhysicsShapeQueryParameters3D = PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.transform = placement.translated_local(Vector3.UP * (definition.size.y * 0.5 + 0.04))
	query.collision_mask = 1
	query.collide_with_areas = false
	query.collide_with_bodies = true
	if is_instance_valid(_player):
		query.exclude = [_player.get_rid()]
	return not get_world_3d().direct_space_state.intersect_shape(query, 8).is_empty()


func _category_indexes(category: int) -> Array[int]:
	var indexes: Array[int] = []
	if catalog == null:
		return indexes
	for index: int in catalog.pieces.size():
		var definition: BuildingPieceData = catalog.pieces[index]
		if definition != null and definition.category == category:
			indexes.append(index)
	return indexes


func _select_first_piece_in_category(category: int) -> void:
	var indexes: Array[int] = _category_indexes(category)
	if not indexes.is_empty():
		selected_index = indexes[0]


func _sync_world_state() -> void:
	if _world_state == null:
		return
	var states: Array[Dictionary] = []
	for child: Node in get_children():
		if child is BuildingPiece and not child.is_queued_for_deletion():
			states.append((child as BuildingPiece).serialize_state())
	_world_state.building_states = states
	_world_state.state_changed.emit()
