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
