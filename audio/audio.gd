extends AudioStreamPlayer3D
class_name Audio

## Clip-based 3D audio player using AudioStreamPolyphonic.
## One AudioStreamPlayer3D — all spatial/volume/pitch properties are native.
## Per-clip gain is applied at the mix level via play_stream(volume_db),
## completely bypassing the max_db spatial clamp.

signal clip_finished(clip_index: int)

# ── Clip configuration ───────────────────────────────────────────────────

@export_group("Clips")
@export var clip_0_start: AudioStream
@export var clip_1_idle_loop: AudioStream
@export var clip_2_shutoff: AudioStream
@export var clip_3_start_rev: AudioStream
@export var clip_4_rev_loop: AudioStream
@export var clip_5_end_rev: AudioStream

@export_group("Clip Gain (dB)")
@export_range(-40.0, 12.0, 0.1) var gain_0_start: float = 0.0
@export_range(-40.0, 12.0, 0.1) var gain_1_idle_loop: float = 0.0
@export_range(-40.0, 12.0, 0.1) var gain_2_shutoff: float = 0.0
@export_range(-40.0, 12.0, 0.1) var gain_3_start_rev: float = 0.0
@export_range(-40.0, 12.0, 0.1) var gain_4_rev_loop: float = 0.0
@export_range(-40.0, 12.0, 0.1) var gain_5_end_rev: float = 0.0

@export_group("Crossfade")
## Default crossfade seconds when no per-pair transition is defined.
## 0.0 = hard-cut (instant switch).
@export var default_fade_duration: float = 0.0

@export_group("Debug")
## Check to spawn a real-time audio visualiser overlay (toggle F3).
@export var debug_overlay: bool = false

# ── Runtime state ────────────────────────────────────────────────────────

var current_clip: int:
	get: return _current_clip

# ── Internals ────────────────────────────────────────────────────────────

var _playback: AudioStreamPlaybackPolyphonic
var _current_id: int = -1
var _fade_id: int = -1
var _current_clip: int = -1
var _is_fading: bool = false
var _fade_tween: Tween
var _clip_streams: Array[AudioStream] = []
var _clip_gains: PackedFloat32Array = []
var _clip_auto_advance: PackedInt32Array = []
var _transitions: Dictionary = {}
var _stream_playing: bool = false
var _current_stream_start: float = 0.0
var _current_stream_length: float = 0.0
var _auto_advance_pending: bool = false
var _current_volume: float = -80.0
var _fade_volume: float = -80.0
var _fade_clip: int = -1


func _ready() -> void:
	_clip_streams = [
		clip_0_start, clip_1_idle_loop, clip_2_shutoff,
		clip_3_start_rev, clip_4_rev_loop, clip_5_end_rev,
	]
	_clip_gains = PackedFloat32Array([
		gain_0_start, gain_1_idle_loop, gain_2_shutoff,
		gain_3_start_rev, gain_4_rev_loop, gain_5_end_rev,
	])
	_clip_auto_advance = PackedInt32Array([1, -1, -1, 4, -1, 1])

	# Polyphonic stream: max 2 voices (current + crossfade overlap)
	var poly := AudioStreamPolyphonic.new()
	poly.polyphony = 2
	stream = poly
	play()
	_playback = get_stream_playback() as AudioStreamPlaybackPolyphonic

	if debug_overlay:
		_spawn_debug_overlay()


# ── Transition config ────────────────────────────────────────────────────

func set_transition(from_clip: int, to_clip: int, fade_duration: float) -> void:
	_transitions[Vector2i(from_clip, to_clip)] = fade_duration


# ── Playback ─────────────────────────────────────────────────────────────

func switch_to_clip(index: int) -> void:
	if index < 0 or index >= _clip_streams.size():
		push_warning("Audio: clip index %d out of range (have %d clips)" % [index, _clip_streams.size()])
		return
	var clip_stream := _clip_streams[index]
	if clip_stream == null:
		push_warning("Audio: clip %d has no stream assigned" % index)
		return

	var fade := _get_fade(_current_clip, index)
	var old_clip := _current_clip
	_current_clip = index

	if fade > 0.0 and _is_id_playing(_current_id):
		_crossfade(clip_stream, fade, old_clip)
	else:
		_hard_switch(clip_stream)


func stop_audio(fade_out: bool = false, fade_duration: float = 0.5) -> void:
	_kill_fade()
	if fade_out and _is_id_playing(_current_id):
		var id := _current_id
		var start_gain := _get_clip_gain(_current_clip)
		_fade_tween = create_tween()
		_fade_tween.tween_method(
			func(vol: float): _playback.set_stream_volume(id, vol),
			start_gain, -80.0, fade_duration)
		_fade_tween.tween_callback(func(): _playback.stop_stream(id))
	else:
		_stop_id(_current_id)
	_stop_id(_fade_id)
	_current_id = -1
	_fade_id = -1
	_fade_clip = -1
	_current_clip = -1
	_current_volume = -80.0
	_fade_volume = -80.0
	_stream_playing = false


func set_paused(paused: bool) -> void:
	stream_paused = paused


# ── Internal ─────────────────────────────────────────────────────────────

func _process(_delta: float) -> void:
	if _current_clip < 0 or _is_fading or not _stream_playing:
		return

	# Check if we should start an early overlap for auto-advance
	if not _auto_advance_pending and _current_stream_length > 0.0:
		var next_clip := _get_auto_advance_target(_current_clip)
		if next_clip >= 0:
			var fade := _get_fade(_current_clip, next_clip)
			if fade > 0.0:
				var elapsed := Time.get_ticks_msec() * 0.001 - _current_stream_start
				var remaining := _current_stream_length - elapsed
				if remaining <= fade and _is_id_playing(_current_id):
					_auto_advance_pending = true
					# Overlap: let old stream finish naturally, start new at full vol
					_fade_id = _current_id
					_fade_clip = _current_clip
					_fade_volume = _current_volume
					_current_clip = next_clip
					var clip_stream := _clip_streams[next_clip]
					if clip_stream:
						_current_volume = _get_clip_gain(next_clip)
						_current_id = _playback.play_stream(clip_stream, 0.0, _current_volume)
						_current_stream_start = Time.get_ticks_msec() * 0.001
						_current_stream_length = clip_stream.get_length() if clip_stream else 0.0
					return

	# Clean up any finished overlap stream
	if _fade_id != -1 and not _is_id_playing(_fade_id):
		_fade_id = -1
		_fade_clip = -1
		_fade_volume = -80.0
		_auto_advance_pending = false

	# Stream fully ended — hard advance or emit finished
	if not _is_id_playing(_current_id):
		_stream_playing = false
		_current_volume = -80.0
		clip_finished.emit(_current_clip)
		_handle_auto_advance()


func _get_fade(from: int, to: int) -> float:
	if from < 0:
		return 0.0
	var key := Vector2i(from, to)
	if _transitions.has(key):
		return _transitions[key]
	return default_fade_duration


func _get_clip_gain(index: int) -> float:
	if index >= 0 and index < _clip_gains.size():
		return _clip_gains[index]
	return 0.0


func _hard_switch(clip_stream: AudioStream) -> void:
	_kill_fade()
	_stop_id(_current_id)
	_stop_id(_fade_id)
	_fade_id = -1
	_fade_clip = -1
	_fade_volume = -80.0
	_auto_advance_pending = false
	_current_volume = _get_clip_gain(_current_clip)
	_current_id = _playback.play_stream(clip_stream, 0.0, _current_volume)
	_current_stream_start = Time.get_ticks_msec() * 0.001
	_current_stream_length = clip_stream.get_length() if clip_stream else 0.0
	_stream_playing = true


func _crossfade(clip_stream: AudioStream, duration: float, old_clip: int = -1) -> void:
	_kill_fade()
	_stop_id(_fade_id)

	_is_fading = true
	# Old stream becomes the fade-out target
	_fade_id = _current_id
	_fade_clip = old_clip
	_fade_volume = _current_volume
	# New stream starts at full target volume (no dip)
	var new_gain := _get_clip_gain(_current_clip)
	_current_id = _playback.play_stream(clip_stream, 0.0, new_gain)
	_current_volume = new_gain
	_current_stream_start = Time.get_ticks_msec() * 0.001
	_current_stream_length = clip_stream.get_length() if clip_stream else 0.0
	_auto_advance_pending = false
	_stream_playing = true

	var old_id := _fade_id
	var old_gain := _fade_volume

	var fade_out_fn := func(vol: float):
		_playback.set_stream_volume(old_id, vol)
		_fade_volume = vol

	_fade_tween = create_tween()
	# Only fade out old
	if _is_id_playing(old_id):
		_fade_tween.tween_method(fade_out_fn, old_gain, -80.0, duration)
	_fade_tween.tween_callback(_on_crossfade_complete)


func _on_crossfade_complete() -> void:
	_stop_id(_fade_id)
	_fade_id = -1
	_fade_clip = -1
	_fade_volume = -80.0
	_is_fading = false
	if not _is_id_playing(_current_id):
		_handle_auto_advance()


func _get_auto_advance_target(clip: int) -> int:
	if clip >= 0 and clip < _clip_auto_advance.size():
		return _clip_auto_advance[clip]
	return -1


func _handle_auto_advance() -> void:
	var next_clip := _get_auto_advance_target(_current_clip)
	if next_clip >= 0:
		switch_to_clip(next_clip)


func _is_id_playing(id: int) -> bool:
	return id != -1 and id != AudioStreamPlaybackPolyphonic.INVALID_ID and _playback.is_stream_playing(id)


func _stop_id(id: int) -> void:
	if id != -1 and id != AudioStreamPlaybackPolyphonic.INVALID_ID:
		_playback.stop_stream(id)


func _kill_fade() -> void:
	if _fade_tween and _fade_tween.is_valid():
		_fade_tween.kill()
	_is_fading = false


# ── Debug ────────────────────────────────────────────────────────────────

func get_debug_info() -> Dictionary:
	return {
		"clip": _current_clip,
		"clip_vol": _current_volume,
		"fade_clip": _fade_clip,
		"fade_vol": _fade_volume,
		"pitch": pitch_scale,
		"fading": _is_fading,
	}


func _spawn_debug_overlay() -> void:
	var canvas := CanvasLayer.new()
	canvas.layer = 100
	canvas.name = "AudioDebugLayer"
	add_child(canvas)
	var DebugScript = load("res://scripts/audio_debug.gd")
	if DebugScript == null:
		push_warning("Audio: debug_overlay enabled but scripts/audio_debug.gd not found")
		return
	var ctrl := Control.new()
	ctrl.set_script(DebugScript)
	ctrl.name = "AudioDebug"
	ctrl.audio = self
	ctrl.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	canvas.add_child(ctrl)
