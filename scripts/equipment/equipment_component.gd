class_name EquipmentComponent
extends Node

signal equipment_changed(slot: EquipmentData.Slot, item: ItemData)
signal drop_requested(item: ItemData, quantity: int)

var _inventory: InventoryComponent
var _health: HealthComponent
var _mana: ManaComponent
var _stamina: StaminaComponent
var _corruption: CorruptionComponent
var _focus_item: ItemData
var _robe_item: ItemData
var _talisman_item: ItemData
var _focus_visual: MeshInstance3D
var _robe_visuals: Array[MeshInstance3D] = []


func bind(
	inventory: InventoryComponent,
	health: HealthComponent,
	mana: ManaComponent,
	stamina: StaminaComponent,
	corruption: CorruptionComponent,
	focus_visual: MeshInstance3D = null,
	robe_visuals: Array[MeshInstance3D] = []
) -> void:
	_inventory = inventory
	_health = health
	_mana = mana
	_stamina = stamina
	_corruption = corruption
	_focus_visual = focus_visual
	_robe_visuals = robe_visuals
	_refresh_visuals()


func equip_from_inventory(slot_index: int) -> bool:
	if not is_instance_valid(_inventory) or slot_index < 0 or slot_index >= _inventory.slots.size():
		return false
	var inventory_slot: InventorySlot = _inventory.slots[slot_index]
	if inventory_slot.is_empty() or inventory_slot.item.equipment == null:
		return false
	var incoming_item: ItemData = inventory_slot.item
	var definition: EquipmentData = incoming_item.equipment
	if not definition.is_valid_definition() or not definition.matches_item(incoming_item):
		return false
	var previous_item: ItemData = get_equipped_item(definition.slot)
	if _inventory.remove_from_slot(slot_index, 1) != 1:
		return false
	_set_equipped_item(definition.slot, incoming_item)
	if previous_item != null and _inventory.add_item(previous_item, 1) > 0:
		drop_requested.emit(previous_item, 1)
	_emit_slot_changed(definition.slot)
	return true


func unequip(slot: EquipmentData.Slot, drop_if_full: bool = false) -> bool:
	var equipped_item: ItemData = get_equipped_item(slot)
	if equipped_item == null or not is_instance_valid(_inventory):
		return false
	if _inventory.can_accept(equipped_item, 1):
		_set_equipped_item(slot, null)
		_inventory.add_item(equipped_item, 1)
		_emit_slot_changed(slot)
		return true
	if not drop_if_full:
		return false
	_set_equipped_item(slot, null)
	drop_requested.emit(equipped_item, 1)
	_emit_slot_changed(slot)
	return true


func get_equipped_item(slot: EquipmentData.Slot) -> ItemData:
	match slot:
		EquipmentData.Slot.FOCUS:
			return _focus_item
		EquipmentData.Slot.ROBE:
			return _robe_item
		EquipmentData.Slot.TALISMAN:
			return _talisman_item
		_:
			return null


func get_spell_profile(spell: SpellData) -> Dictionary:
	var profile: Dictionary = {
		"cooldown_multiplier": 1.0,
		"mana_cost_multiplier": 1.0,
		"damage_multiplier": 1.0,
		"projectile_speed_multiplier": 1.0,
		"area_radius_multiplier": 1.0,
		"effect_duration_multiplier": 1.0,
		"chain_jump_multiplier": 1.0,
	}
	for item: ItemData in [_focus_item, _robe_item, _talisman_item]:
		if item == null or item.equipment == null:
			continue
		var equipment: EquipmentData = item.equipment
		profile["cooldown_multiplier"] *= equipment.cooldown_multiplier
		profile["mana_cost_multiplier"] *= equipment.mana_cost_multiplier
		profile["damage_multiplier"] *= equipment.damage_multiplier
		profile["projectile_speed_multiplier"] *= equipment.projectile_speed_multiplier
		profile["area_radius_multiplier"] *= equipment.area_radius_multiplier
		profile["effect_duration_multiplier"] *= equipment.effect_duration_multiplier
		profile["chain_jump_multiplier"] *= equipment.chain_jump_multiplier
		if spell != null and spell.school == equipment.school_affinity:
			profile["damage_multiplier"] *= equipment.affinity_damage_multiplier
		if _condition_is_active(equipment):
			profile["damage_multiplier"] *= equipment.conditional_damage_multiplier
			profile["cooldown_multiplier"] *= equipment.conditional_cooldown_multiplier
	return profile


func filter_incoming_damage(damage: float) -> float:
	var multiplier: float = 1.0
	for item: ItemData in [_focus_item, _robe_item, _talisman_item]:
		if item == null or item.equipment == null:
			continue
		var equipment: EquipmentData = item.equipment
		multiplier *= equipment.incoming_damage_multiplier
		if _condition_is_active(equipment):
			multiplier *= equipment.conditional_incoming_damage_multiplier
	return maxf(0.0, damage * multiplier)


func notify_spell_cast(_spell: SpellData) -> void:
	if not is_instance_valid(_corruption):
		return
	var corruption_cost: float = 0.0
	for item: ItemData in [_focus_item, _robe_item, _talisman_item]:
		if item != null and item.equipment != null:
			corruption_cost += item.equipment.corruption_per_cast
	if corruption_cost > 0.0:
		_corruption.add_corruption(corruption_cost, &"forbidden_equipment")


func serialize_state() -> Dictionary:
	return {
		"focus": _item_id_or_empty(_focus_item),
		"robe": _item_id_or_empty(_robe_item),
		"talisman": _item_id_or_empty(_talisman_item),
	}


func apply_state(state: Dictionary, catalog: ItemCatalog) -> void:
	_focus_item = _resolve_saved_item(state, "focus", EquipmentData.Slot.FOCUS, catalog)
	_robe_item = _resolve_saved_item(state, "robe", EquipmentData.Slot.ROBE, catalog)
	_talisman_item = _resolve_saved_item(state, "talisman", EquipmentData.Slot.TALISMAN, catalog)
	for slot: EquipmentData.Slot in [
		EquipmentData.Slot.FOCUS,
		EquipmentData.Slot.ROBE,
		EquipmentData.Slot.TALISMAN,
	]:
		_emit_slot_changed(slot)


func _set_equipped_item(slot: EquipmentData.Slot, item: ItemData) -> void:
	match slot:
		EquipmentData.Slot.FOCUS:
			_focus_item = item
		EquipmentData.Slot.ROBE:
			_robe_item = item
		EquipmentData.Slot.TALISMAN:
			_talisman_item = item


func _emit_slot_changed(slot: EquipmentData.Slot) -> void:
	_refresh_visuals()
	equipment_changed.emit(slot, get_equipped_item(slot))


func _condition_is_active(equipment: EquipmentData) -> bool:
	match equipment.condition:
		EquipmentData.Condition.HIGH_MANA:
			return is_instance_valid(_mana) and _mana.get_mana_ratio() >= equipment.condition_threshold
		EquipmentData.Condition.LOW_HEALTH:
			return is_instance_valid(_health) and _health.get_health_ratio() <= equipment.condition_threshold
		EquipmentData.Condition.HIGH_CORRUPTION:
			return is_instance_valid(_corruption) \
				and _corruption.current_corruption / _corruption.maximum_corruption >= equipment.condition_threshold
		EquipmentData.Condition.HIGH_STAMINA:
			return is_instance_valid(_stamina) \
				and _stamina.get_stamina_ratio() >= equipment.condition_threshold
		_:
			return true


func _refresh_visuals() -> void:
	if is_instance_valid(_focus_visual):
		_focus_visual.visible = _focus_item != null
		if _focus_item != null:
			_focus_visual.material_override = _make_material(_focus_item.equipment.accent_color)
			_focus_visual.scale = Vector3.ONE * (1.0 + float(_focus_item.equipment.visual_variant) * 0.12)
	for visual_index: int in _robe_visuals.size():
		var visual: MeshInstance3D = _robe_visuals[visual_index]
		if not is_instance_valid(visual):
			continue
		visual.visible = _robe_item != null and visual_index <= _robe_item.equipment.visual_variant
		if _robe_item != null:
			visual.material_override = _make_material(_robe_item.equipment.accent_color)


func _make_material(color: Color) -> StandardMaterial3D:
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.72
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = 0.35
	return material


func _resolve_saved_item(
	state: Dictionary,
	key: String,
	expected_slot: EquipmentData.Slot,
	catalog: ItemCatalog
) -> ItemData:
	if catalog == null:
		return null
	var item_id: StringName = StringName(String(state.get(key, "")))
	var item: ItemData = catalog.get_item(item_id)
	if item == null or item.equipment == null or item.equipment.slot != expected_slot:
		return null
	return item


func _item_id_or_empty(item: ItemData) -> String:
	return String(item.item_id) if item != null else ""
