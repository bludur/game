class_name AshenGrove
extends SurvivalRegion

var _ground_material: StandardMaterial3D
var _stone_material: StandardMaterial3D
var _wood_material: StandardMaterial3D
var _water_material: ShaderMaterial
var _rune_decal_texture: ImageTexture
var _crypt_seal: MeshInstance3D


func _ready() -> void:
	_build_palette()
	_build_ground()
	_build_boundaries()
	_build_verticality()
	_build_landmarks()


func set_crypt_unsealed(unsealed: bool) -> void:
	if is_instance_valid(_crypt_seal):
		_crypt_seal.visible = not unsealed


func _build_palette() -> void:
	_ground_material = _make_material(Color(0.075, 0.095, 0.085, 1.0), 0.94)
	_stone_material = _make_material(Color(0.16, 0.14, 0.2, 1.0), 0.84)
	_wood_material = _make_material(Color(0.13, 0.075, 0.095, 1.0), 0.92)
	_water_material = ShaderMaterial.new()
	_water_material.shader = load("res://shaders/ashen_water.gdshader") as Shader
	_rune_decal_texture = _create_rune_decal_texture()


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
	var boundary_mesh: CylinderMesh = CylinderMesh.new()
	boundary_mesh.top_radius = 0.54
	boundary_mesh.bottom_radius = 0.78
	boundary_mesh.height = 6.0
	boundary_mesh.radial_segments = 7
	boundary_mesh.material = _wood_material
	var multi_mesh: MultiMesh = MultiMesh.new()
	multi_mesh.transform_format = MultiMesh.TRANSFORM_3D
	multi_mesh.mesh = boundary_mesh
	multi_mesh.instance_count = 32
	for index: int in 32:
		var angle: float = TAU * float(index) / 32.0
		var radius: float = 89.0
		var position_3d: Vector3 = Vector3(cos(angle) * radius, 0.0, sin(angle) * radius)
		var height_scale: float = (4.5 + float(index % 4)) / 6.0
		var trunk_transform: Transform3D = Transform3D(
			Basis(Vector3.UP, -angle).scaled(Vector3(1.0, height_scale, 1.0)),
			position_3d + Vector3.UP * 3.0 * height_scale
		)
		multi_mesh.set_instance_transform(index, trunk_transform)
	var forest_instances: MultiMeshInstance3D = MultiMeshInstance3D.new()
	forest_instances.name = "ForestInstances"
	forest_instances.multimesh = multi_mesh
	forest_instances.visibility_range_end = 145.0
	boundary_root.add_child(forest_instances)
	var collision_root: StaticBody3D = StaticBody3D.new()
	collision_root.name = "WorldBounds"
	collision_root.collision_layer = 1
	collision_root.collision_mask = 0
	add_child(collision_root)
	_add_wall_collision(collision_root, Vector3(0, 2, -94), Vector3(192, 4, 2))
	_add_wall_collision(collision_root, Vector3(0, 2, 94), Vector3(192, 4, 2))
	_add_wall_collision(collision_root, Vector3(-94, 2, 0), Vector3(2, 4, 192))
	_add_wall_collision(collision_root, Vector3(94, 2, 0), Vector3(2, 4, 192))


func _build_verticality() -> void:
	var terrain: StaticBody3D = StaticBody3D.new()
	terrain.name = "AuthoredVerticality"
	terrain.collision_layer = 1
	terrain.collision_mask = 0
	add_child(terrain)
	_add_solid_feature(terrain, Vector3(-61, 1.0, 28), Vector3(16, 2, 16), Vector3.ZERO, _ground_material)
	_add_solid_feature(terrain, Vector3(-49, 1.05, 28), Vector3(12, 0.7, 5), Vector3(0, 0, deg_to_rad(-9.0)), _ground_material)
	_add_solid_feature(terrain, Vector3(58, 0.65, 42), Vector3(15, 1.3, 14), Vector3.ZERO, _stone_material)
	_add_solid_feature(terrain, Vector3(48, 0.5, 42), Vector3(9, 0.6, 4), Vector3(0, 0, deg_to_rad(-7.0)), _stone_material)
	_add_solid_feature(terrain, Vector3(4, 0.22, -16), Vector3(14, 0.44, 4.2), Vector3.ZERO, _wood_material)
	for z_offset: float in [-26.0, -6.0]:
		var ravine: MeshInstance3D = _create_box(Vector3(11.0, 0.05, 15.0), _water_material)
		ravine.name = "RavineWater"
		ravine.position = Vector3(4, 0.025, z_offset)
		ravine.visibility_range_end = 100.0
		add_child(ravine)


func _build_landmarks() -> void:
	var landmarks: Node3D = Node3D.new()
	landmarks.name = "Landmarks"
	add_child(landmarks)
	if poi_catalog == null:
		return
	for poi: RegionPoiData in poi_catalog.points:
		var poi_root: Node3D = Node3D.new()
		poi_root.name = "Poi_%s" % String(poi.poi_id)
		poi_root.position = poi.world_position
		poi_root.add_to_group(&"region_poi")
		landmarks.add_child(poi_root)
		match poi.kind:
			RegionPoiData.Kind.AWAKENING:
				_build_awakening_circle(poi_root, Vector3.ZERO)
			RegionPoiData.Kind.HEARTH:
				_build_hearth_clearing(poi_root, Vector3.ZERO)
			RegionPoiData.Kind.RUINS:
				_build_ruins(poi_root, Vector3.ZERO)
			RegionPoiData.Kind.BOG:
				_build_bog(poi_root, Vector3.ZERO)
			RegionPoiData.Kind.CRYPT:
				_build_crypt_gate(poi_root, Vector3.ZERO)
			RegionPoiData.Kind.BRIDGE:
				_build_ash_bridge(poi_root)
			RegionPoiData.Kind.TOWER:
				_build_watchtower(poi_root)
			RegionPoiData.Kind.MOONWELL:
				_build_moonwell(poi_root)
			RegionPoiData.Kind.CAVE:
				_build_root_cave(poi_root)
			RegionPoiData.Kind.PILGRIM_STONES:
				_build_pilgrim_stones(poi_root)
			RegionPoiData.Kind.GALLOWS:
				_build_witch_gallows(poi_root)
			RegionPoiData.Kind.CHAPEL:
				_build_drowned_chapel(poi_root)
		_add_story_decal(poi_root)


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
	var pool: MeshInstance3D = _create_cylinder(10.0, 0.12, _water_material)
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


func _build_ash_bridge(parent: Node3D) -> void:
	for plank_index: int in 9:
		var plank: MeshInstance3D = _create_box(Vector3(1.35, 0.16, 4.0), _wood_material)
		plank.position = Vector3(-5.4 + float(plank_index) * 1.35, 0.48, 0)
		plank.rotation_degrees.y = float((plank_index % 3) - 1) * 1.8
		parent.add_child(plank)
	for x: float in [-6.6, 6.6]:
		var post: MeshInstance3D = _create_cylinder(0.28, 2.6, _wood_material)
		post.position = Vector3(x, 1.3, -2.0)
		parent.add_child(post)


func _build_watchtower(parent: Node3D) -> void:
	for angle_index: int in 6:
		var angle: float = TAU * float(angle_index) / 6.0
		var pillar: MeshInstance3D = _create_box(Vector3(1.5, 8.0, 1.5), _stone_material)
		pillar.position = Vector3(cos(angle) * 4.2, 5.8, sin(angle) * 4.2)
		pillar.rotation_degrees.z = float((angle_index % 3) - 1) * 3.0
		parent.add_child(pillar)
	var crown: MeshInstance3D = _create_cylinder(5.4, 1.0, _stone_material)
	crown.position.y = 9.8
	parent.add_child(crown)
	var beacon: MeshInstance3D = _create_cylinder(0.55, 3.0, _make_emissive(Color(0.5, 0.24, 0.82, 1.0), 1.4))
	beacon.position.y = 11.7
	parent.add_child(beacon)


func _build_moonwell(parent: Node3D) -> void:
	var water: MeshInstance3D = _create_cylinder(4.2, 0.16, _water_material)
	water.position.y = 1.38
	parent.add_child(water)
	for index: int in 10:
		var angle: float = TAU * float(index) / 10.0
		var stone: MeshInstance3D = _create_box(Vector3(1.2, 0.8, 1.5), _stone_material)
		stone.position = Vector3(cos(angle) * 4.7, 1.1, sin(angle) * 4.7)
		stone.rotation.y = -angle
		parent.add_child(stone)
	var needle: MeshInstance3D = _create_cylinder(0.32, 6.5, _make_emissive(Color(0.26, 0.6, 1.0, 1.0), 1.3))
	needle.position = Vector3(0, 4.5, 0)
	parent.add_child(needle)


func _build_root_cave(parent: Node3D) -> void:
	var darkness: MeshInstance3D = _create_box(Vector3(8.0, 5.0, 0.35), _make_material(Color(0.012, 0.008, 0.018, 1.0), 1.0))
	darkness.position = Vector3(0, 2.5, -3.2)
	parent.add_child(darkness)
	for x: float in [-4.5, 4.5]:
		var root: MeshInstance3D = _create_cylinder(0.8, 7.0, _wood_material)
		root.position = Vector3(x, 3.1, -2.5)
		root.rotation_degrees.z = -18.0 * signf(x)
		parent.add_child(root)
	var arch: MeshInstance3D = _create_box(Vector3(9.5, 1.3, 2.0), _wood_material)
	arch.position = Vector3(0, 6.0, -2.5)
	parent.add_child(arch)


func _build_pilgrim_stones(parent: Node3D) -> void:
	for index: int in 7:
		var angle: float = TAU * float(index) / 7.0
		var height: float = 2.2 + float(index % 3) * 0.7
		var stone: MeshInstance3D = _create_box(Vector3(0.85, height, 0.7), _stone_material)
		stone.position = Vector3(cos(angle) * 5.5, height * 0.5, sin(angle) * 5.5)
		stone.rotation_degrees = Vector3(float(index % 2) * 5.0, -rad_to_deg(angle), float((index % 3) - 1) * 4.0)
		parent.add_child(stone)
	var offering: MeshInstance3D = _create_box(Vector3(2.4, 0.45, 1.6), _make_emissive(Color(0.52, 0.28, 0.82, 1.0), 0.8))
	offering.position.y = 0.24
	parent.add_child(offering)


func _build_witch_gallows(parent: Node3D) -> void:
	for x: float in [-3.2, 3.2]:
		var post: MeshInstance3D = _create_box(Vector3(0.65, 7.0, 0.65), _wood_material)
		post.position = Vector3(x, 3.5, 0)
		parent.add_child(post)
	var beam: MeshInstance3D = _create_box(Vector3(7.2, 0.7, 0.8), _wood_material)
	beam.position.y = 6.8
	parent.add_child(beam)
	var cage: MeshInstance3D = _create_cylinder(1.15, 2.5, _stone_material)
	cage.position = Vector3(0.8, 4.4, 0)
	parent.add_child(cage)
	var soul: MeshInstance3D = _create_cylinder(0.22, 1.7, _make_emissive(Color(0.72, 0.16, 0.9, 1.0), 1.8))
	soul.position = Vector3(0.8, 4.4, 0)
	parent.add_child(soul)


func _build_drowned_chapel(parent: Node3D) -> void:
	var water: MeshInstance3D = _create_cylinder(10.0, 0.1, _water_material)
	water.position.y = 0.05
	parent.add_child(water)
	for x: float in [-5.5, 5.5]:
		for z: float in [-4.0, 4.0]:
			var column: MeshInstance3D = _create_box(Vector3(1.2, 5.5, 1.2), _stone_material)
			column.position = Vector3(x, 2.75, z)
			parent.add_child(column)
	var altar: MeshInstance3D = _create_box(Vector3(4.0, 1.2, 2.2), _make_emissive(Color(0.1, 0.58, 0.62, 1.0), 0.7))
	altar.position = Vector3(0, 0.65, -2.0)
	parent.add_child(altar)


func _add_story_decal(parent: Node3D) -> void:
	var decal: Decal = Decal.new()
	decal.name = "StoryRuneDecal"
	decal.texture_albedo = _rune_decal_texture
	decal.size = Vector3(2.8, 1.6, 2.8)
	decal.position = Vector3(0, 0.75, 1.5)
	decal.modulate = Color(0.58, 0.28, 0.86, 0.76)
	decal.distance_fade_enabled = true
	decal.distance_fade_begin = 45.0
	decal.distance_fade_length = 18.0
	parent.add_child(decal)


func _create_box(size: Vector3, material: Material) -> MeshInstance3D:
	var visual: MeshInstance3D = MeshInstance3D.new()
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = size
	visual.mesh = mesh
	visual.material_override = material
	visual.visibility_range_end = 125.0
	visual.visibility_range_end_margin = 8.0
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
	visual.visibility_range_end = 125.0
	visual.visibility_range_end_margin = 8.0
	return visual


func _add_solid_feature(
	parent: StaticBody3D,
	position_3d: Vector3,
	size: Vector3,
	rotation_radians: Vector3,
	material: Material
) -> void:
	var visual: MeshInstance3D = _create_box(size, material)
	visual.position = position_3d
	visual.rotation = rotation_radians
	parent.add_child(visual)
	var collision: CollisionShape3D = CollisionShape3D.new()
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	collision.position = position_3d
	collision.rotation = rotation_radians
	parent.add_child(collision)


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


func _create_rune_decal_texture() -> ImageTexture:
	var image: Image = Image.create(32, 32, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	var color: Color = Color(0.78, 0.52, 1.0, 0.9)
	for pixel: int in 24:
		image.set_pixel(4 + pixel, 4 + pixel, color)
		image.set_pixel(27 - pixel, 4 + pixel, color)
		if pixel % 2 == 0:
			image.set_pixel(16, 4 + pixel, color)
	for x: int in range(8, 25):
		image.set_pixel(x, 16, color)
	return ImageTexture.create_from_image(image)
