extends GutTest

const GRIMOIRE: GrimoireData = preload("res://resources/survival/grimoire.tres")
const ITEM_CATALOG: ItemCatalog = preload("res://resources/survival/item_catalog.tres")
const ARCANE_BOLT: SpellData = preload("res://resources/spells/arcane_bolt.tres")


func test_four_schools_have_three_authored_levels_and_two_new_game_paths() -> void:
	assert_true(GRIMOIRE.is_valid_definition())
	assert_eq(GRIMOIRE.nodes.size(), 12)
	for school: SpellModifierData.School in [
		SpellModifierData.School.ARCANE,
		SpellModifierData.School.FROST,
		SpellModifierData.School.STORM,
		SpellModifierData.School.FORBIDDEN,
	]:
		var levels: Array[int] = []
		for node_data: KnowledgeNodeData in GRIMOIRE.nodes:
			if node_data.school == school:
				levels.append(node_data.knowledge_level)
		levels.sort()
		assert_eq(levels, [1, 2, 3])
	var state: GrimoireState = _make_state()
	state.discover_fragment_from_source(&"broken_observatory")
	state.discover_fragment_from_source(&"root_cave")
	assert_true(state.can_unlock_node(&"arcane_star_sigil"))
	assert_true(state.can_unlock_node(&"frost_rime_veil"))


func test_fragments_unlock_nodes_and_active_profile_only_affects_matching_school() -> void:
	var state: GrimoireState = _make_state()
	assert_not_null(state.discover_fragment_from_source(&"broken_observatory"))
	assert_true(state.unlock_node(&"arcane_star_sigil"))
	assert_true(state.select_node(&"arcane_star_sigil"))
	var profile: Dictionary = state.get_spell_profile(ARCANE_BOLT)
	assert_almost_eq(float(profile["damage_multiplier"]), 1.12, 0.001)
	var frost_circle: SpellData = preload("res://resources/spells/frost_circle.tres")
	var frost_profile: Dictionary = state.get_spell_profile(frost_circle)
	assert_almost_eq(float(frost_profile["damage_multiplier"]), 1.0, 0.001)


func test_incompatible_end_nodes_are_rejected() -> void:
	var state: GrimoireState = _make_state()
	_unlock_path(state, [
		&"broken_observatory", &"dead_moonwell", &"rootbound_matriarch",
	], [
		&"arcane_star_sigil", &"arcane_moon_thread", &"arcane_great_portal",
	])
	_unlock_path(state, [
		&"witch_gallows", &"whispering_bog", &"rootbound_matriarch",
	], [
		&"forbidden_last_whisper", &"forbidden_bog_name", &"forbidden_voidthorn",
	])
	assert_true(state.select_node(&"arcane_great_portal"))
	assert_false(state.select_node(&"forbidden_voidthorn"))
	assert_eq(state.active_node_ids, [&"arcane_great_portal"])


func test_only_three_unlocked_passives_can_be_selected() -> void:
	var state: GrimoireState = _make_state()
	for source_id: StringName in [
		&"broken_observatory", &"root_cave", &"hollow_watchtower", &"witch_gallows",
	]:
		state.discover_fragment_from_source(source_id)
	for node_id: StringName in [
		&"arcane_star_sigil", &"frost_rime_veil", &"storm_lens", &"forbidden_last_whisper",
	]:
		assert_true(state.unlock_node(node_id))
	assert_true(state.select_node(&"arcane_star_sigil"))
	assert_true(state.select_node(&"frost_rime_veil"))
	assert_true(state.select_node(&"storm_lens"))
	assert_false(state.select_node(&"forbidden_last_whisper"))
	assert_eq(state.active_node_ids.size(), 3)


func test_respec_is_atomic_and_never_erases_found_knowledge() -> void:
	var state: GrimoireState = _make_state()
	state.discover_fragment_from_source(&"broken_observatory")
	assert_true(state.unlock_node(&"arcane_star_sigil"))
	assert_true(state.select_node(&"arcane_star_sigil"))
	var inventory: InventoryComponent = InventoryComponent.new()
	add_child_autofree(inventory)
	inventory.initialize_slots()
	var before: Dictionary = state.serialize_state()
	assert_false(state.respec(inventory))
	assert_eq(state.serialize_state(), before)
	var chalk: ItemData = ITEM_CATALOG.get_item(&"ritual_chalk")
	inventory.add_item(chalk, 3)
	assert_true(state.respec(inventory))
	assert_eq(inventory.get_item_count(&"ritual_chalk"), 0)
	assert_true(state.unlocked_nodes.has(&"arcane_star_sigil"))
	assert_true(state.discovered_fragments.has(&"fragment_star_map"))
	assert_true(state.active_node_ids.is_empty())


func test_schema_two_roundtrip_preserves_selected_nodes() -> void:
	var source: GrimoireState = _make_state()
	source.discover_fragment_from_source(&"broken_observatory")
	assert_true(source.unlock_node(&"arcane_star_sigil"))
	assert_true(source.select_node(&"arcane_star_sigil"))
	var snapshot: Dictionary = source.serialize_state()
	assert_eq(snapshot["schema_version"], 2)
	var restored: GrimoireState = _make_state()
	restored.apply_state(snapshot)
	assert_eq(restored.active_node_ids, [&"arcane_star_sigil"])
	assert_true(restored.unlocked_nodes.has(&"arcane_star_sigil"))
	assert_true(restored.discovered_fragments.has(&"fragment_star_map"))


func _make_state() -> GrimoireState:
	var state: GrimoireState = GrimoireState.new()
	state.definition = GRIMOIRE
	add_child_autofree(state)
	return state


func _unlock_path(
	state: GrimoireState,
	source_ids: Array[StringName],
	node_ids: Array[StringName]
) -> void:
	for source_id: StringName in source_ids:
		state.discover_fragment_from_source(source_id)
	for node_id: StringName in node_ids:
		assert_true(state.unlock_node(node_id))
