extends GutTest

const PLAYER_SCENE: PackedScene = preload("res://scenes/characters/player/player.tscn")
const ITEM_CATALOG: ItemCatalog = preload("res://resources/survival/item_catalog.tres")
const ARCANE_BOLT: SpellData = preload("res://resources/spells/arcane_bolt.tres")
const FROST_CIRCLE: SpellData = preload("res://resources/spells/frost_circle.tres")
const RECIPE_CATALOG: RecipeCatalog = preload("res://resources/survival/recipe_catalog.tres")

var _player: MagePlayer
var _inventory: InventoryComponent
var _equipment: EquipmentComponent


func before_each() -> void:
	_player = PLAYER_SCENE.instantiate() as MagePlayer
	add_child_autofree(_player)
	_inventory = _player.get_inventory_component()
	_equipment = _player.get_equipment_component()


func test_equip_swap_and_unequip_are_lossless() -> void:
	_inventory.add_item(ITEM_CATALOG.get_item(&"novice_wand"), 1)
	assert_true(_equipment.equip_from_inventory(_find_inventory_slot(&"novice_wand")))
	assert_eq(_inventory.get_item_count(&"novice_wand"), 0)
	assert_eq(_equipment.get_equipped_item(EquipmentData.Slot.FOCUS).item_id, &"novice_wand")
	_inventory.add_item(ITEM_CATALOG.get_item(&"rimewood_crook"), 1)
	assert_true(_equipment.equip_from_inventory(_find_inventory_slot(&"rimewood_crook")))
	assert_eq(_equipment.get_equipped_item(EquipmentData.Slot.FOCUS).item_id, &"rimewood_crook")
	assert_eq(_inventory.get_item_count(&"novice_wand"), 1)
	assert_eq(_inventory.get_item_count(&"rimewood_crook"), 0)
	assert_true(_equipment.unequip(EquipmentData.Slot.FOCUS))
	assert_null(_equipment.get_equipped_item(EquipmentData.Slot.FOCUS))
	assert_eq(_inventory.get_item_count(&"rimewood_crook"), 1)
	assert_eq(_inventory.get_item_count(&"novice_wand"), 1)


func test_full_inventory_unequip_drops_once_without_duplication() -> void:
	_inventory.add_item(ITEM_CATALOG.get_item(&"novice_wand"), 1)
	assert_true(_equipment.equip_from_inventory(_find_inventory_slot(&"novice_wand")))
	_inventory.add_item(ITEM_CATALOG.get_item(&"gravewood"), 720)
	var dropped: Array[ItemData] = []
	_equipment.drop_requested.connect(func(item: ItemData, _quantity: int) -> void: dropped.append(item))
	assert_false(_equipment.unequip(EquipmentData.Slot.FOCUS, false))
	assert_true(_equipment.unequip(EquipmentData.Slot.FOCUS, true))
	assert_eq(dropped.size(), 1)
	assert_eq(dropped[0].item_id, &"novice_wand")
	assert_eq(_inventory.get_item_count(&"novice_wand"), 0)
	assert_null(_equipment.get_equipped_item(EquipmentData.Slot.FOCUS))


func test_three_authored_builds_have_distinct_combat_profiles() -> void:
	_equipment.apply_state({
		"focus": "novice_wand", "robe": "ashweave_mantle", "talisman": "quicksilver_knot",
	}, ITEM_CATALOG)
	var fast_arcane: Dictionary = _equipment.get_spell_profile(ARCANE_BOLT)
	assert_almost_eq(float(fast_arcane["cooldown_multiplier"]), 0.697, 0.001)
	assert_almost_eq(float(fast_arcane["damage_multiplier"]), 1.035, 0.001)

	_equipment.apply_state({
		"focus": "rimewood_crook", "robe": "rimebound_robes", "talisman": "moonwell_locket",
	}, ITEM_CATALOG)
	var frost_control: Dictionary = _equipment.get_spell_profile(FROST_CIRCLE)
	assert_almost_eq(float(frost_control["area_radius_multiplier"]), 1.56, 0.001)
	assert_almost_eq(float(frost_control["effect_duration_multiplier"]), 1.62, 0.001)
	assert_lt(float(frost_control["mana_cost_multiplier"]), 0.88)

	_player.get_health_component().take_damage(70.0)
	_player.get_corruption_component().apply_state({"current": 60.0})
	_equipment.apply_state({
		"focus": "voidthorn_focus", "robe": "bloodroot_shroud", "talisman": "hollow_eye_relic",
	}, ITEM_CATALOG)
	var forbidden: Dictionary = _equipment.get_spell_profile(ARCANE_BOLT)
	assert_gt(float(forbidden["damage_multiplier"]), 2.3)
	assert_lt(_equipment.filter_incoming_damage(100.0), 77.0)
	_equipment.notify_spell_cast(ARCANE_BOLT)
	assert_almost_eq(_player.get_corruption_component().current_corruption, 64.0, 0.001)


func test_equipment_state_uses_stable_ids_and_missing_items_fall_back_safely() -> void:
	_equipment.apply_state({
		"focus": "stormglass_rod", "robe": "wardkeeper_raiment", "talisman": "last_ember_charm",
	}, ITEM_CATALOG)
	var state: Dictionary = _equipment.serialize_state()
	assert_eq(state["focus"], "stormglass_rod")
	_player.reset_for_new_run()
	assert_eq(_equipment.serialize_state(), state)
	_equipment.apply_state({
		"focus": "removed_focus", "robe": "wardkeeper_raiment", "talisman": "",
	}, ITEM_CATALOG)
	assert_null(_equipment.get_equipped_item(EquipmentData.Slot.FOCUS))
	assert_eq(_equipment.get_equipped_item(EquipmentData.Slot.ROBE).item_id, &"wardkeeper_raiment")


func test_catalog_contains_fifteen_valid_equipment_items_across_four_tiers() -> void:
	var equipment_count: int = 0
	var slots: Dictionary[int, bool] = {}
	var tiers: Dictionary[int, bool] = {}
	for item: ItemData in ITEM_CATALOG.items:
		if item.equipment == null:
			continue
		equipment_count += 1
		assert_true(item.is_valid_definition())
		slots[item.equipment.slot] = true
		tiers[item.equipment.tier] = true
	assert_eq(equipment_count, 15)
	assert_eq(slots.size(), 3)
	assert_eq(tiers.size(), 4)


func test_nine_non_starter_equipment_recipes_are_authored() -> void:
	var recipe_ids: Array[StringName] = [
		&"shape_rimewood_crook", &"shape_stormglass_rod", &"bind_voidthorn_focus",
		&"weave_rimebound_robes", &"weave_wardkeeper_raiment", &"weave_bloodroot_shroud",
		&"set_moonwell_locket", &"bind_last_ember_charm", &"awaken_hollow_eye_relic",
	]
	for recipe_id: StringName in recipe_ids:
		var recipe: RecipeData = RECIPE_CATALOG.get_recipe(recipe_id)
		assert_not_null(recipe)
		assert_not_null(recipe.result_item.equipment)
		assert_false(recipe.ingredients.is_empty())


func test_equipment_updates_focus_and_three_large_robe_visuals() -> void:
	_equipment.apply_state({
		"focus": "voidthorn_focus", "robe": "bloodroot_shroud",
	}, ITEM_CATALOG)
	assert_true((_player.get_node("Visuals/EquipmentVisuals/Focus") as MeshInstance3D).visible)
	assert_true((_player.get_node("Visuals/EquipmentVisuals/RobeShoulders") as MeshInstance3D).visible)
	assert_true((_player.get_node("Visuals/EquipmentVisuals/RobeCape") as MeshInstance3D).visible)
	assert_true((_player.get_node("Visuals/EquipmentVisuals/RobeHood") as MeshInstance3D).visible)
	_equipment.apply_state({}, ITEM_CATALOG)
	assert_false((_player.get_node("Visuals/EquipmentVisuals/Focus") as MeshInstance3D).visible)
	assert_false((_player.get_node("Visuals/EquipmentVisuals/RobeShoulders") as MeshInstance3D).visible)


func _find_inventory_slot(item_id: StringName) -> int:
	for index: int in _inventory.slots.size():
		var slot: InventorySlot = _inventory.slots[index]
		if not slot.is_empty() and slot.item.item_id == item_id:
			return index
	return -1
