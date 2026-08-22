class_name UiTranslations
extends RefCounted

static var _installed: bool = false


static func ensure_registered() -> void:
	if _installed:
		return
	_installed = true
	_register("en", {
		"HUD_TITLE": "THE WITCH'S FOCUS",
		"HUD_HEALTH": "HEALTH  %d / %d", "HUD_MANA": "MANA  %d / %d",
		"HUD_READY": "%s  READY", "HUD_COOLDOWN": "%s  %.1fs",
		"HUD_SLOTS": "[1] BOLT   [2] FROST   [3] LIGHTNING   ACTIVE: %d",
		"HUD_DASH_READY": "DASH  READY", "HUD_DASH_COOLDOWN": "DASH  %.1fs",
		"HUD_WAVE": "WAVE %d/3  •  %d LEFT", "HUD_WAVE_NAME": "WAVE %d/3  •  %s  •  %d LEFT",
		"HUD_INSTRUCTIONS": "WASD — MOVE   •   SHIFT — DASH   •   1/2/3 — SPELL   •   LEFT CLICK — CAST",
		"SPELL_ARCANE_BOLT": "ARCANE BOLT", "SPELL_FROST_CIRCLE": "FROST CIRCLE",
		"SPELL_CHAIN_LIGHTNING": "CHAIN LIGHTNING", "BOSS_ARENA_WARDEN": "ARENA WARDEN",
		"BOSS_PHASE": "PHASE %d / 2", "RUN_UPGRADE_HINT": "The choice lasts for this run only.",
		"RUN_RESTART": "BEGIN A NEW RUN", "RUN_UNAVAILABLE": "UNAVAILABLE",
		"UPGRADE_ARCANE_DAMAGE_NAME": "FOCUSED STAR", "UPGRADE_ARCANE_DAMAGE_DESC": "Arcane Bolt deals 8 additional damage.",
		"UPGRADE_CHAIN_DAMAGE_NAME": "STORM CROWN", "UPGRADE_CHAIN_DAMAGE_DESC": "+10 Chain Lightning damage per target.",
		"UPGRADE_MANA_CAPACITY_NAME": "DEEP RESERVOIR", "UPGRADE_MANA_CAPACITY_DESC": "+25 maximum mana and refill it.",
		"UPGRADE_MANA_REGENERATION_NAME": "DEEP CURRENT", "UPGRADE_MANA_REGENERATION_DESC": "Mana regeneration increases by 7 per second.",
		"UPGRADE_MAXIMUM_HEALTH_NAME": "RUNIC VESSEL", "UPGRADE_MAXIMUM_HEALTH_DESC": "Maximum health increases by 30 and is fully restored.",
		"UPGRADE_RAPID_DASH_NAME": "WINDSTEP SIGIL", "UPGRADE_RAPID_DASH_DESC": "-0.35 seconds Dash cooldown.",
		"RUN_INTRO_TITLE": "THE WITCHING HOUR", "RUN_INTRO_SUBTITLE": "Survive the omens. Choose your power. Break the conclave.",
		"RUN_FINAL_TITLE": "FINAL WAVE", "RUN_FINAL_SUBTITLE": "The Arena Warden has awakened.",
		"RUN_UPGRADE_TITLE": "CHOOSE ONE RUNE", "RUN_VICTORY": "VICTORY", "RUN_DEFEAT": "DEFEAT",
		"RUN_VICTORY_TEXT": "The Warden is broken. Your rune endures until the next run.",
		"RUN_DEFEAT_TEXT": "The arena claimed the mage. Begin again with a clean spellbook.",
		"RESULT_MENU": "Return to Main Menu",
		"TUTORIAL_PROGRESS": "LESSON %d/%d", "TUTORIAL_MOVE": "Move with WASD or the left stick.",
		"TUTORIAL_CAST": "Aim and cast with left click or the right trigger.",
		"TUTORIAL_SWITCH": "Switch spells with 1/2/3 or the D-pad.",
		"TUTORIAL_DASH": "Dash with Shift or the south face button.",
		"TUTORIAL_UPGRADE": "Survive two waves, then choose one rune.",
		"TUTORIAL_SKIP": "F1 / BACK — HIDE TUTORIAL",
		"TUTORIAL_COMPLETE_TITLE": "LESSONS COMPLETE", "TUTORIAL_COMPLETE_PROMPT": "The arena is yours to read.",
	})
	_register("ru", {
		"HUD_TITLE": "ФОКУС ВЕДЬМЫ",
		"HUD_HEALTH": "ЗДОРОВЬЕ  %d / %d", "HUD_MANA": "МАНА  %d / %d",
		"HUD_READY": "%s  ГОТОВО", "HUD_COOLDOWN": "%s  %.1fс",
		"HUD_SLOTS": "[1] СФЕРА   [2] МОРОЗ   [3] МОЛНИЯ   АКТИВНО: %d",
		"HUD_DASH_READY": "РЫВОК  ГОТОВ", "HUD_DASH_COOLDOWN": "РЫВОК  %.1fс",
		"HUD_WAVE": "ВОЛНА %d/3  •  ОСТАЛОСЬ %d", "HUD_WAVE_NAME": "ВОЛНА %d/3  •  %s  •  ОСТАЛОСЬ %d",
		"HUD_INSTRUCTIONS": "WASD — ДВИЖЕНИЕ   •   SHIFT — РЫВОК   •   1/2/3 — ЗАКЛИНАНИЕ   •   ЛКМ — АТАКА",
		"SPELL_ARCANE_BOLT": "ТАЙНАЯ СФЕРА", "SPELL_FROST_CIRCLE": "МОРОЗНЫЙ КРУГ",
		"SPELL_CHAIN_LIGHTNING": "ЦЕПНАЯ МОЛНИЯ", "BOSS_ARENA_WARDEN": "ХРАНИТЕЛЬ АРЕНЫ",
		"BOSS_PHASE": "ФАЗА %d / 2", "RUN_UPGRADE_HINT": "Выбор действует только в этом забеге.",
		"RUN_RESTART": "НАЧАТЬ НОВЫЙ ЗАБЕГ", "RUN_UNAVAILABLE": "НЕДОСТУПНО",
		"UPGRADE_ARCANE_DAMAGE_NAME": "СФОКУСИРОВАННАЯ ЗВЕЗДА", "UPGRADE_ARCANE_DAMAGE_DESC": "Тайная сфера наносит на 8 урона больше.",
		"UPGRADE_CHAIN_DAMAGE_NAME": "КОРОНА БУРИ", "UPGRADE_CHAIN_DAMAGE_DESC": "+10 урона Цепной молнии каждой цели.",
		"UPGRADE_MANA_CAPACITY_NAME": "ГЛУБОКИЙ РЕЗЕРВ", "UPGRADE_MANA_CAPACITY_DESC": "+25 к максимуму маны и полное восполнение.",
		"UPGRADE_MANA_REGENERATION_NAME": "ГЛУБОКОЕ ТЕЧЕНИЕ", "UPGRADE_MANA_REGENERATION_DESC": "Восстановление маны увеличено на 7 в секунду.",
		"UPGRADE_MAXIMUM_HEALTH_NAME": "РУНИЧЕСКИЙ СОСУД", "UPGRADE_MAXIMUM_HEALTH_DESC": "+30 к максимуму здоровья и полное лечение.",
		"UPGRADE_RAPID_DASH_NAME": "ПЕЧАТЬ ВЕТРОШАГА", "UPGRADE_RAPID_DASH_DESC": "Перезарядка рывка короче на 0,35 секунды.",
		"RUN_INTRO_TITLE": "ЧАС КОЛДОВСТВА", "RUN_INTRO_SUBTITLE": "Переживите знамения, выберите силу и сокрушите конклав.",
		"RUN_FINAL_TITLE": "ФИНАЛ", "RUN_FINAL_SUBTITLE": "Хранитель арены пробудился.",
		"RUN_UPGRADE_TITLE": "ВЫБЕРИТЕ ОДНУ РУНУ", "RUN_VICTORY": "ПОБЕДА", "RUN_DEFEAT": "ПОРАЖЕНИЕ",
		"RUN_VICTORY_TEXT": "Хранитель повержен. Руна действует до следующего забега.",
		"RUN_DEFEAT_TEXT": "Арена забрала мага. Новый забег начнётся с чистой книгой заклинаний.",
		"RESULT_MENU": "Вернуться в главное меню",
		"TUTORIAL_PROGRESS": "УРОК %d/%d", "TUTORIAL_MOVE": "Двигайтесь: WASD или левый стик.",
		"TUTORIAL_CAST": "Прицельтесь и атакуйте: ЛКМ или правый триггер.",
		"TUTORIAL_SWITCH": "Смените заклинание: 1/2/3 или крестовина.",
		"TUTORIAL_DASH": "Сделайте рывок: Shift или нижняя кнопка геймпада.",
		"TUTORIAL_UPGRADE": "Переживите две волны и выберите одну руну.",
		"TUTORIAL_SKIP": "F1 / BACK — СКРЫТЬ ОБУЧЕНИЕ",
		"TUTORIAL_COMPLETE_TITLE": "ОБУЧЕНИЕ ЗАВЕРШЕНО", "TUTORIAL_COMPLETE_PROMPT": "Теперь вы читаете знамения арены.",
	})


static func _register(locale_code: String, messages: Dictionary) -> void:
	var translation: Translation = Translation.new()
	translation.locale = locale_code
	for key: String in messages:
		translation.add_message(StringName(key), String(messages[key]))
	TranslationServer.add_translation(translation)
