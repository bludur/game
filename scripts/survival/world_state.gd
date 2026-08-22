class_name WorldState
extends Node

signal state_changed()

var resource_states: Dictionary[StringName, Dictionary] = {}
var ritual_flags: Dictionary[StringName, bool] = {}
var progression_flags: Dictionary[StringName, bool] = {}
var building_states: Array[Dictionary] = []
var raid_state: Dictionary = {}
var echo_state: Dictionary = {}
var last_hearth_id: StringName = &"hearth_ashen_clearing"
var region_tier: int = 1


func set_resource_state(persistent_id: StringName, state: Dictionary) -> void:
	resource_states[persistent_id] = state.duplicate(true)
	state_changed.emit()


func set_ritual_flag(flag_id: StringName, value: bool = true) -> void:
	ritual_flags[flag_id] = value
	state_changed.emit()


func has_ritual_flag(flag_id: StringName) -> bool:
	return ritual_flags.get(flag_id, false)


func set_progression_flag(flag_id: StringName, value: bool = true) -> void:
	progression_flags[flag_id] = value
	state_changed.emit()


func has_progression_flag(flag_id: StringName) -> bool:
	return progression_flags.get(flag_id, false)


func serialize_state() -> Dictionary:
	var resources: Dictionary[String, Dictionary] = {}
	for resource_id: StringName in resource_states:
		resources[String(resource_id)] = resource_states[resource_id].duplicate(true)
	var rituals: Dictionary[String, bool] = {}
	for ritual_id: StringName in ritual_flags:
		rituals[String(ritual_id)] = ritual_flags[ritual_id]
	var progression: Dictionary[String, bool] = {}
	for flag_id: StringName in progression_flags:
		progression[String(flag_id)] = progression_flags[flag_id]
	return {
		"resources": resources,
		"rituals": rituals,
		"progression": progression,
		"buildings": building_states.duplicate(true),
		"raid": raid_state.duplicate(true),
		"echo": echo_state.duplicate(true),
		"last_hearth_id": String(last_hearth_id),
		"region_tier": region_tier,
	}


func apply_state(state: Dictionary) -> void:
	resource_states.clear()
	var raw_resources: Dictionary = state.get("resources", {}) as Dictionary
	for resource_id: String in raw_resources:
		resource_states[StringName(resource_id)] = (raw_resources[resource_id] as Dictionary).duplicate(true)
	ritual_flags.clear()
	var raw_rituals: Dictionary = state.get("rituals", {}) as Dictionary
	for ritual_id: String in raw_rituals:
		ritual_flags[StringName(ritual_id)] = bool(raw_rituals[ritual_id])
	progression_flags.clear()
	var raw_progression: Dictionary = state.get("progression", {}) as Dictionary
	for flag_id: String in raw_progression:
		progression_flags[StringName(flag_id)] = bool(raw_progression[flag_id])
	building_states.assign(state.get("buildings", []))
	raid_state = (state.get("raid", {}) as Dictionary).duplicate(true)
	echo_state = (state.get("echo", {}) as Dictionary).duplicate(true)
	last_hearth_id = StringName(String(state.get("last_hearth_id", "hearth_ashen_clearing")))
	region_tier = maxi(1, int(state.get("region_tier", 1)))
	state_changed.emit()
