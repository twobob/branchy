extends Node3D



var score := 0
var score_label: Label
var tree_gen: TreeGenerator3D
var camera: Camera3D


var leaf_mesh: BoxMesh
var sawdust_mesh: BoxMesh
var spark_mesh: BoxMesh


var saw_instance: Node3D
var saw_timer := 0.0


var grinding_branches: Dictionary = {}
var chipper_center := Vector3(4.0, 1.2, 2.0)
func _ready():
	print("Main game coordinator loaded.")
	
	tree_gen = get_node_or_null("TreeGenerator3D")
	camera = get_node_or_null("Camera3D")
	
	pass
	
	setup_ground_plane()
	setup_wood_chipper()
	pass #gui
	pass #vfx


func setup_ground_plane():
	var ground = StaticBody3D.new()
	ground.name = "GroundPlane"
	ground.collision_layer = 1
	ground.collision_mask = 1
	add_child(ground)
	

	var grass_mat = StandardMaterial3D.new()
	grass_mat.albedo_color = Color(0.15, 0.32, 0.12)
	grass_mat.roughness = 0.9
	

	var ground_mesh = MeshInstance3D.new()
	var plane_mesh = PlaneMesh.new()
	plane_mesh.size = Vector2(250, 250)
	ground_mesh.mesh = plane_mesh
	ground_mesh.material_override = grass_mat
	ground.add_child(ground_mesh)
	

	var ground_col = CollisionShape3D.new()
	var box_shape = BoxShape3D.new()
	box_shape.size = Vector3(250, 2.0, 250)
	ground_col.shape = box_shape
	ground_col.position = Vector3(0, -1.0, 0)
	ground.add_child(ground_col)
	print("Ground plane set up successfully.")

func setup_wood_chipper():

	var chipper_mesh = load("res://assets/wood_chipper.obj")
	if not chipper_mesh:
		printerr("Failed to load assets/wood_chipper.obj")
		return
		
	var chipper_mi = MeshInstance3D.new()
	chipper_mi.name = "WoodChipperMesh"
	chipper_mi.mesh = chipper_mesh
	

	chipper_mi.scale = Vector3(0.0008, 0.0008, 0.0008)
	chipper_mi.rotation_degrees = Vector3(-90, 0, 0)
	chipper_mi.position = Vector3(4.0, 0.0, 2.0)
	add_child(chipper_mi)
	

	chipper_mi.create_trimesh_collision()
	

	for child in chipper_mi.get_children():
		if child is StaticBody3D:
			child.name = "WoodChipperCollision"
			child.collision_layer = 1
			child.collision_mask = 1
			

	var area = Area3D.new()
	area.name = "SuctionArea"

	area.collision_layer = 0
	area.collision_mask = 8
	add_child(area)
	

	area.global_position = chipper_center
	
	var col = CollisionShape3D.new()
	var box = BoxShape3D.new()
	box.size = Vector3(1.5, 1.5, 1.5)
	col.shape = box
	area.add_child(col)
	

	area.body_entered.connect(_on_suction_body_entered)
	area.body_exited.connect(_on_suction_body_exited)
	
	print("Wood chipper and suction area set up successfully.")

func setup_gui():
	var canvas = camera.get_node_or_null("CanvasLayer")
	if not canvas:
		canvas = CanvasLayer.new()
		canvas.name = "CanvasLayer"
		camera.add_child(canvas)
		
	score_label = Label.new()
	score_label.name = "ScoreLabel"
	score_label.text = "SCORE: 0"
	score_label.add_theme_color_override("font_color", Color.WHITE)
	score_label.add_theme_font_size_override("font_size", 32)
	score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	

	score_label.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	score_label.position = Vector2(-220, 180)
	canvas.add_child(score_label)

func setup_vfx_assets():

	leaf_mesh = BoxMesh.new()
	leaf_mesh.size = Vector3(0.08, 0.08, 0.08)
	
	sawdust_mesh = BoxMesh.new()
	sawdust_mesh.size = Vector3(0.05, 0.05, 0.05)
	
	spark_mesh = BoxMesh.new()
	spark_mesh.size = Vector3(0.02, 0.02, 0.02)
	

	var saw_scene = load("res://assets/mini_sierra.glb")
	if saw_scene:
		saw_instance = saw_scene.instantiate()
		saw_instance.visible = false
		saw_instance.scale = Vector3(0.2, 0.2, 0.2)
		add_child(saw_instance)

func add_score(points: int):
	score += points
	if score_label:
		score_label.text = "SCORE: %d" % score

func spawn_particles(type: String, pos: Vector3, dir: Vector3 = Vector3.UP):
	var p = CPUParticles3D.new()
	p.position = pos
	p.one_shot = true
	p.emitting = true
	
	var mat = StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	
	match type:
		"leaf":
			p.amount = 25
			p.lifetime = 0.8
			p.explosiveness = 1.0
			p.direction = dir
			p.spread = 75.0
			p.initial_velocity_min = 2.0
			p.initial_velocity_max = 5.0
			p.gravity = Vector3(0, -6, 0)
			p.mesh = leaf_mesh
			mat.albedo_color = Color(0.2, 0.65, 0.15)
			
		"sawdust":
			p.amount = 20
			p.lifetime = 0.7
			p.explosiveness = 0.8
			p.direction = dir
			p.spread = 90.0
			p.initial_velocity_min = 1.5
			p.initial_velocity_max = 4.0
			p.gravity = Vector3(0, -4, 0)
			p.mesh = sawdust_mesh
			mat.albedo_color = Color(0.76, 0.62, 0.44)
			
		"spark":
			p.amount = 35
			p.lifetime = 0.4
			p.explosiveness = 1.0
			p.direction = dir
			p.spread = 50.0
			p.initial_velocity_min = 3.0
			p.initial_velocity_max = 7.0
			p.gravity = Vector3(0, -8, 0)
			p.mesh = spark_mesh
			mat.albedo_color = Color(1.0, 0.85, 0.1)
			
	p.material_override = mat
	add_child(p)
	

	get_tree().create_timer(p.lifetime + 0.1).timeout.connect(p.queue_free)

func _on_suction_body_entered(body: Node):
	if body is RigidBody3D and not grinding_branches.has(body):
		grinding_branches[body] = 0.5
		print("Branch entered chipper: ", body.name)

func _on_suction_body_exited(body: Node):
	if grinding_branches.has(body):
		grinding_branches.erase(body)

func _physics_process(delta: float):

	var finished_grinds = []
	
	for body in grinding_branches.keys():
		if not is_instance_valid(body) or body.is_queued_for_deletion():
			finished_grinds.append(body)
			continue
			

		var to_center = chipper_center - body.global_position
		var dir = to_center.normalized()
		var dist = to_center.length()
		
		var pull_force = dir * 25.0

		pull_force.y -= 15.0
		body.apply_central_force(pull_force)
		

		body.scale = body.scale.lerp(Vector3.ZERO, delta * 8.0)
		body.rotate(Vector3.UP, delta * 30.0)
		

		if Engine.get_physics_frames() % 5 == 0:
			spawn_particles("sawdust", body.global_position, Vector3.UP)
			

		grinding_branches[body] -= delta
		if grinding_branches[body] <= 0.0:
			finished_grinds.append(body)
			
	for body in finished_grinds:
		if is_instance_valid(body) and not body.is_queued_for_deletion():
			grinding_branches.erase(body)
			add_score(10)
			spawn_particles("sawdust", chipper_center, Vector3.UP)
			spawn_particles("spark", chipper_center, Vector3.UP)
			var asp = get_node_or_null("GrindSound")
			if asp and asp is AudioStreamPlayer3D:
				asp.play()
			body.queue_free()
			print("Branch grinded! Score: ", score)

func _process(delta: float):
	if saw_instance and saw_instance.visible:
		saw_timer -= delta
		if saw_timer <= 0.0:
			saw_instance.visible = false
			

	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		var focus_owner = get_viewport().gui_get_focus_owner()
		if focus_owner and focus_owner is LineEdit:
			return
			
		if camera:
			var mouse_pos = get_viewport().get_mouse_position()
			if mouse_pos.x < 330 and mouse_pos.y < 650:
				return
				
			var origin = camera.project_ray_origin(mouse_pos)
			var end = origin + camera.project_ray_normal(mouse_pos) * 1000.0
			
			var space_state = get_world_3d().direct_space_state
			var query = PhysicsRayQueryParameters3D.create(origin, end)
			query.collision_mask = 2
			
			var result = space_state.intersect_ray(query)
			if result:
				var hit_collider = result.collider
				if hit_collider is RigidBody3D and tree_gen:
					var hit_pos = result.position
					var hit_normal = result.normal
					
					spawn_particles("spark", hit_pos, hit_normal)
					spawn_particles("sawdust", hit_pos, hit_normal)
					
					if hit_pos.y > 1.5:
						spawn_particles("leaf", hit_pos, hit_normal)
						
					if saw_instance:
						saw_instance.global_position = hit_pos
						saw_instance.look_at(hit_pos + hit_normal, Vector3.UP)
						saw_instance.rotate_object_local(Vector3.UP, PI/2.0)
						saw_instance.visible = true
						saw_timer = 0.15
						
					tree_gen.sever_branch(hit_collider, hit_pos, hit_normal)
