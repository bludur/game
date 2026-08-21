class_name SyntheticAudio

const MIX_RATE: int = 22050

enum Waveform {
	SINE,
	SQUARE,
	TRIANGLE,
}


static func create_tone(
	frequency: float,
	duration: float,
	volume: float = 0.3,
	waveform: Waveform = Waveform.SINE,
	decay: bool = true
) -> AudioStreamWAV:
	var sample_count: int = maxi(1, ceili(duration * float(MIX_RATE)))
	var samples: PackedFloat32Array = PackedFloat32Array()
	samples.resize(sample_count)
	for sample_index: int in range(sample_count):
		var time: float = float(sample_index) / float(MIX_RATE)
		var phase: float = TAU * frequency * time
		var sample: float
		match waveform:
			Waveform.SQUARE:
				sample = 1.0 if sin(phase) >= 0.0 else -1.0
			Waveform.TRIANGLE:
				sample = asin(sin(phase)) * 2.0 / PI
			_:
				sample = sin(phase)
		var envelope: float = _edge_fade(time, duration)
		if decay:
			envelope *= pow(maxf(0.0, 1.0 - time / duration), 1.5)
		samples[sample_index] = sample * volume * envelope
	return _create_wav(samples, false)


static func create_spell_cast() -> AudioStreamWAV:
	return _create_chirp(360.0, 920.0, 0.22, 0.28)


static func create_arcane_impact() -> AudioStreamWAV:
	return _create_chirp(680.0, 120.0, 0.24, 0.34)


static func create_hurt() -> AudioStreamWAV:
	return _create_chirp(170.0, 75.0, 0.18, 0.28)


static func create_death() -> AudioStreamWAV:
	return _create_chirp(260.0, 42.0, 0.5, 0.32)


static func create_enemy_attack() -> AudioStreamWAV:
	return _create_chirp(110.0, 420.0, 0.16, 0.25)


static func create_dash() -> AudioStreamWAV:
	return _create_chirp(260.0, 1180.0, 0.18, 0.22)


static func create_ambience() -> AudioStreamWAV:
	var duration: float = 6.0
	var sample_count: int = ceili(duration * float(MIX_RATE))
	var samples: PackedFloat32Array = PackedFloat32Array()
	samples.resize(sample_count)
	for sample_index: int in range(sample_count):
		var time: float = float(sample_index) / float(MIX_RATE)
		var drone: float = sin(TAU * 43.0 * time) * 0.11
		drone += sin(TAU * 64.5 * time + 0.7) * 0.06
		var shimmer: float = sin(TAU * 0.17 * time) * sin(TAU * 172.0 * time) * 0.018
		samples[sample_index] = (drone + shimmer) * _edge_fade(time, duration, 0.08)
	return _create_wav(samples, true)


static func create_music_loop() -> AudioStreamWAV:
	var duration: float = 8.0
	var sample_count: int = ceili(duration * float(MIX_RATE))
	var samples: PackedFloat32Array = PackedFloat32Array()
	samples.resize(sample_count)
	var roots: PackedFloat32Array = PackedFloat32Array([110.0, 130.81, 98.0, 123.47])
	for sample_index: int in range(sample_count):
		var time: float = float(sample_index) / float(MIX_RATE)
		var chord_index: int = mini(3, floori(time / 2.0))
		var root: float = roots[chord_index]
		var pulse: float = 0.6 + 0.4 * sin(TAU * 0.5 * time)
		var sample: float = sin(TAU * root * time) * 0.055
		sample += sin(TAU * root * 1.5 * time) * 0.035
		sample += sin(TAU * root * 2.0 * time) * 0.018
		samples[sample_index] = sample * pulse * _edge_fade(time, duration, 0.08)
	return _create_wav(samples, true)


static func _create_chirp(
	start_frequency: float,
	end_frequency: float,
	duration: float,
	volume: float
) -> AudioStreamWAV:
	var sample_count: int = ceili(duration * float(MIX_RATE))
	var samples: PackedFloat32Array = PackedFloat32Array()
	samples.resize(sample_count)
	var phase: float = 0.0
	for sample_index: int in range(sample_count):
		var time: float = float(sample_index) / float(MIX_RATE)
		var progress: float = clampf(time / duration, 0.0, 1.0)
		var frequency: float = lerpf(start_frequency, end_frequency, progress)
		phase += TAU * frequency / float(MIX_RATE)
		var envelope: float = pow(1.0 - progress, 1.35) * _edge_fade(time, duration)
		samples[sample_index] = sin(phase) * volume * envelope
	return _create_wav(samples, false)


static func _create_wav(samples: PackedFloat32Array, looping: bool) -> AudioStreamWAV:
	var data: PackedByteArray = PackedByteArray()
	data.resize(samples.size() * 2)
	for sample_index: int in range(samples.size()):
		var encoded: int = roundi(clampf(samples[sample_index], -1.0, 1.0) * 32767.0)
		data.encode_s16(sample_index * 2, encoded)

	var stream: AudioStreamWAV = AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = MIX_RATE
	stream.stereo = false
	stream.data = data
	if looping:
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_begin = 0
		stream.loop_end = samples.size()
	return stream


static func _edge_fade(time: float, duration: float, fade_seconds: float = 0.005) -> float:
	var fade_in: float = clampf(time / fade_seconds, 0.0, 1.0)
	var fade_out: float = clampf((duration - time) / fade_seconds, 0.0, 1.0)
	return minf(fade_in, fade_out)
