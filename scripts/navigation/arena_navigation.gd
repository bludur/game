class_name ArenaNavigation
extends NavigationRegion3D

@export_range(4.0, 64.0, 0.5) var arena_half_extent: float = 11.0
@export_range(0.5, 4.0, 0.25) var cell_size: float = 1.0
@export_range(0.0, 3.0, 0.05) var obstacle_clearance: float = 0.55


func _ready() -> void:
	rebuild_navigation_mesh()


func rebuild_navigation_mesh() -> void:
	var mesh: NavigationMesh = NavigationMesh.new()
	var vertices: PackedVector3Array = PackedVector3Array()
	var vertex_indices: Dictionary[Vector2i, int] = {}
	var polygons: Array[PackedInt32Array] = []
	var cell_count: int = floori(arena_half_extent * 2.0 / cell_size)

	for z_index: int in range(cell_count):
		for x_index: int in range(cell_count):
			var center: Vector3 = Vector3(
				-arena_half_extent + (float(x_index) + 0.5) * cell_size,
				0.0,
				-arena_half_extent + (float(z_index) + 0.5) * cell_size
			)
			if _is_cell_blocked(center):
				continue

			var polygon: PackedInt32Array = PackedInt32Array()
			polygon.append(_get_vertex_index(Vector2i(x_index, z_index), vertices, vertex_indices))
			polygon.append(_get_vertex_index(Vector2i(x_index, z_index + 1), vertices, vertex_indices))
			polygon.append(_get_vertex_index(Vector2i(x_index + 1, z_index + 1), vertices, vertex_indices))
			polygon.append(_get_vertex_index(Vector2i(x_index + 1, z_index), vertices, vertex_indices))
			polygons.append(polygon)

	mesh.vertices = vertices
	for polygon: PackedInt32Array in polygons:
		mesh.add_polygon(polygon)
	navigation_mesh = mesh


func _get_vertex_index(
	grid_position: Vector2i,
	vertices: PackedVector3Array,
	vertex_indices: Dictionary[Vector2i, int]
) -> int:
	if vertex_indices.has(grid_position):
		return vertex_indices[grid_position]

	var vertex_position: Vector3 = Vector3(
		-arena_half_extent + float(grid_position.x) * cell_size,
		0.0,
		-arena_half_extent + float(grid_position.y) * cell_size
	)
	var vertex_index: int = vertices.size()
	vertices.append(vertex_position)
	vertex_indices[grid_position] = vertex_index
	return vertex_index


func _is_cell_blocked(cell_center: Vector3) -> bool:
	for obstacle_node: Node in get_tree().get_nodes_in_group(&"navigation_obstacle"):
		if obstacle_node is not Node3D:
			continue
		var obstacle: Node3D = obstacle_node as Node3D
		var collision_shape: CollisionShape3D = obstacle.get_node_or_null("CollisionShape3D") as CollisionShape3D
		if collision_shape == null or collision_shape.disabled or collision_shape.shape == null:
			continue

		var obstacle_center: Vector3 = to_local(collision_shape.global_position)
		var half_size: Vector2 = _get_shape_half_size(collision_shape.shape)
		if half_size == Vector2.ZERO:
			continue
		var cell_margin: float = cell_size * 0.5 + obstacle_clearance
		if absf(cell_center.x - obstacle_center.x) <= half_size.x + cell_margin \
				and absf(cell_center.z - obstacle_center.z) <= half_size.y + cell_margin:
			return true
	return false


func _get_shape_half_size(shape: Shape3D) -> Vector2:
	if shape is BoxShape3D:
		var box: BoxShape3D = shape as BoxShape3D
		return Vector2(box.size.x, box.size.z) * 0.5
	if shape is CylinderShape3D:
		var cylinder: CylinderShape3D = shape as CylinderShape3D
		return Vector2.ONE * cylinder.radius
	if shape is CapsuleShape3D:
		var capsule: CapsuleShape3D = shape as CapsuleShape3D
		return Vector2.ONE * capsule.radius
	if shape is SphereShape3D:
		var sphere: SphereShape3D = shape as SphereShape3D
		return Vector2.ONE * sphere.radius
	return Vector2.ZERO
