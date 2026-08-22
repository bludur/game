class_name BuildingPiece
extends StaticBody3D

var piece_data: BuildingPieceData
var persistent_id: StringName = &""


func configure(definition: BuildingPieceData, instance_id: StringName, placement: Transform3D) -> void:
	piece_data = definition
	persistent_id = instance_id
	transform = placement
	_build_nodes()


func serialize_state() -> Dictionary:
	return {
		"persistent_id": String(persistent_id),
		"piece_id": String(piece_data.piece_id),
		"position": {
			"x": position.x,
			"y": position.y,
			"z": position.z,
		},
		"rotation_y": rotation.y,
	}


func get_refund() -> Array[Dictionary]:
	var refund: Array[Dictionary] = []
	for ingredient: ItemAmountData in piece_data.ingredients:
		refund.append({
			"item": ingredient.item,
			"quantity": maxi(1, floori(float(ingredient.quantity) * 0.5)),
		})
	return refund


func _build_nodes() -> void:
	for child: Node in get_children():
		child.queue_free()
	name = "Building_%s" % persistent_id
	collision_layer = 1
	collision_mask = 0
	var mesh_instance: MeshInstance3D = MeshInstance3D.new()
	mesh_instance.name = "Visual"
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = piece_data.size
	mesh_instance.mesh = mesh
	mesh_instance.position.y = piece_data.size.y * 0.5
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = piece_data.accent_color
	material.roughness = 0.82
	if piece_data.functional_kind in [BuildingPieceData.FunctionalKind.HEARTH, BuildingPieceData.FunctionalKind.WARD]:
		material.emission_enabled = true
		material.emission = piece_data.accent_color
		material.emission_energy_multiplier = 1.5
	mesh_instance.material_override = material
	add_child(mesh_instance)
	var collision: CollisionShape3D = CollisionShape3D.new()
	collision.name = "CollisionShape3D"
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = piece_data.size
	collision.shape = shape
	collision.position.y = piece_data.size.y * 0.5
	add_child(collision)
	if piece_data.ward_radius > 0.0:
		var ward: WardZone = WardZone.new()
		ward.name = "WardZone"
		ward.protection_radius = piece_data.ward_radius
		ward.collision_layer = 0
		ward.collision_mask = 2
		var ward_collision: CollisionShape3D = CollisionShape3D.new()
		var ward_shape: SphereShape3D = SphereShape3D.new()
		ward_shape.radius = piece_data.ward_radius
		ward_collision.shape = ward_shape
		ward.add_child(ward_collision)
		add_child(ward)
