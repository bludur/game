class_name ProgressJournal
extends Node

var _world_state: WorldState
var _grimoire: GrimoireState


func bind(world_state: WorldState, grimoire: GrimoireState) -> void:
	_world_state = world_state
	_grimoire = grimoire


func get_entries() -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	if _world_state == null or _grimoire == null:
		return entries
	if _world_state.active_region_id == &"moonbound_expanse":
		if not _world_state.has_ritual_flag(&"moon_eclipse_path_open"):
			entries.append(_entry(
				&"moon_ritual", "Открыть путь затмения",
				"Соберите 2 ночных стекла и 2 кристалла лунного инея у Обсерватории."
			))
		elif not _world_state.has_progression_flag(&"moon_eater_defeated"):
			entries.append(_entry(
				&"moon_eater", "Победить Пожирателя Луны",
				"Используйте смену света и тени хранителя, чтобы выбирать момент атаки."
			))
		else:
			entries.append(_entry(
				&"moon_complete", "Вернуться с сердцем затмения",
				"Предел покорён. Великий портал вернёт вас в Пепельную рощу."
			))
		return entries
	if not _world_state.has_ritual_flag(&"crypt_unsealed"):
		entries.append(_entry(
			&"unseal_crypt", "Открыть Беззвёздный склеп",
			"Исследуйте Рощу, приготовьте ритуальные компоненты и проведите ритуал снятия печати."
		))
	elif not _world_state.has_progression_flag(&"matriarch_defeated"):
		entries.append(_entry(
			&"defeat_matriarch", "Очистить Укоренённую матриархиню",
			"Решите руническую загадку склепа и сожгите защитные корни ведьминым огнём."
		))
	elif not _grimoire.is_recipe_unlocked(&"great_portal_focus"):
		entries.append(_entry(
			&"learn_portal_focus", "Расшифровать фокус Великого портала",
			"Откройте узел III ступени в Гримуаре, используя сердце Матриархини."
		))
	else:
		entries.append(_entry(
			&"craft_portal_focus", "Собрать фокус Великого портала",
			"Нужны сердце Матриархини, усиленная эссенция оберега и тайные нити."
		))
	var next_node: KnowledgeNodeData = _grimoire.get_next_achievable_node()
	if next_node != null:
		entries.append(_entry(
			&"grimoire_next", "Следующая запись: %s" % next_node.display_name,
			_grimoire.get_unlock_hint(next_node.node_id)
		))
	return entries


func _entry(entry_id: StringName, title: String, hint: String) -> Dictionary:
	return {"id": entry_id, "title": title, "hint": hint}
