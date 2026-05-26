extends Node3D

var active_tool_name: String = "none"
var tool_holder: Node3D = null
var current_model: Node3D = null
var chainsaw_scene = null
var mini_sierra_scene = null

var chainsaw_material_duplicated: bool = false
var chainsaw_material_override: StandardMaterial3D = null

var elbow_pos: Vector3 = Vector3(0.35, -0.35, -0.15)
var tool_length: float = 0.8

func _ready() -> void:
	chainsaw_scene = load("res://assets/chainsaw.glb")
	mini_sierra_scene = load("res://assets/mini_sierra.glb")

	tool_holder = Node3D.new()
	tool_holder.name = "ToolHolder"
	add_child(tool_holder)
	tool_holder.position = elbow_pos

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
			current_model.position = Vector3(0, 0, 0)
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
		current_model.rotation_degrees = Vector3(15, -30, 0)

func select_tool(tool_name: String) -> void:
	set_active_tool(tool_name)

func _process(delta: float) -> void:
	var is_cutting = Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	var time = Time.get_ticks_msec() / 1000.0

	var camera = get_parent()
	if not camera is Camera3D:
		return

	var vp = camera.get_viewport()
	if not vp:
		return
	var mouse_pos = vp.get_mouse_position()
	var vp_size = vp.get_visible_rect().size
	if vp_size.x < 1 or vp_size.y < 1:
		return

	var ndc_x = (mouse_pos.x / vp_size.x - 0.5) * 2.0
	var ndc_y = (mouse_pos.y / vp_size.y - 0.5) * 2.0

	var aim_local = Vector3(ndc_x * 0.3, -ndc_y * 0.2, -1.0).normalized()
	var from_elbow = (aim_local * tool_length - elbow_pos).normalized()

	var target_basis = Basis.looking_at(-from_elbow, Vector3.UP)

	var bob_y = sin(time * 2.2) * 0.008
	var bob_x = cos(time * 1.1) * 0.005
	var target_pos = elbow_pos + Vector3(bob_x, bob_y, 0.0)

	if is_cutting:
		var vib = Vector3(randf_range(-0.008, 0.008), randf_range(-0.008, 0.008), randf_range(-0.008, 0.008))
		target_pos += vib

	tool_holder.position = tool_holder.position.lerp(target_pos, 10.0 * delta)

	var cur_q = Quaternion(tool_holder.basis)
	var tgt_q = Quaternion(target_basis)
	var new_q = cur_q.slerp(tgt_q, clamp(10.0 * delta, 0.0, 1.0))
	tool_holder.basis = Basis(new_q)

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
				var offset_speed = 22.0 if is_cutting else 0.0
				chainsaw_material_override.uv1_offset += Vector3(offset_speed * delta, offset_speed * delta, 0.0)
	elif (active_tool_name == "mini_sierra" or active_tool_name == "mini-saw") and is_instance_valid(current_model):
		var blade = current_model.get_node_or_null("texture_pbr_v128")
		if blade:
			var spin_speed = 65.0 if is_cutting else 0.0
			blade.rotate_object_local(Vector3.RIGHT, spin_speed * delta)
