extends GutTest

const BUILDING_CATALOG: BuildingCatalog = preload("res://resources/survival/building_catalog.tres")
const ITEM_CATALOG: ItemCatalog = preload("res://resources/survival/item_catalog.tres")


func test_authored_catalog_has_ten_pieces_five_categories_and_snap_sockets() -> void:
	assert_eq(BUILDING_CATALOG.pieces.size(), 10)
	var categories: Dictionary[int, bool] = {}
	for piece: BuildingPieceData in BUILDING_CATALOG.pieces:
		assert_false(piece.piece_id.is_empty())
		assert_gt(piece.maximum_durability, 0.0)
		categories[piece.category] = true
	assert_eq(categories.size(), 5)
	assert_gt(BUILDING_CATALOG.get_piece(&"foundation").snap_sockets.size(), 0)
	assert_eq(
		BUILDING_CATALOG.get_piece(&"door").functional_kind,
		BuildingPieceData.FunctionalKind.DOOR
	)
	assert_eq(BUILDING_CATALOG.get_piece(&"chest").storage_capacity, 24)
	assert_eq(BUILDING_CATALOG.get_piece(&"ward_obelisk").ward_fuel_capacity, 10)


func test_durability_support_and_door_state_round_trip() -> void:
	var door: BuildingPiece = BuildingPiece.new()
	door.configure(
		BUILDING_CATALOG.get_piece(&"door"),
		&"build_0001_door",
		Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(4.0, 0.4, 8.0)),
		ITEM_CATALOG
	)
	add_child_autofree(door)
	assert_true(door.damage_durability(35.0))
	door.support_level = BuildingPiece.SupportLevel.BRACED
	door.apply_runtime_state({
		"durability": door.current_durability,
		"support_level": BuildingPiece.SupportLevel.BRACED,
		"functional_state": {"door_open": true},
	})
	var state: Dictionary = door.serialize_state()
	assert_true(door.is_door_open())
	assert_eq(int(state["support_level"]), BuildingPiece.SupportLevel.BRACED)
	assert_almost_eq(float(state["durability"]), 85.0, 0.001)

	var restored: BuildingPiece = BuildingPiece.new()
	restored.configure(
		BUILDING_CATALOG.get_piece(&"door"),
		&"build_0001_door",
		Transform3D.IDENTITY,
		ITEM_CATALOG
	)
	add_child_autofree(restored)
	restored.apply_runtime_state(state)
	assert_true(restored.is_door_open())
	assert_eq(restored.support_level, BuildingPiece.SupportLevel.BRACED)
	assert_almost_eq(restored.current_durability, 85.0, 0.001)


func test_chest_and_ward_move_resources_without_duplication_and_persist() -> void:
	var inventory: InventoryComponent = InventoryComponent.new()
	inventory.capacity = 4
	add_child_autofree(inventory)
	inventory.add_item(ITEM_CATALOG.get_item(&"gravewood"), 4)
	inventory.add_item(ITEM_CATALOG.get_item(&"ward_essence"), 3)

	var chest: BuildingPiece = BuildingPiece.new()
	chest.configure(
		BUILDING_CATALOG.get_piece(&"chest"), &"build_0002_chest", Transform3D.IDENTITY, ITEM_CATALOG
	)
	add_child_autofree(chest)
	assert_true(chest.store_item(inventory, &"gravewood", 3))
	assert_eq(inventory.get_item_count(&"gravewood"), 1)
	assert_eq(int((chest.get_storage_entries()[0] as Dictionary)["quantity"]), 3)
	assert_true(chest.withdraw_item(inventory, &"gravewood", 1))
	assert_eq(inventory.get_item_count(&"gravewood"), 2)
	assert_eq(int((chest.get_storage_entries()[0] as Dictionary)["quantity"]), 2)

	var ward: BuildingPiece = BuildingPiece.new()
	ward.configure(
		BUILDING_CATALOG.get_piece(&"ward_obelisk"), &"build_0003_ward", Transform3D.IDENTITY, ITEM_CATALOG
	)
	add_child_autofree(ward)
	assert_true(ward.add_ward_fuel(inventory, 2))
	assert_eq(ward.get_ward_fuel(), 2)
	assert_eq(inventory.get_item_count(&"ward_essence"), 1)
	var restored_ward: BuildingPiece = BuildingPiece.new()
	restored_ward.configure(
		BUILDING_CATALOG.get_piece(&"ward_obelisk"), &"build_0003_ward", Transform3D.IDENTITY, ITEM_CATALOG
	)
	add_child_autofree(restored_ward)
	restored_ward.apply_runtime_state(ward.serialize_state())
	assert_eq(restored_ward.get_ward_fuel(), 2)
	restored_ward._physics_process(181.0)
	assert_eq(restored_ward.get_ward_fuel(), 1)


func test_repair_consumes_one_material_and_dismantle_returns_explicit_half_refund() -> void:
	var inventory: InventoryComponent = InventoryComponent.new()
	inventory.capacity = 6
	add_child_autofree(inventory)
	var system: ConstructionSystem = ConstructionSystem.new()
	system.catalog = BUILDING_CATALOG
	add_child_autofree(system)
	system.bind(null, inventory, null, ITEM_CATALOG)
	var wall: BuildingPiece = BuildingPiece.new()
	wall.configure(BUILDING_CATALOG.get_piece(&"wall"), &"build_0004_wall", Transform3D.IDENTITY, ITEM_CATALOG)
	system.add_child(wall)
	wall.damage_durability(40.0)
	var repair_item: ItemData = BUILDING_CATALOG.get_piece(&"wall").ingredients[0].item
	inventory.add_item(repair_item, 2)
	assert_true(wall.repair(inventory))
	assert_eq(inventory.get_item_count(repair_item.item_id), 1)
	assert_almost_eq(wall.current_durability, wall.piece_data.maximum_durability, 0.001)
	assert_true(system.dismantle_piece(wall))
	assert_eq(inventory.get_item_count(repair_item.item_id), 2)


func test_three_support_levels_stop_extension_after_two_links() -> void:
	var system: ConstructionSystem = ConstructionSystem.new()
	add_child_autofree(system)
	var grounded: BuildingPiece = _make_support_piece(BuildingPiece.SupportLevel.GROUNDED)
	var braced: BuildingPiece = _make_support_piece(BuildingPiece.SupportLevel.BRACED)
	var extended: BuildingPiece = _make_support_piece(BuildingPiece.SupportLevel.EXTENDED)
	add_child_autofree(grounded)
	add_child_autofree(braced)
	add_child_autofree(extended)
	assert_eq(system.evaluate_support_level(Vector3.ZERO, grounded), BuildingPiece.SupportLevel.BRACED)
	assert_eq(system.evaluate_support_level(Vector3.ZERO, braced), BuildingPiece.SupportLevel.EXTENDED)
	assert_eq(system.evaluate_support_level(Vector3.ZERO, extended), -1)


func _make_support_piece(level: int) -> BuildingPiece:
	var piece: BuildingPiece = BuildingPiece.new()
	piece.configure(BUILDING_CATALOG.get_piece(&"foundation"), &"support", Transform3D.IDENTITY)
	piece.support_level = level
	return piece
