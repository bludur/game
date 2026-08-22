class_name GrimoireState
extends Node

signal knowledge_unlocked(knowledge_id: StringName)
signal recipe_unlocked(recipe_id: StringName)

@export var definition: GrimoireData

var unlocked_knowledge: Dictionary[StringName, bool] = {}
var unlocked_recipes: Dictionary[StringName, bool] = {}


func _ready() -> void:
	if definition == null:
		return
	for knowledge_id: StringName in definition.starting_knowledge:
		unlocked_knowledge[knowledge_id] = true
	for recipe_id: StringName in definition.starting_recipes:
		unlocked_recipes[recipe_id] = true


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


func serialize_state() -> Dictionary:
	return {
		"knowledge": _keys_to_strings(unlocked_knowledge),
		"recipes": _keys_to_strings(unlocked_recipes),
	}


func apply_state(state: Dictionary) -> void:
	unlocked_knowledge.clear()
	unlocked_recipes.clear()
	for knowledge_id: Variant in state.get("knowledge", []):
		unlocked_knowledge[StringName(String(knowledge_id))] = true
	for recipe_id: Variant in state.get("recipes", []):
		unlocked_recipes[StringName(String(recipe_id))] = true


func _keys_to_strings(source: Dictionary[StringName, bool]) -> Array[String]:
	var result: Array[String] = []
	for key: StringName in source:
		if source[key]:
			result.append(String(key))
	return result
