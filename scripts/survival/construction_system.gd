class_name ConstructionSystem
extends Node3D

signal build_mode_changed(active: bool)
signal selection_changed(piece: BuildingPieceData)
signal piece_built(piece: BuildingPiece)
signal piece_removed(persistent_id: StringName)
signal placement_failed(reason: StringName)

@export var catalog: BuildingCatalog
@export_range(0.5, 4.0, 0.5) var grid_size: float = 1.0
@export_range(2.0, 8.0, 0.5) var placement_distance: float = 4.0

var build_mode: bool = false
var selected_index: int = 0
var _player: MagePlayer
var _inventory: InventoryComponent
var _world_state: WorldState
var _preview: MeshInstance3D
var _preview_material: StandardMaterial3D
var _placement_transform: Transform3D
var _placement_valid: bool = false
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


func bind(player: MagePlayer, inventory: InventoryComponent, world_state: WorldState) -> void:
	_player = player
	_inventory = inventory
	_world_state = world_state
	_refresh_preview_mesh()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"build_mode"):
		set_build_mode(not build_mode)
		get_viewport().set_input_as_handled()
		return
	if not build_mode:
		return
	if event.is_action_pressed(&"interact"):
		confirm_placement()
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
	var forward: Vector3 = -_player.global_basis.z
	forward.y = 0.0
	var target: Vector3 = _player.global_position + forward.normalized() * placement_distance
	target.x = snappedf(target.x, grid_size)
	target.z = snappedf(target.z, grid_size)
	target.y = 0.0
	_placement_transform = Transform3D(Basis(Vector3.UP, float(_rotation_steps) * PI * 0.5), target)
	_preview.transform = _placement_transform
	_preview.position.y += definition.size.y * 0.5
	_placement_valid = definition.can_build(_inventory) and _has_ground_support(definition, target) \
		and not _intersects_world(definition, _placement_transform)
	_preview_material.albedo_color = Color(0.18, 0.9, 0.55, 0.42) if _placement_valid \
		else Color(0.95, 0.16, 0.28, 0.42)


func set_build_mode(active: bool) -> void:
	build_mode = active and catalog != null and not catalog.pieces.is_empty()
	_preview.visible = build_mode
	set_physics_process(build_mode)
	build_mode_changed.emit(build_mode)


func cycle_selection(direction: int) -> void:
	if catalog == null or catalog.pieces.is_empty():
		return
	selected_index = wrapi(selected_index + direction, 0, catalog.pieces.size())
	_refresh_preview_mesh()
	selection_changed.emit(get_selected_piece())


func get_selected_piece() -> BuildingPieceData:
	if catalog == null or selected_index < 0 or selected_index >= catalog.pieces.size():
		return null
	return catalog.pieces[selected_index]


func confirm_placement() -> bool:
	var definition: BuildingPieceData = get_selected_piece()
	if definition == null or not _placement_valid:
		placement_failed.emit(&"invalid_placement")
		return false
	for ingredient: ItemAmountData in definition.ingredients:
		_inventory.remove_by_id(ingredient.item.item_id, ingredient.quantity)
	var piece: BuildingPiece = BuildingPiece.new()
	var instance_id: StringName = StringName("build_%04d_%s" % [_next_instance_number, definition.piece_id])
	_next_instance_number += 1
	piece.configure(definition, instance_id, _placement_transform)
	add_child(piece)
	piece_built.emit(piece)
	_sync_world_state()
	return true


func dismantle_piece(piece: BuildingPiece) -> bool:
	if not is_instance_valid(piece) or piece.get_parent() != self:
		return false
	for refund: Dictionary in piece.get_refund():
		_inventory.add_item(refund["item"] as ItemData, int(refund["quantity"]))
	var removed_id: StringName = piece.persistent_id
	piece.queue_free()
	piece_removed.emit(removed_id)
	call_deferred("_sync_world_state")
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
		piece.configure(definition, instance_id, placement)
		add_child(piece)
		piece_built.emit(piece)
		var id_parts: PackedStringArray = String(instance_id).split("_")
		if id_parts.size() > 1:
			highest_id = maxi(highest_id, int(id_parts[1]))
	_next_instance_number = highest_id + 1
	_sync_world_state()


func _refresh_preview_mesh() -> void:
	var definition: BuildingPieceData = get_selected_piece()
	if definition == null or not is_instance_valid(_preview):
		return
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = definition.size
	_preview.mesh = mesh


func _has_ground_support(definition: BuildingPieceData, target: Vector3) -> bool:
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(
		target + Vector3.UP * maxf(1.0, definition.size.y),
		target + Vector3.DOWN * 0.4,
		1
	)
	return not get_world_3d().direct_space_state.intersect_ray(query).is_empty()


func _intersects_world(definition: BuildingPieceData, placement: Transform3D) -> bool:
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = definition.size * 0.92
	var query: PhysicsShapeQueryParameters3D = PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.transform = placement.translated_local(Vector3.UP * (definition.size.y * 0.5 + 0.04))
	query.collision_mask = 1
	query.collide_with_areas = false
	query.collide_with_bodies = true
	return not get_world_3d().direct_space_state.intersect_shape(query, 8).is_empty()


func _sync_world_state() -> void:
	if _world_state == null:
		return
	var states: Array[Dictionary] = []
	for child: Node in get_children():
		if child is BuildingPiece and not child.is_queued_for_deletion():
			states.append((child as BuildingPiece).serialize_state())
	_world_state.building_states = states
	_world_state.state_changed.emit()
