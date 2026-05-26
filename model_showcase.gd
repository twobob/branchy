@tool
extends Node3D

func _ready() -> void:
	if not Engine.is_editor_hint():
		return
	for c in get_children():
		c.queue_free()

	var models = [
		{"name": "1_Husqvarna", "path": "res://assets/husqvarna_chainsaw_LP.obj", "is_mesh": true, "scale": Vector3(0.01, 0.01, 0.01), "rot": Vector3(0, -90, 90)},
		{"name": "2_Chainsaw", "path": "res://assets/chainsaw.glb", "is_mesh": false, "scale": Vector3(0.7, 0.7, 0.7), "rot": Vector3(0, 180, 0)},
		{"name": "3_Animated", "path": "res://assets/animated_chainsaw.glb", "is_mesh": false, "scale": Vector3(1.0, 1.0, 1.0), "rot": Vector3(0, 90, 0)},
		{"name": "4_Makita_Brushless", "path": "res://assets/makita_brushless.glb", "is_mesh": false, "scale": Vector3(0.5, 0.5, 0.5), "rot": Vector3(-90, 180, 0)},
		{"name": "5_Makita_Outdoor", "path": "res://assets/makita_outdoor.fbx", "is_mesh": false, "scale": Vector3(1.0, 1.0, 1.0), "rot": Vector3(-90, -90, 0)},
		{"name": "6_Mini_Sierra", "path": "res://assets/mini_sierra.glb", "is_mesh": false, "scale": Vector3(0.8, 0.8, 0.8), "rot": Vector3(-90, 90, 0)},
		{"name": "7_Chainsaw_C66", "path": "res://assets/chainsaw_c66.glb", "is_mesh": false, "scale": Vector3(1.0, 1.0, 1.0), "rot": Vector3.ZERO},
		{"name": "8_WoodChipper", "path": "res://assets/woodchipper/scene.gltf", "is_mesh": false, "scale": Vector3(0.1, 0.1, 0.1), "rot": Vector3.ZERO},
	]

	var x_pos = 0.0
	for m in models:
		var res = load(m.path)
		if not res:
			continue

		var holder = Node3D.new()
		holder.name = m.name
		add_child(holder)
		holder.owner = get_tree().edited_scene_root
		holder.position = Vector3(x_pos, 1.0, 0)

		var inst: Node3D
		if m.is_mesh and res is Mesh:
			inst = MeshInstance3D.new()
			inst.mesh = res
		elif res is PackedScene:
			inst = res.instantiate()
		else:
			continue

		inst.name = "Model"
		inst.scale = m.scale
		inst.rotation_degrees = m.rot
		holder.add_child(inst)
		inst.owner = get_tree().edited_scene_root

		var label = Label3D.new()
		label.text = m.name.replace("_", " ")
		label.position = Vector3(0, -1.2, 0)
		label.font_size = 48
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		holder.add_child(label)
		label.owner = get_tree().edited_scene_root

		x_pos += 3.0
