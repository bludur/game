class_name GrimoireData
extends Resource

@export var starting_knowledge: Array[StringName] = []
@export var starting_recipes: Array[StringName] = []
@export_range(1, 6, 1) var maximum_active_nodes: int = 3
@export var respec_item_id: StringName = &"ritual_chalk"
@export_range(1, 20, 1) var respec_item_quantity: int = 3
@export var fragments: Array[KnowledgeFragmentData] = []
@export var nodes: Array[KnowledgeNodeData] = []


func get_node_data(node_id: StringName) -> KnowledgeNodeData:
	for node_data: KnowledgeNodeData in nodes:
		if node_data != null and node_data.node_id == node_id:
			return node_data
	return null


func get_fragment(fragment_id: StringName) -> KnowledgeFragmentData:
	for fragment: KnowledgeFragmentData in fragments:
		if fragment != null and fragment.fragment_id == fragment_id:
			return fragment
	return null


func get_fragment_for_source(source_id: StringName) -> KnowledgeFragmentData:
	for fragment: KnowledgeFragmentData in fragments:
		if fragment != null and fragment.source_id == source_id:
			return fragment
	return null


func is_valid_definition() -> bool:
	var node_ids: Dictionary[StringName, bool] = {}
	var fragment_ids: Dictionary[StringName, bool] = {}
	for fragment: KnowledgeFragmentData in fragments:
		if fragment == null or not fragment.is_valid_definition() \
				or fragment_ids.has(fragment.fragment_id):
			return false
		fragment_ids[fragment.fragment_id] = true
	for node_data: KnowledgeNodeData in nodes:
		if node_data == null or not node_data.is_valid_definition() or node_ids.has(node_data.node_id):
			return false
		node_ids[node_data.node_id] = true
	for node_data: KnowledgeNodeData in nodes:
		for fragment_id: StringName in node_data.required_fragment_ids:
			if not fragment_ids.has(fragment_id):
				return false
		for prerequisite_id: StringName in node_data.prerequisite_node_ids:
			if not node_ids.has(prerequisite_id):
				return false
		for incompatible_id: StringName in node_data.incompatible_node_ids:
			if not node_ids.has(incompatible_id) or incompatible_id == node_data.node_id:
				return false
	return nodes.size() == 12 and maximum_active_nodes > 0 and not respec_item_id.is_empty()
