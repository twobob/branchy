extends Node3D

var active_tool_name: String = "none"
var camera: Camera3D = null
var tool_holder: Node3D = null
var current_model: Node3D = null
var chainsaw_scene = null
var mini_sierra_scene = null
var cutting_area: Area3D = null
var cutting_shape: CollisionShape3D = null

var rest_local_pos: Vector3 = Vector3(0.28, -0.22, -0.6)
var rest_local_rot: Vector3 = Vector3(-0.1, 0.2, 0.0)

var sway_speed: float = 8.0
var prev_cam_transform: Transform3D

var chainsaw_material_duplicated: bool = false
var chainsaw_material_override: StandardMaterial3D = null

func _ready() -> void:
	chainsaw_scene = load("res://assets/chainsaw.glb")
	mini_sierra_scene = load("res://assets/mini_sierra.glb")
	
	tool_holder = Node3D.new()
	add_child(tool_holder)
	
	cutting_area = Area3D.new()
	cutting_area.collision_layer = 0
	cutting_area.collision_mask = 2
	add_child(cutting_area)
	
	cutting_shape = CollisionShape3D.new()
	var sphere = SphereShape3D.new()
	sphere.radius = 0.4
	cutting_shape.shape = sphere
	cutting_area.add_child(cutting_shape)
	
	camera = get_node_or_null("../Camera3D")
	if camera:
		prev_cam_transform = camera.global_transform
		global_transform = camera.global_transform

func set_active_tool(tool_name: String) -> void:
	active_tool_name = tool_name.to_lower()
	if is_instance_valid(current_model):
		current_model.queue_free()
		current_model = null
	
	chainsaw_material_duplicated = false
	chainsaw_material_override = null
	
	if active_tool_name == "chainsaw":
		if chainsaw_scene:
			current_model = chainsaw_scene.instantiate()
			tool_holder.add_child(current_model)
			current_model.scale = Vector3(1.0, 1.0, 1.0)
			current_model.rotation_degrees = Vector3(0, 180, 0)
			current_model.position = Vector3(0, 0, -0.41)
	elif active_tool_name == "mini_sierra" or active_tool_name == "mini-saw":
		if mini_sierra_scene:
			current_model = mini_sierra_scene.instantiate()
			tool_holder.add_child(current_model)
			current_model.scale = Vector3(1.0, 1.0, 1.0)
			current_model.rotation_degrees = Vector3(0, 0, 0)
			current_model.position = Vector3(0, 0, 0)
	elif active_tool_name == "shears" or active_tool_name == "pruning shears":
		current_model = MeshInstance3D.new()
		var mesh = BoxMesh.new()
		mesh.size = Vector3(0.05, 0.05, 0.3)
		current_model.mesh = mesh
		tool_holder.add_child(current_model)
		current_model.scale = Vector3(1.0, 1.0, 1.0)
		current_model.rotation_degrees = Vector3(0, 0, 0)
		current_model.position = Vector3(0, 0, 0)

func select_tool(tool_name: String) -> void:
	set_active_tool(tool_name)

func _process(delta: float) -> void:
	if not camera:
		camera = get_node_or_null("../Camera3D")
		if not camera:
			return
	
	var is_cutting = Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	
	var vibration = Vector3.ZERO
	if is_cutting and (active_tool_name == "chainsaw" or active_tool_name == "mini_sierra" or active_tool_name == "mini-saw"):
		vibration = Vector3(
			randf_range(-0.008, 0.008),
			randf_range(-0.008, 0.008),
			randf_range(-0.008, 0.008)
		)
	
	var target_local_pos = rest_local_pos + vibration
	var target_global_pos = camera.global_position + camera.global_basis * target_local_pos
	var target_global_quat = Quaternion(camera.global_basis * Basis.from_euler(rest_local_rot))
	
	global_position = global_position.lerp(target_global_pos, sway_speed * delta)
	global_transform.basis = Basis(Quaternion(global_transform.basis).slerp(target_global_quat, sway_speed * delta))
	
	cutting_area.global_position = camera.global_position - camera.global_basis.z * 1.0
	
	if active_tool_name == "chainsaw" and is_instance_valid(current_model):
		var mesh_inst = current_model.get_node_or_null("Armature/Skeleton3D/chainsaw") as MeshInstance3D
		if mesh_inst:
			if not chainsaw_material_duplicated:
				var mat = mesh_inst.get_active_material(0)
				if mat:
					chainsaw_material_override = mat.duplicate()
					mesh_inst.material_override = chainsaw_material_override
					chainsaw_material_duplicated = true
			if chainsaw_material_override:
				chainsaw_material_override.uv1_offset += Vector3(12.0 * delta, 12.0 * delta, 0.0)
	
	elif (active_tool_name == "mini_sierra" or active_tool_name == "mini-saw") and is_instance_valid(current_model):
		var blade = current_model.get_node_or_null("texture_pbr_v128")
		if blade:
			blade.rotate_local_x(35.0 * delta)

func _physics_process(delta: float) -> void:
	if not camera:
		return
	
	var is_cutting = Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	if not is_cutting:
		return
	
	if active_tool_name == "none" or active_tool_name == "hands":
		return
	
	var space_state = get_world_3d().direct_space_state
	var from = camera.global_position
	var to = from - camera.global_basis.z * 3.0
	var query = PhysicsRayQueryParameters3D.create(from, to)
	query.collision_mask = 2
	query.collide_with_bodies = true
	query.collide_with_areas = false
	var result = space_state.intersect_ray(query)
	if result:
		var hit_body = result.collider
		if hit_body is RigidBody3D:
			var tree_gen = get_node_or_null("../TreeGenerator3D")
			if tree_gen and tree_gen.has_method("sever_branch"):
				tree_gen.sever_branch(hit_body, result.position, result.normal)
	
	var overlapping = cutting_area.get_overlapping_bodies()
	for body in overlapping:
		if body is RigidBody3D:
			var tree_gen = get_node_or_null("../TreeGenerator3D")
			if tree_gen and tree_gen.has_method("sever_branch"):
				var hit_pos = body.global_position
				var hit_normal = (body.global_position - cutting_area.global_position).normalized()
				tree_gen.sever_branch(body, hit_pos, hit_normal)