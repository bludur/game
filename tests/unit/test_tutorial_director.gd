extends GutTest

const ARENA_SCENE: PackedScene = preload("res://scenes/main/arena_run.tscn")


func test_tutorial_advances_in_order_and_does_not_consume_gameplay() -> void:
	var arena: Node = ARENA_SCENE.instantiate()
	add_child_autofree(arena)
	await get_tree().process_frame
	var tutorial: TutorialDirector = arena.get_node("TutorialDirector") as TutorialDirector
	assert_eq(tutorial.get_step_name(), &"move")
	assert_eq((tutorial.get_node("Root") as Control).mouse_filter, Control.MOUSE_FILTER_IGNORE)

	tutorial.notify_cast()
	assert_eq(tutorial.get_step_name(), &"move")
	tutorial.notify_movement()
	tutorial.notify_cast()
	tutorial.notify_spell_switched(null, 1)
	tutorial.notify_dash()
	tutorial.notify_upgrade()
	assert_true(tutorial.is_completed())


func test_tutorial_can_be_skipped_without_changing_run_state() -> void:
	var arena: Node = ARENA_SCENE.instantiate()
	add_child_autofree(arena)
	await get_tree().process_frame
	var tutorial: TutorialDirector = arena.get_node("TutorialDirector") as TutorialDirector
	var director: RunDirector = arena.get_node("RunDirector") as RunDirector
	var state_before: RunDirector.State = director.current_state
	tutorial.skip()
	assert_true(tutorial.is_completed())
	assert_eq(director.current_state, state_before)


func test_release_hud_has_localized_copy_and_version() -> void:
	TranslationServer.set_locale("ru")
	var arena: Node = ARENA_SCENE.instantiate()
	add_child_autofree(arena)
	await get_tree().process_frame
	var instructions: Label = arena.get_node("MageHud/Root/Instructions") as Label
	var version: Label = arena.get_node("SessionUi/Root/Version") as Label
	assert_ne(instructions.text, "HUD_INSTRUCTIONS")
	assert_true(instructions.text.contains("WASD"))
	assert_eq(version.text, "v%s" % BuildInfo.VERSION)
