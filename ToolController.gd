extends Node3D

var active_tool_name: String = "none"
var tool_holder: Node3D = null
var current_model: Node3D = null
var chainsaw_scene = null
var mini_sierra_scene = null
var cutting_area: Area3D = null
var cutting_shape: CollisionShape3D = null

var rest_local_pos: Vector3 = Vector3(0.18, -0.22, -0.45)
var rest_local_rot: Vector3 = Vector3(-0.1, 0.25, 0.05)

var chainsaw_material_duplicated: bool = false
var chainsaw_material_override: StandardMaterial3D = null

func _ready() -> void:
	chainsaw_scene = load("res://assets/chainsaw.glb")
	mini_sierra_scene = load("res://assets/mini_sierra.glb")
	
	tool_holder = Node3D.new()
	add_child(tool_holder)
	
	tool_holder.position = rest_local_pos
	tool_holder.rotation = rest_local_rot
	
	cutting_area = Area3D.new()
	cutting_area.collision_layer = 0
	cutting_area.collision_mask = 2
	add_child(cutting_area)
	
	cutting_shape = CollisionShape3D.new()
	var sphere = SphereShape3D.new()
	sphere.radius = 0.55
	cutting_shape.shape = sphere
	cutting_area.add_child(cutting_shape)
	cutting_area.position = Vector3(0, 0, -1.8)

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
			current_model.scale = Vector3(0.55, 0.55, 0.55)
			current_model.rotation_degrees = Vector3(0, 180, 0)
			current_model.position = Vector3(0, 0, -0.2)
	elif active_tool_name == "mini_sierra" or active_tool_name == "mini-saw":
		if mini_sierra_scene:
			current_model = mini_sierra_scene.instantiate()
			tool_holder.add_child(current_model)
			current_model.scale = Vector3(0.45, 0.45, 0.45)
			current_model.rotation_degrees = Vector3(10, 45, 0)
			current_model.position = Vector3(0, 0, 0)
	elif active_tool_name == "shears" or active_tool_name == "pruning shears":
		current_model = MeshInstance3D.new()
		var mesh = BoxMesh.new()
		mesh.size = Vector3(0.04, 0.04, 0.25)
		current_model.mesh = mesh
		var mat = StandardMaterial3D.new()
		mat.albedo_color = Color(0.7, 0.7, 0.75)
		mat.metallic = 0.9
		mat.roughness = 0.15
		current_model.material_override = mat
		tool_holder.add_child(current_model)
		current_model.scale = Vector3(1.0, 1.0, 1.0)
		current_model.rotation_degrees = Vector3(15, -30, 0)
		current_model.position = Vector3(0, 0, 0)

func select_tool(tool_name: String) -> void:
	set_active_tool(tool_name)

func _process(delta: float) -> void:
	var is_cutting = Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	var time = Time.get_ticks_msec() / 1000.0
	
	var bob_y = sin(time * 2.2) * 0.01
	var bob_x = cos(time * 1.1) * 0.008
	
	var vib_x = 0.0
	var vib_y = 0.0
	var vib_z = 0.0
	if is_cutting and (active_tool_name == "chainsaw" or active_tool_name == "mini_sierra" or active_tool_name == "mini-saw"):
		vib_x = randf_range(-0.015, 0.015)
		vib_y = randf_range(-0.015, 0.015)
		vib_z = randf_range(-0.015, 0.015)
		
	var target_rot = rest_local_rot
	if is_cutting:
		if active_tool_name == "chainsaw":
			var swing = sin(time * 12.0) * 0.2
			target_rot = Vector3(rest_local_rot.x - swing * 0.2, rest_local_rot.y + swing, rest_local_rot.z + swing * 0.3)
		elif active_tool_name == "mini_sierra" or active_tool_name == "mini-saw":
			var swing = sin(time * 15.0) * 0.15
			target_rot = Vector3(rest_local_rot.x + swing * 0.4, rest_local_rot.y + swing, rest_local_rot.z)
		elif active_tool_name == "shears" or active_tool_name == "pruning shears":
			var swing = sin(time * 25.0) * 0.18
			target_rot = Vector3(rest_local_rot.x + swing, rest_local_rot.y, rest_local_rot.z)
			
	tool_holder.position = tool_holder.position.lerp(rest_local_pos + Vector3(bob_x + vib_x, bob_y + vib_y, vib_z), 8.0 * delta)
	tool_holder.rotation.x = lerp_angle(tool_holder.rotation.x, target_rot.x, 12.0 * delta)
	tool_holder.rotation.y = lerp_angle(tool_holder.rotation.y, target_rot.y, 12.0 * delta)
	tool_holder.rotation.z = lerp_angle(tool_holder.rotation.z, target_rot.z, 12.0 * delta)
	
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
				var offset_speed = 22.0 if is_cutting else 4.0
				chainsaw_material_override.uv1_offset += Vector3(offset_speed * delta, offset_speed * delta, 0.0)
				
	elif (active_tool_name == "mini_sierra" or active_tool_name == "mini-saw") and is_instance_valid(current_model):
		var blade = current_model.get_node_or_null("texture_pbr_v128")
		if blade:
			var spin_speed = 65.0 if is_cutting else 15.0
			blade.rotate_local_x(spin_speed * delta)
