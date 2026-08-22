class_name UiTranslations
extends RefCounted

static var _installed: bool = false


static func ensure_registered() -> void:
	if _installed:
		return
	_installed = true
	_register("en", {
		"HUD_HEALTH": "HEALTH  %d / %d", "HUD_MANA": "MANA  %d / %d",
		"HUD_READY": "%s  READY", "HUD_COOLDOWN": "%s  %.1fs",
		"HUD_SLOTS": "[1] BOLT   [2] FROST   [3] LIGHTNING   ACTIVE: %d",
		"HUD_DASH_READY": "DASH  READY", "HUD_DASH_COOLDOWN": "DASH  %.1fs",
		"HUD_WAVE": "WAVE %d/3  •  %d LEFT", "HUD_WAVE_NAME": "WAVE %d/3  •  %s  •  %d LEFT",
		"HUD_INSTRUCTIONS": "WASD — MOVE   •   SHIFT — DASH   •   1/2/3 — SPELL   •   LEFT CLICK — CAST",
		"RUN_INTRO_TITLE": "THE WITCHING HOUR", "RUN_INTRO_SUBTITLE": "Survive the omens. Choose your power. Break the conclave.",
		"RUN_FINAL_TITLE": "FINAL WAVE", "RUN_FINAL_SUBTITLE": "The Arena Warden has awakened.",
		"RUN_UPGRADE_TITLE": "CHOOSE ONE RUNE", "RUN_VICTORY": "VICTORY", "RUN_DEFEAT": "DEFEAT",
		"RUN_VICTORY_TEXT": "The Warden is broken. Your rune endures until the next run.",
		"RUN_DEFEAT_TEXT": "The arena claimed the mage. Begin again with a clean spellbook.",
		"RESULT_MENU": "Return to Main Menu",
	})
	_register("ru", {
		"HUD_HEALTH": "ЗДОРОВЬЕ  %d / %d", "HUD_MANA": "МАНА  %d / %d",
		"HUD_READY": "%s  ГОТОВО", "HUD_COOLDOWN": "%s  %.1fс",
		"HUD_SLOTS": "[1] СФЕРА   [2] МОРОЗ   [3] МОЛНИЯ   АКТИВНО: %d",
		"HUD_DASH_READY": "РЫВОК  ГОТОВ", "HUD_DASH_COOLDOWN": "РЫВОК  %.1fс",
		"HUD_WAVE": "ВОЛНА %d/3  •  ОСТАЛОСЬ %d", "HUD_WAVE_NAME": "ВОЛНА %d/3  •  %s  •  ОСТАЛОСЬ %d",
		"HUD_INSTRUCTIONS": "WASD — ДВИЖЕНИЕ   •   SHIFT — РЫВОК   •   1/2/3 — ЗАКЛИНАНИЕ   •   ЛКМ — АТАКА",
		"RUN_INTRO_TITLE": "ЧАС КОЛДОВСТВА", "RUN_INTRO_SUBTITLE": "Переживите знамения, выберите силу и сокрушите конклав.",
		"RUN_FINAL_TITLE": "ФИНАЛ", "RUN_FINAL_SUBTITLE": "Хранитель арены пробудился.",
		"RUN_UPGRADE_TITLE": "ВЫБЕРИТЕ ОДНУ РУНУ", "RUN_VICTORY": "ПОБЕДА", "RUN_DEFEAT": "ПОРАЖЕНИЕ",
		"RUN_VICTORY_TEXT": "Хранитель повержен. Руна действует до следующего забега.",
		"RUN_DEFEAT_TEXT": "Арена забрала мага. Новый забег начнётся с чистой книгой заклинаний.",
		"RESULT_MENU": "Вернуться в главное меню",
	})


static func _register(locale_code: String, messages: Dictionary) -> void:
	var translation: Translation = Translation.new()
	translation.locale = locale_code
	for key: String in messages:
		translation.add_message(StringName(key), String(messages[key]))
	TranslationServer.add_translation(translation)
