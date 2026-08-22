extends GutTest

const HURTBOX_SCENE: PackedScene = preload("res://scenes/components/hurtbox_component.tscn")

var _resolver: ChainTargetResolver


func before_each() -> void:
	_resolver = ChainTargetResolver.new()
	add_child_autofree(_resolver)


func test_chain_starts_near_aim_then_jumps_once_per_hostile_target() -> void:
	var near_origin: HurtboxComponent = _create_target(Vector3(0.5, 0.0, 0.0), &"enemy")
	var aimed: HurtboxComponent = _create_target(Vector3(5.0, 0.0, 0.0), &"enemy")
	var next: HurtboxComponent = _create_target(Vector3(8.0, 0.0, 0.0), &"enemy")
	var third: HurtboxComponent = _create_target(Vector3(9.5, 0.0, 0.0), &"enemy")
	var friendly: HurtboxComponent = _create_target(Vector3(6.0, 0.0, 0.0), &"player")
	var far: HurtboxComponent = _create_target(Vector3(15.0, 0.0, 0.0), &"enemy")
	var candidates: Array[HurtboxComponent] = [far, friendly, near_origin, third, next, aimed]

	var result: Array[HurtboxComponent] = _resolver.resolve_chain(
		Vector3.ZERO, Vector3(5.1, 0.0, 0.0), candidates, &"player", 10.0, 3.5, 3
	)

	assert_eq(result, [aimed, next, third])
	assert_false(result.has(friendly))
	assert_false(result.has(far))
	assert_eq(_unique_target_count(result), result.size())


func test_chain_returns_empty_without_a_live_hostile_target() -> void:
	var friendly: HurtboxComponent = _create_target(Vector3.ONE, &"player")
	var dead: HurtboxComponent = _create_target(Vector3(2.0, 0.0, 0.0), &"enemy")
	dead.health_component.take_damage(1000.0)
	var result: Array[HurtboxComponent] = _resolver.resolve_chain(
		Vector3.ZERO, Vector3.ONE, [friendly, dead], &"player", 10.0, 4.0, 3
	)
	assert_true(result.is_empty())


func _create_target(position: Vector3, faction: StringName) -> HurtboxComponent:
	var health: HealthComponent = HealthComponent.new()
	add_child_autofree(health)
	var hurtbox: HurtboxComponent = HURTBOX_SCENE.instantiate() as HurtboxComponent
	add_child_autofree(hurtbox)
	hurtbox.global_position = position
	hurtbox.faction = faction
	hurtbox.bind_health(health)
	return hurtbox


func _unique_target_count(targets: Array[HurtboxComponent]) -> int:
	var ids: Array[int] = []
	for target: HurtboxComponent in targets:
		if not ids.has(target.get_instance_id()):
			ids.append(target.get_instance_id())
	return ids.size()
