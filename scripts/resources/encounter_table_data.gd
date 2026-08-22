class_name EncounterTableData
extends Resource

@export var region_id: StringName = &""
@export var roles: Array[EnemyRoleData] = []
@export var mutations: Array[EnemyMutationData] = []
@export var entries: Array[EncounterEntryData] = []
@export var lairs: Array[EnemyLairData] = []


func get_role(role_id: StringName) -> EnemyRoleData:
	for role: EnemyRoleData in roles:
		if role != null and role.role_id == role_id:
			return role
	return null


func get_mutation(mutation_id: StringName) -> EnemyMutationData:
	for mutation: EnemyMutationData in mutations:
		if mutation != null and mutation.mutation_id == mutation_id:
			return mutation
	return null


func get_entry(encounter_id: StringName) -> EncounterEntryData:
	for entry: EncounterEntryData in entries:
		if entry != null and entry.encounter_id == encounter_id:
			return entry
	return null


func get_matching_entries(
	is_night: bool,
	corruption: float,
	tier: int,
	poi_kind: int
) -> Array[EncounterEntryData]:
	var matches: Array[EncounterEntryData] = []
	for entry: EncounterEntryData in entries:
		if entry != null and entry.matches(is_night, corruption, tier, poi_kind):
			matches.append(entry)
	return matches


func is_valid_catalog() -> bool:
	if region_id.is_empty() or roles.size() != 6 or mutations.size() != 2 or lairs.is_empty():
		return false
	var role_ids: Dictionary[StringName, bool] = {}
	for role: EnemyRoleData in roles:
		if role == null or not role.is_valid_definition() or role_ids.has(role.role_id):
			return false
		role_ids[role.role_id] = true
	var mutation_ids: Dictionary[StringName, bool] = {}
	for mutation: EnemyMutationData in mutations:
		if mutation == null or not mutation.is_valid_definition() \
				or mutation_ids.has(mutation.mutation_id):
			return false
		mutation_ids[mutation.mutation_id] = true
	for entry: EncounterEntryData in entries:
		if entry == null or not entry.is_valid_definition():
			return false
		for role_id: StringName in entry.role_ids:
			if not role_ids.has(role_id):
				return false
	for lair: EnemyLairData in lairs:
		if lair == null or not lair.is_valid_definition() or get_entry(lair.encounter_id) == null:
			return false
	return true
