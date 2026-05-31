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


func select_tool(tool_name: String) -> void:
	active_tool = tool_name
	if camera_controller and camera_controller.has_method("select_tool"):
		camera_controller.select_tool(tool_name)

func _setup_wood_chipper() -> void:
	pass

func _setup_hud() -> void:
	canvas_layer = CanvasLayer.new()
	add_child(canvas_layer)
	
	victory_panel = PanelContainer.new()
	victory_panel.name = "VictoryPanel"
	victory_panel.visible = false
	victory_panel.set_anchors_preset(Control.PRESET_CENTER)
	victory_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	victory_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	victory_panel.position = Vector2(-200, -100)
	victory_panel.custom_minimum_size = Vector2(400, 200)
	
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.08, 0.1, 0.88)
	style.border_color = Color(1.0, 1.0, 1.0, 0.15)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.corner_radius_top_left = 16
	style.corner_radius_top_right = 16
	style.corner_radius_bottom_left = 16
	style.corner_radius_bottom_right = 16
	victory_panel.add_theme_stylebox_override("panel", style)
	
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_bottom", 20)
	victory_panel.add_child(margin)
	
	var vbox = VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	margin.add_child(vbox)
	
	victory_label = Label.new()
	victory_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	victory_label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.95, 1.0))
	victory_label.add_theme_font_size_override("font_size", 18)
	vbox.add_child(victory_label)
	
	canvas_layer.add_child(victory_panel)
	
	level_title_label = Label.new()
	info_label = Label.new()
	accuracy_label = Label.new()
	score_label = Label.new()

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
			

	if camera_controller and camera_controller.has_method("select_tool"):
		camera_controller.select_tool("Chainsaw")
	else:
		active_tool = "Chainsaw"
	

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
		var body = b.get("body")
		if not body or not is_instance_valid(body):
			continue
			


		body.collision_layer = 2
		

		body.set_meta("is_branch_tip", true)
		body.set_meta("branch_ref", b)
		
		var tip_pos = body.global_position
		var inside = is_point_inside_hologram(tip_pos)
		
		var deadwood = false
		if is_deadwood_level:

			var parent_height = tip_pos.y

			if parent_height > 1.5 and tree_generator.rng.randf() < 0.35:
				deadwood = true
				total_deadwood += 1
				
		body.set_meta("is_deadwood", deadwood)
		body.set_meta("was_cut", false)
		

		if deadwood:
			var dead_mat = StandardMaterial3D.new()
			dead_mat.albedo_color = Color(0.4, 0.28, 0.2)
			dead_mat.roughness = 0.95
			for child in body.get_children():
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
		var tip = ref.get("body")
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
	print("[GC] _handle_mouse_action called, tool=", active_tool)
	if level_completed:
		return
		
	var mouse_pos = get_viewport().get_mouse_position()
	if get_viewport().gui_get_hovered_control():
		return
		
	var camera = get_viewport().get_camera_3d()
	if not camera:
		return
		
	var offsets = [Vector2.ZERO]
	if active_tool == "Chainsaw":
		offsets = [
			Vector2.ZERO,
			Vector2(-20, 0), Vector2(20, 0),
			Vector2(0, -20), Vector2(0, 20),
			Vector2(-15, -15), Vector2(15, -15),
			Vector2(-15, 15), Vector2(15, 15)
		]
	elif active_tool == "Mini-Saw":
		offsets = [
			Vector2.ZERO,
			Vector2(-10, 0), Vector2(10, 0),
			Vector2(0, -10), Vector2(0, 10)
		]
		
	var space_state = camera.get_world_3d().direct_space_state
	
	for offset in offsets:
		var sampled_pos = mouse_pos + offset
		var from = camera.project_ray_origin(sampled_pos)
		var to = from + camera.project_ray_normal(sampled_pos) * 150.0
		
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
			var ray_dist = camera.global_position.distance_to(result.position)
			if ray_dist > 2.5:
				continue
			if (hit_body is RigidBody3D or hit_body is StaticBody3D) and hit_body.get_meta("is_branch_tip", false):
				if active_tool == "Vacuum":
					_vacuum_branch(hit_body)
					break
				else:
					if not hit_body.get_meta("was_cut", false):
						_cut_branch_physically(hit_body)

func _cut_branch_physically(hit_body: CollisionObject3D) -> void:
	if not is_instance_valid(hit_body):
		return
	
	hit_body.set_meta("was_cut", true)
	
	# Delegate cutting to TreeGenerator3D
	if tree_generator:
		tree_generator.sever_branch(hit_body, hit_body.global_position, Vector3.UP)
	
	var is_deadwood = hit_body.get_meta("is_deadwood", false)
	cut_branches[hit_body.get_instance_id()] = true
	
	if current_mode == Mode.DEADWOOD:
		if is_deadwood:
			pruned_deadwood += 1
			score += 100
			play_procedural_sound("victory")
			spawn_particles(hit_body.global_position, Color(0.45, 0.35, 0.25))
		else:
			healthy_cut += 1
			score -= 50
			play_procedural_sound("penalty")
			spawn_particles(hit_body.global_position, Color(0.2, 0.75, 0.2))
	else:

		score += 20
		play_procedural_sound("cut")
		var leaf_color = Color(0.25, 0.65, 0.25)
		if is_deadwood:
			leaf_color = Color(0.4, 0.3, 0.2)
		spawn_particles(hit_body.global_position, leaf_color)
		
	update_hud()
	

	set_process(false)
	await get_tree().create_timer(0.12).timeout
	set_process(true)
	
	if current_mode == Mode.DEADWOOD:
		check_victory_condition()

func _vacuum_branch(tip: CollisionObject3D) -> void:
	if not is_instance_valid(tip) or tip.get_meta("is_vacuuming", false):
		return
		
	tip.set_meta("is_vacuuming", true)
	if tip is RigidBody3D:
		tip.freeze = true
	
	play_procedural_sound("cut")
	

	var tween = create_tween()
	var target = Vector3(4.0, 1.2, 2.0)
	
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

func _shred_branch_event(tip: Node3D) -> void:
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
	spawn_particles(Vector3(4.0, 1.2, 2.0), p_color)
	

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
		victory_label.text = "LEVEL COMPLETED!\nAccuracy: %.1f%%\n>>> Perfect Topiary! <<<" % calculate_accuracy()
	else:
		victory_label.text = "LEVEL COMPLETED!\nScore: %d\nDiseased Pruned: %d/%d\n>>> Forest Master! <<<" % [score, pruned_deadwood, total_deadwood]
		
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
	if is_instance_valid(camera_controller):
		camera_controller.score = score
		camera_controller.level = current_level
		if current_mode == Mode.SILHOUETTE:
			camera_controller.mode = "Topiary Master"
			camera_controller.accuracy = calculate_accuracy()
		elif current_mode == Mode.DEADWOOD:
			camera_controller.mode = "Zen Garden"
			if total_deadwood > 0:
				camera_controller.accuracy = float(pruned_deadwood) / total_deadwood * 100.0
			else:
				camera_controller.accuracy = 100.0
		else:
			camera_controller.mode = "Creative Sandbox"
			camera_controller.accuracy = 0.0
		if camera_controller.has_method("refresh_hud"):
			camera_controller.refresh_hud()


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
