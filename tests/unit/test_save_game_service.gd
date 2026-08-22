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
	session.grimoire.discover_fragment_from_source(&"broken_observatory")
	assert_true(session.grimoire.unlock_node(&"arcane_star_sigil"))
	assert_true(session.grimoire.select_node(&"arcane_star_sigil"))
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
	session.player.get_equipment_component().apply_state({
		"focus": "stormglass_rod",
		"robe": "wardkeeper_raiment",
		"talisman": "last_ember_charm",
	}, session.item_catalog)
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
	assert_eq(
		session.player.get_equipment_component().serialize_state(),
		{"focus": "stormglass_rod", "robe": "wardkeeper_raiment", "talisman": "last_ember_charm"}
	)
	assert_eq(session.grimoire.active_node_ids, [&"arcane_star_sigil"])
	assert_true(session.grimoire.discovered_fragments.has(&"fragment_star_map"))


func test_version_two_migration_grants_one_safe_starter_loadout() -> void:
	var legacy_snapshot: Dictionary = {
		"version": 2,
		"player": {"inventory": [], "status_effects": []},
		"world_state": {},
	}
	var migrated: Dictionary = _service.call("_migrate", legacy_snapshot) as Dictionary
	assert_eq(migrated["version"], 5)
	assert_eq(
		(migrated["player"] as Dictionary)["equipment"],
		{"focus": "novice_wand", "robe": "ashweave_mantle", "talisman": "quicksilver_knot"}
	)
	assert_eq((migrated["grimoire"] as Dictionary)["active_nodes"], [])
	assert_eq((migrated["world_state"] as Dictionary)["active_region_id"], "ashen_grove")
	var migrated_again: Dictionary = _service.call("_migrate", migrated) as Dictionary
	assert_eq((migrated_again["player"] as Dictionary)["equipment"], (migrated["player"] as Dictionary)["equipment"])


func test_active_region_and_both_region_states_survive_save_load() -> void:
	var session: WorldSession = WORLD_SCENE.instantiate() as WorldSession
	add_child_autofree(session)
	await get_tree().process_frame
	session.world_state.set_progression_flag(&"matriarch_defeated")
	session.get_player_inventory().add_item(session.item_catalog.get_item(&"portal_focus"), 1)
	assert_true(session.request_region_transition(&"moonbound_expanse", &"portal_focus"))
	await get_tree().process_frame
	session.player.global_position = Vector3(17.0, 0.1, -19.0)
	assert_true(_service.save_game(session, 0))
	assert_eq(_service.read_snapshot(0)["region_id"], "moonbound_expanse")
	assert_true(session.request_region_transition(&"ashen_grove"))
	await get_tree().process_frame
	assert_true(_service.load_game(session, 0))
	await get_tree().process_frame
	assert_eq(session.get_region_id(), &"moonbound_expanse")
	assert_almost_eq(session.player.global_position.x, 17.0, 0.01)
	assert_almost_eq(session.player.global_position.z, -19.0, 0.01)
	assert_true(session.world_state.region_states.has(&"ashen_grove"))
	assert_true(session.world_state.region_states.has(&"moonbound_expanse"))
