extends Node3D

var active_tool_name: String = "none"
var tool_holder: Node3D = null
var current_model: Node3D = null

var chainsaw_material_duplicated: bool = false
var chainsaw_material_override: StandardMaterial3D = null

var tool_configs: Dictionary = {}
var rest_pos: Vector3 = Vector3(0.35, -0.25, -0.6)

func _ready() -> void:
	tool_holder = Node3D.new()
	tool_holder.name = "ToolHolder"
	add_child(tool_holder)
	tool_holder.position = rest_pos

	tool_configs = {
		"husqvarna": {
			"scene_path": "res://assets/husqvarna_chainsaw_LP.obj",
			"is_mesh": true,
			"scale": Vector3(0.012, 0.012, 0.012),
			"rotation_deg": Vector3(0, 0, 90),
			"offset": Vector3(0, 0.15, 0),
			"type": "chainsaw"
		},
		"chainsaw": {
			"scene_path": "res://assets/chainsaw.glb",
			"is_mesh": false,
			"scale": Vector3(0.7, 0.7, 0.7),
			"rotation_deg": Vector3(0, 180, 0),
			"offset": Vector3.ZERO,
			"type": "chainsaw"
		},
		"animated_chainsaw": {
			"scene_path": "res://assets/animated_chainsaw.glb",
			"is_mesh": false,
			"scale": Vector3(0.012, 0.012, 0.012),
			"rotation_deg": Vector3(0, 180, 0),
			"offset": Vector3.ZERO,
			"type": "chainsaw"
		},
		"makita_brushless": {
			"scene_path": "res://assets/makita_brushless.glb",
			"is_mesh": false,
			"scale": Vector3(0.5, 0.5, 0.5),
			"rotation_deg": Vector3(0, 180, 0),
			"offset": Vector3.ZERO,
			"type": "chainsaw"
		},
		"makita_outdoor": {
			"scene_path": "res://assets/makita_outdoor.fbx",
			"is_mesh": false,
			"scale": Vector3(0.012, 0.012, 0.012),
			"rotation_deg": Vector3(0, 0, 90),
			"offset": Vector3.ZERO,
			"type": "chainsaw"
		},
		"mini_sierra": {
			"scene_path": "res://assets/mini_sierra.glb",
			"is_mesh": false,
			"scale": Vector3(0.8, 0.8, 0.8),
			"rotation_deg": Vector3(0, 90, 0),
			"offset": Vector3.ZERO,
			"type": "mini_saw"
		}
	}

func set_active_tool(tool_name: String) -> void:
	active_tool_name = tool_name.to_lower()
	if is_instance_valid(current_model):
		current_model.queue_free()
		current_model = null
	chainsaw_material_duplicated = false
	chainsaw_material_override = null

	if not tool_configs.has(active_tool_name):
		for key in tool_configs:
			if key.contains(active_tool_name) or active_tool_name.contains(key):
				active_tool_name = key
				break

	if not tool_configs.has(active_tool_name):
		return

	var cfg = tool_configs[active_tool_name]
	var res = load(cfg.scene_path)
	if not res:
		return

	if cfg.is_mesh and res is Mesh:
		current_model = MeshInstance3D.new()
		current_model.mesh = res
	elif res is PackedScene:
		current_model = res.instantiate()
	else:
		return

	tool_holder.add_child(current_model)
	current_model.scale = cfg.scale
	current_model.rotation_degrees = cfg.rotation_deg
	current_model.position = cfg.offset

func select_tool(tool_name: String) -> void:
	set_active_tool(tool_name)

func get_tool_type() -> String:
	if tool_configs.has(active_tool_name):
		return tool_configs[active_tool_name].type
	return "none"

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
	if vp_size.x < 1.0 or vp_size.y < 1.0:
		return

	var ndc_x = (mouse_pos.x / vp_size.x - 0.5) * 2.0
	var ndc_y = -(mouse_pos.y / vp_size.y - 0.5) * 2.0

	var pivot = Vector3(0.4, -0.3, -0.25)
	var aim_point = Vector3(ndc_x * 0.35, ndc_y * 0.25, -1.2)
	var arm_dir = (aim_point - pivot).normalized()

	var pitch = asin(clamp(-arm_dir.y, -0.8, 0.8))
	var yaw = atan2(arm_dir.x, -arm_dir.z)

	var target_rot = Vector3(pitch, yaw, 0.0)
	var target_pos = pivot

	var bob_y = sin(time * 2.0) * 0.006
	var bob_x = cos(time * 1.3) * 0.004
	target_pos += Vector3(bob_x, bob_y, 0.0)

	if is_cutting:
		target_pos.z -= 0.15
		var vib = Vector3(randf_range(-0.006, 0.006), randf_range(-0.006, 0.006), 0.0)
		target_pos += vib

	tool_holder.position = tool_holder.position.lerp(target_pos, 12.0 * delta)
	tool_holder.rotation.x = lerp_angle(tool_holder.rotation.x, target_rot.x, 12.0 * delta)
	tool_holder.rotation.y = lerp_angle(tool_holder.rotation.y, target_rot.y, 12.0 * delta)
	tool_holder.rotation.z = lerp_angle(tool_holder.rotation.z, 0.0, 12.0 * delta)

	if get_tool_type() == "chainsaw" and is_instance_valid(current_model):
		var mesh_inst: MeshInstance3D = null
		if current_model is MeshInstance3D:
			mesh_inst = current_model
		else:
			for child in current_model.get_children():
				if child is MeshInstance3D:
					mesh_inst = child
					break
				for sub in child.get_children():
					if sub is MeshInstance3D:
						mesh_inst = sub
						break
					for sub2 in sub.get_children():
						if sub2 is MeshInstance3D:
							mesh_inst = sub2
							break
		if mesh_inst:
			if not chainsaw_material_duplicated:
				var mat = mesh_inst.get_active_material(0)
				if mat:
					chainsaw_material_override = mat.duplicate()
					mesh_inst.material_override = chainsaw_material_override
					chainsaw_material_duplicated = true
			if chainsaw_material_override:
				var speed = 22.0 if is_cutting else 0.0
				chainsaw_material_override.uv1_offset += Vector3(speed * delta, speed * delta, 0.0)

	elif get_tool_type() == "mini_saw" and is_instance_valid(current_model):
		var blade = current_model.get_node_or_null("texture_pbr_v128")
		if blade:
			var speed = 40.0 if is_cutting else 0.0
			blade.rotate_object_local(Vector3.RIGHT, speed * delta)
