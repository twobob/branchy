extends Node3D

var active_tool_name: String = "none"
var tool_holder: Node3D = null
var current_model: Node3D = null
var is_cutting: bool = false

var tool_configs: Dictionary = {}
var rest_pos: Vector3 = Vector3(0.35, -0.35, -0.55)

func _ready() -> void:
	tool_holder = Node3D.new()
	tool_holder.name = "ToolHolder"
	add_child(tool_holder)
	tool_holder.position = rest_pos

	tool_configs = {
		"husqvarna": {
			"scene_path": "res://assets/husqvarna_chainsaw_LP.obj",
			"is_mesh": true,
			"scale": Vector3(0.01, 0.01, 0.01),
			"rotation_deg": Vector3(0, -90, 90),
			"offset": Vector3.ZERO,
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
			"scale": Vector3(1.0, 1.0, 1.0),
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
			"scale": Vector3(1.0, 1.0, 1.0),
			"rotation_deg": Vector3(0, -90, 90),
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
		},
		"hands": {
			"scene_path": "",
			"is_mesh": false,
			"scale": Vector3.ONE,
			"rotation_deg": Vector3.ZERO,
			"offset": Vector3.ZERO,
			"type": "hands"
		}
	}

func set_active_tool(tool_name: String) -> void:
	active_tool_name = tool_name.to_lower().replace(" ", "_")
	if is_instance_valid(current_model):
		current_model.queue_free()
		current_model = null

	if not tool_configs.has(active_tool_name):
		for key in tool_configs:
			if key.contains(active_tool_name) or active_tool_name.contains(key):
				active_tool_name = key
				break

	if not tool_configs.has(active_tool_name):
		return

	var cfg = tool_configs[active_tool_name]

	if cfg.scene_path == "":
		return

	var res = load(cfg.scene_path)
	if not res:
		return

	if cfg.is_mesh and res is Mesh:
		current_model = MeshInstance3D.new()
		(current_model as MeshInstance3D).mesh = res
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
	is_cutting = Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	var time = Time.get_ticks_msec() / 1000.0

	var target_pos = rest_pos
	var bob_y = sin(time * 2.0) * 0.005
	var bob_x = cos(time * 1.3) * 0.003
	target_pos += Vector3(bob_x, bob_y, 0.0)

	if is_cutting:
		target_pos.z -= 0.1
		var vib = Vector3(
			randf_range(-0.005, 0.005),
			randf_range(-0.005, 0.005),
			0.0
		)
		target_pos += vib

	tool_holder.position = tool_holder.position.lerp(target_pos, 10.0 * delta)

	if get_tool_type() == "mini_saw" and is_instance_valid(current_model):
		for child in current_model.get_children():
			if child is MeshInstance3D:
				var speed = 40.0 if is_cutting else 0.0
				child.rotate_object_local(Vector3.RIGHT, speed * delta)
