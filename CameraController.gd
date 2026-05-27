extends Camera3D

@export var move_speed: float = 15.0

var sound_synthesizer: Node
var audio_enabled: bool = false
var is_orbiting: bool = false
var orbit_sensitivity: float = 0.003
var active_tool: String = "Hands"
var is_climbing: bool = false
var climb_target: Node3D = null
var climb_height: float = 0.0
const CLIMB_STEP: float = 0.5
const CLIMB_SPEED: float = 2.0
var velocity: Vector3 = Vector3.ZERO
var player_height: float = 1.7
var on_ground: bool = false
var gravity: float = 20.0
var jump_speed: float = 7.0
var walk_speed: float = 5.0
var tool_cards: Dictionary = {}
var drawer_open: bool = false
var drawer_panel: PanelContainer

var score: int = 0
var level: int = 4
var mode: String = "Creative Sandbox"
var accuracy: float = 100.0

var spin_x: SpinBox
var spin_y: SpinBox
var spin_z: SpinBox

var style_btn_normal: StyleBoxFlat
var style_btn_hover: StyleBoxFlat
var style_btn_pressed: StyleBoxFlat
var style_active_card: StyleBoxFlat
var style_inactive_card: StyleBoxFlat

var score_label: Label
var level_label: Label
var mode_label: Label
var accuracy_progress: ProgressBar
var accuracy_label: Label

func _ready() -> void:
	var tc_script = load("res://ToolController.gd")
	if tc_script:
		var tc = tc_script.new()
		tc.name = "ToolController"
		add_child(tc)
		
	if audio_enabled:
		var synth_script = load("res://SoundSynthesiser.gd")
		if synth_script:
			sound_synthesizer = synth_script.new()
			add_child(sound_synthesizer)
		
	var canvas = CanvasLayer.new()
	canvas.name = "CanvasLayer"
	add_child(canvas)
	
	style_btn_normal = _create_glass_style(Color(0.14, 0.14, 0.18, 0.8), Color(1.0, 1.0, 1.0, 0.1), 8)
	style_btn_hover = _create_glass_style(Color(0.46, 0.76, 0.54, 0.25), Color(0.46, 0.76, 0.54, 0.8), 8)
	style_btn_pressed = _create_glass_style(Color(0.46, 0.76, 0.54, 0.4), Color(0.85, 0.67, 0.28, 1.0), 8)
	style_active_card = _create_glass_style(Color(0.46, 0.76, 0.54, 0.18), Color(0.85, 0.67, 0.28, 1.0), 12)
	style_inactive_card = _create_glass_style(Color(0.08, 0.08, 0.1, 0.5), Color(1.0, 1.0, 1.0, 0.08), 12)
	
	var fps_label = Label.new()
	fps_label.name = "FPSLabel"
	fps_label.position = Vector2(15, 60)
	fps_label.add_theme_color_override("font_color", Color(0.65, 0.65, 0.7, 1.0))
	fps_label.add_theme_font_size_override("font_size", 14)
	canvas.add_child(fps_label)
	
	var dev_toggle = Button.new()
	dev_toggle.name = "DevToggleBtn"
	dev_toggle.text = "[DEV] Console"
	dev_toggle.custom_minimum_size = Vector2(130, 40)
	dev_toggle.position = Vector2(15, 15)
	dev_toggle.add_theme_stylebox_override("normal", style_btn_normal)
	dev_toggle.add_theme_stylebox_override("hover", style_btn_hover)
	dev_toggle.add_theme_stylebox_override("pressed", style_btn_pressed)
	dev_toggle.add_theme_color_override("font_color", Color.WHITE)
	canvas.add_child(dev_toggle)
	_setup_btn_anims(dev_toggle)
	dev_toggle.pressed.connect(toggle_drawer)
	
	drawer_panel = PanelContainer.new()
	drawer_panel.name = "DrawerPanel"
	drawer_panel.custom_minimum_size = Vector2(340, 0)
	drawer_panel.set_anchors_preset(Control.PRESET_LEFT_WIDE)
	drawer_panel.grow_horizontal = Control.GROW_DIRECTION_END
	drawer_panel.position = Vector2(-340, 60)
	
	var drawer_style = _create_glass_style(Color(0.06, 0.06, 0.08, 0.94), Color(1.0, 1.0, 1.0, 0.15), 0)
	drawer_style.corner_radius_top_right = 16
	drawer_style.corner_radius_bottom_right = 16
	drawer_panel.add_theme_stylebox_override("panel", drawer_style)
	canvas.add_child(drawer_panel)
	
	var drawer_margin = MarginContainer.new()
	drawer_margin.add_theme_constant_override("margin_left", 15)
	drawer_margin.add_theme_constant_override("margin_right", 15)
	drawer_margin.add_theme_constant_override("margin_top", 70)
	drawer_margin.add_theme_constant_override("margin_bottom", 15)
	drawer_panel.add_child(drawer_margin)
	
	var drawer_scroll = ScrollContainer.new()
	drawer_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	drawer_margin.add_child(drawer_scroll)
	
	var drawer_vbox = VBoxContainer.new()
	drawer_vbox.add_theme_constant_override("separation", 15)
	drawer_scroll.add_child(drawer_vbox)
	
	var header_lbl = Label.new()
	header_lbl.text = "DEVELOPER CONSOLE"
	header_lbl.add_theme_color_override("font_color", Color(0.85, 0.67, 0.28, 1.0))
	header_lbl.add_theme_font_size_override("font_size", 16)
	drawer_vbox.add_child(header_lbl)
	
	var tree_gen = get_node_or_null("../TreeGenerator3D")
	
	var lvl_lbl = Label.new()
	lvl_lbl.text = "SELECT LEVEL / MODE:"
	lvl_lbl.add_theme_color_override("font_color", Color(0.85, 0.67, 0.28, 1.0))
	lvl_lbl.add_theme_font_size_override("font_size", 14)
	drawer_vbox.add_child(lvl_lbl)
	
	var levels = [
		{"name": "Level 1: Sphere Match", "idx": 1},
		{"name": "Level 2: Cube Match", "idx": 2},
		{"name": "Level 3: Diseased Pruning", "idx": 3},
		{"name": "Level 4: Creative Sandbox", "idx": 4}
	]
	
	for lvl in levels:
		var btn = Button.new()
		btn.text = lvl.name
		btn.custom_minimum_size = Vector2(280, 36)
		btn.add_theme_stylebox_override("normal", style_btn_normal)
		btn.add_theme_stylebox_override("hover", style_btn_hover)
		btn.add_theme_stylebox_override("pressed", style_btn_pressed)
		btn.add_theme_color_override("font_color", Color.WHITE)
		btn.add_theme_font_size_override("font_size", 12)
		drawer_vbox.add_child(btn)
		_setup_btn_anims(btn)
		btn.pressed.connect(func():
			var g_ctrl = get_node_or_null("../GameController")
			if g_ctrl and g_ctrl.has_method("select_level"):
				g_ctrl.select_level(lvl.idx)
		)
		
	var pos_lbl = Label.new()
	pos_lbl.text = "Camera Position:"
	pos_lbl.add_theme_color_override("font_color", Color(0.65, 0.65, 0.7, 1.0))
	drawer_vbox.add_child(pos_lbl)
	
	for axis in ["x", "y", "z"]:
		var hbox = HBoxContainer.new()
		drawer_vbox.add_child(hbox)
		var lbl = Label.new()
		lbl.text = axis.to_upper() + ":"
		lbl.custom_minimum_size = Vector2(40, 0)
		hbox.add_child(lbl)
		var spin = SpinBox.new()
		spin.min_value = -10000.0
		spin.max_value = 10000.0
		spin.step = 0.1
		spin.custom_minimum_size = Vector2(180, 0)
		spin.focus_mode = Control.FOCUS_CLICK
		spin.get_line_edit().focus_mode = Control.FOCUS_CLICK
		spin.get_line_edit().text_submitted.connect(func(_text): spin.get_line_edit().release_focus())
		hbox.add_child(spin)
		spin.value_changed.connect(_on_pos_changed.bind(axis))
		if axis == "x": spin_x = spin
		elif axis == "y": spin_y = spin
		elif axis == "z": spin_z = spin
		
	var seed_hbox = HBoxContainer.new()
	drawer_vbox.add_child(seed_hbox)
	var seed_lbl = Label.new()
	seed_lbl.text = "Seed:"
	seed_lbl.custom_minimum_size = Vector2(60, 0)
	seed_hbox.add_child(seed_lbl)
	var seed_spin = SpinBox.new()
	seed_spin.min_value = 0
	seed_spin.max_value = 100000
	seed_spin.step = 1
	seed_spin.custom_minimum_size = Vector2(120, 0)
	seed_spin.focus_mode = Control.FOCUS_CLICK
	seed_spin.get_line_edit().focus_mode = Control.FOCUS_CLICK
	seed_spin.get_line_edit().text_submitted.connect(func(_text): seed_spin.get_line_edit().release_focus())
	seed_hbox.add_child(seed_spin)
	if tree_gen:
		seed_spin.set_value_no_signal(tree_gen.seed)
	seed_spin.value_changed.connect(_on_seed_changed)
	
	var col_hbox = HBoxContainer.new()
	drawer_vbox.add_child(col_hbox)
	var col_lbl = Label.new()
	col_lbl.text = "Collisions:"
	col_lbl.custom_minimum_size = Vector2(120, 0)
	col_hbox.add_child(col_lbl)
	var col_check = CheckBox.new()
	col_check.focus_mode = Control.FOCUS_CLICK
	if tree_gen:
		col_check.button_pressed = tree_gen.show_debug
	else:
		col_check.button_pressed = true
	col_hbox.add_child(col_check)
	col_check.toggled.connect(_on_debug_toggled)
	
	var shape_hbox = HBoxContainer.new()
	drawer_vbox.add_child(shape_hbox)
	var shape_lbl = Label.new()
	shape_lbl.text = "Shape:"
	shape_lbl.custom_minimum_size = Vector2(120, 0)
	shape_hbox.add_child(shape_lbl)
	var shape_opt = OptionButton.new()
	shape_opt.add_item("Capsule", 0)
	shape_opt.add_item("Sphere", 1)
	shape_opt.focus_mode = Control.FOCUS_CLICK
	if tree_gen:
		shape_opt.selected = tree_gen.collision_shape_type
	shape_hbox.add_child(shape_opt)
	shape_opt.item_selected.connect(_on_shape_toggled)
	
	var self_hbox = HBoxContainer.new()
	drawer_vbox.add_child(self_hbox)
	var self_lbl = Label.new()
	self_lbl.text = "Self-Collision:"
	self_lbl.custom_minimum_size = Vector2(120, 0)
	self_hbox.add_child(self_lbl)
	var self_check = CheckBox.new()
	self_check.focus_mode = Control.FOCUS_CLICK
	if tree_gen:
		self_check.button_pressed = tree_gen.enable_self_collision
	self_hbox.add_child(self_check)
	self_check.toggled.connect(_on_self_col_toggled)
	
	var rule_sec_lbl = Label.new()
	rule_sec_lbl.text = "L-System Rule X:"
	rule_sec_lbl.add_theme_color_override("font_color", Color(0.65, 0.65, 0.7, 1.0))
	drawer_vbox.add_child(rule_sec_lbl)
	
	var rule_hbox = HBoxContainer.new()
	drawer_vbox.add_child(rule_hbox)
	var rule_edit = LineEdit.new()
	rule_edit.custom_minimum_size = Vector2(180, 0)
	rule_edit.focus_mode = Control.FOCUS_CLICK
	if tree_gen:
		rule_edit.text = tree_gen.rule_X
	rule_hbox.add_child(rule_edit)
	
	var rand_btn = Button.new()
	rand_btn.text = "Rand"
	rand_btn.custom_minimum_size = Vector2(60, 0)
	rand_btn.focus_mode = Control.FOCUS_CLICK
	rule_hbox.add_child(rand_btn)
	
	var rule_status = Label.new()
	rule_status.text = "Valid"
	rule_status.add_theme_color_override("font_color", Color.GREEN)
	drawer_vbox.add_child(rule_status)
	
	rule_edit.text_submitted.connect(func(new_text: String):
		_apply_rule(new_text, rule_edit, rule_status)
		rule_edit.release_focus()
	)
	rule_edit.text_changed.connect(func(new_text: String):
		_validate_rule_ui(new_text, rule_status)
	)
	rand_btn.pressed.connect(func():
		if tree_gen:
			for _attempt in range(20):
				var new_rule = tree_gen.randomize_rule_x()
				tree_gen.rule_X = new_rule
				tree_gen.regenerate_tree(tree_gen.seed)
				if tree_gen.branches.size() > 0:
					rule_edit.text = new_rule
					rule_status.text = "VALID Branches rendered: %d" % tree_gen.branches.size()
					rule_status.add_theme_color_override("font_color", Color.GREEN)
					break
			await get_tree().process_frame
			await get_tree().process_frame
			frame_tree()
	)
	
	_add_slider(drawer_vbox, "Iterations", "iterations", 1, 10, 1, tree_gen, true)
	_add_slider(drawer_vbox, "Segment Len", "segment_length", 0.1, 8.0, 0.1, tree_gen, true)
	_add_slider(drawer_vbox, "Branch Angle", "angle_deg", 5.0, 80.0, 1.0, tree_gen, true)
	_add_slider(drawer_vbox, "Thickness", "branch_thickness", 0.05, 2.0, 0.05, tree_gen, true)
	_add_slider(drawer_vbox, "Thickness Taper", "thickness_taper", 0.0, 0.5, 0.01, tree_gen, true)
	_add_slider(drawer_vbox, "Base Offset", "base_branch_offset", 0.0, 1.0, 0.05, tree_gen, true)
	_add_slider(drawer_vbox, "Vertical Falloff", "vertical_falloff", 0.1, 5.0, 0.1, tree_gen, true)
	_add_slider(drawer_vbox, "Branch Scaling", "branch_length_scale", 0.1, 3.0, 0.1, tree_gen, true)
	_add_slider(drawer_vbox, "Stiffness", "stiffness", 0.0, 200.0, 0.1, tree_gen, true)
	_add_slider(drawer_vbox, "Damping", "damping", 0.0, 50.0, 0.1, tree_gen, true)
	
	var wind_header = Label.new()
	wind_header.text = "WIND & ENVIRONMENT"
	wind_header.add_theme_color_override("font_color", Color(0.85, 0.67, 0.28, 1.0))
	wind_header.add_theme_font_size_override("font_size", 14)
	drawer_vbox.add_child(wind_header)
	
	_add_slider(drawer_vbox, "Wind Scale", "wind_scale", 0.1, 20.0, 0.1, tree_gen, false)
	_add_slider(drawer_vbox, "Wind Speed", "wind_speed", 0.0, 20.0, 0.1, tree_gen, false)
	_add_slider(drawer_vbox, "Capsule Wind x", "capsule_wind_multiplier", 1.0, 50.0, 0.5, tree_gen, false)
	
	var top_panel = PanelContainer.new()
	top_panel.name = "TopPanel"
	top_panel.custom_minimum_size = Vector2(820, 80)
	top_panel.set_anchors_preset(Control.PRESET_CENTER_TOP)
	top_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	top_panel.position = Vector2(-410, 5)
	var top_style = _create_glass_style(Color(0.08, 0.08, 0.1, 0.65), Color(1.0, 1.0, 1.0, 0.15), 12)
	top_panel.add_theme_stylebox_override("panel", top_style)
	canvas.add_child(top_panel)
	
	var top_margin = MarginContainer.new()
	top_margin.add_theme_constant_override("margin_left", 20)
	top_margin.add_theme_constant_override("margin_right", 20)
	top_panel.add_child(top_margin)
	
	var top_hbox = HBoxContainer.new()
	top_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	top_hbox.add_theme_constant_override("separation", 35)
	top_margin.add_child(top_hbox)
	
	var mode_vbox = VBoxContainer.new()
	mode_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	top_hbox.add_child(mode_vbox)
	var mode_title = Label.new()
	mode_title.text = "GAME MODE"
	mode_title.add_theme_color_override("font_color", Color(0.65, 0.65, 0.7, 1.0))
	mode_title.add_theme_font_size_override("font_size", 10)
	mode_vbox.add_child(mode_title)
	mode_label = Label.new()
	mode_label.text = mode
	mode_label.add_theme_color_override("font_color", Color(0.46, 0.76, 0.54, 1.0))
	mode_label.add_theme_font_size_override("font_size", 16)
	mode_vbox.add_child(mode_label)
	
	var lvl_vbox = VBoxContainer.new()
	lvl_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	top_hbox.add_child(lvl_vbox)
	var lvl_title = Label.new()
	lvl_title.text = "CURRENT LEVEL"
	lvl_title.add_theme_color_override("font_color", Color(0.65, 0.65, 0.7, 1.0))
	lvl_title.add_theme_font_size_override("font_size", 10)
	lvl_vbox.add_child(lvl_title)
	level_label = Label.new()
	level_label.text = "Level %d" % level
	level_label.add_theme_color_override("font_color", Color(0.85, 0.67, 0.28, 1.0))
	level_label.add_theme_font_size_override("font_size", 16)
	lvl_vbox.add_child(level_label)
	
	var score_vbox = VBoxContainer.new()
	score_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	top_hbox.add_child(score_vbox)
	var score_title = Label.new()
	score_title.text = "TOTAL SCORE"
	score_title.add_theme_color_override("font_color", Color(0.65, 0.65, 0.7, 1.0))
	score_title.add_theme_font_size_override("font_size", 10)
	score_vbox.add_child(score_title)
	score_label = Label.new()
	score_label.text = "%d" % score
	score_label.add_theme_color_override("font_color", Color.WHITE)
	score_label.add_theme_font_size_override("font_size", 16)
	score_vbox.add_child(score_label)
	
	var acc_vbox = VBoxContainer.new()
	acc_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	top_hbox.add_child(acc_vbox)
	var acc_title = Label.new()
	acc_title.text = "MATCH ACCURACY"
	acc_title.add_theme_color_override("font_color", Color(0.65, 0.65, 0.7, 1.0))
	acc_title.add_theme_font_size_override("font_size", 10)
	acc_vbox.add_child(acc_title)
	var acc_hbox = HBoxContainer.new()
	acc_hbox.add_theme_constant_override("separation", 10)
	acc_vbox.add_child(acc_hbox)
	
	accuracy_progress = ProgressBar.new()
	accuracy_progress.min_value = 0
	accuracy_progress.max_value = 100
	accuracy_progress.value = accuracy
	accuracy_progress.show_percentage = false
	accuracy_progress.custom_minimum_size = Vector2(100, 10)
	accuracy_progress.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var pg_bg = StyleBoxFlat.new()
	pg_bg.bg_color = Color(1, 1, 1, 0.05)
	pg_bg.corner_radius_top_left = 5
	pg_bg.corner_radius_top_right = 5
	pg_bg.corner_radius_bottom_left = 5
	pg_bg.corner_radius_bottom_right = 5
	accuracy_progress.add_theme_stylebox_override("background", pg_bg)
	var pg_fg = StyleBoxFlat.new()
	pg_fg.bg_color = Color(0.46, 0.76, 0.54, 0.85)
	pg_fg.corner_radius_top_left = 5
	pg_fg.corner_radius_top_right = 5
	pg_fg.corner_radius_bottom_left = 5
	pg_fg.corner_radius_bottom_right = 5
	accuracy_progress.add_theme_stylebox_override("fill", pg_fg)
	acc_hbox.add_child(accuracy_progress)
	
	accuracy_label = Label.new()
	accuracy_label.text = "%d%%" % int(accuracy)
	accuracy_label.add_theme_color_override("font_color", Color(0.46, 0.76, 0.54, 1.0))
	accuracy_label.add_theme_font_size_override("font_size", 14)
	acc_hbox.add_child(accuracy_label)
	
	var wind_vbox = VBoxContainer.new()
	wind_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	top_hbox.add_child(wind_vbox)
	var wind_title = Label.new()
	wind_title.text = "BREEZE CONTROL"
	wind_title.add_theme_color_override("font_color", Color(0.65, 0.65, 0.7, 1.0))
	wind_title.add_theme_font_size_override("font_size", 10)
	wind_vbox.add_child(wind_title)
	var wind_h = HBoxContainer.new()
	wind_h.add_theme_constant_override("separation", 10)
	wind_vbox.add_child(wind_h)
	var wind_slide = HSlider.new()
	wind_slide.min_value = 0.0
	wind_slide.max_value = 10.0
	wind_slide.value = tree_gen.wind_strength if tree_gen else 1.5
	wind_slide.custom_minimum_size = Vector2(100, 16)
	wind_slide.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	wind_h.add_child(wind_slide)
	var wind_val_lbl = Label.new()
	wind_val_lbl.text = "%d" % int(wind_slide.value)
	wind_val_lbl.add_theme_color_override("font_color", Color(0.85, 0.67, 0.28, 1.0))
	wind_val_lbl.add_theme_font_size_override("font_size", 12)
	wind_h.add_child(wind_val_lbl)
	wind_slide.value_changed.connect(func(val: float):
		wind_val_lbl.text = "%d" % int(val)
		if tree_gen:
			tree_gen.wind_strength = val
	)
	
	var tool_bar = PanelContainer.new()
	tool_bar.name = "ToolBar"
	tool_bar.custom_minimum_size = Vector2(520, 100)
	tool_bar.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	tool_bar.grow_horizontal = Control.GROW_DIRECTION_BOTH
	tool_bar.grow_vertical = Control.GROW_DIRECTION_BEGIN
	tool_bar.position = Vector2(-260, -130)
	var tool_bar_style = _create_glass_style(Color(0.06, 0.06, 0.08, 0.75), Color(1.0, 1.0, 1.0, 0.18), 16)
	tool_bar.add_theme_stylebox_override("panel", tool_bar_style)
	canvas.add_child(tool_bar)
	
	var tool_margin = MarginContainer.new()
	tool_margin.add_theme_constant_override("margin_left", 15)
	tool_margin.add_theme_constant_override("margin_right", 15)
	tool_bar.add_child(tool_margin)
	
	var tool_hbox = HBoxContainer.new()
	tool_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	tool_hbox.add_theme_constant_override("separation", 15)
	tool_margin.add_child(tool_hbox)
	
	var tools_list = ["Husqvarna", "Chainsaw", "Animated Chainsaw", "Makita Brushless", "Makita Outdoor", "Mini Sierra", "Hands"]
	var tool_emojis = {
		"Husqvarna": "[1] ",
		"Chainsaw": "[2] ",
		"Animated Chainsaw": "[3] ",
		"Makita Brushless": "[4] ",
		"Makita Outdoor": "[5] ",
		"Mini Sierra": "[6] ",
		"Hands": "[H] "
	}
	
	for t_name in tools_list:
		var btn = Button.new()
		btn.text = tool_emojis[t_name] + t_name
		btn.custom_minimum_size = Vector2(80, 55)
		btn.add_theme_stylebox_override("normal", style_inactive_card)
		btn.add_theme_stylebox_override("hover", style_btn_hover)
		btn.add_theme_stylebox_override("pressed", style_btn_pressed)
		btn.add_theme_color_override("font_color", Color.WHITE)
		btn.add_theme_font_size_override("font_size", 12)
		tool_hbox.add_child(btn)
		tool_cards[t_name] = btn
		_setup_btn_anims(btn)
		btn.pressed.connect(select_tool.bind(t_name))
		
	select_tool("Hands")
	
	var legend_panel = PanelContainer.new()
	legend_panel.name = "LegendPanel"
	legend_panel.custom_minimum_size = Vector2(200, 180)
	legend_panel.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	legend_panel.position = Vector2(-220, -210)
	var legend_style = _create_glass_style(Color(0.08, 0.08, 0.1, 0.6), Color(1.0, 1.0, 1.0, 0.12), 12)
	legend_panel.add_theme_stylebox_override("panel", legend_style)
	canvas.add_child(legend_panel)
	
	var legend_margin = MarginContainer.new()
	legend_margin.add_theme_constant_override("margin_left", 15)
	legend_margin.add_theme_constant_override("margin_right", 15)
	legend_margin.add_theme_constant_override("margin_top", 10)
	legend_margin.add_theme_constant_override("margin_bottom", 10)
	legend_panel.add_child(legend_margin)
	
	var legend_vbox = VBoxContainer.new()
	legend_margin.add_child(legend_vbox)
	
	var legend_title = Label.new()
	legend_title.text = "Camera Controls"
	legend_title.add_theme_color_override("font_color", Color(0.85, 0.67, 0.28, 1.0))
	legend_title.add_theme_font_size_override("font_size", 14)
	legend_vbox.add_child(legend_title)
	
	var keys = [
		"W/S - Forward / Back",
		"A/D - Strafe Left / Right",
		"Q/E - Down / Up",
		"Right-Click Drag - Orbit",
		"Left/Right - Orbit",
		"Scroll - Zoom",
	]
	for k in keys:
		var lbl = Label.new()
		lbl.text = k
		lbl.add_theme_color_override("font_color", Color(0.65, 0.65, 0.7, 1.0))
		lbl.add_theme_font_size_override("font_size", 11)
		legend_vbox.add_child(lbl)
		
	await get_tree().process_frame
	await get_tree().process_frame
	frame_tree()

func _create_glass_style(bg_col: Color, border_col: Color, radius: int) -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = bg_col
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.border_color = border_col
	style.corner_radius_top_left = radius
	style.corner_radius_top_right = radius
	style.corner_radius_bottom_left = radius
	style.corner_radius_bottom_right = radius
	style.shadow_color = Color(0, 0, 0, 0.2)
	style.shadow_size = 6
	style.shadow_offset = Vector2(0, 3)
	return style

func _setup_btn_anims(btn: Control) -> void:
	btn.pivot_offset = btn.custom_minimum_size / 2.0
	btn.mouse_entered.connect(func():
		var tween = btn.create_tween()
		tween.tween_property(btn, "scale", Vector2(1.06, 1.06), 0.15).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	)
	btn.mouse_exited.connect(func():
		var tween = btn.create_tween()
		tween.tween_property(btn, "scale", Vector2(1.0, 1.0), 0.15).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	)
	btn.button_down.connect(func():
		var tween = btn.create_tween()
		tween.tween_property(btn, "scale", Vector2(0.94, 0.94), 0.08).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	)
	btn.button_up.connect(func():
		var tween = btn.create_tween()
		tween.tween_property(btn, "scale", Vector2(1.0, 1.0), 0.15).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	)

func toggle_drawer() -> void:
	drawer_open = not drawer_open
	var target_x = 0.0 if drawer_open else -340.0
	var target_pos = Vector2(target_x, drawer_panel.position.y)
	var tween = create_tween()
	tween.tween_property(drawer_panel, "position", target_pos, 0.35).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	if sound_synthesizer:
		sound_synthesizer.play_sound("scissor")

func select_tool(t_name: String) -> void:
	active_tool = t_name
	for tn in tool_cards.keys():
		var btn: Button = tool_cards[tn]
		if tn == active_tool:
			btn.add_theme_stylebox_override("normal", style_active_card)
			btn.add_theme_color_override("font_color", Color(0.85, 0.67, 0.28, 1.0))
		else:
			btn.add_theme_stylebox_override("normal", style_inactive_card)
			btn.add_theme_color_override("font_color", Color.WHITE)
			
	if sound_synthesizer:
		sound_synthesizer.stop_sound("all")
		if active_tool in ["Husqvarna", "Chainsaw", "Animated Chainsaw", "Makita Brushless", "Makita Outdoor"]:
			sound_synthesizer.play_sound("chainsaw")
		elif active_tool == "Mini Sierra":
			sound_synthesizer.play_sound("minisaw")
		elif active_tool == "Hands":
			sound_synthesizer.play_sound("chime")
			
	var tool_controller = get_node_or_null("ToolController")
	if tool_controller:
		if tool_controller.has_method("set_active_tool"):
			tool_controller.set_active_tool(active_tool)
		elif tool_controller.has_method("select_tool"):
			var tc_name = active_tool.to_lower().replace(" ", "_")
			if tc_name == "mini_sierra": tc_name = "mini_sierra"
			tool_controller.select_tool(tc_name)
			
	var game_controller = get_node_or_null("../GameController")
	if game_controller:
		game_controller.active_tool = active_tool

func refresh_hud() -> void:
	if score_label:
		score_label.text = "%d" % score
	if level_label:
		level_label.text = "Level %d" % level
	if mode_label:
		mode_label.text = mode
	if accuracy_progress:
		accuracy_progress.value = accuracy
	if accuracy_label:
		accuracy_label.text = "%d%%" % int(accuracy)

func _add_slider(panel: Control, label_text: String, prop_name: String, min_val: float, max_val: float, step: float, tree_gen: Node, triggers_regen: bool) -> void:
	var hbox = HBoxContainer.new()
	hbox.name = "HBox" + prop_name.to_upper()
	panel.add_child(hbox)
	
	var label = Label.new()
	label.text = label_text + ":"
	label.custom_minimum_size = Vector2(120, 0)
	label.add_theme_color_override("font_color", Color(0.65, 0.65, 0.7, 1.0))
	label.add_theme_font_size_override("font_size", 12)
	hbox.add_child(label)
	
	var spin = SpinBox.new()
	spin.name = "Spin" + prop_name.to_upper()
	spin.min_value = min_val
	spin.max_value = max_val
	spin.step = step
	spin.custom_minimum_size = Vector2(140, 0)
	spin.focus_mode = Control.FOCUS_CLICK
	
	var le = spin.get_line_edit()
	le.focus_mode = Control.FOCUS_CLICK
	le.text_submitted.connect(func(_text): le.release_focus())
	
	if tree_gen:
		spin.set_value_no_signal(tree_gen.get(prop_name))
		
	hbox.add_child(spin)
	
	spin.value_changed.connect(func(val: float):
		if tree_gen:
			tree_gen.set(prop_name, val)
			if triggers_regen and tree_gen.has_method("regenerate_tree"):
				tree_gen.regenerate_tree(tree_gen.seed)
				var rule_status = panel.get_node_or_null("RuleStatus")
				if rule_status:
					rule_status.text = "VALID Branches rendered: %d" % tree_gen.branches.size()
					rule_status.add_theme_color_override("font_color", Color.GREEN)
				await get_tree().process_frame
				await get_tree().process_frame
				frame_tree()
	)

func frame_tree() -> void:
	var tree_gen = get_node_or_null("../TreeGenerator3D")
	if not tree_gen or not tree_gen.has_method("get_tree_bounds"):
		return
	var bounds = tree_gen.get_tree_bounds()
	if bounds.size.length() < 0.01:
		return
	
	var center = bounds.get_center()
	var tree_height = bounds.size.y
	var tree_width = max(bounds.size.x, bounds.size.z)
	var max_dim = max(tree_height, tree_width)
	
	var half_fov = deg_to_rad(fov * 0.5)
	var required_dist = (max_dim * 0.7) / tan(half_fov)
	
	var angle_rad = deg_to_rad(35.0)
	var offset = Vector3(cos(angle_rad), 0.45, sin(angle_rad)).normalized() * required_dist
	
	position = center + offset
	look_at(center - Vector3(0, tree_height * 0.1, 0), Vector3.UP)

func _validate_rule_ui(rule_text: String, status_label: Label) -> void:
	var tree_gen = get_node_or_null("../TreeGenerator3D")
	if not tree_gen:
		return
	var err = tree_gen.validate_rule(rule_text)
	if err == "":
		status_label.text = "Valid"
		status_label.add_theme_color_override("font_color", Color.GREEN)
	else:
		status_label.text = err
		status_label.add_theme_color_override("font_color", Color.RED)

func _apply_rule(rule_text: String, rule_edit: LineEdit, status_label: Label) -> void:
	var tree_gen = get_node_or_null("../TreeGenerator3D")
	if not tree_gen:
		return
	var err = tree_gen.validate_rule(rule_text)
	if err == "":
		var old_rule = tree_gen.rule_X
		tree_gen.rule_X = rule_text
		tree_gen.regenerate_tree(tree_gen.seed)
		if tree_gen.branches.size() == 0:
			tree_gen.rule_X = old_rule
			tree_gen.regenerate_tree(tree_gen.seed)
			rule_edit.text = old_rule
			status_label.text = "Rule produced 0 branches"
			status_label.add_theme_color_override("font_color", Color.RED)
		else:
			status_label.text = "VALID Branches rendered: %d" % tree_gen.branches.size()
			status_label.add_theme_color_override("font_color", Color.GREEN)
	else:
		status_label.text = err
		status_label.add_theme_color_override("font_color", Color.RED)

func _on_self_col_toggled(toggled_on: bool) -> void:
	var tree_gen = get_node_or_null("../TreeGenerator3D")
	if tree_gen and tree_gen.has_method("regenerate_tree"):
		tree_gen.enable_self_collision = toggled_on
		tree_gen.regenerate_tree(tree_gen.seed)

func _on_shape_toggled(index: int) -> void:
	var tree_gen = get_node_or_null("../TreeGenerator3D")
	if tree_gen and tree_gen.has_method("regenerate_tree"):
		tree_gen.collision_shape_type = index
		tree_gen.regenerate_tree(tree_gen.seed)

func _on_debug_toggled(toggled_on: bool) -> void:
	var tree_gen = get_node_or_null("../TreeGenerator3D")
	if tree_gen and tree_gen.has_method("set_debug_visible"):
		tree_gen.set_debug_visible(toggled_on)

func _on_seed_changed(val: float) -> void:
	var tree_gen = get_node_or_null("../TreeGenerator3D")
	if tree_gen and tree_gen.has_method("regenerate_tree"):
		tree_gen.regenerate_tree(int(val))

func _on_pos_changed(val: float, axis: String) -> void:
	if axis == "x":
		position.x = val
	elif axis == "y":
		position.y = val
	elif axis == "z":
		position.z = val

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		var key_map = {
			KEY_1: "Husqvarna",
			KEY_2: "Chainsaw",
			KEY_3: "Animated Chainsaw",
			KEY_4: "Makita Brushless",
			KEY_5: "Makita Outdoor",
			KEY_6: "Mini Sierra",
			KEY_H: "Hands"
		}
		if key_map.has(event.keycode):
			select_tool(key_map[event.keycode])
			return
		if event.keycode == KEY_E:
			_toggle_climbing()
			return
	var focus_owner = get_viewport().gui_get_focus_owner()
	if focus_owner and focus_owner is LineEdit:
		if event is InputEventMouseButton and event.is_pressed():
			focus_owner.release_focus()
		return

	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				if sound_synthesizer:
					if active_tool in ["Husqvarna", "Chainsaw", "Animated Chainsaw", "Makita Brushless", "Makita Outdoor"]:
						sound_synthesizer.play_sound("chainsaw_cut")
						sound_synthesizer.play_sound("grinding")
					elif active_tool == "Mini Sierra":
						sound_synthesizer.play_sound("minisaw_cut")
						sound_synthesizer.play_sound("grinding")
					elif active_tool == "Pruning Shears":
						sound_synthesizer.play_sound("scissor")
			else:
				if sound_synthesizer:
					if active_tool == "Chainsaw":
						sound_synthesizer.play_sound("chainsaw")
						sound_synthesizer.stop_sound("grinding")
					elif active_tool == "Mini-Saw":
						sound_synthesizer.play_sound("minisaw")
						sound_synthesizer.stop_sound("grinding")
						
		if event.button_index == MOUSE_BUTTON_RIGHT:
			is_orbiting = event.pressed
			if event.pressed:
				Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
			else:
				Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

		var zoom_speed = 2.0
		var forward_dir = -global_transform.basis.z.normalized()
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			position += forward_dir * zoom_speed
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			position -= forward_dir * zoom_speed

	if event is InputEventMouseMotion and is_orbiting:
		var rel = event.relative
		rotate_y(-rel.x * orbit_sensitivity)
		var current_x_rot = rotation.x
		var new_x = clamp(current_x_rot - rel.y * orbit_sensitivity, -PI * 0.45, PI * 0.45)
		rotation.x = new_x

func _process(delta: float) -> void:
	var label = get_node_or_null("CanvasLayer/FPSLabel")
	if label:
		label.text = "FPS: %d" % Engine.get_frames_per_second()
		
	var is_typing = false
	var focus_owner = get_viewport().gui_get_focus_owner()
	if focus_owner and focus_owner is LineEdit:
		is_typing = true
		
	if spin_x and not spin_x.get_line_edit().has_focus():
		spin_x.set_value_no_signal(position.x)
	if spin_y and not spin_y.get_line_edit().has_focus():
		spin_y.set_value_no_signal(position.y)
	if spin_z and not spin_z.get_line_edit().has_focus():
		spin_z.set_value_no_signal(position.z)
					
	if is_typing:
		return
		
	if is_climbing and climb_target and is_instance_valid(climb_target):
		var climb_pos = climb_target.global_position
		if Input.is_key_pressed(KEY_W):
			climb_height += CLIMB_SPEED * delta
		if Input.is_key_pressed(KEY_S):
			climb_height -= CLIMB_SPEED * delta
			if climb_height < player_height:
				climb_height = player_height
				is_climbing = false
		if Input.is_key_pressed(KEY_A):
			var angle = CLIMB_SPEED * delta
			var offset = position - climb_pos
			offset.y = 0
			var dist = offset.length()
			if dist < 0.1:
				dist = 1.0
			var current_angle = atan2(offset.z, offset.x)
			current_angle += angle
			position.x = climb_pos.x + cos(current_angle) * dist
			position.z = climb_pos.z + sin(current_angle) * dist
			rotation.y += angle
		if Input.is_key_pressed(KEY_D):
			var angle = -CLIMB_SPEED * delta
			var offset = position - climb_pos
			offset.y = 0
			var dist = offset.length()
			if dist < 0.1:
				dist = 1.0
			var current_angle = atan2(offset.z, offset.x)
			current_angle += angle
			position.x = climb_pos.x + cos(current_angle) * dist
			position.z = climb_pos.z + sin(current_angle) * dist
			rotation.y += angle
		position.y = climb_height
		velocity = Vector3.ZERO
		return

	var forward_vec = -global_transform.basis.z
	forward_vec.y = 0
	if forward_vec.length_squared() > 0.001:
		forward_vec = forward_vec.normalized()
	var right_vec = global_transform.basis.x.normalized()
	right_vec.y = 0
	if right_vec.length_squared() > 0.001:
		right_vec = right_vec.normalized()

	var move_dir := Vector3.ZERO
	if Input.is_key_pressed(KEY_W):
		move_dir += forward_vec
	if Input.is_key_pressed(KEY_S):
		move_dir -= forward_vec
	if Input.is_key_pressed(KEY_D):
		move_dir += right_vec
	if Input.is_key_pressed(KEY_A):
		move_dir -= right_vec

	if move_dir.length_squared() > 0:
		move_dir = move_dir.normalized()

	velocity.x = move_dir.x * walk_speed
	velocity.z = move_dir.z * walk_speed

	velocity.y -= gravity * delta

	var ground_y = player_height
	if position.y + velocity.y * delta <= ground_y:
		position.y = ground_y
		velocity.y = 0.0
		on_ground = true
	else:
		on_ground = false

	if on_ground and Input.is_key_pressed(KEY_SPACE):
		velocity.y = jump_speed

	var t_move = velocity * delta
	t_move.y = velocity.y * delta

	if t_move.length() > 0:
		position += t_move.normalized() * move_speed * delta


func _toggle_climbing() -> void:
	if is_climbing:
		is_climbing = false
		climb_target = null
		return

	var space_state = get_world_3d().direct_space_state
	var vp_center = get_viewport().get_visible_rect().size * 0.5
	var origin = project_ray_origin(vp_center)
	var ray_end = origin + project_ray_normal(vp_center) * 3.0
	var query = PhysicsRayQueryParameters3D.create(origin, ray_end)
	query.collision_mask = 2
	var result = space_state.intersect_ray(query)
	if result:
		var hit = result.collider
		if hit:
			is_climbing = true
			climb_target = hit
			climb_height = position.y
			var to_trunk = hit.global_position - position
			to_trunk.y = 0
			if to_trunk.length() > 0.5:
				var dir = to_trunk.normalized()
				position.x = hit.global_position.x - dir.x * 0.8
				position.z = hit.global_position.z - dir.z * 0.8
