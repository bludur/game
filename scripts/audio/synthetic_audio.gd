class_name SyntheticAudio

const MIX_RATE: int = 22050

enum Waveform {
	SINE,
	SQUARE,
	TRIANGLE,
}

static var _spell_cast_cache: AudioStreamWAV
static var _arcane_impact_cache: AudioStreamWAV
static var _hurt_cache: AudioStreamWAV
static var _death_cache: AudioStreamWAV
static var _enemy_attack_cache: AudioStreamWAV
static var _enemy_warning_cache: AudioStreamWAV
static var _dash_cache: AudioStreamWAV
static var _ward_cache: AudioStreamWAV
static var _chain_lightning_cache: AudioStreamWAV
static var _victory_cache: AudioStreamWAV
static var _defeat_result_cache: AudioStreamWAV
static var _ambience_cache: AudioStreamWAV
static var _music_cache: AudioStreamWAV
static var _region_ambience_cache: Dictionary[int, AudioStreamWAV] = {}


static func release_cached_streams() -> void:
	_spell_cast_cache = null
	_arcane_impact_cache = null
	_hurt_cache = null
	_death_cache = null
	_enemy_attack_cache = null
	_enemy_warning_cache = null
	_dash_cache = null
	_ward_cache = null
	_chain_lightning_cache = null
	_victory_cache = null
	_defeat_result_cache = null
	_ambience_cache = null
	_music_cache = null
	_region_ambience_cache.clear()


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
	if _spell_cast_cache == null:
		_spell_cast_cache = _create_chirp(360.0, 920.0, 0.22, 0.28)
	return _spell_cast_cache


static func create_arcane_impact() -> AudioStreamWAV:
	if _arcane_impact_cache == null:
		_arcane_impact_cache = _create_chirp(680.0, 120.0, 0.24, 0.34)
	return _arcane_impact_cache


static func create_hurt() -> AudioStreamWAV:
	if _hurt_cache == null:
		_hurt_cache = _create_chirp(170.0, 75.0, 0.18, 0.28)
	return _hurt_cache


static func create_death() -> AudioStreamWAV:
	if _death_cache == null:
		_death_cache = _create_chirp(260.0, 42.0, 0.5, 0.32)
	return _death_cache


static func create_enemy_attack() -> AudioStreamWAV:
	if _enemy_attack_cache == null:
		_enemy_attack_cache = _create_chirp(110.0, 420.0, 0.16, 0.25)
	return _enemy_attack_cache


static func create_enemy_warning() -> AudioStreamWAV:
	if _enemy_warning_cache == null:
		_enemy_warning_cache = _create_sequence(PackedFloat32Array([196.0, 246.94]), 0.13, 0.19)
	return _enemy_warning_cache


static func create_dash() -> AudioStreamWAV:
	if _dash_cache == null:
		_dash_cache = _create_chirp(260.0, 1180.0, 0.18, 0.22)
	return _dash_cache


static func create_ward() -> AudioStreamWAV:
	if _ward_cache == null:
		_ward_cache = _create_chirp(210.0, 760.0, 0.28, 0.2)
	return _ward_cache


static func create_chain_lightning() -> AudioStreamWAV:
	if _chain_lightning_cache == null:
		_chain_lightning_cache = _create_chirp(1280.0, 180.0, 0.32, 0.3)
	return _chain_lightning_cache


static func create_victory() -> AudioStreamWAV:
	if _victory_cache == null:
		_victory_cache = _create_sequence(PackedFloat32Array([392.0, 523.25, 659.25, 783.99]), 0.16, 0.24)
	return _victory_cache


static func create_defeat_result() -> AudioStreamWAV:
	if _defeat_result_cache == null:
		_defeat_result_cache = _create_sequence(PackedFloat32Array([220.0, 164.81, 110.0]), 0.22, 0.25)
	return _defeat_result_cache


static func create_ambience() -> AudioStreamWAV:
	if _ambience_cache != null:
		return _ambience_cache
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
	_ambience_cache = _create_wav(samples, true)
	return _ambience_cache


static func create_music_loop() -> AudioStreamWAV:
	if _music_cache != null:
		return _music_cache
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
	_music_cache = _create_wav(samples, true)
	return _music_cache


static func create_region_ambience(mood: int) -> AudioStreamWAV:
	if _region_ambience_cache.has(mood):
		return _region_ambience_cache[mood]
	var base_frequencies: PackedFloat32Array = PackedFloat32Array([47.0, 61.0, 38.0, 31.0, 72.0])
	var base: float = base_frequencies[clampi(mood, 0, base_frequencies.size() - 1)]
	var duration: float = 6.0
	var sample_count: int = ceili(duration * float(MIX_RATE))
	var samples: PackedFloat32Array = PackedFloat32Array()
	samples.resize(sample_count)
	for sample_index: int in sample_count:
		var time: float = float(sample_index) / float(MIX_RATE)
		var slow_pulse: float = 0.62 + sin(TAU * (0.07 + float(mood) * 0.013) * time) * 0.28
		var sample: float = sin(TAU * base * time) * 0.075
		sample += sin(TAU * base * 1.51 * time + float(mood)) * 0.038
		sample += sin(TAU * (base * 3.0 + 7.0) * time) * 0.009 * slow_pulse
		samples[sample_index] = sample * _edge_fade(time, duration, 0.08)
	var stream: AudioStreamWAV = _create_wav(samples, true)
	_region_ambience_cache[mood] = stream
	return stream


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


static func _create_sequence(
	frequencies: PackedFloat32Array,
	note_duration: float,
	volume: float
) -> AudioStreamWAV:
	var total_duration: float = note_duration * float(frequencies.size())
	var sample_count: int = ceili(total_duration * float(MIX_RATE))
	var samples: PackedFloat32Array = PackedFloat32Array()
	samples.resize(sample_count)
	for sample_index: int in range(sample_count):
		var time: float = float(sample_index) / float(MIX_RATE)
		var note_index: int = mini(frequencies.size() - 1, floori(time / note_duration))
		var note_time: float = fmod(time, note_duration)
		var envelope: float = pow(maxf(0.0, 1.0 - note_time / note_duration), 1.2)
		samples[sample_index] = sin(TAU * frequencies[note_index] * time) * volume * envelope
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
