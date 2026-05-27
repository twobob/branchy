extends Control
class_name AudioDebug

## Real-time timeline visualiser for the Audio node.
## Horizontal lanes per clip, scrolling left. Pitch graph below.
## Toggle with F3.

var audio: Audio
var history_seconds: float = 5.0
var toggle_key: Key = KEY_F3

const CLIP_NAMES := ["start", "idle", "shutoff", "start_rev", "rev_loop", "end_rev"]
const CLIP_COLORS := [
	Color(0.4, 0.75, 1.0),    # start - blue
	Color(0.3, 0.9, 0.4),     # idle - green
	Color(0.95, 0.3, 0.3),    # shutoff - red
	Color(1.0, 0.85, 0.2),    # start_rev - yellow
	Color(1.0, 0.55, 0.1),    # rev_loop - orange
	Color(0.8, 0.45, 0.95),   # end_rev - purple
]

const LANE_H := 22.0
const LANE_GAP := 3.0
const LABEL_W := 76.0
const MARGIN := 8.0
const PITCH_H := 50.0
const STATUS_H := 18.0
const FONT_SIZE := 11
const NUM_CLIPS := 6

var _history: Array = []
var _t0: float = 0.0


func _ready() -> void:
	_t0 = Time.get_ticks_msec() * 0.001
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == toggle_key:
		visible = not visible
		get_viewport().set_input_as_handled()


func _process(_delta: float) -> void:
	if not visible or audio == null:
		return
	var now := Time.get_ticks_msec() * 0.001 - _t0
	var info: Dictionary = audio.get_debug_info()
	info["t"] = now
	_history.append(info)
	var cutoff := now - history_seconds
	while _history.size() > 0 and _history[0].get("t", 0.0) < cutoff:
		_history.pop_front()
	queue_redraw()


func _draw() -> void:
	if audio == null or _history.is_empty():
		return

	var font: Font = ThemeDB.fallback_font
	var last: Dictionary = _history[-1]
	var now: float = last.get("t", 0.0)

	var total_h := MARGIN + NUM_CLIPS * (LANE_H + LANE_GAP) + MARGIN * 0.5 + PITCH_H + STATUS_H + MARGIN
	var panel_w := maxf(size.x, 400.0)
	var gl := LABEL_W + MARGIN                 # graph left x
	var gw := panel_w - gl - MARGIN - 34.0     # graph width (34px right margin for pitch labels)
	var gr := gl + gw                           # graph right x

	# ── Background ──
	draw_rect(Rect2(0, 0, panel_w, total_h), Color(0.05, 0.05, 0.08, 0.85))
	draw_rect(Rect2(0, 0, panel_w, total_h), Color(0.25, 0.25, 0.3, 0.5), false, 1.0)

	# ── Lane backgrounds + labels ──
	for i in NUM_CLIPS:
		var y := MARGIN + i * (LANE_H + LANE_GAP)
		draw_rect(Rect2(gl, y, gw, LANE_H), Color(0.12, 0.12, 0.15))
		draw_string(font, Vector2(MARGIN, y + LANE_H - 6), CLIP_NAMES[i],
			HORIZONTAL_ALIGNMENT_LEFT, LABEL_W, FONT_SIZE, CLIP_COLORS[i])

	# ── History blocks (single pass) ──
	var sample_w := maxf(2.0, gw / maxf(float(_history.size()), 1.0) * 1.3)
	for j in _history.size():
		var e: Dictionary = _history[j]
		var t: float = e.get("t", 0.0)
		var x := gr - (now - t) / history_seconds * gw
		if x < gl:
			continue

		# Active clip
		var ac: int = e.get("clip", -1)
		if ac >= 0 and ac < NUM_CLIPS:
			var ay := MARGIN + ac * (LANE_H + LANE_GAP)
			var adb: float = e.get("clip_vol", -80.0)
			var anorm := clampf((adb + 60.0) / 60.0, 0.0, 1.0)
			var ah := LANE_H * anorm
			var col: Color = CLIP_COLORS[ac]
			col.a = clampf(anorm * 0.8 + 0.2, 0.25, 1.0)
			draw_rect(Rect2(x, ay + LANE_H - ah, sample_w, ah), col)

		# Fading clip (dimmer)
		var fc: int = e.get("fade_clip", -1)
		if fc >= 0 and fc < NUM_CLIPS:
			var fy := MARGIN + fc * (LANE_H + LANE_GAP)
			var fdb: float = e.get("fade_vol", -80.0)
			var fnorm := clampf((fdb + 60.0) / 60.0, 0.0, 1.0)
			var fh := LANE_H * fnorm
			var fcol: Color = CLIP_COLORS[fc]
			fcol.a = clampf(fnorm * 0.5 + 0.05, 0.05, 0.55)
			draw_rect(Rect2(x, fy + LANE_H - fh, sample_w, fh), fcol)

	# ── Pitch graph ──
	var py := MARGIN + NUM_CLIPS * (LANE_H + LANE_GAP) + MARGIN * 0.5
	draw_rect(Rect2(gl, py, gw, PITCH_H), Color(0.12, 0.12, 0.15))
	draw_string(font, Vector2(MARGIN, py + PITCH_H * 0.5 + 4), "pitch",
		HORIZONTAL_ALIGNMENT_LEFT, LABEL_W, FONT_SIZE, Color(0.6, 0.6, 0.6))

	# Baseline (1.0x)
	var bl_y := py + PITCH_H * 0.5
	draw_line(Vector2(gl, bl_y), Vector2(gr, bl_y), Color(0.3, 0.3, 0.35), 1.0, true)

	# Scale labels
	draw_string(font, Vector2(gr + 4, py + 10), "2x",
		HORIZONTAL_ALIGNMENT_LEFT, 28, 9, Color(0.4, 0.4, 0.4))
	draw_string(font, Vector2(gr + 4, bl_y + 4), "1x",
		HORIZONTAL_ALIGNMENT_LEFT, 28, 9, Color(0.5, 0.5, 0.5))
	draw_string(font, Vector2(gr + 4, py + PITCH_H - 2), ".5x",
		HORIZONTAL_ALIGNMENT_LEFT, 28, 9, Color(0.4, 0.4, 0.4))

	# Pitch line
	var prev_pt := Vector2.ZERO
	var has_prev := false
	for j in _history.size():
		var e: Dictionary = _history[j]
		var t: float = e.get("t", 0.0)
		var x := gr - (now - t) / history_seconds * gw
		if x < gl:
			has_prev = false
			continue
		var p: float = e.get("pitch", 1.0)
		var p_log := log(maxf(p, 0.01)) / log(2.0)           # octaves from 1.0
		var p_norm := clampf((p_log + 1.0) / 2.0, 0.0, 1.0)  # -1 oct → 0, +1 oct → 1
		var ply := py + PITCH_H * (1.0 - p_norm)
		var pt := Vector2(x, ply)
		if has_prev:
			draw_line(prev_pt, pt, Color(1.0, 1.0, 0.3, 0.9), 1.5)
		prev_pt = pt
		has_prev = true

	# ── Status line ──
	var clip_idx: int = last.get("clip", -1)
	var clip_name: String = CLIP_NAMES[clip_idx] if clip_idx >= 0 and clip_idx < NUM_CLIPS else "none"
	var clip_vol: float = last.get("clip_vol", -80.0)
	var p_val: float = last.get("pitch", 1.0)
	var status := "▶ %s  vol: %.1f dB  pitch: %.3fx" % [clip_name, clip_vol, p_val]
	if last.get("fading", false):
		var fi: int = last.get("fade_clip", -1)
		var fn: String = CLIP_NAMES[fi] if fi >= 0 and fi < NUM_CLIPS else "?"
		var fv: float = last.get("fade_vol", -80.0)
		status += "  ⟷  %s %.1f dB" % [fn, fv]
	var sty := total_h - MARGIN + 2
	draw_string(font, Vector2(gl, sty), status,
		HORIZONTAL_ALIGNMENT_LEFT, gw, FONT_SIZE, Color(0.85, 0.85, 0.85))
	draw_string(font, Vector2(panel_w - 80, sty), "[F3] toggle",
		HORIZONTAL_ALIGNMENT_RIGHT, 72, 9, Color(0.4, 0.4, 0.4))
