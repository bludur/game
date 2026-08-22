class_name StatusEffectComponent
extends Node

signal effects_changed(active_effects: Array[ActiveStatusEffect])
signal effect_applied(definition: StatusEffectData)
signal effect_removed(effect_id: StringName)

@export var catalog: StatusEffectCatalog

var active_effects: Array[ActiveStatusEffect] = []
var _health: HealthComponent
var _mana: ManaComponent
var _stamina: StaminaComponent
var _base_max_health: float = 100.0
var _base_max_mana: float = 100.0
var _base_max_stamina: float = 100.0
var _base_mana_regeneration: float = 0.0
var _base_stamina_regeneration: float = 0.0
var _last_display_second: int = -1


func bind(health: HealthComponent, mana: ManaComponent, stamina: StaminaComponent) -> void:
	_health = health
	_mana = mana
	_stamina = stamina
	_base_max_health = health.max_health
	_base_max_mana = mana.max_mana
	_base_max_stamina = stamina.max_stamina
	_base_mana_regeneration = mana.regeneration_per_second
	_base_stamina_regeneration = stamina.regeneration_per_second
	_recompute_modifiers()


func _physics_process(delta: float) -> void:
	advance(delta)


func advance(delta: float) -> void:
	if delta <= 0.0 or active_effects.is_empty():
		return
	var health_regeneration: float = 0.0
	for active: ActiveStatusEffect in active_effects:
		var active_delta: float = minf(delta, active.remaining_seconds)
		active.remaining_seconds = maxf(0.0, active.remaining_seconds - delta)
		health_regeneration += active.definition.health_regeneration * active_delta
	if health_regeneration > 0.0 and is_instance_valid(_health):
		_health.heal(health_regeneration)
	var removed_ids: Array[StringName] = []
	for index: int in range(active_effects.size() - 1, -1, -1):
		if active_effects[index].remaining_seconds <= 0.0:
			removed_ids.append(active_effects[index].definition.effect_id)
			active_effects.remove_at(index)
	if not removed_ids.is_empty():
		_recompute_modifiers()
		for effect_id: StringName in removed_ids:
			effect_removed.emit(effect_id)
		_emit_changed()
		return
	var display_second: int = _get_highest_remaining_second()
	if display_second != _last_display_second:
		_emit_changed()


func apply_effect(definition: StatusEffectData) -> bool:
	if definition == null or not definition.is_valid_definition():
		return false
	if definition.preparation_slot != StatusEffectData.PreparationSlot.NONE:
		_remove_preparation_slot(definition.preparation_slot, definition.effect_id)
	var existing: ActiveStatusEffect = get_active_effect(definition.effect_id)
	if existing != null:
		_apply_stack_policy(existing, definition)
	else:
		active_effects.append(ActiveStatusEffect.new(definition, definition.duration_seconds))
	_recompute_modifiers()
	effect_applied.emit(definition)
	_emit_changed()
	return true


func apply_effect_by_id(effect_id: StringName) -> bool:
	return catalog != null and apply_effect(catalog.get_effect(effect_id))


func remove_effect(effect_id: StringName) -> bool:
	for index: int in active_effects.size():
		if active_effects[index].definition.effect_id == effect_id:
			active_effects.remove_at(index)
			_recompute_modifiers()
			effect_removed.emit(effect_id)
			_emit_changed()
			return true
	return false


func get_active_effect(effect_id: StringName) -> ActiveStatusEffect:
	for active: ActiveStatusEffect in active_effects:
		if active.definition.effect_id == effect_id:
			return active
	return null


func get_preparation_in_slot(slot: StatusEffectData.PreparationSlot) -> ActiveStatusEffect:
	for active: ActiveStatusEffect in active_effects:
		if active.definition.preparation_slot == slot:
			return active
	return null


func get_resistance(resistance_type: StatusEffectData.ResistanceType) -> float:
	var total: float = 0.0
	for active: ActiveStatusEffect in active_effects:
		total += active.definition.get_resistance(resistance_type)
	return clampf(total, 0.0, 0.85)


func serialize_state() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for active: ActiveStatusEffect in active_effects:
		result.append(active.serialize())
	return result


func apply_state(data: Array) -> void:
	active_effects.clear()
	if catalog != null:
		for raw_entry: Variant in data:
			if raw_entry is not Dictionary:
				continue
			var entry: Dictionary = raw_entry as Dictionary
			var definition: StatusEffectData = catalog.get_effect(
				StringName(String(entry.get("effect_id", "")))
			)
			if definition == null:
				continue
			var remaining: float = clampf(
				float(entry.get("remaining_seconds", 0.0)),
				0.0,
				definition.duration_seconds * 3.0
			)
			if remaining > 0.0:
				active_effects.append(ActiveStatusEffect.new(definition, remaining))
	_recompute_modifiers()
	_emit_changed()


func _apply_stack_policy(existing: ActiveStatusEffect, incoming: StatusEffectData) -> void:
	match incoming.stack_policy:
		StatusEffectData.StackPolicy.REPLACE:
			existing.definition = incoming
			existing.remaining_seconds = incoming.duration_seconds
		StatusEffectData.StackPolicy.EXTEND:
			existing.remaining_seconds = minf(
				existing.remaining_seconds + incoming.duration_seconds,
				incoming.duration_seconds * 3.0
			)
		StatusEffectData.StackPolicy.KEEP_STRONGEST:
			if incoming.get_power_score() > existing.definition.get_power_score():
				existing.definition = incoming
			existing.remaining_seconds = maxf(existing.remaining_seconds, incoming.duration_seconds)
		_:
			existing.remaining_seconds = maxf(existing.remaining_seconds, incoming.duration_seconds)


func _remove_preparation_slot(
	slot: StatusEffectData.PreparationSlot,
	except_effect_id: StringName
) -> void:
	for index: int in range(active_effects.size() - 1, -1, -1):
		var active: ActiveStatusEffect = active_effects[index]
		if active.definition.preparation_slot == slot \
				and active.definition.effect_id != except_effect_id:
			var removed_id: StringName = active.definition.effect_id
			active_effects.remove_at(index)
			effect_removed.emit(removed_id)


func _recompute_modifiers() -> void:
	if not is_instance_valid(_health) or not is_instance_valid(_mana) \
			or not is_instance_valid(_stamina):
		return
	var health_bonus: float = 0.0
	var mana_bonus: float = 0.0
	var stamina_bonus: float = 0.0
	var mana_regeneration_bonus: float = 0.0
	var stamina_regeneration_bonus: float = 0.0
	for active: ActiveStatusEffect in active_effects:
		health_bonus += active.definition.maximum_health_bonus
		mana_bonus += active.definition.maximum_mana_bonus
		stamina_bonus += active.definition.maximum_stamina_bonus
		mana_regeneration_bonus += active.definition.mana_regeneration_bonus
		stamina_regeneration_bonus += active.definition.stamina_regeneration_bonus
	_health.set_max_health(_base_max_health + health_bonus, true)
	_mana.set_max_mana(_base_max_mana + mana_bonus, true)
	_stamina.set_max_stamina(_base_max_stamina + stamina_bonus, true)
	_mana.regeneration_per_second = _base_mana_regeneration + mana_regeneration_bonus
	_stamina.regeneration_per_second = _base_stamina_regeneration + stamina_regeneration_bonus


func _emit_changed() -> void:
	_last_display_second = _get_highest_remaining_second()
	effects_changed.emit(active_effects.duplicate())


func _get_highest_remaining_second() -> int:
	var result: int = -1
	for active: ActiveStatusEffect in active_effects:
		result = maxi(result, ceili(active.remaining_seconds))
	return result
