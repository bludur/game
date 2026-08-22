extends GutTest

const TELEGRAPH_SCENE: PackedScene = preload(
	"res://scenes/components/enemy_telegraph_component.tscn"
)
const LUNGE: EnemyTelegraphData = preload(
	"res://resources/enemy_telegraphs/shadow_lunge.tres"
)
const BOLT: EnemyTelegraphData = preload(
	"res://resources/enemy_telegraphs/ember_bolt.tres"
)


func test_telegraph_definitions_share_complete_contract() -> void:
	for definition: EnemyTelegraphData in [LUNGE, BOLT]:
		assert_true(definition.is_valid_definition())
		assert_gt(definition.warning_seconds, definition.danger_seconds)
		assert_ne(definition.warning_color, definition.danger_color)
		assert_eq(definition.sound_cue, &"enemy_warning")


func test_telegraph_advances_warning_danger_and_idle_deterministically() -> void:
	var telegraph: EnemyTelegraphComponent = TELEGRAPH_SCENE.instantiate() as EnemyTelegraphComponent
	add_child_autofree(telegraph)
	telegraph.set_physics_process(false)
	var danger_count: Array[int] = [0]
	telegraph.danger_started.connect(
		func(_definition: EnemyTelegraphData) -> void: danger_count[0] += 1
	)
	assert_true(telegraph.begin(LUNGE))
	assert_eq(telegraph.get_phase_name(), &"warning")
	telegraph.advance(LUNGE.warning_seconds)
	assert_eq(telegraph.get_phase_name(), &"danger")
	assert_eq(danger_count[0], 1)
	telegraph.advance(LUNGE.danger_seconds)
	assert_eq(telegraph.get_phase_name(), &"idle")
