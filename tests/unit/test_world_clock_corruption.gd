extends GutTest


func test_clock_restores_day_and_selects_expected_phase() -> void:
	var clock: WorldClock = WorldClock.new()
	add_child_autofree(clock)
	clock.apply_state({"normalized_time": 0.84, "day_number": 4})
	assert_true(clock.is_night())
	assert_eq(clock.day_number, 4)
	assert_eq(clock.get_time_label(), "20:09")
	clock.apply_state({"normalized_time": 0.5, "day_number": 5})
	assert_eq(clock.current_phase, WorldClock.Phase.DAY)


func test_corruption_combines_exposure_resistance_and_ward_cleansing() -> void:
	var corruption: CorruptionComponent = CorruptionComponent.new()
	corruption.night_gain_per_second = 1.0
	corruption.cursed_gain_per_second = 2.0
	corruption.ward_cleanse_per_second = 4.0
	add_child_autofree(corruption)
	corruption.update_exposure(5.0, true, false, true)
	assert_eq(corruption.current_corruption, 15.0)
	corruption.apply_temporary_resistance(0.5, 10.0)
	corruption.update_exposure(2.0, true, false, false)
	assert_eq(corruption.current_corruption, 16.0)
	corruption.update_exposure(2.0, true, true, true)
	assert_eq(corruption.current_corruption, 8.0)
	corruption.apply_temporary_resistance(0.0, 0.0)
	corruption.add_corruption(50.0, &"test")
	assert_eq(corruption.get_threshold(), 2)
	assert_eq(corruption.get_regeneration_multiplier(), 0.65)


func test_corruption_state_round_trip_is_clamped() -> void:
	var corruption: CorruptionComponent = CorruptionComponent.new()
	add_child_autofree(corruption)
	corruption.apply_state({"current": 170.0, "temporary_resistance": 2.0, "resistance_remaining": -4.0})
	assert_eq(corruption.current_corruption, 100.0)
	assert_eq(corruption.get_threshold(), 3)
	var state: Dictionary = corruption.serialize_state()
	assert_eq(state["temporary_resistance"], 0.9)
	assert_eq(state["resistance_remaining"], 0.0)


func test_corruption_uses_external_preparation_resistance() -> void:
	var corruption: CorruptionComponent = CorruptionComponent.new()
	add_child_autofree(corruption)
	corruption.set_external_resistance_provider(func() -> float: return 0.35)
	assert_true(corruption.add_corruption(20.0, &"test_preparation"))
	assert_almost_eq(corruption.current_corruption, 13.0, 0.001)
