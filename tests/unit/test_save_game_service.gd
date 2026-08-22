extends GutTest

const WORLD_SCENE: PackedScene = preload("res://scenes/survival/world_session.tscn")
const SAVE_DIRECTORY: String = "res://.godot/survival_save_test/"

var _service: SaveGameService


func before_each() -> void:
	_service = SaveGameService.new()
	_service.save_directory = SAVE_DIRECTORY
	add_child_autofree(_service)
	_service.delete_save(0)


func after_each() -> void:
	_service.delete_save(0)


func test_three_save_cycles_and_backup_recovery_preserve_world_state() -> void:
	var session: WorldSession = WORLD_SCENE.instantiate() as WorldSession
	add_child_autofree(session)
	await get_tree().process_frame
	var inventory: InventoryComponent = session.get_player_inventory()
	var gravewood: ItemData = session.item_catalog.get_item(&"gravewood")
	inventory.add_item(gravewood, 3)
	session.player.global_position = Vector3(1, 0.1, 2)
	assert_true(_service.save_game(session, 0))
	session.player.global_position = Vector3(11, 0.1, 12)
	inventory.add_item(gravewood, 2)
	var status_effects: StatusEffectComponent = session.player.get_status_effect_component()
	assert_true(status_effects.apply_effect_by_id(&"rested"))
	status_effects.set_physics_process(false)
	status_effects.advance(37.5)
	var saved_remaining: float = status_effects.get_active_effect(&"rested").remaining_seconds
	status_effects.serialize_state()
	assert_almost_eq(status_effects.get_active_effect(&"rested").remaining_seconds, saved_remaining, 0.001)
	assert_true(_service.save_game(session, 0))
	session.player.global_position = Vector3(21, 0.1, 22)
	inventory.add_item(gravewood, 4)
	assert_true(_service.save_game(session, 0))
	assert_eq(_service.read_snapshot(0)["version"], SaveGameService.CURRENT_VERSION)

	var primary_path: String = SAVE_DIRECTORY + "slot_0.json"
	var corrupt_file: FileAccess = FileAccess.open(primary_path, FileAccess.WRITE)
	assert_not_null(corrupt_file)
	corrupt_file.store_string("{corrupt")
	corrupt_file = null
	session.player.global_position = Vector3.ZERO
	assert_true(_service.load_game(session, 0))
	assert_almost_eq(session.player.global_position.x, 11.0, 0.01)
	assert_almost_eq(session.player.global_position.z, 12.0, 0.01)
	assert_eq(session.get_player_inventory().get_item_count(&"gravewood"), 5)
	assert_almost_eq(
		session.player.get_status_effect_component().get_active_effect(&"rested").remaining_seconds,
		saved_remaining,
		0.01
	)
