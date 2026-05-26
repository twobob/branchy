extends Node3D
class_name GameController

enum Mode { SILHOUETTE, DEADWOOD, SANDBOX }
var current_mode: int = Mode.SANDBOX



var current_level: int = 4


var score: int = 0
var pruned_deadwood: int = 0
var total_deadwood: int = 0
var healthy_cut: int = 0
var level_completed: bool = false


var total_branches_at_start: int = 0
var original_branch_states: Array = []
var cut_branches: Dictionary = {}


var hologram_mesh_instance: MeshInstance3D
var hologram_shape: String = "Sphere"
var hologram_size: float = 3.5
var hologram_center: Vector3 = Vector3(0, 3.5, 0)
var hologram_material: StandardMaterial3D


var active_tool: String = "Chainsaw"


var tree_generator: Node3D
var camera_controller: Camera3D
var hopper_area: Area3D
var wood_chipper_root: Node3D


var canvas_layer: CanvasLayer
var info_label: Label
var accuracy_label: Label
var score_label: Label
var level_title_label: Label
var victory_panel: PanelContainer
var victory_label: Label

func _ready() -> void:

	tree_generator = get_node_or_null("../TreeGenerator3D")
	camera_controller = get_node_or_null("../Camera3D")
	
	if not tree_generator:

		tree_generator = get_parent().get_node_or_null("TreeGenerator3D")
	if not camera_controller:
		camera_controller = get_parent().get_node_or_null("Camera3D")
		

	hologram_material = StandardMaterial3D.new()
	hologram_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	hologram_material.albedo_color = Color(0.0, 0.8, 1.0, 0.25)
	hologram_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	hologram_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	

	hologram_mesh_instance = MeshInstance3D.new()
	hologram_mesh_instance.name = "HologramVisual"
	hologram_mesh_instance.material_override = hologram_material
	hologram_mesh_instance.visible = false
	add_child(hologram_mesh_instance)
	

	_setup_wood_chipper()
	

	_setup_hud()
	


	await get_tree().process_frame
	select_level(4)

func _process(delta: float) -> void:
	if current_mode == Mode.SILHOUETTE and not level_completed:
		var acc = calculate_accuracy()
		accuracy_label.text = "Match Accuracy: %.1f%%" % acc
		

		var some_pruning = false
		for k in cut_branches:
			if cut_branches[k] == true:
				some_pruning = true
				break
				
		if acc >= 90.0 and some_pruning:
			complete_level()
			

	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		_handle_mouse_action()

func _setup_wood_chipper() -> void:

	var chipper_mesh = load("res://assets/wood_chipper.obj")
	if not chipper_mesh:
		print("Warning: Could not load wood_chipper.obj")
		return
		

	wood_chipper_root = Node3D.new()
	wood_chipper_root.name = "WoodChipper"
	add_child(wood_chipper_root)
	
	var chipper_vis = MeshInstance3D.new()
	chipper_vis.name = "Visual"
	chipper_vis.mesh = chipper_mesh
	

	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(0.85, 0.45, 0.1)
	mat.roughness = 0.4
	mat.metallic = 0.7
	chipper_vis.material_override = mat
	wood_chipper_root.add_child(chipper_vis)
	

	var center_offset = Vector3(1952.435, 233.793, 82.197)
	chipper_vis.position = -center_offset
	

	wood_chipper_root.scale = Vector3(0.001, 0.001, 0.001)
	

	wood_chipper_root.position = Vector3(4.5, 0.0, 0.0)
	wood_chipper_root.rotation_degrees = Vector3(0, 180, 0)
	

	hopper_area = Area3D.new()
	hopper_area.name = "HopperArea"
	add_child(hopper_area)
	hopper_area.position = Vector3(4.5, 1.2, 0.0)
	
	var col = CollisionShape3D.new()
	var box = BoxShape3D.new()
	box.size = Vector3(2.5, 2.0, 2.5)
	col.shape = box
	hopper_area.add_child(col)
	
	hopper_area.body_entered.connect(_on_hopper_body_entered)

func _setup_hud() -> void:
	canvas_layer = CanvasLayer.new()
	canvas_layer.name = "GameHUD"
	add_child(canvas_layer)
	

	var main_box = HBoxContainer.new()
	main_box.set_anchors_preset(Control.PRESET_FULL_RECT)
	main_box.offset_left = 20
	main_box.offset_top = 20
	main_box.offset_right = -20
	main_box.offset_bottom = -20
	main_box.mouse_filter = Control.MOUSE_FILTER_PASS
	canvas_layer.add_child(main_box)
	

	var left_col = VBoxContainer.new()
	left_col.custom_minimum_size = Vector2(250, 0)
	left_col.add_theme_constant_override("separation", 15)
	main_box.add_child(left_col)
	

	var title = Label.new()
	title.text = "BRANCHY! 🌳"
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", Color.YELLOW)
	left_col.add_child(title)
	

	level_title_label = Label.new()
	level_title_label.text = "Level: Creative Sandbox"
	level_title_label.add_theme_font_size_override("font_size", 18)
	left_col.add_child(level_title_label)
	

	var lvl_group = VBoxContainer.new()
	lvl_group.name = "LevelGroup"
	left_col.add_child(lvl_group)
	
	var levels = [
		{"name": "Level 1: Sphere Match", "idx": 1},
		{"name": "Level 2: Cube Match", "idx": 2},
		{"name": "Level 3: Deadwood Pruning", "idx": 3},
		{"name": "Level 4: Creative Sandbox", "idx": 4}
	]
	
	for lvl in levels:
		var btn = Button.new()
		btn.text = lvl.name
		btn.alignment = HorizontalAlignment.HORIZONTAL_ALIGNMENT_LEFT
		btn.focus_mode = Control.FOCUS_NONE
		btn.pressed.connect(func():
			play_procedural_sound("click")
			select_level(lvl.idx)
		)
		lvl_group.add_child(btn)
		

	var tool_label = Label.new()
	tool_label.text = "SELECT TOOL:"
	tool_label.add_theme_font_size_override("font_size", 14)
	left_col.add_child(tool_label)
	
	var tool_box = HBoxContainer.new()
	tool_box.name = "ToolBox"
	left_col.add_child(tool_box)
	
	var tools = ["Chainsaw", "Handsaw", "Vacuum"]
	for t in tools:
		var btn = Button.new()
		btn.text = t
		btn.focus_mode = Control.FOCUS_NONE
		btn.custom_minimum_size = Vector2(80, 40)
		btn.pressed.connect(func():
			play_procedural_sound("click")
			select_tool(t)
		)
		tool_box.add_child(btn)
		

	var action_box = VBoxContainer.new()
	left_col.add_child(action_box)
	
	var regen_btn = Button.new()
	regen_btn.text = "Regenerate Tree"
	regen_btn.focus_mode = Control.FOCUS_NONE
	regen_btn.pressed.connect(func():
		play_procedural_sound("click")
		regenerate_current_tree()
	)
	action_box.add_child(regen_btn)
	

	var spacer = Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left_col.add_child(spacer)
	

	var legend_panel = PanelContainer.new()
	var leg_vbox = VBoxContainer.new()
	legend_panel.add_child(leg_vbox)
	left_col.add_child(legend_panel)
	
	var leg_title = Label.new()
	leg_title.text = "HOW TO PLAY:"
	leg_title.add_theme_font_size_override("font_size", 12)
	leg_vbox.add_child(leg_title)
	
	var leg_text = Label.new()
	leg_text.text = "- Click branch to cut\n- Vacuum grabs cut wood\n- Drop branches in Chipper!\n- Move: W/A/S/D + Left/Right\n- Zoom: Scroll Wheel"
	leg_text.add_theme_font_size_override("font_size", 11)
	leg_vbox.add_child(leg_text)
	

	var right_col = VBoxContainer.new()
	right_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_col.alignment = BoxContainer.ALIGNMENT_BEGIN
	right_col.mouse_filter = Control.MOUSE_FILTER_PASS
	main_box.add_child(right_col)
	

	var status_bar = HBoxContainer.new()
	status_bar.alignment = BoxContainer.ALIGNMENT_END
	status_bar.mouse_filter = Control.MOUSE_FILTER_PASS
	right_col.add_child(status_bar)
	
	score_label = Label.new()
	score_label.text = "Score: 0"
	score_label.add_theme_font_size_override("font_size", 22)
	score_label.add_theme_color_override("font_color", Color.GREEN_YELLOW)
	score_label.custom_minimum_size = Vector2(180, 0)
	status_bar.add_child(score_label)
	
	accuracy_label = Label.new()
	accuracy_label.text = ""
	accuracy_label.add_theme_font_size_override("font_size", 22)
	accuracy_label.add_theme_color_override("font_color", Color.CYAN)
	accuracy_label.custom_minimum_size = Vector2(250, 0)
	status_bar.add_child(accuracy_label)
	

	var instr_panel = PanelContainer.new()
	instr_panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	instr_panel.offset_top = 20
	right_col.add_child(instr_panel)
	
	info_label = Label.new()
	info_label.text = "Trim excess branches outside the hologram shape!"
	info_label.add_theme_font_size_override("font_size", 16)
	info_label.horizontal_alignment = HorizontalAlignment.HORIZONTAL_ALIGNMENT_CENTER
	instr_panel.add_child(info_label)
	

	victory_panel = PanelContainer.new()
	victory_panel.visible = false
	victory_panel.set_anchors_preset(Control.PRESET_CENTER)
	victory_panel.custom_minimum_size = Vector2(400, 200)
	canvas_layer.add_child(victory_panel)
	
	var vic_vbox = VBoxContainer.new()
	vic_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vic_vbox.add_theme_constant_override("separation", 20)
	victory_panel.add_child(vic_vbox)
	
	victory_label = Label.new()
	victory_label.text = "LEVEL COMPLETED!\n\u2b50 Perfect Pruning \u2b50"
	victory_label.add_theme_font_size_override("font_size", 24)
	victory_label.horizontal_alignment = HorizontalAlignment.HORIZONTAL_ALIGNMENT_CENTER
	vic_vbox.add_child(victory_label)
	
	var next_btn = Button.new()
	next_btn.text = "Proceed to Next Level"
	next_btn.custom_minimum_size = Vector2(200, 50)
	next_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	next_btn.focus_mode = Control.FOCUS_NONE
	next_btn.pressed.connect(func():
		play_procedural_sound("click")
		victory_panel.visible = false
		if current_level < 4:
			select_level(current_level + 1)
		else:
			select_level(1)
	)
	vic_vbox.add_child(next_btn)

func select_tool(tool_name: String) -> void:
	active_tool = tool_name
	

	var tool_box = canvas_layer.get_node_or_null("HBoxContainer/VBoxContainer/ToolBox")
	if tool_box:
		for child in tool_box.get_children():
			if child is Button:
				if child.text == tool_name:
					child.add_theme_color_override("font_color", Color.YELLOW)
				else:
					child.remove_theme_color_override("font_color")

func select_level(level_idx: int) -> void:
	current_level = level_idx
	level_completed = false
	victory_panel.visible = false
	

	score = 0
	pruned_deadwood = 0
	healthy_cut = 0
	cut_branches.clear()
	
	match level_idx:
		1:
			current_mode = Mode.SILHOUETTE
			hologram_shape = "Sphere"
			hologram_size = 3.2
			hologram_center = Vector3(0, 3.5, 0)
			level_title_label.text = "Level 1: Sphere Match"
			info_label.text = "Goal: Trim branches outside the holographic Sphere! (>90% accuracy)"
		2:
			current_mode = Mode.SILHOUETTE
			hologram_shape = "Cube"
			hologram_size = 4.5
			hologram_center = Vector3(0, 3.5, 0)
			level_title_label.text = "Level 2: Cube Match"
			info_label.text = "Goal: Trim branches outside the holographic Cube! (>90% accuracy)"
		3:
			current_mode = Mode.DEADWOOD
			level_title_label.text = "Level 3: Deadwood Pruning"
			info_label.text = "Goal: Cut all dark brown diseased branches. DO NOT cut healthy green ones!"
		4:
			current_mode = Mode.SANDBOX
			level_title_label.text = "Creative Sandbox"
			info_label.text = "Sandbox Play: Customize the parameters and prune to your heart's content!"
			

	select_tool("Chainsaw")
	

	regenerate_current_tree()

func regenerate_current_tree() -> void:
	if not tree_generator:
		return
		

	if current_level == 1:
		tree_generator.rule_X = "F-[[X]+X]+F[+FX]-X"
		tree_generator.iterations = 4
		tree_generator.segment_length = 0.7
	elif current_level == 2:
		tree_generator.rule_X = "F-[[X]+X]+F[+FX]-X"
		tree_generator.iterations = 4
		tree_generator.segment_length = 0.8
	elif current_level == 3:

		tree_generator.rule_X = "F-[[X]+X]+F[+FX]-X"
		tree_generator.iterations = 4
		tree_generator.segment_length = 0.75
		

	tree_generator.regenerate_tree(tree_generator.seed)
	

	await get_tree().process_frame
	await get_tree().process_frame
	

	_initialize_level_branches()
	update_hud()

func _initialize_level_branches() -> void:
	if not tree_generator:
		return
		
	original_branch_states.clear()
	total_branches_at_start = tree_generator.branches.size()
	

	if current_mode == Mode.SILHOUETTE:
		hologram_mesh_instance.visible = true
		if hologram_shape == "Sphere":
			var mesh = SphereMesh.new()
			mesh.radius = hologram_size
			mesh.height = hologram_size * 2.0
			hologram_mesh_instance.mesh = mesh
		else:
			var mesh = BoxMesh.new()
			mesh.size = Vector3(hologram_size, hologram_size, hologram_size)
			hologram_mesh_instance.mesh = mesh
		hologram_mesh_instance.global_position = hologram_center
	else:
		hologram_mesh_instance.visible = false
		

	var is_deadwood_level = (current_mode == Mode.DEADWOOD)
	total_deadwood = 0
	
	var index = 0
	for b in tree_generator.branches:
		var anchor: StaticBody3D = b.anchor
		var tip: RigidBody3D = b.tip
		
		if not is_instance_valid(tip) or not is_instance_valid(anchor):
			continue
			


		tip.collision_layer = 2

		anchor.collision_layer = 2
		

		tip.set_meta("is_branch_tip", true)
		tip.set_meta("branch_ref", b)
		
		var tip_pos = tip.global_position
		var inside = is_point_inside_hologram(tip_pos)
		
		var deadwood = false
		if is_deadwood_level:

			var parent_height = tip_pos.y

			if parent_height > 1.5 and tree_generator.rng.randf() < 0.35:
				deadwood = true
				total_deadwood += 1
				
		tip.set_meta("is_deadwood", deadwood)
		tip.set_meta("was_cut", false)
		

		if deadwood:
			var dead_mat = StandardMaterial3D.new()
			dead_mat.albedo_color = Color(0.4, 0.28, 0.2)
			dead_mat.roughness = 0.95
			for child in tip.get_children():
				if child is MeshInstance3D:
					child.material_override = dead_mat
					
		original_branch_states.append({
			"tip_pos": tip_pos,
			"is_inside": inside,
			"is_deadwood": deadwood,
			"ref": b
		})
		
		index += 1
		
	print("GameController initialized %d branches. Deadwood branches: %d" % [original_branch_states.size(), total_deadwood])

func is_point_inside_hologram(p: Vector3) -> bool:
	if current_mode != Mode.SILHOUETTE:
		return false
		
	var local_p = p - hologram_center
	if hologram_shape == "Sphere":
		return local_p.length() <= hologram_size
	else:
		var hs = hologram_size * 0.5
		return abs(local_p.x) <= hs and abs(local_p.y) <= hs and abs(local_p.z) <= hs

func calculate_accuracy() -> float:
	if total_branches_at_start == 0:
		return 100.0
		




	var tp = 0
	var fp = 0
	var fn = 0
	var tn = 0
	
	for state in original_branch_states:
		var ref = state.ref
		var tip = ref.tip
		var originally_inside = state.is_inside
		
		var is_cut = true
		if is_instance_valid(tip) and not tip.get_meta("was_cut", false):
			is_cut = false
			
		if not is_cut:
			if originally_inside:
				tp += 1
			else:
				fp += 1
		else:
			if originally_inside:
				fn += 1
			else:
				tn += 1
				
	var acc = float(tp + tn) / float(total_branches_at_start) * 100.0
	return clamp(acc, 0.0, 100.0)

func _handle_mouse_action() -> void:
	if level_completed:
		return
		
	var mouse_pos = get_viewport().get_mouse_position()
	var camera = get_viewport().get_camera_3d()
	if not camera:
		return
		
	var from = camera.project_ray_origin(mouse_pos)
	var to = from + camera.project_ray_normal(mouse_pos) * 150.0
	
	var space_state = camera.get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(from, to)
	

	if active_tool == "Vacuum":

		query.collision_mask = 1
	else:

		query.collision_mask = 2
		
	query.collide_with_areas = false
	query.collide_with_bodies = true
	
	var result = space_state.intersect_ray(query)
	if result:
		var hit_body = result.collider
		if hit_body is RigidBody3D and hit_body.get_meta("is_branch_tip", false):
			if active_tool == "Vacuum":
				_vacuum_branch(hit_body)
			else:

				if not hit_body.get_meta("was_cut", false):
					_cut_branch_physically(hit_body)

func _cut_branch_physically(tip: RigidBody3D) -> void:
	if not is_instance_valid(tip):
		return
		
	tip.set_meta("was_cut", true)
	

	var parent = tip.get_parent()
	if is_instance_valid(parent):
		for child in parent.get_children():
			if child is Joint3D:
				child.queue_free()
				

	tip.gravity_scale = 1.0
	tip.collision_layer = 1
	tip.collision_mask = 1
	

	var push_dir = (tip.global_position - global_position).normalized()
	if push_dir.length() < 0.1:
		push_dir = Vector3.UP
	
	var multiplier = 2.5 if active_tool == "Chainsaw" else 1.0
	tip.apply_impulse((push_dir * 1.5 + Vector3(
		tree_generator.rng.randf_range(-0.5, 0.5),
		tree_generator.rng.randf_range(-0.2, 0.5),
		tree_generator.rng.randf_range(-0.5, 0.5)
	)) * multiplier)
	

	var is_deadwood = tip.get_meta("is_deadwood", false)
	cut_branches[tip.get_instance_id()] = true
	
	if current_mode == Mode.DEADWOOD:
		if is_deadwood:
			pruned_deadwood += 1
			score += 100
			play_procedural_sound("victory")
			spawn_particles(tip.global_position, Color(0.45, 0.35, 0.25))
		else:
			healthy_cut += 1
			score -= 50
			play_procedural_sound("penalty")
			spawn_particles(tip.global_position, Color(0.2, 0.75, 0.2))
	else:

		score += 20
		play_procedural_sound("cut")
		var leaf_color = Color(0.25, 0.65, 0.25)
		if is_deadwood:
			leaf_color = Color(0.4, 0.3, 0.2)
		spawn_particles(tip.global_position, leaf_color)
		
	update_hud()
	

	set_process(false)
	await get_tree().create_timer(0.12).timeout
	set_process(true)
	
	if current_mode == Mode.DEADWOOD:
		check_victory_condition()

func _vacuum_branch(tip: RigidBody3D) -> void:
	if not is_instance_valid(tip) or tip.get_meta("is_vacuuming", false):
		return
		
	tip.set_meta("is_vacuuming", true)
	tip.freeze = true
	
	play_procedural_sound("cut")
	

	var tween = create_tween()
	var target = Vector3(4.5, 1.2, 0.0)
	
	tween.tween_property(tip, "global_position", target, 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.parallel().tween_property(tip, "scale", Vector3.ZERO, 0.45)
	
	tween.finished.connect(func():
		_shred_branch_event(tip)
	)

func _on_hopper_body_entered(body: Node3D) -> void:
	if not is_instance_valid(body):
		return
		

	var tip: RigidBody3D = null
	if body is RigidBody3D and body.get_meta("is_branch_tip", false):
		tip = body
	elif body.get_parent() is RigidBody3D and body.get_parent().get_meta("is_branch_tip", false):
		tip = body.get_parent()
		
	if tip and not tip.get_meta("is_vacuuming", false):

		_shred_branch_event(tip)

func _shred_branch_event(tip: RigidBody3D) -> void:
	if not is_instance_valid(tip):
		return
		
	var is_deadwood = tip.get_meta("is_deadwood", false)
	

	if current_mode == Mode.DEADWOOD:
		if is_deadwood:
			score += 150
			play_procedural_sound("victory")
		else:
			score -= 100
			play_procedural_sound("penalty")
	else:
		score += 50
		play_procedural_sound("shred")
		

	var p_color = Color(0.4, 0.28, 0.18)
	if not is_deadwood:
		p_color = Color(0.18, 0.52, 0.18)
	spawn_particles(Vector3(4.5, 1.2, 0.0), p_color)
	

	var parent = tip.get_parent()
	if is_instance_valid(parent):
		parent.queue_free()
	else:
		tip.queue_free()
		
	update_hud()
	
	if current_mode == Mode.DEADWOOD:
		check_victory_condition()

func check_victory_condition() -> void:
	if level_completed:
		return
		
	if current_mode == Mode.DEADWOOD:

		if pruned_deadwood >= total_deadwood and total_deadwood > 0:
			if healthy_cut <= 3:
				complete_level()
			else:
				info_label.text = "You pruned the deadwood, but cut too many green branches (%d)! Restarting..." % healthy_cut
				play_procedural_sound("penalty")
				await get_tree().create_timer(3.0).timeout
				select_level(current_level)

func complete_level() -> void:
	level_completed = true
	victory_panel.visible = true
	
	if current_mode == Mode.SILHOUETTE:
		victory_label.text = "LEVEL COMPLETED!\nAccuracy: %.1f%%\n\u2b50 Perfect Topiary! \u2b50" % calculate_accuracy()
	else:
		victory_label.text = "LEVEL COMPLETED!\nScore: %d\nDiseased Pruned: %d/%d\n\u2b50 Forest Master! \u2b50" % [score, pruned_deadwood, total_deadwood]
		
	play_procedural_sound("victory")
	

	for i in range(5):
		await get_tree().create_timer(0.2).timeout
		var spark_pos = Vector3(
			tree_generator.rng.randf_range(-2.0, 2.0),
			tree_generator.rng.randf_range(2.0, 6.0),
			tree_generator.rng.randf_range(-2.0, 2.0)
		)
		spawn_particles(spark_pos, Color(1.0, 0.85, 0.2))

func update_hud() -> void:
	score_label.text = "Score: %d" % score
	
	if current_mode == Mode.SILHOUETTE:
		accuracy_label.text = "Match Accuracy: %.1f%%" % calculate_accuracy()
	elif current_mode == Mode.DEADWOOD:
		accuracy_label.text = "Deadwood: %d/%d | Cut Healthy: %d" % [pruned_deadwood, total_deadwood, healthy_cut]
	else:
		accuracy_label.text = "Sandbox Mode"


func spawn_particles(pos: Vector3, color: Color) -> void:
	var particles = CPUParticles3D.new()

	get_parent().add_child(particles)
	particles.global_position = pos
	
	particles.amount = 20
	particles.lifetime = 0.5
	particles.one_shot = true
	particles.explosiveness = 0.95
	particles.direction = Vector3.UP
	particles.spread = 75.0
	particles.gravity = Vector3(0, -9.8, 0)
	particles.initial_velocity_min = 3.0
	particles.initial_velocity_max = 6.0
	

	var mat = StandardMaterial3D.new()
	mat.albedo_color = color
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	
	var mesh = BoxMesh.new()
	mesh.size = Vector3(0.1, 0.1, 0.1)
	mesh.material = mat
	
	particles.mesh = mesh
	particles.emitting = true
	
	var timer = get_tree().create_timer(1.0)
	timer.timeout.connect(func(): particles.queue_free())


func play_procedural_sound(sound_type: String) -> void:
	var stream = AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = 22050
	
	var duration = 0.25
	if sound_type == "victory":
		duration = 1.2
	elif sound_type == "penalty":
		duration = 0.6
	elif sound_type == "shred":
		duration = 0.5
		
	var num_samples = int(stream.mix_rate * duration)
	var data = PackedByteArray()
	data.resize(num_samples * 2)
	
	for i in range(num_samples):
		var t = float(i) / stream.mix_rate
		var val = 0.0
		
		match sound_type:
			"cut":

				var freq = lerp(880.0, 220.0, t / duration)
				val = sin(2.0 * PI * freq * t) * exp(-10.0 * t)
			"shred":

				val = (randf() * 2.0 - 1.0) * exp(-4.0 * t)
				var low_rumble = sin(2.0 * PI * 80.0 * t)
				val = (val + low_rumble * 0.4) * exp(-2.0 * t)
			"victory":

				var note_idx = int(t / 0.15)
				var notes = [261.63, 329.63, 392.00, 523.25, 659.25, 783.99, 1046.50]
				var freq = notes[clamp(note_idx, 0, notes.size() - 1)]
				var local_t = fmod(t, 0.15)
				val = sin(2.0 * PI * freq * local_t) * exp(-3.0 * local_t)
			"penalty":

				var freq = lerp(180.0, 90.0, t / duration)
				val = (1.0 if sin(2.0 * PI * freq * t) > 0.0 else -1.0) * 0.5 * exp(-3.0 * t)
			"click":

				val = sin(2.0 * PI * 1200.0 * t) * exp(-60.0 * t)
				
		var sample = int(clamp(val, -1.0, 1.0) * 32767)
		data.encode_s16(i * 2, sample)
		
	stream.data = data
	
	var player = AudioStreamPlayer.new()
	add_child(player)
	player.stream = stream
	player.play()
	player.finished.connect(func(): player.queue_free())
