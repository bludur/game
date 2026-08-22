extends GutTest

const HURTBOX_SCENE: PackedScene = preload("res://scenes/components/hurtbox_component.tscn")

var _resolver: AimAssistResolver = AimAssistResolver.new()


func test_assist_selects_hostile_inside_small_cone_only() -> void:
	var inside: HurtboxComponent = _create_hurtbox(_direction_at_degrees(4.0) * 10.0, &"enemy")
	var outside: HurtboxComponent = _create_hurtbox(_direction_at_degrees(8.0) * 8.0, &"enemy")
	var friendly: HurtboxComponent = _create_hurtbox(Vector3(0.0, 0.0, -6.0), &"player")
	var candidates: Array[HurtboxComponent] = [outside, friendly, inside]
	var result: HurtboxComponent = _resolver.choose_target(
		Vector3.ZERO,
		Vector3.FORWARD,
		candidates,
		20.0,
		5.5
	)
	assert_same(result, inside)


func test_assist_rejects_targets_beyond_range() -> void:
	var distant: HurtboxComponent = _create_hurtbox(Vector3(0.0, 0.0, -24.0), &"enemy")
	var result: HurtboxComponent = _resolver.choose_target(
		Vector3.ZERO,
		Vector3.FORWARD,
		[distant],
		20.0,
		5.5
	)
	assert_null(result)


func _create_hurtbox(position: Vector3, faction: StringName) -> HurtboxComponent:
	var hurtbox: HurtboxComponent = HURTBOX_SCENE.instantiate() as HurtboxComponent
	hurtbox.position = position
	hurtbox.faction = faction
	add_child_autofree(hurtbox)
	return hurtbox


func _direction_at_degrees(angle: float) -> Vector3:
	var radians: float = deg_to_rad(angle)
	return Vector3(sin(radians), 0.0, -cos(radians))
