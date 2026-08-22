extends GutTest

const PLAYER_SCENE: PackedScene = preload("res://scenes/characters/player/player.tscn")
const CHASER_SCENE: PackedScene = preload("res://scenes/enemies/chaser_enemy.tscn")
const CULTIST_SCENE: PackedScene = preload("res://scenes/enemies/cultist_enemy.tscn")


func test_stylized_characters_share_animation_contract() -> void:
	var scenes: Array[PackedScene] = [PLAYER_SCENE, CHASER_SCENE, CULTIST_SCENE]
	for character_scene: PackedScene in scenes:
		var character: Node = character_scene.instantiate()
		add_child_autofree(character)
		var animator: CharacterAnimator = character.get_node_or_null("CharacterAnimator") as CharacterAnimator
		assert_not_null(animator)
		assert_not_null(character.get_node_or_null("Visuals/ModelRoot"))
		for animation_name: StringName in [&"idle", &"move", &"run", &"jump", &"cast", &"hit", &"dash", &"death"]:
			assert_true(animator.has_animation(animation_name))
		animator.play_cast()
		assert_eq(animator.get_current_animation_name(), &"cast")


func test_animator_returns_to_movement_after_one_shot() -> void:
	var player: MagePlayer = PLAYER_SCENE.instantiate() as MagePlayer
	add_child_autofree(player)
	player.set_controls_enabled(false)
	var animator: CharacterAnimator = player.get_node("CharacterAnimator") as CharacterAnimator
	animator.set_moving(true)
	animator.play_hit()
	await get_tree().create_timer(0.25).timeout
	assert_eq(animator.get_current_animation_name(), &"move")


func test_animator_distinguishes_run_and_airborne_locomotion() -> void:
	var player: MagePlayer = PLAYER_SCENE.instantiate() as MagePlayer
	add_child_autofree(player)
	player.set_controls_enabled(false)
	var animator: CharacterAnimator = player.get_node("CharacterAnimator") as CharacterAnimator
	animator.set_locomotion(true, true, false)
	assert_eq(animator.get_current_animation_name(), &"run")
	animator.set_locomotion(true, false, true)
	assert_eq(animator.get_current_animation_name(), &"jump")
