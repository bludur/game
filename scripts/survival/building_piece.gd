class_name BuildingPiece
extends StaticBody3D

signal state_changed(piece: BuildingPiece)
signal function_requested(piece: BuildingPiece, interactor: MagePlayer)

enum SupportLevel {
	GROUNDED,
	BRACED,
	EXTENDED,
}

var piece_data: BuildingPieceData
var persistent_id: StringName = &""
var current_durability: float = 0.0
var support_level: SupportLevel = SupportLevel.GROUNDED
var functional_state: Dictionary = {}
var _item_catalog: ItemCatalog
var _ward_zone: WardZone
var _main_collision: CollisionShape3D
var _visual: MeshInstance3D

static var _material_cache: Dictionary = {}


func configure(
	definition: BuildingPieceData,
	instance_id: StringName,
	placement: Transform3D,
	item_catalog: ItemCatalog = null
) -> void:
	piece_data = definition
	persistent_id = instance_id
	transform = placement
	_item_catalog = item_catalog
	current_durability = definition.maximum_durability
	functional_state = _default_functional_state()
	_build_nodes()
	set_physics_process(
		definition.functional_kind == BuildingPieceData.FunctionalKind.WARD
		and get_ward_fuel() > 0
	)


func _physics_process(delta: float) -> void:
	if piece_data == null or piece_data.functional_kind != BuildingPieceData.FunctionalKind.WARD:
		set_physics_process(false)
		return
	var fuel: int = get_ward_fuel()
	if fuel <= 0:
		set_physics_process(false)
		return
	var remaining: float = float(functional_state.get("ward_burn_remaining", 0.0)) - delta
	if remaining > 0.0:
		functional_state["ward_burn_remaining"] = remaining
		return
	fuel -= 1
	functional_state["ward_fuel"] = fuel
	functional_state["ward_burn_remaining"] = (
		piece_data.ward_fuel_seconds_per_unit if fuel > 0 else 0.0
	)
	_apply_functional_state()
	state_changed.emit(self)
	if fuel <= 0:
		set_physics_process(false)


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
		"durability": current_durability,
		"support_level": int(support_level),
		"functional_state": functional_state.duplicate(true),
	}


func apply_runtime_state(state: Dictionary) -> void:
	current_durability = clampf(
		float(state.get("durability", piece_data.maximum_durability)),
		1.0,
		piece_data.maximum_durability
	)
	support_level = clampi(
		int(state.get("support_level", SupportLevel.GROUNDED)),
		SupportLevel.GROUNDED,
		SupportLevel.EXTENDED
	) as SupportLevel
	var saved_functional: Dictionary = state.get("functional_state", {}) as Dictionary
	for key: Variant in saved_functional:
		functional_state[key] = saved_functional[key]
	_apply_functional_state()
	set_physics_process(
		piece_data.functional_kind == BuildingPieceData.FunctionalKind.WARD
		and get_ward_fuel() > 0
	)


func get_refund() -> Array[Dictionary]:
	var refund: Array[Dictionary] = []
	for ingredient: ItemAmountData in piece_data.ingredients:
		refund.append({
			"item": ingredient.item,
			"quantity": ceili(float(ingredient.quantity) * 0.5),
		})
	return refund


func get_snap_points() -> Array[Vector3]:
	var points: Array[Vector3] = []
	for local_socket: Vector3 in piece_data.snap_sockets:
		points.append(to_global(local_socket))
	return points


func damage_durability(amount: float) -> bool:
	if amount <= 0.0 or current_durability <= 1.0:
		return false
	current_durability = maxf(1.0, current_durability - amount)
	state_changed.emit(self)
	return true


func repair(inventory: InventoryComponent) -> bool:
	if inventory == null or current_durability >= piece_data.maximum_durability - 0.001 \
			or piece_data.ingredients.is_empty():
		return false
	var repair_item: ItemData = piece_data.ingredients[0].item
	if repair_item == null or not inventory.has_item_id(repair_item.item_id, 1):
		return false
	inventory.remove_by_id(repair_item.item_id, 1)
	current_durability = piece_data.maximum_durability
	state_changed.emit(self)
	return true


func store_item(inventory: InventoryComponent, item_id: StringName, quantity: int = 1) -> bool:
	if piece_data.storage_capacity <= 0 or inventory == null or _item_catalog == null or quantity <= 0:
		return false
	var stored_total: int = 0
	for entry: Dictionary in functional_state.get("storage_entries", []) as Array:
		stored_total += int(entry.get("quantity", 0))
	if stored_total + quantity > piece_data.storage_capacity or not inventory.has_item_id(item_id, quantity):
		return false
	if inventory.remove_by_id(item_id, quantity) != quantity:
		return false
	var entries: Array = functional_state.get("storage_entries", []) as Array
	for entry: Dictionary in entries:
		if StringName(String(entry.get("item_id", ""))) == item_id:
			entry["quantity"] = int(entry.get("quantity", 0)) + quantity
			state_changed.emit(self)
			return true
	entries.append({"item_id": String(item_id), "quantity": quantity})
	functional_state["storage_entries"] = entries
	state_changed.emit(self)
	return true


func withdraw_item(inventory: InventoryComponent, item_id: StringName, quantity: int = 1) -> bool:
	if inventory == null or _item_catalog == null or quantity <= 0:
		return false
	var item: ItemData = _item_catalog.get_item(item_id)
	if item == null or not inventory.can_accept(item, quantity):
		return false
	var entries: Array = functional_state.get("storage_entries", []) as Array
	for index: int in entries.size():
		var entry: Dictionary = entries[index]
		if StringName(String(entry.get("item_id", ""))) != item_id \
				or int(entry.get("quantity", 0)) < quantity:
			continue
		entry["quantity"] = int(entry.get("quantity", 0)) - quantity
		if int(entry["quantity"]) <= 0:
			entries.remove_at(index)
		functional_state["storage_entries"] = entries
		inventory.add_item(item, quantity)
		state_changed.emit(self)
		return true
	return false


func get_storage_entries() -> Array:
	return (functional_state.get("storage_entries", []) as Array).duplicate(true)


func get_ward_fuel() -> int:
	return int(functional_state.get("ward_fuel", 0))


func is_door_open() -> bool:
	return bool(functional_state.get("door_open", false))


func add_ward_fuel(inventory: InventoryComponent, quantity: int = 1) -> bool:
	if piece_data.ward_fuel_capacity <= 0 or inventory == null or quantity <= 0:
		return false
	var fuel: int = int(functional_state.get("ward_fuel", 0))
	var accepted: int = mini(quantity, piece_data.ward_fuel_capacity - fuel)
	if accepted <= 0 or not inventory.has_item_id(&"ward_essence", accepted):
		return false
	inventory.remove_by_id(&"ward_essence", accepted)
	functional_state["ward_fuel"] = fuel + accepted
	if fuel <= 0:
		functional_state["ward_burn_remaining"] = piece_data.ward_fuel_seconds_per_unit
	_apply_functional_state()
	set_physics_process(true)
	state_changed.emit(self)
	return true


func _build_nodes() -> void:
	for child: Node in get_children():
		child.queue_free()
	name = "Building_%s" % persistent_id
	collision_layer = 1
	collision_mask = 0
	_visual = MeshInstance3D.new()
	_visual.name = "Visual"
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = piece_data.size
	_visual.mesh = mesh
	_visual.position.y = piece_data.size.y * 0.5
	_visual.material_override = _get_shared_material(piece_data)
	add_child(_visual)
	_main_collision = CollisionShape3D.new()
	_main_collision.name = "CollisionShape3D"
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = piece_data.size
	_main_collision.shape = shape
	_main_collision.position.y = piece_data.size.y * 0.5
	add_child(_main_collision)
	if piece_data.ward_radius > 0.0:
		_ward_zone = WardZone.new()
		_ward_zone.name = "WardZone"
		_ward_zone.protection_radius = piece_data.ward_radius
		_ward_zone.collision_layer = 0
		_ward_zone.collision_mask = 2
		var ward_collision: CollisionShape3D = CollisionShape3D.new()
		var ward_shape: SphereShape3D = SphereShape3D.new()
		ward_shape.radius = piece_data.ward_radius
		ward_collision.shape = ward_shape
		_ward_zone.add_child(ward_collision)
		add_child(_ward_zone)
	if piece_data.functional_kind != BuildingPieceData.FunctionalKind.STRUCTURE:
		_build_interactable()
	_apply_functional_state()


func _build_interactable() -> void:
	var interactable: InteractableComponent = InteractableComponent.new()
	interactable.name = "InteractableComponent"
	interactable.prompt_text = _get_prompt_key()
	interactable.interaction_distance = 3.5
	interactable.interaction_priority = 2
	interactable.collision_layer = 0
	interactable.collision_mask = 2
	var collision: CollisionShape3D = CollisionShape3D.new()
	var shape: SphereShape3D = SphereShape3D.new()
	shape.radius = maxf(1.0, maxf(piece_data.size.x, piece_data.size.z) * 0.55)
	collision.shape = shape
	collision.position.y = piece_data.size.y * 0.5
	interactable.add_child(collision)
	add_child(interactable)
	interactable.interaction_requested.connect(_on_interaction_requested)


func _on_interaction_requested(interactor: Node3D) -> void:
	if interactor is not MagePlayer:
		return
	if piece_data.functional_kind == BuildingPieceData.FunctionalKind.DOOR:
		functional_state["door_open"] = not bool(functional_state.get("door_open", false))
		_apply_functional_state()
		state_changed.emit(self)
		function_requested.emit(self, interactor as MagePlayer)
		return
	if piece_data.functional_kind == BuildingPieceData.FunctionalKind.WARD:
		add_ward_fuel((interactor as MagePlayer).get_inventory_component(), 1)
	function_requested.emit(self, interactor as MagePlayer)


func _apply_functional_state() -> void:
	if is_instance_valid(_main_collision) \
			and piece_data.functional_kind == BuildingPieceData.FunctionalKind.DOOR:
		var door_open: bool = bool(functional_state.get("door_open", false))
		_main_collision.set_deferred("disabled", door_open)
		if is_instance_valid(_visual):
			_visual.rotation.y = PI * 0.5 if door_open else 0.0
	if is_instance_valid(_ward_zone) and piece_data.ward_fuel_capacity > 0:
		_ward_zone.set_active(int(functional_state.get("ward_fuel", 0)) > 0)


func _default_functional_state() -> Dictionary:
	return {
		"door_open": false,
		"storage_entries": [],
		"ward_fuel": 0,
		"ward_burn_remaining": 0.0,
	}


func _get_prompt_key() -> String:
	match piece_data.functional_kind:
		BuildingPieceData.FunctionalKind.DOOR:
			return "PROMPT_TOGGLE_DOOR"
		BuildingPieceData.FunctionalKind.STORAGE:
			return "PROMPT_OPEN_STORAGE"
		BuildingPieceData.FunctionalKind.CRAFTING:
			return "PROMPT_USE_STATION"
		BuildingPieceData.FunctionalKind.HEARTH, BuildingPieceData.FunctionalKind.BED_ALTAR:
			return "PROMPT_REST_SAVE"
		BuildingPieceData.FunctionalKind.WARD:
			return "PROMPT_FUEL_WARD"
		_:
			return "PROMPT_INTERACT"


static func _get_shared_material(definition: BuildingPieceData) -> StandardMaterial3D:
	var key: String = "%s_%d" % [definition.accent_color.to_html(), definition.functional_kind]
	if _material_cache.has(key):
		return _material_cache[key] as StandardMaterial3D
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = definition.accent_color
	material.roughness = 0.82
	if definition.functional_kind in [BuildingPieceData.FunctionalKind.HEARTH, BuildingPieceData.FunctionalKind.WARD]:
		material.emission_enabled = true
		material.emission = definition.accent_color
		material.emission_energy_multiplier = 1.5
	_material_cache[key] = material
	return material
