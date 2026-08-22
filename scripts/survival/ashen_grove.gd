class_name AshenGrove
extends Node3D

@export var region_data: RegionData

var _ground_material: StandardMaterial3D
var _stone_material: StandardMaterial3D
var _wood_material: StandardMaterial3D
var _crypt_seal: MeshInstance3D


func _ready() -> void:
	_build_palette()
	_build_ground()
	_build_boundaries()
	_build_landmarks()


func get_region_id() -> StringName:
	return region_data.region_id if region_data != null else &"unknown"


func get_spawn_position() -> Vector3:
	return region_data.spawn_position if region_data != null else Vector3.ZERO


func get_persistent_resources() -> Array[ResourceNode]:
	var result: Array[ResourceNode] = []
	for child: Node in get_node("Resources").get_children():
		if child is ResourceNode:
			result.append(child as ResourceNode)
	return result


func set_crypt_unsealed(unsealed: bool) -> void:
	if is_instance_valid(_crypt_seal):
		_crypt_seal.visible = not unsealed


func _build_palette() -> void:
	_ground_material = _make_material(Color(0.075, 0.095, 0.085, 1.0), 0.94)
	_stone_material = _make_material(Color(0.16, 0.14, 0.2, 1.0), 0.84)
	_wood_material = _make_material(Color(0.13, 0.075, 0.095, 1.0), 0.92)


func _build_ground() -> void:
	var body: StaticBody3D = StaticBody3D.new()
	body.name = "Ground"
	body.collision_layer = 1
	body.collision_mask = 0
	add_child(body)
	var visual: MeshInstance3D = MeshInstance3D.new()
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = Vector3(192.0, 0.5, 192.0)
	visual.mesh = mesh
	visual.material_override = _ground_material
	visual.position.y = -0.25
	body.add_child(visual)
	var collision: CollisionShape3D = CollisionShape3D.new()
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = Vector3(192.0, 0.5, 192.0)
	collision.shape = shape
	collision.position.y = -0.25
	body.add_child(collision)
	for path_data: Dictionary in [
		{"position": Vector3(0, 0.015, 26), "size": Vector3(8, 0.04, 68)},
		{"position": Vector3(-22, 0.02, -8), "size": Vector3(52, 0.04, 7)},
		{"position": Vector3(27, 0.02, -37), "size": Vector3(64, 0.04, 6)},
	]:
		var path: MeshInstance3D = MeshInstance3D.new()
		var path_mesh: BoxMesh = BoxMesh.new()
		path_mesh.size = path_data["size"] as Vector3
		path.mesh = path_mesh
		path.position = path_data["position"] as Vector3
		path.material_override = _make_material(Color(0.115, 0.09, 0.12, 1.0), 1.0)
		add_child(path)


func _build_boundaries() -> void:
	var boundary_root: Node3D = Node3D.new()
	boundary_root.name = "BoundaryForest"
	add_child(boundary_root)
	for index: int in 32:
		var angle: float = TAU * float(index) / 32.0
		var radius: float = 89.0
		var position_3d: Vector3 = Vector3(cos(angle) * radius, 0.0, sin(angle) * radius)
		var trunk: MeshInstance3D = _create_cylinder(0.75, 4.5 + float(index % 4), _wood_material)
		trunk.position = position_3d + Vector3.UP * 2.2
		trunk.rotation_degrees.z = float((index % 5) - 2) * 4.0
		boundary_root.add_child(trunk)
	var collision_root: StaticBody3D = StaticBody3D.new()
	collision_root.name = "WorldBounds"
	collision_root.collision_layer = 1
	collision_root.collision_mask = 0
	add_child(collision_root)
	_add_wall_collision(collision_root, Vector3(0, 2, -94), Vector3(192, 4, 2))
	_add_wall_collision(collision_root, Vector3(0, 2, 94), Vector3(192, 4, 2))
	_add_wall_collision(collision_root, Vector3(-94, 2, 0), Vector3(2, 4, 192))
	_add_wall_collision(collision_root, Vector3(94, 2, 0), Vector3(2, 4, 192))


func _build_landmarks() -> void:
	var landmarks: Node3D = Node3D.new()
	landmarks.name = "Landmarks"
	add_child(landmarks)
	_build_awakening_circle(landmarks, Vector3(0, 0.0, 58))
	_build_hearth_clearing(landmarks, Vector3(-24, 0.0, 8))
	_build_ruins(landmarks, Vector3(29, 0.0, 17))
	_build_bog(landmarks, Vector3(-42, 0.0, -35))
	_build_crypt_gate(landmarks, Vector3(42, 0.0, -56))


func _build_awakening_circle(parent: Node3D, center: Vector3) -> void:
	var ring: MeshInstance3D = MeshInstance3D.new()
	var mesh: TorusMesh = TorusMesh.new()
	mesh.inner_radius = 4.2
	mesh.outer_radius = 4.55
	mesh.rings = 40
	mesh.ring_segments = 6
	ring.mesh = mesh
	ring.position = center + Vector3.UP * 0.04
	ring.material_override = _make_emissive(Color(0.48, 0.2, 0.9, 1.0), 2.0)
	parent.add_child(ring)


func _build_hearth_clearing(parent: Node3D, center: Vector3) -> void:
	for index: int in 6:
		var angle: float = TAU * float(index) / 6.0
		var stone: MeshInstance3D = _create_box(Vector3(1.1, 1.8, 1.1), _stone_material)
		stone.position = center + Vector3(cos(angle) * 7.0, 0.9, sin(angle) * 7.0)
		stone.rotation_degrees.y = rad_to_deg(-angle)
		parent.add_child(stone)


func _build_ruins(parent: Node3D, center: Vector3) -> void:
	for offset: Vector3 in [Vector3(-6, 2.5, -4), Vector3(6, 2.5, -4), Vector3(-6, 2.5, 4), Vector3(6, 2.5, 4)]:
		var pillar: MeshInstance3D = _create_box(Vector3(1.6, 5.0, 1.6), _stone_material)
		pillar.position = center + offset
		parent.add_child(pillar)
	var lintel: MeshInstance3D = _create_box(Vector3(13.5, 1.2, 1.6), _stone_material)
	lintel.position = center + Vector3(0, 5.2, -4)
	parent.add_child(lintel)


func _build_bog(parent: Node3D, center: Vector3) -> void:
	var pool: MeshInstance3D = _create_cylinder(10.0, 0.12, _make_emissive(Color(0.08, 0.32, 0.28, 1.0), 0.45))
	pool.position = center + Vector3.UP * 0.03
	parent.add_child(pool)
	for index: int in 5:
		var stump: MeshInstance3D = _create_cylinder(0.42, 2.0 + index * 0.25, _wood_material)
		stump.position = center + Vector3(-6.0 + index * 3.0, 1.0, float((index % 2) * 4 - 2))
		parent.add_child(stump)


func _build_crypt_gate(parent: Node3D, center: Vector3) -> void:
	for x: float in [-4.0, 4.0]:
		var tower: MeshInstance3D = _create_box(Vector3(3, 7, 3), _stone_material)
		tower.position = center + Vector3(x, 3.5, 0)
		parent.add_child(tower)
	var arch: MeshInstance3D = _create_box(Vector3(11, 2, 3), _stone_material)
	arch.position = center + Vector3(0, 7, 0)
	parent.add_child(arch)
	_crypt_seal = _create_box(Vector3(5, 5, 0.35), _make_emissive(Color(0.58, 0.12, 0.86, 1.0), 1.7))
	_crypt_seal.position = center + Vector3(0, 2.5, -1.45)
	parent.add_child(_crypt_seal)


func _create_box(size: Vector3, material: Material) -> MeshInstance3D:
	var visual: MeshInstance3D = MeshInstance3D.new()
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = size
	visual.mesh = mesh
	visual.material_override = material
	return visual


func _create_cylinder(radius: float, height: float, material: Material) -> MeshInstance3D:
	var visual: MeshInstance3D = MeshInstance3D.new()
	var mesh: CylinderMesh = CylinderMesh.new()
	mesh.top_radius = radius * 0.72
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 8
	visual.mesh = mesh
	visual.material_override = material
	return visual


func _add_wall_collision(parent: StaticBody3D, position_3d: Vector3, size: Vector3) -> void:
	var collision: CollisionShape3D = CollisionShape3D.new()
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	collision.position = position_3d
	parent.add_child(collision)


func _make_material(color: Color, roughness: float) -> StandardMaterial3D:
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	return material


func _make_emissive(color: Color, energy: float) -> StandardMaterial3D:
	var material: StandardMaterial3D = _make_material(color.darkened(0.35), 0.66)
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = energy
	return material
