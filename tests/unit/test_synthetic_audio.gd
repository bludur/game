extends GutTest


func test_short_sfx_is_mono_pcm_with_data() -> void:
	var stream: AudioStreamWAV = SyntheticAudio.create_spell_cast()
	assert_false(stream.stereo)
	assert_eq(stream.format, AudioStreamWAV.FORMAT_16_BITS)
	assert_gt(stream.data.size(), 100)


func test_ambience_is_configured_as_loop() -> void:
	var stream: AudioStreamWAV = SyntheticAudio.create_ambience()
	assert_eq(stream.loop_mode, AudioStreamWAV.LOOP_FORWARD)
	assert_eq(stream.loop_begin, 0)
	assert_gt(stream.loop_end, 0)


func test_result_stingers_are_distinct_non_looping_streams() -> void:
	var victory: AudioStreamWAV = SyntheticAudio.create_victory()
	var defeat: AudioStreamWAV = SyntheticAudio.create_defeat_result()
	assert_ne(victory, defeat)
	assert_eq(victory.loop_mode, AudioStreamWAV.LOOP_DISABLED)
	assert_eq(defeat.loop_mode, AudioStreamWAV.LOOP_DISABLED)
	assert_gt(victory.data.size(), 100)
	assert_gt(defeat.data.size(), 100)
