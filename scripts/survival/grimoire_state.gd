class_name GrimoireState
extends Node

signal knowledge_unlocked(knowledge_id: StringName)
signal recipe_unlocked(recipe_id: StringName)
signal fragment_discovered(fragment_id: StringName)
signal node_unlocked(node_id: StringName)
signal active_nodes_changed(active_node_ids: Array[StringName])
signal respec_completed(cost_item_id: StringName, quantity: int)

const STATE_SCHEMA_VERSION: int = 2

@export var definition: GrimoireData

var unlocked_knowledge: Dictionary[StringName, bool] = {}
var unlocked_recipes: Dictionary[StringName, bool] = {}
var discovered_fragments: Dictionary[StringName, bool] = {}
var unlocked_nodes: Dictionary[StringName, bool] = {}
var active_node_ids: Array[StringName] = []


func _ready() -> void:
	_apply_starting_unlocks()


func unlock_knowledge(knowledge_id: StringName) -> bool:
	if knowledge_id.is_empty() or unlocked_knowledge.has(knowledge_id):
		return false
	unlocked_knowledge[knowledge_id] = true
	knowledge_unlocked.emit(knowledge_id)
	return true


func unlock_recipe(recipe_id: StringName) -> bool:
	if recipe_id.is_empty() or unlocked_recipes.has(recipe_id):
		return false
	unlocked_recipes[recipe_id] = true
	recipe_unlocked.emit(recipe_id)
	return true


func is_recipe_unlocked(recipe_id: StringName) -> bool:
	return unlocked_recipes.get(recipe_id, false)


func discover_fragment(fragment_id: StringName) -> bool:
	if definition == null or definition.get_fragment(fragment_id) == null \
			or discovered_fragments.has(fragment_id):
		return false
	discovered_fragments[fragment_id] = true
	fragment_discovered.emit(fragment_id)
	return true


func discover_fragment_from_source(source_id: StringName) -> KnowledgeFragmentData:
	if definition == null:
		return null
	var fragment: KnowledgeFragmentData = definition.get_fragment_for_source(source_id)
	if fragment != null:
		discover_fragment(fragment.fragment_id)
	return fragment


func can_unlock_node(node_id: StringName) -> bool:
	return get_unlock_status(node_id) == &"ready"


func get_unlock_status(node_id: StringName) -> StringName:
	if definition == null:
		return &"missing_definition"
	var node_data: KnowledgeNodeData = definition.get_node_data(node_id)
	if node_data == null:
		return &"missing_definition"
	if unlocked_nodes.has(node_id):
		return &"already_unlocked"
	for prerequisite_id: StringName in node_data.prerequisite_node_ids:
		if not unlocked_nodes.has(prerequisite_id):
			return &"missing_prerequisite"
	for fragment_id: StringName in node_data.required_fragment_ids:
		if not discovered_fragments.has(fragment_id):
			return &"missing_fragment"
	return &"ready"


func unlock_node(node_id: StringName) -> bool:
	if not can_unlock_node(node_id):
		return false
	var node_data: KnowledgeNodeData = definition.get_node_data(node_id)
	if node_data == null:
		return false
	unlocked_nodes[node_id] = true
	unlock_knowledge(node_id)
	if node_data.reward_kind == KnowledgeNodeData.RewardKind.EQUIPMENT_RECIPE:
		unlock_recipe(node_data.reward_id)
	else:
		unlock_knowledge(node_data.reward_id)
	node_unlocked.emit(node_id)
	return true


func select_node(node_id: StringName) -> bool:
	if definition == null or not unlocked_nodes.has(node_id) or active_node_ids.has(node_id):
		return false
	if active_node_ids.size() >= definition.maximum_active_nodes:
		return false
	var candidate: KnowledgeNodeData = definition.get_node_data(node_id)
	if candidate == null:
		return false
	for active_id: StringName in active_node_ids:
		var active: KnowledgeNodeData = definition.get_node_data(active_id)
		if candidate.incompatible_node_ids.has(active_id) \
				or (active != null and active.incompatible_node_ids.has(node_id)):
			return false
	active_node_ids.append(node_id)
	active_nodes_changed.emit(active_node_ids.duplicate())
	return true


func unselect_node(node_id: StringName) -> bool:
	var index: int = active_node_ids.find(node_id)
	if index < 0:
		return false
	active_node_ids.remove_at(index)
	active_nodes_changed.emit(active_node_ids.duplicate())
	return true


func toggle_node(node_id: StringName) -> bool:
	return unselect_node(node_id) if active_node_ids.has(node_id) else select_node(node_id)


func respec(inventory: InventoryComponent) -> bool:
	if definition == null or inventory == null or active_node_ids.is_empty():
		return false
	if not inventory.has_item_id(definition.respec_item_id, definition.respec_item_quantity):
		return false
	if inventory.remove_by_id(definition.respec_item_id, definition.respec_item_quantity) \
			!= definition.respec_item_quantity:
		return false
	active_node_ids.clear()
	active_nodes_changed.emit(active_node_ids.duplicate())
	respec_completed.emit(definition.respec_item_id, definition.respec_item_quantity)
	return true


func get_spell_profile(spell: SpellData) -> Dictionary:
	var profile: Dictionary = _empty_spell_profile()
	if definition == null or spell == null:
		return profile
	for node_id: StringName in active_node_ids:
		var node_data: KnowledgeNodeData = definition.get_node_data(node_id)
		if node_data == null or node_data.school != spell.school:
			continue
		profile["cooldown_multiplier"] *= node_data.cooldown_multiplier
		profile["mana_cost_multiplier"] *= node_data.mana_cost_multiplier
		profile["damage_multiplier"] *= node_data.damage_multiplier
		profile["projectile_speed_multiplier"] *= node_data.projectile_speed_multiplier
		profile["area_radius_multiplier"] *= node_data.area_radius_multiplier
		profile["effect_duration_multiplier"] *= node_data.effect_duration_multiplier
		profile["chain_jump_multiplier"] *= node_data.chain_jump_multiplier
	return profile


func get_next_achievable_node() -> KnowledgeNodeData:
	if definition == null:
		return null
	for node_data: KnowledgeNodeData in definition.nodes:
		if get_unlock_status(node_data.node_id) == &"ready":
			return node_data
	for node_data: KnowledgeNodeData in definition.nodes:
		if unlocked_nodes.has(node_data.node_id):
			continue
		var prerequisites_met: bool = true
		for prerequisite_id: StringName in node_data.prerequisite_node_ids:
			if not unlocked_nodes.has(prerequisite_id):
				prerequisites_met = false
				break
		if prerequisites_met:
			return node_data
	return null


func get_unlock_hint(node_id: StringName) -> String:
	if definition == null:
		return "Гримуар не настроен."
	var node_data: KnowledgeNodeData = definition.get_node_data(node_id)
	if node_data == null:
		return "Запись не найдена."
	match get_unlock_status(node_id):
		&"ready":
			return "Все требования выполнены — запись можно расшифровать."
		&"already_unlocked":
			return "Запись уже расшифрована. Выберите её, чтобы включить эффект."
		&"missing_prerequisite":
			for prerequisite_id: StringName in node_data.prerequisite_node_ids:
				if not unlocked_nodes.has(prerequisite_id):
					var prerequisite: KnowledgeNodeData = definition.get_node_data(prerequisite_id)
					return "Сначала откройте: %s." % (
						prerequisite.display_name if prerequisite != null else String(prerequisite_id)
					)
		&"missing_fragment":
			for fragment_id: StringName in node_data.required_fragment_ids:
				if not discovered_fragments.has(fragment_id):
					var fragment: KnowledgeFragmentData = definition.get_fragment(fragment_id)
					return fragment.source_hint if fragment != null else "Найдите фрагмент знания."
	return "Эта запись пока недоступна."


func serialize_state() -> Dictionary:
	return {
		"schema_version": STATE_SCHEMA_VERSION,
		"knowledge": _keys_to_strings(unlocked_knowledge),
		"recipes": _keys_to_strings(unlocked_recipes),
		"fragments": _keys_to_strings(discovered_fragments),
		"nodes": _keys_to_strings(unlocked_nodes),
		"active_nodes": _names_to_strings(active_node_ids),
	}


func apply_state(state: Dictionary) -> void:
	unlocked_knowledge.clear()
	unlocked_recipes.clear()
	discovered_fragments.clear()
	unlocked_nodes.clear()
	active_node_ids.clear()
	for knowledge_id: Variant in state.get("knowledge", []):
		unlocked_knowledge[StringName(String(knowledge_id))] = true
	for recipe_id: Variant in state.get("recipes", []):
		unlocked_recipes[StringName(String(recipe_id))] = true
	for fragment_id: Variant in state.get("fragments", []):
		var resolved_fragment: StringName = StringName(String(fragment_id))
		if definition != null and definition.get_fragment(resolved_fragment) != null:
			discovered_fragments[resolved_fragment] = true
	for node_id: Variant in state.get("nodes", []):
		var resolved_node: StringName = StringName(String(node_id))
		if definition != null and definition.get_node_data(resolved_node) != null:
			unlocked_nodes[resolved_node] = true
	for node_id: Variant in state.get("active_nodes", []):
		select_node(StringName(String(node_id)))
	_apply_starting_unlocks()
	active_nodes_changed.emit(active_node_ids.duplicate())


func _apply_starting_unlocks() -> void:
	if definition == null:
		return
	for knowledge_id: StringName in definition.starting_knowledge:
		unlocked_knowledge[knowledge_id] = true
	for recipe_id: StringName in definition.starting_recipes:
		unlocked_recipes[recipe_id] = true


func _empty_spell_profile() -> Dictionary:
	return {
		"cooldown_multiplier": 1.0,
		"mana_cost_multiplier": 1.0,
		"damage_multiplier": 1.0,
		"projectile_speed_multiplier": 1.0,
		"area_radius_multiplier": 1.0,
		"effect_duration_multiplier": 1.0,
		"chain_jump_multiplier": 1.0,
	}


func _keys_to_strings(source: Dictionary[StringName, bool]) -> Array[String]:
	var result: Array[String] = []
	for key: StringName in source:
		if source[key]:
			result.append(String(key))
	return result


func _names_to_strings(source: Array[StringName]) -> Array[String]:
	var result: Array[String] = []
	for value: StringName in source:
		result.append(String(value))
	return result
