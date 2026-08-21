extends Node

@export var continue_to_victory: bool = false
@export var force_defeat: bool = false


func _ready() -> void:
	call_deferred("_prepare_upgrade_preview")


func _prepare_upgrade_preview() -> void:
	await get_tree().process_frame
	var main: Node = get_node("Main")
	var director: RunDirector = main.get_node("RunDirector") as RunDirector
	var waves: WaveDirector = main.get_node("WaveDirector") as WaveDirector
	var player: MagePlayer = get_tree().get_first_node_in_group(&"player") as MagePlayer
	director.intermission_duration = 0.01
	director.start_new_run(true)
	if force_defeat:
		player.get_health_component().take_damage(1000.0)
		return
	player.get_hurtbox_component().grant_invulnerability(30.0)
	await _defeat_wave(waves)
	for _frame: int in 4:
		await get_tree().physics_frame
	await _defeat_wave(waves)
	if continue_to_victory:
		director.choose_upgrade(0)
		await _defeat_wave(waves)


func _defeat_wave(waves: WaveDirector) -> void:
	var expected: int = waves.get_remaining_count()
	for _frame: int in 180:
		if waves.get_spawned_enemies().size() == expected:
			break
		await get_tree().physics_frame
	for enemy: Node in waves.get_spawned_enemies():
		if enemy is ChaserEnemy:
			(enemy as ChaserEnemy).get_health_component().take_damage(1000.0)
		elif enemy is CultistEnemy:
			(enemy as CultistEnemy).get_health_component().take_damage(1000.0)
	await get_tree().process_frame
