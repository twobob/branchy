extends Camera3D

@export var move_speed: float = 10.0

func _ready() -> void:
	var canvas := CanvasLayer.new()
	canvas.name = "CanvasLayer"
	add_child(canvas)
	
	var fps_label := Label.new()
	fps_label.name = "FPSLabel"
	fps_label.position = Vector2(10, 10)
	fps_label.add_theme_color_override("font_color", Color.WHITE)
	fps_label.add_theme_font_size_override("font_size", 24)
	canvas.add_child(fps_label)
	var scroll = ScrollContainer.new()
	scroll.name = "ScrollContainer"
	scroll.position = Vector2(10, 50)
	scroll.size = Vector2(320, 600)
	canvas.add_child(scroll)
	
	var panel = VBoxContainer.new()
	panel.name = "UIPanel"
	scroll.add_child(panel)

	# Top Right Panel - Camera Controls
	var top_right_panel = VBoxContainer.new()
	top_right_panel.name = "TopRightPanel"
	top_right_panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	top_right_panel.position = Vector2(-200, 10)
	top_right_panel.alignment = BoxContainer.ALIGNMENT_END
	canvas.add_child(top_right_panel)

	for axis in ["x", "y", "z"]:
		var hbox = HBoxContainer.new()
		hbox.name = "HBox" + axis.to_upper()
		hbox.alignment = BoxContainer.ALIGNMENT_END
		top_right_panel.add_child(hbox)
		
		var label = Label.new()
		label.text = "Pos " + axis.to_upper() + ":"
		label.custom_minimum_size = Vector2(60, 0)
		hbox.add_child(label)
		
		var spin = SpinBox.new()
		spin.name = "Spin" + axis.to_upper()
		spin.min_value = -10000.0
		spin.max_value = 10000.0
		spin.step = 0.1
		spin.custom_minimum_size = Vector2(120, 0)
		spin.focus_mode = Control.FOCUS_CLICK
		spin.get_line_edit().focus_mode = Control.FOCUS_CLICK
		
		var line_edit = spin.get_line_edit()
		line_edit.text_submitted.connect(func(_text): line_edit.release_focus())
		
		hbox.add_child(spin)
		spin.value_changed.connect(_on_pos_changed.bind(axis))
		
	# Add Seed Control UI
	var seed_hbox = HBoxContainer.new()
	seed_hbox.name = "HBoxSEED"
	panel.add_child(seed_hbox)
	
	var seed_label = Label.new()
	seed_label.text = "Seed:"
	seed_label.custom_minimum_size = Vector2(60, 0)
	seed_hbox.add_child(seed_label)
	
	var seed_spin = SpinBox.new()
	seed_spin.name = "SpinSEED"
	seed_spin.min_value = 0
	seed_spin.max_value = 100000
	seed_spin.step = 1
	seed_spin.custom_minimum_size = Vector2(120, 0)
	seed_spin.focus_mode = Control.FOCUS_CLICK
	seed_spin.get_line_edit().focus_mode = Control.FOCUS_CLICK
	
	var seed_line_edit = seed_spin.get_line_edit()
	seed_line_edit.text_submitted.connect(func(_text): seed_line_edit.release_focus())
	
	seed_hbox.add_child(seed_spin)
	
	# Fetch initial seed from generator
	var tree_gen = get_node_or_null("../TreeGenerator3D")
	if tree_gen:
		seed_spin.set_value_no_signal(tree_gen.seed)
	
	seed_spin.value_changed.connect(_on_seed_changed)

	# Add Collision Debug UI
	var debug_hbox = HBoxContainer.new()
	debug_hbox.name = "HBoxDEBUG"
	panel.add_child(debug_hbox)
	
	var debug_label = Label.new()
	debug_label.text = "Show Collisions:"
	debug_label.custom_minimum_size = Vector2(120, 0)
	debug_hbox.add_child(debug_label)
	
	var debug_check = CheckBox.new()
	debug_check.name = "CheckDEBUG"
	debug_check.focus_mode = Control.FOCUS_CLICK
	debug_check.button_pressed = get_tree().debug_collisions_hint
	debug_hbox.add_child(debug_check)
	
	debug_check.toggled.connect(_on_debug_toggled)

	# Add Collision Shape UI
	var shape_hbox = HBoxContainer.new()
	shape_hbox.name = "HBoxSHAPE"
	panel.add_child(shape_hbox)
	
	var shape_label = Label.new()
	shape_label.text = "Shape:"
	shape_label.custom_minimum_size = Vector2(120, 0)
	shape_hbox.add_child(shape_label)
	
	var shape_opt = OptionButton.new()
	shape_opt.name = "OptSHAPE"
	shape_opt.add_item("Capsule", 0)
	shape_opt.add_item("Sphere", 1)
	shape_opt.focus_mode = Control.FOCUS_CLICK
	
	if tree_gen:
		shape_opt.selected = tree_gen.collision_shape_type
		
	shape_hbox.add_child(shape_opt)
	shape_opt.item_selected.connect(_on_shape_toggled)
	
	# Add Self-Collision UI
	var self_col_hbox = HBoxContainer.new()
	self_col_hbox.name = "HBoxSELFCOL"
	panel.add_child(self_col_hbox)
	
	var self_col_label = Label.new()
	self_col_label.text = "Self-Collision:"
	self_col_label.custom_minimum_size = Vector2(120, 0)
	self_col_hbox.add_child(self_col_label)
	
	var self_col_check = CheckBox.new()
	self_col_check.name = "CheckSELFCOL"
	self_col_check.focus_mode = Control.FOCUS_CLICK
	
	if tree_gen:
		self_col_check.button_pressed = tree_gen.enable_self_collision
		
	self_col_hbox.add_child(self_col_check)
	self_col_check.toggled.connect(_on_self_col_toggled)
	
	_add_slider(panel, "Iterations", "iterations", 1, 8, 1, tree_gen, true)
	_add_slider(panel, "Segment Len", "segment_length", 0.1, 8.0, 0.1, tree_gen, true)
	_add_slider(panel, "Branch Angle", "angle_deg", 5.0, 80.0, 1.0, tree_gen, true)
	_add_slider(panel, "Thickness", "branch_thickness", 0.05, 2.0, 0.05, tree_gen, true)
	_add_slider(panel, "Thickness Taper", "thickness_taper", 0.0, 0.5, 0.01, tree_gen, true)
	_add_slider(panel, "Base Offset", "base_branch_offset", 0.0, 1.0, 0.05, tree_gen, true)
	_add_slider(panel, "Vertical Falloff", "vertical_falloff", 0.1, 5.0, 0.1, tree_gen, true)
	_add_slider(panel, "Branch Scaling", "branch_length_scale", 0.1, 3.0, 0.1, tree_gen, true)
	
	_add_slider(panel, "Stiffness", "stiffness", 0.0, 200.0, 1.0, tree_gen, true)
	_add_slider(panel, "Damping", "damping", 0.0, 50.0, 0.1, tree_gen, true)
	# Bottom Right Panel - Wind Controls
	var bottom_right_panel = VBoxContainer.new()
	bottom_right_panel.name = "BottomRightPanel"
	bottom_right_panel.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	bottom_right_panel.position = Vector2(-300, -150)
	canvas.add_child(bottom_right_panel)
	
	_add_slider(bottom_right_panel, "Wind Strength", "wind_strength", 0.0, 200.0, 1.0, tree_gen, false)
	_add_slider(bottom_right_panel, "Wind Scale", "wind_scale", 0.1, 20.0, 0.1, tree_gen, false)
	_add_slider(bottom_right_panel, "Wind Speed", "wind_speed", 0.0, 20.0, 0.1, tree_gen, false)
	_add_slider(bottom_right_panel, "Capsule Wind x", "capsule_wind_multiplier", 1.0, 50.0, 0.5, tree_gen, false)

func _add_slider(panel: Control, label_text: String, prop_name: String, min_val: float, max_val: float, step: float, tree_gen: Node, triggers_regen: bool):
	var hbox = HBoxContainer.new()
	hbox.name = "HBox" + prop_name.to_upper()
	panel.add_child(hbox)
	
	var label = Label.new()
	label.text = label_text + ":"
	label.custom_minimum_size = Vector2(140, 0)
	hbox.add_child(label)
	
	var spin = SpinBox.new()
	spin.name = "Spin" + prop_name.to_upper()
	spin.min_value = min_val
	spin.max_value = max_val
	spin.step = step
	spin.custom_minimum_size = Vector2(120, 0)
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
	)

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
	get_tree().debug_collisions_hint = toggled_on
	
	# Godot requires physics shapes to completely respawn to actually draw their debug mesh
	var tree_gen = get_node_or_null("../TreeGenerator3D")
	if tree_gen and tree_gen.has_method("regenerate_tree"):
		tree_gen.regenerate_tree(tree_gen.seed)

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
	var focus_owner = get_viewport().gui_get_focus_owner()
	if focus_owner and focus_owner is LineEdit:
		return

	if event is InputEventMouseButton and event.is_pressed():
		var zoom_speed = 2.0
		# Zoom directly along where the camera is currently looking
		var forward_dir = -global_transform.basis.z.normalized()
		
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			position += forward_dir * zoom_speed
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			position -= forward_dir * zoom_speed

func _process(delta: float) -> void:
	var label = get_node_or_null("CanvasLayer/FPSLabel")
	if label:
		label.text = "FPS: %d" % Engine.get_frames_per_second()
		
	var is_typing = false
	var focus_owner = get_viewport().gui_get_focus_owner()
	if focus_owner and focus_owner is LineEdit:
		is_typing = true
		
	var top_right_panel = get_node_or_null("CanvasLayer/TopRightPanel")
	if top_right_panel:
		for axis in ["x", "y", "z"]:
			var spin: SpinBox = top_right_panel.get_node_or_null("HBox" + axis.to_upper() + "/Spin" + axis.to_upper())
			if spin and not spin.get_line_edit().has_focus():
				if axis == "x": spin.set_value_no_signal(position.x)
				elif axis == "y": spin.set_value_no_signal(position.y)
				elif axis == "z": spin.set_value_no_signal(position.z)
					
	if is_typing:
		return
		
	var t_move := Vector3.ZERO
	
	# Global Up / Down
	if Input.is_key_pressed(KEY_E) or Input.is_key_pressed(KEY_UP):
		t_move.y += 1.0
	if Input.is_key_pressed(KEY_Q) or Input.is_key_pressed(KEY_DOWN):
		t_move.y -= 1.0
		
	# Strafe Left / Right
	var right_vec = global_transform.basis.x.normalized()
	if Input.is_key_pressed(KEY_D):
		t_move += right_vec
	if Input.is_key_pressed(KEY_A):
		t_move -= right_vec
		
	# Orbit Left / Right (Rotates position around global Y axis without snapping looking angle)
	if Input.is_key_pressed(KEY_RIGHT) or Input.is_key_pressed(KEY_LEFT):
		var angle = move_speed * delta * 0.1
		if Input.is_key_pressed(KEY_LEFT):
			angle = -angle
			
		# Extract horizontal 2D position relative to center (0,0)
		var pos_2d = Vector2(position.x, position.z)
		
		# Rotate 2D vector
		var cos_a = cos(angle)
		var sin_a = sin(angle)
		var new_x = pos_2d.x * cos_a - pos_2d.y * sin_a
		var new_z = pos_2d.x * sin_a + pos_2d.y * cos_a
		
		# Apply exclusively to X and Z, perfectly preserving Y
		position.x = new_x
		position.z = new_z
		
		# Rotate the camera itself around its own Y axis by the exact same amount
		rotate_y(-angle)
		
	# Forward / Backward (Flattened to XZ plane so W/S never move you straight into the ground)
	var forward_vec = -global_transform.basis.z
	forward_vec.y = 0
	if forward_vec.length_squared() > 0.001:
		forward_vec = forward_vec.normalized()
	else:
		forward_vec = -global_transform.basis.y
		
	if Input.is_key_pressed(KEY_W):
		t_move += forward_vec
	if Input.is_key_pressed(KEY_S):
		t_move -= forward_vec

	if t_move.length() > 0:
		position += t_move.normalized() * move_speed * delta
