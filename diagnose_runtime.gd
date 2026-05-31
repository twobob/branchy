extends SceneTree

func _init():
	print("=== RUNTIME DIAGNOSTICS ===")
	
	# Load the scene
	var scene = load("res://main.tscn")
	if not scene:
		print("ERROR: Cannot load main.tscn")
		quit()
		return
	
	var root = scene.instantiate()
	get_root().add_child(root)
	
	# Wait 2 frames for _ready to fire
	await process_frame
	await process_frame
	
	# Find TreeGenerator3D
	var tree_gen = root.get_node_or_null("TreeGenerator3D")
	if not tree_gen:
		print("ERROR: No TreeGenerator3D node")
		for child in root.get_children():
			print("  Child: ", child.name, " (", child.get_class(), ")")
		quit()
		return
	
	print("TreeGenerator3D found: ", tree_gen)
	print("  branches count: ", tree_gen.branches.size())
	
	# Check a branch
	if tree_gen.branches.size() > 0:
		var b = tree_gen.branches[0]
		var segs = b.get("segments", [])
		var jts = b.get("joints", [])
		print("  Branch 0:")
		print("    segments: ", segs.size())
		print("    joints: ", jts.size())
		print("    severed: ", b.get("severed", false))
		print("    parent_index: ", b.get("parent_index", -1))
		print("    children: ", b.get("children", []))
		if segs.size() > 0:
			var seg = segs[0]
			print("    seg0 class: ", seg.get_class())
			print("    seg0 can_sleep: ", seg.can_sleep)
			print("    seg0 gravity_scale: ", seg.gravity_scale)
			print("    seg0 collision_mask: ", seg.collision_mask)
			print("    seg0 freeze: ", seg.freeze)
			print("    seg0 sleeping: ", seg.sleeping)
			print("    seg0 linear_damp: ", seg.linear_damp)
	
	# Check trunk
	var trunk = tree_gen.get_node_or_null("Trunk")
	if trunk:
		print("  Trunk: ", trunk.get_class())
		print("    collision_layer: ", trunk.collision_layer)
		print("    collision_mask: ", trunk.collision_mask)
	else:
		print("  Trunk: NOT FOUND")
	
	# Check MeshSlicer
	var slicer = tree_gen.get_node_or_null("MeshSlicer")
	print("  MeshSlicer in TreeGen: ", slicer)
	slicer = root.get_node_or_null("MeshSlicer")
	print("  MeshSlicer in Main: ", slicer)
	
	# Test CSG slice on a branch segment
	if tree_gen.branches.size() > 0:
		var b = tree_gen.branches[0]
		var segs = b.get("segments", [])
		if segs.size() > 0:
			var seg = segs[0]
			var mesh_inst: MeshInstance3D = null
			for child in seg.get_children():
				if child is MeshInstance3D:
					mesh_inst = child
					break
			if mesh_inst and mesh_inst.mesh:
				print("  Test slice:")
				print("    mesh type: ", mesh_inst.mesh.get_class())
				print("    mesh surfaces: ", mesh_inst.mesh.get_surface_count())
				print("    mesh AABB: ", mesh_inst.mesh.get_aabb())
				
				# Try CSG slice
				var test_slicer = MeshSlicer.new()
				root.add_child(test_slicer)
				var slice_xform = Transform3D()
				slice_xform.origin = mesh_inst.mesh.get_aabb().get_center()
				var result = test_slicer.slice_mesh(slice_xform, mesh_inst.mesh)
				print("    slice result[0]: ", result[0], " surfaces: ", result[0].get_surface_count() if result[0] else 0)
				print("    slice result[1]: ", result[1], " surfaces: ", result[1].get_surface_count() if result[1] else 0)
				test_slicer.queue_free()
			else:
				print("  No mesh on segment 0")
	
	# Check camera ray setup
	var cam = root.get_node_or_null("Camera3D")
	if cam:
		print("  Camera3D found, near: ", cam.near, " far: ", cam.far)
	else:
		print("  Camera3D NOT FOUND")
	
	print("=== DIAGNOSTICS COMPLETE ===")
	quit()
