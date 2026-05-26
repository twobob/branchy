extends Node

var volume_enabled: bool = true
var master_volume: float = 0.3

var chainsaw_player: AudioStreamPlayer
var chainsaw_playback: AudioStreamGeneratorPlayback
var chainsaw_playing: bool = false
var chainsaw_cutting: bool = false
var chainsaw_phase: float = 0.0
var chainsaw_freq: float = 65.0

var minisaw_player: AudioStreamPlayer
var minisaw_playback: AudioStreamGeneratorPlayback
var minisaw_playing: bool = false
var minisaw_cutting: bool = false
var minisaw_phase: float = 0.0
var minisaw_freq: float = 320.0

var grinding_player: AudioStreamPlayer
var grinding_playback: AudioStreamGeneratorPlayback
var grinding_playing: bool = false
var grinding_phase: float = 0.0

var snip_player: AudioStreamPlayer
var snip_playback: AudioStreamGeneratorPlayback
var snip_time: float = -1.0
var snip_duration: float = 0.15

var chime_player: AudioStreamPlayer
var chime_playback: AudioStreamGeneratorPlayback
var chime_time: float = -1.0
var chime_duration: float = 1.0

var sample_rate: float = 22050.0
var max_frames_per_tick: int = 512

func _ready() -> void:
	chainsaw_player = _make_stream()
	minisaw_player = _make_stream()
	grinding_player = _make_stream()
	snip_player = _make_stream()
	chime_player = _make_stream()

func _make_stream() -> AudioStreamPlayer:
	var p = AudioStreamPlayer.new()
	var g = AudioStreamGenerator.new()
	g.mix_rate = sample_rate
	g.buffer_length = 0.1
	p.stream = g
	add_child(p)
	return p

func _ensure_playing(player: AudioStreamPlayer):
	if not player.playing:
		player.play()

func _process(_delta: float) -> void:
	if chainsaw_playing:
		_ensure_playing(chainsaw_player)
		_fill_chainsaw()
	if minisaw_playing:
		_ensure_playing(minisaw_player)
		_fill_minisaw()
	if grinding_playing:
		_ensure_playing(grinding_player)
		_fill_grinding()
	if snip_time >= 0.0:
		_ensure_playing(snip_player)
		_fill_snip()
	if chime_time >= 0.0:
		_ensure_playing(chime_player)
		_fill_chime()

func _fill_chainsaw():
	if not chainsaw_player.playing:
		return
	chainsaw_playback = chainsaw_player.get_stream_playback()
	if not chainsaw_playback:
		return
	var frames = mini(chainsaw_playback.get_frames_available(), max_frames_per_tick)
	var target_f = 160.0 if chainsaw_cutting else 65.0
	for i in range(frames):
		chainsaw_freq = lerp(chainsaw_freq, target_f, 0.0003)
		chainsaw_phase += chainsaw_freq / sample_rate
		if chainsaw_phase > 1.0:
			chainsaw_phase -= 1.0
		var saw1 = 2.0 * (chainsaw_phase - floor(chainsaw_phase)) - 1.0
		var p2 = chainsaw_phase * 2.0
		var saw2 = 2.0 * (p2 - floor(p2)) - 1.0
		var val = (saw1 * 0.7 + saw2 * 0.3) * master_volume
		if not volume_enabled:
			val = 0.0
		chainsaw_playback.push_frame(Vector2(val, val))

func _fill_minisaw():
	if not minisaw_player.playing:
		return
	minisaw_playback = minisaw_player.get_stream_playback()
	if not minisaw_playback:
		return
	var frames = mini(minisaw_playback.get_frames_available(), max_frames_per_tick)
	var target_f = 500.0 if minisaw_cutting else 320.0
	for i in range(frames):
		minisaw_freq = lerp(minisaw_freq, target_f, 0.0003)
		minisaw_phase += minisaw_freq / sample_rate
		if minisaw_phase > 1.0:
			minisaw_phase -= 1.0
		var sine_val = sin(2.0 * PI * minisaw_phase)
		var sq_val = 1.0 if minisaw_phase < 0.5 else -1.0
		var val = (sine_val * 0.4 + sq_val * 0.6) * 0.15 * master_volume
		if not volume_enabled:
			val = 0.0
		minisaw_playback.push_frame(Vector2(val, val))

func _fill_grinding():
	if not grinding_player.playing:
		return
	grinding_playback = grinding_player.get_stream_playback()
	if not grinding_playback:
		return
	var frames = mini(grinding_playback.get_frames_available(), max_frames_per_tick)
	for i in range(frames):
		grinding_phase += 40.0 / sample_rate
		if grinding_phase > 1.0:
			grinding_phase -= 1.0
		var rumble = sin(2.0 * PI * grinding_phase)
		var crackle = 0.0
		if randf() > 0.96:
			crackle = randf_range(-1.0, 1.0)
		var val = (rumble * 0.3 + crackle * 0.7) * 0.4 * master_volume
		if not volume_enabled:
			val = 0.0
		grinding_playback.push_frame(Vector2(val, val))

func _fill_snip():
	if not snip_player.playing:
		return
	snip_playback = snip_player.get_stream_playback()
	if not snip_playback:
		return
	var frames = mini(snip_playback.get_frames_available(), max_frames_per_tick)
	for i in range(frames):
		if snip_time >= 0.0 and snip_time < snip_duration:
			var env = 1.0 - (snip_time / snip_duration)
			var noise_val = randf_range(-1.0, 1.0) * env * 0.3 * master_volume
			if not volume_enabled:
				noise_val = 0.0
			snip_playback.push_frame(Vector2(noise_val, noise_val))
			snip_time += 1.0 / sample_rate
		else:
			snip_time = -1.0
			snip_playback.push_frame(Vector2.ZERO)
			break

func _fill_chime():
	if not chime_player.playing:
		return
	chime_playback = chime_player.get_stream_playback()
	if not chime_playback:
		return
	var frames = mini(chime_playback.get_frames_available(), max_frames_per_tick)
	var notes = [523.25, 587.33, 659.25, 783.99, 880.00, 1046.50]
	var delays = [0.0, 0.08, 0.16, 0.24, 0.32, 0.40]
	for i in range(frames):
		if chime_time >= 0.0 and chime_time < chime_duration:
			var total_val = 0.0
			for idx in range(notes.size()):
				var note_t = chime_time - delays[idx]
				if note_t >= 0.0 and note_t < 0.4:
					var env = exp(-7.0 * note_t)
					var freq = notes[idx]
					var sine_val = sin(2.0 * PI * freq * note_t)
					var harmonic = sin(2.0 * PI * (freq * 2.0) * note_t) * 0.3
					total_val += (sine_val + harmonic) * env * 0.15
			total_val *= master_volume
			if not volume_enabled:
				total_val = 0.0
			chime_playback.push_frame(Vector2(total_val, total_val))
			chime_time += 1.0 / sample_rate
		else:
			chime_time = -1.0
			chime_playback.push_frame(Vector2.ZERO)
			break

func play_sound(sound_name: String) -> void:
	if sound_name == "chainsaw":
		chainsaw_playing = true
		chainsaw_cutting = false
	elif sound_name == "chainsaw_cut":
		chainsaw_playing = true
		chainsaw_cutting = true
	elif sound_name == "minisaw":
		minisaw_playing = true
		minisaw_cutting = false
	elif sound_name == "minisaw_cut":
		minisaw_playing = true
		minisaw_cutting = true
	elif sound_name == "scissor" or sound_name == "snip":
		snip_time = 0.0
	elif sound_name == "grinding":
		grinding_playing = true
	elif sound_name == "chime" or sound_name == "level_completed":
		chime_time = 0.0

func stop_sound(sound_name: String) -> void:
	if sound_name == "chainsaw":
		chainsaw_playing = false
		chainsaw_cutting = false
	elif sound_name == "minisaw":
		minisaw_playing = false
		minisaw_cutting = false
	elif sound_name == "grinding":
		grinding_playing = false
	elif sound_name == "all":
		chainsaw_playing = false
		chainsaw_cutting = false
		minisaw_playing = false
		minisaw_cutting = false
		grinding_playing = false

func toggle_mute() -> void:
	volume_enabled = not volume_enabled

func set_volume(val: float) -> void:
	master_volume = clamp(val, 0.0, 1.0)
